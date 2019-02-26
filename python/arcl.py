#!/bin/false  This file is not meant to be run.

# Python module for ARCL clients.

import re
import socket
import time

# Exception thrown when no expected response is received.
class Timeout(RuntimeError):
  pass

# Turn on debug spew by assigning a file to .spew.  For example
#   foo=Arcl(...)
#   foo.spew = sys.stdout
# Turn on logging of all ARCL commands and responses similarly:
#   foo.commLog = open('arcl.log', 'w')
# Additional functions are available on subclasses ArclEM and ArclRobot.
class Arcl:
  def __init__(self, ip, port=None):
    if port is None: port = 7171
    self.ip = (ip, port)
    # debug spew
    self.spew = False
    # log all data sent & received
    self.commLog = None
    # Remaining line fragment at end of last packet, string
    self.fragment = ''
    # Remaining lines after a match, list of strings
    self.lines = []

  # Open the socket, provide the password, and read the command list.
  p_pw = re.compile('Enter password:')
  p_endCmds = re.compile('End of commands')
  def connect(self, password, timeout=1.0):
    self.sock = socket.socket()
    self.sock.connect(self.ip)
    self.expect([self.p_pw], timeout)
    self.send(password)
    self.expect([self.p_endCmds], timeout)

  def send(self, text):
    if self.commLog:
      print("--> " + text, file=self.commLog)
    text += '\r\n'
    self.sock.send(text.encode('ascii'))

  # Read one packet or time out. Return list of strings, one per line.
  def _readLines(self, timeout):
    self.sock.settimeout(timeout)
    try:
      data = self.sock.recv(8096)
    except socket.timeout:
      if self.spew: print('_readLines: socket timed out')
      return []
    if self.spew: print('_readLines: got {} bytes'.format(len(data)))
    # convert data to list of lines
    lines = list()
    start = 0
    for i in range(len(data)):
      # 13 == \r; assume \r is always followed by \n.
      if data[i] == 13:
        lines.append(data[start:i].decode('ascii'))
        start = i + 2
    # TODO  This scheme fails if end of packet occurs between \r and \n.
    # Prepend any fragmentary line from previous packet.
    if len(lines) > 0 and len(self.fragment) > 0:
      lines[0] = self.fragment + lines[0]
      self.fragment = ''
    # Hold on to any remaining fractional line at end of packet.
    if start < len(data):
      self.fragment += data[start:].decode('ascii')
    if self.commLog:
      for line in lines:
        print("<-- " + line, file=self.commLog)
    return lines

  # Read lines until one of the patterns matches, or timeout expires.
  # Leave the pattern that matched on self.matchedPattern and the
  # re.MatchObject on self.matchObject.
  def expect(self, patterns, timeout):
    self.matchedPattern = None
    self.matchObject = None
    now = time.perf_counter()
    expiration = now + timeout
    while now < expiration:
      if len(self.lines) > 0:
        lines = self.lines
        self.lines = []
      else:
        lines = self._readLines(expiration - now)
      for n, line in enumerate(lines):
        for pat in patterns:
          mob = pat.match(line)
          if (mob):
            self.matchedPattern = pat
            self.matchObject = mob
            if self.spew:
              print('"{}" matched "{}"'.format(line, pat))
            # Hold on to any remaining lines.
            self.lines = lines[n + 1:]
            return
      now = time.perf_counter()
    raise Timeout('ARCL timeout.')

  # Return a configuration section as a dict.
  p_cfgItem = re.compile(r'GetConfigSectionValue: (?P<name>[^ ]+) (?P<value>.*)')
  p_cfgEnd = re.compile('EndOfGetConfigSectionValues')
  def getConfig(self, section):
    self.send('getConfigSectionValues {}'.format(section))
    result = dict()
    while True:
      self.expect([self.p_cfgItem, self.p_cfgEnd], 1.0)
      if self.matchedPattern is self.p_cfgEnd:
        return result
      if self.matchedPattern is self.p_cfgItem:
        result[self.matchObject.group('name')] = self.matchObject.group('value')

  # Set configuration.  Takes a dict of dicts.
  # First key is section, second is parameter.
  p_cfgChanged = re.compile('Configuration changed')
  def setConfig(self, config):
    self.send('ConfigStart')
    for (section, params) in config.items():
      self.send('ConfigAdd Section {}'.format(section))
      for (name, value) in params.items():
        self.send('ConfigAdd {} {}'.format(name, value))
    self.send('ConfigParse')
    self.expect([self.p_cfgChanged], 5.0)

