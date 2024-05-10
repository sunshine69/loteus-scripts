#!/bin/bash -x

# This will install porteus into a disk given by $1 (LOOP_DEV)

LOOP_DEV=$1

if [ -z "$LOOP_DEV" ]; then
    printf "ERROR - Usage: $0 [disk-device-like-sda] <boot-from-dir-name> <porteus-devname-like-sdc3>
    env vars used and can be customized:
      - MKFS to make the file ssytem on the third partition; default is 'mkfs.btrfs' with compression support.
      - OS_DIR where to copy the OS dir base images, default to be the current running system OS dir.
      - CURRENT_BOOT_DIR - Path to the boot directory where the bzImage and initrd.xz will be installed. If not set it uses the current one.
      - FORCE_HYBRID value yes|no|legacy. Make the boot disk hybrid mode. By default if device is loop, then it is yes, otherwise is no (only EFI boot is setup). Set it to 'yes' to force building EFI and legacy hybrid disk.
      If the value is 'legacy' then setup the boot disk is legacy only, no EFI.
      - If the device is a disk partition then the partition will be formarted and the OS images will be installed on it. It will bypass the auto partition scheme and only copy files to that part"
    exit 1
fi

export SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
MKFS=${MKFS:-mkfs.btrfs -f}

if [ ! -b "/dev/${LOOP_DEV}" ]; then
    echo "Not a block device /dev/${LOOP_DEV}"
    exit 1

fi

udevadm info --query=all /dev/${LOOP_DEV} > /tmp/dis_info_$$.txt
if $(grep ID_USB_DRIVER /tmp/dis_info_$$.txt >/dev/null 2>&1) || [[ "$LOOP_DEV" == loop* ]]; then
    USB_BOOT_OPT="usb_delay=2"
    IS_USB="true"
else
    USB_BOOT_OPT=""
fi

DEVTYPE=$(grep -oP '(?<=DEVTYPE=)[^\s]+' /tmp/dis_info_$$.txt)
DISK_DEVICE=$(lsblk --list --noheadings --output PKNAME /dev/${LOOP_DEV} | tail -n1)
if [ -z "$DISK_DEVICE" ]; then DISK_DEVICE=${LOOP_DEV}; fi # lsblk cmd does not work well with loop dev;

CURRENT_BOOT_FROM=$2
CURRENT_BOOT_OS=$(grep -oP '(?<=os=)[^\s]+' /proc/cmdline)

if [ ! -z "$OS_DIR" ]; then
    BOOT_OS=$(basename $OS_DIR)
else
    BOOT_OS=$CURRENT_BOOT_OS
fi

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

set -e

if [ "$DEVTYPE" = 'disk' ]; then
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

    # create 3th parition ext
    sgdisk /dev/${LOOP_DEV} --new=3:0:0
    sgdisk /dev/${LOOP_DEV} --typecode=3:8300

    # make hybrid. Assume that if we uses loop device, otherwise it is hard disk ignore

    if [[ $LOOP_DEV =~ "loop" ]] || [[ $LOOP_DEV =~ "nvme" ]] || [[ $LOOP_DEV =~ "mmcblk" ]]; then
        HYBRID=yes
        PART_CHAR="p" # loop device the partition has extra p (parallel devices, not serial one)
    else
        PART_CHAR=""
    fi

    FORCE_HYBRID=${FORCE_HYBRID:-no}
    if [ "$FORCE_HYBRID" = "yes" ]; then HYBRID=yes; fi

    if [[ $HYBRID = "yes" ]]; then
        sgdisk /dev/${LOOP_DEV} --hybrid=1:2:3
    else
        if [ "$FORCE_HYBRID" != "legacy" ]; then
            echo "Operating on real disk do not make hybrid disk"
        else
            echo "Only use legacy boot due to FORCE_HYBRID=$FORCE_HYBRID"
        fi
    fi

    # refresh partition table in kernel memory
    partprobe /dev/${LOOP_DEV}

    # review partition tables

    # using gdisk
    gdisk -l /dev/${LOOP_DEV}

    # using parted
    parted -a optimal -s /dev/${LOOP_DEV} print

    # create and mount file-system
    sleep 5 # hit error device not exists even gdisk list above saw it
    yes | mkdosfs -F 32 -I -n "BOOTDISK" /dev/${LOOP_DEV}${PART_CHAR}2
    if [ "$?" != "0" ]; then echo "ERROR mkdosfs -F 32 -I -n \"BOOTDISK\" /dev/${LOOP_DEV}${PART_CHAR}2 . Aborting..."; exit 1; fi
    #yes | mkdosfs -F 32 -I -n "BOOTDISK" /dev/${LOOP_DEV}${PART_CHAR}3
    yes | $MKFS -f /dev/${LOOP_DEV}${PART_CHAR}3
    if [ "$?" != "0" ]; then echo "ERROR $MKFS -f /dev/${LOOP_DEV}${PART_CHAR}3 . Aborting..."; exit 1; fi

