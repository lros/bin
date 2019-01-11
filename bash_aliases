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

# TODO Use tput to generate the escape sequences.
# (Example in Arnl/tests/exec.sh.)

# Set the window/icon title:
PS1='\[\e]0;${SPECIAL_SHELL:-\h}: \w\a\]'
# Set the first part of the prompt:
PS1+='\[\e[1;32m\]${SPECIAL_SHELL:-\h}\[\e[0m\]:'
# Set the second part of the prompt:
PS1+='\[\e[1;34m\]\w\[\e[0m\]\$ '

# Set up a special shell if appropriate.

case "$SPECIAL_SHELL" in
  Robot-MTX)
    # Chroot cross-development environment
    #echo "On the way in."

    # Which repo am I in?  Assume the fourth component of CURDIR.
    # (CURDIR might be e.g. /home/steve/mobilesoftware/Arnl.)
    repo=`echo $CURDIR | cut -d/ -s -f4`
    # If not in a repo, $repo is empty.
    if [ -z "$repo" ] ; then
      echo "Not in a repo!  Not setting environment variables."
    else
      repo="$HOME/$repo"
      # Cribbed from Matt LaFary's mobilesoftware/vars.
      # NOTE: these paths are in the chrooted filesystem.
      # I removed the buld time use of ARIA, ARNL, and ARAM.
      # These point to where I have .p files and maps.
      #export ARIA="$HOME/ubuntu"
      #export ARNL="$ARIA"
      #export ARAM="$ARIA"
      echo "Did not set ARIA, ARNL, ARAM"
      # vars sets ARIA_INTERNAL_LIBS.  I suspect it's unused.
      export LD_LIBRARY_PATH="$repo/AramServer/lib:/opt/pylon3/lib:/opt/pylon3/genicam/bin/Linux32_i86"
      # Needed when building versions that use Pylon.
      source /opt/pylon3/bin/pylon-setup-env.sh /opt/pylon3
      # vars set PMAKENUM to -j8.  Let's confuse our build time and
      # run time environments wherever possible!
    fi

    # Magically go to the right directory after chroot.
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

      # passing a command through or be interactive
      if [ $# -gt 0 ]; then
        cmd=(-c "source ~/.bash_aliases; $*")
      else
        cmd=()
      fi

      # Incantation to get into the environment
      sudo -E SPECIAL_SHELL=Robot-MTX CURDIR=$curDir \
          chroot "$root" su -p -l "${cmd[@]}" $USER
      unset root cmd
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

# Dubious value:
# Edit both dir/src/Foo.cpp and dir/include/Foo.h files:
#   xxvi dir/Foo
function xxvi () {
  for file in "$@" ; do
    d=$(dirname "$file")
    f=$(basename "$file")
    gvim -f "$d/src/$f.cpp" &>> /tmp/xvi.out &
    gvim -f "$d/include/$f.h" &>> /tmp/xvi.out &
  done
}

