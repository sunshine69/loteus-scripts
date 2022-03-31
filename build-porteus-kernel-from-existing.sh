#!/bin/bash

if [ "$(id -u)" != "0" ]; then
    exec sudo -E $0 $*
fi

export SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

if [ -z "$KVER" ]; then 
    echo "KVER is not set. You need to tell me which kernel version to build."
    echo "Kernel version to build: $(uname -r)"
    read KVER ; [ -z "$KVER" ] && KVER=$(uname -r)
    if [ ! -d /lib/modules/$KVER ]; then 
        echo "K modules not detected at /lib/modules/$KVER. Where is the directory? "
        read KMOD_DIR
    else 
        KMOD_DIR=/lib/modules/$KVER
    fi 
    if [ ! -d /usr/src/linux-headers-$KVER ]; then
        echo "K header is not at /usr/src/linux-headers-$KVER. Where is the k source dir? "
        read KHEADER_DIR
    else
        KHEADER_DIR=/usr/src/linux-headers-$KVER
    fi 
    if [ ! -f /boot/vmlinuz-$KVER ]; then
        echo "K image vmlinuz-$KVER is not found in /boot. Where is it? "
        read KIMAGE_PATH
    else
        KIMAGE_PATH=/boot/vmlinuz-$KVER
    fi
fi 

[ -z "$WORK_DIR" ] && WORK_DIR=/tmp/build-porteus-kernel-$$

mkdir -p $WORK_DIR/porteus-kernel >/dev/null 2>&1

pushd .
cd $WORK_DIR
mkdir -p kmod/lib/modules/$KVER
mount -o bind $KMOD_DIR kmod/lib/modules/$KVER
mksquashfs kmod porteus-kernel/000-$KVER.xzm -comp xz -b 1M
umount kmod/lib/modules/$KVER
rm -rf kmod
(cd $KHEADER_DIR/../ && mksquashfs $KHEADER_DIR $WORK_DIR/porteus-kernel/000-linux-src-$KVER.xzm -comp xz -b 1M )
cp -a $KIMAGE_PATH $WORK_DIR/porteus-kernel/bzImage 
KVERS=$KVER $SCRIPT_DIR/rebuild-initrd.sh $WORK_DIR/porteus-kernel/initrd.xz
cp $SCRIPT_DIR/common.sh $SCRIPT_DIR/porteus-install-kernel.sh $WORK_DIR/porteus-kernel/
$SCRIPT_DIR/porteus-scripts/repack-porteus-kernel.sh porteus-kernel-$KVER.tar.sfx
popd
mv $WORK_DIR/porteus-kernel-$KVER.tar.sfx .
# rm -rf $WORK_DIR
chmod +x porteus-kernel-$KVER.tar.sfx
echo "Output file is porteus-kernel-$KVER.tar.sfx"

