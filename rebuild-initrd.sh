#!/bin/bash

echo "Start rebuild initrd.xz"

CWD="$(pwd)"

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
. $SCRIPT_DIR/common.sh


if [ -z "$1" ]; then
    INF=$BOOT_DIR/initrd.xz
else
    INF=$1
    echo "Input: '$1'"
fi

if [ -z "$2" ]; then
    OUT=$INF
else
    OUT=$2
fi

[ ! -f "$INF" ] && echo "Origin initrd.xz as input file $INF does not exist. Aborting..." && exit 1

mkdir /tmp/initrd_$$
cd /tmp/initrd_$$

xzcat $INF | cpio -id
cp -a $SCRIPT_DIR/linuxrc .

echo "Copy modules into - /tmp/initrd_$$/lib/modules/ if needed and then type kernel version in"

if [ -z "$KVERS" ]; then
    echo "Enter kernel version (space separated for a list): "
    read KVERS
else
    echo "Kernel version from KVERS: $KVERS"
fi

if [ ! -z "$KVERS" ]; then
    for KVER in $KVERS; do
        KBUILDDIR=""
        SRCDIR=""
        DESTDIR="/tmp/initrd_$$/lib/modules/$KVER" ; rm -rf $DESTDIR; mkdir -p $DESTDIR

        if [ -z "$KBUILDDIR_ENV" ]; then
            #Install xzm modules
            ( cd $CWD ; $TARGET_DIR/porteus-kernel-$KVER.tar.sfx )
            KBUILDDIR="$CWD/porteus-kernel"
        else
            KBUILDDIR=$KBUILDDIR_ENV
        fi

        if [ -z "$SRCDIR_ENV" ]; then
            mkdir $KBUILDDIR/1 ; mount -o loop $KBUILDDIR/000-$KVER.xzm $KBUILDDIR/1
            SRCDIR="$KBUILDDIR/1/lib/modules/$KVER/kernel"
        else
            SRCDIR=$SRCDIR_ENV
        fi

        echo Clean up old modules
        rm -rf /tmp/initrd_$$/lib/modules/*
        echo Copy some modules over
        mkdir -p $DESTDIR
        cp -a $SRCDIR/{crypto,lib} $DESTDIR/
        cp -a $SRCDIR/drivers/{hid,ata,block,acpi,crypto,md,memstick,mmc} $DESTDIR/
        cp -a $SRCDIR/drivers/hwmon/applesmc.ko $SRCDIR/drivers/input/input-polldev.ko $DESTDIR/
        cp -a $SRCDIR/fs/{jfs,reiserfs,xfs,aufs,btrfs,f2fs,fat,isofs,nls,overlayfs,udf,ufs,binfmt_misc.ko} $DESTDIR/
        depmod $KVER -b .
        umount $KBUILDDIR/1; rm -rf $KBUILDDIR/1
        if [ -d "$CWD/porteus-kernel" ]; then rm -rf "$CWD/porteus-kernel"; fi
    done
fi

echo "Building ..."

mv $OUT ${OUT}.bak
echo "Kernel modules file list"
find ./lib/modules/
find . | cpio --quiet -o -H newc | lzma -7 > $OUT

cd $CWD
echo "Output file $OUT"
rm -rf /tmp/initrd_$$

if [ ! -z "$KVER" ]; then
   cp $TARGET_DIR/porteus-kernel-$KVER.tar.sfx /mnt/doc/tmp/
fi
