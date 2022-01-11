#!/bin/bash


mount -o bind lib/modules/$KVER /lib/modules/$KVER
[ ! -d /usr/src/linux-headers-$KVER ] && mkdir /usr/src/linux-headers-$KVER

if [ -f "${FROM_DIR}/000-linux-src-${KVER}.xzm" ]; then
    echo mount -o loop ${FROM_DIR}/000-linux-src-${KVER}.xzm /usr/src/linux-headers-$KVER
    mount -o loop ${FROM_DIR}/000-linux-src-${KVER}.xzm /usr/src/linux-headers-$KVER
else
    if [ ! -z "$KHEADER_MOD" ]; then
        mount -o loop $KHEADER_MOD /usr/src/linux-headers-$KVER
    else
        echo "No kernel mod file found and var KHEADER_MOD not set, can not mount header. Aborting"
        exit 1
    fi
fi

vboxconfig
pushd .
cd /mnt/nvme0n1p3/tmp/Linux-Magic-Trackpad-2-Driver/linux/drivers/hid/ && make clean && make && cp hid-magicmouse.ko /lib/modules/${KVER}/misc/
cd /mnt/nvme0n1p3/tmp/bcwc_pcie/ && make clean && make && make install

echo "remember to run build-extra-kmod2.sh as well after compression"
