#!/bin/sh
copy_binary busybox
cat /etc/os-release > $work/etc/os-release
copy_modules hid_generic psmouse usbhid atkbd evdev