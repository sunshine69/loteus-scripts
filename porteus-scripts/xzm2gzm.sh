#!/bin/bash

XZMFILE="$1"
GZMFILE="`basename $1 .xzm`.gzm"
rm -rf 1; mkdir 1
mount -o loop $XZMFILE 1
mksquashfs 1 $GZMFILE -comp gzip -b 1024K
umount 1
