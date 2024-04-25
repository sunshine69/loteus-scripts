#!/bin/bash

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

if [ ! -z "$BOOT_DIR" ]; then export BOOT_DIR; fi

. $SCRIPT_DIR/common.sh

CURRENT_DIR=$(pwd)

CURRENT_KVER=$(uname -r)

# Clean up
LAST_FILE=$(find $PORT_DIR/ -maxdepth 1 -type f -name "000*linux-header*.xzm" -printf "%T+\t%p\n" | grep -v  "${CURRENT_KVER}" | grep -v "${KVER}" | grep -v 'fallback' | sort -r )

LINE_COUNT=$(echo "$LAST_FILE" | wc -l )
let "TOBE_RM_COUNT=${LINE_COUNT}-1"

if [ $LINE_COUNT -gt 2 ]; then
    echo "clean should exclude CURRENT_KVER: $CURRENT_KVER | KVER: $KVER"
    echo "$LAST_FILE" | tail -n $TOBE_RM_COUNT | awk '{print $2}' |  while read fn; do echo "going to rm $fn"; rm -f "$fn"; done
fi

LAST_FILE=$(find $PORT_DIR/ -maxdepth 1 -type f -name "000*.xzm" -printf "%T+\t%p\n" | grep -v  "${CURRENT_KVER}" | grep -v "${KVER}" | grep -v 'fallback' | sort -r )

LINE_COUNT=$(echo "$LAST_FILE" | wc -l )
let "TOBE_RM_COUNT=${LINE_COUNT}-1"

if [ $LINE_COUNT -gt 2 ]; then
    echo "$LAST_FILE" | tail -n $TOBE_RM_COUNT | awk '{print $2}' |  while read fn; do echo "going to rm '$fn'"; rm -f "$fn"; done
fi

echo "BOOT_DIR: $BOOT_DIR"

for BD in $(echo $BOOT_DIR); do
	echo "Backup current kernel in $BD ..."
	[ -f "$BD/bzImage" ] && mv "$BD/bzImage" "$BD/bzImage.old"
	[ -f "$BD/initrd.xz" ] && mv "$BD/initrd.xz" "$BD/initrd.xz.old"

	echo "Copy new kernel in $BD"
	cp $SCRIPT_DIR/initrd.xz $SCRIPT_DIR/bzImage $BD/
	if [[ "$KVER" =~ "fallback" ]]; then
		cp -a $SCRIPT_DIR/bzImage $BD/bzImage.fallback
		cp -a $SCRIPT_DIR/initrd.xz $BD/initrd.xz.fallback
		rm -f $PORT_DIR/000-*fallback.xzm
	fi
	cp $SCRIPT_DIR/000-*.xzm $PORT_DIR/

done


cd $CURRENT_DIR
echo "Going to remove '$SCRIPT_DIR'"
rm -rf "$SCRIPT_DIR"
