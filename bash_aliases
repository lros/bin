# Personal modifications, leaving .bashrc untouched.

# Notes on setting PS1:
# See the PROMPTING section in 'man bash'.
# See https://www.xfree86.org/4.8.0/ctlseqs.html.
# \[...\] surrounds nonprinting text - so bash knows how to backspace.
# \e]0;...\a sets window/icon title.
# \e[...m sets character attributes such as color for following text.
#    attribute(s) are 0-normal, 1-bold, 32-green, 34-blue, separated by ;

# I replace the default user@host of PS1 with whatever I call the special
# shell that's running, or the hostname for a normal shell.  I do this by
# having the prompt use the same variable as this file keys off of.

# Set the window/icon title:
PS1='\[\e]0;${SPECIAL_SHELL:-\h}: \w\a\]'
# Set the first part of the prompt:
PS1+='\[\e[1;32m\]${SPECIAL_SHELL:-\h}\[\e[0m\]:'
# Set the second part of the prompt:
PS1+='\[\e[1;34m\]\w\[\e[0m\]\$ '

# Set up a special shell if appropriate.

case "$SPECIAL_SHELL" in
    ChrootXDev)
        # Chroot cross-development environment

        #echo "On the way in."
        cd ~/mobilesoftware
        source vars
        cd $CURDIR
        unset CURDIR
        ;;

    AramRuntime)
        # Runtime environment for ARAM software on Ubuntu

        #echo "On the way in."
        export ARIA="$HOME/home/ubuntu"
        export ARNL="$ARIA"
        export LD_LIBRARY_PATH="$HOME/home/ubuntu/lib"
        ;;

    '')
        # This is a regular shell
        function bsh () {
            # Root of the chroot environment
            root="$HOME/Robot-MTX"

            # Try to find the current directory within the chroot
            absHere=$(pwd -P)
            case "$absHere" in
                $root/*)
                    curDir=${absHere:${#root}}
                    ;;
                *)
                    curDir=.
            esac
            unset absHere

            # Make sure the bind mounts are mounted.
            if [ ! -e "$root/dev/zero" ]; then
                sudo mount "$root/dev"
                sudo mount "$root/proc"
                sudo mount "$root/sys"
                sudo mount "$root/tmp"
                sudo mount --bind ~/bin "$root/home/steve/bin"
            fi

            # Incantation to get into the environment
            sudo -E SPECIAL_SHELL=ChrootXDev CURDIR=$curDir \
                    chroot "$root" su -p - $USER
            unset root
        }
        function aramsh () {
            SPECIAL_SHELL=AramRuntime bash
        }
        ;;
esac

function xvi () {
    for file in "$@" ; do
        gvim -f "$file" &>> /tmp/xvi.out &
    done
}

