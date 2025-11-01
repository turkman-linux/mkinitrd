#!/bin/sh
function init_top(){
    if [ -f /etc/modules ] ; then
        cat /etc/modules | while read module ; do
            if [ "$module" == "" ] ; then
                modprobe $module || true
            fi
        done
    fi
}

function init_bottom(){
    :
}
