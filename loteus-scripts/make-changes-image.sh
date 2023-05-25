#!/bin/bash

CURRENT_OS=$(cat /proc/cmdline | grep -oP '(?<= os=)[^\s]+')

BOOT_MOUNT=$(grep -A1 'Booting data device:' /var/log/live/livedbg | tail -n1)
CURRENT_CHANGES=$(grep -A1 'Changes are stored in:' /var/log/live/livedbg | tail -n1)

# size in MB
SIZE="${1:-512}"
# generated image name, default is c.img
IMAGE_NAME=${2:-c.img}
FILE_PATH="${BOOT_MOUNT}/${IMAGE_NAME}"

if [ "$( basename $0)" = "make-changes-image-enc.sh" ]; then FILE_ENC=yes; fi

# This is from the initrd image to insure compatibility betwwel LUK VERSION
CRYPTSETUP=$(which cryptsetup)

FILE_NAME=$(basename $FILE_PATH)
DIR_NAME=$(dirname $FILE_PATH)

if [ ! -d $DIR_NAME ]; then
     echo "Directory does not exist. Creating .."
     mkdir -p $DIR_NAME
fi

DEVICE=""

if [ -b "$FILE_PATH" ]; then
    echo "Raw block device detected"
    DEVICE=$FILE_PATH
elif [ ! -f "$FILE_PATH" ]; then
    fallocate -l ${SIZE}M $FILE_PATH
    #dd if=/dev/zero of=$FILE_PATH bs=1M count=$SIZE
fi

if [ -z "$DEVICE" ]; then
    LODEV=`losetup -f`; losetup $LODEV $FILE_PATH
    DEVICE=$LODEV
    USE_LOOP=yes
fi

if [ "$FILE_ENC" = "yes" ]; then
    if [ -z $PASS ]; then read -s -p "Enter Pass: " PASS; fi

    if blkid $DEVICE 2>/dev/null | cut -d" " -f3- | grep -q _LUKS; then
        echo "Detected existing LUKS. Wont run luksFormat again"
    else
        echo "Will set up new LUKS container"
        echo $PASS | $CRYPTSETUP --key-file=- -q luksFormat --type luks1 $DEVICE
    fi
    echo $PASS | $CRYPTSETUP --key-file=- luksOpen $DEVICE ${FILE_NAME}_ENC_$$
    TARGET_DEVICE=/dev/mapper/${FILE_NAME}_ENC_$$
else
    TARGET_DEVICE="$DEVICE"
fi

MKFS="${3:-mkfs.ext4}"
echo "Create file system on it using $MKFS - if you want to customise, set the var MKFS to the path of the make file system command"

$MKFS $TARGET_DEVICE

echo "Mount target device"
mkdir /tmp/mount$$ -p
mount $TARGET_DEVICE /tmp/mount$$
mkdir /tmp/mount$$/${CURRENT_OS}/

DISK_UUID=$(blkid $TARGET_DEVICE | grep -oP '(?<= UUID=)[^\s]+' | sed 's/"//g' | cut -b1-8)
echo "Copy current changes into new one"
rsync -a ${BOOT_MOUNT}/${CURRENT_CHANGES}/ /tmp/mount$$/${CURRENT_OS}/

echo "Backup ${BOOT_MOUNT}/boot/grub/grub.cfg before editing"
cp ${BOOT_MOUNT}/boot/grub/grub.cfg ${BOOT_MOUNT}/boot/grub/grub.cfg.bak

sed -i "s|changes=${CURRENT_CHANGES}|changes=${IMAGE_NAME}/${CURRENT_OS}|g" ${BOOT_MOUNT}/boot/grub/grub.cfg

sync
umount /tmp/mount$$ && rm -rf /tmp/mount$$

if [ "$FILE_ENC" = "yes" ]; then $CRYPTSETUP luksClose ${FILE_NAME}_ENC_$$; fi

if [ "$USE_LOOP" = "yes" ]; then losetup -d $DEVICE; fi

echo "Done!"