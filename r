#!/bin/bash
# Multipurpose script for interacting with robots and EMs.
# Set ROBOTIP to the IP of your robot or EM, and use these commands.

set -e

#
# Utility functions used by more than one subcommand.
#

# Report an error.
# Args: CODE HELP_FN MESSAGE...
# Prints MESSAGE to stderr, invokes HELP_FN, then exits with CODE
function _error() {
  code=$1; shift
  helpFn=$1; shift
  message="$*"
  echo "$message" >&2
  $helpFn >&2
  exit $code
}

# If we're in a mobilesoftware repo, report the top or the repo.
# Otherwise report nothing.
function _top() {
  local p="$PWD"
  while [ ! -d "$p/.git" -o ! -d "$p/AramServer" ]; do
    p=$(cd "$p/.."; printenv PWD)
    if [ "$p" == / -o -z "$p" ]; then
      return
    fi
  done
  echo "$p"
}

# ssh options to prevent it from doing host key checking,
# since the host keys of the VMs change frequently.
sshNoHost="-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null"

#
# Print help for given subcommand or all subcommands.
#

function help() {
  subcmd=$1
  allsubcmds=(
    arcl
    ssh
    deploy
  )
}

#
# Deploy aram using the scp and symlink method.
#

# Report the latest version of Aram tarball in this repo.
function _deploy_latestAram() {
  which=$1
  shopt -s nullglob
  dir=$(_top)/AramServer
  files=($dir/${which}_*gz)
  let n=${#files[*]} || true  # don't fail the script if n is set to 0
  if [ 0 -eq $n ]; then
    _error 1 help_deploy "Cannot find '$which' tarball."
  fi
  let last=$n-1 || true  # don't fail the script if last is set to 0
  echo "${files[$last]}"
}

# Parse the args to deploy.
# Report path to the .tgz file to deploy.
function _deploy_args() {
  # There should be at most one argument.
  if [ $# -gt 1 ]; then
    _error 1 help_deploy "Too many arguments."
  fi
  # If there's one argument, it ends in .tgz, and it names a file.
  case "$1" in
    *.tgz|*.tar.gz)
      if [ -f "$1" ]; then
        echo "$1"
      else
        _error 1 help_deploy "File not found:" "$1"
      fi
      ;;
    aram)
      _deploy_latestAram aram
      ;;
    both|aramBoth)
      _deploy_latestAram aramBoth
      ;;
    central|aramCentral)
      _deploy_latestAram aramCentral
      ;;
    *)
      _error 1 help_deploy "Unknown argument:" "$1"
      ;;
  esac
}

function help_deploy() {
  cat <<EOF
Command:  r deploy (aram|both|aramBoth|central|aramCentral)
          r deploy PATH_TO_TARBALL

The first form deploys the latest aram, aramBoth, or aramCentral build
in this repository, to $ROBOTIP.

The second form deploys the specific tarball to $ROBOTIP.
EOF
}

# Args:  TGZ_FILENAME
#   or:  aram|aramCentral|aramBoth
function deploy() {
  pathTarball=$(_deploy_args "$@")
  ip=$ROBOTIP
  echo tarball is $pathTarball
  justTarball=$(dirname "$pathTarball")
  echo sshpass -proot scp $sshNoHost "$pathTarball" root@$ip:/mnt/rdos
  linkCmd="ln -s /mnt/rdos/$justTarball /mnt/rdsys/home/admin/"
  echo sshpass -proot ssh $sshNoHost root@$ip "$linkCmd"
}

#
# Deploy aram using the curl method.
#

#
# Actually parse the command line and do something.
#

cmd="$1"
shift || true  # don't fail if shift fails

case "$cmd" in
  "")
    if [ -n "$ROBOTIP" ]; then
      echo "Robot IP is $ROBOTIP"
    else
      echo "Robot IP is not set."
    fi
    ;;
  arcl)
    exec telnet $ROBOTIP 7171
    ;;
  ssh)
    exec ssh root@$ROBOTIP
    ;;
  deploy)
    deploy "$@"
    ;;
  *)
    echo "Command not understood: $cmd"
    ;;
esac
