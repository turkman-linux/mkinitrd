#!/bin/busybox ash
set -e
set -o pipefail
export PATH=/usr/sbin:/usr/bin:/sbin:/bin
if [ -f $(dirname $0)/optparse.sh ] ; then
    source $(dirname $0)/optparse.sh
else
    source /etc/initrd/optparse.sh
fi
source $config
source $basedir/functions.sh
if [ -f "$output" ] && [ "$update" != 1 ] ; then
    echo "Error: The output file $output already exists."
    echo "To regenerate it, please use the '-u' option."
    exit 1
fi
# depmod kernel
depmod -a "$kernel"
# create work
export work=$(mktemp -d)
echo "Create workdir: $work"
for dir in etc bin lib scripts; do
    mkdir -p $work/$dir
done
ln -s .. $work/usr
ln -s bin $work/sbin
# copy base libc
cp -f $basedir/init $work/init
copy_binary ldconfig busybox
i=0
for mod in $hooks ; do
    hook="$basedir/hooks/$mod.sh"
    script="$basedir/scripts/$mod.sh"
    if [ -f $hook ] ; then
        echo "Run Hook: $mod"
        source $hook
    fi
    if [ -f $script ] ; then
        cp -f $script $work/scripts/"$i-$mod".sh
        i=$(($i+1))
    fi
done
# busybox symlinks
if [ -f $work/bin/busybox ] ; then
    $work/bin/busybox --list | grep -v busybox | while read line ; do
        if ! [ -f $work/bin/$line ] ; then
            ln -s busybox $work/bin/$line
        fi
    done
fi
# depmod
if [ -f $work/bin/depmod ] ; then
    echo "Run depmod for: $kernel"
    $work/bin/depmod -a -b $work/ $kernel
fi
#tree $work
cur=$PWD
cd $work
chmod 755 $work/bin $work/lib
echo "Compress: $output"
find . | cpio -H newc -o | $compress > $output
cd $cur
# clear work
if [ "$keep" == 0 ] ; then
    rm -rf $work
fi
# mkunify
if [ "$mkunify" == 1 ] ; then
    exec mkunify -a -l /boot/vmlinuz-$kernel -i $output
fi
# force sync
echo s > /proc/sysrq-trigger
