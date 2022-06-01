#!/bin/bash

export PORT_DIR=$(dirname `losetup -a|grep -P '000\-[\d\.]+'|awk '{print $3}'|cut -d'(' -f2` | head -n1)

cp ${PORT_DIR}/000-${KVER}.xzm.new /mnt/portdata/build/kernel-binary/porteus-kernel/000-${KVER}.xzm
cd /mnt/portdata/build/kernel-binary/
./repack-porteus-kernel.sh porteus-kernel-${KVER}.tar.sfx
