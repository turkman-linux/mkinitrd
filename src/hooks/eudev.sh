#!/bin/sh
copy_binary kmod
for f in depmod insmod modinfo modprobe rmmod ; do
    rm -f $work/bin/$f
    ln -s kmod $work/bin/$f
done
if [ -f /lib/systemd/systemd-udevd ] ; then
    copy_binary /lib/systemd/systemd-udevd udevadm
else
    copy_binary udevd udevadm
fi
copy_files /etc/udev \
    /lib/udev/rules.d \
    /lib/udev/hwdb.bin \
    /lib/udev/hwdb.d
for prog in /lib/udev/*_id ; do
    copy_binary $prog
    ln -s /bin/${prog/*\//} $work/lib/udev/${prog/*\//}
done
for file in /lib/modules/$kernel/modules.* ; do
    copy_files $file
done
