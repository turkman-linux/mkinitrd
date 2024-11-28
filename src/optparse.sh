#!/bin/busybox ash
output=""
update=0
kernel="$(uname -r)"
basedir="/etc/initrd/"
compress=gzip
config=""
firmware=0
mkunify=0

function help_message() {
    echo "Usage: mkinitrd [OPTIONS]"
    echo "Create an initial ramdisk image for booting the Linux kernel."
    echo ""
    echo "Options:"
    echo "  -o <output>      Specify the output file path."
    echo "  -b <basedir>     Specify the base directory."
    echo "                    Default is /etc/initrd/."
    echo "  -k <kernel>      Specify the kernel version."
    echo "                    Default is the $(uname -r)"
    echo "  -f               Enable firmware inclusion in the output."
    echo "  -c <config>      Specify the configuration file path."
    echo "  -z <compress>    Specify the compression method. Default is 'gzip'."
    echo "  -u               Update mode. Run in update mode if this flag is provided."
    echo "  -a               Generate unified kernel image then add into efivars."
    echo "  -h, --help       Display this help message and exit."

}

for arg in $@ ; do
    if [ "$arg" == "-u" ] ; then
        update=1
    elif [ "$arg" == "-a" ] ; then
        mkunify="1"
    fi
done
while getopts ":o:b:k:f:c:z:u:a" arg; do
  case $arg in
    o)
      output=$(realpath $OPTARG)
      ;;
    c)
      config=$(realpath $OPTARG)
      ;;
    z)
      compress=$OPTARG
      ;;
    f)
      firmware=1
      ;;
    b)
      basedir=$(realpath $OPTARG)
      ;;
    k)
      kernel=$OPTARG
      ;;
    u);;
    a);;
    *)
      help_message
      exit 1
      ;;
  esac
done

if ! [ -d "$basedir" ] ; then
    echo "No such directory: $basedir"
    exit 1
fi
if [ "$config" == "" ] ; then
    config="$basedir/config.sh"
fi
if [ "$output" == "" ] ; then
    output="/boot/initrd.img-$kernel"
fi
export kernel
export firmware

