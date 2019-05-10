#!/bin/bash

SOURCE="$1"
TARGET="$2"
echo "Starting to detect bootdata source location"
# losetup -a | grep 000 give us, 000 is the kernel mod module file name
# /dev/loop0: [2065]:12 (/mnt/sdb1/bootdata/centos7/base/000-kernelmod-4.0.2.xzm)
DETECT_SRC=`losetup -a | grep 000 | perl -pe 's|.*\(([^\(\)]+)/base[^\(\)]+\)|\1|'`
DETECT_SRC=`dirname $DETECT_SRC`
CHECK=`basename ${DETECT_SRC}`
if [ "${CHECK}" == 'copy2ram' ]; then
        DETECT_SRC=''
        echo 'Unable to detect, as boot to ram. You need to specify it manually. Mount the USB or CDROM disk under /mnt/cdrom and use /mnt/cdrom/bootdata as the source'
elif [ "${CHECK}" != 'bootdata' ]; then
        echo "Boot data folder name is not standard (bootdata). Remember to update the grub.cfg manually"
else
        echo "Source detected at $DETECT_SRC"
fi

help() {
        cat <<EOF
        Usage: $0 /path/to/data/source/folder /path/to/the/mounted/fs
        This script will install the live system into /path/to/the/mounted/fs such as /mnt/sda3. You need to partition the disk and make filesystem and mount it manually as I assume you are a geek! :-)
        /path/to/data/source/folder is where the folder that contains the root of the porteus live data is. Run command 'losetup -a' you can see. I will try to auto detect that and confirm with you.
It looks like your /path/to/datasource is:
$DETECT_SRC

If you already have disk partitoned and boot this sytem from usb or live cd then there are already mounted under /mnt. Below if the output of df -h
EOF
        df -h
        exit 1
}

if [ -z "$TARGET" ]; then
        help
fi

if [ "$SOURCE" != "$DETECT_SRC" ]; then
        echo "I detect your source folder is: ${DETECT_SRC}. Are you sure to use ${SOUCE} ? y/n"
        read ans
        if [ $ans != 'y' ]; then echo Aborted ; exit 1; fi
fi

echo "Copy ${SOURCE} to ${TARGET}"
# remove the last slash / if given
SOURCE="`echo $SOURCE | perl -pe 's|[\/]+$||'`"
cp -a $SOURCE ${TARGET}/
# hardcoded the dir name bootdata, it is in the grub.cfg so we do not need to edit them.
if [ ! -d ${TARGET}/bootdata ]; then mv ${TARGET}/`basename ${SOURCE}` ${TARGET}/bootdata; fi

# If we install on USB we already should use the Porteus install script inspead. For HD it should always be /dev/sda.
DEV='/dev/sda'
echo "Install grub boot loader to ${DEV}? Say y to use it, type other /dev/sdX if you want to change or n to abort. y/n"
read ans
if [ $ans == 'n' ]; then echo Aborted ; exit 1; fi
if [ $ans != 'y' ]; then DEV="$ans" ; fi

grub2-install --boot-directory=${TARGET} $DEV
if [ "$?" == '0' ]; then
        cp -a /boot/grub.cfg ${TARGET}/grub2/
        echo You can check and edit the grub config file ${TARGET}/grub2/grub.cfg to customize. It is not needed for standard install.
fi

echo "Where is your 'changes' directory? This is used to keep the changes you made into the system to survive after reboot. To do factoryreset just select the second boot grub menu and it will clear the content of this folder. This should be at the first level of the filesystem and the filesystem must be posix compliant (can be used as Linux root filesystem)"
echo
echo "Enter the path so I will do a mkdir $PATH/changes. If you hit enter then I will do mkdir ${TARGET}/changes"
read path
if [ ! -z "$path" ]; then
        mkdir ${path}/changes
else
        mkdir ${TARGET}/changes
fi
echo
echo "Now you can remove the cdrom/usb boot media and type reboot."
echo "When login you need to configure enable the folowing services and also start them"
echo "edit /etc/init.d/docker specify where your docker data folder would be"
echo "edit /etc/init.d/swarm specify where your master jenkins should be and swarm user and password"
echo "chkconfig jenkins-scripts on; systemctl start jenkins-scripts"
echo "chkconfig ci-client on; systemctl start ci-client"
echo
echo "Installation to disk completed. "

