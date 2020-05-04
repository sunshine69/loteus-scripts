#!/bin/bash

export INSTALL_MOD_PATH=/var/tmp/kernel-build

if [ -z "$KSOURCE_DIR" ]; then
    KSOURCE_DIR=$(pwd)
    KSOURCE_DIR=$(dirname $KSOURCE_DIR)
fi

if [ -z "$VERSION" ]; then
    SUBLEVEL=$(grep -oP '(?<=SUBLEVEL \= )([\d]+)' Makefile)
    VERSION=$(grep -oP '(?<=VERSION \= )([\d]+)' Makefile)
    PATCHLEVEL=$(grep -oP '(?<=PATCHLEVEL \= )([\d]+)' Makefile)
    LOCAL_VER=$(grep -Po '(?<=CONFIG_LOCALVERSION=")([^"]+)' .config)
    [ -z "$VERSION" ] && echo "Can not detect VERSION. You need to run this script inside the kernel source tree" && exit 1
fi

build_external_module() {
    pushd .
    export KERNELRELEASE=$KVER
    cd /home/stevek/src/bcwc_pcie
    if [ -z "$KDIR" ]; then
        export KDIR="$KSOURCE_DIR/linux-${VERSION}.${PATCHLEVEL}"
    else
        export KDIR="$KDIR"
    fi
    echo "Build bcwc_pcie with KDIR: $KDIR"
    read _junk
    make
    make install
    popd
}

#KVER=$1
CDIR=`pwd`
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
. $SCRIPT_DIR/common.sh

PORTEUS_INSTALL_KERNEL_SCRIPT=$SCRIPT_DIR/porteus-install-kernel.sh

mkdir -p $TARGET_DIR >/dev/null
OLDKERNEL=no
# replace it with dir name unter the arch/ folder, not the output of arch cmd
if [ ! "$ARCH" ]; then
ARCH=`arch`
fi

KVER=`cat $CDIR/include/generated/utsrelease.h | perl -ne '/[^"]+"([^"]+)"/ && print $1  '`
echo "DEBUG '$KVER'"
if [ "$KVER" = "" ] || [ "$KVER" = "-" ] ; then
	KVER=`cat $CDIR/include/linux/utsrelease.h | grep 'UTS_RELEASE' | perl -ne '/[^"]+"([^"]+)"/ && print $1  '`
	echo "DEBUG '$KVER'"
	echo "Old kernel detected - $KVER"
	OLDKERNEL=yes
fi
if [ "$KVER" = "" ] || [ "$KVER" = '-' ] ; then
echo "Error. Maybe you are not in the kernel source build"
echo "Kernel version not found in $CDIR/include/generated/utsrelease.h"
exit 1
fi

if [ "$KVER" = "" ] || [ "$KVER" = '-' ]; then
echo "Fatal Error. No KVER found!"
exit
fi
if [ ! -d ${INSTALL_MOD_PATH}/$KVER ]; then
        make modules_install
        build_external_module
else
    echo "${INSTALL_MOD_PATH}/$KVER exists. Maybe you are building the kernel version same as current version."
    echo "Continue? y/n"
    read _confirm
    if [ $_confirm = 'n' ]; then exit 1; fi
fi

echo "Done make modules_install"

cd $CDIR

mkdir -p $TARGET_DIR/kernel-$KVER/

