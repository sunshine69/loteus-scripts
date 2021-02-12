#!/bin/bash

export PATH=/opt/bin:$PATH
export SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

WORK_DIR=/mnt/portdata/tmp

KVER=${KVER:-$(uname -r)}
_KMOD_PATH=$(losetup -a | sed 's/(//; s/)//' | grep -P "${KVER}.[xgz]zm" | awk '{print $3}' | head -n1)
KMOD_PATH=${KMOD_PATH:-$_KMOD_PATH} ; echo "KMOD_PATH=${KMOD_PATH}"
FROM_DIR=$(dirname $KMOD_PATH)

echo "FROM_DIR=$FROM_DIR"

#pushd .
#cd $WORK_DIR

mount -o bind lib/modules/$KVER /lib/modules/$KVER
[ ! -d /usr/src/linux-headers-$KVER ] && mkdir /usr/src/linux-headers-$KVER

if [ -f "${FROM_DIR}/000-linux-src-${KVER}.xzm" ]; then
    echo mount -o loop ${FROM_DIR}/000-linux-src-${KVER}.xzm /usr/src/linux-headers-$KVER
    mount -o loop ${FROM_DIR}/000-linux-src-${KVER}.xzm /usr/src/linux-headers-$KVER
else
    if [ ! -z "$KHEADER_MOD" ]; then
        mount -o loop $KHEADER_MOD /usr/src/linux-headers-$KVER
    else
        echo "No kernel mod file found and var KHEADER_MOD not set, can not mount header. Aborting"
        exit 1
    fi
fi

echo "Kernel source and mod mounted. Run your program to build the mod, when done type exit the shell"
bash
