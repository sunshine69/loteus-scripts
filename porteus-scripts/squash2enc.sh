#!/bin/bash

SRC=$1
LUKS_ORIG=$2
PASS=$3
OUT=`basename $SRC`.enc
SIZE=`ls -s --block-size=1048576 $SRC | cut -d' ' -f1`
if [ $SIZE -lt 3 ]; then 
	SIZE=4
else
	let "SIZE=$SIZE+2"
fi # Minimum size 4 Mb - 2Mb more
echo "Creating empty container with size $SIZE Mb..."
dd if=/dev/zero of=$OUT bs=1M count=$SIZE
NEWCRYPT='y'
if [ -f $LUKS_ORIG ]; then
	echo "Use exsting LUKS info from $LUKS_ORIG"
	LODEV1=`losetup -f`; losetup $LODEV1 $LUKS_ORIG
	cryptsetup luksHeaderBackup $LODEV1 --header-backup-file ${LUKS_ORIG}_backup
	if [ $? == 0 ]; then
		losetup -d $LODEV1
		NEWCRYPT=n
	fi
fi
LODEV=`losetup -f`; losetup $LODEV $OUT
if [ -z $PASS ]; then read -s -p "Enter Pass: " PASS; fi
if [ $NEWCRYPT == 'y' ]; then
	echo "Will set up new LUKS container"
	echo $PASS | md5sum | cut -f1 -d' ' | cryptsetup --key-file=- -q luksFormat $LODEV
else
	cryptsetup -q luksHeaderRestore $LODEV --header-backup-file ${LUKS_ORIG}_backup
	rm -f ${LUKS_ORIG}_backup
fi
echo $PASS | md5sum | cut -f1 -d' ' | cryptsetup --key-file=- luksOpen $LODEV ${OUT}_ENC
if [ $? != 0 ]; then echo "Second try .."; cryptsetup luksOpen $LODEV ${OUT}_ENC; fi
if [ $? == 0 ]; then
echo "copy from $SRC to $OUT"
dd if=$SRC of=/dev/mapper/${OUT}_ENC
mkdir TEST_$$ >/dev/null 2>&1
mount /dev/mapper/${OUT}_ENC TEST_$$
if [ $? != 0 ]; then echo "WARNING. Something wrong, I can not mount the container"; fi
umount TEST_$$ >/dev/null 2>&1; rm -rf TEST_$$
cryptsetup luksClose ${OUT}_ENC
fi
losetup -d $LODEV
echo "Encrypted image is $OUT"
