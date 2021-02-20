#!/bin/bash

SRC=$1

[ -z "$SRC" ] && echo "Usage: $0 <image_file> [work_dir|pwd] [enc] [enc password]" && exit 1

[ -z "$WORKDIR" ] && WORKDIR=$(pwd)

ENC=$3
PASS=$4

NAME_PREFIX='update_mod'

CDIR=`pwd`; cd $WORKDIR; rm -rf ${NAME_PREFIX}1 ${NAME_PREFIX}2 ${NAME_PREFIX}3 ${NAME_PREFIX}-wd >/dev/null 2>&1; mkdir ${NAME_PREFIX}1 ${NAME_PREFIX}2 ${NAME_PREFIX}3 ${NAME_PREFIX}-wd >/dev/null 2>&1

SRCPATH="`realpath $SRC`"

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

#mount -t aufs none ${NAME_PREFIX}3 -o br=${NAME_PREFIX}2=rw:${NAME_PREFIX}1=ro
mount -t overlay overlay -o lowerdir=${NAME_PREFIX}1,upperdir=${NAME_PREFIX}2,workdir=${NAME_PREFIX}-wd ${NAME_PREFIX}3


if [ $? != 0 ]; then echo "Fatal Error mount layered fs"; umount ${NAME_PREFIX}1; losetup -d $LODEV >/dev/null 2>&1; exit 1;fi

echo "Mount done, start subshell now on the mount point. Copy and modify files under it."

if [ ! -z "$2" ]; then
    echo "When done, type exit to exit this shell and I will continue "
    ( cd ${NAME_PREFIX}3 && /bin/bash )
else
    echo "will execute script in the dir ${NAME_PREFIX}3"
    ( cd ${NAME_PREFIX}3 && /bin/bash $2 )
fi

cd $WORKDIR
rm -f out.sqs
if [ -z "$SQUASHFS_OPT" ]; then
	# Best balance now seems to be lz4 -Xhc. The zstd is good to built rescue but level 19 is too slow
	SQUASHFS_OPT="-comp zstd -Xcompression-level 15"
	#SQUASHFS_OPT="-comp lz4 -Xhc -b 1024K"
	#SQUASHFS_OPT="-b 1024K"
	echo "Default SQUASHFS_OPT is '$SQUASHFS_OPT' - fast enough and good compression"
	echo "0. -comp lz4 -Xhc -b 1024K - Fast to compress/decompress, size is bugger the zstd. Small memory"
	echo "1. -comp zstd -b 1024K -Xcompression-level 19 - good compress but compress slow"
	echo "2. -comp gzip -b 1M - bigger size than zstd"
	echo "3. -comp xz -b 1M - compress best but slowest"
	echo "Enter your selection as number or your own option string. Hit enter to choose default"
	read ans
	case "$ans" in
		0)
			SQUASHFS_OPT="-comp lz4 -Xhc";
			;;
		1)
			SQUASHFS_OPT="-comp zstd -Xcompression-level 19";
			;;
		2)
			SQUASHFS_OPT="-comp gzip";
			;;
		3)
			SQUASHFS_OPT="-comp xz";
			;;
		*)
			if [ ! -z "$ans" ]; then SQUASHFS_OPT="$ans"; fi
			echo "Use '$SQUASHFS_OPT'"
	esac
fi

OUTDIR=${NAME_PREFIX}3
mksquashfs $OUTDIR out.sqs $SQUASHFS_OPT

umount ${NAME_PREFIX}3; sleep 3; umount ${NAME_PREFIX}1 >/dev/null 2>&1

if `ls /dev/mapper/${NAME_PREFIX}_DEC >/dev/null 2>&1`; then
	cryptsetup luksClose /dev/mapper/${NAME_PREFIX}_DEC
fi

if [ "$LODEV" ]; then losetup -d $LODEV; fi
if [ "$ENC" == 'enc' ]; then
	/opt/bin/squash2enc.sh out.sqs $SRCPATH $PASS # Given the existing module so we will use the existing luks
	mv out.sqs.enc out.sqs
fi
echo "run 'mv $WORKDIR/out.sqs ${SRCPATH}.new' ? y/n"
read a
if [ "$a" == 'y' ]; then mv $WORKDIR/out.sqs ${SRCPATH}.new; else echo "Output file is $WORKDIR/out.sqs";fi
rm -rf ${NAME_PREFIX}1 ${NAME_PREFIX}2 ${NAME_PREFIX}3 ${NAME_PREFIX}-wd ${NAME_PREFIX}ENC ${NAME_PREFIX}D >/dev/null 2>&1
cd $CDIR
