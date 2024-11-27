work=$(mktemp -d)
set -e
set -o pipefail

# default arguments
linux=/boot/vmlinuz-$(uname -r)
initrd=/boot/initrd.img-$(uname -r)
cmdline="$(cat /proc/cmdline)"
output=/boot/efi/linux-$(uname -r).unified.efi
target=$(uname -m)-efi

# default arguments about efibootmgr
efi_add=0
efi_disk=""

# help message
function show_help {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Mkunitf creates a unified EFI image for booting a Linux kernel with an initial RAM disk (initrd)."
    echo ""
    echo "Options:"
    echo "  -l <path>    Specify the path to the Linux kernel image (default: /boot/vmlinuz-$(uname -r))"
    echo "  -i <path>    Specify the path to the initrd image (default: /boot/initrd.img-$(uname -r))"
    echo "  -c <cmdline> Specify the kernel command line parameters (default: contents of /proc/cmdline)"
    echo "  -o <path>    Specify the output path for the unified EFI image (default: /boot/efi/linux-$(uname -r).unified.efi)"
    echo "  -t <arch>    Specify the target architecture for EFI (default: $(uname -m)-efi)"
    echo "  -h           Display this help message and exit"
    echo ""
    echo "Efi Options:"
    echo "  -a           Add generated image to efivars"
    echo "  -e <efidisk> Specify the path to efi disk"
    echo "  -p <partnum> Specify the path to efi disks partition number"

}

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
    module loop
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
echo "linux /linux" >> $work/grub.cfg
echo "initrd /initrd $cmdline" >> $work/grub.cfg
echo "boot" >> $work/grub.cfg

# calculate required size
size=$(du -b $work | cut -f1)
size=$(expr $size '*' 105 / 100)

# create and format image
echo "Generating: $output"
busybox dd if=/dev/zero of=$work/memdisk.img bs=$size count=1 2>/dev/null
busybox mkfs.vfat $work/memdisk.img

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
grub-mkimage -m $work/memdisk.img -C none -p / -O "$target" -o "$output" all_video memdisk fat normal linux

# cleanup
rm -rf $work

# efibootmgr
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
set +o pipefail
efibootmgr | grep -e "/${entry_path/\\/\\\\}" | while read line ; do
    num=$(echo $line | cut -d' ' -f1)
    num=${num/Boot/}
    efibootmgr -B -b ${num/'*'/} >/dev/null
done
efibootmgr -c -d ${efi_disk} -p ${efi_partnum} -L ${output/*\//} -l ${entry_path} >/dev/null
