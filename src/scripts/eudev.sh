function init_top(){
    depmod -a
    mkdir -p /run/udev
    if command -v systemd-udevd ; then
        systemd-udevd --debug --daemon 2>/udev.debug
    elif command -v udevd ; then
        udevd --daemon --debug 2>/udev.debug
    fi
    udevadm trigger --action=add --type=subsystems
    udevadm trigger --action=add --type=devices
    udevadm settle
}

function init_bottom(){
    udevadm control --exit
}