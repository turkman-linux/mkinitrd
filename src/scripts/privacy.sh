init_top(){
    : empty
}

init_bottom(){
    # hide hardware info
    mount -t tmpfs -o ro tmpfs /sys/class/dmi
    mount -t tmpfs -o ro tmpfs /sys/devices/virtual/dmi
}