class ArclEM(Arcl):
  def __init__(self, ip, port=None):
    super().__init__(ip, port)

  # Queue one job and wait for it to complete.  Returns the robot name.
  p_queued = re.compile('queuepickup .* id (?P<id>[^ ]*) .* successfully queued')
  def queuePickup(self, goal, timeout):
    self.send("queuePickup " + goal)
    self.expect([self.p_queued], 1.0)
    requestid = self.matchObject.group('id')
    p = 'QueueUpdate: {} [^ ]+ [^ ]+ Completed' \
        + ' [^ ]+ Goal "[^"]*" "(?P<robot>[^"]*)"'
    p_completed = re.compile(p.format(requestid))
    self.expect([p_completed], timeout)
    return self.matchObject.group('robot')

  p_status = re.compile('QueueRobot: "(?P<robot>[^"]*)"')
  p_parked = re.compile('QueueRobot: "(?P<robot>[^"]*)" Available Parked')

  def waitParked(self, robot, timeout):
    now = time.perf_counter()
    expiration = now + timeout
    while now < expiration:
      time.sleep(2)
      self.send('queueShowRobot "{}"'.format(robot))
      self.expect([self.p_parked, self.p_status], 1.0)
      if self.matchedPattern is self.p_parked \
            and self.matchObject.group('robot') == robot:
        if self.spew: print('Parked')
        return True
      now = time.perf_counter()
    return False

  # Return the current map file.
  oldp_map = re.compile(r'GetConfigSectionValue: Map (.*)')
  oldp_configEnd = re.compile('EndOfGetConfigSectionValues')
  def oldgetMap(self):
    self.send('getConfigSectionValues Files')
    theMap = None
    while True:
      self.expect([self.p_map, self.p_configEnd], 1.0)
      if self.matchedPattern is self.p_configEnd:
        break
      if self.matchedPattern is self.p_map:
        theMap = self.matchObject.group(1)
    if theMap is None:
      raise RuntimeError('No map property.')
    return theMap

  oldp_configChanged = re.compile('Configuration changed')
  def oldsetMap(self, theMap):
    self.send('ConfigStart')
    self.send('ConfigAdd Section Files')
    self.send('ConfigAdd Map ' + theMap)
    self.send('ConfigAdd Section Path Planning Settings')
    self.send('ConfigAdd PlanRes 20.0')
    self.send('ConfigParse')
    self.expect([self.p_configChanged], 5.0)

class ArclRobot(Arcl):
  def __init__(self, ip, port=None):
    super().__init__(ip, port)

  # Send the robot to a named goal.  Return True/False on success/failure.
  p_going = re.compile('Going to ')
  p_arrived = re.compile('Arrived at ')
  p_failed = re.compile('Error: Failed going to goal')
  def gotoGoal(self, goal, timeout):
    self.send("GoTo " + goal)
    self.expect([self.p_going], 1.0)
    self.expect([self.p_arrived, self.p_failed], timeout)
    if self.spew and self.matchObject is self.p_failed:
      print('Failed gotoGoal ' + goal, self.spew)
    return self.matchObject is self.p_arrived

  # Send the robot to specific coordinates.
  # If you don't care about heading, pass '' for th.
  def gotoPoint(self, x, y, th, timeout):
    self.send("GoToPoint {} {} {}".format(x, y, th))
    self.expect([self.p_going], 1.0)
    self.expect([self.p_arrived, self.p_failed], timeout)
    if self.spew and self.matchObject is self.p_failed:
      print('Failed gotoPoint {} {} {}'.format(x, y, th))
    return self.matchObject is self.p_arrived

