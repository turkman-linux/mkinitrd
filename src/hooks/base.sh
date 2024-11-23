#!/bin/sh
copy_binary busybox
busybox --list | grep -v busybox | while read line ; do
    ln -s busybox $work/bin/$line
done
cat /etc/os-release > $work/etc/os-release