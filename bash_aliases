# Personal modifications, leaving .bashrc untouched.

# Set up a special shell if appropriate.

case "$SPECIAL_SHELL" in
    BUILD)
        # Chroot cross-development environment

        #echo "On the way in."
        echo Entering build shell, part 2
        # esc]0;titlebel
        # Set the window (and icon) title to title.
        echo -e "\e]0;Build Shell\a"
        # esc[7m - set inverse; esc[0m - normal
        PS1='\e[7mBuild Shell: \w $\e[0m '
        cd ~/mobilesoftware
        source vars
        ;;

    ARAM)
        # Runtime environment for ARAM software on Ubuntu

        #echo "On the way in."
        echo -e "\e]0;ARAM Shell\a"
        PS1='\e[7mARAM Shell: \w $\e[0m '
        if false; then
            # Older approach that confuses build and run.
            root="$HOME/home/mobilesoftware"
            export ARIA="$root/Aria"
            export ARNL="$root/Arnl"
            export LD_LIBRARY_PATH="$ARIA/lib:$ARNL/lib"
        else
            export ARIA="$HOME/home/ubuntu"
            export ARNL="$ARIA"
            export LD_LIBRARY_PATH="$HOME/home/ubuntu/lib"
        fi
        unset root
        ;;

    '')
        # This is a regular shell
        function bsh () {
            echo Entering build shell, part 1
            # Root of the chroot environment
            root="$HOME/Robot-MTX"

            # Make sure the bind mounts are mounted.
            if [ ! -e "$root/dev/zero" ]; then
                sudo mount "$root/dev"
                sudo mount "$root/proc"
                sudo mount "$root/sys"
                sudo mount "$root/tmp"
                sudo mount --bind ~/bin "$root/home/steve/bin"
            fi

            # Incantation to get into the environment
            sudo -E SPECIAL_SHELL=BUILD chroot "$root" su -p - $USER
            unset root
        }
        function aramsh () {
            SPECIAL_SHELL=ARAM bash
        }
        ;;
esac

function xvi () {
    for file in "$@" ; do
        gvim -f "$file" &>> /tmp/xvi.out &
    done
}

