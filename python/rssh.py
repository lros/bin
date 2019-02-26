#!/bin/false  This file is not meant to be run.

# Python module for interacting with robots via ssh.

import re
import subprocess

# Run command as root on host ip, returning stdout as a list of lines.
def sshCmd(ip, command):
  cmdList = ['sshpass', '-proot', 'ssh', 'root@' + ip, command]
  ran = subprocess.run(cmdList,
    stdout=subprocess.PIPE,
    stderr=subprocess.DEVNULL,
    check=True)
  return ran.stdout.decode('ascii').split('\n')

# return the PID of aramServer as a string, or None
p_PID = re.compile('[0-9]+$')
def aramServerPID(ip):
  progs = [
    'aramServer' + sound + pylon
    for sound in ('Cepstral', '')
    for pylon in ('', 'Pylon')
  ]
  for prog in progs:
    try:
      lines = sshCmd(ip, "pidof " + prog)
    except subprocess.CalledProcessError:
      continue
    if p_PID.match(lines[0]):
      return lines[0]
  return None

# Return aramServer process size, data size, stack size in kB as a tuple.
cachedPID = None
def getMemInfo(ip):
  global cachedPID
  for attempt in range(2):
    if cachedPID is None:
      cachedPID = aramServerPID(ip)
    try:
      lines = sshCmd(ip, "cat /proc/" + cachedPID + "/status")
    except subprocess.CalledProcessError:
      if attempt == 0:
        print('cached PID {} did not work.'.format(cachedPID))
        cachedPID = None
        continue
      raise
    break
  vmsize = None
  vmdata = None
  vmstk = None
  for line in lines:
    words = line.split()
    if (len(words) < 2): continue
    if words[0] == "VmSize:": vmsize = words[1]
    elif words[0] == "VmData:": vmdata = words[1]
    elif words[0] == "VmStk:": vmstk = words[1]
  lines = sshCmd(ip, "cat /proc/meminfo")
  free = None
  for line in lines:
    words = line.split()
    if (len(words) < 2): continue
    if words[0] == "MemFree:":
      free = words[1]
      break
  return {
    'vmsize': vmsize,
    'vmdata': vmdata,
    'vmstk': vmstk,
    'free': free,
  }

