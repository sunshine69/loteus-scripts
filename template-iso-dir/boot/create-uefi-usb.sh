#!/bin/bash

## create a UEFI compatible USB device with 100MB EPS and the rest for porteus

wrk=/home/guest/Downloads/efimods
template=https://dl.dropbox.com/s/1bsl2nqtfv1i01x/porteus-uefi-usb-template.tar.xz
kern000=https://dl.dropbox.com/s/9nrwswxk1av5gaz/000-uefi-kernel.xzm
modir=`ls -l /mnt/live/porteus/modules|awk '{print$NF}'`
portdir=${modir%/*}
## Check if user booted from ISO and make a change of path
if [ `echo "$modir"|grep -o isoloop` ]; then
  portdir=/mnt/live/mnt/isoloop/porteus
fi
basedir=${portdir}/base

## Cyan colored output
cyan() {
    echo -e "\033[01;36m$@\033[00m"
}

## Blue colored output
blue() {
    echo -e "\033[01;34m$@\033[00m"
}

## Magenta colored output
magenta() {
    echo -e "\033[01;35m$@\033[00m"
}

cleanup() {
for a in /tmp/.sanity /tmp/.links $wrk; do
    [ -f $a -o -d $a ] && rm -f $a 2>/dev/null
done
[ -d /home/guest/Downloads/efimods ] && rm -rf /home/guest/Downloads/efimods
}

##Make sure we are running porteus
if [ ! -d /mnt/live/porteus ]; then
    echo && echo "You can only run this script from a Porteus install"
fi

## If user didn't boot into a storage mode then exit
if [ `ls $basedir|grep -o 000-core.xzm` ]; then
    echo && magenta "You must boot into freshmode to run this script!"
    exit
      elif [ `file /mnt/live/porteus/modules|grep -o sbroken` ]; then
   echo && magenta "You can NOT run this scrip after booting from an ISO!"
    exit
fi

## Error
erro(){
echo
magenta "$1"
magenta "Exiting now"
cleanup
exit
}

## Sanity checks
check() {
which $1 2>/dev/null >&- || echo $1 >> /tmp/.sanity
}

check_quit(){
if [ "$1" == "q" -o "$1" == "quit" ];then cleanup; exit; fi
}

# Check if a website is online and working (silently)
# Returns url=0 if it is avaiable
check_url(){
if (wget -q --spider --force-html --inet4-only $1 >/dev/null 2>&1); then
    answ=0
    else
    answ=1
fi
}

format_p2(){
## Ask for filesystem of partition 2
echo
cyan "Please select a partition type for Porteus"
echo "[1] FAT32"
echo "[2] ext2"
echo "[3] ext3"
echo "[4] ext4"
echo
read -n1 ptype

case $ptype in
1 )
mkdosfs ${targ}2 ;;
2 )
mkfs.ext2 ${targ}2 ;;
3 )
mkfs.ext3 ${targ}2 ;;
4 )
mkfs.ext4 ${targ}2 ;;
* )
cyan "You must choose 1-4"
$FUNCNAME
;;
esac
}

format_usb(){
#parted /dev/sdd << 'EOF'
#mklabel msdos
#quit
#EOF

gdisk $targ << 'EOF'
o
y
n
1

+100M
ef00
n
2



w
y
EOF
# Format partition 1
mkdosfs ${targ}1
format_p2
}

[ -d $wrk ] && rm -rf $wrk
mkdir -p $wrk

################# BEGIN WORK



## Dump links file
cat >> /tmp/.links << EOF
https://dl.dropbox.com/s/pynrlyp87p6ipq3/gdisk-0.6.14-x86_64-1alien.xzm
EOF

echo
echo "#### WELCOME TO THE PORTEUS UEFI USB CREATOR ####"
echo "#### Type quit at any question to quit."
echo "Script by Brokenman"
echo

if [ `whoami` != "root" ]; then
  echo "You must be root to run this!!"
  exit
fi

## Sanity check
check gdisk

if [ -f /tmp/.sanity ]; then
    for pkg in `cat /tmp/.sanity`; do
        magenta "$pkg was not found and is required to continue"
        echo "Would you like to download it now [y/n]?"
        read -n1 downit
        if [ "$downit" == "y" -o "$downit" == "Y" ]; then
          echo
          for getit in `grep $pkg /tmp/.links`; do
            wget --no-check-certificate $getit -P $wrk
            file=${getit##*/}
            activate $wrk/$file
          done
            else
          erro "You do not have the required packages installed"
        fi
    done
