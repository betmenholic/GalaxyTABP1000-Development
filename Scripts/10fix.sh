#!/system/bin/sh

busybox mount -o remount,rw /
find /sbin -maxdepth 1 -type l -exec rm {} \;
busybox mount -o remount,ro /