cp -a System.map $TARGET_DIR/kernel-$KVER/
case "$ARCH" in
'i386'|'i686'|'amd64'|'x86_64')
	cp -L arch/x86/boot/*zImage $TARGET_DIR/kernel-$KVER/
	;;
*)
	cp -L arch/$ARCH/boot/*zImage $TARGET_DIR/kernel-$KVER/
	;;

esac
#gzip -c .config > $TARGET_DIR/kernel-$KVER/config-${KVER}.gz
#gzip /boot/config-$KVER
#mv /boot/config-${KVER} $TARGET_DIR/kernel-$KVER/

rm -rf $TARGET_DIR/kernel-$KVER/$KVER
mv ${INSTALL_MOD_PATH}/lib/modules/$KVER $TARGET_DIR/kernel-$KVER/
rm -f /mnt/live/memory/changes/rootdir/lib/modules/$KVER

echo "Done "
echo "Create install script ..."
cat <<EOF > $TARGET_DIR/kernel-$KVER/install-$KVER.sh
#!/bin/bash
scriptname=\`basename \$0\`
KVER="$KVER"
if [ "\$scriptname" == "remove-\${KVER}.sh" ]; then
	rm -f /boot/*-\${KVER}
	rm -f /boot/remove-\${KVER}.sh
	rm -rf /lib/modules/\$KVER
	rm -rf /usr/src/linux-headers-\$KVER
	update-grub2
	if [ "\$?" != "0" ]; then update-grub ; fi
	if [ "\$?" != "0" ]; then
		which grub2-mkconfig >/dev/null 2>&1
		if [ "\$?" == "0" ]; then
		  grub2-mkconfig -o /boot/grub2/grub.cfg
		fi
	fi
	if [ "\$?" != "0" ]; then echo "Warning. can not update-grub. You need to manually edit grub entry"; fi
	echo "Removed \$KVER completed"
else
	rm -rf /lib/modules/\$KVER
	mv \$KVER /lib/modules/
	rm -rf /usr/src/linux-headers-\${KVER}
	mv linux-headers-\${KVER} /usr/src/
	rm -f /lib/modules/\$KVER/build
	ln -sf /usr/src/linux-headers-\${KVER} /lib/modules/\$KVER/build
	mv *zImage /boot/vmlinuz-\$KVER
	mv System.map /boot/System.map-\$KVER
	mv *\$KVER /boot/
	ln -sf /usr/src/linux-headers-\${KVER}/.config /boot/config-\${KVER}
	depmod \$KVER
	which update-initramfs
	if [ "\$?" == "0" ]; then
		rm -f /boot/initrd*\$KVER
		update-initramfs -k \$KVER -c
	else
		which mkinitrd
		if [ "\$?" == "0" ]; then
			rm -f /boot/initramfs-\$KVER
			mkinitrd /boot/initramfs-\$KVER \$KVER
		fi
	fi
	if [ -f "/usr/lib/dkms/dkms_autoinstaller" ]; then
		echo "Start dkms_autoinstaller"
		/usr/lib/dkms/dkms_autoinstaller start \$KVER >/dev/null
		depmod \$KVER
	fi
	update-grub2
	if [ "\$?" != "0" ]; then update-grub ; fi
        if [ "\$?" != "0" ]; then
	  if \`which grub2-mkconfig >/dev/null 2>&1\`; then
	    mv /boot/initramfs-\$KVER /boot/initramfs-\$KVER.img
	    grub2-mkconfig -o /boot/grub2/grub.cfg
	  fi
	fi
	if [ "\$?" != "0" ]; then echo "Warning. can not update-grub. You need to manually edit grub entry"; fi
	( cd /usr/src/linux-headers-\$KVER ; make scripts )
	rm -f /lib/modules/\$KVER/source ; ln -sf /usr/src/linux-headers-\$KVER /lib/modules/\$KVER/source
	cp install-\$KVER.sh /boot/remove-\$KVER.sh
	chmod +x /boot/remove-\$KVER.sh
	cd ../
	rm -rf kernel-\$KVER
fi
echo "Done"
EOF
chmod +x $TARGET_DIR/kernel-$KVER/install-${KVER}.sh
PKGTYPE="$1"
echo "Done install script\nPackage type is $PKGTYPE"
case "$PKGTYPE" in
'deb')
	echo "Building debian kernel pkg"
	mkdir -p  $TARGET_DIR/kernel-$KVER/DEBIAN
	mkdir -p $TARGET_DIR/kernel-$KVER/boot
	mkdir -p $TARGET_DIR/kernel-$KVER/lib/modules
	mkdir -p $TARGET_DIR/kernel-$KVER/usr/src
	mv $TARGET_DIR/kernel-$KVER/bzImage $TARGET_DIR/kernel-$KVER/boot/vmlinuz-$KVER
	mv $TARGET_DIR/kernel-$KVER/System.map $TARGET_DIR/kernel-$KVER/boot/System.map-$KVER
	mv $TARGET_DIR/kernel-$KVER/config* $TARGET_DIR/kernel-$KVER/boot/
	mv $TARGET_DIR/kernel-$KVER/initrd* $TARGET_DIR/kernel-$KVER/boot/
	mv $TARGET_DIR/kernel-$KVER/$KVER $TARGET_DIR/kernel-$KVER/lib/modules
	mv $TARGET_DIR/kernel-$KVER/linux-headers-$KVER $TARGET_DIR/kernel-$KVER/usr/src/
	rm -f $TARGET_DIR/kernel-$KVER/lib/modules/$KVER/build && ln -sf /usr/src/linux-headers-$KVER $TARGET_DIR/kernel-$KVER/lib/modules/$KVER/build
	rm -f $TARGET_DIR/kernel-$KVER/install-${KVER}.sh

	if [ "$ARCH" == 'x86_64' ]; then ARCH=amd64; fi

	cat <<EOF > $TARGET_DIR/kernel-$KVER/DEBIAN/control
	Package: linux-image-custom-$KVER
	Version: $KVER
	Section: base
	Priority: optional
	Architecture: $ARCH
	Depends: coreutils, initramfs-tools, module-init-tools
	Maintainer: Steve Kieu <steve.kieu@m5networks.com.au>
	Description: linux kernel custom built.
	EOF
	cat <<EOF > $TARGET_DIR/kernel-$KVER/DEBIAN/postinst
	#!/bin/bash
	# set -e

	if [ "\$1" != "configure" ]; then
		exit 0
	fi
	depmod $KVER
	which update-initramfs
	if [ "\$?" == "0" ]; then
		echo "Update initramfs"
		rm -f /boot/initrd*$KVER
		update-initramfs -k $KVER -c
	fi
	if [ -f "/usr/lib/dkms/dkms_autoinstaller" ]; then
		echo "Start dkms_autoinstaller"
		/usr/lib/dkms/dkms_autoinstaller start $KVER >/dev/null
		depmod $KVER
	fi
	which update-grub2
		if [ "\$?" == "0" ]; then
		update-grub2
	else
		which update-grub
		if [ "\$?" == "0" ]; then
			update-grub
		fi
	fi
        echo "rebuild scripts tools"
	( cd /usr/src/linux-headers-$KVER ; make scripts )
	exit 0

	EOF

	chmod 0555 $TARGET_DIR/kernel-$KVER/DEBIAN/postinst

	cat <<EOF > $TARGET_DIR/kernel-$KVER/DEBIAN/postrm
	#!/bin/sh
	if [ "\$1" == "remove" ]; then
		update-grub2
		if [ "\$?" != '0' ]; then update-grub ; fi
	fi

EOF
	chmod 0555 $TARGET_DIR/kernel-$KVER/DEBIAN/postrm

	dpkg-deb --build --nocheck $TARGET_DIR/kernel-$KVER
	mv $TARGET_DIR/kernel-$KVER.deb $TARGET_DIR/linux-image-custom-${KVER}_${KVER}_${ARCH}.deb
	echo "package $TARGET_DIR/linux-image-custom-${KVER}_${KVER}_${ARCH}.deb ready"
	;;

'lzma'|'tlzma')
	echo "Creating tar.lzma kernel package ..."
	cd $TARGET_DIR
	TARGET="kernel-$KVER.tar.lzma"
	CPUS=`cat /proc/cpuinfo | grep processor | wc -l`
	which threadzip.py
	if [ "$?" == '0' ] && [ "$PKGTYPE" == 'tlzma' ]; then
		echo "Detect threadzip.py, use $CPUS cpus"
		TARGET="kernel-$KVER.tar.tlzma"
		COMP="threadzip.py --lzma -t $CPUS"
	else
		COMP="lzma -9 -c -T $CPUS"
	fi
	;;

'xz')
	echo "Creating tar.$PKGTYPE kernel package ..."
	cd $TARGET_DIR
	TARGET="kernel-$KVER.tar.$PKGTYPE"
	CPUS=`cat /proc/cpuinfo | grep processor | wc -l`
	which threadzip.py
	if [ "$?" == '0' ] && [ "$PKGTYPE" == 'tlzma' ]; then
		echo "Detect threadzip.py, use $CPUS cpus"
		TARGET="kernel-$KVER.tar.tlzma"
		COMP="threadzip.py --lzma -t $CPUS"
	else
		COMP="xz -9 -c -T $CPUS"
	fi
	;;

'gz'|'bz2'|'bzip2')
	echo "Creating $PKGTYPE kernel package ..."
	cd $TARGET_DIR
	TARGET="kernel-$KVER.tar.$PKGTYPE"
	if [ "$PKGTYPE" == 'gz' ]; then
		which pigz
		if [ "$?" == '0' ]; then
			COMP='pigz -c -'
		else
			COMP='gzip -c -'
		fi
	else
           	which pbzip2
                if [ "$?" == '0' ]; then
                        COMP='pbzip2 -c -'
                else
                        COMP='bzip2 -c -'
                fi
	fi
	;;
*)
	echo "Unknown pacakge type $PKGTYPE. Will create gz"
		which pigz # yuk lazy :-)
                if [ "$?" == '0' ]; then
                        COMP='pigz -c -'
                else
                        COMP='gzip -c -'
                fi
esac
echo Skipping creating tar ball for now
#tar -cf - kernel-$KVER | $COMP > $TARGET

echo "generate the xzm modules"
cd kernel-$KVER
rm -rf porteus-kernel
mkdir porteus-kernel

cp -a $PORTEUS_INSTALL_KERNEL_SCRIPT porteus-kernel/porteus-install-kernel.sh; chmod +x porteus-kernel/porteus-install-kernel.sh
cp -a $SCRIPT_DIR/common.sh porteus-kernel/common.sh
echo "export KVER=${KVER}" >> porteus-kernel/common.sh

mv bzImage porteus-kernel/

cd porteus-kernel
mkdir -p 1/lib/modules
mv ../$KVER 1/lib/modules/
( cd 1/lib/modules/${KVER}/ ; rm -f build ; ln -sf /usr/src/linux-headers-$KVER build )
rm -f 000-${KVER}.xzm
mksquashfs 1 000-${KVER}.xzm -comp xz -b 1M
rm -rf 1

echo "Create new initrd.xz"

INITRD_PATH=$(echo $BOOT_DIR|cut -f1 -d' ')
echo "INITRD_PATH to search for input initrd.xz:  '$INITRD_PATH'"
KBUILDDIR_ENV=$(pwd) KVERS="$KVER" $SCRIPT_DIR/rebuild-initrd.sh "$INITRD_PATH/initrd.xz" "$(pwd)/initrd.xz"

echo "Create kernel source module ..."

echo "going to run ${SCRIPT_DIR}/create-kernel-src.sh ${KSOURCE_DIR}/linux-${VERSION}.${PATCHLEVEL} ${TARGET_DIR}/porteus-kernel"

#echo "TODO temporary disable kernel source generation. Skip run command below. Hit enter to continue"
echo "Run: ${SCRIPT_DIR}/create-kernel-src.sh ${KSOURCE_DIR}/linux-${VERSION}.${PATCHLEVEL} ${TARGET_DIR}/porteus-kernel"
#read _junk
${SCRIPT_DIR}/create-kernel-src.sh ${KSOURCE_DIR}/linux-${VERSION}.${PATCHLEVEL} ${TARGET_DIR}/porteus-kernel

cd ..

tar cf porteus-kernel-$KVER.tar porteus-kernel
cat <<EOF > self-extract.sh
#!/bin/bash

sed -e '1,/^##EOS##$/d' "\$0" | sudo tar xf -
echo "Run porteus-install-kernel script? y/n"
read ans
if [ "\$ans" == "y" ]; then
     cd porteus-kernel && sudo ./porteus-install-kernel.sh
fi
exit 0
##EOS##
EOF
cat self-extract.sh porteus-kernel-$KVER.tar > porteus-kernel-$KVER.tar.sfx
chmod +x porteus-kernel-$KVER.tar.sfx
mv porteus-kernel-$KVER.tar.sfx $TARGET_DIR/

rm -rf porteus-kernel-$KVER.tar porteus-kernel self-extract.sh

cd $CDIR

rm -rf $TARGET_DIR/kernel-$KVER

echo "Output in $TARGET_DIR/$TARGET"
echo "Output porteus-install-kernel $TARGET_DIR/porteus-kernel-$KVER.tar.sfx"
echo "Completed"
