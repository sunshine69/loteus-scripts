#!/bin/bash

OS="$1"

OLD_OS=$(grep -P -o '(?<=os=)[^\s]+' ./isolinux/live.cfg | head -n1)

echo "Detected old OS: $OLD_OS"

if [ ! -z "$OS" ]; then
  for fname in ./isolinux/live.cfg ./boot/grub/menu.cfg ./boot/syslinux/porteus.cfg; do

	  perl -i.bak -pe "s/changes=([^\/]+)\/[^\s]*/changes=\1\/${OS}/g; s/os=[^\s]*/os=${OS}/g; s/c-${OLD_OS}/c-${OS}/g; s/label ${OLD_OS}/label ${OS}/g" $fname
    rm -f ${fname}.bak
  done
else
  echo "Output information mode"
  for f in ./isolinux/live.cfg ./boot/grub/menu.cfg ./boot/syslinux/porteus.cfg; do
    echo $f
    grep -P -o '(?<=os=)[^\s]+' $f
  done
fi

[ -z "$KVER" ] && KVER=$(uname -r)

echo "KVER is : $KVER"

KERNEL_MOD="000-$KVER.xzm"

if [ ! -f $KERNEL_MOD ]; then
	rm -f 000-*.xzm
	ln -sf /mnt/sda3/usb/$KERNEL_MOD $KERNEL_MOD
    [ "$?" = "0" ] || (echo "Fatal, can not make kernel mod sym link" && exit 1)
fi
