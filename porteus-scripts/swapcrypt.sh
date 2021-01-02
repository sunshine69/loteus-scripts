#!/bin/sh -ex

RANDOM=$$
DEV=$1
shift

PASS="$RANDOM"

echo $PASS | cryptsetup --key-file=- luksFormat /dev/${DEV} $*
echo $PASS | cryptsetup --key-file=- luksOpen /dev/${DEV} swapenc $*
mkswap /dev/mapper/swapenc
echo /dev/mapper/swapenc