fi

mkdir /mnt/root -p

if [ "$DEVTYPE" = "disk" ]; then
    TARGET_DEVICE=/dev/${LOOP_DEV}${PART_CHAR}3
else
    TARGET_DEVICE=/dev/${LOOP_DEV}
fi
if [ "$FORCE_HYBRID" != "legacy" ]; then # EFI enabled
    if [ "$DEVTYPE" = "disk" ]; then
        TARGET_EFI_PART=/dev/${LOOP_DEV}${PART_CHAR}2
    else
        TARGET_EFI_PART_NO=$(gdisk -l /dev/${DISK_DEVICE} | grep 'EF00' | awk '{print $1}')
        if [ -z "$TARGET_EFI_PART_NO" ]; then
            echo "ERROR Could not detect the EFI partition on device ${LOOP_DEV}"
            exit 1
        fi
        TARGET_DEVICE=/dev/${LOOP_DEV}
        TARGET_EFI_PART=/dev/${DISK_DEVICE}${TARGET_EFI_PART_NO}
    fi
fi
    echo "*** ALL DATA ON $TARGET_DEVICE as I am going to create a file system on $TARGET_DEVICE ***"
    echo "Command MKFS: $MKFS"
    echo "Type yes to continue"
    read _confirm
    if [ "$_confirm" != "yes" ]; then
        echo "Aborted!"
        exit 1
    fi
    $MKFS $TARGET_DEVICE

mount $TARGET_DEVICE /mnt/root
if [ "$?" != "0" ]; then echo "ERROR mounting $TARGET_DEVICE /mnt/root. Aborting..."; exit 1; fi

if [ "$FORCE_HYBRID" != "legacy" ]; then
    mkdir -p /mnt/root/boot/efi
    mount $TARGET_EFI_PART /mnt/root/boot/efi
    if [ "$IS_USB" = "true" ]; then GRUB_OPT="--removable"; else GRUB_OPT=""; fi
    grub-install --target=x86_64-efi --efi-directory=/mnt/root/boot/efi --boot-directory=/mnt/root/boot $GRUB_OPT --recheck --uefi-secure-boot
fi

if [[ $HYBRID = "yes" ]] || [[ $FORCE_HYBRID = "legacy" ]]; then
    grub-install --force --target=i386-pc --root-directory=/mnt/root --boot-directory=/mnt/root/boot /dev/${DISK_DEVICE}
fi

ROOT_PART_UUID=$(blkid --match-tag UUID $TARGET_DEVICE | grep -oP '(?<=UUID=)[^\s]+' | sed 's/"//g')

if [ -z "$BOOT_FROM" ]; then BOOT_FROM=$(echo $ROOT_PART_UUID | cut -f1 -d-); fi

sed "s/<SET_ME_ROOT_PART_UUID>/${ROOT_PART_UUID}/g; s/<SET_ME_BOOT_OS>/${BOOT_OS}/g; s/<SET_ME_BOOT_FROM>/${BOOT_FROM}/g; s/<SET_ME_HOSTNAME>/${HOSTNAME}/g; s/<SET_ME_USB_BOOT_OPT>/${USB_BOOT_OPT}/ " ${SCRIPT_DIR}/grub.cfg.tmpl > /mnt/root/boot/grub/grub.cfg

# Populate things here
cp ${CURRENT_BOOT_DIR}/{bzImage,initrd.xz} /mnt/root/boot/

mkdir /mnt/root/$BOOT_FROM/${BOOT_OS} -p

if [ ! -z "$OS_DIR" ]; then CURRENT_KERNEL_VER="custom"; fi

OS_DIR=${OS_DIR:-$CURRENT_PORT_DIR/$BOOT_OS}
echo "Use OS_DIR: '$OS_DIR'"

mkdir /mnt/root/c-${BOOT_FROM}/${BOOT_OS} -p
if [[ $MKFS =~ mkfs.btrfs ]]; then
    chattr +c -R /mnt/root/c-${BOOT_FROM}
    btrfs property set /mnt/root/c-${BOOT_FROM} compression zstd
    btrfs property set /mnt/root/c-${BOOT_FROM}/${BOOT_OS} compression zstd
fi

if [ -z "$CURRENT_KERNEL_VER" ]; then
    CURRENT_KERNEL_VER=$(uname -r)
    cp -a ${CURRENT_PORT_DIR}/000-*${CURRENT_KERNEL_VER}* /mnt/root/$BOOT_FROM/
else
    CUSTOM_PORT_DIR=$(dirname $OS_DIR)
    cp -a $CUSTOM_PORT_DIR/000-* /mnt/root/$BOOT_FROM/
fi

rsync --exclude '999*' --exclude '*.old' --exclude '*.new' --inplace -avh ${OS_DIR}/ /mnt/root/$BOOT_FROM/${BOOT_OS}/

sync

