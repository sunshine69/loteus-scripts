#!/bin/bash

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
. $SCRIPT_DIR/common.sh

CURRENT_KVER=$(uname -r)

# Clean up
LAST_FILE=$(find $PORT_DIR/ -maxdepth 1 -type f -name "000*linux-header*.xzm" -printf "%T+\t%p\n" | grep -v  "*${CURRENT_KVER}*.xzm" | sort -r | head -n 1 | awk '{print $2}')

find $PORT_DIR/ -maxdepth 1 -type f -name "000*linux-header*.xzm" | grep -v  "*${CURRENT_KVER}*.xzm" | grep -v "$LAST_FILE" | while read fn; do rm -f "$fn"; done

LAST_FILE=$(find $PORT_DIR/ -maxdepth 1 -type f -name "000*.xzm" -printf "%T+\t%p\n" | grep -v  "*${CURRENT_KVER}*.xzm" | sort -r | head -n 1 | awk '{print $2}')

find $PORT_DIR/ -maxdepth 1 -type f -name "000*.xzm" | grep -v  "*${CURRENT_KVER}*.xzm" | grep -v "$LAST_FILE" | while read fn; do rm -f "$fn"; done

# Copy new kernel
mv $BOOT_DIR/bzImage $BOOT_DIR/bzImage.old
mv bzImage $BOOT_DIR/
mv 000-*.xzm $PORT_DIR/
cd ..
rm -rf "$SCRIPT_DIR"
