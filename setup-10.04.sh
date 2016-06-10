#!/bin/bash

# Set up a clean Ubuntu 10.04 installation for VGo build.

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
    echo "${hostsline[1]} == files -a ${hostsline[2]} == dns"
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

# make sure the current user has infinite sudo rights
sudo -K
if sudo -l | grep -q 'NOPASSWD:' ; then
    echo "You appear to have the necessary sudo rights."
else
    echo "You need to set up sudo.  Run visudo and add a line at the end:"
    echo " $LOGNAME ALL=NOPASSWD: ALL"
    exit 1
fi

# make sure /bin/sh refers to bash (not dash)
symcheck /bin/sh bash

# make sure dns is set up correctly
setup_dns

# make sure apt-get will look for old packages we need
linecheck /etc/apt/sources.list \
    'old-releases\.ubuntu\.com.*jaunty.*universe' \
    'deb http://old-releases.ubuntu.com/ubuntu jaunty universe'

#sudo apt-get update
pkglist=""
pkglist+=" gcc-4.2"
pkglist+=" gcc-4.2-base"
pkglist+=" g++-4.2"

sudo apt-get -y install $pkglist || exit 1
symcheck /usr/bin/gcc gcc-4.2
symcheck /usr/bin/g++ g++-4.2

pkglist=""
pkglist+=" subversion"
pkglist+=" automake"
pkglist+=" libc6-dev"
pkglist+=" flex"
pkglist+=" gtk-doc-tools"
pkglist+=" nfs-common"
pkglist+=" rpm"
pkglist+=" librpm0"
pkglist+=" zlib1g-dev"
pkglist+=" libncurses5-dev"
pkglist+=" gettext"
pkglist+=" libglib2.0-dev"
pkglist+=" libboost-dev"
pkglist+=" make"
pkglist+=" bison"
pkglist+=" liblzo2-dev"
pkglist+=" libexpat1-dev"
pkglist+=" libssl-dev"
pkglist+=" tcl"

sudo apt-get -y install $pkglist || exit 1

# Install LTIB into /opt/freescale
function install_ltib () {
    sudo rm -rf /opt/freescale
    sudo mkdir -p /opt/freescale
    sudo chmod 077 /opt/freescale

    local cachedir=~/vgo-cache/freescale
    local cachedltib=$cachedir/L2.6.24_2.3.2_SDK_082008
    local ltibiso=IMX31_PDK14_LINUX_BSP_R14.tar.gz
    if [ ! -d $cachedltib ] ; then
        echo 'Untar LTIB ISO into vgo-cache.'
        mkdir -p $cachedir
        tar xf /mnt/auto/swrepository/freescale/$ltibiso -C $cachedir
    fi

    echo 'Untar LTIB into /opt/freescale.'
    tar xf $cachedltib/Common/ltib.tar.gz -C /opt/freescale
    echo 'Copy packages into /opt/freescale.'
    cp -dR $cachedltib/Common/pkgs /opt/freescale/ltib

    # fix the two lines in ltib script
    cp /mnt/auto/swrepository/freescale/ltib.fixed /opt/freescale/ltib/ltib

    echo 'When you get to the curses GUI to pick packages, quit.'
    echo -n 'Press the Enter key to continue: '
    read
    cd /opt/freescale/ltib
    ./ltib
}

if [ ! -x /opt/freescale/ltib/ltib ] ; then
    install_ltib
fi

