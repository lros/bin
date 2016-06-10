function xvi () {
    for file in "$@" ; do
        gvim -f "$file" &>> /tmp/xvi.out &
    done
}

# Mount my home directory from the Mac on /mnt/mac:
#  1.  Make sure /mnt/mac exists and is writeable by sclark.
#  2.  Check the Mac's IP and change $macip accordingly.
#  3.  mm
# To unmount: um

macip=10.10.10.162

function mm () {
    if [ ! -d /mnt/mac ] ; then
        echo 'Create /mnt/mac and make it writeable by you.'
        exit 1
    fi
    if [ ! -w /mnt/mac ] ; then
        echo 'Make /mnt/mac writeable by you.'
        exit 1
    fi
    afp_client mount -u sclark -p - $macip:sclark /mnt/mac
    #read -srp "password: " pw
    #echo
    #mount_afp afp://sclark:$pw@$macip/sclark /mnt/mac
}

function um () {
    afp_client unmount /mnt/mac
}

export VGO_SWREPOSITORY=/mnt/auto/swrepository
export VGO_SCANLOG_DIR=~/data

for newdir in "$HOME/bin" "$HOME/build-bin" ; do
    case "$PATH" in
        *"${newdir}"*) ;;
        *) PATH="$newdir:$PATH"
    esac
done

if [ -e ~/.at_home ] ; then
    export VGO_MAP_DIR=~/work/mapdata
fi

function log () {
    ~/work/trunk/tools/postmortem/log.py "$@"
}

function vp () {
    vp.py "$@"
}
