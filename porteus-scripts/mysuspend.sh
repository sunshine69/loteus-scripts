#!/bin/bash
if [ "`whoami`" != 'root' ]; then
/usr/bin/sudo $0
exit 0
fi
umount /data /mnt/data /mnt/archive
#dbus-send --system --print-reply --dest="org.freedesktop.UPower"  /org/freedesktop/UPower org.freedesktop.UPower.Suspend
/usr/sbin/pm-suspend
for i in {0..7}; do echo 0 > /sys/class/thermal/cooling_device$i/cur_state; done
