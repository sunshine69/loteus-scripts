#!/bin/sh
# This script was generated using Makeself 2.1.5

CRCsum="3730701519"
MD5="e19d02060e1dce844e9552dcdf962245"
TMPROOT=${TMPDIR:=/tmp}

label="Porteus Installer"
script="bash .porteus_installer/installer.com"
scriptargs=""
targetdir="."
filesizes="184320"
keep=y

print_cmd_arg=""
if type printf > /dev/null; then
    print_cmd="printf"
elif test -x /usr/ucb/echo; then
    print_cmd="/usr/ucb/echo"
else
    print_cmd="echo"
fi

unset CDPATH

MS_Printf()
{
    $print_cmd $print_cmd_arg "$1"
}

MS_Progress()
{
    while read a; do
	MS_Printf .
    done
}

MS_diskspace()
{
	(
	if test -d /usr/xpg4/bin; then
		PATH=/usr/xpg4/bin:$PATH
	fi
	df -kP "$1" | tail -1 | awk '{print $4}'
	)
}

MS_dd()
{
    blocks=`expr $3 / 1024`
    bytes=`expr $3 % 1024`
    dd if="$1" ibs=$2 skip=1 obs=1024 conv=sync 2> /dev/null | \
    { test $blocks -gt 0 && dd ibs=1024 obs=1024 count=$blocks ; \
      test $bytes  -gt 0 && dd ibs=1 obs=1024 count=$bytes ; } 2> /dev/null
}

MS_Help()
{
    cat << EOH >&2
Makeself version 2.1.5
 1) Getting help or info about $0 :
  $0 --help   Print this message
  $0 --info   Print embedded info : title, default target directory, embedded script ...
  $0 --lsm    Print embedded lsm entry (or no LSM)
  $0 --list   Print the list of files in the archive
  $0 --check  Checks integrity of the archive
 
 2) Running $0 :
  $0 [options] [--] [additional arguments to embedded script]
  with following options (in that order)
  --confirm             Ask before running embedded script
  --noexec              Do not run embedded script
  --keep                Do not erase target directory after running
			the embedded script
  --nox11               Do not spawn an xterm
  --nochown             Do not give the extracted files to the current user
  --target NewDirectory Extract in NewDirectory
  --tar arg1 [arg2 ...] Access the contents of the archive through the tar command
  --                    Following arguments will be passed to the embedded script
EOH
}

MS_Check()
{
    OLD_PATH="$PATH"
    PATH=${GUESS_MD5_PATH:-"$OLD_PATH:/bin:/usr/bin:/sbin:/usr/local/ssl/bin:/usr/local/bin:/opt/openssl/bin"}
	MD5_ARG=""
    MD5_PATH=`exec <&- 2>&-; which md5sum || type md5sum`
    test -x "$MD5_PATH" || MD5_PATH=`exec <&- 2>&-; which md5 || type md5`
	test -x "$MD5_PATH" || MD5_PATH=`exec <&- 2>&-; which digest || type digest`
    PATH="$OLD_PATH"

    MS_Printf "Verifying archive integrity..."
    offset=`head -n 403 "$1" | wc -c | tr -d " "`
    verb=$2
    i=1
    for s in $filesizes
    do
		crc=`echo $CRCsum | cut -d" " -f$i`
		if test -x "$MD5_PATH"; then
			if test `basename $MD5_PATH` = digest; then
				MD5_ARG="-a md5"
			fi
			md5=`echo $MD5 | cut -d" " -f$i`
			if test $md5 = "00000000000000000000000000000000"; then
				test x$verb = xy && echo " $1 does not contain an embedded MD5 checksum." >&2
			else
				md5sum=`MS_dd "$1" $offset $s | eval "$MD5_PATH $MD5_ARG" | cut -b-32`;
				if test "$md5sum" != "$md5"; then
					echo "Error in MD5 checksums: $md5sum is different from $md5" >&2
					exit 2
				else
					test x$verb = xy && MS_Printf " MD5 checksums are OK." >&2
				fi
				crc="0000000000"; verb=n
			fi
		fi
		if test $crc = "0000000000"; then
			test x$verb = xy && echo " $1 does not contain a CRC checksum." >&2
		else
			sum1=`MS_dd "$1" $offset $s | CMD_ENV=xpg4 cksum | awk '{print $1}'`
			if test "$sum1" = "$crc"; then
				test x$verb = xy && MS_Printf " CRC checksums are OK." >&2
			else
				echo "Error in checksums: $sum1 is different from $crc"
				exit 2;
			fi
		fi
		i=`expr $i + 1`
		offset=`expr $offset + $s`
    done
    echo " All good."
}

UnTAR()
{
    tar $1vf - 2>&1
}

finish=true
xterm_loop=
nox11=n
copy=none
ownership=y
verbose=n

initargs="$@"

while true
do
    case "$1" in
    -h | --help)
	MS_Help
	exit 0
	;;
    --info)
	echo Identification: "$label"
	echo Target directory: "$targetdir"
	echo Uncompressed size: 188 KB
	echo Compression: none
	echo Date of packaging: Fri Jan 17 13:08:13 Local time zone must be set--see zic manual page 2014
	echo Built with Makeself version 2.1.5 on linux-gnu
	echo Build command was: "/usr/bin/makeself.sh \\
    \"--nocomp\" \\
    \"--current\" \\
    \"installer/\" \\
    \"Porteus-installer-for-Linux.com\" \\
    \"Porteus Installer\" \\
    \"bash .porteus_installer/installer.com\""
	if test x$script != x; then
	    echo Script run after extraction:
	    echo "    " $script $scriptargs
	fi
	if test x"" = xcopy; then
		echo "Archive will copy itself to a temporary location"
	fi
	if test x"y" = xy; then
	    echo "directory $targetdir is permanent"
	else
	    echo "$targetdir will be removed after extraction"
	fi
	exit 0
	;;
    --dumpconf)
	echo LABEL=\"$label\"
	echo SCRIPT=\"$script\"
	echo SCRIPTARGS=\"$scriptargs\"
	echo archdirname=\".\"
	echo KEEP=y
	echo COMPRESS=none
	echo filesizes=\"$filesizes\"
	echo CRCsum=\"$CRCsum\"
	echo MD5sum=\"$MD5\"
	echo OLDUSIZE=188
	echo OLDSKIP=404
	exit 0
	;;
    --lsm)
cat << EOLSM
No LSM.
EOLSM
	exit 0
	;;
    --list)
	echo Target directory: $targetdir
	offset=`head -n 403 "$0" | wc -c | tr -d " "`
	for s in $filesizes
	do
	    MS_dd "$0" $offset $s | eval "cat" | UnTAR t
	    offset=`expr $offset + $s`
	done
	exit 0
	;;
	--tar)
	offset=`head -n 403 "$0" | wc -c | tr -d " "`
	arg1="$2"
	shift 2
	for s in $filesizes
	do
	    MS_dd "$0" $offset $s | eval "cat" | tar "$arg1" - $*
	    offset=`expr $offset + $s`
	done
	exit 0
	;;
    --check)
	MS_Check "$0" y
	exit 0
	;;
    --confirm)
	verbose=y
	shift
	;;
	--noexec)
	script=""
	shift
	;;
    --keep)
	keep=y
	shift
	;;
    --target)
	keep=y
	targetdir=${2:-.}
	shift 2
	;;
    --nox11)
	nox11=y
	shift
	;;
    --nochown)
	ownership=n
	shift
	;;
    --xwin)
	finish="echo Press Return to close this window...; read junk"
	xterm_loop=1
	shift
	;;
    --phase2)
	copy=phase2
	shift
	;;
    --)
	shift
	break ;;
    -*)
	echo Unrecognized flag : "$1" >&2
	MS_Help
	exit 1
	;;
    *)
	break ;;
    esac
done

case "$copy" in
copy)
    tmpdir=$TMPROOT/makeself.$RANDOM.`date +"%y%m%d%H%M%S"`.$$
    mkdir "$tmpdir" || {
	echo "Could not create temporary directory $tmpdir" >&2
	exit 1
    }
    SCRIPT_COPY="$tmpdir/makeself"
    echo "Copying to a temporary location..." >&2
    cp "$0" "$SCRIPT_COPY"
    chmod +x "$SCRIPT_COPY"
    cd "$TMPROOT"
    exec "$SCRIPT_COPY" --phase2 -- $initargs
    ;;
phase2)
    finish="$finish ; rm -rf `dirname $0`"
    ;;
esac

if test "$nox11" = "n"; then
    if tty -s; then                 # Do we have a terminal?
	:
    else
        if test x"$DISPLAY" != x -a x"$xterm_loop" = x; then  # No, but do we have X?
            if xset q > /dev/null 2>&1; then # Check for valid DISPLAY variable
                GUESS_XTERMS="xterm rxvt dtterm eterm Eterm kvt konsole aterm"
                for a in $GUESS_XTERMS; do
                    if type $a >/dev/null 2>&1; then
                        XTERM=$a
                        break
                    fi
                done
                chmod a+x $0 || echo Please add execution rights on $0
                if test `echo "$0" | cut -c1` = "/"; then # Spawn a terminal!
                    exec $XTERM -title "$label" -e "$0" --xwin "$initargs"
                else
                    exec $XTERM -title "$label" -e "./$0" --xwin "$initargs"
                fi
            fi
        fi
    fi
fi

if test "$targetdir" = "."; then
    tmpdir="."
else
    if test "$keep" = y; then
	echo "Creating directory $targetdir" >&2
	tmpdir="$targetdir"
	dashp="-p"
    else
	tmpdir="$TMPROOT/selfgz$$$RANDOM"
	dashp=""
    fi
    mkdir $dashp $tmpdir || {
	echo 'Cannot create target directory' $tmpdir >&2
	echo 'You should try option --target OtherDirectory' >&2
	eval $finish
	exit 1
    }
fi

location="`pwd`"
if test x$SETUP_NOCHECK != x1; then
    MS_Check "$0"
fi
offset=`head -n 403 "$0" | wc -c | tr -d " "`

if test x"$verbose" = xy; then
	MS_Printf "About to extract 188 KB in $tmpdir ... Proceed ? [Y/n] "
	read yn
	if test x"$yn" = xn; then
		eval $finish; exit 1
	fi
fi

MS_Printf "Uncompressing $label"
res=3
if test "$keep" = n; then
    trap 'echo Signal caught, cleaning up >&2; cd $TMPROOT; /bin/rm -rf $tmpdir; eval $finish; exit 15' 1 2 3 15
fi

leftspace=`MS_diskspace $tmpdir`
if test $leftspace -lt 188; then
    echo
    echo "Not enough space left in "`dirname $tmpdir`" ($leftspace KB) to decompress $0 (188 KB)" >&2
    if test "$keep" = n; then
        echo "Consider setting TMPDIR to a directory with more free space."
   fi
    eval $finish; exit 1
fi

for s in $filesizes
do
    if MS_dd "$0" $offset $s | eval "cat" | ( cd "$tmpdir"; UnTAR x ) | MS_Progress; then
		if test x"$ownership" = xy; then
			(PATH=/usr/xpg4/bin:$PATH; cd "$tmpdir"; chown -R `id -u` .;  chgrp -R `id -g` .)
		fi
    else
		echo
		echo "Unable to decompress $0" >&2
		eval $finish; exit 1
    fi
    offset=`expr $offset + $s`
done
echo

cd "$tmpdir"
res=0
if test x"$script" != x; then
    if test x"$verbose" = xy; then
		MS_Printf "OK to execute: $script $scriptargs $* ? [Y/n] "
		read yn
		if test x"$yn" = x -o x"$yn" = xy -o x"$yn" = xY; then
			eval $script $scriptargs $*; res=$?;
		fi
    else
		eval $script $scriptargs $*; res=$?
    fi
    if test $res -ne 0; then
		test x"$verbose" = xy && echo "The program '$script' returned an error code ($res)" >&2
    fi
fi
if test "$keep" = n; then
    cd $TMPROOT
    /bin/rm -rf $tmpdir
