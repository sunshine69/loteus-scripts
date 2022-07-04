#!/bin/bash


BZIMAGE_PATH=$(cat /proc/cmdline | grep -oP '(?<=BOOT_IMAGE=)[^\s]+(?=.*)')
BZIMAGE_NAME=$(basename $BZIMAGE_PATH)
BZIMAGE_DIR=$(dirname $BZIMAGE_PATH)

if [ -z "$BZIMAGE_FULL_PATH" ]; then
	if ! `touch ${BZIMAGE_DIR}/test-file >/dev/null 2>&1`; then
	    echo "${BZIMAGE_DIR} is not writable. Looks like we boot from cdrom. Will use hardcoded path from portdata"
	    export BZIMAGE_FULL_PATH=/mnt/sr0/${BZIMAGE_NAME}
	    #export PORT_DIR=/mnt/portdata/port
	    #export BOOT_DIR=/mnt/portdata/boot
	else
	    export BZIMAGE_FULL_PATH=$(find /mnt/nvme*/${BZIMAGE_DIR}/ /mnt/sd*/${BZIMAGE_DIR}/ -maxdepth 2 -type f -name ${BZIMAGE_NAME}|head -n1)
	fi
fi
export PORT_DIR=$(dirname `losetup -a|grep -P '000\-[\d\.]+'|awk '{print $3}'|cut -d'(' -f2` | head -n1)
export BOOT_DIR=$(dirname $BZIMAGE_FULL_PATH)

[ -z "$PROMPT" ] && PROMPT=y

# [ -z "$TARGET_DIR" ] && TARGET_DIR=$(dirname $PORT_DIR)/build/kernel-binary
[ -z "$TARGET_DIR" ] && TARGET_DIR=/mnt/portdata/build/kernel-binary

echo "TARGET_DIR=$TARGET_DIR PORT_DIR $PORT_DIR BOOT_DIR $BOOT_DIR"
