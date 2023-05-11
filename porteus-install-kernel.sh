#!/bin/bash

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
. $SCRIPT_DIR/common.sh

CURRENT_DIR=$(pwd)

CURRENT_KVER=$(uname -r)

# Clean up
LAST_FILE=$(find $PORT_DIR/ -maxdepth 1 -type f -name "000*linux-header*.xzm" -printf "%T+\t%p\n" | grep -v  "*${CURRENT_KVER}*.xzm" | grep -v "*${KVER}*.xzm" | sort -r )

LINE_COUNT=$(echo "$LAST_FILE" | wc -l )

if [ $LINE_COUNT -gt 2 ]; then
    echo "$LAST_FILE" | head -n 1 | awk '{print $2}' |  while read fn; do rm -f "$fn"; done
fi

LAST_FILE=$(find $PORT_DIR/ -maxdepth 1 -type f -name "000*.xzm" -printf "%T+\t%p\n" | grep -v  "*${CURRENT_KVER}*.xzm" | grep -v "linux-header" | grep -v "*${KVER}*.xzm" |sort -r )

LINE_COUNT=$(echo "$LAST_FILE" | wc -l )

if [ $LINE_COUNT -gt 2 ]; then
    echo "$LAST_FILE" | head -n 1 | awk '{print $2}' |  while read fn; do echo "Going to rm '$fn'"; rm -f "$fn"; done
fi

echo "BOOT_DIR: $BOOT_DIR"

for BD in $(echo $BOOT_DIR); do
	echo "Backup current kernel in $BD ..."
	[ -f "$BD/bzImage" ] && mv "$BD/bzImage" "$BD/bzImage.old"
	[ -f "$BD/initrd.xz" ] && mv "$BD/initrd.xz" "$BD/initrd.xz.old"

	echo "Copy new kernel in $BD"
	cp $SCRIPT_DIR/initrd.xz $SCRIPT_DIR/bzImage $BD/
	cp $SCRIPT_DIR/000-*.xzm $PORT_DIR/

done


cd $CURRENT_DIR
echo "Going to remove '$SCRIPT_DIR'"
rm -rf "$SCRIPT_DIR"
