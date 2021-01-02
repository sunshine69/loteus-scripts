#!/bin/sh
# $0 <device name> <optional - addition Luks option like --header headerfilename>
if [ -f "$1" ]; then
    LODEV=$(losetup -f)
    losetup $LODEV $1
    DEV=$LODEV
else
    DEV=$(echo $1 | sed 's/\/dev\///')
    shift
fi
set -x
if [ -z "$PASSPHRASE" ]; then
    echo "**** "
    read -s PASSPHRASE
    if [ "$?" != "0" ]; then
        echo "type pass, it will be displayed on the screen"
        read PASSPHRASE
    fi
fi

# Only raw plain or Bitlocker handled. Normal cryptsetup is in linuxrc already
TYPE=$(blkid /dev/$DEV 2>/dev/null | egrep -o ' TYPE=[^ ]+' | cut -d'"' -f2)

if [ "$TYPE" = "BitLocker" ]; then
    mkdir /mnt/blk /mnt/blkm >/dev/null 2>&1
    dislocker /dev/$DEV -p$PASSPHRASE -- /mnt/blk
    ntfs-3g /mnt/blk/dislocker-file /mnt/blkm
    echo /mnt/blkm
elif [ "$TYPE" = "crypto_LUKS" ] || [ "${FORCE_LUKS}" = "y" ]; then
    echo $PASSPHRASE | cryptsetup --key-file=- luksOpen /dev/$DEV ${DEV}_DEC $*
    echo "/dev/mapper/${DEV}_DEC"
else
    echo $PASSPHRASE | cryptsetup --key-file=- plainOpen /dev/$DEV ${DEV}_DEC $*
    echo "/dev/mapper/${DEV}_DEC"
fi
