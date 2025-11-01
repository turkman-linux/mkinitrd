#!/bin/sh
if [ "$fstypes" == "" ] ; then
    fstypes="ext4"
fi
for fs in $filesystems ; do
    copy_modules $filesystems
    copy_binary $(command -v fsck.$filesystems)
done

copy_binary $(command -v blkid)