#!/bin/bash

function help() {
printf "
Used to re-pack the current kernel mod dir into
When build a new kernel / reboot and we can run this to recompile external modules and re-pack

Usage: $0 [path_to_kernel_mod_file] [path_to_kernel_source_xzm_mod_file]

Argument are options, if not provided it will use current running kernel and default kernel source dir in the symlink 'source' in /lib/modules/<kver>/source

The environment vars below is set as default. You can change it as you wish

KBIN_DIR=/mnt/portdata/build/kernel-binary - dir that store the porteus kernel build output.
WORK_DIR=/mnt/portdata/tmp - script working dir
"
exit 0
}

if [ "$1" = "-h" ] || [ "$1" = "--help" ] || [ "$1" = "help" ]; then
    help
fi

export SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
export KBIN_DIR=${KBIN_DIR:-/mnt/portdata/build/kernel-binary}
export WORK_DIR=${WORK_DIR:-/mnt/portdata/tmp}

pushd .
cd $WORK_DIR

rm -rf repack1 repack2 repack3 repack1s repack2s repack3s repack-wds repack-wd; mkdir repack1 repack2 repack3 repack1s repack2s repack3s repack-wds repack-wd

KVER=$1
if [ "$KVER" = "" ]; then
    KVER=$(uname -r)
    KMOD_MOUNT="/mnt/live/memory/images/000-${KVER}.xzm"
else
    NOT_RUNNING_KERNEL="y"
    [ ! -f $KVER ] && echo "Kernel mod file does not exist, aborting ..." && exit 1
    LOOP_DEV=$(losetup -f)
    losetup $LOOP_DEV $KVER
    mount $LOOP_DEV repack1
    KVER=$(ls repack1/lib/modules/)
    KMOD_MOUNT="${WORK_DIR}/repack1"
    if [ "$2" = "" ]; then
        KSOURCE_DIR="source"
    else
        if [ ! -f "$2" ]; then
            echo "Kernel source mod file does not exists, aborting ..."
            losetup -d $LOOP_DEV >/dev/null 2>&1
            exit 1
        fi
        LOOP_DEV_S=$(losetup -f); losetup $LOOP_DEV_S $2
        mount $LOOP_DEV_S repack1s
        mount -t overlay overlay -o lowerdir=repack1s,upperdir=repack2s,workdir=repack-wds repack3s
        KSOURCE_DIR="${WORK_DIR}/repack3s"
    fi
fi

mount -t overlay overlay -o lowerdir=${KMOD_MOUNT},upperdir=repack2,workdir=repack-wd repack3
(cd repack3/lib/modules/${KVER}; ln -sf $KSOURCE_DIR build)

echo "KSOURCE_DIR: $KSOURCE_DIR Mod read-write mount: $WORK_DIR/repack3/lib/modules/${KVER}"

if [ -d /lib/modules/${KVER} ]; then
    mount -o bind $WORK_DIR/repack3/lib/modules/${KVER} /lib/modules/${KVER}
#   (cd /lib/modules/${KVER} ; ln -sf source build )
fi

if [ "$NOT_RUNNING_KERNEL" = "y" ]; then
    echo "Building for different kernel than the current running kernel"
    echo "The modules has been mounted rw at ${WORK_DIR}/repack3/lib/modules/${KVER}"
    echo "Kernel source dir is at '$KSOURCE_DIR'"
    echo "Use these dir to manually make your kernel modules. When done, hit enter."
    read _junk
fi

echo ""
echo "Make module read write, now go and compile external modules as required\nYou may need to populate the source When done hit enter"
read _junk

mksquashfs repack3 000-${KVER}.xzm -comp xz -b 1M

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

umount /lib/modules/${KVER} >/dev/null 2>&1
umount repack3 repack3s  >/dev/null 2>&1
umount repack1  >/dev/null 2>&1
umount repack1s  >/dev/null 2>&1
losetup -d $LOOP_DEV >/dev/null 2>&1
losetup -d $LOOP_DEV_S >/dev/null 2>&1

rm -rf repack1 repack2 repack3 repack1s repack2s repack3s repack-wds repack-wd

popd
