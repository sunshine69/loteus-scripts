#!/bin/bash

[ -z "$TARGET_DIR" ] && TARGET_DIR=/mnt/portdata/build/kernel-binary

BZIMAGE_PATH=$(cat /proc/cmdline | grep -oP '(?<=BOOT_IMAGE=)[^\s]+(?=.*)')
BZIMAGE_NAME=$(basename $BZIMAGE_PATH)
BZIMAGE_DIR=$(dirname $BZIMAGE_PATH)

export BZIMAGE_FULL_PATH=$(find /mnt/sd*/${BZIMAGE_DIR}/ -maxdepth 2 -type f -name ${BZIMAGE_NAME})
export PORT_DIR=$(dirname `losetup -a|grep 000|awk '{print $3}'|cut -d'(' -f2`)
export BOOT_DIR=$(dirname $BZIMAGE_FULL_PATH)

[ -z "$PROMPT" ] && PROMPT=y

echo "TARGET_DIR=$TARGET_DIR PORT_DIR $PORT_DIR BOOT_DIR $BOOT_DIR"
