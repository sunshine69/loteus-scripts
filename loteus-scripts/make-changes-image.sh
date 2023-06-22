#!/bin/bash

CURRENT_OS=$(cat /proc/cmdline | grep -oP '(?<= os=)[^\s]+')

BOOT_MOUNT=${BOOT_MOUNT:-$(grep -A1 'Booting data device:' /var/log/live/livedbg | tail -n1)}
CURRENT_CHANGES=$(grep -A1 'Changes are stored in:' /var/log/live/livedbg | tail -n1)

# size in MB
SIZE="${1:-512}"
# generated image name, default is c.img
FILE_PATH=${2:-${BOOT_MOUNT}/c.img}
IMAGE_NAME=$(basename $FILE_PATH)

if [ "$( basename $0)" = "make-changes-image-enc.sh" ]; then FILE_ENC=yes; fi

# This is from the initrd image to insure compatibility betwwel LUK VERSION
CRYPTSETUP=$(which cryptsetup)

DIR_NAME="$(dirname $FILE_PATH)"

if [ ! -d $DIR_NAME ]; then
     echo "Directory does not exist. Creating .."
     mkdir -p $DIR_NAME
fi

echo "INFO FILE_PATH: $FILE_PATH | DIR_NAME: $DIR_NAME | SIZE: $SIZE | MKFS: $MKFS | BOOT_MOUNT: $BOOT_MOUNT CURRENT_CHANGES: $CURRENT_CHANGES"

DEVICE=""

if [ -b "$FILE_PATH" ]; then
    echo "Raw block device detected"
    DEVICE=$FILE_PATH
elif [ ! -f "$FILE_PATH" ]; then
    truncate -s 0 $FILE_PATH
    file_system=$(df -P "$FILE_PATH" | awk 'NR==2{print $1}')
    file_system_type=$(blkid -s TYPE -o value $file_system)
    if [ "$file_system_type" = "btrfs" ]; then
        echo "btrfs fs detected. Will disable COW"
        chattr +C $FILE_PATH
        fallocate -l ${SIZE}M $FILE_PATH
    else
        fallocate -l ${SIZE}M $FILE_PATH
    fi
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
    echo $PASS | $CRYPTSETUP --key-file=- luksOpen $DEVICE ${IMAGE_NAME}_ENC_$$
    TARGET_DEVICE=/dev/mapper/${IMAGE_NAME}_ENC_$$
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
CHANGES_DEV=$(df /mnt/live/memory/changes | tail -n1 | awk '{print $1}')
CHANGES_MOUNT=$(df $CHANGES_DEV | tail -n1 | awk '{print $NF}')
if [ "$CHANGES_MOUNT" = "/mnt/live/memory/changes" ]; then
    echo "Detect that we have changes as loop file"
    rsync -a ${CHANGES_MOUNT}/ /tmp/mount$$/${CURRENT_OS}/
else
    rsync -a ${CHANGES_MOUNT}/${CURRENT_CHANGES}/ /tmp/mount$$/${CURRENT_OS}/
fi

echo "Backup ${BOOT_MOUNT}/boot/grub/grub.cfg before editing"
cp ${BOOT_MOUNT}/boot/grub/grub.cfg ${BOOT_MOUNT}/boot/grub/grub.cfg.bak

sed -i "s|changes=${CURRENT_CHANGES}|changes=${IMAGE_NAME}/${CURRENT_OS}|g" ${BOOT_MOUNT}/boot/grub/grub.cfg

sync
umount /tmp/mount$$ && rm -rf /tmp/mount$$

if [ "$FILE_ENC" = "yes" ]; then $CRYPTSETUP luksClose ${IMAGE_NAME}_ENC_$$; fi

if [ "$USE_LOOP" = "yes" ]; then losetup -d $DEVICE; fi

echo "Done!"
