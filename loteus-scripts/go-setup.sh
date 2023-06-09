#!/bin/sh

# Usage $0 <setup device> <encrypted dev>
# <setup dev> must have the goe and goem dir contains gocryptfs data
# in there there is a <host name>-pass.dat and <host name>-luks.dat files. If
# there files are not found it will prompt for pass and use the luks plain
# encryption

# If arg 3 exists then it will use as data dev otherwise it will be setup dev
# as data dev. data dev is device contains the porteus OS compress image which
# does not need to be encrypted.

# If first arg is like sda3/somefilename then it will mount the sda3 device and use the a file `somefilename` as loop device to find out teh final encryption data. If the loop device is a luk RAW image itself it will use the pass key prompt to decrypt it.

# During the run it will try to update the system images from the <source data dir> to the <data dev> based on timestamp and a exists of the fime out.sqs. <source data dir> is the unencrypted device if it is mountable otherwise it will fall back to the <setup dev>
###########

value() { egrep -o " $1=[^ ]+" /proc/cmdline | cut -d= -f2; }
param() { egrep -qo " $1( |\$)" /etc/cmdline; }

if param debug; then set -x; fi

# dev having the gocryptfs data. The update file source uses this dev. Priority 2
setup_dev=${1:-sda3}
# dev used as raw device (enc). Also used as source of update. Priority 1
blk_dev=${2:-sda4}
# dev contains the port OS folder
data_dev=${3:-$setup_dev}

setup_raw() {
    # $1 is like /mnt/${device}/${loop_file}
    LOOP_DEV=$(losetup -f)
    losetup $LOOP_DEV $1
    echo "****"
    read -s p
    echo $p | cryptsetup --key-file=- plainOpen $LOOP_DEV testme
    [ "$data_dev" = "$setup_dev" ] && data_dev=$device
    setup_dev=mapper/testme
}

umount_all() {
    umount /mnt/${setup_dev_mnt}/goem >/dev/null 2>&1 || true
    if ! $(echo $src_data_dir | grep blkm >/dev/null 2>&1); then umount -l $src_data_dir || true; fi
    if $(echo $src_data_dir | grep '_DEC' >/dev/null 2>&1); then
        umount $src_data_dir
        rmdir $src_data_dir
    fi
    umount -l /mnt/$data_dev|| true
    umount -l /mnt/$setup_dev_mnt || true
}

loop_file=$(echo $setup_dev | sed 's|/dev/||' | cut -f 2 -d/)
device=$(echo $setup_dev | sed 's|/dev/||' | cut -f 1 -d/)
if [ ! -z "$loop_file" ]; then
    mkdir /mnt/$device >/dev/null 2>&1
    mount /dev/$device /mnt/$device
    if [ -f /mnt/${device}/${loop_file} ]; then
        setup_raw /mnt/${device}/${loop_file}
    else
        umount -l /mnt/$device && sleep 2 && rmdir /mnt/$device
    fi
fi

echo "setup_dev: $setup_dev blk_dev: $blk_dev data_dev: $data_dev"

setup_dev_mnt=$(basename $setup_dev)
if [ ! -d /mnt/$setup_dev_mnt ]; then
    echo "creating setup dev /mnt/$setup_dev_mnt"
    mkdir /mnt/$setup_dev_mnt
fi

if [ "$data_dev" != "$setup_dev" ] && [ ! -d /mnt/$data_dev ]; then
    echo "creating data dev and mount /dev/$data_dev /mnt/$data_dev"
    mkdir /mnt/$data_dev
    mount /dev/$data_dev /mnt/$data_dev
fi

mount /dev/$setup_dev /mnt/$setup_dev_mnt || (umount_all ; echo "error mount setup_dev, aborting" && exit 1)

if [ -d /mnt/${setup_dev_mnt}/goe ]; then
    mkdir /mnt/${setup_dev_mnt}/goem >/dev/null 2>&1
    while [ "$SUCCESS" != "yes" ]; do
        gocryptfs /mnt/${setup_dev_mnt}/goe /mnt/${setup_dev_mnt}/goem
        if [ "$?" = "0" ]; then SUCCESS="yes"; fi
    done
    SEC_DIR=/mnt/${setup_dev_mnt}/goem
else
    SEC_DIR=/mnt/${setup_dev_mnt}
fi

echo "SEC_DIR: $SEC_DIR"

