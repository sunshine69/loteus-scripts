#!/bin/sh
export PATH=/opt/bin:$PATH

cd /mnt/portdata/tmp || exit 1

echo 2 > /sys/module/hid_apple/parameters/fnmode
activate /mnt/nvme0n1p3/port-modules/002-ubuntu-devtool-x86_64.xzm
[ ! -d /mnt/portdata/docker ] && mkdir -p /mnt/portdata/docker
if `pidof dockerd >/dev/null 2>&1`; then
    echo "docker already started"
else
    dockerd --data-root /mnt/portdata/docker >/dev/null 2>&1 &
    mkdir -p /mnt/portdata/var-lib-lxc /mnt/portdata/var-cache-lxc >/dev/null 2>&1
    mount -o bind /var/lib/lxc /mnt/portdata/var-lib-lxc
    mount -o bind /var/cache/lxc /mnt/portdata/var-cache-lxc
fi

HOST_LINE="192.168.20.25 note.kaykraft.org tech.kaykraft.org www.kaykraft.org kaykraft.org git.kaykraft.org"
if `grep "${HOST_LINE}" /etc/hosts >/dev/null 2>&1`; then
        if `ping -c 1 192.168.20.1 >/dev/null 2>&1`; then
            mkdir -p /mnt/doc >/dev/null 2>&1
            sed -i "s/^#${HOST_LINE}/${HOST_LINE}/g" /etc/hosts
	        SMBPASS=$(cat /home/stevek/.smb-pass)
            [ ! -d /mnt/doc/opc-backup ] && mount //192.168.20.25/doc /mnt/doc -o username=stevek,password=$SMBPASS,uid=stevek,gid=stevek
        else
            sed -i "s/^${HOST_LINE}/#${HOST_LINE}/g" /etc/hosts
        fi
else
        echo "${HOST_LINE}" >> /etc/hosts
fi

