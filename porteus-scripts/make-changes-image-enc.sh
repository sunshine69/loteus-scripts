#!/bin/bash

FILE_PATH="$1"
SIZE="${2:-512}"

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
        echo $PASS | md5sum | cut -f1 -d' ' | $CRYPTSETUP --key-file=- -q luksFormat --type luks1 $DEVICE
    fi
    echo $PASS | md5sum | cut -f1 -d' ' | $CRYPTSETUP --key-file=- luksOpen $DEVICE ${FILE_NAME}_ENC_$$
    TARGET_DEVICE=/dev/mapper/${FILE_NAME}_ENC_$$
else
    TARGET_DEVICE="$DEVICE"
fi

echo "Create ext4 file system on it"

MKFS="${3:-mkfs.ext4}"

$MKFS $TARGET_DEVICE

if [ "$FILE_ENC" = "yes" ]; then $CRYPTSETUP luksClose ${FILE_NAME}_ENC_$$; fi

if [ "$USE_LOOP" = "yes" ]; then losetup -d $DEVICE; fi

echo "Done!"
