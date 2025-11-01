#!/bin/sh
function init_top(){
    if [ "$rootfstype" == "" ] ; then
        rootfstype=ext4
    fi
    modprobe $rootfstype || true
    if command -v fsck.$rootfstype >/dev/null ; then
        yes "" | fsck.$rootfstype "$root" || true
    fi
    modprobe sd_mod || true
    modprobe sr_mod || true
    if [ "${root#UUID=}" != "$root" ]; then
        # mark as custom rootfs mount
        mkdir -p /rootfs
    fi
}

function init_bottom(){
    # find uuid root and mount
    if [ "${root#UUID=}" != "$root" ]; then
        for dev in /sys/class/block/* ; do
            part="/dev/${dev##*/}"
            uuid=$(blkid -s UUID -o value)
            if [ "${root#UUID=}" == "${uuid}" ] ; then
                mount -t auto "${part}" /rootfs
                break
            fi
        done
    fi
}
