#!/bin/bash

CWD="$(pwd)"

if [ -z "$1" ]; then
    INF=/mnt/sda4/boot/initrd.xz
else
    INF=$1
fi

if [ -z "$2" ]; then
    OUT=/tmp/initrd.xz
else
    OUT=$2
fi

[ ! -f "$INF" ] && echo "Input file $INF does not exist" && exit 1

mkdir /tmp/initrd_$$ && cd /tmp/initrd_$$

xzcat $INF | cpio -id
cp -a $CWD/linuxrc .
echo "Copy modules in - /tmp/initrd_$$/lib/modules/ if needed and then type kernel version in"
read KVER

[ ! -z "$KVER" ] && depmod $KVER -b .

echo "Building ..."

find . | cpio --quiet -o -H newc | lzma -7 > $OUT

cd $CWD
echo "Output file $OUT"
rm -rf /tmp/initrd_$$
