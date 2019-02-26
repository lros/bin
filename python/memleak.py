#!/usr/bin/env python3

# new memleak program

import arcl
import rssh
import time
import argparse
import sys

parser = argparse.ArgumentParser(prog='ml',
    description='Perform memory leak tests on a robot.')
parser.add_argument('-c', '--count', type=int, default=10, metavar='N',
    help='Repeat N times [10]')
parser.add_argument('--up', action='store_true',
    help='If changing res, increase it (make it coarser) rather than decrease.')
parser.add_argument('target', choices=['robot', 'sim'])
parser.add_argument('change', choices=['map', 'res'])

args = parser.parse_args()
print(args)

if args.change == 'map':
  def change():
    oldMap = arclServer.getConfig('Files')['Map']
    if oldMap == map1:
      newMap = map2
    else:
      newMap = map1
    print("Changing map from {} to {}".format(oldMap, newMap))
    arclServer.setConfig({
      'Files': { 'Map': newMap },
      'Path Planning Settings': { 'PlanRes': '20.0' },
    })
  def confirm():
    newMap = arclServer.getConfig('Files')['Map']
    print('Confirm: new map is ' + newMap)
elif args.change == 'res':
  if args.up:
    resolution = 15
    resIncr = 5
  else:
    resolution = 20 + 5 * args.count
    resIncr = -5
  def change():
    global resolution
    resolution += resIncr
    print("Setting PlanRes to {}".format(resolution))
    arclServer.setConfig({
      'Path Planning Settings': { 'PlanRes': resolution },
    })
  def confirm():
    newRes = arclServer.getConfig('Path Planning Settings')['PlanRes']
    print('Confirm: new PlanRes is ' + newRes)

if args.target == 'robot':
  emIP = None
  robotIP = '10.151.193.177'
  arclServer = arcl.ArclRobot(robotIP)
  map1 = 'common-new.map'
  map2 = 'common-new_MocapShift.map'
  def planAndGo():
    arclServer.gotoGoal('RD1', 45)
  def planAndReturn():
    arclServer.gotoPoint(1950, -3550, '', 45)
elif args.target == 'sim':
  emIP = '10.151.196.41'
  robotIP = '10.151.196.43'
  arclServer = arcl.ArclEM(emIP)
  map1 = 'sample_large.map'
  map2 = 'sample_large_1.map'
  def planAndGo():
    robotName = arclServer.queuePickup('P1', 30)
    assert(robotName == "Sim43")  # this is the only robot right now
  def planAndReturn():
    print('Wait for robot to park.')
    arclServer.waitParked("Sim43", 30)

memLog = open('memory.log', 'w')
def logMem(tag, robotIP):
  info = rssh.getMemInfo(robotIP)
  line = "{:>6}  {:>7}  {:>7}  {:>7}  {:>7}".format(tag,
    info['vmsize'], info['vmdata'], info['vmstk'], info['free'])
  print(line, file=memLog)

#arclServer.commLog = sys.stdout
arclServer.commLog = open('arcl.log', 'w')
arclServer.connect('arcl')

logMem("before", robotIP)
for i in range(args.count):
  change()
  print('Give the robot a chance to redo its maps.')
  time.sleep(5)
  confirm()
  logMem("change", robotIP)
  planAndGo()
  logMem("goal", robotIP)
  planAndReturn()
  logMem("return", robotIP)


