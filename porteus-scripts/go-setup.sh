#!/bin/sh -x
# dev having the gocryptfs data
setup_dev=${1:-sda3}
# dev used as raw device (enc)
blk_dev=${2:-sda4}
# dev contains the port OS folder
data_dev=${3:-$setup_dev}


value() { egrep -o " $1=[^ ]+" /proc/cmdline | cut -d= -f2; }

echo "setup_dev: $setup_dev blk_dev: $blk_dev data_dev: $data_dev"

if [ ! -d /mnt/$setup_dev ]; then
    mkdir /mnt/$setup_dev
fi

mount /dev/$setup_dev /mnt/$setup_dev || (echo "error mount setup_dev, aborting" && exit 1)

[ ! -d /mnt/${setup_dev}/goe ] && echo "goe dir not found" && ( umount /mnt/${setup_dev}; exit 1 )

mkdir /mnt/${setup_dev}/goem >/dev/null 2>&1

gocryptfs /mnt/${setup_dev}/goe /mnt/${setup_dev}/goem

PASS_FILE_NAME=$(value hostname)-pass.dat
if [ ! -f /mnt/${setup_dev}/goem/${PASS_FILE_NAME} ]; then PASS_FILE_NAME=blk.dat; fi
p=$(cat /mnt/${setup_dev}/goem/${PASS_FILE_NAME})

PASSPHRASE=$p setup_disk_output=$(setup-disk.sh $blk_dev)

if $(grep mapper $setup_disk_output >/dev/null 2>&1); then
  mkdir /mnt/$(basename $setup_disk_output)
  mount $setup_disk_output /mnt/$(basename $setup_disk_output)
  if [ "$?" = "0" ]; then
      src_data_dir=/mnt/$(basename $setup_disk_output)
  else
      src_data_dir=/mnt/$data_dev
      mkdir $src_data_dir
  fi
else
    src_data_dir=$setup_disk_output
fi

if [ "$src_data_dir" = "/mnt/$data_dev" ]; then echo "src data same as data nothing to do. exiting"; exit 0; fi

mount /dev/$data_dev /mnt/$data_dev

copyfile() {
    _src=$1
    _dest=$2
    if [ -z "$_src" ]; then echo "empty srcfile"; return; fi
    if [ ! -f $_dest ]; then
        cp -a ${_src} ${_dest}
    else
        if [ $(stat -c %Y $_src) -gt $(stat -c %Y $_dest) ]; then
            cp -a ${_src} ${_dest}
        fi
    fi
    if [ "$?" != "0" ]; then echo "ERROR" ; exit 1 ; fi
}

if [ $(value reset) = "1" ]; then
      from=$(value from)
      os=$(value os)
      kver=$(uname -r)
      srckmodfile=$(find ${src_data_dir}/*/000-${kver}.xzm)
      destkmodfile=$(find /mnt/${data_dev}/${from}/000-${kver}.xzm)
      copyfile $srckmodfile $destkmodfile
      srcfile=$(find ${src_data_dir}/*/${os}/base/001-*${os}-x86_64.zzm)
      destfile=/mnt/${data_dev}/${from}/${os}/base/$(basename ${srcfile})
      copyfile $srcfile $destfile
      src_share_file=$(find /mnt/${setup_dev}/*/share/002-*${os}-*x86_64.zzm)
      dest_share_file=$(find /mnt/${data_dev}/${from}/share/002-*${os}-*x86_64.zzm)
      copyfile $src_share_file $dest_share_file
      umount /dev/$data_dev
      # hardcoded section
      outfile=$(find ${src_data_dir}/out.sqs ${src_data_dir}/tmp/out.sqs 2>/dev/null | tail -n1)
      if [ ! -z "$outfile" ] && [ -f "$outfile" ] && [ $(stat -c %Y $outfile) -gt $(stat -c %Y /mnt/${data_dev}/${from}/${os}/base/001-ubuntu-focal-x86_64.zzm) ]; then
          echo "Copy out.sqs from ${src_data_dir} to current ${data_dev}.."
          cp ${outfile} /mnt/${data_dev}/${from}/${os}/base/001-ubuntu-focal-x86_64.zzm
      fi
fi

umount -l /mnt/${setup_dev}/goem
umount -l /mnt/${setup_dev}
