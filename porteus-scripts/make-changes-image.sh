#!/bin/bash

FILE_PATH="$1"
SIZE="${2:-512}"

if [ ! -f $(dirname $FILE_PATH) ]; then
     echo "Directory does not exist"
     exit 1
fi

OS_DIR=$(losetup -a | grep -Po '[^\/]+(?=\/base\/001)')
if [ -z "$OS_DIR" ]; then
    echo "Not running in a porteus env as we can not detect OS_DIR. Abort."
    exit 1
fi

echo "Going to create an image $FILE_PATH with size $SIZE"
dd if=/dev/zero of=$FILE_PATH bs=1M count $SIZE
echo "Create ext4 file system on it"

MKFS="${3:-mkfs.ext4}"
$MKFS $FILE_PATH
echo "Mount it under /tmp/$$"
mkdir /tmp/$$
mount -o loop $FILE_PATH /tmp/$$
echo "Make changes directory"
mkdir -p /tmp/$$/${OS_DIR}
echo "Umount"
umount /tmp/$$
echo "Done!"
