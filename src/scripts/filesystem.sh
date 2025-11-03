#!/bin/sh
function get_part(){
    # find uuid root and mount
    if [ "${root#UUID=}" != "$root" ]; then
        for dev in /sys/class/block/* ; do
            part="/dev/${dev##*/}"
            uuid=$(blkid -s UUID -o value "$part")
            if [ "${root#UUID=}" == "${uuid}" ] ; then
                echo "$part"
                break
            fi
        done
    fi
}

function init_top(){
    if [ "${root#UUID=}" != "$root" ]; then
        # mark as custom rootfs mount
        mkdir -p /rootfs
        export root=$(get_part)
    fi
    if [ "$rootfstype" == "" ] ; then
        rootfstype=ext4
    fi
    modprobe $rootfstype || true
    if command -v fsck.$rootfstype >/dev/null ; then
        yes "" | fsck.$rootfstype "$root" || true
    fi
    modprobe sd_mod || true
    modprobe nvme   || true
    modprobe sr_mod || true
}

function init_bottom(){
    if [ "${root#UUID=}" != "$root" ]; then
        mount -t auto $(get_part) /rootfs
    fi
}