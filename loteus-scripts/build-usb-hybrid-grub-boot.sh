#!/bin/bash

# This will install porteus into a disk given by $1 (LOOP_DEV)

LOOP_DEV=$1

if [ -z "$LOOP_DEV" ]; then
    printf "ERROR - Usage: $0 [disk-device-like-sda] <boot-from-dir-name> <porteus-devname-like-sdc3>
    env vars used
      - MKFS to make the file ssytem on the third partition; default is mkfs.btrfs with compression support
      - OS_DIR where to copy the OS dir base images, default to be the current running system OS dir"
    exit 1
fi

export SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

if [ ! -b "/dev/${LOOP_DEV}" ]; then
    echo "Not a block device /dev/${LOOP_DEV}"
    exit 1

fi

CURRENT_BOOT_FROM=$2
CURRENT_BOOT_OS=$(grep -oP '(?<=os=)[^\s]+' /proc/cmdline)

if [ -z "$CURRENT_BOOT_FROM" ]; then
    CURRENT_BOOT_FROM=$(grep -oP '(?<=from=)[^\s]+' /proc/cmdline)
fi
CURRENT_PORTEUS_DEV=$3

if [ -z "$CURRENT_PORTEUS_DEV" ]; then
    _BOOT_DATA_DEV=$(grep -A1 'Booting data device:' /var/log/live/livedbg | tail -n1)
    echo $_BOOT_DATA_DEV
    CURRENT_PORTEUS_DEV=$(basename $_BOOT_DATA_DEV)
fi

CURRENT_PORTEUS_DISK=$(echo $CURRENT_PORTEUS_DEV|sed 's/[0-9]$//g')
CURRENT_EFI_DEV=${CURRENT_EFI_DEV:-${CURRENT_PORTEUS_DISK}2}

# Assume boot dir and port dir in the same device.
CURRENT_BOOT_DIR=${CURRENT_BOOT_DIR:-/mnt/${CURRENT_PORTEUS_DEV}/boot}
CURRENT_PORT_DIR=${CURRENT_PORT_DIR:-/mnt/${CURRENT_PORTEUS_DEV}/${CURRENT_BOOT_FROM}}

if [ ! -f ${CURRENT_BOOT_DIR}/bzImage ]; then
    CURRENT_BOOT_DIR=/mnt/${CURRENT_EFI_DEV}/boot
    if [ ! -f ${CURRENT_BOOT_DIR}/bzImage ]; then
        BZIMAGE_PATH=$(cat /proc/cmdline | grep -oP '(?<=BOOT_IMAGE=)[^\s]+(?=.*)')
        BZIMAGE_NAME=$(basename $BZIMAGE_PATH)
        BZIMAGE_DIR=$(dirname $BZIMAGE_PATH)

        if [ -z "$BZIMAGE_FULL_PATH" ]; then
            if ! `touch ${BZIMAGE_DIR}/test-file >/dev/null 2>&1`; then
                echo "${BZIMAGE_DIR} is not writable. Looks like we boot from cdrom. Will use hardcoded path from portdata"
                export BZIMAGE_FULL_PATH=/mnt/sr0/boot/syslinux/${BZIMAGE_NAME}
                #export PORT_DIR=/mnt/portdata/port
                #export BOOT_DIR=/mnt/portdata/boot
            else
                export BZIMAGE_FULL_PATH=$(find /mnt/nvme*/${BZIMAGE_DIR}/ /mnt/sd*/${BZIMAGE_DIR}/ -maxdepth 2 -type f -name ${BZIMAGE_NAME}|head -n1)
            fi
        fi
        CURRENT_BOOT_DIR=$(dirname $BZIMAGE_FULL_PATH)
        if [ ! -f ${CURRENT_BOOT_DIR}/bzImage ]; then
            echo "Can not find where the kernel is. Last chance ..."
            echo "Enter the directory where your boot kernel is or where you want to copy the kernel from"
            read CURRENT_BOOT_DIR
        fi
    fi
fi

umount /mnt/root/boot/efi || true
umount /mnt/root || true
umount /dev/${LOOP_DEV}* || true

# partition disk
# clear existing data
sgdisk /dev/${LOOP_DEV} --zap-all

# create 1st partition
sgdisk /dev/${LOOP_DEV} --new=1:0:+1M
sgdisk /dev/${LOOP_DEV} --typecode=1:EF02

# create 2nd parition
sgdisk /dev/${LOOP_DEV} --new=2:0:+100M
sgdisk /dev/${LOOP_DEV} --typecode=2:EF00

