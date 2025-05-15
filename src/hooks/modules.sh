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
