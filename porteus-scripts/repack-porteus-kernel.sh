#!/bin/bash

[ ! -d porteus-kernel ] && echo "porteus-kernel dir deos nto exists - abort" && exit 1

TARGET_FNAME=$1
TAR_FNAME=${TARGET_FNAME%.sfx}

KVER=$(echo $TARGET_FNAME | grep -oP '(?<=porteus\-kernel\-)[\d\.]+')

if ! $(ls porteus-kernel/000-${KVER}* >/dev/null 2>&1); then
    echo "No matching kernel version detected, abort"
    exit 1
fi
tar cf $TAR_FNAME porteus-kernel
cat self-extract.sh $TAR_FNAME > $TARGET_FNAME
rm -f $TAR_FNAME porteus-kernel
