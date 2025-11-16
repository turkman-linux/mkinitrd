init_top(){
    : empty
}

init_bottom(){
    # generate read only empty file
    > /dev/empty
    mount --bind -o ro  /dev/empty /dev/empty
    # hide cpuinfo
    mount --bind -o ro /dev/empty /proc/cpuinfo
    mount -t tmpfs -o ro tmpfs /sys/bus/cpu
    # hide hardware info
    mount -t tmpfs -o ro tmpfs /sys/class/dmi
    mount -t tmpfs -o ro tmpfs /sys/devices/virtual/dmi
}
