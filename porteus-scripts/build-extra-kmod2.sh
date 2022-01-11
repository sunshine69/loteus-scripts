#!/bin/bash

cp /mnt/nvme0n1p3/nve/000-${KVER}.xzm.new /mnt/nvme0n1p3/build/kernel-binary/porteus-kernel/000-${KVER}.xzm 
cd /mnt/nvme0n1p3/build/kernel-binary/
./repack-porteus-kernel.sh porteus-kernel-${KVER}.tar.sfx 
