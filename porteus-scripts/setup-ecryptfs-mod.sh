#!/bin/bash

export PATH=/bin:/sbin:/usr/bin:/usr/sbin:/opt/bin
find /mnt/live/memory/images/ -maxdepth 1 -type d -name "*.ecryptfs.xzm" > /tmp/ecryptfs.lst
for ENAME in `cat /tmp/ecryptfs.lst`; do
	DNAME="`basename $ENAME .ecryptfs.xzm`.xzm"
	rm -rf /mnt/live/memory/images/${DNAME} >/dev/null 2>&1
	mkdir /mnt/live/memory/images/${DNAME}
	mount -t proc none /proc
	mount -t sysfs none /sys
	mount -t ecryptfs -o key=passphrase:ecryptfs_cipher=aes:ecryptfs_key_bytes=16:ecryptfs_passthrough=n:ecryptfs_enable_filename_crypto=n:no_sig_cache $ENAME /mnt/live/memory/images/${DNAME}
	mount -t aufs -o remount,add:1:/mnt/live/memory/images/${DNAME}=rr none /
done
