#!/bin/bash
# Multipurpose script for interacting with robots and Enterprise Managers.
# Set ROBOTIP to the IP of your robot, and/or CENTRALIP to the EM.

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

# Figure out which IP to use.
# Args: defaultIP
# Returns defaultIP unless overrideIP is set.
function _whichIP() {
  if [ -n "$overrideIP" ]; then
    echo "$overrideIP"
  else
    echo "$1"
  fi
}

# ssh options to prevent it from doing host key checking,
# since the host keys of the VMs change frequently.
sshNoHost="-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null"

#
# Print help for given topic or all topics.
#

function help() {
  topic=$1
  shift || true  # don't fail if shift fails
  # These are all the subcommands with a help_command function.
  alltopics=(
    arcl
    ssh
    deploy
  )
  case "$topic" in
    '')
      echo -n "Command:  r help all"
      for topic in "${alltopics[@]}"; do
        echo -n "|$topic"
      done
      echo
      echo "Print help on TOPIC, or all topics."
      ;;
    all)
      help
      for topic in "${alltopics[@]}"; do
        echo "-------- --------- -------- --------- -------- --------- --------"
        "help_$topic" || true
      done
      ;;
    *)
      if ! "help_$topic" 2>/dev/null; then
        echo "No help for $topic, sorry."
      fi
      ;;
  esac
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
Command:  r [-r] deploy (aram|both|aramBoth|central|aramCentral)
          r [-r] deploy PATH_TO_TARBALL

Deploys to the EM unless -r is present.

The first form deploys the latest aram, aramBoth, or aramCentral build
in this repository.

The second form deploys the specific tarball.
EOF
}

# Deploy using scp and symlink.
function deploy() {
  pathTarball=$(_deploy_args "$@")
  ip=$(_whichIP $CENTRALIP)
  echo tarball is $pathTarball
  justTarball=$(basename "$pathTarball")
  sshpass -proot scp $sshNoHost "$pathTarball" root@$ip:/mnt/rdos
  linkCmd="ln -s /mnt/rdos/$justTarball /mnt/rdsys/home/admin/"
  sshpass -proot ssh $sshNoHost root@$ip "$linkCmd"
}

# Deploy using the curl method.
function deploy_curl() {
  pathTarball=$(_deploy_args "$@")
  ip=$(_whichIP $CENTRALIP)
  cmd=(
    curl
    --insecure
    -u admin:admin
    -i
    -X POST
    -F upload_file=@"$pathTarball"
    "https://$ip/cgi-bin/uploadSoftware.cgi"
  )
  echo "${cmd[@]}"
  "${cmd[@]}"
  sleep 1
  deploy_curl_status
}

function deploy_curl_status() {
  ip=$ROBOTIP
  curl --insecure -u admin:admin "https://$ip/msgsrv.php"
}

#
# Actually parse the command line and do something.
#

function _perform() {
  cmd="$1"
  shift || true  # don't fail if shift fails

  case "$cmd" in
    "")
      if [ -z "$ROBOTIP" ]; then
        ROBOTIP="not set"
      fi
      if [ -z "$CENTRALIP" ]; then
        CENTRALIP="not set"
      fi
      echo "ROBOTIP is $ROBOTIP"
      echo "CENTRALIP is $CENTRALIP"
      ;;
    -r)
      overrideIP=$ROBOTIP
      _perform "$@"
      ;;
    -c)
      overrideIP=$CENTRALIP
      _perform "$@"
      ;;
    arcl)
      exec telnet $(_whichIP $ROBOTIP) 7171
      ;;
    ssh)
      exec ssh root@$(_whichIP $ROBOTIP)
      ;;
    ping)
      exec ping $(_whichIP $ROBOTIP)
      ;;
    deploy)
      deploy "$@"
      ;;
    deployc)
      deploy_curl "$@"
      ;;
    deploys)
      deploy_curl_status
      ;;
    help)
      help "$@"
      ;;
    *)
      echo "Command not understood: $cmd"
      ;;
  esac
}

useRobot=false;
useCentral=false;
_perform "$@"

