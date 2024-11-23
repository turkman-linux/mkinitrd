#!/bin/sh
set -e
set -o pipefail
source /etc/initrd/optparse.sh
source $config
source $basedir/functions.sh
# create work
export work=$(mktemp -d)
for dir in etc bin lib scripts; do
    mkdir -p $work/$dir
done
ln -s .. $work/usr
ln -s bin $work/sbin
# copy base libc
cp -f $basedir/init.sh $work/init
copy_binary ldconfig
i=0
for module in $hooks ; do
    hook="$basedir/hooks/$module.sh"
    script="$basedir/scripts/$module.sh"
    if [ -f $hook ] ; then
        echo "Run Hook: $module"
        source $hook
    fi
    if [ -f $script ] ; then
        cp -f $script $work/scripts/"$i-$module".sh
        i=$(($i+1))
    fi
done
#tree $work
cur=$PWD
cd $work
chmod 755 -R $work
find . | cpio -H newc -ov | $compress > $output
# clear work
rm -rf $work
