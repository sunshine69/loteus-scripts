#!/bin/bash

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
if [ ! -d /lib/modules/$KVER ]; then
        make modules_install
fi

#fi
#make menuconfig
#make -j2 bzImage modules
#make modules_install
echo "Done make modules_install"
echo "Create kernel header ..."

if [ -d $TARGET_DIR/kernel-$KVER ]; then
echo "Existing $TARGET_DIR/kernel-$KVER, clean it up? y/n"
read ans
else
ans=no
fi

TDIR=$TARGET_DIR/kernel-$KVER/linux-headers-$KVER

if [ "$ans" == "y" ]; then
	rm -rf $TARGET_DIR/kernel-$KVER
fi

mkdir -p $TARGET_DIR/kernel-$KVER/linux-headers-$KVER

if [ "$ans" == "skiprsync" ]; then
:
else
	# find . -type f \( -name "Makefile*" -o -name "Kconfig*" -o -name "*.h" -o  -name "Kbuild*"  -o -name "*.conf" -o -name "*.sh"  -\) | perl -ne '$s=$_; if ($s !~ /^\.\/Documentation/) {if ($s=~/^\.\/arch/) {print $s if ($s =~ /^\.\/arch\/$ARCH/) } else {  if ($s=~/^\.\/drivers/) { print $s if ($s =~ /(Makefile|Kconfig)*$/) } else {print $s}   }  } ' | while read fn; do rsync -aR $fn ${TDIR}/ ; done
	find . -type f \( -name "Makefile*" -o -name "Kconfig*" -o -name "*.h" -o  -name "Kbuild*"  -o -name "*.conf" -o -name "*.sh"  -\) -print | perl -ne '$s=$_; if ($s !~ /^\.\/Documentation/) {if ($s=~/^\.\/arch/) {print $s if ($s =~ /^\.\/arch\/$ARCH/) } else {  if ($s=~/^\.\/drivers/) { print $s if ($s =~ /(Makefile|Kconfig)*$/) } else {print $s}   }  } ' | tar  c --files-from - | tar xf - -C ${TDIR}/

	# tar -xf /tmp/temp.tar -C ${TDIR}/  # ; rm -f /tmp/temp.tar
fi
	#mkdir $TDIR
	cp -a Module.symvers  .config  ${TDIR}/
	cp -a arch/Kconfig ${TDIR}/arch/
	rsync -a  scripts/  ${TDIR}/scripts/
	if [ ! -f "${TDIR}/arch/x86/include/asm/system.h" ]; then # kernel 3.7.x depricated header make some third party module
		( cd arch/arm/include/asm/ && cp -a system.h system_info.h system_misc.h compiler.h ${TDIR}/arch/x86/include/asm/ )
	fi

	cd $TDIR/include/
	if [ "$OLDKERNEL" = 'no' ]; then
		mkdir  $TDIR/include/asm-x86
		if [ `echo $KVER | cut -f 1 -d '.'` == '3' ]; then
			echo "Kernel 3 detected"
		else
			rm -f asm
			#ln -sf asm-generic asm
			ln -sf asm-x86 asm
		fi
		cd asm-x86
		rm -f asm-offsets.h
		ln -sf ../generated/asm-offsets.h asm-offsets.h
		cd ../linux
		if [ ! -f "autoconf.h" ]; then
		ln -sf ../generated/autoconf.h autoconf.h
		fi
		if [ ! -f "version.h" ]; then
		# 3.4.35 still has that file
		ln -sf ../generated/uapi/linux/version.h version.h # Linux 3.7.x
		fi
		if [ ! -f "compile.h" ]; then
		ln -sf ../generated/compile.h compile.h
		fi
	else
	rm -f asm ; ln -sf asm-x86 asm
	fi
	cd $CDIR


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
rm -rf $TARGET_DIR/kernel-$KVER/$KVER ; mv /lib/modules/$KVER $TARGET_DIR/kernel-$KVER/
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
tar -cf - kernel-$KVER | $COMP > $TARGET

echo "generate the xzm modules"
cd kernel-$KVER
mkdir porteus-kernel

cp -a $PORTEUS_INSTALL_KERNEL_SCRIPT porteus-kernel/porteus-install-kernel.sh; chmod +x porteus-kernel/porteus-install-kernel.sh
cp -a $SCRIPT_DIR/common.sh porteus-kernel/common.sh
mv bzImage porteus-kernel/

cd porteus-kernel
mkdir -p 1/lib/modules
mv ../$KVER 1/lib/modules/
( cd 1/lib/modules/${KVER}/ ; rm -f build ; ln -sf /usr/src/linux-headers-$KVER build )
rm -f 000-${KVER}.xzm
mksquashfs 1 000-${KVER}.xzm -comp xz -b 1M
rm -rf 1

mkdir -p 1/usr/src
mv ../linux-headers* 1/usr/src/
mv ../System.map 1/usr/src/linux-headers*/
rm -f 000-linux-headers-$KVER.xzm
mksquashfs 1 000-linux-headers-$KVER.xzm -comp xz -b 1M
rm -rf 1

# Create new initrd.xz
KBUILDDIR_ENV=$(pwd) $SCRIPT_DIR/rebuild-initrd.sh $BOOT_DIR/initrd.xz $(pwd)/initrd.xz

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
