#!/bin/bash

SRC=$1
ENC=$2
if [ "$3" ]; then WORKDIR="$3"; else WORKDIR=/mnt/live; fi
PASS=$4

NAME_PREFIX='update_mod'

CDIR=`pwd`; cd $WORKDIR; rm -rf ${NAME_PREFIX}1 ${NAME_PREFIX}2 ${NAME_PREFIX}3 >/dev/null 2>&1; mkdir ${NAME_PREFIX}1 ${NAME_PREFIX}2 ${NAME_PREFIX}3 >/dev/null 2>&1
SRCPATH="`realpath $1`"

LODEV=`losetup -f`; losetup $LODEV $SRCPATH
if [ $? == 0 ]; then
	if blkid $LODEV 2>/dev/null | cut -d" " -f3- | grep -q _LUKS; then
		if [ -z $PASS ]; then read -s -p "Enter pass:" PASS; fi
		echo "$PASS" | md5sum | cut -f1 -d' ' | cryptsetup --key-file=- luksOpen $LODEV ${NAME_PREFIX}_DEC
		if [ $? != 0 ]; then echo "Second try .."; cryptsetup luksOpen $LODEV ${NAME_PREFIX}_DEC; fi
		mount /dev/mapper/${NAME_PREFIX}_DEC ${NAME_PREFIX}1
	else
		mount $LODEV ${NAME_PREFIX}1
	fi
else
  echo "Error mount old changes module. New changes will be saved into new module"
  LODEV=''
fi
mount -t aufs none ${NAME_PREFIX}3 -o br=${NAME_PREFIX}2=rw:${NAME_PREFIX}1=ro
if [ $? != 0 ]; then echo "Fatal Error mount aufs"; umount ${NAME_PREFIX}1; losetup -d $LODEV >/dev/null 2>&1; exit 1;fi

echo "Mount done, start subshell now on hte mount point. Copy and modify files under it."
echo "When done, type exit to exit this shell and I will continue "
( cd ${NAME_PREFIX}3 && /bin/bash )

cd $WORKDIR
rm -f out.sqs
if [ -z "$SQUASHFS_OPT" ]; then
	SQUASHFS_OPT="-comp xz -b 1024K"
	echo "Default SQUASHFS_OPT is  '-comp xz -b 1024K'"
fi
OUTDIR=${NAME_PREFIX}3
mksquashfs $OUTDIR out.sqs $SQUASHFS_OPT
umount ${NAME_PREFIX}3; sleep 3; umount ${NAME_PREFIX}1 >/dev/null 2>&1
if `ls /dev/mapper/${NAME_PREFIX}_DEC >/dev/null 2>&1`; then
	cryptsetup luksClose /dev/mapper/${NAME_PREFIX}_DEC
fi
if [ "$LODEV" ]; then losetup -d $LODEV; fi
if [ "$2" == 'enc' ]; then
	/opt/bin/squash2enc.sh out.sqs $SRCPATH $PASS # Given the existing module so we will use the existing luks
	mv out.sqs.enc out.sqs
fi
echo "run 'mv $WORKDIR/out.sqs ${SRCPATH}.new' ? y/n"
read a
if [ "$a" == 'y' ]; then mv $WORKDIR/out.sqs ${SRCPATH}.new; else echo "Output file is $WORKDIR/out.sqs";fi
rm -rf ${NAME_PREFIX}1 ${NAME_PREFIX}2 ${NAME_PREFIX}3 ${NAME_PREFIX}ENC ${NAME_PREFIX}D >/dev/null 2>&1
cd $CDIR
