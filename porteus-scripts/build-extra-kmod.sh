#!/bin/bash

export KVER=$(uname -r)
export WORK_DIR=$(dirname $1)
export _KMOD_PATH=$(losetup -a | sed 's/(//; s/)//' | grep -P "${KVER}.[xgz]zm" | awk '{print $3}' | head -n1)
export KMOD_PATH=${KMOD_PATH:-$_KMOD_PATH} ; echo "KMOD_PATH=${KMOD_PATH}"
export FROM_DIR=$(dirname $KMOD_PATH)

update-image.sh /mnt/nvme0n1p3/nve/000-${KVER}.xzm /mnt/nvme0n1p3/tmp/build-extra-kmod1.sh
