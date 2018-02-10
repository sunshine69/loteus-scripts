#!/bin/bash

TARGET_DIR=/mnt/sda4/build/kernel-binary

BZIMAGE=$(find /mnt/sd*/ -maxdepth 2 -type f -name bzImage)
PORT_DIR=$(dirname `losetup -a|grep 000|awk '{print $3}'|cut -d'(' -f2`)
BOOT_DIR=$(dirname $BZIMAGE)