fi
echo
blkid|grep "^/dev/.d."
echo
cyan "Above is a list of your partitions."
cyan "Please enter the base path to your target USB device."
echo "Example: /dev/sdc (no numbers)"
read -e -p "> " targ
check_quit $targ
targ=`tr -d [:digit:] <<<$targ`

## Safety check for USB device
target_base=${targ##*/}
grep ^  /sys/block/$target_base/removable || { echo "No removable device found. Exiting!"; exit; }
if [ `grep ^  /sys/block/$target_base/removable` -ne 1 ]; then
    erro "This does not appear to be a removable device."
      else
    echo "Target verified as removable"
fi

## Get info about USB device
TARG_UUID=`blkid | sed -n "/$target_base/s/.*UUID=\"\([^\"]*\)\".*/\1/p"`
echo
cyan "We will now format your USB $targ device with partition UUID's:"
echo "$TARG_UUID"
echo "MAKE SURE YOU ARE CERTAIN!!"
echo "Would you like to continue? [y/n]"
read form
echo
if [ "$form" == "y" -o "$form" == "Y" ]; then
  for a in /dev/${target_base}[0-9]; do umount $a; done
  format_usb
    else
  erro "User aborted"
  exit
fi

echo
cyan "We will now download the required files (20Mb)from the internet."
cyan "Make sure you have an internet connection before continuing."
echo "Press enter to continue"
read books
if [ "$books" == "quit" ]; then erro "User aborted"; exit; fi
wget --trust-server-name --no-check-certificate $template -P $wrk
wget --trust-server-name --no-check-certificate $kern000 -P $wrk
eps=${targ}1

## Make sure USB partitions are mounted
if [ ! `mount|grep -o ${targ}2` ]; then
    [ ! -d /mnt/${target_base}2 ] && mkdir /mnt/${target_base}2
    mount ${targ}2 /mnt/${target_base}2
fi
if [ ! `mount|grep -o ${targ}1` ]; then
    [ ! -d /mnt/${target_base}1 ] && mkdir /mnt/${target_base}1
    mount ${targ}1 /mnt/${target_base}1
fi

## Create EPS partition files
cyan "Creating EPS file structure ..."
cd /mnt/${target_base}1
tar xvf $wrk/porteus-uefi-usb-template.tar.xz
cd -

## Copy porteus files
echo
cyan "Copying porteus files ..."
cp -a $portdir /mnt/${target_base}2/ && cp -a $wrk/000-uefi-kernel.xzm /mnt/${target_base}2/porteus/base/000-kernel.xzm

## Get UUID of second USB partition
portpart=`blkid | sed -n "/$target_base/s/.*UUID=\"\([^\"]*\)\".*/\1/p"|tail -n1`

## Build custom porteus refind.conf
cat > /mnt/${target_base}1/EFI/BOOT/refind.conf << EOF
timeout 20
hideui label,editor,hints
icons_dir myicons
banner myicons/porteus-bootloader.bmp
use_graphics_for linux
showtools reboot, shutdown, exit
scan_driver_dirs EFI/tools/drivers_x64
scanfor manual,external
scan_all_linux_kernels
menuentry "Porteus" {
    icon EFI/BOOT/myicons/porteus-saved.png
        volume ext2
    loader /EFI/porteus/vmlinuz
    initrd /EFI/porteus/initrd.xz
    options "from=UUID:$portpart changes=/porteus volume=99%"
}

menuentry "Porteus RAM" {
    icon EFI/BOOT/myicons/porteus-ram.png
        volume ext2
    loader /EFI/porteus/vmlinuz
    initrd /EFI/porteus/initrd.xz
    options "from=UUID:$portpart copy2ram volume=99%"
}

menuentry "Porteus FRESH" {
    icon EFI/BOOT/myicons/porteus-fresh.png
        volume ext2
    loader /EFI/porteus/vmlinuz
    initrd /EFI/porteus/initrd.xz
    options "from=UUID:$portpart base_only nomagic norootcopy volume=99%"
}

menuentry "Porteus TEXT" {
    icon EFI/BOOT/myicons/porteus-text.png
        volume ext2
    loader /EFI/porteus/vmlinuz
    initrd /EFI/porteus/initrd.xz
    options "from=UUID:$portpart 3 volume=99%"
}
EOF

echo "Finishing installation ...."

## Prelim cleanup
for a in ${targ}[0-9]; do umount $a 2>/dev/null; done
cleanup

cyan "Your installation has finished!!"
cyan "Make sure you set your system to boot"
cyan "into UEFI mode and reboot now!"
exit
