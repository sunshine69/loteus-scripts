#!/bin/bash

DISK=$1

echo "move second header to end of disk (update gpt part to use whole disk)"
sgdisk -e $DISK

echo "get last sector"
ENDSECTOR=$(sgdisk -E $DISK)

echo "delete partition 3"
sgdisk -d 3 $DISK

echo "replace with new"
#sgdisk -n 1:4096:$ENDSECTOR -c 1:"Linux" -t 1:8300 $DISK
sgdisk --largest-new=3 -c 3:"Linux" -t 3:8300 $DISK

echo "re-read the partition table entries"
partx -u $DISK

mkdir /tmp/$$

mount ${DISK}3 /tmp/$$
btrfs filesystem resize max /tmp/$$
umount /tmp/$$

rm -rf /tmp/$$

echo "resize the partition using your own tools"
# resize2fs ${DISK}3

