#!/bin/bash -e

function doexit() {
    set +e
    STATUS=$?
    echo "EXIT detected with exit status \\$STATUS"
    echo "ERROR on line $1"
    cryptsetup luksClose test$$ || cryptsetup plainClose test$$
    losetup -d $LOOP_DEV
    rm -rf /tmp/test$$
    exit $STATUS
}

trap 'doexit $LINENO' TERM KILL INT ERR

FILE=$1
LOOP_DEV=$(losetup -f)
losetup $LOOP_DEV $FILE
echo "***"
read -s p
if blkid $LOOP_DEV | grep 'TYPE="crypto_LUKS"' >/dev/null 2>&1; then
    echo $p|cryptsetup --key-file=- luksOpen $LOOP_DEV test$$
else
    echo $p|cryptsetup --key-file=- plainOpen $LOOP_DEV test$$
fi

mkdir /tmp/test$$

mount /dev/mapper/test$$ /tmp/test$$

echo Mounted at /tmp/test$$
