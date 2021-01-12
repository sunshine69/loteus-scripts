#!/bin/bash
# ---------------------------------------------------
# Script to create bootable ISO in Linux
# usage: make_iso.sh [ /tmp/porteus.iso ]
# author: Tomas M. <http://www.linux-live.org>
# updated for Porteus by fanthom <http://www.porteus.org>
# ---------------------------------------------------

if [ "$1" = "--help" -o "$1" = "-h" ]; then
  echo "This script will create bootable ISO from files in curent directory."
  echo "Current directory must be writable."
  echo "example: $0 /mnt/sda5/porteus.iso"
  exit
fi

./update-boot-menu.sh || exit 1

if [ -z "$1" ]; then
   SUGGEST=$(readlink -f ../$(basename $(pwd)).iso)
   echo -ne "Target ISO file name [ Hit enter for $SUGGEST ]: "
   read ISONAME
   if [ "$ISONAME" = "" ]; then ISONAME="$SUGGEST"; fi
fi

CDLABEL="ISOBOOT"
# ISONAME=$(readlink -f "$1")

iso_file_name=$(basename -- "$ISONAME")

extension="${iso_file_name##*.}"
if [ "$extension" != 'iso' ]; then
	ISONAME="${ISONAME}.iso"
fi

cd $(dirname $0)

#mkisofs -o "$ISONAME" -v -l -f -J -joliet-long -R -D -A "$CDLABEL" \
#-V `date "+$CDLABEL-%H%M%S-%Y%m%d"` \
#-no-emul-boot -boot-info-table -boot-load-size 4 -boot-info-table \
#-eltorito-alt-boot -eltorito-platform 0xEF -e boot/grub/efi.img \
#-b isolinux/isolinux.bin -c isolinux/isolinux.boot .
#if ! `which xorriso >/dev/null 2>&1`; then
#  apt-get install xorriso # isolinux might not be available, better just copy the .bin file
#fi
#  -isohybrid-mbr /usr/lib/syslinux/mbr/isohdpfx.bin \

rm -f ${ISONAME}

#xorriso -as mkisofs -l -f -J -joliet-long \
#-isohybrid-mbr isolinux/isohdpfx.bin \
#-isohybrid-gpt-basdat \
mkisofs -l -f -J -joliet-long -r \
  -c isolinux/isolinux.boot \
  -b isolinux/isolinux.bin \
  -no-emul-boot \
  -boot-load-size 4 \
  -boot-info-table \
  -eltorito-alt-boot \
  -e boot/grub/efi.img \
  -no-emul-boot \
  -udf \
  -allow-limited-size \
  -V $CDLABEL \
  -o "$ISONAME" \
  .
echo "Completed. This is for legacy boot iso. Not yet test EFI but better use USB for EFI machine"
