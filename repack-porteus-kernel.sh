#!/bin/bash
# Take a dir `porteus-kernel` and create new sfx file

export SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

[ ! -d porteus-kernel ] && echo "porteus-kernel dir does not exist - abort" && exit 1

[ ! -f ${SCRIPT_DIR}/self-extract.sh ] && echo "self-extract.sh in the same dir does not exist, abort" && exit 1

KVER=$(ls porteus-kernel/000*.xzm | grep -v 'linux-src' | sed 's/porteus-kernel\///; s/.xzm$// ; s/000\-// ')
if [ -z "$KVER" ]; then
    KVER=$(ls porteus-kernel/000*.xzm.new | grep -v 'linux-src' | sed 's/porteus-kernel\///; s/.xzm$// ; s/000\-// ')
fi
echo "Detected KVER: '$KVER'"

TAR_FNAME="porteus-kernel-${KVER}.tar"
TARGET_FNAME="${TAR_FNAME}.sfx"

if ! $(ls porteus-kernel/000-${KVER}* >/dev/null 2>&1); then
    echo "No matching kernel version detected, abort"
    exit 1
fi
rm -f porteus-kernel/*.bak
find porteus-kernel/*.new | while read fn; do
	_name=$(basename $fn .new)
    echo mv $fn $(dirname $fn)/$_name
	mv $fn $(dirname $fn)/$_name
done
tar cf $TAR_FNAME porteus-kernel
cat ${SCRIPT_DIR}/self-extract.sh $TAR_FNAME > $TARGET_FNAME
rm -rf $TAR_FNAME porteus-kernel
chmod +x $TARGET_FNAME

if [ -d /mnt/doc/opc-backup ]; then
	echo "Copy to /mnt/doc/opc-backup ..."
	cp $TARGET_FNAME /mnt/doc/opc-backup/
fi
