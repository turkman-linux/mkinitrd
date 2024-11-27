#!/bin/bash
work=$(mktemp -d)
set -e
set -o pipefail

# help message
show_help() {
    echo "Usage: mkunify [OPTIONS]"
    echo ""
    echo "mkunify creates a unified EFI image for booting a Linux kernel with an"
    echo "initial RAM disk (initrd)."
    echo ""
    echo "Options:"
    echo "  -l <path>    Specify the path to the Linux kernel image"
    echo "                (default: /boot/vmlinuz-$(uname -r))"
    echo "  -i <path>    Specify the path to the initrd image"
    echo "                (default: /boot/initrd.img-$(uname -r))"
    echo "  -c <cmdline> Specify the kernel command line parameters"
    echo "                (default: contents of /proc/cmdline)"
    echo "  -o <path>    Specify the output path for the unified EFI image"
    echo "                 (default:/boot/efi/linux-$(uname -r).unified.efi)"
    echo "  -t <arch>    Specify the target architecture for EFI"
    echo "                 (default: $(uname -m)-efi)"
    echo "  -h, --help       Display this help message and exit."
    echo ""
    echo "Efi Options:"
    echo "  -a           Add generated image to efivars"
    echo "  -e <efidisk> Specify the path to efi disk"
    echo "  -p <partnum> Specify the path to efi disk's partition number"
}

detect_root() {
    # detect running system disk
    root_disk=$(realpath $(cat /proc/mounts | grep " / " | cut -f1 -d" "))
    root_efi_disk=$(realpath $(cat /proc/mounts | grep " /boot/efi " | cut -f1 -d" "))
    root_disk=${root_disk/*\//}
    root_efi_disk=${root_efi_disk/*\//}
    if [ "${root_disk/[0-9]*/}" == "nvme" ] || [ "${root_disk/[0-9]*/}" == "mmcblk" ] ; then
        root_disk=${root_disk/p[0-9]*/}
        root_efi_disk=${root_efi_disk/${root_disk}p/}
    else
        root_disk=${root_disk/[0-9]*/}
        root_efi_disk=${root_efi_disk/${root_disk}/}
    fi
    echo ${root_disk} ${root_efi_disk}
}


# default arguments
linux=/boot/vmlinuz-$(uname -r)
initrd=/boot/initrd.img-$(uname -r)
cmdline="$(cat /proc/cmdline)"
output=/boot/efi/EFI/linux/linux-$(uname -r).unified.efi
target=$(uname -m)-efi

# default arguments about efibootmgr
root_data=$(detect_root)
efi_add="0"
efi_partnum=${root_data/* /}
efi_disk=/dev/${root_data/ */}
unset root_data

# parse arguments
while getopts ":l:i:c:o:t:e:p:a" arg; do
  case $arg in
    o)
      output="$OPTARG"
      ;;
    c)
      cmdline="$OPTARG"
      ;;
    l)
      linux="$OPTARG"
      ;;
    i)
      initrd="$OPTARG"
      ;;
    t)
      target="$OPTARG"
      ;;
    e)
      efi_disk="$OPTARG"
      ;;
    p)
      efi_partnum="$OPTARG"
      ;;
    a)
      efi_add=1
      ;;
    *)
      show_help
      exit 0
      ;;
  esac
done

if [ $(id -u) -ne 0 ] ; then
    echo "You must be root!" > /dev/stderr
    exit 1
fi

if [ ! -d /sys/module/loop ] ; then
    modprobe loop
fi
for cmd in grub-mkimage busybox ; do
    if ! command -v $cmd >/dev/null ; then
        echo "Error: $cmd not found" > /dev/stderr
        exit 2
    fi
done

# copy kernel and initrd
cp $linux $work/linux
cp $initrd $work/initrd

# generate config file
echo "insmod all_video" > $work/grub.cfg
echo "insmod memdisk" >> $work/grub.cfg
echo "insmod fat" >> $work/grub.cfg
echo "insmod linux" >> $work/grub.cfg
echo "set root=(memdisk)" >> $work/grub.cfg
echo "linux /linux $cmdline" >> $work/grub.cfg
echo "initrd /initrd" >> $work/grub.cfg
echo "boot" >> $work/grub.cfg

# calculate required size
size=$(du -b $work | cut -f1)
size=$(expr $size '*' 105 / 100)

# create and format image
echo "Generating: $output"
busybox dd if=/dev/zero of=$work/memdisk.img bs=$size count=1 2>/dev/null
mkfs.vfat $work/memdisk.img

# mount image
mkdir -p $work/memdisk
mount $work/memdisk.img $work/memdisk

# add items to disk image
mkdir -p $work/memdisk/boot/grub
mv $work/linux $work/memdisk
mv $work/initrd $work/memdisk
mv $work/grub.cfg $work/memdisk/boot/grub/grub.cfg

# sync and umount image
sync
umount $work/memdisk

# create unified image
mkdir -p $(dirname ${output})
grub-mkimage -m $work/memdisk.img -C none -O "$target" -o "$output" all_video memdisk fat normal linux

# cleanup
rm -rf $work

# efibootmgr
if [ "${efi_add}" != "1" ] ; then
    exit 0
fi
if ! command -v efibootmgr >/dev/null ; then
    echo "Error: efibootmgr not found" >/dev/stderr
    exit 1
fi
if ! [ -b "${efi_disk}" ] ; then
    echo "You must specify an efi device using '-e </dev/xxx>'" >/dev/stderr
    exit 1
fi
if [ "${efi_partnum}" == "" ] ; then
    echo "You must specify an efi part number using '-p <partnum>'" >/dev/stderr
    exit 1
fi


entry_path=$(echo ${output/\/boot\/efi/} | tr '/' '\\')
echo "Adding efivar: ${output/*\//} => ${entry_path}"
efibootmgr | grep -e "${output/*\//}" | while read line ; do
    num=$(echo $line | cut -d' ' -f1)
    num=${num/Boot/}
    efibootmgr -B -b ${num/'*'/} >/dev/null
done
efibootmgr -c -d ${efi_disk} -p ${efi_partnum} -L ${output/*\//} -l ${entry_path} >/dev/null
