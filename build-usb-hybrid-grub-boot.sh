#!/bin/bash


LOOP_DEV=$1

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
sgdisk /dev/${LOOP_DEV} --new=3:0:1G
sgdisk /dev/${LOOP_DEV} --typecode=3:0700

sfdisk --activate /dev/${LOOP_DEV} 3

# create 4th parition ext
sgdisk /dev/${LOOP_DEV} --new=4:0:0
sgdisk /dev/${LOOP_DEV} --typecode=4:8300

# make hybrid
sgdisk /dev/${LOOP_DEV} --hybrid=1:2:3:4

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
yes | mkdosfs -F 32 -I -n "BOOTDISK" /dev/${LOOP_DEV}p2
yes | mkdosfs -F 32 -I -n "BOOTDISK" /dev/${LOOP_DEV}p3
yes | mkfs.ext4 -m0 /dev/${LOOP_DEV}p4

if [ -d /mnt/root/boot ]; then
    echo "/mnt/root exist, aborting"
    exit 1
else
    mkdir /mnt/root
fi
mount /dev/${LOOP_DEV}p3 /mnt/root

mkdir -p /mnt/root/boot/efi
mount /dev/${LOOP_DEV}p2 /mnt/root/boot/efi

grub-install --target=x86_64-efi --efi-directory=/mnt/root/boot/efi --boot-directory=/mnt/root/boot --removable --recheck --uefi-secure-boot
grub-install --target=i386-pc --boot-directory=/mnt/root/boot /dev/${LOOP_DEV}

ROOT_PART_UUID=$(grep -oP '(?<=search.fs_uuid )[^\s]+(?= root)' /mnt/root/boot/efi/EFI/BOOT/grub.cfg)
sed "s/<SET_ME_ROOT_PART_UUID>/${ROOT_PART_UUID}/" grub.cfg.tmpl > /mnt/root/boot/grub/grub.cfg

# Populate things here
cp /mnt/sr0/boot/syslinux/bzImage /mnt/root/boot/bzImage
cp /mnt/sr0/boot/syslinux/initrd.xz /mnt/root/boot/initrd.xz


# umount and exit
cd
sync
umount /mnt/root/boot/efi
umount /mnt/root
