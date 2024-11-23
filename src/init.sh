#!/bin/busybox sh
/bin/busybox --list | /bin/busybox grep -v busybox | while read line ; do
    if ! [ -f /bin/$line ] ; then
        /bin/busybox ln -s busybox /bin/$line
    fi
done
echo -ne "\033c"
set +e
distro=$(/bin/busybox ash -c 'source /etc/os-release ; echo $NAME')
kernel=$(/bin/busybox uname -r)
arch=$(/bin/busybox uname -m)
set -e
echo -e "Booting \033[32;1m$distro $kernel\033[;0m ($arch)\n"
# create system dirs
/bin/busybox mkdir -p /dev /sys /proc
# mount system dirs
/bin/busybox mount -t devtmpfs devtmpfs /dev || :
/bin/busybox mount -t sysfs sysfs /sys || :
/bin/busybox mount -t proc proc /proc || :
# define environments
export PATH="/bin"
export init=/sbin/init
# parse cmdline
for arg in $(/bin/busybox cat /proc/cmdline) ; do
    if [[ "$arg" == *"="* ]]; then
        name="${arg%%=*}"
        name_length=${#name}
        value="${arg:name_length+1}"
        export "$name=$value"
fi
done
# create shell futcion
function create_shell(){
    echo "Boot failed! Creating debug shell as PID: 1"
    exec >/dev/console
    exec 2>/dev/console
    exec </dev/console
    exec /bin/busybox ash
}
# mount  rootfs function
function mountroot() {
    if [ ! -d /rootfs ] ; then
        /bin/busybox mkdir -p /rootfs
        if echo $root | grep -e "^UUID=" ; then
            uuid="${root#*UUID=}"
            root="/dev/disk/by-uuid/$uuid"
        fi
        /bin/busybox mount "$root" -o rw /rootfs
    fi
}
# run scripts (init top)
if [ -d /scripts ] ; then
    for file in $(/bin/busybox ls /scripts | /bin/busybox sort) ; do
        echo -e "\033[32;1mRunning:\033[;0m$file"
        /bin/busybox ash -c "source /scripts/$file ; init_top" || create_shell
    done
fi
# mount rootfs
mountroot || create_shell
# run scripts (init top)
if [ -d /scripts ] ; then
    for file in $(/bin/busybox ls /scripts | /bin/busybox sort) ; do
        echo -e "\033[32;1mRunning:\033[;0m$file"
        /bin/busybox ash -c "source /scripts/$file ; init_bottom" || create_shell
    done
fi
# switch root
if [ ! -d /rootfs ] ; then
    create_shell
fi
for dir in dev sys proc ; do
    /bin/busybox mount --move /$dir /rootfs/$dir
done
exec /bin/busybox env -i TERM="$TERM" /bin/busybox \
    switch_root /rootfs $init || create_shell