fi
eval $finish; exit $res
./                                                                                                  0000755 0000000 0000000 00000000000 12266225472 007721  5                                                                                                    ustar   root                            root                                                                                                                                                                                                                   ./.porteus_installer/                                                                               0000755 0000000 0000000 00000000000 12230756674 013561  5                                                                                                    ustar   root                            root                                                                                                                                                                                                                   ./.porteus_installer/lilo.com                                                                       0000755 0000000 0000000 00000272240 12266225302 015216  0                                                                                                    ustar   root                            root                                                                                                                                                                                                                   ELF             �|� 4           4    (             �  � |t |t              � �              a���UPX!�    P P �   y      ?d�ELF   ������4�   (   {��d-#�o ���� X�؃`?��  ��Q�td  ��� R?�_���[�e? �� (      @��n D0 I ���U��S�  <�� 
���[]�����1�^����PTRh�JhԀQVh-�����#�V����$�C���=0� uJ�d��w��,-`���X��B�4���Ǿ��9�rm6 ��t>���}h���~�����K�]�����^�� *PPh8��'g.i�=hW t%ls�wP��C��[�v���j/P�j�'�w�}�PSh���5���Jh�m�r�%l#K1h!'G��K�<�]!L S.G��[L��y�L �6M�� rM��}$�j	�h�.L�������\��;��-X�\�؛~ �,@t<P�������P�Љ�������YY����	����I�wq@>W ��\`\���`�`,�<@6d,`,d@.�,�dP� �hPdPhP敼HNpzr��tzpztz��Ehvlv�A hvlvl lxpx$y�lxpx���\�(�t��H��$DOL+�M�jcj ����jjhqOH�C��}�h�ZYj3j~�V�=<�/,h w-k\j6Dq�L$�o��;�q�WVSQ��$'��r��1�Y�耣>���^ew�P	���	�w�a'���� ��;�����h�n���
������H�	�����M��N$ܒ��!ǅ�Rh	�I&�d���r���L6�$�1�/l��ÊJ�� ��^����Whۧ���-�hldiȋt.�z����7d\���;�V���N�2�~�V�-�5QQM��7�)1�OLt@����:��֊���A<9����o����$�`I��݆�}� ��C�S�m�.:-�Np쑽[c��s*�i��I(��Z�	e���ሙ�N�y�P�3��p�ى=�f7{-)MQ�	��r�5�*�(P�6Y��m�Ժ [�}���Gۙo\	xK�3�d������`g��
���O[AN6L6P/-%2����@��RRj=W�l��s��@?���gP�k�(o��8uT���j5!&.�mihN�! ܲ��B�,�1���H@�b�nǀxYF
�ǎw:5t�ʿ�?{)�u"��޽1�������ѥQ���涛};��T5_,��(�%{m^=xwlQRA�Y_�dR[PpjLK�w�*��6R%h��lN�H��<�~�	���69Q�a�3�+�*�
U2ۆ7*PM����`4gY�g��KR9-�;�N#C3uS��[��K.���/~9	�6�(ǉ��ׅ�OWއL�LO�	�!K�yf�@�g��č���򒆱�@Q�M:�&�Z�+�$��GQE�n9K	J���!�!W�v&mG�n'�	L�زsJn���b��U2)٦��7g�G��Yw�,���"I��yk�pLf�8��`{�/�5+��8 ��k;W�.�k0H��c����^�%9�;y�&v�#=�Z�0�o�P���g$h|�x����8�6SS%� ��	��E(��_�*�9�Xiؕ�)�@� � �C,��|�g�����H~�z- �(��^����� ���0�m��A��us�n���ji��Q�ζ,Y"��}����E��VVh���@��+Rt";3Գ�RL~W���S��Sq��ݑ~2=�� ��V�\�7���$�D���6�ͅ�:1j
���d�d�[�ao	�
g�(=��5�F��� O��S1�nt7�+��h�R�����t��1��B�����G�����5.�*�Ə�ȹ���{�l+N�+��;$O�RR��[��|�g��O���x�k�݃�7�˹P��y�z�b����
���Ƿ��~~�d[T��u�\h��� �W�X �z8��h T��� �06��� �y�­����uB8��s�P0-��-陣�HT��6�-5�H$5��]GH��lTdz�5��%y9�w%Y;��K�!���%J��A
�!5�zt�@6��P�ux�^B���\X�4&(�_XhK������c��Ј�O�T��#[��qHu'�h��-��Ht�g�
[��=(�-�{I\	1]s��u��)L�/�Y$=�
1Ƀ��������5(.�aٰ�fE>f�"�߉��(4<"��`FF6}kP �O*6!�9Q�씡�2ts�l�H2��=YjVYчW�{�xG1]80�	���08�#?��� 3�Zѭ�{MW��B�w۪�� �U\h. �Ȳ5N ��?�9=	 �(D����>Mu	��ܟ1,�~#�:�p+���T?b�U�8�r���H<��B�q;\	�}��|+�=�SuV��:[x�[_�4]�@��.�SX^�\=j1�`�X,V�Q:r!#�[j�@�wS��F>qT2S�X�Pj �E�g� eW>dqWj�d��2e���B.d��r���O	�� ��p01c��@��R��;u;�����t�)�A���KP�V�òbc3�1�������Y��>M���V�������tb��<�=�!����
���<��F���I�8��)�}���F�8�PR?�����T1W8,����E�'���]�Y^�!W�1W�����E�i������k�n����P�
 
�9P�>dB�E�wf��!G�,iW!H�CξeGBR;���7_3Q�E�a*�'�m W�V�d��m�8Bt�<���W��C&�o	X7�r�,'EZP=e���,X"�h���K" &9�/��"_Il���"i�A�@�dъEb�>H��K�X��
�4KYuȳs}� (GY8ݐ�آe����u
]���d*PV�����P��h��tT�R�d��t"-42�Y�7�M�x�h�Bk';d	Z\u�M�R@�M����؀~�L�#��F���4�J���m.g�F�VEx�ٝ�~�`a�i'��{�$nRk�&6���Ԇ�Zx ���!�F����`tJ5}[����`uV5N�zm���2�{,�]�)Q%��[ F��%�,����I|4òH�D/D�vf�F����-�1�VZ���sf(!cg7y1�����DE�Z����0��r�c2v�˸�!Ȏ��1�!�C ��'Gޱ[����:ۇ������4G�[@C2�-�jl�dw��|��u%�-R	Y�f��b[�|f�a]@�ks3v�K8�[k�6�����D*�U�	�7�� {�`o��EH�@���7�P�$�@�D$���l�Qvb���X��\��X�O�@�)\��h�7�!�QE�y���R�W\d�=PPVu'9d�\WW���!�\Չz#��ہ���$��<'��JQ�W��r�#�xA�ZWh]%]��Kb�)��"##��S�cًj�Pf�B�����!4]�J'�\p�"�j$*���Oξ�)�(v�d'&hg:�CQD@^6Dt5'pY�]$����3�2�<8�W2H�}{��P�3u2<.�G�x$�I�]^�ɷ�R��Q�RhO�6D+ )����7L���.�W��O׹�¾HU�
w�z:�ǒ#펚�;���^�����6��2|�!�����h	G����Q�о9�u��~4 �'R�aL[^.�*h�nc��hw ^\1>#-�1��Q0��!���%�j�V������67]ȋ_E5�!�y{W��00%�+2#�َ^�,Q81��l6!M7� !`�	!WV�YX{�V�3���PѴ)�YWV�7���R��ޅ�tg��0լcF�q�`��*�v�% վ�G�6ȑ
xd7_}��2T%]��a�!<�������
.�4!��Ab�uX)q_؍�n�3i�W������9v-rZ���+��_@.�\���dl ����]0�B�
SSP٭_ `5��	���z��B,"��e�Y�e���_ɍa����� ��w��jۆ�EY�Ska������!�B��
�-؞����!�f� ��C������% ��މ���[������	��tY؅8QShRR(�o�!Bذ��Ù��CL��!�V�`�sS����'h_X���	��9�ut�(�x%s���hݳ��:�zhwo�*�r���5�|6���a��k��+��eY����	t<Lɦ-ZGQ1Z��=t����ᴗ�{u ���8/�xɂcE�ar<��:��Pj�Ռ;v9b����WW�,]��n�$�(bašyp&h\�5�D�gkcs��=� ���&)b##�����}c$�ܓ	�V8�R9�u3Bvᐆtu�H0��hcbv}�ky6y/�Yw���]zH�	Hn��M���n�@6G�PLH��b�:Z�*%hZu��mD���/Z�
J3l��"XF��u�Ppc�*D�g�X�Kc�%őcd,�u#�,y��|c���FGQ����]6cS��L���DSJ#�e���FV11��LX��ߪk`����8c�����,�>�	����A9� ����_2"h�Ѐ�	0���	»��T������	��`��@�H]5�J���s!h�_~�D����ʉ�@��H�P�R�0�}	9u�7,kC������|�B���d`�cL8F_[�9#r��]�p�2���0��d�Wd4�80�I�ܓ�	 �AF�$1�T*�]��Uȫ	�ʈ��Я�4���M���%��
g��0���)Ё�\� ��	ȣu�)�K�@^�d��|6������Hץ�1Qm��(hQll�fE�� ��@�e? o+����5[\��[�PT���a���+�P,���«��e��c��(ݐ�B��휉˲,�J���ӣ-*��R���w�)�+�p�wW������C�������iW!�"\F��~h�Ot�;�A�` �!ßNxǎՋ��'��=Rg�;+}������@��T8��c��H�C���"���v��@xphu!��Un�+j�M(��6�3���=?�w XZj�j��	"$�2��R"N�H��<��L�OsHH����HHB�.C;�D^�e�(A�xu�xE����
��{�
n�.��uV�OK�;M8��n��0i�$�BA�1+�������*mj��d qTO��	k�E	P23��\����t ˳7���� �����x�ntL��a�
�D�O(�s�]*4�ul�a/t�;�>!;+:Hk��p-��-�C��P ����u�j؊Ӎ�;�P�FQ�J?6�|<a:$P��Q���L"� ���
#�ea�BX�gƽ��W�K�H�ω;Ȅ0��@��z>�,D���J�/rv�9uc:<0�׈t%� ��j���
 y9�f[��;?GK�0lݴy���!�!�G;={,�o$��L�9uu���=W�fz=ٞ�2�=��D�`�G��t�>�D�x���^'�6`��3�~Z'[޸x y	^K|���P;¯^:�v+Af��W�}g�Gz�
�u"���$���v"�fα�i���`'����H�����5YtqW:�3�U�Y\��u�0�mf��1�1��l�ib餸�g+�8��|	t�خ+nU��gQ�g
X��~3���4���h�C���� V|�H0A�X60��u7ǒ�J�.��g�� '�EY+����<u�P0�r���T{nv��kʛ�������/q�2A�%^%�}��0'h[A�K���V�Qvh���x�LA�:�ܫ��4Ͳf��L5K�c��251p��8�O<�<�8\�ߋ��P���,/�5yy�Вt�U�[
j�C�aPb2��U�b#�<yBMi��0�cm����4eO��<���uS��0(a�C��Z�"���3�O����gF.�s���R Q�ht�`�� 61�����L|2~?X-u9i��]��,�?���󫺾�t��T���<�ۥ�|������	�@9�|ೋ}k�a����s�D����`��j�$�Y�iK��CZ���l�eC���d�P�< 	x~1ف��'8;;|�Hqj�l^t�<��j.��]�RfhTf^B�v�K0?�Pe�S͑��BTy�i�~a���<�uS7;�}�I��K����ZvxT�S)�N�jV���m�n �o��� x{�P��4�R��<	���-&��F6�X������B�< t�d���h]�oG��o��l�1��Rk�6b��-��ciP��\r������֑���t,�u�Pt��y��s�0E���\6C6�0	�x6�iWSπ:P�܅�f�����3��(%�N}Y�HőW�"ؐ���i�=P�39�S�C�`�J�Xj�]瀀p2�����H�<Sh�kqP�����k��t����fb�C�mkKS�[_�\���� �<i_�]QY�-�Ґ����<�a��R�����hk&Z=�[�;1��6e;�t"��jt�
0E��F�^4k�RG��r4��(� al�t�S.��=6��G�u����`�IU���`'`k3RĀM{�8ScD�2��� �XnE�{��d-V�S�\�'-�	�<��ʺ��Q{
�6xx��10��]�{�Z��=��P�jxHx��k�7WW�e&h��u)�<7�u�pK(�j�0a�"�9t7B@2�RQi�J�N\�D����V:�klZA
=�1W�l�E���a��l^��`7fj,���S�ǈK�@[������B�0�9b�T$%�AL�Nx$\��&S�uXV�T���K�<�S<�g�/�( 9�^��ҋҙ�	[@*Ȍf�D�_���	c�}��M��k�`SW4;��kbѵ(YW͘lp�; w���;@|�VB���?�k�\<��j�D��*�<qo�?i���փ�SȦ��R͋[@}�홭���	���=��<:�������P��1рῶ�cy;���� t>_@��o�xH9�P$�@jo��⿈?�#���ί�6�@F1;w���uz-�nS��1��ž��	�?�
�yr�!PH 	�9�D!b��ǋ��{��50���9�uB�j�`B��SB6��5f��q��o�Xc�����2��D��n�CB�9��@�'m,wC�P�t��~?=G��S�vΕ�%\B:�����9u`,PczS�u�0!����%"$���g� �����啝�^k���
5lƟ=t��C�m	��`�`ޜ	�j�C�X	�PmQ��k�;����C=Z)�0�Se4.�+�9
X�)Ew@(��qLQb���h�l(��
Z�IG����F
�vIB����V! !�uP%�DkjH����=Y�0C�e=���W�p"�wφY���l9�8vx�TY<��B�-E/Q��wC�[�c��XSw�`;j����t\֤ǉ���u�@��hc��,j��'?c�B�膾E��M$�}h;�X�9���}�m[]zs�J�M�Mp��˶}�ۨ6�
�
��3h�@t�E�7��ܢ�d"o	B�6��	�Uk]����#5Y.��}����#�KP�g�%g�s�BfFXh#KR���ܱ�1(���t*O�X5j����!����	�l0GB�@���Lu�lvc3��2�	Pydq�Rp9
mB���7���>.&6��a>G���SE8\�%mw� �I���m}�~��W<3�-�(�@����F��xDtX��d[�'U����J���P�9�^��T�vmW�)��i�y�h5���z~�;�G{Б�󤉽�mm�4�f�)���V��\iؘq��6�k!�mZ)e�z�gZQ
a����%���S�� l
40ɫ�Z| fB�	(�X!p���2��t�"�1K�X��3e$*�����o2HuR�MS^"�6���m%��I&�K��x�mW@,��XutJ���+�P��4�4�Q�p�%�����jP����'#�B���G����7�u�L�8�`n<�V���6��M#u@"DT+gΩ���D�;pDxn}n�l�[�7JhH�Q�
B�l[�@P�#-8���@�A��n,��%V��8��cJ����O�Ǎ@Gdk`�D�`0�J�0/��Gp�p��!�^�\����I��g���ς�G�=��<�΃� ��W��-���������	bT�C_���s0F���
��Fnl�p�BEm���SV�dVa�EjDt����;V�e���gV��$Wmh����X�MO'�-�Dire�1j�{��[l��-n�$߅��@�LvA�����6�uĢW�D�����Mr�W���
�vt	�:�����"X�+.p�v��C�n`��.㧠`������Ç�]5Ë5۹�t�B�!��V�VkE��_X�V��	�!���FT�ڶ�P�u/�Ǵ�j�j�p��M�]	&���Fy��#E�!�=	�t�b�^n;��59�DDsZF�܁)�:� %��$�Ӄ@C����Q"��9���������0�;�n�f���B�h�[�l��g��
�MG�n�XZ9:�> 7�|�
tVV<�$J�X�v���_S����&�EGDXly`$���!i:�������Mo`�Q[U����0�'|�1	�J؈�vɀnb6Uc[��M~�n�kp�`~q�lE��g�E|_�H:3dx-�H$�dt�`�_�/n�IW�ρ�#�J%ׁ^wX��ӑP����A'9d��l`P�oH)�� �����t4t/?t*t%=��P�eK-?c���B`hn}�í��(t�u��|-"�� έ(q�	x������Cu�4�HvR$�QAK�[�:KHYxM`��RE��w�[h�T��6X��u���"���p�/�[K8�e�dK��?���:9�T1C�K�Rc�u�K���g~W�s�s�iY���30Vp��JC��-%��~��:f���|/s��?\��9S�;Z
,K����}ݾ?q�	7������4P��@s���X��H?�$�<�9�yplU�|[R�՘��P:������;f����[*	w(Fz���:�5���Tpo��Zrh����9��ңω��%�R�0��N��U<@z|�HL�A��q�-�o� Y1�;�1�I�� Mž5r,�2/���%�SSHqQ��,�n/,1��jq�cjۑ�~�}�-_�A���Dڲ�9`��\�h�9,��ߣ�w��4/�W:�u!2��3F��q�/yWhLr�H��F���V�L�ց�u��^��H�������%��u8!q�Hh���;���rX2���W�bT�f��8, ����5w,�n�� 0�?�?N�<�峽\Q�"K!O��v��
�@��R:�!������F��6�X�7;0](-����$,�D}9)��=e<�dW7H��A_�[�/�� 2]�$p\ߗd�e/hr�Q�Fp��������.<Px���e\���~*R���"�8��-$��Txs�M�˲(!���b�|R�Z-Y�HL��(��	�K(��`u\D�}rA̋
���`9��P����jd��Q�D�����6�:�/T�`�I���ʈp�6�V�a�5B�(�dS���s�r�tb`A.�P�t�� 	 �B��q!�3d'xnm�H!W$�Q�¤5���`�YCu.US �fiUS���Co�,��b��!�j�� M<?��j��<�<&<�ϥI�b�v�T	w�x2N�![�aj��@�`��`�##D�-vYA>��t��h9t6�[s�R���]T��;l�h�e��x�]�?%9ǋ�t	,��$�J,ă{����0xh@v�?�o���M�������ډ��u@G#�v}�#�����H�uew`�<?"w.݁2�!)[w�@��tlW����t�mt|�27w�A��0U"$^���ҝ9
Sewds_����[w
XsjA��]Apt\wS+=��_rum�6�a׭%��dm�	��
Y����*��m��ԅ^�� ��ܱ%�y��_�SBUuM����nc���_̠a�Au�s@b+3va�0N����4�4�0lKF4$P!���T*�P����:uf��H�+0C.�� -.�ǚ:?��TЊ��Jֶ���
�+<�g�%$x�vn��V��s0J4�BԀ���6���uu2o��R��>��y� �LQ�1����S�{4W���b��a�m���������X�l��W��� d?���wAx��M�Q�Z4�0���Q̪"�n�O�y61�U�R+>+t`N?��Q��H�N��S[�1&B��F�3��y��Yw��mŷ:X���=��Fʐ�i!�Q��X1 s�\\��}�\�X�PH!ڎ�Z(h�/`2&��������
E�8�`G���:�@�~1�;�6�@ml�*Ĩ�Q����!M��Q �%��d�/PT�TtY�"R��^�C�[�����97�[H�/���)j�[��(PI��!�e�t�AĞ3��	Pp c_�Go�~��f@�<&@t#���L=g�m�[7E \��3Bu=�TP22��T���]1�-`Rb�*V6UMA�Iv�ܪ�d�=����!�
9�|&�Z���; ��l,��3�wp�KR�H�O���lT��	zV��vK
z��O<�Gl�G �6q,�V��լ|Ʋ	~j[WRX8w6��a��^m{8�`���g[�&*,h�Nj�~t-����wP�Z��h��UQ�@~b��Pj@+x��h�[hUx(�E��+�KϾ�H��{ϲ[��0oQ��(a3�<0�{��c#�ܖ�`:y�ڲ�
�P�L ��1$K�Zs7^�*�bG���>F�5^�X���X|��,�Y�#�������Nj:z���l':$��"E���@"�(�Г����C�.
$|��,1��U�r7��@ Tm�f�$z��jl���y�u��m���_�����(�n,�PS(V�ve�rg<}3D�Y�� r	L�!j*^fQ�؀u�gs�*���y<U�x�&?2��4�";�y\` ǩ4K��G�0�`$?��H�z!0�c��7��:��?!I:A=U��M�²����:=�p��K,�' +6�/�M�����Ps(�L(憝6��3r;#�$ �YA�+:����B�o��x�;��}�Ħ��{ .�� �zV��c����!�_3�񉏸�P
�E[���sIeRu@�ͬ�@&�挂�]za�J�W'��Hb1���S4vQ؟ �ɞ��DRR�%�x.$6ֲ~�7�9c�sPP�W�dl!���#�*�!b��QU��ʋ�p�2z��ѽ�E���o���}��J��bA0��Z�&c�Eؚ�P��tk49؂<�DC0�{��v@f��u1�V�ceuc�)�ʀ}����TE̚�Щ�$���"`�1����BO2,{s--�1F9�<끽�k�je4 N$�co�n�`�P�b[D��a��ɮ�Q���@���
n�$��6\��oMȈF�:���ݭ���6j�XY�v�P��~=U�~3�
���#��V���ZP4Ž~��[{́�XGŲ*����$�b.E0V�b��_�.�%:P��(��h�{����?b������Ư f;X��L�BV�h��K�ak��B�e�]�j�V]�Eg��]/�D�|7}9�|y��%h��L]׶�R"R�����^r�Q��|��h�mۈQU�������>@�e!��9��H�c�/�Mn�u����Z����	�RS���o�M�t>�98E�u6�M8ey�n�u.�u&�����u�uV��#x:$^��z޴��0}9�|����kF�\�$Y"���4�p�M�
@&�Q�h�aᖪ��rF�P��f��C,f�U��)\	
!�����{��M����-l-,����0z��'��O�0u�A��J����)�GQ����fy�"vf�K2a�)�m�R� e�?��E�?h}^dQaK�$�w� $U- 9�gG���4C-_:|Xv}�vG��E�h��/����D�9�~?wP\[��������uR4jm�heƾ��"�/)�k���^d�B��8D�g@d�M����.�f��Q��}�r#�vV��}|	�k4�#`�RF��gQ�d;���`!��RR�}P�8ZY^3���l�Fz�v(��P�Y^�2b�(��1�-��}�A� ~t#�ʶ�uWB����c�<>� p�?�  8���2tw��yc~)E#԰�!����a�����5ie��.�{�X�S�P!���q��j-d�)Ƴ�Y�mS�G�<@5�;)�yL�ks
!�s+;�r���vI0���<��cA��R&=%�X��~=2��!��(�JP�p�y�� �,�8����4��G�:����v�f�m��8I"�љ���%�t4ll6��cl�>2'g6�BVsW�vb%�s��->m�أi����5h��������_
�5f�� ���;}�T!���� CS�����@v���W��^��u�e�pH�o�[V��WG/��}(�c�]�f��o@��XI@BX7xx�o�}>W�+�W�jrC��]��l�u���5�"&#OA��F"hT�J[�/\kw/h�!�S��,�VU>L<Yќ(cQ/��7|���1��+�W���sdRe! ��`�VV�]q�">��!���<�F��\���4�p�Dl?�tK�.E�����w4�C<:�0��)�ҡ���>�۲�P�>�w�	�Z��=������Fk�y+rG��� j6�?�,	����ڸ�b�c���Vh��j8z9U|?N�\mD3�\X��<Qd�-ܩ�PW8�Yp��=YQJ��=K����g��Gaf��>������Y�HPI��W�r�+��b�)Y_�SP���C&h��7T���o�k�d��og*1v�� �Czol<���.��U� �a!�`�΁�FC*Xvh��6����;\,��f<��$�C$ZY$��&����BVkX��n����{�@��	w�~0P�h�9�[�_���F��v���6_vӟS��M�E�D
;a�V[,@-������/�K�I��}�Wm��M�ւ����-� Ȥ�H*4���f����m+s� 5���.��lE&���Q��ʱ�����`F.ftF�ylS�ҹ�Ծtl�� ׋�"�M5�����+�|w�І>��] /pS� � G�I8ps�
���$S}��x	�Vnr�Q}S2�g�@-�V�r��@t5��{g���1�<�����{��	9��t��t6t3~�1t,Ƅ"b�"��X��0
����l���D�����u�)ud#��_V�,�R�T��b�\p���	g�%�p`���`z�n���EǄy�4�������Tb��]@��N��2�x�������������G���	�~�^��u6�^9P
9R�W�x
�g�����F�0K�Ǝ�l'G��kp��|��7F�t)~�j�P�F��H�>�$U[�/��0  ,O�G���6�hh��P���+����
j� �H�7�!�C@�(q�/Di�� ��H�_5����֑&_56H|��9~0W�Ѓ��tv-�@�Vh��I|��'Ɖ$�k���G�b�Fk�8`y���dœ�a��$�@d��#�T=zE��;<��.�ޯ"<�bI9�� ��R�� /@	l��U�M��j�=W;R�K�t7U���߃���-3l�8o�/@)M�QS�����9�]�Y�k�*"�m�A�
.��g���A(�3�Q$���j�m#@{ǂ�y.to�˺?(�R��xe�tO���t;!k��������]�6���R��k4�v7;!��"'=T�B���s90}^^�4,� v�f�VԀx�sr�0�ϑ�뒘�7@�nȱw�1}���X:}�V�Z�NvD��XA�j%��'�0]�I3A��$PGH4�֌����E�����G~$�QN�D�/nY>k袖y��'!#�:��yt��GV��;����ۦ"WG,������B=v1�r�o5��D�Y[V��7a������]�� |0Ɂ���Q��E,?�QJԶ�p)�=�&�'�x�G�[t�"�k4&�$��l� ��
q|JN�1B1�K�V��W$9pu0b�R��|�֓%`w��F��]G8�xH���箔T)iЌ��Q�h�Oc���W'�
�W	�E	�`���*�w�1�Y��5[� |�UW7�5 ���YX^RK�P�xBƷ��3u̞h��a�r i ! ��Ȩ�aZZZ�0�W�BB�<V��`E� ^5���`�G�eq�z ���Jw�z�,Cx�[q�0��ᅊӲ0����ut�5�?�C\�C���E���׶;v��>O�H[�QtC0[@��� s\��z�t{5��t4�$s��B���\IX���5�\{aQ�'��@vު��e3=����߮���0����E��	ÏVq����o�(�~����[���@u��"
�d�VE�mZ���~	�@3��� �u�O�xy!��琢0�G��a�����ςB�n�����M����ϗ�б�$���>��ʅ�R������VW�f��`ځv!b]�P�1ņ֭b!��C�d&�P��1�2����6�O��PQ���
 ��r��	 N�u�V��9�"x���/��~�F��ǯ���t���9�|�=����oа�q[h�"��gy�ZY���-��
Y[ZC�²��[_%�E=< �.EXh79h@��9hI8hRBÐn[$�V��0�7��y�1�P�[`R|��Z��
�U1!O�Q���a�2u�*1k�_�y��j"hm�"hv!h��< !h�w�AX�����kP�� t�C�4F�'h�y��%��h�7�-�R���L ��3 ��r�1�1�/����2}4��*E�䀾-Pˀ���m��T3�@>?q@�pSB��b,��8%�яη�Vl�4�S��LD ��K�K5m������>��#�vf+"?�gRj��h	�Q�#~� �#g-�.��ZC  u�tb�@��r���P>�rl�t`u�c_�&���u�w�X���;�z�uC:+�xR�*RT��X/X)�$H��Y_ViQO�
d��Q�8]]!H]&�#b8J"K`��2�K��(��%����
;4�����t%B9�|�=� O�Z�Z�J���.�{"/<Jb@��v��ch<b⤲`RՐ
&��0)8��GX�@��ec�ǃWk�P���V���crS).��2��RDR���B��VQ�j$)�1�|g@��8DĘd�怉�]u$W�m�7�]�m<j/���;YI}�I}�ƚ-�*@a�th���(W��ڈdS��45�
+���I�{�Y��4�V�=��gZ����PFBML#��$ٰ���ˈ�]�E���5Sl�k� |��<
(}TN�x�,�D�f�:7 f9Љ��8�����A��@�4�nf�  :6��7B �Mftu	��`'�Ʌ<y#`o�S��2f����!���;�p�,�bnX�4�S�p.0���e���=|�^X ���+�uP;�b�f AD#�v�]~Pj=���* 	J�A�zoC�1cuf�{߁���ƾߪ��Z��K�
���	��E�%Y\�\�e%�4f,`*8�9���A�F���rRSJ��G��f��=��f�a4 ��>!��̈́H��! <�TCX �����2[ ˳l�,@��T,`9�r�G�+���:�A�p)�#�j�G����`����qwH2ɏ��RR���=�n�ݷJ�YhJn����Z�q���V#��t�}2��면�5��$p�x�x�76�V��ύ�&��"uR�'�(�qPB���<P�?i�$[T<�9��u�Ç=F&94���۰��r��!�1�q�#�4��j��9�4�Z{k�I���5/�����Y^S�*4G+:Vd��Xx0��ŧ����Հ�%���,��T�����V��u���'�rߕ�����Ŭ�'��D]8a4;��8��N�t��x?w�#������eP\~6��9�~��qH�l�XB*=��F�_s�M��6��v ؠ�E��ŧ�����Y	��4���I��җ�U��W�2�A�z���j[	��c� 0��fÆC9G�� ��v�U�%#ކM�Q��@_j�,�
�]���%7+IZ[�כ�9`}u��*_�t͌ �C�V�� �v-�y ���v%���Vဍ�@m��Ѓ�w��:����P�}ܪ&�Wu0w�a���~WQ�bU���4��n�ÝK@�!�$��J u��w���<���t	�t�[���Ɯ�&��voLF����}��
z2�P� V� �/dev�/7V�i��j��7T�\�y� ���	��MM.�/ǧ����OXິQA�P1�,KWWP܀%p��uo����F�[~n�V�`Їֈ��(�N��!	"b ��݅^{�S�7�{}�o�Q�0̖ph4��O.�Y ��&xu ��N!������Q{��W����x�Ƽ�+к1f!�B���Q���Gt!�*O19�����xc0Vѹ�`)�����L2���O<R����������p �P�/�Ok�,;�A���u�xQ�}j0�䍿�3ˮ�۶���|�Z�_>?~�G�ۖ�|��W�����!�'k�,��^���b,��������`���dP`�������H��6}$����K��&PR)À�@�W���^���&�0B�N�i�*�#�pr[17���<k�ل=��ܩDd�֔�ѬҽH!쬽6�3�K.J���K���|�G/j��	�k�l �A�:�wf��=u���m���੣�s;�B�k�,U���$H�3��,9�u�Qk�,���z�>�k�	h���.E�/���	tOAt�[(��'ނ����b�[���P�X�B�P��ɦ�+z����jS�P6"<�L�*��7�{v�t9_�k��X�o�}��!9x�����
�H��?y���A��|��߃��񞙭%�zG�e ��w���5�� 㡨p:O�����h��==ƄZ����:=� !�!�9i����`�E���RuȒ+F�R�c_+������3>԰���9dЯ�)�,�5�|�+� �UhK ��Kk2�>�Q�x�u��/�Q����>�x08~$m�_�p�W���
�aX��$	$�[R�~�;Cu�K��XK&Y����뱿߻v�k ,��
�4B��`=tW�n,N�/���;�hό-�,b����%�Q}l�&��{����;�P��g=������N�w#Wk�%�
��)���K�l��$u�"D":5�n���	(�p�^H�u�n#)Q7�V����Ј}k�/�|�}��Yw�.����>�%�Y�.S��WK[H�b�M��]8ndg�Z�#�8� � |��U������7M�0�Y0v��Ě��+��������vdŉ��� �F������Z�OT��uE�	�	�J�J�_e�7u�-t�1���	��G;��en_�Ԑ�v�T�R����BF��]}1`B�1'���ChZY/��,�&�k�l�5�P�v:G���T0Ɣ5:����d���Z)�Fdz�c��z��Br؄ ���̝2K{�,�*w�׃��鴰���B��Ϲ�H�:5�[@#<��)K�PXl쑇����"a,;� ��s��lG*�taC�l����tCHVk�½�;P�l�un���O�x���{�R�B�=Q����C�6#z{�	��wQ����{�ن��`�ܩE��H2�p������! 9V���N��6��B��!°t+��Bl�Ďm%,	����h������5<�Yr�*Ԅ����M�P������-��.ɯM9߹���/���~��&�gh��Q��);������$g����x��N��hBHm�~��\<�<�����h��@,��條>��	��!n�b�v�S⛰��hT�����&G:m4�7�� 6��������fd;&�9t���W9Fu�����0�aBM;��|��o���~"���a�e}�S\�؝:�лV�	�>q��p�T#VV
�(! �ICE���׷�3�8��~(��C�m"�����r�cMAo�e��BAN�C	�|�dSS0��.�m��ө�T{\O1�}V �Z�r�u5x�t���êFECWQh�h�hRZ���Gw{�@FS�
�)<CT���C�S��*6�X��	�!��Uԃ@�TU����@�I�Rj�^�hl�vk,�������HV����$|Y��[WW(��r��2}�� ��r�� y�����JVD@�.�R�耎H�s��$h��d�u�]Y0�`%Z�'TC����D_�u�Q���x�	�xH��P�R�_�Ps	�
B��:UŁ�댞���c4�A��Wp)�'gtz�}	��*�w@h7���a�d�:H��[v
�T�m��Ѐ�W]�N"�CWp|>���jug����5Ђ`M��6_��6/�y�5Fȳ�&#pLti�j ��j���+��-K{C�nuF�6�x(?��9��Tt4��TM�St%�o��H�
mthu�smqik`t �	I<@m�
=�+v$��=��w�h�XA�}L�nb]5� �ԙ\���'*�+�'W(to4�&�g{9sy��tDQW͖�f�[
f�@�"��t �_��j3�/�8�B�XTC���5�
�X9Z�hР;l�5T��9J�9[b���.]����0U2bYt ,�u�}�/T4��1�1��
-�����#}��1������M��qðo<�Y[�-�E�2�T2�8JE;{ �ӣ�wB4��0����49H�e}�Zo ��fYV��#h$�CD�l�X���r� �a(G�{�|I�5�y
U�V,�$���Phh	D���˙�h��|1l*��J<N`-y�Hd`2T�HQ5	D�Rթk�v���(�wh���i�m/��#�����p	�h��^���t���=�g��@(�*���ת��o;�Q��ʞx�JQ�5��x�������(��}�W���#j��0F'�Ǎ^�&J+&#��Rσ�oT�x2���ւ#�h�`�Mل �)��z��J56W���0,�x�G!bo�F�4�U�!V裛��,V=S�	�}�v~Z�oQZ�$Ap��ͪ��cEh�
Z@(��xRd��� �@��0��������8�$�e6��W-���[p9�tKG�v�T�4�"
5$\H�6�P�_�t�ZBr���ӉM��)@+e���� �!�&
����lY]�-� u��[�_@��E�c�j*v�.�6��k��1w
���g��@�8��=}�ݿ�k�6��B���xk�6E��J��1��ڲ=}��P�����A3�۷�Z�j�F4#hOE������@���~΂�����<xf9<H��UHh*�O���{Sk6;�~�Iх��t;����^�L#�P�u�2���<�;�n����MhJ����g�49|�Þ�m�@�5p�~�kU�6����6�'to����Pj�ʶ���'�X(��S ��������$Qȶ��Qk�6;�FF��@�Ƃ����y�ZaC�h���R��#]v�����=��$Z�'(�	���(J�+tr�����u�2������z�Y���Y����t�?ԙH�P��������5�Dؠ=�s��"��*��5��-ʆ_3���5T������EZv"9�~$k�����@ (��(k�n�hV�/���bG�u�h8�T��.��C/JX0�[xk�V2$�D,@@�4SrHB >���t2Z��� 
DL8��-�NPAt: e�����v`ɀ\(Dq,3T���x�IW�-P���.0��ec2X~ �=x��v�� }��
;,�5��!/��SSQQz�J	� ,5�u�} �Z������ >�A�J�,�?PI�DJt,@��V�*&���)����x��Pq��9wA��93�Pt%vopuN��363�>u�΍H��M۶�Lg�A;�����}l���Cs,��� U���� �ҋQ�������l,XH��xdp!(z0 h1�Yx�O�����dP�� >=V���xF� �nlMi��26��͚/A��(`���^C.Y��8*!�=X ����x�T=Қ�U ϾVN(2 � �Fl8P=�7��+='�@�,KuQmi��H� ��ɚ�{<^ CV���}���������@��f�CN�Gt��L�&r����`S��[��P�LMh�Z��	v��f�@�n�L�S	��`�toQ :P�e�p��0Ft���(	�3 h-H��A(1H]X �NFJf �he�= <����2༉�����C2����W�f��f���@A@��2^_-0���g�30���44t��TO�ba���{s6����16� ��T!�.6�8+|�{lf����ňIPj��m�_�k���P���\�O��n_ئ��m8Y^7K6���P6����S0=�!��=�jS2H;8`��������=�~-������F9!����{�l�ޮ:�#aG|6�8�8<�>�.�A�@o@�v<kBNT@:R�DѰ�S7��7���%�Zլ���$��0"���yR_H#�]RJ@?H���`���KV�O�C�dS$0��4���Q�4�h\�� 1k-��qXC�[fʱ�)���Tªcz-92����o��^���*�d���H4�.�d"�>"D�#j<3�V�5Q�h��7";	�Av�{��G� �b�@; ?,A�E��p��"NN!�z }r��%�k����g1���] N�;�~�����?G4��r�p��2[��E��!�a�	��[�<�pWUctRMr"�׫��n �I�
 +��X_H�@q_��*�GQ����U=q�5iGH���F3 N���0�j�$�dfW�^>��P �ԑ/$ó�lj�с��q�/W1^P.�5���>F9��0(~	���v��~6�.ͷ���;[�G�v���g9@�F5}pJ�F_XC�\{��!e ��b��K�A<�'� �2�%j_u�m)���k�KL�KeÞE]��d������n5�6���Ў7�8�$m���a��c�NP���T��	�;���9�tEu0Y�J�/�%`]bE����P���!;TQ��&�Q�~� s�����Ⱥ!��s�C���ogTV�sq���{�V�=EV�����"���IÐ���5��gkv�e���b�3@�!�Rjh��u.P�ڐ-���s��B��hw�����V�x�խ>U@�B,��@��+P혺�#P$����A��V"3��x��1|��&�ez�KXq�]# ���Z%�<w��1��t�*8%�t}�{�ԅ�5���4	��\!���Sb�/�,	� �<K�)�u�hiw]�٬���4���s�M� ���݋����.�����"-cR��F����Z%� tk]X�Hrd�(7��A�-��(	�c�����ҋ�D� i�g ����$[�����2t�P'�`�	Q�Y��x� ��@����0z.�����l�'%vꀍ���� 3 Y��D��v�m��t�ts=��B K�@	Rl$��+��]<�7}��n�q%/n��!>�l����p�)0w/�#{n!�|/e'�X���h?$S�#`�<F	�!�y$��ݐr��Z�u��C�$�PPI|Cؐ�%�Gc���VV��p���L�B�Tc/��{=�N��ZB�,aow���������	�����}���:N���j�;Q��6f��,��0<�
�|4B?��/Z���q�v�""� w�~�� 2A�0�$U�*��C2%	�%G���AAe�&S�S/)c�c�̱���M��f��K@c@�9d6y�t#�~Y����a-�t(+<�">�>��UlHD�#��"ؖܠq�Ȟ� aȅ���5�H٪\�X�p�S��|���@�Z�P���a�J��:����E�����+��vC�VDh�C��8d����+��=b�����*h�j�gDt�,T\8�����$�%�e	��bX tG@���ܗ��'���$}]���C��*�؎p	"V �/ 2�v���O��a�u<��d(�K�5 ��T��$Ey?p׭�?[��rʡ��dA@�_Z3|�F�SR�:Q'.��> 5�����k���+�o�e�7� N��$[�i# WĚ'���ò��7��\�F*�R���fpl;�ыh�0{�X����@��� ��i��t\8��c0�7>��$��� �LILO%%�P	H�j�f
b��Q�ؽ+ Uf�(><C�#ϻ��w�d)G��Æ��9?���h&Ȑ��`���9�u%Xπ�ta� A0#w�K���$@��a������B02iʠ\QS��ַ��(�9���!�%� M/b����Ng>�悽��5h�G0\���:4�)�+�8�P6�O���ĒC*����k��yU�7,�@HH��^�	�vۈ�D�2�\�d��q�_�Bn�uJ9հ�)��;�2�'�6��9��b߇�G9�x�ꂙhn5�`yyS��L��*	`�+n͆q�nSw�*��`�� v�{��ȃ�X�O%8�jR j"n\�z�e� Ru��;P���i�۸�h��"}�(u���}�7u_��V:�~{4U���X2���6�A����~n��5�����~�AB�<{@t#Y�	 v��l��>|ε9�V~���W3�F(5��P��k���Q�8�BFo�?��
�������')�e�;%�e9r4���ZWO�^���:�5q��Q�p2$� y�@�:̤ZȄQUM�=��8Ö���@� 4��aؠr�Y��l���	/)���;�(�@�������Ft鳄^a<,Y�<Mv���F�[A0��Bˀ; �����PW��`~�*���:26Y��u���7Zu�
�����	��������t>V� z�At��X3��B�6@E��-D�L�)U9`�Q��PF�!���{��_�t:?�!cKv��nQ[�<7 1�����-�~i9��B{�M6��y�/hX�c��"��:���
,��G4E+m :��	�"o%��c��Us���vs�B�A��v%m謊���Grd��Ǧ G����Ge�����E�O	��^���L�-C�0i���E(���A>,j����e����65t��:��E��'�ù =�H�6�Ϻ��#�D���K�-�E���E�E�u��e��m�hW_�EP'��1�M���u�L��u��
`� �np����k?|��<|�
Ʒ��l�2A�Z��@�O*�w?�*;@vK�+2PP-/#�vX�i��a��Rh�÷,``� ��dg/C5�(�I��l�o��BѪ�>V�0���� hD�	S�
���=ZA�� J.���#��C!��ۻ���NLp��TТ " c�#
��"#����"PMENUgr��0p�3� �P"! Ȇ%�hg��Ǭ�%'�ta÷�'��j%v��{%h�!R�����k��	r[�[�$���v�z��`����S�sH��/�Rb�sP>��&{rR@(��/y�m�z?�QQ���$��z�O i���~���[^2 �`X�	j����
��� ˀ�� D4x@=S5� �f�
 ^;�$�B[�����m��
��6��t��Ԓ��%-@9�|���6 �R\�f�BF��@f��y�� ��Q��$Y���
nH��0��ED�@$���u� n��1��kǷ^͂�Ggu�����jiF;5�86�|�E��j��%��bu)4?%K�fh6�ɨa���vQDxB]�bVW��a@��|#]x��$����~=�=a��}���]��9�o17W��m��Z2I��
�t F���®���~�����@�UB���"�[��t��Ug ��2M��h���l�8����rA0z0Q`!��,�Y W��0K�j��_@,����m;4A��������l�T�I�)ځ������<�bC�h����oSH��ƅ�B����@fs	��c%���������߼�u!UN�ķ}�'����f�0�ޔ#��.�U����9�%@߱F�"P{
��(��,���EYH e�U�Y(d���E���#���U��'���n�HE���k`�
>/��:~��`�QW	CrB�p�/�j�6WV�j^Y(R�4k�T�,Ym=���Da(�X|�������W�]B�K~���o���Y[���zT`*�;@P+h:ɓ3�K�X)�b(^fI:&=��b`B�/6�$�4x����I���'(h�	s\��%݃���8	�	���Е�})9�U}�}hIP�q��	�%�`VVSS�e00}�'��e"^ZP=���s�¸�':��O�M�(FB��Yхt7s��G�~�c\�l"�>��gY�U�@h A���/,kXh�[����t	��$C{𳜂�Ktv}�1�ыh�2�0�|�|!�����qj�/�m Z�}�hZk � {@�ٚC.��Ml��AKf�=Tt���|�0�e�]�+��$�uh
�m,��_-h��5��/\lѳ<RR����x
�$��Qq�WeE�Qǔ�`uD��X?�B��t!��a��9E�t�R��&�!��j��ɭh���]�c+QQH���I�re�����!�%W����b�aV��!��W�0���M������d�RD�� }����ٕ�x����fj%f��jX�A��-��ȋ~�#	��A������_��hK"�%���ɞ�U��hkH(���T�bVj`�71�)�R�+�SR�,��bP�|L� %���jX���&�2�EH�pPu��(����P"p��,�4Q�~%H���v�d��	 'b�+�l�T4O4XЫ`�2:Nr�RR#�'H�"�" ���	��0,
Ktp�����	q�ڡTf�owm����@��2�����A�h8rR��~f��	
a����>�u59\uSx�,#c:zJJA�E.i�JRR���E$����<�9�>P�P���ZW�[�E[��]{�־"X��7�c�Q�����
9�̅Խ:a6�Fm"��"C���y�J�j"74hm! }�����_"'�k�t�!B�w?$4x_tt�4��+�(Z���huanxZ�CL׼��O3�)&����T��W��q����@��H���H	P���,?Ǜ5D�tD�LU,�B��B��/ -
��L%�����
u���#�=��Z@4��!� �2�#��[��
]���!�=�#cPp��";[r1���a�����q��
��+���2e<��WC�^)\t(��vt#s
���,�'6�qs2є�� �5���u��11,� #����P�
׺u[X!�)�����H����:;�@� ��=��g��� �FhooC1���{x��
StX����U���	W��5�>e�^����W�ڍ��u�%+Z�f-��@��0���� Z�α�P�{=q�B�W{B��`�=QPG�K� �u�!h�H�#e;��x�tGA9Cu�
XA�SFA�5?4���~�� �V�p� ��pXTL~��A�)tm��3$� ��S~�����a������[��������3lm;u��7��<�5@f-$D�5�u��.�B�=r�&��Fkm�TgO�n�w�}�h�}�EH�o�@Wq���g�ڌ�W��+��?Ja�P8�#𙆘J(@�TF&0�|ơu���1�i�X��;���,�κ��D��):<%[�m�=+�<ǀ���M/�O�;��� �jF%�p+���2�5TqfB.paY�1��t;{��D�?_�G஁��%�kW쁀�#��Q�����*B?p���&"���U5�"����O�o�*��-Gf��
���9𒅢"aSݏ�&T,d�.9����C�uB>.QQO([�(F<�.�{�$������ǶPPm����6>)�����
 �h(Db  ��SS�	����h_4� d���(U��1L���My8�]�S11W�$�>��m�h�7N����)Z՞�8u(;D'(��.�`3 <�a�A�p�!#�YY��'�1Qѳ:;7({Q�8�� �h(���& �qo�8H1IS0_�dQ4H)݁��D�i��"<\ T K'��R�h0Ɏ��QS^u�T�>�!�}C�!�E�$�Q���8W�L�G@"�����`� ���ơ\�8P�ª��t�@a���Xk�''�7�M�Y��<6�NNPM�=Ք��*��x��Ķ9n[�ȃ��xA��k�F��Gu��C�<�P�����}� {H�E� h��~*��!��;������o�j�۰0�K*J '��-�u.�۵�u��P��إ�	�8�]��u@�G�4:1��x�+M� ��c��C�;U�uQۍ�K�u��;�����)ب9u2������"�� �2�A8`#BR<P�c�k��C;]�|��ѵ-��޿�QuY��Bw!
���spCp��J�/����2����d0P�ED�xe6�;���%R?�����±�&����0�ayS��B-�?�fi�ǻ�#�}���-�jNW�k ��h���1R+tȺ�:SZ�C",�)�P;S�b�E�� ��ڽ�"Ǆ���	H<l��6d
��仴����� ���b{1����SD�j�U�7�I�=v�؋�x���+�1����#���x4a/)h�@�g �'S�������+��h��"�����C�)�o��� �<��=����<����1D"�#�ٺ.�\_��2�Ύ����#@��0���ا2#b4h��
��#]+�� 5`|�k�h��(]��,˵�nh��VQ�;H��J�b�m�}��FЎ�DS�uV�Vh\Jl��y�̲�G�0�}������U��MR�I���Բ@� `�V�9�����}e���Wm�QH-� �`T5�Cd,��Z�d�h#�������M��Nɠ��x����o��x�O;�9�u�A5ߋ�KK.���$Z���AQpE�}�j��	��ң�*���i8d�y^tQ	�C��Q@ӍC��R���\�v����<�<�m9^�J���L��������9�n��_�"V�"v�~�*�M����o<��H����>8�?9�)%�)�_� x�@ؒ8�ȳ�(mtتZ�W ��o�=�"�Z�=�
����1�=��*��b!K��\�U$�t]n��tH���� �/�2�"[�E�<��
���M;i\�Yg�%�g-Y_�� l4f��x�H�� ��@���x8�$,���A�a�%�����>RA�0Ga�p�B�KE? ��מ���"M�۟kE��D�;xP\�7w�Q�Pݽ������!�?��)X�t��ɠn��	)�	R��f9�t���$����G]Q�TP�����B�PBQ�&~��#���,U�9��p�����u� p�ٌ�iu9oa��>��,����W�UP���M�3;�l�V
�G,�
�t���mk��^2JM�Jn�B�Qr� ��&Hܴ�U3J�-\*o�?��!��bl����B�e���@�%W(��|�%[E���S
�MW�G�%�f!��m~��2	\6X���B�Z���S�<��(�?�}�̌T:��a����F��f�"�X�zXN��Y�\�
�`E����rA<hйЪ��Z�"v�p�ط�`�22U��`��_��>	/������B�����~щ��8���N$����:��VV0��-8Ӄ�w᫆�z0����Д�f C������ ��`�F�����Lq���%���2b
��@$N�20m?V@[�S]�u��a�$�$�i���u��������D@��M�hYUG?�b�#,V��rU�4�*jU�͈��X	*��C�	E�!�,B/M6�7(*0{T8� !D��(���ֽ�Ň V��T��T����$��"���Pp#I�9!���,"��|���0 "`P<x�[��tEsQ��������Y�?�x�����;�$u�J+�E]���Ǡ@�O3+�5�P��p@]��_�lk�h���9l;9Lp��<�IO�lksW{�n���C�<9�3�����m��*�Y��f�eGaw�8��Su"�K.S�x�Fk'��[K�e�E�$E��3f%9!ƣSBPfh�U�(�5�gS�2����:�F���+�-����?���h��8%��H�M���	vN�_S�Шx�A��yn �5�PSĞf�΋�/�=Ro�W�)��P�>��À��g=5��"�*�ĵîB_�M����	�M�����]CXp�bS�̓�Ĳ��B*_T|�4.h�� [�b4�1��o�ߟ'���	Y��a't�`��q`̓]������HC��& $���=x��J>��)#3�g@>۱9y�;CO������A�U �����ǉ�&,.x����"'�XԬ�D1y2�ߗA'��B�=NV�	�}4X�A�h�1�:w-5�T��{�D4�⁻W�}# ��W�鰋}��E��:��BP��`9�<ہ��Ɖ.��jYyB�����H�v��������$!�u�9T����Ń"����Hj�+��Y{ܪ�2�g�f�E�U�I�l"�GUd�-'F��KD GQ9�"h �i@�>�+.�=�ܗ�V�N�ɽh C�hVׄ�T���@WfC��(�d&{5��Tw!�aqV��!� ,�qVi���$�â�1٠��a(?���d(���"@8�r�7:>ߋI��r
YĀ�	�7�����e]'R��N2B��R�SϏ��t��� ��EƖR�D�:�}��@��'�<?�h��TV�WÆ�S�]���@6�@��P2BR�S��A�)�CPs�V���j;�PH� U�l�د��~��=������G�J~6������t0�����^�0|�I�L}#A���%6(�Vg�@��+
Q�;���[�!E��h�Xus6�[j���	��U���}�mv����ՠ�B/	��Jα��ɀ����'6��l3 $: 5 �E��ԉ������.���N��2���Sn��VM�Q�9�J�Qu�V#>�
��E�΄c.����
�ᳰ�~:JC^�R^�S~A~���NA�pF@�����o�sU)s�@Y�F�cH�U�pBl ��*�y��#�X�(R��;�l�Ht?AR4�~a�N���ՄW��i7�@�K'���ҩ�� B՜�իu�ԕ&|�k�`Fr��^��Y,NL(
�j��)����
���WP��"�I����-�^H�}�[=�xG��X��������ޏ���z;�J���H��s8F�tE��n�S#�%�&��wP�T��ݺd�Xy $5�:��&"B4:�5U���GQu��C6�=��䌯
@ԊW�!�[a%��X(��!�Y��v9��j_W�	��H�d �a�i�Q����m�٭�jr^_+�ʾ�jk)�ja�-��jR�+�(A�$$���v �7O�u
�h-b�p���2��p�E�Ђ�uij�w�����
�y�
t"DV'Eυ�إl�1�wHk�A�ՐT���X$@̲P(҉�j��Gk�QqYe��QU����,q�����pUjP*y,�.-WWaT�f��n�m1�#Ԯ�`t�]�Y��
 ��݃Z��Y_)2���#~�
bc@��������C���H2!�D�U�W�.�gt�.3?�� �Ȫ��4��Um��[����u.s�VO���96(G������!t�2�cVI�����l�=��-;�P����ҋWu>1eh��J�=6"�j"PH4$�,�	�����R6�͉��� �Q!��/�QD�5"�;�ѣۗ�׋�F��{�"!��uh*# ` h)����&�P�Q�}��E��hr�K�@�"fFx�s�i��y4���%��pV,ZF x��λCI��C�j>h���XA�a�1���(CvL����3À��� �.�tPP�CJ:��7
@���������"��yjn�(����0՝G�E�P
�?�Q�	R��;�%�H	��+��7�@IN.R,'2I��oDdh���Ed;���*�,8K�!b�)�E�ڿ�.>.��4��M��M�8d���
5��P�P�Hg"�0�ދ�ǍU�~�.Y��R( GXBD&#-f�}��
� eΟ�^p�A�S�����T�uB�ERR�Y�м>�l��h�%��jdD�Q���Q>Aj�ے�O-��f�Я����u�p$�cq����A�HI��y\��>�斊%�H��T������ZVuX��n���?(�U������ݼ(rC�	
P	���_� #I����ş������^��	V�WdZ�$|�-|�h,Uĉ���AP����c4m��t�kS�oIA��M���NT���e�f�T����������b
A=?B w�=�v, ��*�P<�ĮkJ���A��Ļ�S�J�S�Z��� ʚ;�C��۪�:�cn���9�r�QR�[֭f�l5�hظ�o,���4�s��W]��*G�?��P��k68�W4Lt-s0�EA���6hВ�E0l�gm޼�¨�E���@��DL�	�A��ENh����3� #A,�D��+Y���[R�@��S<W��]E`�d~@�ܠ&���|��<g	A����Ef0�̑!`�����z<��; �z	( x���{@��aÒP���UC�4���[nK�7x��	�m��4���<
h�\����tZ�����bN~L�5}�C���t�J�Gm�����B{��K �Qb����S�������V��P�~@��Zen�@�tE�M��Xu�j6P�:e��ۗ7Y9�}A�!�.�%����&�n�ni+	�MN�2a,a2Q�\U� �ь�D�Ӎ��R��x'�0R�膮�s���P��ֈ�&_P��q��"��t�����hnK�P��E��+��.�Hw�R�N�X��h���X<�7MѮ�u�
ab�b�gm�hX�Zv��6��B��i��B���.�_�CB�݋�<�o���B.�Jȉ)�A���z��!�*�f����[�@�m&�������D���@bv�
�K,J'�F{Y�܉s����K\"h���{ݯ��K��.;;v];�K#t3�2�ǞM����C2=�ǫhpp�w��F'�mp{�p@濯Ω�莈�^��A��/[v�f�zU��۷�)���B�݃-L�z%Vk����4�I�V m	����5F%�~ 	-D�<]F��F��J�N�Kte� �~\�ݮa�~N[�������B���Э�I�_�;S�M�[���YL�aȿV�v�����D��@*FHF�Qk�;I�~c� ^K|Du�1�lq��ǋ���E'�~#(
f�@u`D��!`"�)�Y�u?���g7r���:P�1�����-�^�M� ��Tı���2�e) �,i���b�]�uI��A�U�� YD|�<��e�V�_s�*@�&���3-���IjG".E��u�����*@���k1���h0.AlsZ�܅�e� �\���� ��f\�����# �a��BXZR�+�zK���v�ѻ��`�V�N���7ĲՉ������-,Vڂ4��]�U��5l ���91�U�X��I�w�V�|�����!�A;�U���|�#!U��� ��@e�V��� �pqȶ�V�BC���X��k�Ɖ�O��]>�Ǆ.&2�Z%<<�v@ƾ�0u��@V��^
�Jp�`� Ir ��.�h��S�)�P�HR����l�
_����W��l� k�	���9)��:~�	ߍ� �f��f��k [��ن��R��_
r@ѱV\���o�e���)��T�VSU�$��%�+I�����4���PS���Z�rSB[�dy�A��j��RnP
�t���*{(�� i��K( �{�R�����;��@���� ���`UػD{1��.��?�Q��	p�5�z�#@@����ue��t�
'�]��;| '�O]k�t�@&�>����[�w]��\o�,�`2RC���u<�Q��/	�Q����n���n=w�$����Y@��r �~[�Z�E��츲�/&�(P�ջ���	;4���B� [D�c��F�8ts)g��.�x4x!C�Uw��V�
Ȅ}e2K�5�.��;�F��Ou=�e�H�L�tf�#~��JG�3u�_�5�)��h��̲N����K�!2��hE�l3�(]wɃ,��v{��듾�
�FX���sA-�R.P�%���b�r��Bm~p#�6?� ��X�g��[�~F����`#� �	{>t%AtCw�_�}�<ޢ��{�t/��m���{@�����Á��#���}��԰*5L#F��G����Il�| �(�
�=�<A�!�^�4\�n�S,Q5).4�n�7F�ϙ ��/��1V�$ ��c�y�&Wܰ�,��FQ���'E�9؆�5�)?"��$[����k�@hU��;!Z�@��rt> ��&��>�C�v'�X�/�ĉ�k*h�,^��M�e�h�_��Z*�Q9}G$-���~Ƴ"5Q������T�ހ�������<�U�� �\�,h�� �V�" 6��@6"Dn���bPݶ=��#��*�QjpI�#�~�0�g,S�F�mdAr�L��g��y��=g�L�@��n%� �,��t�fŽx��  �%K��`J�%��hܱ�I���@,�R��$��6��49�7��{�r5u��ԇ[0��yc\�ń�kl����"tL�`�A-9��M�>E�;#X*ߋ)������{4;}Ȏ�J"�;u��5��{�YXH_���;�tm�Yr��,ݼ�-Zȱ����)�����=Qh��P�K�"����s`�mʈ�������3��zp� ��M� ���7b�2:�b<�u���U�u�5�$Eb��*	w2<�^�Chg]p�!gUy�@K>x����?k�=,؊v��w	��՞y�$Y4���i0T��i4�T������K��%g��q,ưKG��vD5آv�wV���
�G��K�[����@�(r��,���!j��$D{� �^3���d���њUߖ[�B�PuաZ�E-�?����]��5u܋2@��=}ؑtT�ֺ�±��_������U��<�V���"ض����7�y�Z3�.��J��ދ}�!�	�u,u��߶�#���u��
Es��-�'G������3���n��1�1ˍ4]���76�ؽ(uʋL}�����s9�&���Ǩ��79ܼ�!	�#���_��!�	�jh�"�=��H<u�:EC�%ݚ�v�4�����b���ͭo�1�1��?]��h[8C�貅
�GZG>��JP�}܉=U�>G�-u��P��m�5�m�����j+�A��˛��Z#Eg	����+o�7�ܺ�vT2^�Mn����ø�	�1p���^�S�?�s�2���x��%���W�i�28V�EB[�v�9�T����(*�)�9��0��3��5X�-T�nh� ƀ����78��
$H-� ���}/�sp����ݸ��q�8,�8)��`6�p���m��@^��ݍ��DZ[��N /��
��Љ���ɑ�Ш�N�_n��R���PmA1�8�3�-�X7��F����63Zr+�؈rF ��\%,l{;�(�� !��p�#��Cn쀳O�Ef
u��@k�X��+ z=��n�� �|�g�l�{�PYX~k�K�R�(�I�Bܡ�<�94�RR�XZ��nK��xJz2��v�������@hT��R<�d�f9�u{%��h�UN,�"�����E�	��5��6,�EH��SS�mAPN�*kU�^��l滑�ц��sr�= a���Vհ[���!�n!�00J�&⎜�tU���
�ɖD�3�:'�?b���C>�#*�D��,��B�-H�1�J޺�M�R�9�`�����\� `��E�%(�_n��L�� �z*�4�C͖�D����Ҕ�[F��F��+��������A�ۯH��G �]��9oQ��C����k�� Df�P�T�B�un��1��z�LN�E0�9Q��[9M�QW�� 7�;{�	�se\*i�. @f�4X3�Hu��qԽF��S|�2�� �"@��U�F�����+�(���F�\��
�'�(�eI��΃��%j��+#�БQm����	E�̸�̚��^���W�QV1�hm�j�K0?p�P�(J�r1��w�5t�$|���#tXt"Sp�ՃQ
5@�	y
��${�vN��9�~-���B@53�6[Ñ08�8%,�R�8��6ƽ�3R�A��.Զ��sK���䷴@1�aB��|۶�ԍ�BlȷxNSh�u '���3�%eQf� ���YtN�0(�EG���GV ?�t��0=(J�Q�T,t�`�~5f`O�7�?<'_S�f��E��8BM�0FE�#5N��~ujW�'ډ�Ĩ�$&�Z�*(hQ��T��E�fB��M�K����.�m$ ;�B+B
����(��8�F|�t([Vj&<��B7�&l�}1�M���޹�����wsMwU ���[���)�HO���##I��f� ��`+p���f��s�Ԩr@p��\�a��"xu�[)̍p��Rbfy�9�uko�x�Uum��}�0�@��uaS.�ݰ��.uD٤�$pWx�V�FC�"[pS��Ѿ������dr;�@W��H�v+�_���D�ͽ��_�L.G��u_58RP����!��'P$�l��jA(LT[�+����&�6l5�
��hh=��XP%8��P ڣ(V� �8�c	$��h)�I�^X�Ktw�$��c }+�1-Q���-�vt��;kU�HUt�Ut��|���%s un�F�fNF�∞&D7q�����(Y**�6�����}�je��S)�L����8Cd����5�f@N!��X��Uz~*QP��ј]��@J%�*>�t����0J��A�&�/�}�F����W
���j���+H����s� �m����T���(��&D.cKYE���	��A�%&lI@'���:TQ%Ðdԙ��d	��b|��Ϊ��yQQ�ײ
�,�Ep�1p�*Z�{O��!`�o�ڜ0N���'��Tǽ���$��	!��?��6�u]/���M�Գs��%�>/�����@���J�{�V���Y��@փ�U�Y__ZV��fb��B/(\QI��S��lC_S 0l��QODq8�3QXUg�e���]�O.՛E.Q1:ϸRg�	��$�5�$�������h`8�'i�f�.��G[�H�`�W�Y[%_Z	k5N����;~=�ZY�ḫ)�X��XV���{��5"�u��ؕ�� @!J��E ����ͮ�*<z�{!u��a;e8���Q4���uwCt(L{4�.t �I�OT/�W0�%#^��z�
�u�J1��8F���iПweÞHt$BuC�����SFt_5�����U�SЍ��%��{�r��4d!�X	���A$�I�����-�4��T6	n?�DtO6��ѐr�G/U/g�o/|�r�!��$Q�~������{Z�"���ɘ#:[3��8s�=��C0z�jȵ"�x�<Ƹg�U.y�勱^���/"����&9����gc,A�ǡ1;u��^8iqx{	J�=?���B�0���]q��fiw�
��y�xf-�Ky��Q�π1�є�`�(�0zBt+�cEu�fRx�f�,nL �TW����/��2g��z4vh�YXZ8�"1RC��]e�Д0y �U�Z�YG�d^cޚ��Vh��3Jh)8D#�g/���#/���8����lx肥�~l�H�O�)K�c�lܹ"=�b����}�f�?6��bǺ)�z��X���Р�dꕉz,���$����;Œ��tR�4[n�e)C;C�5u ,@��j,��
�n���c4I�HOV�(;�76rSj;OP��-�H��c��rdd�WVVb@^QQ��.� �N

�6d@
g-���ˋ5lB��a�y��gΎ#���|�֊q:����D(l߃5���RU݄K��W�ސ��f �z��D�	�WW	���VV"��쒤Om��m{;	����p�C"Q��ے�!:�^>T#Ҙ�,�N�P17c��P; �����]���x_]�N�.+5��!�1����.�a�@���ƿa���<�f�$�!a���f��F3�-�3�/+��������j��x�����&#���FC�[�Xe�Z��A�;z���(��k:Aն*#f�MUm@[z�P�6�����3}�X��ʀ1�&-�	��h�~kP�m>0K)Ӽ,��P��TO(� �6Z�[ПZ�V�L$$��@t�FP��T$�_U��ẁ[�6T�=�v��޾�>��0�^�;T,ч˸
}+��+,+�(��k`_�,rz+������hA��.htϟ�ٿG�Ӹ!E���09���\�L{c�+5`�����h�@/��_.l[h-vϕc@3`C%9,��$86	����U 2Ҿ�g.a�L6�d$g�@�=%a�&��BX�Ö�2��Q-�Zz�i�Q�I�~�u��A�촌�U߉8:"M��*��p���Y^Y���"0u;([���CZ��$�>f?��� 	0Z�nU��������|�0�vUp�.�a�@�!� �q�רV�黮���$�i�A�[�]�d!Ǜ4j0�F��Vǉ�XOJ$tq�7�'۫�Gb��?�W��*�U��jp��x��	4ɲUW5���*�ȳ��6 $"���(,Y��եx(d�5��g��_ZKXL�DK�0I )tD�@=/◚�TA� |��L�Hf!��Z�����oXnm� �4��@d�c.�ЈxT�wpYZ����6�nl���Pq<a�@8�,1�,���G6'��6=_�A �Y�~W$DPW���9Fw��>d�~�,p~)w����F�%��h�ƷW�����?L�d����[��[���Y�����3��\�HW���.����Ro��U8)> >��<8�nv�s,��@l$(�8��,����sc�)�|׋��qpZ�}cN�ET�RF?,��,����;eC��<��|��w��6b�x�������S�r�uF�����-�zЉ���	wUL��0@_)z�k�KL��o���9�s$����4�1ɀ8:5c��@�w��U�,Zt�e���}�;��?Ǆ$��[�����V��EN0�V�l�Q�J?���Z&[�g�@sjPᗞ*�_��x8jDUӝE�t�-���Ed�9��
�=�P�	���(w���
MX�w
�9CCQPg�B[uaj.g�#��K�(�.��	j����YB���>~#H(
u�DW�+��lNH��6v�1�/���ń���E�
<:(\8z�ϰ�,ngw��Y_� �mUV��KM���t>1@\k��&5Dz������݀n<uE�>k��;��n#L��6��~7t�������AFt� ct;��!}i� ������}�
o,o�l���w��?��s�<+t�<-t����_�YƂT�%	8�t�mi�_(#w�����0<	v������q��'\(�'Jbr#>���� C�>-u��.�pk���k׊D\Nut���� 	��0ou����l�7؃�$��t�C�%'$FE,��8���<Mt<J�M�LG��m�X|�~�ıM�v�J7,��~^kt�7Lc�SZ�f�/�o4j��R ��
qA�U][��Y���L9�ENt�mxk4��G�+� ���f��ۇN�p&~j�P�_9�wlϸ��8ju`E������dc@V� -@�� �4�w�/u��z�(�Dʔ��T`6�B{,Etd@����<�k�׹Q�U��go�BP���loa�\"-���fD�;<��@�����PĻT b�����]L2���P,�	�Ĩ��	�r=r[�Aku�U��f3<C�$;Tx[3H80j�d�6\	 kMX��:_�/a�+�M ����i���~��t-���>VE6�fx��o�F � $r?�&z���:�A�nÍ})M`����tN�m �u�j�f�j�Ί�t��8���6�Y�CK8?Oy���ZM( oL�h�M~�~(�dN��p��F����X��X�(hF�k~���~~k�<>� ]۹����l���:8��u*�`�k�J#(�nf�3�ba���UiC�k-���b�{T�Ue�kxOf�rv(�Xt�醝$��Y�o��/��4�QH�fs-��AJ����.U��;�Fs�$����l	�i��[i�����)ր�@�/;���X(�����5�;�6v#)���\K�n�u��� ���_p���н��,$)��v�x��iA
k��;K���l*|��H�k�y�+9�9�yBn]�i�QA�;l����6s�U�H6�hD����E��4�z�BdmOD�c@�3<,�F�#vDd08^~H[.Y胈u�L$,�AHo�@UVP�av[e� 4UG_Ȧ�$��]>�8e�B���CG�g��U�R
m2	��#�X[��)A�juR�m�K=�f `��0�z#d�x�2� D�&,�&���~�mt�M�YVi�� Dг��V@d�D�F�kj7����M�9X��ɽKh���j
1� ̆'(Re�6XS�n5&ڠ�}��0[
�-NX�lg���0R�|�5[�I����*�0�#nH���V��B�i(�K�ϊ���Y^7Z?��<$\I�kr7@�������~l(^��1�>u��s7�.�+��6/��3/I\�5U]6i|��d9�.�FL9TRo�Y�� t;K|��Fsv�4��8H�	n�.ԉV�&��%�zw' wh�5>��P�u<R!���-lK���?-�<�'����V%�VE�<�@�-� �ӖP���M���ٓ�a�"�JF�4���\�؈�deyQx�H�@�8��LJ��x���:t�xհAh"$(,ud04�xf��6 n �@>�H��LO�bb�?X����9���w8,�7����_M���$Y��BR��͞{�C�;�uJ�
	���dϸ�ͮ�Kt�30�l'�+��/{mT2�`�`���Ä`LR���+��Z>t�UU�*��6V�L\cx~F0	I��ut2�R��[� a�b��X�.N�F0B*��A���������+8�����F���t-��U(��F���Ct q�!:��x�joT����g~E)���Q�t
�x+D�+P\4e����zQ.������+�l
�9�� nO9������0��P�YKl8�>&�$�M>(��2�+��A��rt:<wϵ
o7<at6��k���TJO�	� j�1�Z���%䜂H�q	%btP�m/o
x+8�G���/��xuu�hc��Vmjdˎ��XfŢ�A� ���xE�])D xV]�[�lD����KB8�w$�@!�9M6���ƈ}�j�L][�z�)'B	��k���*\$�{���z^m
͙6�K���7����f�	F�G����ĻJ�P�n��'pC3t"TǋU�h0�L�Em;n�	eۊh(�o{w���t&�h�@�	��1c������n�uf�(,#��,"0K�x�4��h��C�;\H��ti�����WbV�YN� �|W�9��E�bY��U5(��PC�\�5$��?�O��/�:r/���<ȥ \�G�vO�_!��~
�{]lt0��3,����AA00|6�W:v Y���u~�B�$P5ذA6$^9�Pv��		2�X21�[H��ɝP[�.>Lxu8��^5.��
6�#��Zh�>5��VseO�@o:ʅ�J��&tYM�n-�ڨ͉��M�����X��@�5̿!G^[�[�)�f�#�|w9��+�~��\���(E�T�vE3�3(b�xŅ�_o7�����'Q��-($7p	���nLUy�rU���oL�t�b�Y]|�X	�0V�O�-rr�
�����! �>���JA��,�`�
��@Eˁ���MH��)�u���=�? C��Rj��t0�|��j�ZY)Ǣ~�����W �
��7�X9�u��EvW��WUo8��6��l�8�[��@D�i��HO,1M����2���q�QV����\���d�Z�%��y|�VB<�͠�� {G�"8Zl-~����RWF|Y<����1]�t	����l�S}�pD�\��2���hM8t%�9�<���)��kWR�n)��gc�g����V>���{~%Y�վ�E�E'{�@t�\
Z�p�uºH�_Z��?PM����~k�Zh����T2&QЎ^�T��
@;Whr��|����J++����s|�%��ZД�����Y�m�
��U��/6�}���W��
u!�@�y8�� �-��4+�6j��@d�ɱ�ho;w(���oDn��7�g�~��ٿ���D Řz���y�����B�����D�
�H������������׼!э����j��Q�E�P�T���	gc�v-���ۀ-���A���-P������X4	��u�jd��)�:�y�o��,�t�Rَj�vx	��uTo�:	9�w�]W�4�90��u�Y��.��~ �����y����V�|�i~��H�)�����vX-{8��X�ah���(U�0��;���Pe�0���E������!Q��VÆk7+�@u?�����0Wژ�x#�m.�CpP�P��R�d(l����9,"�̥�?�P�%$�^���f���A�����Wo��b�!kbA�PQ�Kk?VY^ZD��! �"�M7ш�X����`LXv�򈅒,���JQ���WLU��V'���,��4�Rx-D��]
�oZ׋�0�&7�ݻ0;��Hu0)�R���	c�R�����H�JB�)�eרּ/r����Ha��;Ȩ�^���aU�p!�|]�t���*���9� �Y9�6xC{ccv+������l�i����8�*u9���ú ������3Z;/��',�+A#��g{��W4P�l�X�0JDL��P���}V�&yO{Y��VQ�+"HO�m�}�k���O���K����v�� )�fAp��r��`uR)�!%4e�
Y0��8u�|�f��i�Al�Swo�
b��	��b��h�A7��/���N�V7�5.�(��x��Hu�����V�%�@"D����V�vV�ex���9�^��^Z��a�L�e6�& "�~a�Y��V�" [b�HL��x/�[V����x+�uqPL:�o��HU�t�pPK�@��L��%�(G�tf	t���O~M�H�.��EmM�t>~<	
�,�\;��JPM�g���"�P�&���*�>�
t{8�oix|��0����B�$Jk�6���֖|%d�h�a��#�ʸj7����t�"|Y�[ۻ/n6A#�Pڔ8��^�A��2��w�@7z-����ƈ���%���h�\\�"|,\99Hg`@D/��o�G%� t!�u��5��R�M��2�� ��om�;2�`% �x`Cv֬ ��? k!��o�*pր:*�S#�v���@kr���� ��)=���~=�:jT~7�� 
���[���wvn-v�ʉ�Z����U����b�Rрz�V����]���(C��ji����;�d9�~!���~!+Q��mtS�1���C!m�:�C��sĆ�ft�A8uF	����~��=����׃�
��Vȕ �
�{���x\�-G9�0h­{�>$*��)fF[ ����D�\kA9��.�F�D�ua.� ���>Bx�`G�F�f���m �٠8uF��T���/���o�)щ�J
����	F��Z*i	�%S�EG����[�\\�:uU:	����"T������6���G +l�`kBE
��{,��ވ��S	-��ͺ�S!�cHV���PZj6\WωOۂ�^9B��[_TQ��0�&th��d�p����	�G�JÙ݅fmu c�ģQ�x��hw>�8)ЗH�ܨW딗�_�SA�:���c!CÐ(?#�P/�r���_�1jo�������D$�:n4�^�d��Lj�V�]ŷws�ු@|%�$&�_�5/t%����Pr�ԃ@w���95AU�"L�(B����4}���G&�P�����G((l���wol��h!7�h)�
����� -4�[�*h��`H�$�[p�笡��C �t�z�;l��쾮;� �|W���I b�t0�
y.�`�o($��d6�C�
C��K�!�ӼA��aX�T;�)�`CItL���Qn]��]Y^�!Z�;i.K~�E$p��[�t�;Vv��n�B:�S=f�^�J�9��H3�6Xa��YC��@b`�a��a���g�s�I3�H(oa�}hDYig�{n�c?*�$nk�<�NNs�6�A�N!��`VRy_Z�Uo�I��sN ��>�A		��z{�c�@,%�H�:j��KXdK�&U����; ��0��	�h滾���" ��H� |Ze�@+ ~��C�x4����� �����1�x 0D�`�*ʉ0����p���}��j� �剱 Z\YY�`9*�Ɖ��X�lt�Vr���ϔJ�$���	�(�e�K�@�&tW��"j< ��f���Rˮ�U�m��rB�/ْ֠�+�.bX*+Vu���_7W�wWMU<f
@���f5@��@�2u�Y��*�`��r���!��`��8�;8���lF-f��. �g�r��dB S�Q��s�gڋ���(��u}l�oQ(-T�If��<�j ��z�9Z*l�~t@G��i�KlP�u��(a#�J�X�����(�w#�Y�9Ft#��곯s�rt.�����ͧL@	L�Y��,(���^�'��Ք�����J�<2���eG*��w�O�
�W�rU�c�8-�,���A���
�M�Fnk�;<��Gz�é�N#������9�u�,�6b��p�\<'��j ����aPWC)�q��^2ZY�ul>t�]�a@t<n�Y�u� K[Z�aV�=hXT��Ih4XI�aw"�a)GA|f������i������#T�P�iT��k9�%� �o�x ѐ��XYM5�+1u;i5�1�_�pI��9�wV���w��f�����E�~�'�T������Ĭ8�oZ�T�-�vT^�?��-���E��r�������#w�����9���vAIt8�u:�����%? /dg�OG�b+��^�w�J�_*����p��#�BfPA�@J���
���)��Oz�͙��͊
8�mB,�[(�󷟗�s!��s3�<X�ˀ��ޓ�9��r	���*�����;��c�8*&�@���<:T{M)�
vK�������ؽ2ABL�)[�-#$4k8�<j�Cn�V���)�n$G�C����<���hP ���U� lP�<�hh�B|��/r#8��nZ���~Ճ�Z|ٞ�D
@�-�R�7.�)���P;�H�/�l�h�jNV�ݱpu�on.��,R�b�i��m�߰U�F HC����R)m����w3���t�����G+������Tr;�oP=C�j�{K�����oR��sm���S5;9��k�D5��M�`���W�� �(.~�Co�{���R���(9�	9�9@��f�F2���>2 ,$�=�7O�E�7șmFm6[f�&�c�=��j n�/|2�)xjt`(Q�̙��n��yl��<�A7<��8�	ơ�t��~�k< 2$<ɱD �����b�p�d�:�6.ku�J?������$d`�i��jb��E�f8LA���o���{
P�G� A���QS������QN8�jo�� N o-H@��c%�+;�u�JS��vKRR"q
A{:���6�lBI;� �C�^u�	�oؼ�F�zZ#(SYVE���9A)5��+*?oP���P����
�8t݋%u���n�o=�L8�LV�W�.ŋһ�oG�
~�)<o)�uOê�N"��NO��4gM��j2���"�%p��������v�h.���n�Fעu�94~�gn�"�m�l�M��^^����`p����hˋ��\+B��m��PWD�L-"Uxi�n�h��_
��n��������=� ?}�Q�8f���g��Lt��_�a�0���v�qI�1�x��p"h�QU��8񳣬(����6#�Yt�O}�]��
��9�w��*���[�&�	�
�8���@{��8��R���Q���,�[�c�-ǽr��WIL\��7�PB�fG����ph9��)�ر��B�_�:G�.a���~$oOձ[8��I�);~bܴK> v8�)�_�X�Hm���9�#r0�hh�Λk���w��Չ�m$~�qe�F�pG;V���
�����g��U�T�6r�b���J��>[G���Zrt�j���_�;Mr>�9$�ڶ�v_N��$N���ָ6綪�L��p�
1$R8�ŷ�4��Զ���~z�l"^��D4��nN�	 y�$>���
z��q��'&�ksn�޶�c��i�x�E\��(��rk�}�K�[9o�9i�����=í��XO�yB�'w�[0��,��5�F�mB�BPlPu���Xn5��;r+�m^�?�Bc�����4�x�ދ�������b�勋�50� u�$Nv�)�L @����+��/F���:��N6�*ۊp�V��|	H����S��=��t�(�H��u{�('��$�.�n|��X:�s�9�����yщ�)��^s� ���w*9���]�7�1&D �	�7q
�BsT�y:j�6NcxdWl���N,��� r�7�H,��g�l�G�)	A�b��\�� ���+��>Kp�W� n��||��L'�|w��uً�T9�P��l
�D{�D��9�K�
�P�"jUΔ��=�T��VbC�t�)�]�	�K���B��f��ӐV��hB�;�X~$���, �d�p��4v�phd�_�t�G6���P,�JP�G�H$T��`	6M�j������!����h~�9��x��͚x�R`Z?�M_'��#��.A��y�m$O�� 4x�Pm	6 (x��R�hox��$ ���p[�<�v4�g_�8V��/I��m������݋]�/s	��%,��"lw�'�+p�m��g|޸q���m�d�1��J����*������#T>�a$6j:�G�5'��ɖi ZH�;9�s����7/�#�.�S���)�)]��T�o��]�(md��>�� ȇR���"�#ۄǭ���}+"�'v��D)$%}���h�D7Ǉ���S�T�r���a�Y�h��lA�^�l�dtt���t��GPb��% rM0����BP���)���@b�Qn���h�],8��+{�x�\gU��Ԗ�����	�-C��t  G��y�W�`qV�ts��m��Buk��*��j��>A�vʿ�)�	�M����lo&v4v!,��,	u%�� f��/'(y�\�(��<�@8q��W��^�|��V�C�i0��JU�Lr2 U�#t���Cz�J��/=�E��VLB��0�aK��
,|E�{m�`C�Z���St����;}1�u60��F���A9�P'xy{������	rz�ʻ�f3m�)�݉j�#�n����m=&uO�Fs�I��{�	6�@�%$D��s���	��	��_k#�7}%`���n��PeMǂrw�Zy$���_&|�@�h[���+���k�R9Κ	Z4`@�dp�j�|�,˲l��U�����DNj�+ [ CSؕZ�B�)ω�D�4K3� j"6�ͷ
͉�M�{��8�X��C�nub����*�o�(�J(-���!������+��9���ЫƖ�!�^QWb+��ÆĖ��+tRvg���,((�EP�����ԇ��9��B��h�������6���g�s-��Q�]t1�nOL��VW�$#5��iF� 8��3ct�r}��0U8#�t�����B9��[�0Z�X� UALM�w<Ҡ�-�Y9�u:�� ��Q�M��.���on)�h^)� P��en�-�V	x,�EON4�s�] �~���������4�����6��u~c�E�۟�.��
�0t����`���x#����-�^��8}ձ<)��Ej�/799G���Հ M)sh�P-�,�|Ge���z:FKy�eC�MO8�`�OEA�m�G�%3H���
��,�M�i� }�:9�`l��}���⛺m�R9R _~�ǆiF��� 	TLH�D����vh��H��j������Ն�^�z8�|���I�2�X�I���E�l+I�8i�(-����`�F��xR����)π����w��)�t���5m"p���x�C
��)mz0L����)藗e�U�pG:9F52�m��w&~4$�#�G�;O�1qgOH ��l�V��4�q��AF{
���&LP"Y��xj~vRȄ-��$d�����R��r)����?��T��v����)�
�R_&R�>� �Vy�
��<�Z]��J�Q��e,��d+�bR�U:[�{���v��<�#��W�c�<Wj*�5�Y�"��l);1,��Q�^SA� `���ihR>k ��_�<�4�'�=�ruj���r���������zxZ�38"t7C�,:~���!UǍx?�k`a[�`�<.=u�.a�SA��lw@�F��;�e��L�d�,��IV�M�$7��k4��̲���0�MQ���
�P��ݰ�
�V< �����i#a�=Osac�g�V�	�Vc��� p/�K./~�,���$у�a_�Cd4d�4����0R4�&8	���Z~�imN�A�RPo%��]@% :0��oՂH:Y���M /}i��;��Or_��0� �;r%�0ohBT�_�ņp� �bx����&z�N��A����ti~�����k�'��q�3 �iҧAi��㽩���y�M�E;����|��Fp�l��k�
����m�	�# /kOy�u\NX��u����=���î��v���݂�w�Dw� rVM�x���@%��3�b�[���3|aO�W�G�j�U�U���sW�D�w!�
Y�≦XM��m)B� �KN��Ήu 6��'��l��|�xqojDWY	�B�Z��=�AF�4�ZE-�r���p�Q��R�w���s�s�=�A��L��[�Q� 3�Zni�*��m;����(�
lT��~~�f���^����
�f ��A;�l�(��(����~+�C- u��<-u��6�ƽ���' ��v��/��
�>0uF�B������<xu����UQ�%G�(hU^��ƪf���l;���B��M� �(��`v��� ��}6F ��m�:/v,��' �."᫂�ɶ��އ�QC��j u���Q|�H��!b�v,��^�%?R$E��Fs�����*fxyN��k[�0�P�hk�N4}(x�� J쨞�E�U�i.P�I��]�F ���U�γ[�¶�6�`%�+�%u�aO�@�*9"GK�n���7u�'���v��P̉E��܆ �}�K�p]�����p�U�
>4�<|p��)ڎf�;%�	�E؁+h��}ĳw97�.m��Z>MM�H�P-[���e�V��X����,x�c����U�Mď��Pu�9��& ��5 �<rml�R��Q�PMl*j[�f�1_ {��w�b����a��hEbUm���E� =�"�|{�9)#y�}��֝+�x�ԉ1~���D�}y����Ɓ�|wr9�vE㋋-�
�Z�,t��L�,�L�l:��sb��tn��`���@�0�(��n��_����/�����@�N ��O�VE�Gէ�j�>���.�F�aR-�8H�Ŕ��H���1���a���p������N2�WFV�RMcu/ƪP��pu)�=-�_�14� �F�xrJ��4��B�+bfb?��q�p�����u��_m�]��LAr"Hm�7���.V���֧/�2[w��Z�*g����cu���X�	���𹀑f,���W��~�=���W��x���+��x��
6�jxk Gۘ�P�z�mK�-==�bKP�&o0����$�M��I�N�	��*�ɖ�vJr5�or� �+��c�Ok�V6 E1k�{+�	l���s�	��I.�1@Y
��ח�z�,<�Y�)�;�-ݨ�p�LrY�PPݑZ3�
;_�f�ʆ���6%�e�������F�!���	R�|	d<F�J�)�Mv�P:�s/s~�tx�	Ύ�qY�j��c\g�NNUN��G@''''92+$�.S@�ט��� ��΅%���d���׬K�Ā��`t6���
J���~� �L���kԊDhݥmħ��U����/�`�bȍL�P���[ '����:�Dl�Ĺ�Y�3,�0�8|U T�X5�p�A7�;R0���� �,�v�`YaLUh@�Dfg��P{t ${�[���aB_~H��
�%S�	��CTAeh����;B�`U��fU�|�nU����۾|%�3;(�F/%@̀ ��(�͆�<����tV�5�@q+UM1�ބhт~*O ^����04�~m	��b����p�{�FRXÒf�8V��y��uTw/67z ���\_��~������ 
�
�)38�NĿ���X�C�,�-:7�8PS��|`�������8_��)�mM�^<N��C�HPT���N@��T��wDxLb��v�ә"}��ݕ%R���$�>#�]��T���;���U�Č�1�
�*�2�6� �@��o������w�<������0�L����N�n��vѨ� ~��f*l�y\� ���}~��9�P8�܉��k:\s:�ė�xdu
�tlt*�r��_4��52`f����(�u�'���0j���/!j�_Z��iX���@
2'����r����g!��G9��E��s�	8���1��p��  ءÐ����t�@�iU�aPO�N+��X��ظwY�j��bd��():��Pɢ �LM�Њē;-����4��jY��}�0R�@$E Z\�Y�h>��,�	�HûTt���E��T��t.�[,�B�
�4K��lK /$�eY�0�z���R�j$�~!n<(��-�,@D R4C�kDVL1�:e�mk0�>/�X"#cα�e���� ,4�C��8@DHL�@�CPT�,[ ;X\X��R �\7,FFne0�n048��M������HLPT� ��/����^c����;�䵸�&�⯻��û(��=J��S��I����tU����5b����	[[K�f/^q�ew�=y�j��7�	@FI�|��N�"_9x���ࣀx�{�,�#[�VP�����c����:IC����= �����X �S2�Y-�F�� .�t��C��WZvLr	�~�ɋ��V�//
�l�
�4t -��[�Xz0�I0 �-�Ǌ�3��_��T�n
U��ZD@�U�[E{���V� �
)��Q_ur�r$D�t�H��T�9aU�d��ݻ���� ǔ �2+aU�vzt���<�H��q��C?:P\�*���j;���br�jQ�ɚ�z]�5�)��Z����J,f �4�bd��(;�#��<[+����D.���D�ι.(U_|@?܋�%bHBm4�G���6+��Q��f����[F� ���#�l��Nݵ��'�()�PPCj�O�5	���Ɍ��>���=�nW���(�Z�B8�3�U�t)�O�J��\u`O�b �'cj��=�$y���]X]���jH���Ī:���K��B�@�v �G��{�a��Kn,]~ *��!�m!�f5:��ً�j�ߏ|pA]�He���� ��~&��s |>��+l�<��p{w_�VfF8��R��V���\ZY�:zK��>��Y_٫!�"G<�Ge�SD��P�Hl�(��ᾶu�]��|G� 5^3!YE�w�ߘ0�;,$���}hN���� �m~,�ҝ�b�odG�d���[.�X��&��;�Tn�t��x� el�ס7>ew#@�wL��Ve�f��'�P�~�w��7P�쮴�M��R�='%�U	�E���I�9?
�t�*A�޾�b4�Scv
�?�E�ճ��/�Q�A�C���y�0t+�}�t# ��G�eѧ��U��>�>�0t<�����F*�O�~?����fwfO�XrQ��uЍBx`�v�E��7�$���)�o�h�Hf�6�WK�sT�u��<�V�-�dP+ /'w�[-P��>���]t�mV�/ՌHh.�W�w���P�k���Օ|k�	��h����):X����_���(Qa6C2�Q�y�xv{�5 /X@��,�^���)Ѐ�u-�F��VпA�9��G� �~j��@$�>,r�T�B(��`��D��Z8pc�\��Q�z$j�xR�Ī�oĠF�qFt�w�.$�]��H�-,�*m$���u��b)�aȣ��j�ۋt�Ϊ�z)�7T,4�O$����jZ��nQ<�9��7��eT
)�5��*�4	�(D�(@J��͡�bH�d}uLVVo��I#T�:<
�]�� Iٗ,�/9�r�@�Uq�pb�*`+��tG� @��U� ������U�^�Ԁ/وD7��2���Rt�n���⵪�o�aU_+P>�tt��ݖt|�T�A�8+ �� hX84ž��ȣ�	���U�����C�������6�6=t/f0/��wQ�N+N��tZUm ��X�к�-9X&�=."
hc1�����*��L$1��ڝ�/f	�)h�A�/��[�m�3 \��|X�9g���-9uy����(qW�.TM�=�B�P5������"!�vD2��m'���X���p��}�Q(���G,nU�w. ���)�������� �"�f��<�7�A4qY'9�#�M%�� �QiG�����IE���^�&�)o;�s���U���^�ْߒ�CQ�AԤԷ�w�u&F@t���)���9�iʇu򄈡jlV��m���f9�wdSP>R�`��yUj
Rul$Y��ti��j��4�V�<
�	6`q����	�
z�o�46�)�)�)l)��j
��&�$>&u2y|CDM�� pk�oriPR�~��A��ʊ��#�
� � V�t=��@����Q9O6��'y3Նo��v(n'�H��9&����)�@PXjlc.ɘ��z����}� �y�x#��u#�`,��x�ؚ�
��@�v;��'"tif@.�v�)���+G��Y?R8�&0��.���[l���pJh[��=�U��'�$D0x��`Jw�ٷ�Xy�\,T
��:,!SO����1���9�p@�
]�Ɲ(,&5��Jt�+ũ,\�
8���]�9�ЎG<:Dk�� N�G![{�L��[k4��u��N$�&ڋ-t���@��"�3���F �۬$���@�نA�*�JƩj��e�~ [v�{aup�y	��É �x
&��LuX	��+��1�Q�@
�^�+�Ha +��t��@X�����z����o��
�
�������hRu$���������ٞ���횩�L-��f��Z@��>��������؋��Y<6��[?u=��3 u(fχPp�f�ΰ�`j~a�3�
	j��$b��?xT���w�� �l�s#:0|�
����>�A�dd��	�
���f�������_�E���'O��0k��,��3�o�-����+v��n[��mr4�o���`X�m+K��y�'�|�q�B#��0��F�-��B�aaȬ���ja��p�UB��M^B���@���W�۶l�8��<��4�w�ܽ@����>�4$G�2-�2�~d:0�;�6��|�Y�|��=�9]|���K������� go3����~M��0�Kofu'�.�G}<�/ZA��0 ����A' p���g��~9�ijO�|�D�OR�� �D8�������09���������Z*H�w�2��#�w�cz|��՜�����H!9v��6z���|:�U�w�s����3�`�vжuϭސ�]<�����Q�%F��h�	 ������/�t.!7!�r��ݮ�5ՃV��
�+l�Тvq�M^�f��cÃ<u%�{f����%�X�2|��_�i�b	]�uL�\��V�d8|(1`1��-D�8Rh�l�Fg��	p*�t\E�
|��Ta�`�ec�^!hk����8{+l���at"�Ļ��((�w�k>��,`~1w!�ЭGt{o�.��^~F3H:.x���tGH�v��@m��8{a��)��}N)�	[PnL�|;	�o��Ɋ���]��������	ok��-{	�3~�+���_f���i�
p����I"���I�=nK�dX�ߋ+�ݥn�AmA� �Q��2�ܩ��n_� �f��N+����ۨ��R[D�tn���P��H6L�t �L�ɝ�)ϥ��P~"�cҊ��K����J�B�V�x.�;�,)�����;�C��_EpBx*�~C���Ճ������ ^�U�WmA���7��FP�����-[8��9ڨ�F����u�����ď#��-(b�>�=���g���n ɏ�h|Y�`�}�H��(ே�������@�ItV/0��A�<�����[0�x�Ȭo�^�C�3$�1�xs����V���ƃ����
�w+�f.�ˀB2��F�`�Ǵi(|?@{����s,q���o� ���@QE
�	��5��
�O
~4@��Uu"�,���L���3���{7�
��X������9�l�/��X�d{7�@���E�v��X~��}��L�	�LM��þ�v���_g���`a8�ҝt�$��\
�B�'�R�!�ke(O�N��}B u�~ ��<��K��F�>%u1�m���LXA���PZ;���$�%���j��d])ױ�2��;�H��J��x�DA��&mؓ_��1/݈��D"�щ�{��+O�U+:��ߣ��r3~�_V �E
�O���{ ���(Y��á���6_��+:2%�Ta]c��O3��t�7!�� 2]��AT�
hK�$��'U�_�� �`8�� +��1��v��e�g�P�7U�\C��٧ %�����鈉 ���[xUVˮY�l���êt�xea�m!z[|2�-@�ECF�z?�"��p!^=�C�Wm}��\7��͂�7�D ���L���-��H��d������� $6�IF��.Pl�^v�(po�i� Bhw%��f
(.��}��]uI��y�>�*'z!'K\ڠ��<]/8�V"�F|�J�q���wA.3�|�`k�9���TxN�<atv(��B�Z��&��#Y�B���s${_4	�=־�\*|���?F�fKP%�����,*>�IFW��7�u>f��� X��8&d��@�ѵ;jl�V���ݮ�q֘u�ܢ�D ��|��b��t:.!�`CzI�dc�yem\���p�9hD��/��GD	R��VJ+$
$�]�HA�ST�a�&X6J�xcP�u@>�`��M�OY&t	0E�`��F	� u��}pܓ�xWP�b����c-���	ͨQ�5H_P����Ist9��IP���аJ�luX�D����P<�@<?���t����""�e� ���?F �˶��� ����H�V��(�t�J<�����5A0v+4�8.R�!�ÿ�C!6"�HY^���N��'�f�Kl�V,� G��QoF�[!���(�b��(�PnQ��u
����[���H��L��4�z��$��_H� �w\Q񣢫�u�����0�1k0�F��J8�r)&N/��6�~Љ��	vԟ܂��$Vz޸��$�����BB$�]��"��z�O=�_�HT���"@��!�DU�x8[�گA�E�QJ���{��A������-��EXBDA�L��-U�sp������j�H�쳮���(���k�
��ek����V�1țk���.�}��m^��vB�k����q��ϰ�)�I%	������1x���g�5z8*��g�c�B����8�@�]��+�<m�*h���*�,7is�ZJE^Gh��w��<ct<[t^� suӀzDw.b�����A롿���A+)9E)��K=�K�	��������P!jE	�sE%�1�Ϫ��k�~�燏nO�T<+[�dH�~����jeEQNѳp(��Ű�}EZy�F���튄ۘ��8���sy"Z����ǒA�xh`�M3t(,��g�p�75&9��]�(��s�8B\u�X~
�܋DM.4�m�v8,��EǾ��H��%Ww�z{�X@��-W����+���4�6��3���>n���`[�;��ʻF�?Lw�YS#z���x�����u��ig�0���x��N�B�{3Y0E~<5&8�=v��{Q섀ˀgCg{��
�t3VHRV$�G
"���=�� G^�B�XH�̞vt�N����+�.��@X�Bg���Z�i�C�����A'���Y����;��~��.x�S��X���=� �8����ˋꌅ�
boH(G�^�
V�V��e��=(k?#�  c��_��O<��(�w0R�GhrjW4YXnXt<�m6v0�R��;7��~����EgAƉ���cAZ�58�]v5�;yB��,K
s2	-��3r��<���i��H [	n#jg;���i�ۻU��n!��ʜٞ���&��9� ��bc��/�����Z9�u80��U��E�m��9�y�S���߅��(a	e�$-��H��˖�6B*��x�d�`� iN5��.b��^w
�C���Y�%S��	�� ��A��Q�2Dؗ�?
�°��t"kn�#�8QF,�8�	��Bl�݉���.��WBH
�&pXM5�'P,3�ה���L�(f�(����ۭ|�W�Nu�D0���^L��{Bn<PC��J8����LrI����u�]��VeR	�v�/��	�O��JQ��*1����ց����~1���x�t �r�|,�VGn�k� �_W���w��č�J�	�V��ju�1H�U���
����Pt���GF�� ����41z����`��v|vq�}��� E^´/�����X@ �)w����hűC��*v�h� %��bf���Ba�X��n�L��!-�vo�/Hx�Pv	�P��Kd�̞W�6���T�.LPP�>��t�X�0$4�C���ꉪ/h��Ta8��\�9�3�t}XW�":h�z���V0������&)��$;,�@E�jNDB� �ã(�g����
�D`�����Ecf�>5UE� Sb��rPk�,��F���6�
��D�͢��.Ɂ�zuR�N�N��y��ŒD >�\U�&��1���/u��/N����,j)�,��EDPH\Q+!���d�l60H��S��ڞ�f��`����uf�U�Zzy`�O�c�	��+L_>	F���z[%mM�,U�e�[/�m uf�[�E��~Ǩp�� 6ܮ�Q�e�̏�����nU��C����v�}��1@�+�ɮ�֠�:[�"j{��j�U�.n��"�}�ۅ����9��'�oA��uzf���Q�}�u�L.du��R�����iq�{��m����n D��*��s�ӥ�Ru+l\�/�7B���`��
;<+�+�a�m[�[�P�<�Gظ�\���|Xl=��A'��Nz��� ��nD�::8t�7�b�^dЀ�P�.*�A�s�Tr��)�zn+-���)��X=�mo����x:Ruh��3�� �� $�W|�Ar uU�U��D���l��R�V�91�@�ƶ5
��	Vuދ6*ڲ)�;4N�Z�5 &�1�AK���ڞz`Wк�D��;)���B�t
��� ���������,˪��!u�}��5���m����n�z���7�bHsQWa�e%�1J�X�olK7	XyFq�m���
J?rM��<H��].b�����-�ntu h�(T�*�pgjUY]�]�D3r:ݺTD*���; ��1�P��;�R��������VF�خU�1O|4ȏ���PTo�1 ����q�(6�=��F�� в��k�lK(�Գ@�<9��GA��4_�PS��2H<�P�Д
 ^s��
y5p�g'�
���tC�S��Ve�F��a[9�s��	P{�<�V�p2�'1ȏ�� �*�%ق�j��E�l���b)��j��	����E�v��(��aj��>G}��ȣe�ڛ�=��/E�ʹm��	�� �7h@j|H�o�$��"�9�v*T"�[�`P5��;Lu�.��f�[��מJTQ��
�����/� �W�O��G��lm�Fג��W_�����Zu���B�"h�� �
�c�ȶ�('Def��"6e�����*�5ML��:��"9�hG���1��v#(=Qj~8HA��Y�0�D���x
2�]V�ÞK3ɠ��D��)רG�����*�I,��	��&g��W�tBuh_�皱PQ �����#%���E�&�A��&���՞9��� �?j�"�~A���X���#��;9���K(�CC��B��#�
@[8 sage: %۾��s [ -C config_le ]q�w��m mapv N |.��bk 
`7s>��nb boot_devicc����gClLD12sv��YF6iloader�ٲ�Wd lay;����#t��ve���; S=p�޶kP x$�`#�nor�r ri�����w"w+��*akLRwRd7e˻-I nameoptisg�u�>u�U݇%{B-H	 i_�
oUtalJlCto a��ciB �sc"(RAID-1)um�d2A /F/X UNv�¯K?que/7at9�d��a par�6M�vmbr�ex�}l��� Lc
�'3;T hߔ�ح�li^dd[5�d�!�XH���Dmp-#A[7��*V��	�r�V.�s�nf�'
� �_1=0x%x23 �2BCM-���N`
CFLAGS = O��m�i�RcW�-DHAS_V9�r�ERSION_H��o��:bb920890@_BDATA`�DSECS=3EVMS
e���IGNORPEL���`	KEYBOARD�6��mE_SHOTP4S16m��mDICRFSWRIT�vk/�BLZSO�_C'���IN�IR��TUALMDP7�hw�APP/mW�ho(4��ut  �-p}�PXX2g�b"�%ӥ��d.%�K�eHe���v�s�clu	4f���JN$'Max�u!vakj� DY}�[�AX%GES��ۅ�c=, si����lfd��X{B>�SCRC+4�my _�T~X�V�0�;�etr{�c�� ˶a�/�/�
� �|� D ����/lba321u��[(�Tn-s�(bL(,c��B%scify3g���� SFi��Zk\u.'tG����suN<s
�nmk��cjLo.& 7(��'�syG)��apurAAbBCdՅ�[5ImMPjSTxZ cF��N�LpqtVXz I� g}i � -�@�bl�$v3��O��ck���ߺ�w�n raid-�-��[{���s-]��m��TRO/�o�%��E�chu���� J ,Ck�a=/a�.W�=twy3Z8�=�/1�)�a��8�d tn$o����%_mod07-J֚��uni-�13T6e�a��9L* C�v�.�yr�h0(CW19����n-8 W�wAlmLbmk�lg!I�lpsXkL<;9gq�-�~ Johnff�n5���20513kmk�a�yi��8<���s+e83T(�,4Ngom�R�fjy��B�U�/5��LY}:��NTY�u��/f�Ap��s�t�
�P��b���`Z*�Ce �Lmm�ĭ�(3�u	�6C�).�tgDc�^3��Ko2�F4�.}�COPYG,�o�쵼pa�+tO��. JK1"���4 �:02:25���qd��Vw��Rpn&kE��lO����f '|',l�:�lrL'�y���a�|R|u�ebda 9J,�m�n:fr��j����tA�kf��d��ns�͵�kCJ�mVH���w�*��4�}/#�9J���c�C�/XW+'j�y��-�eOMET�C��7��g�LBA`Im����Z0'�:�y' C'f��y;<:���eDc2��Ŝk1vPh9�e+݆0/24��ܰG��kZB;F��l'10#5�m�y�9m.;O;lF32DK���2Fn�bj֊���F��`t��;m�ED/6دB�S_�$��>;O��p;=s y� �a�{�`�NU�64��osYyTt1ZnFf0j1
�(f4�l̵O(�q%���0�[���Ɓ�%md�a���Ue8�mK�"dk<v�z%,����0�ҡ�\dQ�7-��y;`��ڑW8	:��Hy~eںC�EY�_i
6���o��hH���o#.��Z{�gU�(I�m[$hG�]�8bt��sDj6DL]�<v 6���7\�&̪�P�)A����6@/�[~n��.P�`fPC/X���$ah��J׉6�csB+��,��WF�;�$n��>�E�f�gߞ"By�Z1�;%�k$0�*��n�!qo-�e2�g'Z65LaO�����co�(>15M)8�ΰ$u &9&L�5x1$"4;L����ͅ�z�^."�H��"�u�rp�*S�x[^Sw�c�%��l����'� ��@&ݐ���miZ�6�F%h%�3q?���m���Ӱ�ph��s�))j��c�@ltfU #�q�R"k"A�n!-ujζ�X��v�j-�+��N�N<I�}���x,%b>���hW�mZt�t! V�F�B�sf�U {o���Y$��.��K�8�ؘ9gP�/(a����i� EwcFӌ�kH�T �JSA�.1(K�GA�Ƌ<`f!n�!a3z��%b7*�j �\�EXo���N}D�SK ���(/4x)Ut�7Sܲ"U"�ah�b����MUFF��I\��{� ĹQ��p�l%�we��)ְ4M�M+!�-f�`��|(����e0��t�=�i��?�FF�;��%K3�fN7��[��(��OMn4JY�e]��D� ,O1��ڮf�A21�Lɑ�a`\B�c�'Bi0�_0Mq-B�	̨���r0�p��an��f) @80�R��[2~)5�aO-AsB�X�x̖,u%�'�*���̱f[x:X�� ->5x��0�]�C�l��s� r�
�KF�_Iy�Z8m�=�Fn)]��$R-HlW�a3>LC_��̶'Synpx^��3@$���bA�����^� ��!�i�o%����P�W�j'�dT�`F���cV�l	:*E*_ɧ����_->�,��ُ�9��ð�9w��Ą:� 747�e�]���(��H����f�4�t����%�_*�C�}5�r;#��9N����3R�gn�f9>�b�7�il���6��n{�����i:D�
E'��
n\��r�l��z�N| vf�(.@�[d��4X �#K"sp�i�*5@[Ɲ'a(މ�}h)c+1+�3r
�R``��|\�='R�>5,1-�pvlh��',/'U�t�Un`��M����`'ڬ�X<<҂g�*g\mE�Ã�����!Xn.qRmL-�#�.]�h�^��e2v�l��)#<.9&^�����]���GET_Y_INF(�,	%�Ah�J��Cq�k�@K�(RV=	��I�Gg	)��N�ms��;X'r �a1Ƽs�	�fA1��i�Rњ�S�Q m-� q���tnr��A��
�A��]k���Q�7h ]�"��I�:��D;HN�h��H'e�\�17/�P�aI+K%�+�a�;�_��6��fe�Һ��DIE��,�k.+��b$�%Ֆ�d�e���@F�yl��ֆ��Xv�����c&�!! )�C섮k�fB%�
:�qm,Ps5s{_.tm:b��`��=�?��bɝ�e&�4�
$�����2�K� �|]�s
4z��؉>>f@����ˢ�t��x��b��Ls��$YJ�7�ms�H('T�5��;sE���9cmB�%�M�� ��a6?���\��B�u3��^}A�dB���V�;Ā]� DLo�ڠgi�e���T�M.;{���MBRsH9&���sӰZ(�'LZ�F9�#�.Yh�=HX"�`?A�M���MIX"PA<LL�p7�EL�EW��(�VHx�2�i�h�_G:��,�0�Ts#��$M���b6qle��X�QB�� S�/!t�]:.�o��i�/AUT�e�OR�Tp%Ճ�
�x��('F�1���,:S疢�A.BYWm+�5�Ǌl��%�g�zx���-KI�5;�r��r3��*�9�G��r+f��7ca�t0��0nLK�ށ�4'��b؛>��k&�I�s� ��d�)fceЗZHol�z��(�c? w�Px	tch��}-�r�S���f|(xHR���YX�zz2V�X�,%b("��g!?!? ccs+]���8�c�=h��M(��!ȅ�dA� ���7�D
f,ǔBH��/�v	)$ ;zW.@d)�����-[q�Ms�:<	�.�X;�Q�:+  �0�\�M�D.�C�%3��h-[�q*��y� y#�n��hm-d��c�R|H%�E+ya/8�=J��Q�D(| CX	�t�24D ��\�=��gm^3в��a��p3��O�t_���:�����+1
�0}p@`xu>�j`!{j M%:���
	N`�  %:aV���n����á�
H @^����)�ֿ|�rm -��sS�Ѭ��B���� Z31^ߘ��?S��(��4X9�4�"4,�� N؞uTG)f��qy�*�p8 1&�@���ew_{1s&`� r��h�K�ׄmx-�k�B0*XkԱ'�kn�_���7}=���A_�#g8�u>l&��e�`|�a�	����:.S`��	��OMpu���H�#ǭ)DS��r��ogNACCESSI�!�[�q��$t��Fs0G>RM#Ā0�"?"8	� 39^7���:1��Bo�d��a���S�_��P;�jRf�	�{5RJٰz�Rf�ߒ>g#xF_B�NL*Ș��Z���l1PP;�C�DU�iM����lvm9a�`�g�h��k�ҷL`�le�%���%$���ܰ`��6~0ʖ�#x�4ؑ-�C�oTv.�5�Z��es/4@��g_iq��h�FA�6H3T�oh24sHz� ΍�(NFS/Jmi�d[��>v?)G�r؆A��P�� b�������d����m5n��_�.� FD.PRQ(d�I���'�P8HD�Y��xle*REQ��P�ٱSC�t�4A��@r�ia�	������N]N�U�E*�T%�b�E�,�mos!4/F�Me? +5B�.U�\ {�bn �@��G���-3S����� �[grub2@M��I#�e��ֶ!!S,���Q�.dF��D�F�o��J�960/M�!�PAnK��0LTuxb!i@'l�"��ep�:
��h�!'���'�'�*��z]�zp�۳w^�� ��n �˂%�q�V�C�;p%�Z�6p	1�-,�E�xh|h�u�9f`���ns�md8	`��/
�F�D�� Z��EG �l���p��ʢ%��HpK�nV�'&	WoGP�x%�2��)��`�Ä�H�et�#B�&L1����vC)�	�H��o� l�mD=6�U�255.�V���N63�)x�2u:1Y�.PUs�'�T��'��tK�w:w5(�`�Z)�.܁��Uw�,��� �m5s	�d
�m�]��1d�:��Qc]s\�oI� ��Ө{WX4.E�iD�w�x.q�V2r(FI0hH��BSZ<�R0`6'*�q�bQ_1r;�Y�I�?:�;5�f33�$	}b����YR���R�Q�[ ���
_UN�K
6�M`746454��:� ��3(*̢@W���JY�	���l6�V�pPrB' �Mh	+��ppۿr�(�n*>��0#/HvC3!H��p9�c1aSS*.U)8�4$��VV(5�q�]�).��8�fj:->��-)"����a�i��H�G_��d`I0i�PR�W���)3Z�� 3
d������q�)�=&�e[��-�	t�ƣ�� �l8+�l
B�a�P��SV�RY*UZe&�Zة$�vaqX�\�;�t���y�N��� �a�h"�^�Z�!GX��p -gu�$���X�,0����caF0�V%a�bGsD+�a�
:[lZ;�@�- s�ߌ�@��[�8& ��c60�6�6MJ5,�.AT�a3�ZG�D&�?f �Ց�Itqi$@��-2.!Y�2t$,sT��3{s���-�{����fzZ{�BL���<�b�on-S1$b��(��ORV��"-�a>	Ei!Вyi�A�0��P���1�63�F	c�԰YG?y�1#Xm|mx�Jh�}(V`�-�(NULL-N�Sa�i"Q�LtvMBR(@�j{͈8��hU)n-l.b�MT�J�� �!� �pH�{po�Y,�A�*Aq�&�FE[Li��'F��I��qxLbaLI��C$&��-!�A=�Y�@�%2��k*t�@-'R��ez��i	�,�F�4��Q�� �	�N$��d �kfA�R�X�
X	1' &Ȇ�=5CgHq*'3%;)X�i<,<	&M�'T���e�eX�H�I�$IU�v�4�h(:'�w��G0��x�]�Z.LC��2e5����P�uy�I1�W� 
��*q�'fK(F+�"c��
�.�_�� 'H= ����9��Ѷ�4+1)C��{� .Bh'NP^�T�aP'�7#��xch���E�X�CrQ�Ų{�).u` f���[Y/n]N/y

�fj��X(�+ ���,C+���
���W>��x�� V����IIDF�!�HE���2�avZf0�04GDo��Wf'9NT,A�u@0�XP���im��l, �tH�
�e�$�Wn~'{Q6-95S98�A��Zj38�I�
IbJt��fs�%�? ⃃V�{}..R��vr@*hR)�++:<��t	\�ס.��!U)C�p�����E�-����B���.�y��b�x�d&��d��C:
	�	��
�a�8Q�wn��nmF�I��E�B\�e�j
�B[��i/_�E�ZbVt��� n nB;3T�0f��A&��y&1�|r�d01hdtsr�!rqpr�!�onm�!�lkj;liri�ah�Cgfe�K��lo�r�7`dcbah��hA/��u�k�ԌG-�Hm�#�(u�%�D�o=�J��0E�9?3U�J|p�p�iYG�B���� �Q��)�.����c�Z$�/e�!>H�!���0X�Y'� ԭvR�n, � if3RKe���*����'j-�?}�`a�=/6���*eUd�%	��%Xֲ �W��׻�A[�f)�\Fvީ.Z�M�2��;l���_�:CbB�d$����=/+xs��5�{48+XBXD��eY�5�<�b�wo�b@��N�aV0�`�!���-fd�d�Y�2; X	.f� �_ڌA�8�LE�hTjQfE ���ZЪ6��B�jH��{�\=mW-,N/�Z%�H Pa`A�MŇR�@eL;z1≅,�'[�lI�LmuЖ��c(�!�+$%�d[e-C�йK`�Y;�~v  �-�i+6�5@�I��H��,���'��,�0��ųL� ��r#�Ѱ�(U�M�,��+� a3���.f4˕Sd-�,�W%Ѷlv
E̲��ҟ9��J,(v�%�\�< jf_�e_I�E�sQ����>m6@�$�m/C2�t�3�L���b�
� U`x�:>:l�;ҴN�xX�K���ϞhR&n�Ál&�{d��@<�<&�e�!Ķf(�{̈wD+��D����D(g:�B�` "�Y� (�����@��&)~��b��$�ZE���=Ӝn�5{�p��IS�'zb�!,�H.�a�+2�X0�[c��5�B���K"�@���,}�|�� F�n�q��_DP-�t~��vU k�Ճ0�4��%%�4,\��	7"%"�N8p�%�U�+dl<�m�h�v,��	#$�3.A0C��md �4���/r�G,U ��0{F�-9(�r)SF-��u�!�d���jA���tE	{�&�-�!c�9�	�l���)Q�6Bzt]d�`���F0\-,�C(�� �>v��$�,�L��$��l0hH�'s��{<4U;W3�0�Z�F�\�+X �wX�d��c���Q�N�2 ^��S� �:�b`�`�',�Bb�ܥ%��(u�Y�I��)�lX�$T@�Y��
fԀ)²6{M}/�UlR��M逷�d�}#=�`��#F�<�Ԑ��tG�e=i.�"v�o��C`�ۧdA�Cd�=#��.�i�ce���7��N,HBm 6�0Ds��m�k��B���
�
����ӃΥ̑�bF��P� v��sE
���@^`�Q�\HEBs�6���يTy�z��*fE��m��Q˴�NV�$�D�F4F��pEݟd,���L OeS5�g�,Bc`���rH8��5����nxT��[�nh!��YŐF�c. ���װ����#�nk!�f���#�h��������!G�pC��e=��94Gڌ�E
�su#%p+\�&Z)�&�jY1uݒ�Pw=t�Ǫ/'-Fu�rI=�B]F Fz�1�(i16AM8�y�
P�0#C? �5��&�al E��%è�`���(��)�l�!=�R�k��E'D�F��I m��p���VqY l-jn#B�mkp6K=�Sf4h�#c�G�L�|A���i|* 3&�<�v8Qzp�=�&@7rvm�`�kb�SHaTG�S-�=<��²u�� ��V�h�1�-T�R7STROg���!}�z���6Z�Փ�,� Adh�"0V.i���
)@&+?�p�*�4s%:�7
$:�hMKH6V�]䧯�(rcv��:xF`A Ru��G�jrm,vtW8��| �ԣ��f	 zV+�z�(CGA�*K ��X�	L�IeF������F'/�')E`��hIg�/�bmibP-T$��Y	�'
��x�kj&�	��*���l5pwLE�>�_�-!;����F��t=<�> ~���c� �,(*&Psm˟�� 0. b<s2dl_;f�V����CdL��5��
EkR��0���m�"l��; * PhPsx'�D bc��e-p 6&�~,-P��a���H��	�C �h�>_���ONLY_�0�;.8��oFw  =3���K���/sLABEL�U�j�U�='D�`'��0��%�'P<�'��;8�-uKP$��@k�dk��vs�m�aH���Cp�kQ(�V����V�D@UI��ND�X9C;�! @UT	!�XQ_o�AJae�,Ujg8�PDN�Am 0$�V���a4��u��~ў[;�MA9AB	U�S,�js�DD��l6BY6�\�2TL`��,���0�f8Ws,Y�kD5R VdA���7 R�������l�v�Z�UVMkG
�� jC�a6��N�7�-�-������.,��U]m��KY]7u�=��J�,� c/%��DOCK�F�W ?{��n�XT�TACE8!  kAb��2�S4��Bm �V�Z��fw�TB��<�
�D��e؇�2��BPBn�X���2~�Hf�+�a� 2��`�G�^5Xѯ�,�z;*&��\Y÷u(2)@�(HE�ɠVF�7�` yw��b ��tOBM���_FԲ9=�fM�=&�WS/Nǰ*3��B��2q޳a�w"%0¤��'2`�D�G�G�0`p��-�+M�ʽ>�v��fA�\i�(6�=O����	p{	A�"Els/D�^����NGF�,QcV,�KrA E��K~I��my 6 �	,ۀ�B�q�U&��0��t|(+�N�p�UUv�`�R���@k�*#���2�-
-� 7=o-����ur�CAkN|thKې8;h�I�O	��UT�20�Sc��s ��bYٍ*ԉ�&3�y	b�/�(�0-3)T�����<.>[,<bpsh\�a�y�>] ���B3��W`8�SGp��&5��؄@81���N�O�1�8�E�78F�e��X���IIg-!uPS��� 6�PR&T�����,[m�*LؕYY98�	Z�-� ��e-V��b(��=WhX���Q.g��x� k�n���fA�)L�([�[ ���p���59:�{��39.5�$1�&A�&0�� �]��t�s;5R�"��0S]�m�'��-�w1���v��c'eh�xp,��e�ϗ��GU^�eA�E+jv k+"�̨1w��"Y+�WW"�5�(�k�8��j�@&t���X��l�W)%g�q��'�}��:9x��(�a��FsF�{�P__L_�Q���'%`(K@'���B�(qE��T�tULos�'��#��e@�N�.&�T�H�3BP���R2�!u�TM0��,0,�=	�Ite5�l�bf8��,��4�Hg�B�A�ׅF�Ƥ �K�P<_n��ٌ"5$��,B&Vn+�B(K�tTW��-�$�TɚX@�%�$x�pE���J(����BB1+ƿD{��0��D��:�-�B�$/��)��� �T��bL�*B+�^U����
�	�� i�-U��|E/�k��/'k�8 ���70�,Wsf��ѫ�,脲�5W;�= }r��� ����j�	2�w:��"�ܳq"^��& �8�����+�OF�zV�� �a+[�J"�&# �u)K4?dqu���o�*Ba�+{x�v\\nRA$��\t��m)[*�Q�pK�0E[Cù�Ճ+ItHXn |�]um��@���=X���� �b{!��t����
��bVx%m%7�T6��	)$ozmd���U�W��vYM�!��mȢpc��

�{��%�+9Rtf_B:���e%0��`&	0���j�D��&�(F� .�Ȩ7���bT;�k��j�*L�SYNuA�p	�H��mmZ.PMj�^S1{�M(��w+8�n���#�C�%���,.Fr��D<�mQh� RHͨI�pG�͆�Di����e���x���:ZZ+�e,�nv6/a:9ec Lt::���D�� �Or�ZC�_�[�	��:sX�k��FSB�LDR7��7����(.P�%�%�APSRE2
���-f_
�T��v/#g�,�8r%U8�/(^ઘFBAB�1�C,!�":b~Vf��I��*%N�0U{H�bc� ���k�SU Q@H����lB�z#npd�*cJ:�t�	d< �����[6췩64i� +VY��%4��ˈw%ߐ`�Ng�AU]�ě�)TK1F�;1d�䊞\rA� �^3�-�*dUmj(LW�V28�Ԯ��HS�`��PT:�L[�$	-{���q.þ`+(K(<��Tu.EFIX-1��[]�
f؂ԗL
If�a,�074�5(��C(<)��� �BB��}�jf�4cBo.�� E���	"��Y/4�BD!eA'�F�B	j�ڑ�FA1#���t.1bT�o����ID�N@C��@0�_���:�=�_��H�Z9G���ec���� �dTIC[V��W k���ON �"�&���';@�$�,��ae4[m�{�a�`�Z-N�!	$�˂��!7��+�NGE������8�"0"��C��� ��	d�_T�#B��_SQ��%NCTIVՖ"���Xi�`� � F,16_Cr.�	32 �=���"	4��`�2�$L*Q�
b"^D*{��A1�Q%\�hW�$��l�8b �];V�!��� ���-,���Ζ1+NXʭ��%�!30������ ��-[XB�^�C"E�0kd0_K��Tz��gQj(1-'ڂ�U�-� �L|q��%��]Fv�����C<��@���tN`�x�+"�פ�oA�.ktl3�-kaA�Ֆ=��p�F�dՃ|TV,�+ƪ��t<�=l{n�C4-J_(3 ]���Lp�������T��5�>��z 	jT�	�I������Qik7�q+		N:��N�H�	�*`2H�-�،}� �#qMpok�dQ	�%���D�M	%18�w6�m51142u�{'��E
�.UԵ�i42�����MGT %�E2CK%��7����	�L\b�$	�3u>����{cb%u ,h�� �3))`Iq k�=���wC:H:SPCl���LiLo 22.5.104YE��7X�bQ1�N��"F5��.��C,oe�4Y'��v"QA"N
��Y�:v?2j&��s�3`�^��C��8G�x�
b�K|�X�� �!F0��.P0��a
��$���r��$SRhHĐ��*��qpy�8�
"CD$��KJmk�Ȑ<��E\�13E���禅8�d��48k;����
3/B�Z0�f���;e� fE84M��m�s��u6a=u����f(>)Т�!:>�?vY{�q+~HeF�~�Q�H63"	�2���D��_m�-��BE$�bV�N
{���Q���BO��(�^�9Z  sC�7����@�E`�
#'�=VG3�f�.�'-'6�X��2Rq�JA�0,H�z�<
	@�B{.H�R�bH/��!W��u��|�xn*��A��e+p���j�ƀ�ajor�duHҌ�:�ܒ(V��G���k�A���cvB���
zrbM��^s'�s�1Z�H����KC�n����2MW���Ñ6X(�y�P{+�P��^E�8(0 :��f�:	;��JAk:5�Y��:��ì1f�v�
d:�A,k��'k�a��@����:�!l�G5�p�?$ YD 
����%����>�X�XDEIS���N6f�h^�:K�bn|�J�nd�	��w�5��pF�HoD'Q��\a�Xr�:
�GQ,u*�B�*x���k�V(��35W6d��%�10Z��482Η2a��56<3b��Y1����60;
�)"�a��5�a"��T'�#	�:$p��e�7C�eV�b`A�(}+�f&sJt��Ƒ+:��-�(a��Ծ%Nl�*J��3���~a`�^�N� � �j	�+u*�	lD8B6kAP~Y) F}.��V�&Nq !1��
$� @�9�GcG� �(�	 yN΢? �`%�Ǩ�,E��DL4;z�M� fs|F�!�>(uG@���&A�l�[� *E��`A[֧�fDe�I<�ސ�
qx�F���{�j争A�L�~L�aD� PJtp[z/��4(l)``�@�S�I����VTC�R!LB��2uY E4+Z���@p<gaDA�s���F= <>��(訯$�%������B� .7/n	�&͂��HZPa ���6!@�A�WX����1�qHKgRr��`�G�ă��MCV/e?2� WINk���7s�
N���y�O�x�+>�} �݅�g 3�7� 89��0C123���<456���&�d���&ɚ�4�r@�;?DHXO�be�5�9۱��k�3)��iQ� ^i��ik�w���i�������  4M�]������4M�ܱ���M�4M�����ۥ�X2<C�(� ��a��+|�#�%���Rapy$�4�.K�R(Y(Dt����m�PНM:<NǢ�,F7
X�f�a���E�-Ln.&),ۣ6[�+&X�8�-v=x�w1:ժv�P�fI�ͬ"+'���h��S�D{A7�6`&��e��<ԝ�-fl��gb{:�&+2L���_1ڕs.&��X�opUofR�:S>h��FP�`:f��.7 +��@t�qWZ���r^����4i H��Vy�Ş)��R�!�v��N��k���'5D.a����s@(B붅C_X[]x? =^�^%�M����pp$+݄}�-123[j]��{��0�X�c���-�f �$uGU�Xqd_��B�"`�r$J��[	El��	�-�)��օ�a�'i��
�`}c1�w��R#(Q A�9��.B�} ]t/p@�8� ��!A>�v�B�Ѵ�d �	Bi�\<ƚTf��IA��*7��+%|��\��Ed�Vf:R%�5��]�3X
��iBA!L)a�ح�0�C)!T)����Q)�W)��� H�[��N)(H)�t�6 D %I�%��'�ر

L�VD@�.�r�P)A
�@�tB)�� ֕�  � �Y�wUL-�$C�)b��8�oY�/���cA�E)����lI�^S�=�)9n;K+!��OY�'=�c#
#��d:za��]  �=�]/	ԥ,{�D};
$P1`6�[�L�$�o#Mh��<���ˈD�r?`��T�d�-{5h6�-�͈�t�
܄�&�Rp2r�%s?�p�J��,�x- �����E��Titp���َ|����/�S8((݇- qP `9�;c� �jr� N��
�>��U&�()[Y3��Ӧ�,�  ���   y�| `��.{a+!��쁅@?���;��GUB������[P,F�������������������������������������������������������������������������������������������������������������VA�����������������������������������������������������������������������������������������������������������������������������������������������������������������O 
E�V�g^�`�0H �[�}�  �X t�ߟ     �!���J# $� &Ł
mx #K+Tk#x - 5 �o��o� 3 4 5 6 7 8 9 �; <h�Qo>%p���)A B� D�V�/5 F G�� JhA5
L��ƌ Q� �A�����X�V� X Y Z [ \ ] ^ _ �1?{�j��}uk����� � � � � � � � � � � � � � ��� ۑ � � � � � � ����� � � � � � � � � � � � � � � � ����� � � � � � � � � � � � � � � � �_"��W� � � � ������� � � � � � � � ����� � � � � � � � � � � � � � � � ����� � � � � � � � � � � � � � � � ���� � � � � � � ����� � � � �w� � G*��� � � � � � ��TZ��f�l� a��if4TZ<<.��h�-,M4.1.0��m�10S03.21���#""##$ %%&& S_�mh��n1(Ql)u�[�p|+;0xԠ�B� 
$�m�/�LjztqZA@,7��-]O���?�0̈́s��5c�R�� �xX��K�B�FeEgGaACScs� ����+0-#'W@3?���| 
��hqcw�  ��B_qx�**�ti�{%�:c,�m�{~]gs�i��}������i�������,��i���	��7�W=G��Q'#1[i�f�eoy��5]s������6 M�C�����r�l���i�#-7Ai��iKU_is�i��}���O4M�]!+5�6M�?IS�+���]gq{��隦i����O��i�������t�%���4M� '.5<�XC+X_�}�fw�pEJ�Qr5��Z��ttyU���SX��� � ���� g; in�k �m n � q /�D� �v w��B� h�zS �?S���@SunMonTueWedThuFriSK4 ((-Vb�v+�MarA#yJ#lA�V��ugSepOctNovDec4 0]|˷:0 ?=<�Mt����aso�slD�x��=F:�P+�j�AN,���ހ@���?��9ACG�O_���������y@� �����4o��o��p+��ŝiզ7Ix�7���ӟ����G���������~�Q��/��8����F�u��uv�����HM�]=�];���Z�� �R`�%��u�uA�� A(knN%dh׆L>*;4�znm=[����$���Mu��]�|�_�KB��nFOQ�y# +B����S<�ń��Gv� ��"@�b�h�1BɆ���{�Urup5�6���S/�,6#Zv:%�hU�YU�[�rgv��`2��E�v� �BB�Y{�
'iuVD��Td�eB�cUurc�i�CnzTI��k�V� �� +ĠjA�:Ғ��^p�B��MћD�r��au�y�	@�QͶ��͡G-A�BB��j���0mIsG� a/CtxP�$�؄�Bap�^2(D�;�b�72���)ČC ^�
�!Q2�A.����:R$�lG��K���rYp�U
����kb�d. 
fA,�p�0�2�dx�,D��oýx.$T��"f�aVFc�dD���NElw"^�Z���5�� ��mbo=� ho�
V1V�&|IK��G#X,\j�r�I��~6�Lc 2~��CE<B�;A3�7�XL���&0NP>���A�?�VQ�Z�aW�B*\�� ɘ[�m�H�)�؁4���E#�P#
�jؕmtd1csmR+����ņ4+k�{o��mTQ�9�-� g3""��-s�� I�6[z6�` `t4,I�;�����N�L�2@mB�l���g�s)sAd� t�Z�Sr�����j�PgK�<nd�*M{Jah���[���9�5# 0rjR�?f@'�,��*������~�F^L� (_�EC��k��	�N�U��ײbs����b>�"�;�n�f5$.��/Xd|a.�.YTZD	Cz �sW�4*aMa�s�bvlo	ZlY�	jX��!�C��,!�d����F�4
F~|˚��H�� Lv��q�*IM�h�7�J����0|d,kB��Df3�wr�Ll`@���e,:�!{D<'�d�Hf�x	lvaA�ɂuU6p=(!"XA]ý(�ĺ�8$�k�N��T����=�����ђ46�!4p��czI*8S��5��y#C��шŖ1���A�x�?�=j`M/��Wk�<��M��Y��a�'�e/�#
���8Qt5-�Pj�>q,�do'�=0ke�C���u�f
� r�L�`}'�2��h�F�
�r"aGw��A]zN5�,�� �PL���+XENIX���&c;��Z�ڭ��_J١��U24���I/O�#�!�}Ua��&1%5i\;�T�W`��l�K�n
i��
s�	@   8 $  �؃  �9     �f�� ��UT�uˑC�����/��8�t� <��n����H�+���;�� ��tMwr(��@?�]�}����$l_ ��` ��?��� 	}��a# "f��  ?T[�&�' & g˂- w E�  ���Ƈ���/�n����a/110 15��f�306122448���5993857s�}-2?60��m NnOoEe0D3ckbgcrmy�=��wKBGCRMYW�P�&P\r;aó��QW�a;�~�^I���]�79Q���We���B^�cܠW�J^�囇핼�Zځ0��^�o�ow�P���W�JQ�[	��J��m��Wv �\'Q�야3QP;&�@�}	Q+{e�D�O~w{%�K)P0�;J^�+n�^��6c΁p��W����O,��䕽lT'�����+{e@QOG���J^�ZX����G�;�HȕE��J`g���ȕ��8야��Y�{W� r%���wY��1Ǘ��O��Gԙ_�?c���K��~,H^��CA�&�H߷@x%���?Ze�.Zc>R��_�g�@�8/�s'	u./2z��t�o��cyj�� ����jO�qv����C�@���kȕ|;�����nVk����]d'�O�c���'ǁ���mW����.n�\����5�w���"oIrw�J�-;��������W�76�#c�n��w�$e�==�'��
M�4�Dl����i�H�g�Ǩ��~��ػ^���<�l��!�=-��d��Bf-�l��M�s������n�n��s�?�V��Y6'��~� ���	 Type  Boot g_�� Start End
S�5��ector#ss�xte�o��e!BIOS Da; Are(E�i�BDA)+<#vice�ɽ>s@���!�LILO��}� ���м �RS����V���1�`� �6�a��f�
�aL����\`���u��\�v�Ѐ�0�x
<��o�s�F@u.f�vf	�t#R���S�[r��/�W�ʺlf1�@�` f;��t��ZS�ߺ�D���ߘ�f���u)���^h�1��� u�����
������u��u
U�I�� ˴@� ��<� �N��� t��a�\����`UUf�Sjj������S��`tp t��U�A�r��U�u�k���uAR�r�Q�����Y�������@I��?A�ᓋD�T
9�s���9�w���$��o|����d��AZ����B[� `C����sMt��aM��YX�����~��dG�f��t
fF�����_�������$'�@`�H�n��+X��>�tb(�N�`��7}����{���.���������-���1�1��� ���v�o�h~��?��q���t0���J�	j/��[��6x�|	wX��J�o���;&�E�������z �.���*
�ˎ�����Á�^�9�v��&����F�T	�O �R	��)����Ӊ̿�mP>RQ
�MAGE�_�u�>um�>Suf?��Fo����*�&�d�T�t��K�:~�df��u7������$��#������
�� Ɓ}����#r���fh���+����8t������@������
s%�-��t�E2�tW�u6�6���m��u�_���6���
r�FȄ)��#������� d� ��#��#��#����C�?��u	�mk�k	�L�Gߺ7��F���q���90����oi%��������"�������Sf�[C9�v�#�֦�~ɽ���p������B�f���O�����u{w���D	r7>�[r�9td��v�+�o�~#r=d�T&d��d��ڿd��&f��d�6�ݽ��&�<>�M*� uC���[�A���V,�T�֭�nK������D��ۇ h��Q&���A����_#��~������S��u���o� p	&�F������۹��'%�<	t�<?t�f<t\����<tv<tTw�<tQ<tM< r�w8G?�{{�[i�t���C]�[~�u��hr݈����t�j?8�u�}϶���&����{��� �� S����<n���s�C�b����"����0����������u�nb��Ā� uKL6�W<nobdu{ w���w/�4vga='#:��ܦ��%k'=����x6lockud(w�O'mem�ݭ��v�t�z�����찱�tt:��zQo+���g�m��K��KS��֔[��{;��K��XL���c�L>�u�}��7d�}s��誰6��@D�G2u��.�-t��!�޿,��G��ǭ�s���u�6[����D�N�6��9�t/m��0�)S++�������K�<P���X[<yK�7_<Y����6�
�[r�P��(��?�d��U�����4y��>� Dwt4/+0,w�o|+t^� 's�6�cG�*_ho����	3���V�GOt����!N��l�1�A)��m��WV�u���
�^���*��/р ^_�AQ�~�����.�Y��][	�m�o�xa��(����=�f�[����^V�-,�; �?�#�u��VCqP}׶��x6�mX=
��jU�=TS��°c/P�P����,��!��������PXjP��IԭU8�v�\u_�t5C��B�&�Xz����}�OA���=��D�����^~S�� ^����{�7}�k����G&��S
�\���tŋ�����ʻ��v�^�T&�Z�Lh7�A>����;n��6e�܌�9�v�������eQ� Y��[NG_&G�o5G�t&� >�=x�&�B&vv>m[ln+�O"�$m�m�i�^A*��t�&P�X.[��	�t����H�r5P(��m���
��	>S�fغ������X���x(Z�������P�@����	��["����.��~O� �/�(f�Sޒ�[n�.�������������[K�����������m��m�hR�>Hdr�?%Q�fH\Ey4K�� gun�[hG4��T	*�@[�V�d�� �>��f�����]�3f)�s������Znr�f��m�[�*������/��(�&YA?�&�>"0xpco�5qaB�oK��'�*��#�ָA�Iw#�
04�o�i��#�.nۀ&!�+�t�>�u������ ������Z4]�aP��h�\�Xtu�a����h�@ �[PQV�Z�Zm�.�>����о�^Y
X:&�	��)��V�R�D����6n5�*�&*Rh��-��(Z-cj�ۻ�rg�skc����'���nl�]�࣠[ ש�V?���<S<zw, ���m:�#a3:Fm��3k�-<�eS�
�$ <�j�S�y�[zG��� Cu��!S}�?��[�R.8�c��[[ÃP�Zm��������X�Zá}����u"-,���,"�$u��X����A"�[J|��U-.���ZJ$_#�� cR ����XYc	Q�![�����BAp .��F7�2mrK������&ýKa���E�����ָq�.hz�.�[���u�L�8�9j� �-��]͵PI������+RF�[9�[�0G��{ ��B� s `��J�~��o%�U��z�z�a��j�j�����V�����%�����s`E8aB��B��u��*tc��~� ��r�"��� m���T��w�NiU`�[���PT��Y�������� y�@����s������_�(��f`���r)��"f�hXMV�K�f�}ǺX�޶�[ f�f9��5fI�f���9{,E����`�d$�l�����`�4�u�,VWF>j�@H���B��rF��f���� ��s/�.�3F����f��_^����O��� Y[��> ��x1����{	��A��tifR����PAMS���f���fZrUf=uMf������uG��:u�V�0#���$

¾n���<r�G6r��w�f����z��f����U�dⶰ����br;t�6���Ө��ЮE�����9�����z<�8��f]ȳ���u���.�cd<0v2�f��f�����n��,Kc�u�m�C/r'[��k^~E�Np/�K?��f����s�"����ߒ��\�OV �j�X��D2$ YL$�lD唭��X�\�:�0p�Y��BVW:��[�:��_>�w\���Yv�������U���b�wݭc^�7�{�
>�*���0 l:��o�7�x[~�PR�j@[ �.��Į�[���t�.���J���R���R��BOۛk�B�l��j}�����1��F�o����-�ԇ�Ph�S�DB�\n�oMU})m��w��f!�f���	�¿�^řy�Z�t�Pr�!xwy�f11����n� ����Р.�!��m�Q4��Y"�$���C�p�9��;�*>��w��5� @��fw�
-�OW�Ựm�]��5��}�	��e��ō���`@)���*�6S2�=�4��<��
3ז�\m�Eo�.�7jW��K*���[���_�%O�W'0#Eg���E�����ܺ�vT2������Ҩ)UE_��m�m�R>�y�?�Fm�o�!�*Pv��o_�)�r��z)�P�C]`�Q��c)�d.�+���K��v;ƅ�Gl��8vE,�}����7=%��8������		��{��fz+�������m������eVSR��K4��S��x��RA9�w5PF�(�Xr*G$�[� ���P�j|SP_hGwDB�w �ڶ���oSPO��7��d�r|p ��XZ9�sd��l^t#Z�(���zrZ[t�ҭg9�ډ�om�J[;_lك,���œ�)�u��+�� U^�3�Mt7�f{۾5B3��@MY[�Y��6b^t`�����v��W�&�GG!7*�m8S�!�����X#�f�tyж5j63��-
���d��h�~�o�IG�"u�!H���h����n�D�;�E�w���/#*�U�)�
�ԭ�9���ށʀ�V���Z��7CC9����W��7��/��A�r���]�#9�o9}���s/P�x�s�V~YU���Չ�J_�� ��	Cf��@69�7X�/r¡_���O
Error: DuplicatkVoluXh�V� IDҵQo�Zq���2Yr!�m�8�s�ʹ������n�/���r&~���_���0VA�Ӏ�.7��#a�
.�'	8�
<��u�Vp�[X^�'�oћ�d�d��h�-�J��������@#���B*N�~�YQ���;&�>L 	�u;��J�s3z��`r.wl�.n[j0!"I�my�%=,Fz��ڷP v@R�vW���V�{Ah���Z^�O��;iLo�ذphJ~� ��K|�����8�H^�Kz�l��j��R.�7�3�̟Z����Tx���C:R<V�h2�W�H�M!�F��_"���FD`^`��j!>T���g�X=>V�_h+Ȅ嫓��8�Z���}�r{���n����wl�x����u_<r[o�4����Z�!C,6 �-��������O [5��M5!�'Ŷ����VEu!=SAu�O�#Tj���+����@�NQ�R�SWZ����yQ�yY��}lk������zy���["���ŘYP&x�M��S����JY�����]�Ɓy�RP:��o�w�y�B��tHWȴ�V��>�_���pe� ���i����cU^NSV[��51,0r
{��r',̬�r�m��
�5���K�<,��ɻi7���=�������6�������%d��>r��&;mk�Ug<������û�>��X뾔��^%Jm�1,�ӕ�6�'C�(\��8�t����V�C����XN���/�^��f������wQG�������ASK6�EXTENDED
��w5NNORMAL�Qo����>)l�� kt�7Ggt
m-�R.Nf�����n�c F�($�w?�Ou��V���r6(@�:��uuF��T+a��]�w|�
v]u��Bk��_�V���Y���+V�����R�	����<z<9wH0rCuFII�<Y��Xtx��F��.���'8�S��sR��F65��
�xCk�		Z�r�F�Ϩ]�(W&�J��=V�/�4����Ċ�����0rt%y�
\h�u��ں�6w�^�6V��^�_lp[�+[�-O�6���@�.��b�:#��joading�dch����ecksuccessful�bypa
�	�_	s 0x No ���w"h image. [Tab]hows Ck��@�st.-O - T F�m�[Vmp m+t2�L��Dcrip7qp��Lm e\Key4bl٥*�3d/!헪}rnelh�Initr����yJonf���tDSignquB nb�ޗ�foun�0/���:� [qui�n�m��7�c vaAe$Ma��ZwfiwY;�nv�}cd=���%IWRI� 肩�mOCT?���ֶXb�;k�@�Ck�.^ovlu�@k< ��dĪ�g{WARNING:zk�A;�٧=����[�nv	,�n�D(���yӡg����WG�-�?�y/n��ڭ�*I�u�h��*�U�xpk)EO���FP�w�dS�m�B>.#Vdi#&�a�
>�Cj�Zm����5l�r8dOl@ml{�bkAtvChl���a�I�7-�Z{�Vސ7l�ms9��a�buf(�8�f.@l6`h8�B�S�}���iyr08��zdGl�C�Q�� 4Mb����_��mpoiu$^��24.0 :�\H����Nau�BO%_I�	��� �vԝ $y ȕ�"ɀ`�Jɕ��"�r�"�" 輼�U7hV��m9�#�?�V�F4�2��%>�8��N~��,��+L��+�C&i,��J�ϗ h ��N,�TҼY,�Vm�[�DV�+�Vm�(++?�����+�(�	�TN��U�?G��"�$G�*$#���v	=�"��V]h��"�d�"����"�0y
U���@�m��P(F�A3X�����u� ���+��Ȫ���Gu�����"���4�#y2X5#�(�������6+˲U�)�F!��k��,a{Yw�VRt�,����%t���V](��X&#u��p�d@F,\p���S��"�gk!�x��"�n���#@&���6�%�"&���##Py%�����"�r�#���tUac�U&_Q�9�xm��~��=��-\���Ū���)�ti~���5x�F��9���7j���[�d��lSu2�~iC�UA%u����l�A�� /�r,##��A�"}"!Z�f������A��$VAe�!�V�4����CA�2�BROƪgAg�
��`խ�KA2ܪoG��#�A#�i����"�
�il�!��VA(A�q��(_(��L �j4A#(�"y�l�"�9 ��"�"r���"%�� C�� ����!�*��/B{!�a�V
��A��e�"Q�"�"S��V�ޔA�"�/&�"���B���D�4�"� ��2��_��"E �z�O��-��+蚭�C��#�o�� D+��x0��"�Ȫg4C�"�
䀹"R"�E2���VT�G�\�"�u��ɕUC&�eխ��<ⴵ(<_ .��U�*�.�REW���A���\i6��}�'|'���'Q:6}s
�.�v�u��x�p[�D܋!��7Z*�Z��C��"�"�ue�%-�&�����ؕ*�#�@�"�"��<�"�"�*����"�"�<>O����"�"�"�"Ʉ|�"*9Y5������� �2��0ߒ!y� �!�E8� �&�*� �# ����"�(�C�"�"�@N��"�"����"�"�"�"����"�"�"�"rT�g"�����A>�"�"�V=@���(�F�� �"�"�j����� O.��"��"�"�lg9��?{��!���"J!#�@F*�L�222ɁL222!'�L222E�222C��2222ȕ 22ȁ�222�4�222rP%�222��"+�	�22��.�*qR���+e �J2+e�;�++~���ͷ2r�&2�"� 9H�2��+�2���
�� ���dY���������Љ����o�C��)Ó�۵<��h��.���ɉ|m����	f��X�h����05r��Y�6����
R$��0�����vW.X�'QSP�v�~XP��(�	
[Y=R������^t2����ZI����Q��y}� ����.?�tOPV%$�����(���Cv��Q��;.�e�Պ$�F����,�l�YQ��t�طۃ��^j`�L��aP��m�\*��-���OJ -������::�d:DS�������ct#�"��A��u����� ��������Ŀ������ͻ���Ⱥ�ķ���Ӻ�͸�������Գ�ͳ�Ŵ��׶��ص��ι���������������������GqGNp�`�P�R�,Ж&��u�BP�Ұc��^�R�4�{���|�)��+U��'�s#7�K�6F@L�r9��K��r��F��Je����L�Z����(���S��<~������PZ����<���N	 �m���ư��1������t��Z��CRTR��[���
XZ��	�V�w�m6�h�w&���w]۾�^�Q�.TR�R��x��F�H��-�ݸ�׻����	���m������V���H@�Z�Y(�u�p�����H��N��QRPO�K��_9������5��]�M�q�����J	:�UQ�F��^p�
@u�L�	�W����	t��t�Pt�* ����ZX�Oك��Vāp����.�wv�끡D�#��F�Zd�	��P�v�Y�ƋV��(��=����&]y^k�6����A��
����[��S۷�ژF_�	v1ҡ�9!����rd�Jt9�)\��Fq��ںZ]��ۿ��Pt���Ht�6+�[��Ot�GtŠ����Z�M�BvAr��!Io�l�u�ވ��
Q� �Bڶ�Kuk�So~l����;�`�ꋰ����,��`e0��
��˭����.Xe����--�����";�t��7�Q��#�&��6����Z���
 ��*�8�h�
1��R���P����� �:0ܠ�e�"P�Z�ۖ��4n0:* �խ-�@�<��u�B�OS�c��M�d6, AA�Bu��'�Q�)��� n�p�������Z�ڈ����X�>F�U�MEN3��W���_�5�	�G�����n��R�Q�=% sT�vQ>#�_p���GJ/L,ת�x -��	k?*�Me%X�-8: Hitiyl`0yfc�� 7t�outSUFM%�o�Us�#@�}w%s&ma	�o �l�ion E���o	�v�~ & ops, h\CR0HA� �S$?�!�	�"���Tr@�n�j����"���@ �|���y�"�"� ����#�y�f,#�M$� �+�%w�p�,��T��>����[�����I�;�� �+� �T&�IA-d2�Lq&���@�����\Y�&9���$�#��#vыAN�(%(% ��Vp�a�$ (�r@N!#p?%����%4%��&��ˏ��
�.��-�`��<d��-.b"��|�7"�"���
. ͫ�
.�X
���-�_��*--��-�@*�3�%�6.�r G����$��%A
.��Y%��`����$�g)�R�Э�5P��M3*��$��eξ%��	^<��D%�_C%���$����w�;H���
�?9H���������乭���C't�����E%u��~.9�jb+
.3�<Ӟ#�ʂH�[��9%
no���H'�$J�C�D%D%�<������%���$.�EV
>�%��!��'
�����$��D
/�%����`�oG���[�V����g�ӚH'D%.� 9Y��.<@^�D%D%%/���U���p� �AU�	�j�6)سJ���;H��y�>��`���> 9)��HA�Sr�r�l�
��4
�%ʛ.�i�\�C%�!�!�6��$�tpe�.��&*=�ɐ�*#*�t�6�D%�d*���%r%C6�%�$F'� �vp#���r,�2��#�l�ڤ�PX�����#�$N�$���$Sޑ&�$� �#(�$H��r6r$ Wp4�K^%x"�>�I>�!�;�!�--�ahp�AΦ��] %�&-��?y6���$��6��"�$�$��+�$u��r�!�db�$�J
�<��Gb�d4+u
X ,���$��$L�!y ��$ %����,-���$��u!��LR�Ѩ,y G^�$ %�$9!�+�$i�$>��$�<��$>�'G�$�$�$�$�dB,QN&)�..,�|@�"�y<*wdH���"�h\�9�..,� �V"�@��$�(�C�$%�@N�%$%���%% %%���%%%%rTr�$����A>%	%��R� -h�*�F�� %
%�-�o!>�$���y%p%
%0�i�{��)��$2�
���#�D�44��444r2�$444�\ 44$̀\444\� 2444ȑ�444H3Ȁ444U�444�A!�$-��!�44X虹J.���O-4;�e ---~rI���\%G�<4(��\4�$\
d9H44@��f\����2 ���A C��sɲL����u�\�v�`�l4^D�������-�d��n�h��D���[d=�_�rw^���wq����K�)�@��6.���ds�������
�������4-�H��:P-w�6-oP�K*v���U��k]@)�@�����H��#\+Mݙd?��-���ANr.���<y��� o[� ����
�d�4-4lK����8�`�9G���-N��a=���Z�M-�x^�X��Vo[��;_"J�e{�L,�&aW6c]���6��e�3�:hF-j��Pk�LV6N-�,�7.��i�:���x��h@-��pk
:-�J����FDK�AA��Qx�K&�k�\��X�fz_�!2-�0�67�j\9���8-),��������PQ�&s
v+{v ���-��P���%���X(�c����D'.�6�)ѯ��ֿ��wst~������XI$�l5���m9�+6� /��ǈ�)��s��$��@P(6�P�[�u��ϑ ���,&��ƀ����M�-
,��u�[�{���f��a��\zY��]����.�����@`�!����7ZN�����D����������oKk�P��׉F��F+���^ߖZ�&�喠P�Ъ���#P�g8'XtP�İ�&���ޱX�
GE8tnk�ZD�4#m�eXg�n�l�B	
@l���P�u��ɡ�;(�������N�^�V�v��v�����2�v���cm����l��Ts?���'���P&�����l��������ت��Ю��W�u�[��_ko���~{9~��韛�P���K|+�G��?_��F��u�kEf ��w9�vY29�0����l�RAZ� ����lm�
-�.��E��W�����Q^�F�&-�z�?B�&���i��(tt_��P��m�/�t��/��B�]�V��<&�?�Kl.2}G&�g
�b������@㻿Y�uM�uEC��Ķ:G��01�i&�v�	�� ��P�ws͒��%�7�(�VBE2"�.����=O�wf�=��VEnYO�lo_�)\�����߶��Q	 �@�����u��$�f� f��A	�a�%�oշ ��{t��1�V��$<.�\�OAݻ[t1���. EP��<��a�tK�1c��\�8�,$��g��6�^�7b?c���S�w����mU(�?���L������Z[���7��~�=�F`^��P�·��l
WȂ`h7���	�˺%;ʡ��R�{��7v������&#O����'����	�<�!Hx���|������?a�� d�L�wM1�5ñ�QR�?��z	�Ǌ��m#>`���t��h�n�Sw�i+.�P[��Z\`#q	Â��
���D\����C�Nr�h��k�[��K��:��K�����τ�7��)ʻ�%W�
V���~�-������g��x�B�?���R��;"�U�9w��t�&��mi$��
D_&ki�
��\0��~o�[��uU���n���V�����u�.��r���u��q���B�� ��[��i���s8�
��Q;
~�Ș��2&_���)�@Nu���n���^Ţ'�86$A~�����N$��J�0 �%� ���#�1���6%C���%�"�����.��C6D%���A�P ���2�&�6.7�g+6����$Dd6Ģ7(�O �/�.
q,1�l�|^�]��	��F�� �����ͷ|���SV�D��R��"����ۥ�V�.�`/fRfю�����������_`+B}$B����达:E���x3�/����6@�p�i� a�_��ve
$y�e���VPT2��k����D
Z= ��K�6b}�X<��mK���^[��*XĦu s�int#v�jN`���E�	Pt�7�B�?R�CQ�"!��ѥ��|�"$�"-�7��\>��nM����D��UI�U.Vh���A>`绯[�d�g���s�	?�f��f�ݶ�>�m (}x!��#����\* �h�8 0d.
oq 9��DMt�Q��<U��|��(H�2o�����Y�#@~�g�o��B%��+�兰=������&%w�j���>X �Z �>T�;�u�<�u!�ƻ�&�
��$�ĉD8VD��u���7n�/m����r�$���|�~�uO&�<�rI<�wE	�?��7t)5(u5�� x;۸�a#���o��w� R$�6=_��Tf� ���֛�b��:�
:P�Q XP�Q跢
�x 8��Z�������� �|����A�e����(~�����7X��þ�&8��V�_����������0��[�
�,5/H莂i�O�V�.2�2 8�u����҆��I�=�,<��{���΁������/5��^PS6�?�t�u7P�G����@@dXu(6y����.f��L.���߿�w�&f��ֲ��D�P-#e�8��.M�$W�G�o�G&��%u� eb�(�>�V���C_��@t�H�zk��ah6���j�O�����-h���-�^��jTD;``����a4�0 �����@��$��	�� 7��Ũ���(L��b,T�b�A�Ay�P��q^PG�#UZ���.�������u��^�F�F*n �l��;�2�F���3n�n+f
,�����]�sA٠6�FvjSD���r; c�b��`:'���\���3 (�������'�2�l����?olv ;_�oao�g�`�c���P �c(�*�{�7G��9�㼥ͤt����gQ>��PN�aP�qk�,�j��j_�/v�H�T��U��7�Z����q�YI��σ�7	q��R�>)�GO�����q��N�9�N�����L(���K���@��K�����箂CAk[S�ž��tk�B�ۂ�m{  &��	   ��        ���       H �   M     m���GCC: (Gentoo 4.5.3-r2 p1	,��n�ie-0.7)  .shstrtas�۷b	inittexfm��}rodaeh_frame	c��d�Trsdjcr"{���)el-got.plX��=bs*comm�  �4�'Ԁ�2Ȁ4��5��O���� �J�� �6�'��Mത%�����okw�l/'X�Xf@�6`f���`=Oh@�hBd i�llO��ixx|@�iT���n�']  ݕ�w0�c'ز��0�0	�c'���vhO0'-�%lH�s']  ��q�       ��    UPX!         �l �g  �ZXY�`�T$ ��   `�t$$�|$,����������F�G�u����ۊr�   �u�������s�u	�����s�1Ƀ�r���F���tv���u�������u������u A�u�������s�u	�����s���� ������/����v�B�GIu��^�����������w���H����T$$T$(9�tH+|$,�T$0�:�D$aÉ��1���<�r
<�w��t,�<w"8u�f������)�����������؃��a�QPR�
 $Info: This file is packed with the UPX executable packer http://upx.sf.net $
 $Id: UPX 3.07 Copyright (C) 1996-2010 the UPX Team. All Rights Reserved. $
 jZ�   PROT_EXEC|PROT_WRITE failed.
Yj[jX̀�jX̀^�E��8)���@H�  % ���jP1�j�j2�jQP��jZX̀;���������P��PQR�P��D$V�Ճ�,�]����=  \  I ۷��WS)ɺx  ���)��	 �Y�ww����)��$ą�u��"��� ��o =�3� �N�/proc/sm���elf/exe [jUX̀��x�^@�o�� 
S�SH���
�� ���R)�f�����{u�P���G��H���T$`G�d���o��$Y[��@Z���PO6<��?��u�PP)ٰ[�'��w�ogu����	W�� s�����[u����@�H����_�S�\$jZ۷��[� WV��S��9��s
j�k��7����t�G�B��s)3�9��{U��/�Ӄ�E3}{����E܃: ��GU�������m� �M���UPX!u�>)��M��_um9�w�;�oo�w�s_E���u�P�wQ�}w��v�Ub�GϋU�;cuǊE�������t"��t�� �w9u��P�۶�E�PR9��4��F��<���
��U���v)�R��A�e��������t�u	9t����1���[�mg�S�D������o���]U����[������M��x�J,�]���������w�����1�W"Jx�;f����9�s��S9��� ���>�*)���8:�[��Gj j�PSV�8����ډ�y-)��E�  y��y, ����i�L}����� t ��qu-̺&����K�����%����8��HL�@bQs��������Z�m�O�B���Ճe�|�֡�ǍK�o�4[�x�)׋A�J��^p|yP?���P=�m/`����2���V���FPW�_���v��9ǌ� ��+/�76��u�7��j��u��n*XZ����!�%/a�y�t9�7t���@����gcCx�uV�@tEP�XQ:���M�;Pu����%:��[���k�4�z��Lu��7.@=�a�t���ۆ@1����Ƈ����4[���j}t�����o��;s�j2���o��)�S�o��Z�e쭱ʩb���7
�j[F���QA,�=v��� 9
�#/��ˈT�	�j-.�5\����aZ�<�I�����6���}��u�ll�W4zC ?�n�p�bE eV����n������O, 7�:���]$��*�]����*]�h(��mso�4�R����P_���^���	4����lU��wf�d�p_fi~O���v,3jL1��I^oE��jj�x�@xݷÉ�j=�s���ur�(ox�{��j�/M�p���{��j2B��i`�����|�5�      � �  UPX!!�\���:�   M  P I z�                                                                                                                                                                                                                                                                                                                                                                   ./.porteus_installer/mbr.bin                                                                        0000664 0000000 0000000 00000000670 12041470417 015024  0                                                                                                    ustar   root                            root                                                                                                                                                                                                                   3���؎м |��W����� � ��  RR�A��U1�0���r��U�u��s	f���B�Z����?Q��@��RPf1�f��f �!Missing operating system.
f`f1һ |fRfPSjj��f�6�{����Œ�6�{���A���{��dfa������}���  ��f`�廾� 1�SQ��t@�ރ���Ht[y9Y[�G<t$<u"f�Gf�Vf�f!�uf����r��f�F������fa��b Multiple active partitions.
f�DfFf�D�0�r�>�}U�����{Z_���� Operating system load error.
^���>b��<
u�����                                                                                                            ./.porteus_installer/extlinux.com                                                                   0000755 0000000 0000000 00000205310 12042203255 016124  0                                                                                                    ustar   root                            root                                                                                                                                                                                                                   ELF             �� 4           4    (             �  � �
 �
            ^^              f�hUPX!�    L� L� �   u      ?d�ELF   ���o��4̄   (   ��s�-#\�  } d�Ȕ�d���Q�td  `f� R?�/Hw��[�e? �� (       ���  �|  I
 w_��U��S�
  <���
��4[����]�1�^����PTRh,ChԀQVh۝����#�r����$�C���=, uJ����p,-l���X��B�0������9�rD6 ��t��o�>hg�~�����K�]��o���^�� *PPh4v�ə.i�=tW t%���P��C�D����WVS��P�Ɖ����������v�N� �V�;$J��?����~S��������L�ػ�$|� F��B�����^��PQhhXraX��U&L0ݶ��/�j hK+ٽͭ������8.��l�w =.�RjZnɮaP�PZa؛���֕�WjR um�v���E�Iu\���{���9��E;�u=I;0���VjhTG%d��r��Q�����	���B�؍e�[^_�x�����É�����0���	�P��%���� �H�ډ��0�����v�i*hY�j@�U�R����D�Ap/K���HW�R:����1���@0�rƄ&���� R3/W$`l"��!o����P+��z���ш��Q��dhe��M��btK�����/dev�G/�G���!u�/�@B�
��u�Ɵ��ht��H�k;�����19�Lu9�u
���~nu)s�j��6,+%΃KVMw0^uD � 0_��s�.� ����u��x�O�3i�o�p3dU5PJ�FSƭ�ĺ�]Q�l�Kش��t����O/��� 7�E�Pмt9܈�����f�=nU]�E��-]���= @��38n_s���5��AX��Tn��Q��Yf�.5?[ǅ�	�4#͌ �T���t��'��=3�d�� $�L�	���ݎ?��1��d�꽈RK�f�	Ԡx�/yp$ۋ�8��&�g�����1ɀ���o|��0�����m �C��|���Tuh����VPmF>�n�Dp�Ptl`��s�ԑ XZh�Q�ccc׈��*u�:×���v��a]	�tY�"���TKC�S�7�X��(3%S�l�X�f&���Ƞ�ˋ[K��Z2�Sm2�g�ރ�N�	�tU���os�	���l�E%�y���4k�;V���Q;x|y#SSo-�CD
r39[Dp?�=+ͻ��&1LC���\�����ȍ����P`��+x�u>��(\`_��J9Hu��$(PPQSWhx?��ƃ��Kp�P72�,H���`dY���HX��<d��\�����#YVuU��GF㋃��j�@��5���� �r0��T��\��ll6O V< �x]��t��- �t�fǋ�?�6IG��	��BJ��I��÷� U���hIN1=�?�>��E��ۍu�9
���3
��st"	Hl��=�v
+�~]�> h��s}�m��mV$f�-9}�¬��9E�8�W�m4�Stv���a�|�^ǒ�t.ռ��n�9�u"�6`�3���u�Y76���5��7ֹQrRR��˪dH�@��<��Xt0�	%6���	Fe�.;	�e��Mel.���;]y��?l��Z��[�SPw妹�e�tV0(V�#������??�Ǒt1��r0(����$5�� �����֔=S�,�d�s��
�>=>h#�+=DM%��.=FUset=NTFS;�,�Y",�8�ɱDWW���Z��4V�%���f��#�BSL@���!3_�C����,�Sۿoe5~���D��D�p�JR�%r���p�<�ɥ�t��Ԗ'��������eQM���Y����Pٰ�f\n7ij� c%�=C��t�
��oM �l������=htЂp�8����^�B<�Bp�	��%#�ڋ@�{����8/ua�{,y0;�"uS;�k.Q�6uKR��PH86ohd �u)�:.��`l���ߟ�9���[�uY����鉍�;[��'d�:K=H!�Fٝ���]$��R)�SvD�qj1.��8����`h�S_6ؓ8��SI�@�Y��H��'0Q�RR���dM<@�6�$=W#`H�VR����}(�� �j�3F%��?D6�H�wp;���� 9h� �f-<�S=�4W�e�aC���T��Ӱd�fp`tlٮ��^m�~�,���#t�X�K���\���U�h�B���l�]��N��z��fSh���Гf��|�e_��E�v�&]�����@GKbԈ�%����f�C���n=;�t��B���u<�>ZĖ�#j)��Km�8H�	�uȋ=n�ջ��@����`5V��ձ ��K*��/��d�����	�R�k�,m�`�X��7t����P���(f�Q7Y�(�O��1�[�Q�x��4Ԕ6I���������	��	�%R0`���1%k��	��s���zl�(�n�ƌ�M���}+���^���
�$��M��	�P�ȓ[��xKE���졓�!� �;dzw1�eB�t�O(u�Q��fE���'~Y��4$?���0dA*����윜�Ӛ�ROu�Y��!�p�S�}�xt
�lc�P��8�!�<�2J�p��YnlU̚kh����(I��t����;=tQ���!�;4��yȑ����_��Í�/�;/u_�j`�P�9�v�K/R�w�k��ǈ�x�eo/C�j/S`��h��
R/YK땻eQ��.KE�roWl_����wR���@�`  �1ݐ�e��K�R�d���1�'8���F�W����t���ۭ�ߠȉ��u�P�W�g�&�� �|��� �t�/�������n		��@�� wsvf��[!s
�x:�hS�8�Y:�f�`	�b��v��d�@Pi!b�7����%���)č|$�������;L�t�u:��,9	���0�Y�l%a�~(��+`CiOh��O�A������P���[썌|�� ~H@Sg�O@\6��+%��Z��f�$�V�@z�D�
M����0
]�u4\��QK��~Ĭ�mM9fg����|�� �ȊF���8>��x�7�ݬh�#�V�}�_](&NP�d����K��{npf���뀽u/���.�f��o	�-VR�� P��^'��J����!{�m����@����ɁX	
-��n4yr[����F9d�	t.�PØ-� H��9>�uM�jhHk�/5��ɛu'Zh���֑:=���@�)FxEIO>��Qu#Th�_H���tAM?���x*�8�NV��maM.9�t�VF�'WҐ���%fΒuhF��6���x9� G�@@>��1���?G|න��/ P{�E�=�;dC�u:���L��m���x���}�=�M�-������B6i��u(V#R��|���"÷y8���w��2|/���b��S!s�hA5BC� �8w�U���|��|;�"�X��$$�X(foѝe����5,{gQPL*����Ȁ���&�����0A^X%S؉&��t 4��^'�	0fy`�j��ñ$Y[.�x{vX%Z"8xTD݁7bp~�&l	��(J&_��c@���,p�)w�٣%*��	cc@�hW!яY����Hg!ae$w-�Z<�5�*1�4E�}4(4������x�
�%��=}�t�I�8��J�M�g5��i��%%�|	+�tR�K � @F6�?l�5��#VV����85#�h�a�N��{1�������L$��q��Q�[8�0j��(k�[z(�����l�<u	�@�BCoa�=�$$�9��u+ 4�fS����lE��j@'�/���Wm� f�&��G�\:=V8ِAz�1t$P-�B����d¤>ĺ���r�xI@��@W�"K$���I�Qy��?�g�.�$U�9�(�;0!�E�t(R�GX�T#���,��3oM������Y�'J��"��Yҍa�Ð�R%� �UU���M��F�z����~��{H��S;Ss	>`�^�B��Ej]��	
�>�ZH�����V<�	 
AU؈� ��F�+�}\u]1�e�vh�b��C�PЃ�w6C3~	��h+����K,x[6`��F�M�F��G8'������� x�KD0(��f�߄x����#UMo��B�s4�����"�����!�禋C���v-�"��}�
,�<��
�x��C�����8�@�rsPU�R �xuK!�Q��C�q�,�Y��@c ����O�x���0ѕ�@�/�9�����+��c��P���	�&x���܁���l[����9	�	��,�0�(�����5{t/����-�C����XGل؉��!ǉ{$7*��Hu�O-u�-,�ص8��A�Y4���xk&�5�V�NYFOWWWW���KW�E����V�/]�
<=<���Sl��E� >��|���>F��'�s^edYYZH�F��3��u�z��G�7L5�w����8��K9N u�Pw�m^PPR�vw���C(��=ҋ6n8�#�u�Ռ ��]��PR 4@��I�TQ�S������$�ZF�SMñ`�献�I"��p��ĩ�cl( u[��\$;�S9�|O�X�����G09E�u>�;G����,u3PRYw*U�l��k�`���~������/ujb)�/��?(�Q)-�Q���^?;�h�r�jS,�DZU�����荈�n�>��	���9d��m�T���o�=@�(��9��>u�����$��Y�]�����2�zv�^}K��`	�����+��fǁ��]���fE�̃�_��f�F�F
��LSocĉ~��n_��f�A
>I��~1����G�[�[�&�Z~� ���k���
�I��[�N�u���j�ء��� ���V�w�Dno����
�|�@}�6t�۷7m9�dY�x���	�X�ׁ��w+�1t�[�v�3�1�'1���m[-�G��l�3uЁ�ڒ��:)�۶�9���
T�#�J��������Ⱥ�u��S�Ǹ��9�[��{����Z���G�90�%ΔU�x�6%�����������T��Lޑ��L�,��}ԋ��PT���X�H� ����>�KF9�}��b�,H�v��M�(Gs�6� ���M9f���UBPPO(���방>C������f�+\ۍ�� @;,|�S䴄Ļ�R��%��Nċ�OZ��Ѓ�s%r_MG��9R�}H8��B�
I�Q)p+�=�I�z�_a`���e��).�AxYX1�K;��$|�KLIl��
g*�
k����}G]�@ǻ���+��fY�l��)wr
M*�.�}��+3,*�/+�	��)ьl�,UH!O�2�]�S�a���v�dO�r0
v���i9#hW�%��m�oasu%��%s!*t5Y>ېv+zb�(r�8���l��@ t8Rs�]�C��5�(s`���>�#��LP�#+�1^�+UW4�L�dҔ@����.$ +QK� '	����hQl���|���%�p��0xd��!^'T:��|�(��l�l�4�s<g@�L�[`��,F��,F5M�����*'h_i!Ċۢ�O��\z�O�Wӑ:7���(���-��r-�O׆���>�FG=(4'�~@����u=D�<�16(�aSS2p 2S��C�[XW:��K(IWRQj$2F9��!���">E4Cr Q��x��ذ�@)0���J���� Ӏ�ʾD��.�k�8�¶��)ԍ\[�z���𹡹9�h��R��	�}7ZM������;X��rw.�v��Iu������s3��KT�g�P^hf ��;$o����H���5:�l1�:xK��3%�Hk�8�DtF�g�� �we.k���Z�S(\�)xQ$b��.ڪ���| ��5�w�{��9H�`�drS2K���C��	�	Щu�B�����!u��Ъz�����Fe���N���B;����@�.�Fl!T�'�H;��-�s�MN�Ƅ��u��� ���8�;��� 9��-�2N��1��ʸ�%q�F�P��A2"�:�D��9F��IY���� =r:Jqn"ӝ�������5[�@��u��_�'�t$�e( ���/�Sb�����)ð��ģ���
䐩����՗�x�A��@u`���7�tj@�$R�u�Vhf�SۭԲK�P]�m+#��C��d�r*R�,��}YXA��DU��e���3%�6���F�o��+H�M��-���[��<�^S��`W�Co,�jw|R	Yj����D��uc�m1��P��PMH@���^?�Q�M����e��U�M�l�[�����4o���KT/�Qk�����r�u��F��� ��BCj4]�( 5���!S����> 0����OQ��"3�'7����g�8�/-Zu)���6d�(�u��ھ,�����u��m�'�g�>4��[	� ;��4�?����=2�VǆS�>���ڹ����W.�qH=�§-�v�X���� ����[�]�3A����8��.߹}Wߺ�o��C��t@��_ ����;Mu%9�s.Q�m5Z��)��[���;��>`�^h�v$w	)��(w����b.�E9�~z#��2s����M �C�R���;�+U'-�q��d¸���������}�82��p"]�0)^��0���`��)(�e1ȅ<�J���7t�tO������m;kQߚ�v���Ef
S�[3�rc#Z|~�C.9d:�
F}+R�mRh�O�(K�Z��I$��������5HPcY���%5ZC�EL��}Lm��R�� -n������� |=�ww�bdA��FmЪ ���c6a V�?:`�"iV�P/8�x�V���(L�
������_a�:��75QQ�B
/7x@S�.H�7�6�c%��D�4�,!�r$��6H�7a�6\@����?���X�	MA(9I��cu3;E�u��2���uP�T�i�?�tdth�O��Q+a����"Ñ7
��aXK��uVaP�Z)�g"ZH�I�)a�S�t6��L�.��xɪ�S�YxBTN�� F�%��P },nM�}Lu�=��}���ְY7��9�vf��b��28j)
�[�@��M�������
�$l;C����8d�Ѓ���u)�jp���s9vw��`�
vZ���� [���}�����	���u������	�ۏl1-��	׉���K|���a����;
w�p�m��)�9�v��j�ݶN�vZe��2l*ʴ�V�T$��v�ч˸
�̀F=��2�<�މ07SɁm2^+U%�YMD$�4�ex ap;u�	J�6����5�	�9�n{(���`*&Bu$@tw���j�|u#�C�b�������8�
f��Ӄ���� �U�LY�$G�B��@�O pK;%� ��>�׍]]���տ���v��uM�ϓe� V��l.�S �.��UV���k({ŋ>8 BS�'�$��ԼgY� ���V��\W0���Ǉ�͙[���$}9%�4ߔW'��m�/B�}8�/��W�P�9�7/�$'%	s�&^�Hbc���p�U,[�d�36�3�|/T�Ӹ^���0H��Q��Mb[[,p΋�Q(I~����p��B�[L�8��S-m���쮦{�pY^Y�N`��h����Ѕ����lQ�XZ����:�`��j�b>�~�R���7�$fc�߂d�C�%�c�;�Y��O���Sx��Q�[��4:jQ�k� l$�l���
�=�_��-�Bh�<
�#uWUR}j� *ZЁ+������&��JU��hа�,��WRd��*M�����rF�Ȁtnu	��K��k]�V�lPdP%�B0�vxTY��l'Z<<>4��>[,*�v��>	�ӳ`��=�ĳ�,S���V-�>��H��qo�T�<���ֺ^�0@=|���x;,��g*,lٍSX�Pϰl�,ô���Ȇ����jO�`L@�x$˲l!�H<��6�TW�6\�Y� �`�@�nC�c�@����}P�XT���p76@����e�=T��T���XY���΂u�$�G�GY�C��G��ed�A�e $(��1Y,�T0����W4`G8�8��@� c����@7�,��<�P*@"~H _�A ���~LWr2	�$W1���և��	�\�`X�F4u�`EL[�]�6>0�Ǹ��&��C�;aU���&=S�]�&���#�)A���(x��'�f% `:0f ��V8��!� @��ZY�F���Y&�gmtVi���M���V@x|�6��D׃�|#j���D��뙔Ȥ�q���B�A���������l�DpV��
;M�n�nReo���g�0_[]���0J�t���^����B�0yd3A�������l�J6F"XlJ$���3:��+0���Px�U�,B�V�y!W=����X(;d^t�txFn$2Hw��(,0�S�4Of�	i�oy� �@HR3�x�JL��Pw����9�v��Q7j&�I�
�|�9���$�E�O��L�t�;T���nmJ�
�|d',�C��Oۍl6C �0�<�ԅ\��G8����m�Â��C�2$�%_�^~�B\H(Z����uUU�*�<�6�C�Y_x~F0�2U�^��� f�&�l����v���f�F��ML�<$J�ⵌ.[Sh����^8��A���t-��Y��Jt(�K �ѾT"tp���j�Pk�����@ ~p)�f��&�[	x�xJ+P/D��o4�ۉ����6���Ǽ+�l��gs
�9�i9�|�J���yY���1Kǉ��e�9$D�|��<q�&^וrt:<w�A�7y<at6�1�ϳ�V`q	E ��V��B�o��9�B�zbt/oK�P
x+u�GXh�����o��sp��u�*�˞�jd��XffE�XӔF�Jt]�Dc��뾉D�����KB8@!�9���YD���%������t�j�L�][��)'B	��k���*\$�h�^�\��W�@m6��
`�k��f��7��	F�G����	�}Y���n��t",~��U��Y�b�B�; ��vlY�(�Z�Y�s��&@�	|�#ƥ���Fd{n�$�4I(CF��e,R0{4g�`<��?�ht\H��ti��|!OW�rv��|W�w�!�E�U���%`(0���`�>��5�,$�YG6�'���x�!,Zl� #�GI��ӷ�~
]l��t0��3��{,�AA00l
#5W:_��v Y~�B�$P4�� �V$^9v��I�2�X21�[�`�˝�5��<:<*��`+t/����oZj,>��>iV�m7���p)m�RU�9���<q+0���f e�w�x��E�$E��45:AL��Z�i[I7�͇v8�WdH�n�Q��+k�i�$ �M��N}%D��:�j����Hu�F����/��Ն wu���wp�o;OG�r.UnI�Z���s�$	)�U(5�7�P�_܉��W�8�X��M��$)��P,"��6�N2V�lH�x�I��`ٍ�|ۍh�+n�K��9�v>H)�(P�mR0ڧ�]��7�N������ue۫9v%O��~��`0���V3m�;�v���/�FѺ��fѠ�l65J-�aw�'�jŅt^>,�$E Nƍ�F�"��u�,��E*�:�*��j�۹���D���U��� h����u �F"�U�^�"�<��7q�ȴ(ǞnLU�r$U%�j��x=S��l�V�<Y]u�,���0V~ ���n���[�����T�&���v�,�O9V:Rb�a9��H��v)�gr=�?�MlD����t0�5ڇ�`�ZYdJ7:��~(��W��7��KX9�u���n�~�WUo���6l�k��:�u�H���,j�M�q�K���QV����d3�(�SdYZy�6�8�V���4��y�}�޵I5��F���S�Y��1�>��:�t̋�f�l���}�p�zL�c�JhMF�<%� ��x�9���)��k���<WR9�JSIcĳR���V����~%Aվ��M�l;@t�UY
T��ֽ5���H�_Z�[��都��~k�Z���B�TP��T�ep�P}�@;j|�����W��++�/A����%^8�*!S�0��Y"4���i��O=}���W6�
u!�B�P�փ���ۣ�+��,��@ ��;Q�M�w��lr�w��7�ٿ?[��>��D Řy��Q�ݕ���R���f���Ht�����V�\��X���`l�!э��+�Q!E�P���s�p���c�v-�8-u�>�A�"��Ш{���	�pd��u�)�:�y��cO��,tt�R7���v�	��:x��M	9�wu4�90�kQ*�Lu.���8�p~ �C��7�1�tQ.|�i�w��H�)���F�7;Uw8�n�����(U��}8;���P��5����Н@�>�<�Pj8��,@u?�bTO0P`fg�Ss�C Qt6��P~�P�c�T<ڳ,"?�k�R�qW%�{�Ƅf��F��!���/�m��tA�PQ�}�`TY^ZD�,���"8~4���Q:���,X�L]!@�����JQ��� �h�W�y���u��4��+�R�PjK���]P��̓J
<0�G�;��0)�R9�����R����d�	���I=)�@9�a�e�r�	I��;Ȩ���H�%�_�aU�3�&�]�t���6�0�99�6x��ZACv+��'�����lI�{7�i8�*�'=u9�� �ձ$!�3Z;/X6�	�+A;�O#��W4_P�X�g�0JDP��lL��}V����7R��VQғI��m{�jQ�>���z��O�K�����v���)�̨N��r��,uR)�2BJh!�
Y�x�zu-���^i�-���L�oYQ�2�	�]̀ϓ�J�	w�/k���N�!8��fV(�	�����jH�����%�@�6("��.(��Uex�*Z��9B�G��9a^�<��h�L� "�N6���wNT�$�;ɢw�x/���C�Tǁx+�uqPL:��u{�HU�t�pP~��p�L�(G/��tfB�t~ ��O~MuH�.���>~<Al]�	m
 ���,�JP��g�C�"�PL�����*�>�
tp��({ix|��0���[�$Jk�z�����%d���o�y��#c�m�A���c�Y��U#���������-��o�29��9�w�Ux�)���e�%�dS� �hAe7��Hg�b| \`/�99@D�o�G%���u��5��e��Z�2�n�j�/ m�;2,�Ym"Y�UG��vր? k!LL� ����_�{ր:*���jG��@kr�Gw���)=���~=�u�~�@�B7��;.(ݖy����w2���Bv�ʉD��;L�4�e��Z|k�F�рz˖V�FWo�~�-$�j�ک�����d9�~�F�!8�~!mtS]�B��1���C:�j[�C���0%6�7S�A8uF	���o��=����
ѭY!����!
�{?۶uM G9�0dt�>�Ԅ$*FF���/ D�\kA9��{��.�:u%2�Ѐ.�>Ǩw�2F���p.� �Р8u���F�%�/p���)щ�J
��Q,\�	F6@2\���EG�{��P�pE�:uU:#^	�"T�gn�'��l��3W�BE
�����{莄S�	Y�ys-�S�!�cHV Km���6\W ګ7q�O9b��q����A�a�Z�<�w�����,���a�6�W��Jf,2�mu �,�G��Q�x�m� ��8)З����HRjWRq<�EkU:�ȥ>2Ðp/=2��r���,1Ҋx�����D$�M��}d��L����]ōH��n�vු@|%�$�	�v�5/t%& ?3�8<U�@9��5T����(B�� �}���G&	���PэG(K�U����hn�߽!7�h)ƍ� -4lhv�*hrH��Y�(�ʢ����j��G� ���	0	�����#��X1�|W�tH8���ZSɤ �Zv~��V;V�����%]�^�J�5�B83Z6X!��Ywy.,Z�@�0$�V끭�K�^�sE���[P̣,�5��,Qxn��lo �\�ih��LȍT	� jK#է.\z4��~��C�x4������-��1�x`�A�q��0Z�䞍�D��/}P �� tp#"YyƉ�,�ENˏt�����  ҔJ�$N�l��(T�=�l\�w�;��+�r���dj8�_;��]��tl��l$Ur%��9B�/�4�@�+�.ǰr+☉�_W�4��2(�f
f5@@&��>�@'z���r�����ѿj`~�����!��E �8#4EK�;����C]�I�-P�I�;MG�(�^�胀�C.w��_Z�J��^��(��uT6�ػ��T�If�><�߸t���<~9~t���RaG��i�h�;w�u��(J�X��� "lq��UY��X��9Ft#�s�r�G���˧�[�L@	L�vV~&��(�&M�4�O��RCRgDJX�
|a�2i3Gh%�m��O��
9�X��r�8ۍn�-�ruF��
��TM�;<�tnu��d^:�+��8lǢ�P*_HVy	�9�u�X�,��UA��L`����u;�5�1I�/��9�wV���aËU� ��fu���Mt ��Ĭ8��	����"���@��ى�b�x������n�n:i� ����s�Y�Nu��/H3/�m����r��]���lC �M���Z�_.�!J��=�$DB@�A�@J�s]�-�)�÷��~͊
8�=B=�/_�W�|��ur�u�Ɔ��_W�5 C�)�;t�nX_��������:r	������|����;���u��㍕��j��2AB0�)wG�2q$4O8 ���`<�c���[�j5)�c�G[C<���������'U�o��� a��<�7u�Rt/r#� ߘ���~Ճ�l_�m�D
�a�-�-�.�)��R��CH�/�l9�u�Z5��Vn���on.^8�ۉꋲm����H?j���6)ec��j�؉���ŏ��t��߸�rv����Tr;ݡ�{�oPX{�:�K��oR.hϺ����b�5^뜉�9D5����M��ͽW(K,�{o�'���R��jݷ��	9�}�06;��F2�do�>2 �� �,$7O��A�EmF62�m2{����cj n�/d��j�a��t�.���u�����<�lUx�8�	ơ�t���q2$<m������<>p�d�4F��Ou��PڋJ#�N��1��$�˦z4��%�
�A��d�H���M��;uu�r��R�RW%���{���6p� }lBI;[ �C�^u�	�v�[P��F�z]��@{�B�19�)�۶��K*NQo]!�<ʊ���8t݋%u�:��K�7WD����7ѵ�YZƶUl��u�7\*W=d�]�zA�
�#�ZY|H���VO�ۆ��x8t��BÈ��@8��(7��S��犸��X�e/�g"~	�2����N*��+����o�7��D�s�Eu�a,��I�h�_�r��-+ZhEAh���Vt��D�T ^j�n�Dn��_#D��;w&��\����Z��� ��J�R8��٨�$n �h ���0���'I�v~��`�nd�S���vd��/�~�(�ńu�V���jOr]�9�wY�5q+�B��	��"�
�8���`_�8�@�Q[�n���,�����h�WL7�׵�5PB��=�6�;e�9��)�Bǎ�_�:GK��1�p��~$oO�uI�u�F�);~�> v8��
~�)��E����mE9�#r0�hh��6��΁w�ʉ6 ���fŴKp�X��G$u
�������y��U��6;��rYJ�>:�u���tܥ���jw;Mr6�9mk� D+_N,����$z�綨�0L�!6�@��1��[��#�4��m[k��~z{"2� �D4�	��� yXx�N�$ z}�OL8|�f��#h�m���c��i��K\�OE\��Zrk�@lM �M8o�Q��9iGK�B�HD&Oy��B�'w�,�m�p��5�B�B�YXPlPu�n46r+�m��]V�A��������ދ����\쑆�勋�5ۆN0Ԑ;4���vB5@�q�ף���F��׶�N6�����V�VтK��l���~��t�(�H��us��b��!��$|�u�w��X:�i{�y�{���)��^sY�#��w*9��v�7�1&D�<$c	�7q)�T�y:c��8xd�������I�9�r�7�H,�.���G�)	A����\�� P�����ve�۱m�W�z||��L'|w���k9��T9�P�{���l
���9�K#�GD+"jU�x�r������.�ѯ�()��%`+�4��B�3[�U��u���hB�;�X~{|+$ �d�\���pv�p�/��ht�G6�(2 P��J�߱xP��H$T��`	����@����.�����!��`~J���$t���#�J`Z��u�?'��#b��p�����}4m�і�FP6���� (��R�h�l��o$ ��`�'�<�v>��4�<i�m��>�I�����,��k�/s	��%8�E�ll�'� P�(҂g��©4��m��j��d����*eGC�"$��p�0�#T>$6j����:Y�5'm��q�ZH�;9}'d��s7/�#���'�.��)�)����Y���]�$tm>�f���, ��"Џ[��#���}��	+"�D)<(O�%�h�D���v7Ǉ�T��qc#2�Y�h��<���l�l�de�g�tt��G-�T�P rM0�~�ز��Ӊx)��QF$vn�ʛb@>�1,86�80g(/n(����F<�@W	n�&��qW�[�bV�૓�L�RU U�� 6$�C����XR��M��V!�TBiSh�T��
fp_9�h�=m]�[t���;}1u6���8��ōA9Łot���oI�	zz������r�)��j�pX#n۫��@m=&uO�Bs�I��x'~7
@�l-$�`X9{p�	p������ՠ�?}#:���n��PeG�r�S�Z$��O.qI�@��[uQ�3���k5����b����R96 XZ ���D�Qq@dY�e�l%:�D[�vNF� ��EcS@�)ωBkT"=L�3�f�� r"
�f��͉�U8zOF�X��CSn=�/���2�ۂ+0�J(-���!�s ��+q�9��M�0��/�	j�2+kC,�I܏(�+���atRv�,((�E��{�P�܇>�^���J�h,}y����6��-��s-��Q�]�n�tl��VW�#5�1�iF� �$�(���qp����pm�thp;���B9�Ϣ��������lD�_�Mڃ�ﾨ�-�Y9�u:���D07|����)�h^��7�)�PfH��ڪ�T��DoN4�G�s!p����=��4����&8-p��~cq�'mE�s�
\<�$����#Ox#���-�N����uڧ:6�8)�֭P�E799G��
�I)s�@��,tNFO����:FSyM��yO8�X+�\QM�����#%;H���B�r,���? �rW:9�\��`�r?ʾ�����R9R_~�ǆfd{'� 	T�A��LD��t����H��j�{([�^��ft\s���2����X�4�,zEd`+�k<���u&� < C�F��֛����)=9�w��	��)�t�"p��K�����ǒÄ>t�)��ڦ��)�U�p�zyYG:9F5�RH.�T4$��dd�;O�1q��		���4�q��[��AFѬ=��&h���~v|4�RȌl�Ch�R�t�Ð�r)����d?��v����)���F_&R�>��B�@GS�B{W9u:Z�A]�������r�X�2 �K7=�ؽ���G���#ƃc�<Wj�k�հY�"��la<41,�n����� `@ۂ�hR>�{Ϟ}/�<u4�ru���j'�������o��� q�v��$4�F���$8Y�����:��x��xGR�-�^=�>avp?�8$׾�`�~l4 RU����*�<8���R���1���|3/tE,��ڍ�:rwWWt�4N�[	�$�/FV`�/y4����9ɨ'�/�wE����І�%<.v{�+u�U��/W��̲lmD�E��_�.��wNt��v�h�`B�_vAQ��kE�raW㫿� ~(@-}�Uj��3{����gT_QW�:�K�7Qey�:tK��
�V|˿�f���� <$�><¥��������)Ŭ�+GJY�2�`��?�W���M��~5�v�LK�Z��c���ԑ����H%j
��wQxh��0��x�)��`�B��\`v�x���(���~*���y��� u�<+t<-,�W(6��'�j� Й�}
0�F��B���0�<xu'��q{4����10B�P�"wf�����<���B�<	�7h�? �(`v�����9�}6FLM}��:/vX�[ �Ap��"��X���ϺV��c�o���Ż�P�Q|����-���v,?U�h��$��$U�@^�y�l�<� ��kJ ����'��+V���S����*�%H9m���GAV=�k�pzD؄����38pDXܴ� �1��2�W�7�9cu/npuh�)�	+Z������Hm�;
����������Rh�U ���p�s����h@�_mC]��|7��Hm��(��`�V���V�/t�Z�ܺ�Q*gc����u�<X�f��]��p�{�8R5��=�{#�����xW�����a��D������xP��ؖ��F��==s�w�]&���0$��Y{XM����$g	9�d�ɍ���A$f �!��R�Vr�c�-[�dO E1"쭬k�	A�V�s�	&�첋1@)P���)Q�d[��Y�����;f�x�p�I.K�PP��S�l_�
�4_(�i�z8J�Ͷe��0&9l����C(�����W|x��7	J������P:�^�R~�t;�wx�	qY�j��c����\UN��GNNN�@92+:�L�S��9�����΅%�d�*�PMpy!�,�U>�������6������?)Ϡ� ~��)�D�ؽ�*��i�<��)�,��Mn��<Q+ ����~KwG�I$;H�*�|ǲ�)l�1\y6C�I>}b@���F�Լ�_�F5t|׋"�w_9�~
9O�߳m�����+��K�ޱ����#�M0��-~HbT[NL<���J�&�ښb�����:��EE���Sۑ���T�� N̟gxm�o�t~nM-`c'f	��4��R��<ո�_� ����h ���(�	��6:y+�+u
 �	�Ŷ��q!����Q�	$9�=�*v9��ދ�~9�A�Xa�[ND�SmT-eHD�Ҭ���-�@�R(ވYX�D} �Z5�����VF9�d�|���vtM�L�4��ec;�[G�!���퐿u�t �26��bRx�XL�!ւ9��;��N8����
����ώ�B(�d3�p',�-�AB���U�9�04���P��*T�-_���"�;al���v�'���9�A�t7�jt%&X�Q�
�y�&g�_�Y�@�P�Q��A�<=�db�A 4�#I~1%�GΔ(�,�֪:F��V�R���:��e��Fuq/.� <w9={+E�&E��ӶQ�����-�F��;u4@P69W��f�W@��m]�uC���r�,��Q�b5ю���Q�sS B*>\�H8�ZI�O�B}��Д!�_ƉA�����z�]�B�{�`z�}��)��g6&:C��-5��e��7x�mR�.��r��R�9�	�Yl�H��~-4ҒNu��Y)x����祖�Y�� ���(���Zm1�d����AoF�#�6��&T�
?T��\!�	W�D #�
Ae;�tƁ����u��=1�_�o�E���!?qA�xCgG$��ֽ�fˡ������4�?B�p�nO�O{�_Rn�N�U��N���a4r�L��w&ʧ:uD�.����󷤓-2V�F�G�$\��䈓Ҧos��:����S qe�l�t`p�r<�^��f�%�K��~u<�R�a�@8ͶyL�ܘe�C�g��a��A Ã�P��{-�=v� R�[��g0� xb��~�W�����d#$�{ �r�X�v~�4��#`PѲ@uW�G�Y ��9�k����h����
�	�b)�p�X�zX��刿]v���Q?�uT� ����S�sL\C�����`	��\� 
E]x;6@3?��b����G�)��HG�C���H��1�K�up)'���)��N���m+�HN@XQ�����7�wxL~���$��;�f����$�����>�4T���٤�;U�Č9(�n�1��]���$��@���a�/������wbʖ�
u���0���9�N��l6���D5����y\� ��]�?j7up9�8� t͑� :\�k��/:�d�t�9�tlt*�Ē_P�	ȀMbo�{�E�$� �\,'%�0j/D�֑�`l����=�@�2'� �8Dr.���Y��G9�r�$�<���)	1�l��p��l/ �����`�G:��U��ZaĥW�P���I*��X�w���͋��s.(��P��)ɢ ���r�O�W���l���P���A�j�0R�>>����$�ڸZ\���>�Y��;žxÏTt�Z8d�J++h0rF�K�4�
lK�4 /$Y�B�H0��eBz�j$˲l��8�n<(,@D�@pk R4�VL��������lۉ>/�X�le@���� edd�,48@��DHLP@.�T;Ȳ-�X\X�\[Y�7,0�n����048L,��a���HL��,�PT��/��.7���kq;��(V�X����XJY#Սj��Gq�"��LN�~ ~Gv�=>}��
 Ѯ�%��U�Bě������32ȷ��݉(�"�;ۨ�j>fj�	}n��"�����	W�xx�b�dB'c/1"���(����� RD�ǄC��{!d��Ds�������������[GVDo�B �q��5T[�w�9�PvXa�7J �*�I�N�@&�Dl�'���=��t2�0��Ve��?Į6\�TL���,�m@s#�� ���Ov�<Y-����t�W�C�ZBL���\ưɋ�� /
 �)�#�ai�r!����O.Q'�@��l>��7�U+	Z�nV�P��WT�_�.���כ}�N*\n���T诊��9��L)h�4wT^}C�j��q�7�GpN�Wr�5�RK���Q���P*>�c���Ԭ_�U�*��l��E6 $�PMF(��$�FfX�xB�d������KXL����D/j,�S>^ �f��H���g�������oXnm�H��� �ed�1�dЈxT�8 �1Y����6I�ۨ���q<	�"�,Ӱ%ېGG.Ϩ��w�j�~L����
(n-�\wc��r�p~�6,�+���ą)�}W9N\�
ݟ���t�o���
5���וj�U�BGgU�@�X�`���<j��vb��Ǻ��C�i)�?�HWD�Z�~��MV��( (�I�;�<U:�A���e��	�D���Vs�@p��Nu%THB���郎6[�Q�Q
�2W���T�� ����l�Nݵ��'�()�PNE��uU�U��8v�(~���=�n�[�mOP�<���$
?*O�#�%�J��\u`O�'�͂pc:���\L$/�]X]��
mE0�.U[m[J�J	A���6h�R�_�L�ZH�@u�G�8f��{�G�T�W/]Z�>{�����5:{;W��K,j��	�0�uH�������h��3~(�؂��z>=<�;?p�o�{wH�8��R�.���dZY�:zb�c�ǖdY_?�!���U�G�4�y��P��Y�V-�g�uo��u��JG� Y�5YE�0�����;,$��D�}��D�`& �b�	��Y�	Zk���`�ve$j�R�
�E�l�)�1H��jE��
n.$���e� dY,NP�(�$�5��h#�[+Ւ9�Z���V�D8)�2o`�v�T�}$�7�^��k���Ni�,��9�RT
)�%<('eC]���u9�y�؎(�W����qk W�Zy�	T�l��1�$�l��O�p��}�QG,R�w�)��:����LK��F�U<���%�ѱ'9���M�P5�}��
��GR�֨�EE���&`���)o;���vLwI����y8�Lէ,���uDԪQ��8��9�i�RWP���`0V���f9�a��wzPnOձ1~tyUj
i��tiP�}X�t^�4�V�CU�L��u���o�	�
�a��o��R6�)�)�)l}�.-�;�tD���/;c	��<��u�1�V�G��iPR-�A�m7P��7�x'(ʅȊ;^:��r	�.U����qX��X \����9"�$v!�?��[ V�t=R����ӭ9�f��o	."CG��1�P�@�|Ɗ��w�%�6�"�@c�n���%��^�H�͋�o�y�x#�2u#�=� �:K:�
�(n��҉l�'�K��"t\��)�\�ҿ�Y�O+�!O���±�.����維��pJ=�N3^���.#�
�02����G�y���y�\�TV`��
,!c������A ��9�p@�5�(,�5�E�*+��,|h�&��n����s��:��֛ N��	w���@��4���u�N��	�N�-�S6�F"C�}ϝO)�l�a۬$ʹ�;���@�,���f�*�J��e�: ��aup�y	M
����x
�ݡ��	�a+�u�fc�Q@
�+��+��a ���t+�@X�����z����}o����
���hRu$������������ٞ���L�B{-���?��@��>vv-����
y{�u��Y<[?u=f�>X��B �Ppΰu*>�`j~�J�����3
�a�D�\j��?��v���X:�w� ����:���v0� ��=>d���#'G	\�
��m������f~q�r�����'O�k�),�̷�3�-�����`��+&��m��;r��0�Pm+��5#'�|�q��
��B0��F�-�6Ȭ�faݍ������UB�B��f�*ܶ}@���l�8���=��4��+�w��9;>L@o�4$G��2_���0;��b�;|�mO��|�9�|��1~h���� x[�g��~M�����0fu'�����.G}���0 p�	O�� E�����~9�W���|BD� F�O VD8�_lU~���09������� +/�v?GG*H�Ǣw�0t�#�w�xlD�DP��[ޖ�!9v�ݍ|:��ʎZU_�G�s����`����FMϭީb����%F�o)���A	���(p�*��@vm�{7!�r�5�w��V��
�+lq.[U�M�U�l�c�A�����{f�����%�X��Y�_��4u�Ĺ��L�\P���d9�|(1`���t�8Rh�l�²љ�	p*�t|L]��-`��+4*Q�b�c!hu��bm��8u�wG	�at"�((�w�;V�����`~�F@DGt��c{���Q~F��-�(:.���(G����m@���^���)��}N��[��nL�hc�T��劔����̈́�����ᄮ�ok�����-{	�+���5���Ō���S?}�I�ř��y�v�`�E�|�ߋf���+�A��A� �Q�ݖ`橣] ���f�څ,+���O����R[D�G�fв�P��H `��I�L�ɝ�)�T�.�~"[c��x)�����J�B���E�;�,) �х�;�eh��B_E�~|NC��0�+t[���ӂ.uC�WAR��Q������2�����J�v9V�<�h���F���`�N�Ͻ-���(㝵�g�z����h�F�;V�h�
)W٨�_�tѥn(��T�j��$�ֺ<�h�����Hإ����@^��E@Ԅ�Q4�}��UW/���(�	� ]3���T�x/s8R�x$�1�u(������ƻ�!W_�k�f�r��%@�FID�p�� ����=�,�#�	Y��LUG3+��6�	�ۂR-xn�֛ u"�Pp)��Lo�șB1(W��7��UY�_U��Φ/��N�w�X��@����X)g�dᄋ� �����-��($v�0�'A���lt��֕8m��$��h
ҝ
�D8�MG�F��a۶V���B��~�3@��<_2����F�>%u߉A;�۟XX��H}��u��.��d� "l@S�d�2[��!$�=�{��R)��DA��&���(�1/� foP"	щ���a�+O�-�0��+���r3U=x��.B�O��P~����� _��ܫ����c6��l#�{7�T�n6�k��3�7!�5��]�Am�`�$�o?'U��ٹ�H`8�h"{� +y���5Q�qPZ=�T�uDu�u%�� �����0����W�&Q?_nnQ�Qy�^��J����.�0��,\�7Y��8�=e��XNA���o�N=Fơ/^
>t��
�-�+����@�$b{ۖ�L(/]uL)������>���-��'���5��<]8F�k=��q��1D4(9zs[��|��OL(��f ,Q���A�u#�i��"	���$$�prZ�z#lm2Yf���fKV"�D\v���2�&aW����kѽD�	��X���@&��&�Ѱ�ؚn0����]4���@$��c�=Z�D AXO�0�6t:��zI=F��;�m���\�9a¾,h��GD	P[nu	�+$$HƆpYA�V�X�a�6J�u@�q��^f��OY���. t	0�FG�
�k�u����fW,����:"�ct�i�E��\�9in���t9��w<�DJJ��>t?uuȆP<b�07@<�G�	�)�yY^ԃ��e�x˦�ISo���Qp�Ram��&�t����t�J<�H�os���(0x+4��T'n8.���؈c�H5z$`�N��'� n�5B��V,�>�-[	ض1F���^b����ĊP7���u
��6��%\S��HS]NH�T�Q|�'Z��p�O-��0<	wLc,l%�U�0�1.ՠ[0�ԍr0�[Q6�~Љ�s	v�B�Ջ9�	$x �F�z$���Q
�B$��j"�~�m!J���Z��^��nѹ�Aj0v�J]�8>�E���V�OJ��A>.�����E/[mwBD>�L{K-w�epm��ag(��HD��(�������k�
���7�\��-ͩ��.�\�h�}����D�*���lgP��4�)�j��I%	��n��,p��5r8*Gk���z8ug{�v��)�H�G+/9���xn�H��{P	3������ }#`{jE	��-���Em�f��nO��~��r�y<+K���4u�y���v�+#D��d�@�l�O1�V��F�����_���∅��������|�d�Tp,cx���ot(ڸ����+5&9ʞ��8B�j����~D��Dl��4�v86�m,��E����7�%Ww�X��Ao���-�����⡱�����>��ρ-�ب���?�w�gM%�srx�uck��i?[���0�x��Nk�����0E~<5�	�gv��,Q�Z�6���C
x���t3ǋP�tJ$��J�= G�;��^�B�XHvx���t�N>���+�.�-Q�<@	BBg��Z��iӔ,
�C-�������H�;��~��&x�۲,kL�=h�8��@�������˸
b���	(O�+:�p��a���� �n�� �O<p���Bm(�w0R��$�;B�W4YXnXt<0���m���;7F�1Er�AƉ��Z8|�5]v��p5�;�2�s��,
h@Xs7��I�<�����i6B���� j;+�����.iL�-hon!؋s�[�3�p��9��� c���f�؋/��7yF�Z9�uUY��qA���kua�9�y��"5Ņ�p��Z{�	e�%HՆ����B*a�����TOd�N5�o�p��.w
A��b/���Y�`b%Ewt��¢Q���e� 0]��pԻ��t"k8��E�F,�8�	@�����Y��WB�
Π �XOI]��@q���`Y�wI��QD��X.����q����K�"!G�WBt�k�ZJ���B�8 1�:�u��@G�E?[����Ϻ*��z�vの�|J8<rI+!u��u�KQ�"�DK	���	���B ^�r*1����ց���L����~1���t �r}ٶ�}BtG�!�D2!W.uc�$�w J@{׆	�q�j���h''R����)HVGF�D��u褐=� �4�HKP��u|vq 
ԃ�	 m+�ߔ+�X�p�)��XD�q]Cw��U�h�^Y�q�Nf��� P���L ����nY`G��Pv	־"P��t�T��! $.LP ���0ꨑ�04�)EJN\�/xhT8�;$04�3%��d"��#�mf��4�[0������Ġ)�p��~&�ݾ�A�ԀW��G�	xMc$���@�r�����-tu�2d\��>�V���F��ts��@A)`kR�`+�ԇ8�Mwx�n )�v49Y>9v!�9Y>	u b�X�h��'���WF�+~�8��77��G�g!U�&��V�a#<.(Z[�=�[.��,��77�:� ��ņ� ��'�EE�[�]Q�U��IX ��M���KW}�E��[��%�M�6ܒ�� �%�puܕO���{�"v���R�R�'�խQ@�^#P���̉E������[K�p��@WuU�@<�Aw�up���;%�Jђ!���}0�[k�97�3u>MM�����΋P�e�V��X������{U�~�ݿ#�U�Mď��Pu�9�E�5�5 H����ek�R��Q�Ph��M��[��ڟ1$ׁ�ܭ �w�0�5���hEbU%n�� =
�=��"�9)#y�s>�}� x�ԉ1Z���!y?�jn7�9�w`%��r9�v,�VZ�w#d��,�T�n���Y)j#��!H��|�g�C:�����Q��a0y��@��	�;}�H�	F%�B^����m���f�#p�F�p���^d6�em��0��n�@�U��C;m�v�>�1@+��P+Q�:� �o4~0���4h�����W���a��_ؚ��'�^�f�<6pw�zf�cu�L.u	�FA�
�nk�k�g��݅}��� ����}��AA��˒RE!�mE�7BK``J���'xk5�P�<3��D�Gآ�|���zw��<��N��q�ws��D�::8t�7&�dr��Ѐ�P�.���D�-~TN)�x+�J�T������\K ��m�oq�x:Ruf�h���&��m�x��֞��,}�r�hԀ�U����l_��p�(ɉ91�@��i�n�8u�	Vuދ��l)�;4F�h����1�(�1�H�ڞzK(q{Z~���;)�:{�h	�
����
��������,Jy!u�}���m����↰���U����=7��,bH� "Z����AHC��Z��?M`��h��{['B��>���@��S�Ӛ���bN�����r��
�<�V耞�$��� �dJ%$9DF����I��E!QD	bn��t����ؓh?�E�\��~�.��j}���{sY�=��/��\E����XrF� r�Z�H81�߶�"�9�v*X�.OQR�[;Lufz��Du�[�TQ�= �
� 4��GUR���O��Gl=q���FoW^�d˯�;u�""�{�M�APr�tP��*�>�\8b�^�Q��]�$�&AC�Fy�g�Ttw:9�R0V�1(��
Z�QK��8HA���bA0B�x
2�mI���[��l4�w�&sҕ�Hލ,,�,bk9�пT��ܘ��u�i���^��	]�'�9�:�_5��o~E��,bA��[�UՔ6t�?��)���hV�\�=�������V3�R�`��7����$�sl�h/v�4�8H�	��A���_Œ	)��*<!ШKm��-O�g�BSV%"�lE�@����Y�C|�������ȅ�`6�H��è��dE��c�ߺ��@F�X[� �m�eW�<i[9  �/�_BHRfS_H/sys���	[/block/%u:����RROR: failed to open %s
�o�~can'�rform h�[+�e searchJ5ult bt���hs�xt234 v澵[fu+lk nt S��o�LNoJa direcjry:h��/sta# +��v�nF, ?a/3�k��/4�r s��t[���em6/pr�/mou0o/����etWbM�P1�k�n�ic���ٰ�^hq is6�C�48�=�n1o� m�-X$W$nlg)������Z��'+fIgeom� (�}.H-%%�d�:wad�	s(s)
  �\�(oAh[ůk$�b��i�jually&چms.3�/.�njrt�lu�cc	͵�*x?�v��v �tu�
���nz���h���pd9w`̐,�FA� c�T12�6���|3:�;�U�)MS�K��WIN4.01�ritmdoVxbo�0HF[���\GǲE�)u6��	x�ldlLuxX�b�._=�6��neUu�9�m؃�v�XsͱFr]m8A�,���wo�1�c� ���ZE�� <-ȥ��R6r[!
�����	�{P�AN���599�@݋�U�� {$y��!<0���� �  ��[�tlf��� IV;��u�cie�څF�s}��bu�2����5r�Sub�
mR�	F������. �+��0voׄl*W��(-�UsaYL�:Z� [��]���ZS�- ����Y� -O!���8껵e�;�� D�{%��ar X�f��~���f�6S_ F�πkt�a@�f4l*iT �,r�(^� ����.)e<d�ve>d��[���]���B5^8iF�[Iodr(c؛�&r�nPl[����dK�-UUl`K:a6p1ChCxzip���s�s-H 64��V�"[~)8i�t=#8S�Z0���mb�Q"};���r�k8�6ز!�qH4,g��at�id�sS�[h,�w�|f�]m�R0dj_܃�f+Vr.bs�`�9Ė%��:l8o����n=�m%Ex���0�u;cmp  L�s;3cl��޶�9OCl�,��!=�e��ޙ�-ͦR`[�Ä�ad�a�
�t�av��3[�M'V�e��-$l�[ a,���2&�YGbr�mFm�ې MBR�aF�k[�!aM�k&�p6{!` NfV�9��Nfg��Lⵏ\c�/�R��udve�	�56�5uJm��7���1-63)1/
��2560\2�6�-�Ьn��D{���*s�,�}�HV��ۍ%C6��y�gha1m���9940yHP$g�u�A�Q�lvU�Mj�nk�w��%ch��|�aH�2N��+���@��)g�4Bk � �  �I� � W=�p�  4 	-[� < � d�q� � v�tB� * � %� >{��6�f�i~E��Yd/���t�U�n@�z/�S�ds�NsNH��r�f@�v?#h.i�/(O3f@�=M��GmKaiR�����t:f�:UuzsS:H:rvho:OM:v���
�hM �
B/Lh YSL����UXLXT-%����#AIFH�ܤ�4z��KSB.Z�)?
f[|����3��d% 	��[�m
�Znkw bq)���l��+60x��r�� 
�lLjztqZ����wA|f�[
qOA��B 0�s��5)����; npxX��X fFeEgGaACScsK X��+0-#'I<
L�=cpuOٚ)Y����,�%D:	 `|�mWJ������i�������Ͳi����}4M�4)3=G �7�Q}Wq{�4݅#[e�4Ͳ��#�}���f����?�}�.�l���~~YN��/~9�i��CMWak��i�u����m��i����5M�u�OAKU_i�M�4s}�%~+�i�摛�����i�������4Ͳi��$��l�.8�O?F���MT+[bipA�iw���o �M�w|@��~�����POSIXLY_CORRECT�-@�'� `'Mm���bu2
,x-a,�:����Ma�Z����,7y%c*��Dkq��%un�PCdooiz�$���%c۰��eg�9 V�jz1,���& �,�  ��  �| � `�{a+y�!���@.�?����;  F�/�E�O �F n ��K/ NAN� ,�e�@�Ȁ?ȁ��AȀCGO�Ȁ_�ȓ���@��O~ �����4��p+����7�͝iզ��Ix������G�����ߎ�����~�QǑ����F�����u��uv�HM�]=�];���Z����"� �R`�%uA�� ���A(knN�L>]*�VF���JF��s[ ~ut9}_^��T:�|���6۔��T��n
[y p3���Oi  �NE��А��Q�m6Dd����"h�1K9�+�"�tT�5��a��=6sۍ�t/�tv:�z3J�VQdrV`|DA��A��C�� ��a�p�BB1���͓Csc>uV-�+�TF�v�ւ �y�m�p"	y��&*DvC� Cʶ=���t'mh�v��P A`��V:�p�BY7��ii!D��J6rub�KF�m�ex�$��
nR�oG��-� C��8sG�EK`8 T*�yLq��6�3�XBap(�akoi��Xlb�X�qT�)ě�M�r��bf�5I�X0\{ek|0-��f�G���B�K�k�p�U�$�ˎ5��Z�7X�2.��ò b@�qrO�dx����o$��K���"��dVFc^kLi/��3��!weQ�B�-�els��~��`�o�c�b@sۣ�x�
&�y�v�IdY�e,Ds�6qvdCh�I���fM�Lc 2~���e�h44`�F3`�"*�NQ��MP>�c/[����aW�bkR�|I���G,�c� �4�1m�)�,F����t�E#
Wvs�wcod1cI�p`s���Ҭ`��k�����mT��7�Ti.�t6a�p�O-s�����M�*���sP�twlx�m�P��x�ߌ�Lbj2�6�p�l�?��э�w)sAd�Vp��Sr�b�CC`z����u}u���~d�*M{J]:h���[%�$�RFS����r V�u��p����w:�'�Nڇ!p�3�~�F^��kNb_�k5���=�p N�U��x����Xx��b��A8hX��5$���$.�%{4�#.�.i0�D	Ps.���%�Mi��!�n�eKalBZlY<x���l<W�>~by	wS񄁃F���:hna��b"�; ��S|�eMx�H�\T�S�mﱒ���n-s�0s�s�|eM��M������Dwr��a�lL6( 	[ �7��8��D�la<Hv�Mf�xA���f�5
ɂ��=(T	á+zy�+��v$HgnAeN��K�N��9``.�x�-�3��4o|B�>q�cz��mI�f$/����9y#a��ز1����j,�b�	k``M/��s��՚� ��M�an�a�'��5a�#
8�#e�j��5�m�R>qj%�Zs���l�3�e�m?Y�u�f Hop�
r`Vr'�!h#�K��grrյ��w%azN4tE���[d0ST�+�Tsl��"?+XENIX���&c;���ڭΕ_Rv( �U2�Az��I/O�D����h]a��J�&�4\�NG� W`�6�zK�n
i��;	��z��zR|@e���<$��*6�QU+AB� ���H����A�A�;      ��Ȕ  L�     f�� [������ɀ�5�U���v��]��Zd	}�[.��#/x��]��+���o���UH^��v�f�` ; L5��� /���X�SYSLINUX ������1ɎѼv{RWV���&�x{�ٻx �7�V7��� �x1���?�G�d��|�M�P������b�U��u�����Ov1���s+�E�u%8M�}���t f=!GPTu�}��u
f�u���QQ������6|��� r �u��B�{�w�|��rl���U�A����m���[C��t�F} f�ﾭ�f������ �������>��;nut��f`{fd{����D+fRfPSjj��f`�B�w/a�m���dr�1��h��Y*�]�`f�6|>��&��/ܶ����5w��A�ň����ָ�/8D��1��ּh{�������@��}� �t	�� ���c�/��������t{>�Boo"err����or
���>7���?�� 4.06  �����3 �0�5�������|����M���f�f���fa(��޾恀>��m�Ku����9�6 0�OSf�6�}w�o; �I�*f�T0l)�f[�������1��K�[�.`U��J����
��^#o�;$b�m�m)q�ic�ځ� ������fIdf!���xׁ�I0��� ���u��QU� C8��L���W�������]z�f�� )����>�!h��	�_����Q]EUS؄��<��II�9�v����vw�����`�DOr=��oo��l�[�VXfZ��)ͻ���u�uMuٕ�.,�u����;v�|�0��* Loade��'� -�CHS EDD  �U7�������Z��J��ӷ�]�o����8��Nf�0�����K��fh����> xP��������!��0	��4^�-�8��3�~_4��F-B�
9�s#����
R�� d����]�D[X$"�����ņ���U�-�lȐL��6�"���>�W�������O��}����ܾ�)���{t�~���[l/�H�Q��ͪ������ar�����[u�>�Rlh��턍�R����{�]�D�_!E�8 A�h�۷�t�������^U��8Ș8�����C�&  �� <tA< rw������8t��BZ�� ��sҪ����� ��<*><	t8<t-<t<<���~+�<u�:�O��ڍ��o.��� �d���^��x��_���u�W����+�[�~�u%$�f;6Qv2`��ͅ�ќh)�YV�� �Vo�tWQ�&�Y_T� �G ���.l��y ^���ffr�&\<0r�_x��t <9v<��<c{�,W�����$�� ,1���<Dw,;�c��<�/۷�[�<�%U{W��<=��=�o�on2�F��hT�W����ǧ�V�k f�e޺V��_W�:��
���p��������������c��ɋ� (����w�#&�0�<�<IV��х7w^��w�}��/uv�N�8��R|u�rB)_(?u��VJ3�t���u�Ԗ�h�zӛ�oܔ�O&��>�Rt��ڶҒ_�Ӣ�V/�����s�)��tinn��VW��?�EB�R�B�I_^�3�<J M���5oz:й� �uO!�877��ȹS���[�z��n�����D�m�_b����ܹv�Z���;�o�����5/z��az����;�QQW�_[t��ۍ������.���E �1��Y��g��7��/�����6��`u+�X;%w�t�f��tn6��u�Y�\����f��M��e�á�%�8��-����8��38<�aWPҷ���� �M�X_�����>
'�\�f��P�]�� �.comMc
bt��<YX32�bss�e9r/	in ��ܺ�6 0	�ͅo�V��MM^�
�����������om���V��
�����^S�#@ �����&�>�U����V��~h��ش� �m�&N���7��q��&�G�.ut�~T�����W���F�u&�,+��������X�*����_�FF����� �==nKe�m��tat��c8��r,���&���{
f\���^hLi ÉyMw,l�G{Á�M�yǷ�B,�8�7&8����HdrS�&���8��mo��=r&)$��DHn�\�	&�,?��vs�W#�;� 
ύ�vr&���8�p{���T`k��v�@��������h�&C_z)�����ԃ���!���vጘU��������>�8�A��\<Ww*��]B�	�D�)��K���_���wt�v�d9�Jk�
A�|:�E��&��ݖ��ru����[���tS��d���'([t���d}��O�T���  ?�d��z��" ���9�=�g)�vB�	 �Jpaz9�a}����d��6�8-v�>a�7p��Î�T��ıFm�u"-8_k=�gook8A%� ��o>g��L� �ޖ[w�8������
��<hn�0Q���^z$����؎м�z���� Pj �=����0�!�����B�.�W��-pk�*��8,/�.����PV����<K���_7^X�v7��'�9�f+�����֛
��% �����ۣ����m�fHa�?�f_t%�nж��`07�*y$f���[.8�[>��þ�#��X������H�I�6��ѵ�sC��p8~����1��@ BX���$0� ������&���}�� ���B�&������mm��,����C�K��`9����C�����_h1�]꿔X���P9�FQ�j|�x�7�����O>�f��Y�^jI絿���Cpm��C�D����`��:/���a��"��d��������ݎŉ��d�
�D��:F����������F,v��ϋF��v(j!ZI���hs���l����3�*6�+`���K����hx��[ci{)�ގƎ����o�ۿ� � ����������O�#������ 9X����ÊF��[�R�K�F�v�6Z�=$ѳ<��J��>���������Zۣ��oE��4�SYLIN�`�UX4h��un���P��;à
��o����9�L�8��+��%r2����b���������v�kh1 �N����^$
�� Է�^$��a�
�h/�t�B����h����eU��V�lvq�^X�N'�u�Z^�6��g0�s��f#�7����H�81��R����'�"�p{��\� �`�x{)�������e�������&����a����R�̀Z�h{pf��mx]d=�9	�"cp��ċNB�={�#����	]�0<��� �����X�&��� [I���~������$�����h�x¾85���&JvJ %ia��DM����}�o�w�t�*�V�LL<NL��ڎ-l���b������`��0����O~uf�Vvx�Asnj�6��[����N+J��t���<<(������y��OZf�������P� '��Ѓ�/�A�B��@�����3�� ��fX^1һ���J8�6���� �h���-���L�/�!.�E�4}f��>�.�r���Ȫ��9��� L=<�*OH&i�[�TÀpj3g�n�UC2�Z�*�ur�d�	�u�A'$|��[���f
�  l��4�3P���h�aJ𾂿�Wumk� G���;�®F��.��
M.�؜��k���qj�''3�����@a��x��m&Uu5]��n��r{
EXW=���C�9k���f�#�]4l��(����	E��;0����	SS�[h��S���&{��~���N`3�0��&Vt�F����)�6X�;x�`<�t~`�|�l����ј�IxJ��N�Q�j��Jm,�a���a�D�aVe�_��}�}t�%�$����m71�	t���֬�x����:r��ߨ��7M��G@[ԣpkt	SV��Z!�/!�u�o��ƃm��umF�Vo�n��*K�A�o�%뛉���[��V���[�5�#t�v{�	�M�5���&�x������r�����Xs��7�����vo�cWS��lC��-�m[_<Z8<�<
ߪ��:��8P��ÿ���ԍ:y�:�W�7�_r�<-s���R*m�[��QU����1����u�����St<9wM�
�����%�x7w:���0�7~���r8�s}������f¬��N�&kt"<mt<gtN!l����t����]f����w��n��
��Xe,0��-��_arfWk�Kot��H+r&�R�y�\�B�_Zr������^�%�3�u�eB������.��M������8
Т���(l!��)�s���;\��������e��;��`�&��X_��A�����;�m�<tg<tZzf<�}�7t� <tM<	<� s�۷o��+D/�Ot/��ot(�a�>b�	��V(����;@:�;w%���p�_��ø��0���s��j'J�-�v�#�9齵���	�ă9F�6繽Q�E�R���}4� �V� 	6$ m��j�w ���._;�/��"�m-�rW2����U���L�!#M����7���L[�Ms�6�G�A��'��5n	�]6����,��t�	`�n�����$�-�[p��~-f�7�R�F�letP���/c���W� t�B� �8�u���X�����R0f�4
:Jո�����+7��#bu*�C҅�4.���<��2<u��H�B��c'�L��f�`c7��m6Dz�6���<�W�u�0������hi�(���2�	C����#n��6��<%�7v�Ж�h���
.g�����x�p�gy��h�` <�X˳<�PH@<˳<80�<˳(  ˳<�$(, �5��PR.�ZX���X۾W��>��.�oľ#P���.;>}�]h�_.�&X;�_��m��Vϵ�U����&�G���  ����∝������.�b(0<X�����	�䡈��!�6�o�<��!桍5�3(��7�7�n�;1��5!��1`؛�������]���:�M��PV��b���f������F����乿��Cb�/���Ū���,���-6�5��R�L���/����S�o ��Zk�H��	�,(�-w�R69�m�M5�V�R�~����#�$���Ӄ�����u	-<�MB�حӍ@�5�2=+p�҃���H�ը��a�·>��P��^r{�*�X��������6�	�1<J���6H�wX�o�{<�������Zl��)��^����r1�w�R)fS������h��kۀ����>�\�I���1f[�m�XnU�%_��KL�Kݖ����WP���o�w�狽���b�c����Uʃ�X��B�؅Ȉ��BB���f�;u>J=���Xۂ�t	Ѕ��etO�5��B6�r@��9��s]kil������;:�� JK ���}�u�|�pE��բ�pj��d�G^���Ӊ߅[|�G/`
�P� ���, D%� f=�6��ENDTu� XT)M����é���^�B��p�
��n[�q�[�����u�Q�w��j%�t�������O?K���-"�!5�m�Īk����>W�m�@�D��U�.o��	�s@��#tlr�<#t�f��[�����rW���mk/Q�v�p�Y�~.���=!�c��H��0 �9�t&7q�����S]	s�W	"	/���뢾�LF6���_���8Vœ�s��c���T���7"��r����u�u���_�f�Љ&Ѡ5�8�
8	���7l���)d�m��`���|��"�����/hMA��ϮŐ�Q $�6�k.����zQ�ڎ��A.7���.g�� �A��~�޺G.f@L�.un.�&�.�/qkMo��$����[?�-�V>�O�����m��d.���@l��BmWQS0#*����Y&�U�����}��ju������Y�hکQ��~�K[p!�<L���)>��A�
C��&��V}LL��vY�0������� jd���:�	`����j�
yx�0�0鸥���z<QY�?�Kt�mfv� &�/DWz����j���m�c�4���\����� �Y��É��,�DLB����j&��XXM�z0�}s;��6�g���oͯ ����ûƯ�,����U�.�8�]p�¥p��1������������r�(=Q��K|u�>w�~rox�ir� w�)r\h7��(g�����޵`�.0U Q;z��b���ڨ��K�	t�v��H�'Ž�40���� ����NL���H��r!P+-,������x���m�3�
��`����ۮ/��̈&*�Rmahh���;�_�PL�x���r|�ת��=�uq�XL��\d���qVL���H��a$-D�r���Z��Z�T�!^�L;)�����NWW���_;��mT^%p�`QW���^��Zo����(.� ��߾�6P���h�Z�4 8�t��V�Iu��$^�5���Q.�ТY)�w����.W ��af퍿������tc����ڭ���$A�AVU��
4uXY��Ku��G��w�����]^��v�ú��BH�¥�'�_�<v���q����<r@��O���V����ö�-a��c� ƣ]�L����\+��JP�6 .!�� S��k��S�: �6�z.$�na]��[1�_� �Vu�
D�
ݡ�oݏS��l�a ��E{�t����Rp��[�ZB��f�}wo�m �=�PAMcɱ$��-@�u�u.�um��rh?>��k�.G��#�n�_�_ Yr��ms����� �qw�:�J�'�R�*�4n혋v�&�o[�X��8w��m�YKw8��r<�H�wr��\�����X*��8l�%Z;���
9U�7L�#��P���׮V��C������Ankx������%~�X��{%VQ�~�7��j��	�6��JIc���>����Y^�Bf+��]���r	��l��W 7��������B-ly"�rb}�U��3�1��ޖ��	����.�Y�BK�5t���_h��,��1%���/-Z�P�Eg��}����}d�(��$�������V�=.u����P�/)��<u�E�{5^!�I��Ӭ?p��Ɓ�������r��ĉ��=v��d����VW �uYQ.#�oۿ��|�W�)�r��B�~�%^��NY��\*��''��s�ޒ�Ȫ�/�R0)��_^�9����`\Ӳ��a{6�)�[��-&�PQ��T6G
���NXAk���:� ��Pr�ڭ�h�
˼Rko�}*��,ͨ��rco����˪[��+����_���T0�|~V)x	�x� �Mh���@
_�W�^8��e�����C�@�s(���y�$Ыh�l(��(��]��:euJI�a ��m��)Sw���Z�{��`X|����^��_�t3m��p�����l]sc�Õ��R����������w�Y��6Xp��.ii�.?e�o���.:t�7�\�P�-��� BoW��X/�ҋ����&�-ѽ�%g�l�P�P~us0e7�[�����>�����H���(�b�������\7X�90��h��U��;�pC��as	��$�Z�l��q |q�@[4
����b`�� tTh�T�D�5��h0���.�w���E$1���x��hr[

>U ����90�����E)t��UZ�#�~�΢� 6� а(�poO��؋%���3t��������nw���t$ �J��ay����WVSQR����(�|$0�V89�����v,�"��F4��t�D멐�F<s3..�*����1�RB���!��Ӊ;*���B)�)�'�/���@�������F)
������n<@r4=�W���Fo��$F!؃�9QR��5�m~L,0�oK��At/t�HQnmsn=C{74r:=��ݥ������5��#F���?��~[��d���w��&������)�t���ԁ�w�v�����v �r,�y{�dtߦyn�-����t+��z=�Y�Rt�W�����J��Z���n#m�Bl���T{���,9�w&r+�:����/�ZY[^_]Ä�O��w�ܸ�_SRP
��ƃ��~9�r.����s�I���]p������V�����/��%�XZ[�+�9�w���|�.��<rNO>��;">���D{����JFGL��ȳ��{���{?ϫ˫��10�jh�������T����7w����)�bҍ��j��c������	�R8x�.}�;�݋K;��������Z0Q�^���牯�B,�oT��B�b����)��z�ҡ�m��/ l g�s�sD���v���>���={�7�����
m�۾ ��3�ʀ����/� appeWs your ���[�putehaonly 0 ���mK	f low ("DOS") R)�m��.
Ei#v+si(����!Syslinux needs8to b��~)D.  Ifa geqt8����>messa 2��Fd,sold dgn!ۻm�Ctrl ke�w.leE)gnm�n$an#I=wtaֶv��w?fME��t��T�۷?$�0x50890d N�D����EFAULT 2UI�nfigGatm]k��direc	�Qun!k���P~:   �Inva�m�X�wim�ty=x� ׾���;a4C=�6�ZQnC\��ra��l7K I%��owupt#j�����|�_�c�s�v���\��7�#�
A.. ���·y(Chl-ܶ況�m"ski١��1 XZ�Y�4�B����OOT_IMAGE=vga=��m=2�qui���=�5_w=C� ������+�d�\9`9d9h9l9X�^�x9|9�9^�������9�9��9�9�9�9�9�9�9�9�9�9�9�����9@��ؓ���	� �0���۔L�_���������ʔДՔ�������H�o|���������������<�T�s�I����������(4Z���k�h���� s�ǂ�aQ.
CxKOM���N(V 4:.5�3`"32R!Y�	�E�r��?��jTP�Ec7a �}a�Sip_9 �[�7\��XKERNEL?)h��ۚ.-r���;��F�[O�-�x���"5p�%�����jCOUnkn2��taX3f�{��(�M	>F��^�aQ).���YH2��0���o�jA20�(e0c|��sp1�!yN{3QWugh�m��p(�'ziY��h�=����\	
��Vj/ROR}F��D���IF=0�6kH"BP�z4��zmz� ����WSr�opyr�h�(�}��C�1994-�12 H�P��*�A��l�k0l/NKa
p�ҭ@>�chz��c}Vs�p	���|�N�u���|�7��t�;�����B�+���9/������$^��<K)��YQ̀X�����@�	�%�+���2 ��{�����R�P��̴h�)ӟ�6������0 � e��|����N���R2���7G������8:o�����_Y���L�h�G�����1���2���Rퟩ�Q���^��['n���h}��H���w�0��6:����|���h~�]����<=��˳|�>�?�@�<˳<A�B�C�<˳�D�E��,ϲF�FGŎv�HO�����Sa*L����T�
ȶ-ؑ�)N��ao �S��K��L�f��Rϳ&�$hh���˷L�5$�h� ]?s	(ѿ�E��nj	����	������%D$��[ ��r��� �SUVWCDL����gQ8�
8��6fg�X����N�]�2������c*����G�%�  ����2��XI6�=�V%Zy$�!�u������g��x_^]����[��*��L*�`})σ��s��J[8��%&U �	$��L���ծ���o�﫭�oЉ��
[]QQ�� ����ǋX�P��/ŷ�Ap!I�<$��m��n�+���aö���vEf�M�x'"�A;Ls�Z��m�8t�p+X��w��j���vJ�TP�
@\�o��!�CN�: aw�B�X����A~�	��z��|=� �3�����8�T~W���G��)�P���c)P\�%X��7M_PE��� #��|�ߪտ��d���w�N�މֶ��$N��G��u����O����>#�wT��~��^�J~��@�F���� ½��vs�,{ˉ� �
%�[ވ@K�ۚ9��o�����N���u��]��+M�M �UQ_(E��D�2�xQ ����Ê+lOv�l���ֿ���t��uf�=|J�o��~o���]d���pB��R�1�	�`5:��������Z�~��������D�P 9�rI��{���)�����	�r�|�W	ƉO�Z+z*����WS�C
�B	mPW �wл���K�S�X��[ѿ}�9�pzD2��ؕ�`l��/��CP��fF�4y'G%�7.��DkPq�p�%6�#|���,߾,������	��Y�Q(J0��/�ݾ��\	�٣���H�t���l�z$�Y(X���޾},A	-A,2�HKu:���@p[<09�u+�����V����J�Y]M����H&R�B�L5&������@A�X	o�ʃ�n��l/l��^	x�xL�B9�s����xM429�z�R9�u�\B����HZ
/U��	��	�R"��}��x�=N���ǈB�@���uk8���@	����u<�� ��u�\� ��7n5�o�'% |xtQ~3�u��}��E������7�[�y��'�@�\���q��B����x�V�-`0T@V������dI�~�LV��
�1�+����#��xD(
�$�Y19�s���$��L����Ux� �}$�h�@M�N^��ZS!Ђ�����C��fPp�Hk��D^D��l:0�HVZ�ַo�l�,E�|d�9S������zCD}uT�8�J�H�P�D��[�v�x k��[��)�#h	~9�q�R��UN��
��bN��l$#U�*��ٌ�`X��UZ(�/���	8�׀|k��_�v�n�CM�l-	�)a���V[Q)S������/�Ql!�t����]�*��W{�o�F�\{(%*�	��C(_$�Y7��	]%��tf�'i��o�À2־X�a l���p�����I@Tb5K��C�ۅ�K���GA4�{ ���9�I/�Q�\���V�\�R��mm���^��NH5�>� �$�����k5h�r^+GX�@�/��U[�ƭq����QȍP�kk5�����_X`kP�@X����K��K�A¦@QB��8n���
@ gC�3S���<��P�W]�����ZQ/_#�?H��{ ���+N�������
�:]	 Vz��E
�KU�L	Q@=�Y�|�(��5e0T��K[�F
	�W}�lFP!� ��-n}	XBY/��,��	Vrtp����x:�?�[�ȁ�$CW�v\~:��K���ꃏ��i\�m����yI��t��у�L�7��B?�oZ�,��_4 q�����LZlF4L�|_�8/uB�������;XXE�X �G�</���t������p3E�Q�	~-n��t
u��ɀ}�/�m�uT��<EluG���P�{M5�RwJP�Fi/p��jr�![�Y�]^߸Q�'�Q�NW] �p���tT��ڔQ,���u=]�	
��mS�	t	Rh��Z\ű�T����x0Q}
L=�������D=���[���H6\ve�(�����Y6�@Q0�%���o��l�Ӄ�l��m��� /@�M4��SO~��x����YGvTmdb1�pf���/^QF
6^���~~R����m�V�$yd�=�7����Z 
�
&��x"dx���_:v���`G��i��� ^��
���=�����,A8��d
������n�ڃz��!s�y�%���	�����E7S�i�q	`,}����D��#y�c�$����K(@�fX�K��A������J���c(�[Z��������ӥ����o��Z�7�N<x,y^xSV��K��z:t����!�)�	Il@S		-���s���l	���
p݅\�M������>O�"b��Ki�PrS���$u"� Y'piʫ���pq���P ����T��w�P�_}�����!�.�xQ�|�!G*���==�|�W������_M/1�"�3|�j^��H=���i�xd�LB0��u&���DCO�����/��M�O �H7��Ix_B6�u�Ɖ-Ǹzu;!M$�P[KT������b����`!�!iuKj\�Q�����h�����M	��P(U���o-��ң��ǣ�}e����f��RI�����Fhs^��eAp�Dǥ3�r �<W�����9Yos�
X�Rp�B�RtQ�B5���5�7���\�0��P.`���x!/0�Ex+���t�7O�Ý������y	�4��yT���o���q�������.\R��9*�B���^�\��\��D"F��ڶ�%�[P�g{������Չ�	yS+5!�3�UX��QP,IK\L�x�� hF��G]��Q�]�o�LV�jZY'64��o�YP��V�I��u_�����N
VR��^mx@ ��Q�Kk��Å���� CcXci��E:�#�!�^M~m|����9H�5�d��7����ߒ U)G��#&�>�w�����e��9Ge�X�*lR�i��@_F��_�%�k�� �UDDDK��B ��poV���(��i{�D�ί��jT�x=gF����/J��"~*^NM��HE6j����KY�|2,]N�_�B�:׋(y�S)��^sMH�;Ps_��q�[�L! ��N#v�4��*��0��m���F��f
�7,V���w�lkT+�B/[
N���G�U�|�MH�.�D2oD��F�A��)I���<pJN��!�1gs��.Q�B$};4$w\T��n�{4)Ѱ��;Cn�7����8��G@�jT���+.��Ev|�Z��V��o��*Z���PB\�)����V/uү�*h>]Q����!���v`���V��rRPh�{#=}}�U�o_/�`?SEF\�h�-6T��GWo���)N1�D���Z�ԷKQ_n$Q3cQ�p��X¥cD΋W�Z����?�t`�<J��^V���t)��L�f��k�Kf/o��F]^F !
++!*<�l��F$W�F,H ��/�0h4F("X��LLI-����&�?� M�G��%�1��o��|!�$9~��g��O��($�\�MG+*Bz���E�!�'+Qi%+1]��6����L6���[�fEd���H�j:+�qw3"�'�G��VK��OQ��-�ݱQ��%d�oк�r�Z�� {���jp;i�\�{�m ���VY-ւ&]>�"7n��9�$07Yzr�"8�j B�_�jnn� !�1DNf�����8S�1Z�r'����uhuN@h�bA;E2S�J-�0S��[h���T�j�:Xn&�e!OAKm+���K�
	
yA
����/�������S"�5(bl#M7�/��=�X7���f�P���$�w
fǄ⩿�j���KB�Hl'��|�H+EM�`F};F2�}����XmCSPG��Bkt�FP����ƋKZ@G^Jh}��wD�WCe\�Lx>;�\z�/��2���*j9�w�-��8L��J�,X���U�!dGX8���������C��8�
��/CQ��g��_�����,0`����1mM @p/�ݢt� M!�����߀p����� Y��h]�c��3WE7x��șO�-�X	��	M���B�	(�`,!A<�
h8E�U��m�k�B�dP�����TE�c�*CH	�����#�"�j_T$U*S��Q�.��QI!�M�H]�{m���&r�	�K4�nU�a�W�rK-��x
b�?��(-QQ�"�$)a�Z�L�]���\^sY7��^�"IS\E5��uJ�KKz8�<�7��K�Iq������ t���o�-kDp������-�^�aWgf`dZ��[6�BT���o��o �<<߾C;W8��J��@"�5���]��o��!�J)�?��	'�'���%���,�n-}�EU�/}��xI9&U[]-����^-
G����A��h�KE�
rATP:
ѠU�UP�f���ߦ�p<ZH�rLb'4/�+��[�$�j^,�7Z���TUGB!�.)w.z�W!���u0Dw��QS9@1�������U=HA�OѨ@��l7X�!�5�I����h���R���^�����p	�uWT�o��m:Q#$,����n�o���^YL�֌�)��'��/�Q�Ddr5w"y6@A�+n}���L�]@~��sm�DQT��^x�ojd��t6U`A/E+jP�� d+\ ���x�_�]X�
�ld������
z)M,L\�y�뿴�@�v!X`	9l$ޢ�Xw9�rRQ�$
KJ5����cѯ�K�o�
M�p?�&"�9�/���Z4Pj�����i��V��9KP���wr@�ݷ��r�=�L��q_0P��oj��ZP�aQ"�Ml R�/�f+�� Y[P��T�_��'�,�D��kܢ��ǉU��M�#J�����,L������C���)��/�:��E��EВE�{�� ���%T�J}��R�D���Z�f��HH�o��dJѷB����8��x��~�K��E��e	�uY��ݍ� ��]M�Q�7h�A��U��D��P�htW�o$�4G�x~���-~�̨�J��"| !�����=p�	��9�	�����FE�	�-����8��U��,�M������wl-�ߺ��at�ak�LصX�[����\ۭ�����Qö�P�ص���RVS���U�<\��@1@�t��ſFJ�(I=4W��_ J0!9_U��t��.
���]r�Ԝ7����t�P�~k�R�ض��Y�8|���U� �;UY�X
��o[di�;M�C�/���	J�F�!���Z��FSƷ�zPX���N,9XuL�����tq����S7����+h:n/3t��7.�e�YH�&�4�6zP�g�6 ����"�.��{�[���~Q�PO����/�|VR�o9�u3BC}��(�� 
FR�Q��w�ܶ�Z�9j�z[��[ "u	@Xl*���7��XǁWP$J"�2!I"FWm�@�J���"tN����K
�Pi�X��[����xK\�U��&:6��o�@o!1$&! �#@ӿ�x�IuqfAl����
���I����ۗ�Mp���/�V�,ԍ!Y?�bV�`H����F@$B#�'3�ixm�rb�A�V�н���jZv��B�T����m�җ�ڈ	�#x��$���K6zǊ!Rm�� �PvǍ7����F����-�ju�%���%}�_�o�{e�TAV�^	+]�x	��K7֋kŉn)����x-:t~1�m���i�B�
�]�H
(��4�aKեjP�o2[�
�pKd{"(<��x����~%'A`_���-�G.,^�a�����
�!@H" (#*4�8,� ��7W,� F��j�KoQ�rw���v������O&!x�F56�ė^�7!h%S)����tى�Ļ�R\K &�
��IND�(��XtFILE� ZK�V�Pf�n��I��z���T:�If92u;U��R0:L�
����u�(�X@T�DTC�ih	�EU7
��0�"�c����[�h�W���p_�m)�lP�B �%�@K��U�i;�%�R��Q4�r�����/q��Znr"�% ��/��*$-�"x�*�#+!�)!�-wM��0U�4��GlAe��( ��`����82<Im �L�Q^Z8PZD��.��"E�4#8J�����.���S��Y!y1�mL�f=�tR
��΁} �,d����
6�2t���B%?!�u��oP�#,	1J��!�o1[���oZ+Y0��#�/�<%�5�7jw�E�-z�O�K�o4�-qe/0K4�SZ�x���@)�%<U6�U2l"�'����\9J4c�to�6k�&�,�[-�[�a�Gv���nܾ��6GlXpe6  q����d^�6&�#�64.�76�V�m6(4@*����D0�6��-��,�6dX�8���.T����*xi5��5#8#�5�;��o�(3�,�504Q18�5��6�'̭��PG0�5<('NƉ}����KX��tS�A�</�/�-8�		t��N�����!�T�!�" ��G�É���w���tQ����F��?�MDg��t�X�ќ!�'��Ӊ�@�omA�t�@_;�\���:"RH�mD�~s�"?#���m\�/\��y�T���l"�.��O0(Ѫ��&7�p-J_6���A6�2+T���mPrJ����/u�W8����ݑ!�)��v��%�o��d,�>M}��_pQ$� �If�J�`���-��z�!LYGZmt��S�N��oW�c1��!�Y�p
�jk׭"�G)ǟ��@�ݐ�@>�@g�W�<���\��{A��֫a�r|�"��v�T�[OP׸zik�=�0W���/Qڗ"�3�Ƅg6���m����Ȁ�D��.!r]��$����J!��Q�-[���!�(5fL�Um����&�w�x"A#�W^�tz[���
ܕ�v���'�!�������9(�+�hQN K��e=p%@{�h�.QU�R�ۉ-.\�,�!g�-,��~�q0p:,c��-���"�+_F����va,��R��6��ticIS��[�z�i7A&!JK���M��
��{�F;����E�r�A�1A�JA.+m/K,�	U�$���܋��[�B���E�p�/�B�S�I%.�,	-�_�/��	I���䌔
E�P�7ha��M�QR썌�|���ZJ������$�Kw�f�J����b�?��hu�J(Z�h[�oy��LO�0�cO�A������'�WB\�Ir�Q�.�;���m�)� J	v6��|�H��z$I4uD��gI7��_%�	�@Mb3��|/r/Ap/�����W�G�e�8s�1`/,|���)oq3�e-�g
���PbfHP�BfL̌�f;���/\�r�*�4��s���zVV�߻���x�#�_�f[%����Km��u��zX�r#�\D�����B�|+�wC��S'Qur����9 ��eB��m{�;��cp����A
�A��.��Z۠��w���@ �}�[�h�>S&!:�9@%*�����2"�%"4B$9F4��8�umQ�4h�#�}�E�H~n�`>�G�X�u"2lp{�?�maL��R��� *,�)E$��
 U<c���/m�!��C
R�ј�!
_��P�/�P�Ę-CH�F�x���(S����!��V�� Qh���0u4�v���^��$���N
�C�E�����`�{Y�!��@�\!�]��}C	�J���-Y�'ؘN�+5�#<dQ pV����o�#�E�4$!M"J�R`ޝ@#�[��B��ꄧa;zQ0@�wmDT�_������YO��6ne�C �z(�Q�ߋ r}j�-U} %��}X�`����#� A��u%A�"�s$E �R�o_h�q
Q!�EZ#�قW�!_��:��B�"�5�Ɏ������$�]$�'"8v_���4�aX!n���e������/&UEl!HA!�aE�;|P/4.����}�B!tz���nnM�(�	�L��u�o��~����*����̋�0HL��V��U���;}����7��n�!i#W!Og�@��y��^�֚�M0����7J��/����T����7�J�������q�p���(1���c�X��&� Ly�(yw�/�/mc�	5�)-�2'D\II!�[}�l��Gn߂`ߞ��mt�q�#"N����%xG$ڷZ�T�.&�E*��۷}��Ǵ}��O��	������!aG�X"!}DD��-���%��߶�-����W%�Go����\�-�Glo��Hڶ���Uց8��
����d�/�[� �U�z��eQ�R���LB�<� +�/@["�%u����'�I��<uh�<���.0.	�!�@_&~I}����U�J^�!� F��/�f�6Y�7|���Z�Ch��DR���nT�xk�K랫���l��h�zr� �j+Z��[��Be9���]^�������!41%$u.�T��"o�o���r7#gC��DXS��o�Y�A�
 �p�x\�i��R_��m4���(
P�Ћ"�/�ΈJ5�^ 
6���F}�!'�@	b"&j��Z��\y��~,��o �UE��?�#�Y�[ (��['E�B���������8�H<�P(�H,�K��[%P��x�������v'��yc8T��sX�V"9�]�g��<����)M���tgJ�`�orV���3Wx���!��t ����V�lu��o�w�.�[V����
d�_*qz!b�:�.R,k]~^��ŷ�&Jy�L}A:%c/�b�!��/�xB�B�"o�@/�7J/��:/�j���R�xN�~zZ��� �� w�.Q��9�t�y�)�n2�te����j��lH���%7x����!��!��B;��w_o-�����&�iD�ED�!Qc0M�,T(�=�4��P��n��������[�Ɯ�xa�_�%J!�@� p�}�^co�v�
u�1���9���F�7�d&�eS?kX²����R9�wr�w����K���su�	�#�8'^�!E���!����U�E�P�5���h1���oc ����+#;x�B���!��E��b)̾�n��n�t\C��J���lXf6j] 0 +5AA�ҥ�Qt��߶�o$W�sm{+��A����	�����,�aM�������!k�H	�wGr@9�wA.�5����t�8o���w5�zr.�	HOB����R3��I$��$ɉ�k<��o��,�:@&^]�����0m�F#�I�#�hG�W\Ya��o�8]�Y
��!mt"آ������G�lU$���	&Hav�t3Bx���o�	Q@N��!����SQ����7r	�pm¦#� ߡ��+$��+��À6A5/��D��	b誸  �i�ll#|ѿ�6�H�x=�K�����R+�3ٟ?�0��?�[��Fj~��dR�vFt�7�CyPv)@��~���޸�f~ �NHH���� 9ȋ5b����
�)
���z��
I�(E�#5�\!~���V�"q�D!�+H3���@��#�x�] &�m��(!3K�xM+ �ǃ5A�_"(���/�D�]R���Q]*� st�O6Y�]]��o�Z�;$tkr;@��]�j7:�/`e*}B)	|��/�1C��R!�q�{$h�F$���)Y3K_��\1�����h����$,Y�X��_H�&У_��NJ�#��`e'\y��_b����H�@2]�|�C�n���7{{F(j$RP&LM	,e���*��$�x�e�D��/O�$����T�n\�F��?t�$ D��ۿ�RÅ`h�M@��HF����RX�~A �y ��~+��X��Wd;D�~H���K��)a�k2$v�L�����U���#y.�#T�]X��q` �����\Q\s>��O�]
Dk�R�@hT��ߺ�k,2)d^�x *���Y!�(��h��[���l	󤍕�d�*�p��]�VWV���^��� �|%��(�h�7��s؁�`@)=���M�Co)���k�O�	,�\!!��$�5���/�U�(l#�\�8Ľ���\�]����LF3V��P��"j2ę�K��Y�|NY[#)4][v�Z��iG�IM�ɿ��� �ʡC�l*�Q�$�s�$ީ��.$���J��$�x�M%j�f����T�L�#�ZT h�u�!��*#�z�/�����z"�$���L�ںT�y�Dh�N������;$$�zU)$��T|"Hǈi�X��-��`-�;GT��$2t V፾�WL�_Z"ۛE���2g�y@�d�D�$�q`F9�}���Յ��6\3[t^_0$���K��~h#��||�@I5Q�K�6�o|���u���-�D�\�4�A� A��BX���^5XZQ���&��o��xBH�!�%A�E>��>�r�B�p�cT!�<}4��ֿ��_��!��"�U��,7�nFY_��o�3X/i�i9��uj;����o�aY8��N���uQ��r�x�CBn`�^͜"Ŕ�xQ-�&�AV��~�
S޷lF�.%^l���a��(+�׀��i�T��b�։�@bdM�|�)�b��ߝ��`\$]\H!j<S��#.�x����[`#�܅#M���OUѠ^���J��$K@\��ip	.
�A)~�0� !��#B[�������o�� 'ml5�PX^s���s2�U5]"���E0;Y��l�{g�jul�Uh�����zL�@rl�	���L���Z�S�.�m���)�|�1��X�u�K�X	O������6D	]&M�L����2�'������3� ��FHM�@3.�	�JN�����Km�1���^������uTdGU��$Y2\�@+�=�c ޅ����*z 2��Ǡa�/+e1��u��W&�{aFY^P����a���A�TcLe�	���D1�-�d$P�����d����`�	�T5Z��3��P�%"����=,.ve�>���#�,�������4�+X+�d���QnUY �z6�{6/��_ɸ�ID5|M �1!����m4"#˭�|���$qg�V9h�n�o���ZO��A����ZF��|�[���6%�èЏ��\����Y�G�=TR�w
�=P@�����vh�m��Z���"�(�@o, �%�)����]�B��e��V[�����"${�qNZE�Q? !���� �+�fu�?(�jtټ �;'���7��T|$��颴M,���%���,����������������'�M���`<R9��8j�������8K2�0� d�}�u�*�#X��n|�	p:�@X�6蜗���In$���Xz��a-'�o���TW#9�PHV38H/�W_���<�,�E<�z<1��%���z�'L�k�� @E�,Jz�	��[[�;5&��t0��p��olLQ�3����M�&t@"V=*SqK/-���c9�A��g`=�%.�`9���`��/dM�!jbui!JR�M�D�_�Z-Ao8l����o�5/Z ���x�!��Yr+�!dv�U29�v .���o���S��#,UQ�Y%t&GX�F��M��(����r5$%��!2;ʾ�ڷ���������ځ�x;��1�Nu쉳�A��~gu�$�#<#"������	jg0C�]�o���AP(��m���O)�N<F���%h�t�X|Jf�Q��"�^��}@.
�х�/� �@0����/�o�~$���&�,!%m�)}���_�$E�H4&�K<78%������ a��AU�vhe;�]�$ڱ��O&�'lF��o1j���#hH 	 q\їj�`i�U ^�m/����"�H�e�7�O�w�]�H�/o��F#0{D����R�1�����,����u�!��o]�(�lŦ�
������"dĆ�H@<"FU4!�it�@�{� S� gEc�㷺�s9���Pap�"i����A\G"ĆƟt��[��[�E!B�2dF4%J|����"������oo����!K���y�H%O#A�/����u�"��UD�!�l�$���_�*u &��%|"�I,��!7R$����K�N �}y#��^>K(j���p"�%,vc�������]XKR9!���SNXGB¿T�s�Q�	-�/ŧo����;w-;\+r'w�-��;�r+[B0� �x�շ�p��~X1���� �F�r�K$ne�d����[	sE%U>��r�P�d�/Ԣp0����E[��F���Z_��2FT�,��!�6Gc�C)��o�VTE;ltr�kai�z��+|��w��
�>
O���Q}.+��$CЄ.]!�K��_M�T ��;���V�wr9 sB�����HO5s;E��!��j+����!]���H�K,���؉�"b"�^
�!ʋH�����tt1�T��������G<�Y6V���.C	�Ess!D�C��loѣ���$�����D�
~��N=S
�
�����*�_��x�O��hz���_,�#�N�8@TPl�G8sCx���X�@�'� 4�X���񋣗^���	�x�����"���e:�mK�r�#�NV_F�/!�����#P���IYP!q�Ti�wL=/�#���V##^������Yt�)���q�!ͥ S��_������%l;A�+!�X�����[����#��"�SR<�b�dV"�Ka��$D?�@��M*V|��?<7(�Zk� �P[���!�L��C|8\F�OQO8F/��7pXK�3[���� �y6iI"�&�,B� x���%�|)z

�����^�9�� u	���m����`nK��[4}����P�/�L�,��B��V
��
�u�l!l"�oT��"wtH={�c������r ��!6#�$�#�/���tA/~!-*:G��u)��)�ߨ�E%��� t�x�M]Lt�Ɋ�`m\�
B@�[���u��)�.B#Pv)oo[+/
�5)�߂��~�i{9b\�}:�H�q��an_ |%!�'>N��(��P��#G��у���_�VX�XJb	�tw�kH�� ���X��6M���֍���R}A|��_#��߽	�u�"1>B�A"�P�|�	�܆U
$����x�!ق�]σ '<>|g��%�t��HS#f��V[�P.��p?!|�_��8'4@
P�D9\�mr`!])�dX�����f��)�� ��"(���@��xk��gC�%!��!��
��R�!��#�"6(%�ޝT,pa��)��Y384f�x�/�MT3	vHU.uMƄ����m K3~�7�׭6�L\�mt���^���_L�)� ��Wg����q���I�"�P,����-��UKt3EЁ4d[}p �_*�W���i/	\	
��B;<It�jW��p�:T�7��gxM�Jt+��^u������� R!'֗b޹����(�#IF�8I���g[��px'�J����U_�u�%d�YE���ƿ�	�8J ��t-)f;�-nr�^�t
��VsS��>؀9B��I�
J28�u@H`F���x!r�>�+$�N��������eq�Xb{(�#�;t��`t��)AcCc��������|b$NdI�#��b����	�P{���}
�]mWǋW+"x�v���!8_�y6�P`�h��Oʉ=�[�F�u4�z�"p�o��gM$���L [kJ��D,}ả!�K��x{+,�LOD�I	|ى�Z���� ��uE�o�-6�������<S����������zjH�Hi�jz�V��jMo6��K�҃[����T"NK�E������Doz�y���7��q R���I-H�����|�Y���vI��ZE#Z~w���V��q(��G!</X��!�JE��UD/�GA1&QU�$�����(ďJ�8v�+�'r�*w�}Z�<z��C���.p6L"�<T��+���F�^�"y"8h}y&H'F�[�W�&�s"PS�(�?z�[�&<dx-�z�E	�ҭ�����&)ً�o�(� #4���|��q�,~ B/�a@�Z�lA~nxk%�����J�5SKFV(�^�V,e-��oT�����H["�����+Z(=�\�w	�ֺ��_����/�bO@f�Zc!��x �B͖@�t`��o�o\����e3N���@���D��/��T��7c��(B�%���7���<&��Lml@��P��ºt/��FepǓlgB��E ����%}|,#xȉ�v�Z��\���+(���	�Z/(f�PS�Ű"M<8�����[�u
�n���W��%;)�X[�7� �$ �!kS���C�������R�W'��[�`'%�KQ}YgG\�Y� ����(!�Dh��#Hw%s�{$\5|I7~�%C�pC"l�NT%�Ko��bC!����
D";4o����Sr	9C�����(�T&b��[�I�"�\�,&噱X�I�Y������	�y^x��+%"��մ�Zm�)��l�o����[��q#��
�[��ǅ�Z��?������wY;��;�ԍ��K�`^#uf"1�v%?���-�\��J9�(íU��G˗*��9���k�W����w t�ؓ��c���F5��#JE�_� U] D>Y��POr��^�@	��|E��y!���f�o�Gt��T8ev��߸hD72�϶0G�\��@\�[���
�XdOu���j����"����\�$B�MD���EL"K_���0M lqp�lPR���|�lPhUJ�l�A0 ��%��O��u�	Ƿ/��A�������J�����)��&K���Z�i��	ޱ��ֿ�+b��O]�o>�$�$�NܽPt���FS�P�FIq�b!��,7���B]F��F���L�Й���[�$h�,�X�K/q�8�O#3U��+�����	�M#�l�lҶ,����|0�E�'�iP��Й�@��h��o�*
H
R��Iި�71	a@�'�q�I����O!6�d=^92p�h���
NW�P�#P3f�Rn!5Tv =���[![Id���(�J�GJ�$�g8_E�B�t%Y!X������zQO8�������z,BA  j�PUIܔ�?�+�[�C SЋ{i���Hň_��Y$�$�>LeH�
9�b�C(�Oݨ��{�x�U��GS�[�f�jTh��g�Q��_|'�\�SqS��S+
��n���o�4�
��YTعT4yT�K�B31�����4�H��/��V#T�LyP�qj�(D�_^N����|mT������(�_QA�}��\!t1��K��tŉ�V*fX�]�i;�����ZOo�	|([_L��!:�Λ�PH�wJ,��TF����ƍ!��"�A40�4���,����u3!@�H��+�vAf��_GH�UNF�D�/��Q0���Mpy_U���F%'�DvE� bNǋ/\�y J���n�ٚ<(+��7b4�`Q6)mY�����B�Iw��JV)�����	G4�z�d_#�v+\K�T��څ�u�q��/����`�\��?�D��Bh�~��������h/-@~&D���H����@pA<B���o�r=dys$=c'�X���/�fU����ZRhOw����3uOx�Lx�{V\�G6���a]�"��Q��z�_�����F���G0ߥ�u��d�U��n�n� �_���#�-�-.�Sa�E
�[�W(��C���#���m������+L)��_��H�/�K���N�<�#DAH���������q+p P.�@�K���M�L{9�|�`[W�/�7�`l���@���dh|���!¦�Vx\L9KKQ�E���j�[�@[�^K��B伥���`@!��C� X�s^�����i@Cf��c�9ph
ډF�-n�w�G#EPA�o�/��:#�!ݘٟrw������"�N "u����?@�B�ǒ���K��P�HVJ��9�Eo����i*�P���+(@S�o�DKs{8�sH#�L�x�7�
�DW0��!A{@kD�5(�)�^��m��7D"��S<<����w!����[��"�y8�qJT[ύSHa��ko�{Tj��9�C���_藋s@�vT��Jq��8Q*T�;s�KDV����댙!&��x�G�[��R�T��P@t���("L-8
)` �'��XhQgX�9�u9Zu��o��DP��iL2L����[o7D��CQ%���_���('al�������oDVR��@&��V��o��o�_�C�s8��#���)sD��)�tW���;��[��Ԙ$�2Q��TH�@}����@|Nb�0�[-ZV����É��7��5 #��9<�uC�z�ت����+[��7��}U�#V�������}��{*2���s�)hU�M���.}�]�KP]�M���o4���V
��A�M�]�Q
�B"IV���ߪm�NQ`�M�9�Qx�7�F9AU��k�q��r�W�J��-�� u��)ʗZb[ψ���-�#�/�Z�'��V�?_��2��r ׃����Xf���u\�x �ե4tJ�@�o�U�1��C!9�rB;_��|�J@5(k�@D�v5��^���RLU���"�4hZl�d	[�ݠL���_WX�	�rA9�|�������Ah�}��!��^��&k�ZG+��6S�h"����f����Q ��?1��ӄe���)��E�0���-�����d�{�}� o����!�gw�l�)ӍD�Xk*��P��m������:5�����������#X�#L���89�s���X��"�*
��jSQD�&"^
(]�k�+u�}�V�f�"�
�CiYo/�d )��Պ&i��Q
:��O���#�����%�,��X�X���0h�%J-J���M"إ��.��[�90U_v�W�H��CLz�� "�k2,EH�/��Hܢ�#	��B�kL�K���!F�#|\]�CT��P���g��4X#�F���#@�(0."���mC��:�;��Ro��^2#�Cy/���%�	�OtS|Sh�^�^�/� @�$P��"hMo�o��A��<@t5���.6�ۥaȌlʸ�U�@�[��*�*0K@u��q ��K܋7R|�XJ!���/�t�E>f���#�A,��Ul��4VWP#�߀8!S�]?�	�w��.��_>WS^��	bL)�������}����b�FTj���X��_��*1��!�	<0},2V���)�uE��I5��/)����E�:���1o�
0���U"���rV ���ߊ�A�~�^�+�����d(�`G\@s�%�2U��[��G\�!.�^c"+x��/�ruTXN׋h!迡��XV[����6p%����q-��"��Z[a-d��TE�TAF0���xxz��&��,(���fݔ� ����YB'ť/�!9ALi�������(����<	�#�/�m��U|D�AB��^����d� ��x��@���x������O���\g����� ����D6����n��	w_
Z��� S#�h�MX\�%�<*u"|�M!�ߛT�A�/��`S闁�-^I�d^�v�q.y��[�v){�R�z+yE�m"m��A�\߈$DYp1` lt/-�:<ht:j�L��ѷd�ez�| �b��u+�h$��%��#gK��ZVm��}��Az��#S��~��_ ~y��4+W��<n�T>��)<cM�X9<�R<X���-�5X�]kth<i$@�����^<s&�`<ot<p'<��/�u$1<x<�J
�&���"e��V'� �2��o�!p�B,��(������n!�-	�N�cJ�K�V�{�t�Uu �F��v�����B	�N�ͫ�� �}�td�������%/q��G		Ѝ.TzZ��	'%�
�&�$^e��s�7�����$���XRH,j��`�/�[Dt�������K�\���W�F����D
$(T'\�,�K/�ƾ"�f����ƍ_�"GX��'�yJ-YYD/�n\ �=�u�]� �%��!m6t�N���o�� @�`�1}#�m�?��ۿ���|&�bz	�t�$���X�D$<
�!�"�������<wH��O<�"�nV7��4 O�(@kY����A���TyFU��_�f؃�q	8A^*~���o�n%?�(s!X�!P!�#[Y�$X!���j�$��@F�e PRK���Z�D,� ��D׿�P���Xs0-�*yW[��(/Xw�t'�/�K�H-�p�:*a ��3X��V�,�,sQD#-O�m�vJX]�,Xd+`��_�~2J8?�T}n(D�]�01,moo=�J+�8%�`%�m��Kf"YC,I
X$��!�Q逭!�����&�,M 4L m5$S4sQ,�~��_}	J`
39"�\l�H�H�ҷ�R�ZYGLrr^�+|�[��ntYq�-��H�uB�������,O BU*8z�����rg��mBP�~F�u�A8"��y�t#��"a��[�Qc|�lV3T$c��uQ`	��V���N	������I��;V�~_(�za��t"���Pc=�I��oQ�%�w�0"x5\�����R"��;"s�BGm��N9��#`]=�)�@�[I돘v��$Y�-u�7A��\����.�R�FY�B�B��_sn�����F�x$95N\X@' F@���J9��E�.<��@(�)A�/|�E
!�Z�H(����� �+q��wf�M�E�����݆�'v��[�)0\#/u�/�x$p����|�6*���� %�DC��zlV7�V�������o���$H��OE�M��$�[��	c�/]��/�0%uETxƫ��7��h���d&^,WVo$ğ��m/�g�Y��𒙡���Y2���mgT�����M�eM�"�l�(��oQ�$4�_q�'�^ZQR!��ѷG���b�Z[��6��"�7'� 6\!8��KT��7�h?������ì!�( H��7"9;���	��CJ	�t�E����$��" ��������C͍tk�nN���ड��v��y5��U{U��$*e���}�ht+��=�n"�!�6�"�$;}ܿжoe�w)&�U���e��������֋D\a���vC5q�!�>� Dh�!�b^����Ŀe�;���Q����H U�'
-���Ƃ0�g�N �k$Բ�G!3�K���p � ΁P!d�Y���n$��+�������s����?Xc��.�0�����^�7���!�n5���o]������l#�O �d0|6">"v���n/4n}����.<x.�M#H?Mw�A� r24��J�� &� 2ld"�8�m��6@M,Nq��8 �L<�LFP,���	C Գ�X��|6���,N�/�� !"9%&'a�� �*+,-./�3456789:;</El�=>?@C�GHI7�JKLMNOP:STX{�`�Yv\d`8|d_��s{|}~���A�A��E I�����o���O�OUUY�������AI�����������������������������������������������F���������������������������~�Q�����������-�������������  ��abcdefghc���ijklmnopqrstuvwxyz���_���x���������������������������������������� ���?�}�1\*�Y��M4M����L]_	M]O^��5j,Ar�oU��X 	5 ��� ��   آ@!f # ��Ѕ%� '� ) * +�oQ| - .�0 1� ��p�3� 5�7 8 : ����;O|= y�!,����mA B C�l F G H I J K�F� �UPhЪ� �R����7
V W �Y@[7��� \ �_ ` �b K�(�c d e f�i��n�k �m n o p q�Z��l� t \�w�E�7� y /v/���~} ~ � � � � � � � ����A�� � � |� � � � ���� � � � � � �> � ��K�Kˣ � � ��+ � � �Z���� �����#� � � � � � �%�%�%%����a%b%V%U%c%Q%W%]%\%[%%%4%,%�-P�%�^%_%Z%T%i�/��%f�%ql%g%h%d%e%Y����%X%R%S%k%j%%%�%�%�%�%�%�� ��R�-ԣ�������]���"�)�"�"d�o�#!#�]"��"���V�" � �%� � ��68*(��W9��M=�T=�R�
� ��3��� �MB�MC�>�5� ۭ�.��L�@؈��R'?�� � �U?� T߾�oF�_?��T?
������������� ���N���[hE��^�� �(,��6n���,"��T)����L����h�(��O�p��NoF�XYa�
ZO78-�%j�(��
kQ�-�ext2_V��mr)p_Rscb�_���k��>= �s_cH-P��*o7�� W,,�W�Ssb���_ipvstructeE|KD�can'���6�C
�e��r
so��ED �
err#it'����s�H��.�F_2/3'*Q��`(x��5YibS� .[k�X��e�a����_pnɂEML�-�`���~�"�[cheO_�����FTMc	d'�i�_r�[�)LNTFS  QSWIN��[��1�tfs1ut8_o��O*2�]W�?! �5�$�_ALLOCATݷK�mN�s|%Olly~s�n���.,$|de�s�h�@Q/�ą���Id�*��l�ECrrt<`�. A_�p�x	lokx..L���c&�7td7(lT��oAl	)t*�oq���oe�+'A
cNd g)ǭп�����_�-_�C���k6��[	b��P��Volum��_h]�+�5tv��0'Y�����}Elu�y"XH��[�F�b
<t/��to~nyK_��`kJQ�MTb�s����CrXT	@2�/�V!'��7Zx���pa��``�*P�|PB �������pY<s9�nBKubL'}
w	�m�o�U):�DPNo��gBTC�vic��[��_B�fS_M��ܺ��1�
vZ�w�i4gd�7\F1�5%04�����s�cA� (����%u/��lDD9� 
��,�'lf*<
���'6thPu���c�o/��h(C7).i./-��Y�!�1+v(�/8�=�s� ���@B��n#����\��}� (�5�Eﾅt5'�(��i�7Fool�*�p_�oaoUg��c{��� `c���(�:��?��a� �W       �         �       H �   H     m���GCC: (Gentoo 4.5.3-r2 p1	,��n�ie-0.7)  .shstrtas�۷b	inittexfm��}rodaeh_frame	c��d�Trsdjcr"{���)el-got.plX��=bs*comm�  �4�'Ԁ�2Ȁ4.�4��<���A,C,����O'P2�%�P�#%Jn�g�wD ��/'dd�f@�6lf@��l=t@�tBd i�xxO��i��hi�iT��.l ]w � �8ݕ\,�c'��|��5�I'	_��O0'-�f��s'Y  �q�      ��    UPX!        � �g  �ZXY�`�T$ ��   `�t$$�|$,����������F�G�u����ۊr�   �u�������s�u	�����s�1Ƀ�r���F���tv���u�������u������u A�u�������s�u	�����s���� ������/����v�B�GIu��^�����������w���H����T$$T$(9�tH+|$,�T$0�:�D$aÉ��1���<�r
<�w��t,�<w"8u�f������)�����������؃��a�QPR�
 $Info: This file is packed with the UPX executable packer http://upx.sf.net $
 $Id: UPX 3.07 Copyright (C) 1996-2010 the UPX Team. All Rights Reserved. $
 jZ�   PROT_EXEC|PROT_WRITE failed.
Yj[jX̀�jX̀^�E��8)���@H�  % ���jP1�j�j2�jQP��jZX̀;���������P��PQR�P��D$V�Ճ�,�]����=  \  I
 ۷��WS)ɺx  ���)��	 �Y�ww����)��$ą�u��"��� ��o =�3� �N�/proc/sm���elf/exe [jUX̀��x�^@�o�� 
S�SH���
�� ���R)�f�����{u�P���G��H���T$`G�d���o��$Y[��@Z���PO6<��?��u�PP)ٰ[�'��w�ogu����	W�� s�����[u����@�H����_�S�\$jZ۷��[� WV��S��9��s
j�k��7����t�G�B��s)3�9��{U��/�Ӄ�E3}{����E܃: ��GU�������m� �M���UPX!u�>)��M��_um9�w�;�oo�w�s_E���u�P�wQ�}w��v�Ub�GϋU�;cuǊE�������t"��t�� �w9u��P�۶�E�PR9��4��F��<���
��U���v)�R��A�e��������t�u	9t����1���[�mg�S�D������o���]U����[������M��x�J,�]���������w�����1�W"Jx�;f����9�s��S9��� ���>�*)���8:�[��Gj j�PSV�8����ډ�y-)��E�  y��y, ����i�L}����� t ��qu-̺&����K�����%����8��HL�@bQs��������Z�m�O�B���Ճe�|�֡�ǍK�o�4[�x�)׋A�J��^p|yP?���P=�m/`����2���V���FPW�_���v��9ǌ� ��+/�76��u�7��j��u��n*XZ����!�%/a�y�t9�7t���@����gcCx�uV�@tEP�XQ:���M�;Pu����%:��[���k�4�z��Lu��7.@=�a�t���ۆ@1����Ƈ����4[���j}t�����o��;s�j2���o��)�S�o��Z�e쭱ʩb���7
�j[F���QA,�=v��� 9
�#/��ˈT�	�j-.�5\����aZ�<�I�����6���}��u�ll�W4zC ?�n�p�bE eV����n������O, 7�:���]$��*�]����*]�h(��mso�4�R����P_���^���	4����lU��wf�d�p_fi~O���v,3jL1��I^oE��jj�x�@xݷÉ�j=�s���ur�(ox�{��j�/M�p���{��j2B��i`�����|�5�      � �  UPX!�;��.�   H  L� I
 �                                                                                                                                                                                                                                                                                                                           ./.porteus_installer/installer.com                                                                  0000777 0000000 0000000 00000021315 12230756674 016267  0                                                                                                    ustar   root                            root                                                                                                                                                                                                                   #!/bin/bash
# Porteus installation script by fanthom.

function check(){
if [ ! `which $1` ]; then echo "$1" >> /tmp/.sanity; fi
}

check grep
check sed
check sfdisk

## Failed sanity check
if [ -f /tmp/.sanity ]; then
	clear
	echo "The following utilities are required and missing from your system:"
	echo
	cat /tmp/.sanity
	echo
	echo "Please install necessary packages and run the installer again."
	rm /tmp/.sanity
	sleep 1
	rm -rf $bin 2>/dev/null
	exit
fi

# Allow only root:
if [ `whoami` != root ]; then
    echo
    echo "Installer needs root's privileges to run"
    sleep 1
    rm -rf $bin 2>/dev/null
    exit
fi

# Gather all required information:
# - partition to which we are installing
# - partition number
# - device
# - folder where partion is mounted
# - folder where installation is performed
# - folder where ISO is unpacked
# - filesystem

PRT=`df -h . | tail -n1 | cut -d" " -f1`
echo "$PRT" | grep -q mmcblk && PRTN=`echo $PRT | sed s/[^p1-9]*//` || PRTN=`echo $PRT | sed s/[^1-9]*//`
[ "$PRTN" ] && DEV=`echo $PRT | sed s/$PRTN//` || DEV=$PRT
MPT=`df -h . | tail -n1 | cut -d% -f2 | cut -d" " -f2-`
IPT=`pwd`
PTH=`echo "$IPT" | sed s^"$MPT"^^ | rev | cut -d/ -f2- | rev`
FS=`grep -w $PRT /proc/mounts | head -n1 | cut -d" " -f3`
bin="$IPT/.porteus_installer"
extlinux_conf="$IPT/syslinux/porteus.cfg"
lilo_menu="$IPT/syslinux/lilo.menu"
log="$IPT/debug.txt"

# 'debug' function:
debug() {
[ "$LOADER" ] || LOADER=lilo
cat << ENDOFTEXT > "$log"
device: $DEV
partition: $PRT
partition number: $PRTN
partition mount point: $MPT
installation path: $IPT
subfolder: $PTH
filesystem: $FS
bootloader: $LOADER
error code: $1
system: `uname -n` `uname -r` `uname -m`
mount details: `grep -w "^$PRT" /proc/mounts`
full partition scheme:
`fdisk -l`

ENDOFTEXT
[ $LOADER = lilo -a "$1" ] && cat "$lilo_menu" >> "$log"
}

# 'fail_check' function:
fail_check() {
if [ $? -ne 0 ]; then
    echo
    echo 'Installation failed with error code '"'$1'"'.'
    echo 'Please ask for help on the Porteus forum: www.porteus.org/forum'
    echo 'and provide the information from '$log''
    echo
    echo 'Exiting now...'
    sleep 1
    rm -rf $bin 2>/dev/null
    debug $1
    exit $1
fi
}

# 'update_config' function:
update_config() {
echo
echo "Installer detected that Porteus is being installed to the subfolder $PTH"
echo
echo "Press Enter to allow the installer to edit $1"
echo "The following actions will be taken:"
echo "- the old from= cheatcode will be removed (if it exists)"
echo "- from=$PTH cheatcode will be added"
echo "- changes=/porteus cheatcode will be replaced with changes=$PTH/porteus"
echo
echo "If you do not want the installer to update the bootloader config then press"
echo "Ctrl+c to exit, update the configuration file manually and run the installer"
echo "again with the -s (skip) flag like this:"
echo "./linux-installer.com -- -s"
echo
echo "Press Enter to proceed or Ctrl+c to exit."
read abook
# Remove old 'from=' cheatcode:
sed -r 's/from=([^\ ]*.)//' -i "$1"
# Inject new 'from=' cheat:
if [ "$2" = lilo ]; then
    sed -r 's^append\ =\ "^append\ =\ "from='$PTH'\ ^g' -i "$1"
else
    sed -e s^initrd.xz\ ^initrd.xz\ from=$PTH\ ^g -i "$1"
fi
# Update 'changes=' cheat:
sed -e s^changes=/porteus^changes=$PTH/porteus^g -i "$1"
echo "Updated $1"
}

# Set trap:
trap 'echo "Exited installer."; rm -rf $bin; exit 6' 1 2 3 9 15

clear
echo "                             _.====.._"
echo "                           ,:._       ~-_"
echo "                               '\        ~-_"
echo "                                 \        \\."
echo "                               ,/           ~-_"
echo "                      -..__..-''   PORTEUS   ~~--..__"""
echo
echo "==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--"
echo
echo "Installing Porteus to $PRT"
if ! `echo $* | egrep -qo "\-a( |\$)"`; then
    echo "WARNING: Make sure this is the right partition before proceeding."
    echo
    echo "Press Enter to continue or Ctrl+c to exit."
    read abook
fi

echo "Flushing filesystem buffers..."
sync

if [ "$PRTN" ]; then
    # Setup MBR:
    dd if=$bin/mbr.bin of=$DEV bs=440 count=1 conv=notrunc >/dev/null 2>&1
    fail_check 1

    # Make partition active:
    sfdisk -A $DEV $PRTN >/dev/null 2>&1
    fail_check 2
fi


if echo "$FS" | egrep -q 'ext|vfat|msdos|ntfs|fuseblk|btrfs'; then
    echo
    echo "Using extlinux bootloader."
    LOADER=extlinux
else
    echo
    echo "The default Porteus bootloader (extlinux) does not support"
    echo "the $FS filesystem - using LILO for the installation."
    if [ -z "$PRTN" -a "$FS" = xfs ]; then
	echo
	echo "LILO cannot be installed on a device formatted with xfs as this"
	echo "filesystem would be destroyed. Please create partition on $DEV"
	echo "or reformat it with other linux filesystem and repeat the installation."
	echo "Exiting now..."
	sleep 1
	rm -rf $bin 2>/dev/null
	exit
    fi
    if `echo $* | egrep -qo "\-f( |\$)"`; then
        LILO=MBR
    else
	if echo "$FS" | grep -q xfs; then
            echo
            echo "By default Porteus installs LILO to the boot sector of a partition, ie /dev/sdb1"
            echo "When a partition is formatted with the XFS filesystem then LILO can only"
            echo "be installed to the Master Boot Record of a device. For more information, read:"
            echo "http://xfs.org/index.php/XFS_FAQ#Q:_Does_LILO_work_with_XFS.3F"
            echo "Please consider reformatting this partition to a different filesystem,"
            echo "such as ext4, and then run the installer again."
            echo
            echo "Press Enter to install LILO to the MBR of $DEV or press Ctrl+c to exit."
            read abook
            LILO=MBR
        fi
    fi
fi

if [ "$LOADER" = extlinux ]; then

# Install extlinux:
$bin/extlinux.com -i "$IPT"/syslinux >/dev/null 2>&1
fail_check 3

# Update bootloader config if installing to a subfolder:
if [ "$PTH" ]; then
    if ! `echo $* | egrep -qo "\-s( |\$)"`; then
        if ! `echo $* | egrep -qo "\-a( |\$)"`; then
            update_config "$extlinux_conf"
        else
            # Remove old 'from=' cheatcode:
            sed -r 's/from=([^\ ]*.)//' -i "$extlinux_conf"
            # Inject new 'from=' cheat:
            sed -e s^initrd.xz\ ^initrd.xz\ from=$PTH\ ^g -i "$extlinux_conf"
            # Update 'changes=' cheat:
            sed -e s^changes=/porteus^changes=$PTH/porteus^g -i "$extlinux_conf"
            echo
            echo "Updated $extlinux_conf"
        fi
    else
        echo
        echo "Skipped updating of $extlinux_conf"
    fi
fi

else

# Create lilo.menu:
cat << ENDOFTEXT > "$lilo_menu"
boot=$PRT
prompt
#timeout=100
large-memory
lba32
compact
change-rules
reset
install=menu
menu-scheme = Wb:Yr:Wb:Wb
menu-title = "Porteus Boot-Manager"
ENDOFTEXT
sed '1,/#--do-not-delete-me--#/d' "$IPT"/syslinux/lilo.conf >> "$lilo_menu"

# Update paths to vmlinuz and initrd:
sed -e s^DO_NOT_CHANGE^"$IPT"/syslinux^g -i "$lilo_menu"

# Install to MBR instead of partition:
if [ "$LILO" = MBR ]; then
    echo
    echo "Installing to the MBR of $DEV"
    sed -r s^boot=$PRT^boot=$DEV^g -i "$lilo_menu"
fi

# Update 'from=' and 'changes=' cheats if installing to a subfolder:
if [ "$PTH" ]; then
    if ! `echo $* | egrep -qo "\-s( |\$)"`; then
        if ! `echo $* | egrep -qo "\-a( |\$)"`; then
            update_config "$lilo_menu" lilo
        else
            # Remove old 'from=' cheatcode:
            sed -r 's/from=([^\ ]*.)//' -i "$lilo_menu"
            # Inject new 'from=' cheat:
            sed -r 's^append\ =\ "^append\ =\ "from='$PTH'\ ^g' -i "$lilo_menu"
            # Update 'changes=' cheat:
            sed -e s^changes=/porteus^changes=$PTH/porteus^g -i "$lilo_menu"
            echo
            echo "Updated $lilo_menu"
        fi
    else
        echo
        echo "Skipped updating of $lilo_menu"
    fi
fi

# Install LILO:
$bin/lilo.com -P ignore -C "$lilo_menu" -S "$IPT"/syslinux -m "$IPT"/syslinux/lilo.map >/dev/null 2>&1
fail_check 4

fi

echo
echo "Installation finished successfully."
echo "You may reboot your PC now and start using Porteus."
echo "Please check the /boot/docs folder for additional information about"
echo "the installation process, Porteus requirements and booting parameters."
if [ "$LOADER" = extlinux ]; then
    echo "In case of making tweaks to the bootloader config,"
    echo "please edit: $extlinux_conf file."
else
    echo "In case of making tweaks to the bootloader config,"
    echo "please edit: $IPT/syslinux/lilo.conf file"
    echo "and run the installer again as LILO needs to reload it's configuration."
fi

if `echo $* | egrep -qo "\-d( |\$)"`; then
    echo
    echo "Debug log has ben saved as $log"
    debug
fi

if ! `echo $* | egrep -qo "\-a( |\$)"`; then
    echo
    echo "Press Enter to exit."
    read abook
fi

# Delete installator files:
rm -rf $bin 2>/dev/null

exit 0
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                   