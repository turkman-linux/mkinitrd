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
}

function init_bottom(){
    :
}
