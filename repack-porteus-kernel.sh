#!/bin/bash
# Take a dir `porteus-kernel` and create new sfx file

export SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

[ ! -d porteus-kernel ] && echo "porteus-kernel dir does not exist - abort" && exit 1

TARGET_FNAME=$1

[ -z "$TARGET_FNAME" ] && echo "first arg required. This is the target sfx file name" && exit 1

TAR_FNAME=${TARGET_FNAME%.sfx}

KVER=$(echo $TARGET_FNAME | grep -oP '(?<=porteus\-kernel\-)[\d\.]+')

if ! $(ls porteus-kernel/000-${KVER}* >/dev/null 2>&1); then
    echo "No matching kernel version detected, abort"
    exit 1
fi
rm -f porteus-kernel/*.bak
find porteus-kernel/*.new | while read fn; do
	_name=$(basename $fn .new)
	mv $fn $(dirname $fn)/$_name
done
tar cf $TAR_FNAME porteus-kernel
cat ${SCRIPT_DIR}/self-extract.sh $TAR_FNAME > $TARGET_FNAME
rm -rf $TAR_FNAME porteus-kernel
