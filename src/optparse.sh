#!/bin/sh
output=""
update=0
kernel="$(uname -r)"
basedir="/etc/initrd/"
compress=cat
config=""
firmware=0
for arg in $@ ; do
    if [ "$arg" == "-u" ] ; then
        update=1
    fi
done
while getopts ":o:b:k:f:c:z:" arg; do
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
    *)
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