# create 3nd parition
# sgdisk /dev/${LOOP_DEV} --new=3:0:1G
# sgdisk /dev/${LOOP_DEV} --typecode=3:0700

# sfdisk --activate /dev/${LOOP_DEV} 3

# create 3th parition ext
sgdisk /dev/${LOOP_DEV} --new=3:0:0
sgdisk /dev/${LOOP_DEV} --typecode=3:8300

# make hybrid. Assume that if we uses loop device, otherwise it is hard disk ignore

if [[ $LOOP_DEV =~ "loop" ]]; then
	HYBRID=yes
	PART_CHAR="p" # loop device the partition has extra p
else
	PART_CHAR=""
fi

if [[ $HYBRID = "yes" ]]; then
    sgdisk /dev/${LOOP_DEV} --hybrid=1:2:3
else
    echo "Operating on real disk do not make hybrid disk"
fi

# refresh partition table in kernel memory
partprobe /dev/${LOOP_DEV}

# review partition tables
# using fdisk
fdisk -l /dev/${LOOP_DEV}

# using gdisk
gdisk -l /dev/${LOOP_DEV}

# using parted
parted -a optimal -s /dev/${LOOP_DEV} print


# create and mount file-system
yes | mkdosfs -F 32 -I -n "BOOTDISK" /dev/${LOOP_DEV}${PART_CHAR}2
#yes | mkdosfs -F 32 -I -n "BOOTDISK" /dev/${LOOP_DEV}${PART_CHAR}3
MKFS=${MKFS:-mkfs.btrfs}
yes | $MKFS -f /dev/${LOOP_DEV}${PART_CHAR}3

if [ -d /mnt/root/boot ]; then
    echo "/mnt/root exist, aborting"
    exit 1
else
    mkdir /mnt/root
fi
mount /dev/${LOOP_DEV}${PART_CHAR}3 /mnt/root

mkdir -p /mnt/root/boot/efi
mount /dev/${LOOP_DEV}${PART_CHAR}2 /mnt/root/boot/efi

grub-install --target=x86_64-efi --efi-directory=/mnt/root/boot/efi --boot-directory=/mnt/root/boot --removable --recheck --uefi-secure-boot

if [[ $HYBRID = "yes" ]]; then
	grub-install --target=i386-pc --boot-directory=/mnt/root/boot /dev/${LOOP_DEV}
fi

if [ -z "$BOOT_OS" ]; then BOOT_OS=$CURRENT_BOOT_OS; fi

ROOT_PART_UUID=$(grep -oP '(?<=search.fs_uuid )[^\s]+(?= root)' /mnt/root/boot/efi/EFI/BOOT/grub.cfg)

if [ -z "$BOOT_FROM" ]; then BOOT_FROM=$(echo $ROOT_PART_UUID | cut -f1 -d-); fi

sed "s/<SET_ME_ROOT_PART_UUID>/${ROOT_PART_UUID}/g; s/<SET_ME_BOOT_OS>/${BOOT_OS}/g; s/<SET_ME_BOOT_FROM>/${BOOT_FROM}/g; s/<SET_ME_HOSTNAME>/${HOSTNAME}/g " ${SCRIPT_DIR}/grub.cfg.tmpl > /mnt/root/boot/grub/grub.cfg

# Populate things here
cp ${CURRENT_BOOT_DIR}/{bzImage,initrd.xz} /mnt/root/boot/

mkdir /mnt/root/$BOOT_FROM/${CURRENT_BOOT_OS} -p

OS_DIR=${OS_DIR:-$CURRENT_PORT_DIR/$CURRENT_BOOT_OS}
echo "Use OS_DIR: '$OS_DIR'"

rsync --exclude '999*' --exclude '*.old' --exclude '*.new' --inplace -avh ${OS_DIR}/ /mnt/root/$BOOT_FROM/${CURRENT_BOOT_OS}/

CURRENT_KERNEL_VER=$(uname -r)
cp -a ${CURRENT_PORT_DIR}/000-*${CURRENT_KERNEL_VER}* /mnt/root/$BOOT_FROM/

mkdir /mnt/root/c-${BOOT_FROM}/${BOOT_OS} -p
if [[ $MKFS =~ mkfs.btrfs ]]; then
    chattr +c -R /mnt/root/c-${BOOT_FROM}
    btrfs property set /mnt/root/c-${BOOT_FROM} compression zstd
    btrfs property set /mnt/root/c-${BOOT_FROM}/${BOOT_OS} compression zstd
fi
sync

