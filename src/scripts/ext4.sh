#!/bin/sh
function init_top(){
    modprobe ext4
    fsck.ext4 -y "$root" || true
}

function init_bottom(){
    :
}