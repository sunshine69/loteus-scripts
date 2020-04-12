#!/bin/bash

# Used to re-pack the current kernel mod dir into

export SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
export KSOURCE_DIR=/mnt/sda4/tmp
export KBIN_DIR=/mnt/sda4/build/kernel-binary
export WORK_DIR="$KSOURCE_DIR"

KVER=$(uname -r)

pushd .
cd $WORK_DIR

rm -rf 1 2 wd; mkdir 1 2 wd
mount -t overlay overlay -o lowerdir=/mnt/live/memory/images/000-${KVER}.xzm,upperdir=1,workdir=wd 2
mount -o bind 2/lib/modules/${KVER} /lib/modules/${KVER}

(cd /lib/modules/${KVER} ; ln -sf source build )

echo "Make module read write, now go and compile external modules as required. When dont hit enter"
read _junk

mksquashfs 2 000-${KVER}.xzm -comp xz -b 1M

echo n | ${KBIN_DIR}/porteus-kernel-${KVER}.tar.sfx
mv 000-${KVER}.xzm porteus-kernel/000-${KVER}.xzm

CURRENT_KMOD_PATH=$(losetup -a | grep 000-$(uname -r) | awk '{print $3}' | sed 's/(//; s/)//;')
CURRENT_KMOD_DIR=$(dirname $CURRENT_KMOD_PATH)

cp porteus-kernel/000-${KVER}.xzm ${CURRENT_KMOD_DIR}/000-${KVER}.xzm.new

echo "Do you want to rebuild initrd? y/n?"

read ans

if [ "$ans" = "y" ]; then
    $SCRIPT_DIR/rebuild-initrd.sh porteus-kernel/initrd.xz
    if [ "$?" = "0" ]; then rm -f porteus-kernel/initrd.xz.bak; fi
fi

tar cf porteus-kernel-${KVER}.tar porteus-kernel
cat ${SCRIPT_DIR}/self-extract.sh porteus-kernel-${KVER}.tar > porteus-kernel-${KVER}.tar.sfx
chmod +x porteus-kernel-${KVER}.tar.sfx
mv porteus-kernel-${KVER}.tar.sfx ${KBIN_DIR}/

rm -rf porteus-kernel porteus-kernel-${KVER}.tar

popd
