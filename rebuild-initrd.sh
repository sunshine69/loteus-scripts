#!/bin/bash

CWD="$(pwd)"

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
. $SCRIPT_DIR/common.sh

if [ -z "$1" ]; then
    INF=$BOOT_DIR/initrd.xz
else
    INF=$1
fi

if [ -z "$2" ]; then
    OUT=$INF
else
    OUT=$2
fi

[ ! -f "$INF" ] && echo "Input file $INF does not exist" && exit 1

mkdir /tmp/initrd_$$ && cd /tmp/initrd_$$

xzcat $INF | cpio -id
cp -a $SCRIPT_DIR/linuxrc .
echo "Copy modules in - /tmp/initrd_$$/lib/modules/ if needed and then type kernel version in"
echo "Enter kernel version: "
read KVER

if [ ! -z "$KVER" ]; then
    if [ -z "$KBUILDDIR" ]; then
        KBUILDDIR=$TARGET_DIR/kernel-$KVER
        # Install xzm modules
        $TARGET_DIR/porteus-kernel-$KVER.tar.sfx
        KBUILDDIR="$PORT_DIR"
    fi
    DESTDIR="/tmp/initrd_$$/lib/modules/$KVER" ; rm -rf $DESTDIR; mkdir -p $DESTDIR
    mkdir $KBUILDDIR/1 ; mount -o loop $KBUILDDIR/000-$KVER.xzm $KBUILDDIR/1
    SRCDIR="$KBUILDDIR/1/lib/modules/$KVER/kernel"
    cp -a $SRCDIR/{crypto,lib} $DESTDIR/
    cp -a $SRCDIR/drivers/{hid,ata,block,acpi,crypto,md,memstick,mmc} $DESTDIR/
    cp -a $SRCDIR/drivers/hwmon/applesmc.ko $SRCDIR/drivers/input/input-polldev.ko $DESTDIR/
    cp -a $SRCDIR/fs/{jfs,reiserfs,xfs,aufs,btrfs,f2fs,fat,isofs,nls,overlayfs,udf,ufs,binfmt_misc.ko} $DESTDIR/
    depmod $KVER -b .
    umount $KBUILDDIR/1; rm -rf $KBUILDDIR/1
fi

mc /tmp/initrd_$$/lib/modules/
if [ -z "$KVER" ]; then
    echo "Enter kernel version: "
    read KVER
fi
[ "$KVER" ] && depmod $KVER -b .

echo "Building ..."

mv $OUT ${OUT}.bak
find . | cpio --quiet -o -H newc | lzma -7 > $OUT

cd $CWD
echo "Output file $OUT"
rm -rf /tmp/initrd_$$

if [ ! -z "$KVER" ]; then
   cp $TARGET_DIR/porteus-kernel-$KVER.tar.sfx /mnt/doc/tmp/
fi