PASS_FILE_NAME=$(value hostname)-pass.dat
LUKS_HEADER_FILE=$(value hostname)-luks.dat
if [ ! -f ${SEC_DIR}/${PASS_FILE_NAME} ]; then
    if [ -f ${SEC_DIR}/blk.dat ]; then
        PASS_FILE_NAME=blk.dat
    else
        echo "****"
        read -s p
    fi
fi
[ -f "${SEC_DIR}/$PASS_FILE_NAME" ] && p=$(cat ${SEC_DIR}/${PASS_FILE_NAME} 2>/dev/null)

if [ -f "${SEC_DIR}/${LUKS_HEADER_FILE}" ]; then
    EXTOPTS="--header ${SEC_DIR}/${LUKS_HEADER_FILE}"
    export FORCE_LUKS=y
fi

export PASSPHRASE=$p
echo "going to run setup-disk.sh $blk_dev ${EXTOPTS}"
setup_disk_output=$(setup-disk.sh $blk_dev ${EXTOPTS} | tail -n1)

if $(echo $setup_disk_output | grep mapper >/dev/null 2>&1); then
  mkdir /mnt/$(basename $setup_disk_output)
  mount $setup_disk_output /mnt/$(basename $setup_disk_output)
  if [ "$?" = "0" ]; then
      src_data_dir=/mnt/$(basename $setup_disk_output)
  else
      src_data_dir=/mnt/$setup_dev_mnt
      [ ! -d "$src_data_dir" ] && mkdir $src_data_dir
  fi
else
    src_data_dir=$setup_disk_output
fi

echo "src_data_dir for update source: $src_data_dir - Enter new value if required otherwise hit enter to accept that value "
read _ans

[ ! -z "$_ans" ] && src_data_dir=${_ans}

if [ "$src_data_dir" = "/mnt/$data_dev" ]; then echo "src data same as data nothing to do. exiting"; umount_all; exit 0; fi

if ! mount | grep "/mnt/$data_dev" >/dev/null 2>&1; then
    mount /dev/$data_dev /mnt/$data_dev
fi

copyfile() {
    _src=$1
    _dest=$2
    if [ -z "$_src" ]; then echo "empty srcfile"; return; fi
    if [ ! -f $_dest ]; then
        cp -a ${_src} ${_dest}
    else
        if [ $(stat -c %Y $_src) -gt $(stat -c %Y $_dest) ]; then
            rm -f $_dest
            cp -a ${_src} ${_dest}
        fi
    fi
    if [ "$?" != "0" ]; then echo "ERROR" ; umount_all; exit 1 ; fi
}

detect_mod_filename() {
    _fname_ptn=$1
    srcfile=$(find ${src_data_dir}/*/${os}/base/${_fname_ptn} 2>/dev/null)
    if [ -z "$srcfile" ]; then
        srcfile=$(find ${data_dev}/*/${os}/base/${_fname_ptn} 2>/dev/null)
    fi
    echo $srcfile
}

if [ $(value reset) = "1" ]; then
      from=$(value from)
      os=$(value os)
      kver=$(uname -r)
      srckmodfile=$(find ${src_data_dir}/*/000-${kver}.??m >/dev/null)
      destkmodfile=$(find /mnt/${data_dev}/${from}/000-${kver}.??m 2>/dev/null)
      copyfile $srckmodfile $destkmodfile
      srcfile=$(find ${src_data_dir}/*/${os}/base/001-*-x86_64.??m 2>/dev/null)
      echo "srcfile: '$srcfile'"
      if [ ! -z "$srcfile" ]; then
        destfile=/mnt/${data_dev}/${from}/${os}/base/$(basename ${srcfile})
        copyfile $srcfile $destfile
      fi
      src_share_file=$(find /mnt/${setup_dev}/*/share/002-*${os}-*x86_64.??m)
      dest_share_file=$(find /mnt/${data_dev}/${from}/share/002-*${os}-*x86_64.??m)
      copyfile $src_share_file $dest_share_file
      umount /dev/$data_dev
      # hardcoded section
      outfile=$(find ${src_data_dir}/out.sqs ${src_data_dir}/tmp/out.sqs 2>/dev/null | tail -n1)
      if [ ! -z "$outfile" ] && [ -f "$outfile" ]; then
          if [ -z "$srcfile" ]; then
              srcfile=$(find /mnt/${data_dev}/${from}/${os}/base/001-*.??m 2>/dev/null)
              echo "srcfile: '$srcfile'"
          fi
          destfile=/mnt/${data_dev}/${from}/${os}/base/$(basename $srcfile)
          echo "Copy out.sqs from ${outfile} to current $destfile .."
          cp ${outfile} $destfile
      fi
fi

umount_all
