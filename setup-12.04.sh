#!/bin/bash

# Set up a clean Ubuntu 12.04 installation for VGo build.

set -e
tmpfile=`mktemp /tmp/setup-XXXXXX`

# helper functions

# Make a symlink point to the desired item
#  symcheck /path/to/link target
# makes sure link points to target
function symcheck {
    local link=$1
    local target=$2
    if [ `readlink $link` = $target ] ; then
        echo "$link refers to $target"
    else
        sudo ln -sf $target $link
        echo "Made $link refer to $target"
    fi
}

# make sure a line is in a file
#  linecheck file keyword line
# if file does not contain keyword, append line to it
function linecheck {
    local file="$1"
    local keyword="$2"
    local line="$3"
    if grep -q "$keyword" "$file" ; then
        echo "Found $keyword in $file"
    else
        sudo cp "$file" $tmpfile
        sudo chmod a+w $tmpfile
        echo "$line" >> $tmpfile
        sudo cp $tmpfile "$file"
        sudo rm $tmpfile
        echo "Added $keyword to $file"
    fi
}

setup_dns () {
    local -a hostsline=(`grep '^hosts:' /etc/nsswitch.conf`)
    #echo "${hostsline[1]} == files -a ${hostsline[2]} == dns"
    if [ "${hostsline[1]}" == files -a "${hostsline[2]}" == dns ] ; then
        echo DNS is already set up correctly.
        return
    fi
    grep -v '^hosts:' </etc/nsswitch.conf >$tmpfile
    echo "hosts:          files dns mdns4_minimal [NOTFOUND=return] mdns4" \
            >>$tmpfile
    sudo cp $tmpfile /etc/nsswitch.conf
    rm -f $tmpfile
}

off_service () {
    local svc=$1
    if status $svc | grep -vq stop ; then
        sudo stop $svc
        echo Stopped $svc running now.
    fi
    local ofile=/etc/init/${svc}.override
    local override=nonexistent
    if [ -f $ofile ] ; then
        override=`cat $ofile`
    fi
    if [ "$override" != manual ] ; then
        sudo sh -c "echo manual > /etc/init/${svc}.override"
        echo Stopped Upstart from running $svc on boot.
    fi
}

# make sure the current user has infinite sudo rights
sudo -K
if sudo -l | grep -q 'NOPASSWD:' ; then
    echo "You appear to have the necessary sudo rights."
else
    echo "You need to set up sudo.  Do the following:"
    echo "  sudo su"
    echo "  vi /etc/sudoers.d/sclark"
    echo "  # The file content should be one line:"
    echo "    sclark ALL=NOPASSWD: ALL"
    echo "  chmod 0440 /etc/sudoers.d/sclark"
    echo "  # Check that it works in another shell before exiting."
    exit 1
fi

# make sure /bin/sh refers to bash (not dash)
symcheck /bin/sh bash

# make sure dns is set up correctly
setup_dns

# Stop useless services
off_service avahi-daemon
off_service bluetooth

# Necessary packages
pkglist=""
pkglist+=" subversion"
pkglist+=" g++"

# Steve's preferences
pkglist+=" vim-gnome"
pkglist+=" synaptic"
pkglist+=" autofs5"
pkglist+=" afpfs-ng-utils"

# Package list carried over from Ubuntu 10.04 setup
# Comments:  absent = from stock 12.04 install
#            present = in stock 12.04 install
#            does not exist = in 12.04's official package list
#pkglist+=" automake"          # absent
#pkglist+=" libc6-dev"         # present (perhaps due to g++)
#pkglist+=" flex"              # absent
#pkglist+=" gtk-doc-tools"     # absent
#pkglist+=" nfs-common"        # present
#pkglist+=" rpm"               # absent
#pkglist+=" librpm0"           # does not exist (librpm2 does)
#pkglist+=" zlib1g-dev"        # absent
#pkglist+=" libncurses5-dev"   # absent
#pkglist+=" gettext"           # absent
#pkglist+=" libglib2.0-dev"    # absent
#pkglist+=" libboost-dev"      # absent
#pkglist+=" make"              # present
#pkglist+=" bison"             # absent
#pkglist+=" liblzo2-dev"       # absent
#pkglist+=" libexpat1-dev"     # absent
#pkglist+=" libssl-dev"        # absent
#pkglist+=" tcl"               # absent

sudo apt-get -y install $pkglist || exit 1

# TODO set up automounts
# TODO set up ~/bin

