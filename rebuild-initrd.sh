#!/bin/bash -x

echo "Start rebuild initrd.xz"

SYSTEM_PRODUCT_NAME=$(dmidecode -s 'system-product-name')

CWD="$(pwd)"

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
. $SCRIPT_DIR/common.sh


if [ -z "$1" ]; then
    INF=$BOOT_DIR/initrd.xz
else
    INF=$(readlink -f $1)
    echo "Input: '$INF'"
fi

if [ -z "$2" ]; then
    OUT=$INF
else
    OUT=$(readlink -f $2)
fi


if [ ! -f "$INF" ]; then
    INF=$SCRIPT_DIR/initrd-template.xz
    if [ ! -f $INF ]; then
        INF=$(find /mnt/*/build/kernel-binary/initrd-template.xz /mnt/doc/opc-backup/initrd-template.xz 2>/dev/null | head -n1)
    fi
    if [ -z "$INF" ]; then echo "Enter path to initrd: "; read INF ; fi
    if [ ! -f $INF ]; then
        echo "Origin initrd.xz as input file $INF does not exist. Aborting..."
        exit 1
    fi
fi

mkdir /tmp/initrd_$$
cd /tmp/initrd_$$

xzcat $INF | cpio -id
#zcat $INF | cpio -id

LINUXRC_FILE="linuxrc"
#if [ "$SYSTEM_PRODUCT_NAME" = "MacBookPro15,1" ]; then
#    echo "SYSTEM_PRODUCT_NAME MacBookPro15,1 detected. WILL USE linuxrc.mpb2018. IT MAY CRASH. If it is say no here"
#    echo "Use macbookpro 2018 linuxrc? y/n"
#    read _ans
#    if [ "$_ans" = "y" ]; then
#        LINUXRC_FILE="linuxrc.mpb2018"
#    fi
#fi
cp -a $SCRIPT_DIR/${LINUXRC_FILE} .

echo "Copy modules into - /tmp/initrd_$$/lib/modules/ if needed and then type kernel version in"

if [ -z "$KVERS" ]; then
    echo "Enter kernel version (space separated for a list): Hit enter to use the current running version `uname -r`"
    read KVERS
    [ -z "$KVERS" ] && KVERS=$(uname -r)
else
    echo "Kernel version from KVERS: $KVERS"
fi

TEMP_KDIR=/tmp/tempkdir$$
mkdir -p $TEMP_KDIR >/dev/null 2>&1

if [ ! -z "$KVERS" ]; then
    for KVER in $KVERS; do
        KBUILDDIR=""
        SRCDIR=""
        DESTDIR="/tmp/initrd_$$/lib/modules/$KVER" ; rm -rf $DESTDIR; mkdir -p $DESTDIR

        if [ -z "$KBUILDDIR_ENV" ]; then
            #Install xzm modules
            ( cd $TEMP_KDIR ; echo n | $TARGET_DIR/porteus-kernel-$KVER.tar.sfx )
            KBUILDDIR="$TEMP_KDIR/porteus-kernel"
        else
            KBUILDDIR=$KBUILDDIR_ENV
        fi

        if [ -z "$SRCDIR_ENV" ]; then
            if [ -f $KBUILDDIR/000-$KVER.xzm ]; then
                mkdir $KBUILDDIR/1 ; mount -o loop $KBUILDDIR/000-$KVER.xzm $KBUILDDIR/1
                SRCDIR="$KBUILDDIR/1/lib/modules/$KVER/kernel"
            else
                if [ -d /lib/modules/$KVER ]; then
                    SRCDIR=/lib/modules/${KVER}/kernel
                else
                    echo "Can not auto parse the kernel module dir. Enter it here: "
                    read _kmoddir
                    if [ ! -z "$_kmoddir" ]; then
                        SRCDIR=$_kmoddir/kernel
                    else
                        echo "empty answer, aborting"
                        exit 1
                    fi
                fi
            fi
        else
            SRCDIR=$SRCDIR_ENV
        fi

        echo Clean up old modules
        rm -rf /tmp/initrd_$$/lib/modules/*
        echo Copy some modules over
        mkdir -p $DESTDIR
        cp -a $SRCDIR/{crypto,lib} $DESTDIR/
        mkdir -p $DESTDIR/arch/x86 $DESTDIR/drivers $DESTDIR/fs/ $DESTDIR/drivers/platform $DESTDIR/drivers/staging $DESTDIR/drivers/hwmon/
        cp -a $SRCDIR/arch/x86/crypto $DESTDIR/arch/x86/
        cp -a $SRCDIR/drivers/staging/{apple-bce,apple-ibridge} $DESTDIR/drivers/staging/

        cp -a $SRCDIR/drivers/{input,hid,ata,block,acpi,crypto,md,memstick,mmc,cdrom,scsi,macintosh,usb,thunderbolt,nvme} $DESTDIR/drivers/
        cp -a $SRCDIR/drivers/hwmon/applesmc.ko $DESTDIR/drivers/hwmon/
        cp -a $SRCDIR/drivers/platform/x86 $DESTDIR/drivers/platform/
        cp -a $SRCDIR/sound $DESTDIR/
        cp -a $SRCDIR/fs/{ntfs3,jfs,reiserfs,xfs,f2fs,fat,isofs,nls,overlayfs,udf,ufs,binfmt_misc,btrfs} $DESTDIR/fs/
        mkdir $DESTDIR/kernel/crypto -p
        cp -a $SRCDIR/kernel/crypto/{algif_skcipher.ko,af_alg.ko} $DESTDIR/kernel/crypto/
        cp -a $SRCDIR/misc $DESTDIR/
        #cp -a $SRCDIR/misc/vboxvideo $DESTDIR/ || true
        depmod $KVER -b .
        echo "Done copying modules over"
        echo "update helper scripts"
        for sname in setup-disk.sh go-setup.sh swapcrypt.sh; do
            cp -a ${SCRIPT_DIR}/porteus-scripts/${sname} /tmp/initrd_$$/bin/
        done
        echo "Going to unmount and clean up ..."
        umount $KBUILDDIR/1
        sleep 3 # avoid race condition
        rm -rf $KBUILDDIR/1 $TEMP_KDIR
    done
fi

echo "Get into the new initrd root dir /tmp/initrd_$$ and modify things if u need. Then hit enter to build"
#read _junk

echo "Building ..."

[ -f $OUT ] && mv $OUT ${OUT}.bak
echo "Kernel modules file list"
find ./lib/modules/
#if $(which pixz >/dev/null 2>&1); then COMP_CMD=pixz; else COMP_CMD=pigz; fi
COMP_CMD='lzma -9'
find . | cpio --quiet -o -H newc | $COMP_CMD > $OUT

cd $CWD
echo "Output file $OUT"
rm -rf /tmp/initrd_$$

#if [ ! -z "$KVER" ]; then
#   cp $TARGET_DIR/porteus-kernel-$KVER.tar.sfx /mnt/doc/opc-backup/
#fi
