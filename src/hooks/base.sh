#!/bin/sh
copy_modules hid_generic psmouse usbhid atkbd evdev
cat /etc/os-release > $work/etc/os-release
cat /etc/group > $work/etc/group
