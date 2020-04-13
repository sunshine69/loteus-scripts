#!/bin/sh

SOURCE_DIR="$1"
TARGET_DIR="$2"

if [ -z "$SOURCE_DIR" ] || [ -z "$TARGET_DIR" ]; then
    echo "Usage: $0 <kernel_build_source_dir> <target_directory_to_put_output_file>"
    exit 1
fi

cd $SOURCE_DIR

find . -type f -name "*.o" -o -name "*.ko" -o -name "*.cmd" -o -name ".tmp_*" -o -name "vmlinux" -o -name "*.tmp_*" -o -name "vmlinux.bin*" -o -name "bzImage" -o -name "*.o.cmd" -o -name "*.ko.cmd" -o -name "*.a" | while read fn; do rm -f $fn; done

VERSION=$(grep -oP '(?<=VERSION \= )([\d]+)' Makefile)
PATCHLEVEL=$(grep -oP '(?<=PATCHLEVEL \= )([\d]+)' Makefile)
SUBLEVEL=$(grep -oP '(?<=SUBLEVEL \= )([\d]+)' Makefile)
LOCAL_VER=$(grep -Po '(?<=CONFIG_LOCALVERSION=")([^"]+)' .config)
TARGET_FNAME="${TARGET_DIR}/000-linux-src-${VERSION}.${PATCHLEVEL}.${SUBLEVEL}${LOCAL_VER}.xzm"

cd ../

rm -f ${TARGET_FNAME}
mksquashfs $SOURCE_DIR ${TARGET_FNAME} -comp xz -b 1M -e 'Documentation/*'

echo "Kernel source image generated ${TARGET_FNAME}"
