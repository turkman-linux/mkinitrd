function init_top(){
    mkdir -p /run/udev
    if command -v systemd-udevd >/dev/null ; then
        echo "Systemd-udevd detected!"
        echo "Your system may not working good!"
        systemd-udevd --debug --daemon 2>/udev.debug
    elif command -v udevd > /dev/null ; then
        udevd --daemon --debug 2>/udev.debug
    fi
    udevadm trigger --action=add --type=subsystems
    udevadm trigger --action=add --type=devices
    udevadm settle
}

function init_bottom(){
    udevadm control --exit
}