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

which vboxconfig
if [ ! $? = 0 ]; then
	VBOX_VER=$(dpkg -s virtualbox | grep -i version | awk '{print $2}'|awk -F- '{print $1}')
	#cd /usr/src/virtualbox-6.1.34/
	#make; make install
	echo "Run dkms autoinstall"
	dkms remove virtualbox/$VBOX_VER --all
	dkms add virtualbox/$VBOX_VER
	dkms autoinstall
else 
	vboxconfig
fi
pushd .
#cd /mnt/portdata/tmp/Linux-Magic-Trackpad-2-Driver/linux/drivers/hid/ && make clean && make && cp hid-magicmouse.ko /lib/modules/${KVER}/misc/
cd /mnt/portdata/tmp/bcwc_pcie/ && make clean && make && make install

echo "remember to run build-extra-kmod2.sh as well after compression"
