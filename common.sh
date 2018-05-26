#!/bin/bash

[ -z "$TARGET_DIR" ] && TARGET_DIR=/mnt/sda4/build/kernel-binary

BZIMAGE=$(find /mnt/sd*/ -maxdepth 2 -type f -name bzImage)
PORT_DIR=$(dirname `losetup -a|grep 000|awk '{print $3}'|cut -d'(' -f2`)
BOOT_DIR=$(dirname $BZIMAGE)
if [ -f "$BOOT_DIR/syslinux/bzImage" ]; then BOOT_DIR="$BOOT_DIR/syslinux"; fi

[ -z "$PROMPT" ] && PROMPT=y

echo "TARGET_DIR=$TARGET_DIR BZIMAGE $BZIMAGE PORT_DIR $PORT_DIR BOOT_DIR $BOOT_DIR"
