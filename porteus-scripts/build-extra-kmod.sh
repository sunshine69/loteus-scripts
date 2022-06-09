#!/bin/bash

export SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
export KVER=$(uname -r)
export WORK_DIR=$(dirname $1)
export _KMOD_PATH=$(losetup -a | sed 's/(//; s/)//' | grep -P "${KVER}.[xgz]zm" | awk '{print $3}' | head -n1)
export KMOD_PATH=${KMOD_PATH:-$_KMOD_PATH} ; echo "KMOD_PATH=${KMOD_PATH}"
export FROM_DIR=$(dirname $KMOD_PATH)
export PORT_DIR=$(dirname `losetup -a|grep -P '000\-[\d\.]+'|awk '{print $3}'|cut -d'(' -f2` | head -n1)

update-image.sh $PORT_DIR/000-${KVER}.xzm $SCRIPT_DIR/build-extra-kmod1.sh
