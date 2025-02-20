#!/bin/sh
function init_top(){
    if [ "$rootfstype" == "" ] ; then
        rootfstype=ext4
    fi
    modprobe $rootfstype || true
    if command -v fsck.$rootfstype >/dev/null ; then
        fsck.$rootfstype "$root" || true
    fi
}

function init_bottom(){
    :
}
