#!/bin/sh
copy_binary kmod
for f in depmod insmod modinfo modprobe rmmod ; do
    rm -f $work/bin/$f
    ln -s kmod $work/bin/$f
done

for file in /lib/modules/$kernel/modules.* ; do
    copy_files $file
done


if [ "$modules" == "most" ] ; then
    copy_module_tree \
        kernel/lib \
        kernel/crypto \
        kernel/drivers/block \
        kernel/drivers/ata \
        kernel/drivers/cdrom \
        kernel/drivers/usb \
        kernel/drivers/scsi \
        kernel/drivers/nvme \
        kernel/drivers/usb \
        kernel/drivers/pcmcia \
        kernel/drivers/virtio \
        kernel/drivers/ata \
        kernel/drivers/md \
        kernel/drivers/mmc \
        kernel/drivers/fireware \
        kernel/drivers/input/keyboard \
        kernel/drivers/input/serio \
        kernel/fs
elif [ "$modules" == "dep" ] ; then
    copy_modules $(ls /sys/module/)
elif [ "$modules" == "all" ] ; then
    copy_files /lib/modules/$kernel/
    if [ "$firmware" == "1" ] ; then
        copy_files /lib/firmware/
    fi
elif [ "$modules" == "none" ] ; then
    : Module Copy Disabled
fi

copy_modules $(cat /etc/modules /etc/modules.load.d/* | grep -v "#")
echo $(cat /etc/modules /etc/modules.load.d/* | grep -v "#") > $work/etc/modules

find $work/lib/modules -type f -iname "*.ko.gz" -exec gzip -d {} \;
find $work/lib/modules -type f -iname "*.ko.xz" -exec xz -d {} \;