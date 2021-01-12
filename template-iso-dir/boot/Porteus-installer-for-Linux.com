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
./                                                                                                  0000755 0000000 0000000 00000000000 12266225472 007721  5                                                                                                    ustar   root                            root                                                                                                                                                                                                                   ./.porteus_installer/                                                                               0000755 0000000 0000000 00000000000 12230756674 013561  5                                                                                                    ustar   root                            root                                                                                                                                                                                                                   ./.porteus_installer/lilo.com                                                                       0000755 0000000 0000000 00000272240 12266225302 015216  0                                                                                                    ustar   root                            root                                                                                                                                                                                                                   ELF             �|� 4           4    (             �  � |t |t              � �              a���UPX!�
���[]�����1�^����PTRh�JhԀQVh-�����#�V����$�C���=0� uJ�d��w��,-`���X��B�4���Ǿ��9�rm6 ��t>���}h���~�����K�]�����^�� *PPh8��'g.i�=hW t%ls�w
������H�	�
���O[AN6L6P/-%2����@��RRj=W�l��s��@
�ǎw:5t��ʿ�?{)�u"��޽1�������ѥQ���涛};��T5_,��(�%{m^=xwlQRA�Y_�dR[PpjLK�w�*��6R%h��lN�H��<�~�	��
U2ۆ7*PM����`4gY�g��KR9-�;�N#C3uS��[��K.���/~9	�6�(ǉ��ׅ�OWއ
���d�d�[�ao	�
g�(=��5�F��� O��S1�nt7�+��h�R�����t��1��B�����G�����5.�*�Ə�ȹ���{�l+N�+��;$O�RR��[��|�g��O���x�k�݃�7�˹P��y�z�b����
���Ƿ��~~�d[T��u�\h��� �W�X �z8��h T��� �06��� �y�­����uB
�!5�zt�@6��P�ux�^B���\X�4&(�_XhK������c��Ј�O�T��#[��qHu'�h��-��Ht�g�
[��=(�-�{I\	1]s��u��)L�/�Y$=�
1Ƀ��������5(.�aٰ�fE>f�"�߉��(4<"��`FF6}kP �O*6!�9Q�씡�2ts�l�H2��=YjVYчW�{�xG1]80�	���08�#?��� 3�Zѭ�{MW��B�w۪�� �U\h. �Ȳ5N ��?�9=	 �(D����>Mu	��ܟ1,�~#�:�p+���T?b�U�8�r���H<��B�q;\	�}��|+�=�SuV��:[x�[_�4]�@��.�SX^�\=j1�`�X,V�Q:r!#�[j�@�wS��F>qT2S�X�Pj �E�g� eW>dqWj�d��2e���B.d��r���O	�� ��p01c��@��R��;u;�����t�)�A���KP�V�òbc3�1�������Y��>M���V�������tb��<�=�!����
���<��F���I�8��)�}���F�8�PR?�����T1W8,����E�'���]�Y^�!W�1W�����E�i������k�n����P�
 
�9P�>dB�E�wf��!G�,iW!H�CξeGBR;���7_3Q�E�a*�'�m W�V�d��m�8Bt�<���W��C&�o	X7�r�,'EZP=e���,X"�h���K" &9�/��"_Il���"i�A�@�dъEb�>H��K�X��
�4KYuȳs}� (GY8ݐ�آe����u
]�
w�z:�ǒ#펚�;���^�����6��2|�!�����h	G����Q�о9�u��~4 �'R�aL[^.�*h�nc��hw ^\1>#-�1��Q0��!���%�j�V������67]ȋ_E5�!�y{W��00%�+2#�َ^�,Q81��l6!M7� !`�	!WV�YX{�V�3���PѴ)�YWV�7���R��ޅ�tg��0լcF�q�`��*�v�% վ�G�6ȑ
xd7_}��2T%]��a�!<�������

SSP٭_ `5��	���z��B,"��e�Y�e���_ɍa����� ��w��jۆ�EY�Ska������!�B��
�-؞����!�f� ��C������% ��މ���[������	��tY؅8QShRR(�o�!Bذ��Ù��CL��!�V�`�sS����'h_X���	��9�ut�(�x%s���hݳ��:�zhwo�*�r���5�|6���a��k��+��eY����	t<Lɦ-ZGQ1Z��=t����ᴗ�{u ���8/�xɂcE�ar<��:��Pj�Ռ;v9b����
J3l��"XF��u�Ppc�*D�g�X�Kc�%őcd,�u#�,y��|c���FGQ����]6cS��L���DSJ#�e���FV11�
g��0���)Ё�\� ��	ȣu�)�K�@^�d��|6������Hץ�1Qm��(hQll�fE�� ��@�e? o+����5[\��[�PT���a���+�P,���«��e��c��(ݐ�B��휉˲,�J���ӣ-*��R���w
��{�
n�.��uV�OK�;M8��n��0i�$�BA�1+��
�D�O(�s�]*4�ul�a/t�;�>!;+:Hk��
#�ea�BX�gƽ��W�K�H�ω;Ȅ0��@��z>�,D�
 y9�f[��;?GK�0lݴy���!�!�
Af��W�}g�Gz�
�u"���$���v"�fα�i���`'����H�����5YtqW:�3�U�Y\��u�0�mf��1�1��l�ib餸�g+�8��|	t�خ+nU��gQ�g
X��~3���4���h�C���� V|�H0A�X60��u7ǒ�J�.��g�� '�EY+����<u�P0�r���T{nv��kʛ�������/q�2A�%^%�}��0'h[A�K���V�Qvh���x�LA�:�ܫ��4Ͳf��L5K�c��251p��8�O<�<�8\�ߋ��P���,/�5yy�Вt�U�[
j�C�aPb2��U�b#�<yBMi��0�cm����4eO��<���uS��0(a�C��Z�"���3�O����gF.�s���R Q�ht�`�� 61�����L|2~?X-u9i��]��,�?���󫺾�t��T���<�ۥ�|������	�@9�|ೋ}k�a����s�D����`��j�$�Y�iK��CZ���l�
0E��F�^4k�RG��r4��(� al�t�S.��=6��G�u����`�IU���`'`k3RĀM{�8ScD�2��� �XnE�{��d-V�S�\�'-�	�<��ʺ��Q{
�6xx��10��]�{�Z��=��P�jxHx��k�7WW�e&h��u)�<7�u�pK(�j�0a�"�9t7B@2�RQi�J�N\�D����V:�k
=�1W�l�E���a��l^��`7fj,���S�ǈK�@[������B�0�9b�T$%�AL�Nx$\��&S�uXV�T���K�<�S<�g
�yr�!PH 	�
5lƟ=t��C�m	��`�`ޜ	�j�C�X	�PmQ��k�;����C=Z)�0�Se4.�+�9
X�)Ew@(��qLQb���h�l(��
Z�IG����F
�vIB����V! !�uP%�DkjH����=Y�0C�e=���W�p"�wφY�
�
��3h�@t�E�7��ܢ�d"
mB���7���>.&6��a>G���SE8\�%mw� �I���m}�~��W<3�-�(�@����F��xDtX��d[�'U����J���P�9�^��T�vmW�)��i�y�h5�
a����%��
40ɫ�Z| fB�	(�X!p���2��t�"�1K�X��3e$*�����o2HuR�MS^"�6���m%��I&�K��x�mW@,��XutJ���+�P��4�4�Q�p�%�����jP����'#�B���G����7�u�L�8�`n<�V���6��M#u@"DT+gΩ���D�;pDxn}n�l�[�7JhH�Q�
B�l[�@P�#-8���@�A��n,��%V��8��cJ����O�Ǎ@
��Fnl�p�BEm���SV�dVa�EjDt����;V�e���gV��$Wmh����X�MO'�-�Dire�1j�{��[l��-n�$߅��@�LvA�����6�uĢW�D�����Mr�W���
�vt	�:�����"X�+.p�v��C�n`�
�MG�n�XZ9:�> 7�|�
tVV<�$J�X�v���_S����&�EGDXly`$���!i:�������Mo`�Q[U����0�'|�1	�J؈�vɀnb6Uc[�
,K�
�@��R:�!���
���`9��P����jd��Q�D�����6�:
Sewds_����[w
XsjA���]Apt\wS+=��_rum�6�a׭%��dm
Y����*��m��ԅ^�� ��ܱ%�y��_�SBUuM����nc���_̠a�Au�s@b+3va�0N����4�4�0lKF4$P!���T*�P����:uf��H�+0C.�� -.�ǚ:?��TЊ��Jֶ���
�+<�g�%$x�vn��V��s0J4�BԀ���6���uu2o��R��>��y� �LQ�1����S�{4W���b��a�m���������X�l��W��� d?���wAx��M�Q�Z4�0���Q̪"�n�O�y61�U�R+>+t`N?��Q��H�N��S[�1&B��F�3��y��Yw��mŷ:X���=��Fʐ�i!�Q��X1 s�\\��}�\�X�PH!ڎ�Z(h�/`2&��������
E�8�`G���:�@�~1�;�6�@ml�*Ĩ�Q����!M��Q �%��d�/PT�TtY�"R��^�C�[�����97�[H�/���)j�[��(PI��!�e�t�AĞ3��	Pp c_�Go�~��f@�<&@t#���L=g�m�[7E \��3Bu=�TP22��T���]1�-`Rb�*V6UMA�Iv�ܪ�d�=����!�
9�|&�Z���; ��l,����3�wp�KR�H�O���lT��	zV��vK
z��O<�Gl�G �6q,�V��լ|Ʋ	~j[WRX8w6��a��^m{8�`���g[�&*,h�Nj�~t-����wP�Z��h��UQ�@~b��Pj@+x��h�[hUx(�E��+�KϾ�H��{ϲ[��0oQ��(a3�<0�{
�P�L ��1$K�Zs7^�*�bG���>F�5^�X���X|��,�Y�#�������Nj:z���l':$��"E���@"�(�Г����C�.
$|��,1��U�r7��@ Tm�f�$z��jl���y�u��m���_�����(�n,�PS(V�ve�rg<}3D�Y�� r	L�!j*^fQ�؀u�gs�*���y<U�x�&?2��4�";�y\` ǩ4K��G�0�`$?��H�z!0�c��7��:��?!I:A=U��M�²����:=�p��K,�' +6�/�M�����Ps(�L(憝6��3r;#�$ �YA�+:���
�E[���sIeRu@�ͬ�@&�挂�]za�J�W'��Hb1���S4vQ؟ �ɞ��DRR�%�x.$6ֲ~�7�9c�sPP�W�dl!���#�*�!b��QU��ʋ�p�2z��ѽ�E���o���}��J��bA0��Z�&c�Eؚ�P��tk49؂<�DC0�{��v@f��u1�V�ceuc�)�ʀ}����TE̚�Щ�$���"`�1����BO2,{s--�1F9�<끽�k�je4 N$�co�n�`�P�
n�$��6\��oMȈF�:���ݭ���6j�XY�v�P��~=U�~3�
���#��V���ZP4Ž~��[{́�XGŲ*�
@&�Q�h�aᖪ��
!�����{��M����-l-,����0z��'��O�0u�A��J����)�GQ����fy�"vf�K2a�)�m�R� e�?��E�?h}^dQaK�$�w� $U- 9�gG���4C-_:|Xv}�vG��E�h��/����D�9�~?wP\[��������uR4jm�heƾ��"�/)�k���^d�B��8D�g@d�M����.�f��Q��}�r#�vV��}|	�k4�#`�RF��gQ�d;���`!��RR�}P�8ZY^3���l�Fz�v(��P�Y^
!�s+;�r���vI0���<��cA��R&=%�X��~=2��!��(�JP�p�y�� �,�8����4��G�:����v�f�m��8I"�љ���%�t4ll6��cl�>2'g6�BVsW�vb%�s��->m�أi����5h��������_
�5f�� ���;}�T!���� CS�����@v���W��^��u�e�pH�o�[V��WG/��}(�c�]�f��o@��XI@BX7xx�o�}>W�+�W�jrC��]��l�u���5�"&#OA��F"hT�J[�/\kw/h�!�S��,�VU>L<Yќ(cQ/��7|���1��+�W���sdRe! ��`�VV�]q�">��!���<�F��
;a�V[,
���$S}��x	�Vnr�Q}S2�g�@-�V�r��@t5��{g���1�<�����{��	9��t��t6t3~�1t,Ƅ"b�"��X��0
��
9R�W�x
�g�����F�0K�Ǝ�l'G��kp��|��7F�t)~�j�P�F��H�>�$U[�/��0  ,O�G���6�hh��P���+����
j� �H�7�!�C@�(q�/Di�� ��H�_5����֑&_56H|��9~0W�Ѓ��tv-�@�Vh��I|��'Ɖ$�k���G�b�Fk�8`y���dœ�a��$�@d��#�T=zE��;<��.�ޯ"<�bI9�� ��R�� /@	l��U�
.��g���A(�3�Q$���j�m#@{ǂ�y.to�˺?(�R��xe�tO���t;!k��������
q|JN�1B1�K�V��W$9pu0b�R��|�֓%`w��F��]G8�
�W	�E	�`���*�w�1�Y��5[� |�UW7�

 ��r�

�U1!O�Q���a�2u�*1k�_�y��j"hm�"hv!h��< !h�w�AX�����kP�� t�C�4F�'h�y��%
d��Q�8]]!H]&�#b8J"K`��2�K��(��%����
;4�����t%B9�|�=� O�Z�Z�J���.�{"/<Jb@��v��ch<b⤲`RՐ
&��0)8��GX�@��ec
+���I�{�Y��4�V�=��gZ����PFBML#��$ٰ���ˈ�]�E���5Sl�k� |��<
(}TN�x�,�D�f�:7 f9Љ��
���	��E�%Y\�\�e%�4f,`*8�9���A�F���rRSJ��G��f��=��f�a4 ��>!��̈́H��! <�TCX ���
�]���%7+IZ[�כ�9`}u��*_�t͌ �C�V�� �v-�y ���v%���Vဍ�@m��Ѓ�w��:����P�}ܪ&�Wu0w�a���~WQ�bU���4��n�ÝK@�!�$��J u��w���<���t	�t�[���Ɯ�&��voLF����}��
z2�P� V� �/dev�/7V�i��j��7T�\�y� ���	��MM.�/ǧ����OXິQA�P1�,KWWP܀%p��uo����F
�H��?y���A��|��߃��񞙭%�zG�e ��w���5�� 㡨p:O�����h��==ƄZ����:=� !�!�9i����`�E���RuȒ+F�R�c_+������3>԰���9dЯ�)�,�5�|�+� �UhK ��Kk2�>�Q�x�u��/�Q����>�x08~$m�_�p�W���
�aX��$	$�[R�~�;Cu�K��XK&Y����뱿߻v�k ,��
�4B��`=tW�n,N�/���;�hό-�,b����%�Q}l�&��{����;�P��g=������N�w#Wk�%�
��)���K�l��$u�"D":5�n���	(�p�^H�u�n#)Q7�V����Ј}k�/�|�}��Yw�.����>�%�Y�.S��WK
�(! �ICE���׷�3�8��~(��C�m"�����r�cMAo�e��BAN�C	�|�dSS0��.�m��ө�T{\O1�}V �Z�r�u5x�t���êFECWQh�h�hRZ���Gw{�@FS�
�)<CT���C�S��*6�X��	�!��Uԃ@�TU����@�I�Rj�^�hl�vk,�������HV����$|Y��[WW(��r��2}�� ��r�� y�����JVD@�.�R�耎H�s��$h��d�u�]Y0�`%Z�'TC����D_�u�Q���x�	�xH��P�R�_�Ps	�
B��:UŁ�댞���c4�A��Wp)�'gtz�}	��*�w@h7���a�d�:H��[v
�T�m��Ѐ�W]�N"�CWp|>���jug����5Ђ`M��6_��6/�y�5Fȳ�&#pLti�j ��j���+��-K
mthu�smqik`t �	I<@m�
=�+v$��=��w�h�XA�}L�
f�@�"��t �_��j3�/�8�B�XTC����5�
�X9Z�
-�����#}��1�����

Z@(��xRd��� �@��0��������8�$�e6��W-���[p9�tKG�v�T�4�"
5$\
����lY]�-� u��[�_@��E�c�j*v�.�6��k��1w
���g��@�8��=}�ݿ�k�6��B���xk�6E��J��1��ڲ=}��P�����A3�۷�Z�j�F4#hOE������@���~΂�����<xf9<H��U
DL8��-�NPAt: e�����v`ɀ\(Dq,3T���x�IW�-P���.0��ec2X~ �=x��v�� }��
;,�5��!/��SSQQz�J	� ,5�u�} �Z������ >�A�J�,�?PI�DJt,@��V�*&���)����x��Pq��9wA��93�Pt%vopuN��363�>u�΍H��M۶�Lg�A;�����}
 +��X_
�|4B?��/Z���q�v�""� w�~�� 2A�0�$U�*��C2%	�%G���AAe�&S�S/)c�c�̱���M��f��K@c@�9d6y�t#�~Y����a-�t(+<�">�>��UlHD�#��"ؖܠq�Ȟ� aȅ���5�H٪\�X�p�S��|���@�Z�P���a�J��:����E���
b��Q�ؽ+ Uf�(><C�#ϻ��w�d)G��Æ��9?���h&Ȑ��`���9�u%Xπ�ta� A0#w�K���
�������')�e�;%�e9r4���ZWO�^���:�5q��Q�p2$� y�@�:̤ZȄQUM�=��8Ö���@� 4��aؠr�Y��l���	/)���;�(�@�������Ft鳄^a<,Y�<Mv���F�[A0��Bˀ; �����PW��`~�*���:26Y
�����	��������t>V� z�At��X3��B�6@E��-D�L�)U9`�Q��PF�!���{��
,��G4E+m :��	�"o%��c��Us���vs�B�A��v%m謊���Grd��Ǧ G����Ge�����E�O	��^���L�-C�0i���E(���A>,j����e����65t��:��E��'�ù =�H�6�Ϻ��#�D���K�-�E���E�E�u��e��m�hW_�EP'��1�M���u�L��u��
`
Ʒ��l�2A�Z��@�O*�w?�*;@vK�+2PP-/#�vX�i��a��Rh�÷,``� ��dg/C5�(�I��l�o��BѪ�
���=ZA�� J.���#��C!��ۻ���NLp��TТ " c�#
��"#����"PMENUgr��0p�3� �P"! Ȇ%�hg��Ǭ�%'�ta÷�'��j%v�
��� ˀ�� D4x@=S5� �f�
 ^;�$�B[�����m��
��6��t��Ԓ��%-@9�|���6 �R\�f�BF��@f��y�� ��Q��$Y���
nH��0��ED�@$�
�t F���®���~�����@�UB���"
��(��,���EYH e�U�Y(d���E���#�
>/��:~��`�QW	CrB�p�/�j�6WV�j^Y(R�4k�T�,Ym=���Da(�X|�������W�]B�K~���o���Y[���zT`*�;@P+h:ɓ3�K�X)�b(^fI:&=��b`B�/6�$�4x����I���'(h�	s\��%݃���8	�	���Е�})9�U}�}hIP�q��	�%�`VVSS�e00}�'��e"^ZP=���s�¸�':��O�M�(FB��Yхt7s��G�~�c\�l"�>��gY�U�@h A���/,kXh�[����t	��$C{𳜂�Ktv}�1�ыh�2�0�|�|!�����qj�/�m Z�}�hZk � {@�ٚC.��Ml��AKf�=Tt���|�0�e�]�+��$�uh
�m,��_-h��5��/\lѳ<RR����x
�$��Qq�WeE�Qǔ�`uD��X?�B��t!��a��9E�t�R��&�!��j��ɭh���]�c+QQH���I�re�����!�%W����b�aV��!��W�0���M������d�RD�� }����ٕ�x����fj%f��jX�A��-��ȋ~�#	��A�������_��hK"�%���ɞ�U��hkH(���T�bVj`�71�)�R�+�SR�,��bP�|L� %���jX���&�2�EH�pPu��(
Ktp�����	q�ڡTf�owm����@��2�����A�h8rR��~f��	
a����>�
9�̅Խ:a6�Fm"��"C���y�J�j"74hm! }�����_"'�k�t�!B�w?$4x_tt�4��+�(Z���huanxZ�CL׼��O3�)&����T��W��q����@��H���H	P���,?Ǜ5D�tD�LU,�B��B��/ -
��L%�����
u���#�=��Z@4��!� �2�#��[��
]���!�=�#cPp��";[r1���a�����q��
��+���2e<��WC�^)\t(��vt#s
���,�'6�qs2є�� �5���u��11,� #����P�
׺u[X!�)�����H����:;�@� ��=��g��� �FhooC1���{x��
StX����U�
XA�SFA�5?4���~�� �V�p� ��pXTL~��A�)tm��3$� ��S~�����a������[��������3lm;u��7��<�5@f-$D�5�u��.�B�=r�&��Fkm�TgO�n�w�}�h�}�EH�o�@Wq���g�ڌ�W��+��?Ja�P8�#𙆘J(@�TF&0�|ơu���1�i�X��;���,�κ��D��):<%[�m�=+�<ǀ���M/�O�;��� �jF%�p+���2�5TqfB.paY�1��t;{��D�?_�G஁��%�kW쁀�#��Q�����*B?p���&"���U5�"����O�o�*��-Gf��
���9𒅢"aSݏ�&T,d�.9����C�uB>.QQO([�(F<�.�{�$������ǶPPm����6>)�����
 �h(Db  ��SS�	����h_4� d���(U��1L���My8�]�S11W�$�>��m�h�7N����)Z՞�8u(;D'(��.�`3 <�a�A�p�!#�YY��'�1Qѳ:;7({Q�8�� �h(���& �qo�8H1IS0_�dQ4H)݁��D�i�
���spCp��J�/����2����d0P
��仴����� ���b{1����SD�j�U�7�I�=v�؋
��#]+�� 5`|�k�h��(]��,˵�nh��VQ�;H��J�b�m�}��FЎ�DS�uV�Vh\Jl�
����1�=��*��b!K��\�U$�t]n��tH���� �/�2�"[�E�<��
���M;i\�Yg�%�g-Y_�� l4f��x�H�� ��@���x8�$,���A�a�%�����>RA�0Ga�p�B�KE? ��מ���"M�۟kE��D�;xP\�7w�Q�Pݽ������!�?��)X�t��ɠn��	)�	R��f9�t���$����G]Q�TP�����B�PBQ�&~��#���,U�9��p�����u
�G,�
�t���mk��^2JM�Jn�B�Qr� ��&Hܴ�U3J�-\*o�?��!��bl����B�e���@�%W(��|�%[E���S
�MW�G�%�f!��m~��2	\6X���B�Z���S�<��(�?�}�̌T:��a����F��f�"�X�zXN��Y�\�
�`E����rA<hйЪ��Z�"v�p�ط�`�22U��`��_��>	/������B�����~щ��8���N$����:��VV0��-8Ӄ�w᫆�z0����Д�f C������ ��`�F�����Lq���%���2b
��@$N�20m?V@[�S]�u��a
YĀ�	�7�����e]'R��N2B��R�SϏ��t��� ��EƖR�D�:�}��@��'�<?�h��TV�WÆ�S�]���@6�@��P2BR�S��A�)�CPs�V���j;�PH� U�l�د��~��=������G�J~6������t0�����^�0|�I�L}#A���%6(�Vg�@��+
Q�;���[�!E��h�Xus6�[j���	��U
��E�΄c.����
�ᳰ�~:JC^�R^�S~A~���NA�pF@������o�sU)s�@Y�F�cH�U�pBl ��*�y��#�X�(R��;�l�Ht?AR4�~a�N���ՄW��i7�@�K'���ҩ�� B՜�իu�ԕ&|�k�`Fr��^��Y,NL(
�j��)����
���WP��"�I����-�^H�}�[=�xG��X��������
@ԊW�!�[a%��X(��!�Y��v9��j_W�	��H�d �a�i�Q����m�٭�jr^_+�ʾ�jk)�ja�-��jR�+�(A�$$���v �7O�u
�h-b�p���2��p�E�Ђ�uij�w�����
�y�
t"D
 ��݃Z��Y_)2���#~�
bc@��������C���H2!�D�U�W�.�gt�.3?�� �Ȫ��4��Um��
@���������"��yjn�(����0՝G�E�P
�?�Q�	R��;�%�H	��+��7�@IN.R,'2I
5��P�P�Hg"�0�ދ�ǍU�~�.Y��R( GXBD&#-f�}��
� eΟ�^p�A�S�����T�uB�ERR�Y�м>�l��h�%��jdD�Q
P	���_� #I����ş������^��	V�WdZ�$|�-|�h,Uĉ���AP����c4m��t�kS�oIA
A=?B w�=�v, ��*�P<�ĮkJ���A�
h�\����
ab
�K,J'�F{Y�܉s����K\"h���{ݯ��K��.;;v];�K#t3�2�ǞM����C2=�ǫhpp�
f�@u`D��!`"�)�Y�u?���g7r���:P�1�����-
�Jp�`� Ir ��.�h��S�)�P�HR����l�
_����W��l� k�	���9)��:~�	ߍ� �f��f��k [��ن��R��_
r@ѱV\���o�e���)��T�VSU�$��%�+I�����4���PS���Z�rSB[�dy�A��j��RnP
�t���*
'�]��;| '�O]k�t�@&�>����[�w]��\o�,�`2RC���u<�Q��/	�Q����n���n=w�$����Y@��r �~[�Z�E��츲�/&�(P�ջ���	;4���B� [D�c��F�8ts)g��.�x4x!C�Uw��V�
Ȅ}e2K�5�.��;�F��Ou=�e�H�L�tf�#~��JG�3u�_�5�
�FX���sA-�R.P�%���b�r��Bm~p#�6?� ��X�g��[�~F����`#� �	{>t%AtCw�_�}�<ޢ��{�t/��m���{@�����Á��#���}��԰*5L#F��G����Il�| �(�
�=�<A�!�^�4\�n�S,Q5).4�n�7F�ϙ ��/��1V�$ ��c�y�&Wܰ�,��FQ���'E�9؆�5�)?"��$[����k�@hU��;!Z�@��rt> ��&��>�C�v'�X�/�ĉ�k*h�,^��M�e�h�_��Z*�Q9}G$-���~Ƴ"5Q������T�ހ�������<�U�� �\�,h�� �V�" 6��@6"Dn���bPݶ=
�G��K�[����@�(r��,���!j��$D{� �^3���d���њUߖ[�B�PuաZ�E-
Es��-�'G������3���n��1�1ˍ4]���76�ؽ(uʋL}������s9�&���Ǩ��79ܼ�!	�#���_��!�	�jh�"�=��H<u�:EC�%ݚ�v�4�����b���ͭo�1�1��?]��h[8C�貅
�GZG>��JP�}܉=U�>G�-u��P��m�5�m����
$H-� ���}/�sp����ݸ��q�8,�8)��`6�p�
��Љ���ɑ�Ш�N�_n��R���PmA1�8�3�-�X7��F����63Zr+�؈rF ��\%,l{;�(�� !��p�#��Cn쀳O�Ef
u��@k�X��+ z=��n�� �|�g�l�{�PYX~k�K�R�(�I�Bܡ�<�94�RR�XZ��nK��
�ɖD�3�:'
�'�(�eI��΃��%j��+#�БQm����	E�̸�̚��^���W�QV1�hm�j�K0?p�P�(J�r1��w�5t�$|���#tXt"Sp�ՃQ
5@�	y
��${�vN��9�~-���B@53�6[Ñ08�8%,�R�8��6ƽ�3R�A��.Զ��sK���䷴@1�aB��|۶�ԍ�BlȷxNSh�u '���3�%eQf� ���YtN�0(�EG���GV ?�t��0=(J�Q�T,t�`�~5f`O�7�?<'_S�f��E��8BM�0FE�#5N��~ujW�'ډ�Ĩ�$&�Z�*(hQ��T��E�fB��M�K����.�m$ ;�B+B
����(��8�F|�t([Vj&<��B7�&l�}1�M���޹�����wsMwU ���[���)�HO���##I��f� ��`+p���f��s�Ԩr@p��\�a��"xu�[)̍p��Rbfy�9�uko�x�Uum��}�0�@��uaS.�ݰ��.uD٤�$pWx�V�FC�"[pS��Ѿ������dr;�@W��H�v+�_���D�ͽ��_�L.G��u_58RP����!��'P$�l��jA(LT[�+����&�6l5�
��hh=��XP%8��P ڣ(V� �8�c	$��h)�I�^X�Ktw�$��c }+�1-Q���-�vt��;kU�HUt�Ut��|���%s un�F�fNF�∞&D7q�����(Y**�6�����}�je��S)�
���j���+H����s� �m����T���(��&D.cKYE���	��A�%&lI@'���:TQ%Ðdԙ��d	��b|��Ϊ��yQQ�ײ
�,�Ep�1p�*Z�{O��!`�o�ڜ0N��
�u�J1��8F���iПweÞHt$BuC�����SFt_5�����U�SЍ��%��{�r��4d!�X	���A$�I�����-�4��T6	n?�DtO6��ѐr�G/U/g�o/|�r�!��$Q�~������{Z�"���ɘ#:[3��8s�=��C0z�jȵ"�x
��y�xf-�Ky��Q�π1�є�`�(�0zBt+�cEu�fRx�f�,nL 
�n���c4I�HOV�(;�76rSj;OP��-�H��c��rdd�WVVb@^QQ��.� �N

�6d@
g-���ˋ5lB��a�y��gΎ#���|�֊q:����D(l߃5���RU݄K��W�ސ��f �z��D�	�WW	���VV"��쒤Om��m{;	����p�C"Q��ے�!:�^>T#Ҙ�,�N�P17c��P; �����]���x_]�N�.+5��!�1����.�a�@���ƿa���<�f�$�!a
}+��+,+�(��k`_�,rz+������hA��.htϟ�ٿG�Ӹ!E���09���\�L{c�
�=�P�	���(w���
MX�w
�9CCQPg�B[uaj.g�#��K�(�.��	j����YB���>~#H(
u�DW�+��lNH��6v�1�/���ń���E�
<:(\8z�ϰ�,ngw��Y_� �mUV��KM���t>1@\k��&5Dz������݀n<uE�>k��;��n#L��6��~7t�������AFt� ct;��!}i� ������}�
o,o�l���w��?��s�<+t�<-t����_�YƂT�%	8�t�mi�_(#w�����0<	v������q��'\(�'Jbr#>���� C�>-u��.�pk���k׊D\Nut���� 	��0ou����l�7؃�$��t�C�%'$FE,��8���<Mt<J�M�LG��m�X|�~�ıM�v
qA�U][��Y���L9�ENt�mxk4��G�+� ���f
k��;K���l*|��H�k�y�+9�9�yBn]�i�QA�;l����6s�U�H6�hD����E��4�z�BdmOD�c@�3<,�F�#vDd08^~H[.Y胈u�L$,�AHo�@UVP�av[e� 4UG_Ȧ�$��]>�8e�B���CG�g��U�
m2	��#�X[��)A�juR�m�K=�f `��0�z#d�x�2� D�&,�&���~�mt�M�YVi�� Dг��V@d�D�F�kj7����M�9X��ɽKh���j
1� ̆'(Re�6XS�n5&ڠ�}��0[
�-NX�lg���0R�|�5[�I����*�0�#nH���V��B�i(�K�ϊ���Y^7Z?��<$\I�kr7@�������~l(^��1�>u��s7�.�+��6/��3/I\�5U]6i|��d9�.�FL9TRo�Y�� t;K|��Fsv�4��8H�	n�.ԉV�&��%�zw' wh�5>��P�u<R!���-lK���?-�<�'����V%�VE�<�@�-� �ӖP���M���ٓ�a�"�JF�4���\�؈�deyQx�H�@�8��LJ��x���:t�xհAh"$
	���dϸ�ͮ�Kt�30�l'�+��/{mT2�`�`���Ä`LR���+��Z>t�UU�*��6V�L\cx~F0	I��ut2�R��[� a�b��X�.N�F0B*��A���������+8�����F���t-��U(��F���Ct q�!:��x�joT����g~E)���Q�t
�x+D�+P\4e����zQ.������+�l
�9�� nO9������0��P�YKl8�>&�$�M>(��2�+��A��rt:<wϵ
o7<at6��k���TJO�	� j�1�Z���%䜂H�q	%btP�m/o
x+8�G���/��xuu�hc��Vmjdˎ��XfŢ�A� ���xE�])D xV]�[�lD����KB8�w$�@!�9M6���ƈ}�j�L][�z�)'B	��k���*\$�{���z^m
͙6�K���7����f�	F�G����ĻJ�P�n��'pC3t"TǋU�h0�L�Em;n�	eۊh(�o{w���t&�h�@�	��1c������n�uf�(,#��,"0K�x�4��h��C�;\H��ti�����WbV�YN� �|W�9��E�bY��U5(��PC�\�5$��?�O��/�:r/���<ȥ \�G�vO�_!��~
�{]lt0��3,����AA00|6�W:v Y���u~�B�$P5ذA6$^9�Pv��		2�X21�[H��ɝP[�.>Lxu8��^5.��
6�#��Zh�>5��VseO�@o:ʅ�J��&tYM�n-�ڨ͉��M�����X��@�5̿!G^[�[�)�f�#�|w9��+�~��\���(E�T�vE3�3(b�xŅ�_o7�����'Q��-($7p	���nLUy�rU���oL�t�b�Y]|�X	�0V�O�-
�����! �>���JA��,�`�
��@Eˁ���MH��)�u���=�? C��Rj��t0�|��j�ZY)Ǣ~�����W �
��7�X9�u��EvW��WUo8��6��l�8�[��@D�i��HO,1M����2���q�QV����\���d�Z�%��y|�VB<�͠�� {G�"8Zl-~����RWF|Y<����1]�t	����l�S}�pD�\��2���hM8t%�9�<���)��kWR�n)��gc�g
Z�p�uºH�_Z��?PM����~
@;Whr��|����J++����s|�%��ZД�����Y�m�
��U��/6�}���W��
u!�@�y8�� �-��4+�6j��@d�ɱ�ho;w(���oDn��7�g�~��ٿ���D Řz���y�����B�����D�
�H������������׼!э����j��Q�E�P�T���	gc�v-���ۀ-���A���-P������X4	��u�jd��)�:�y�o��,�t�Rَj�vx	��uTo�:	9�w�
�oZ׋�0�&7�ݻ0;��Hu0)�R���	c�R�����H�JB�)�eרּ/r����Ha��;Ȩ�^���aU�p!�|]�t���*���9� �Y9�6xC{ccv+������l�i����8�*u9���ú ������
Y0��8u�|�
b��	��b��h�A7��/���N�V7�5.�(��x��Hu�����V�%�@"D����V�vV�ex���9�^��^Z��a�L�e6�& "�~a�Y��V�" [b�HL��x/�[V����x+�uqPL:�o��HU�t�pPK�@��L��%�(G�tf	t���O~M�H�.��EmM�t>~<	
�,�\;��JPM�g���"�P�&���*�>�
t{
�
��Vȕ �
�{���x\�-G9�0h­{�>$*��)fF[ ����D�\kA9��.�F�D�ua.� ���>Bx�`G�F�f���m �٠8uF��
����	F��Z*i	�%S�EG����[�\\�:uU:	����"T������6���G +l�`kBE
��{,��ވ��S	-��ͺ�S!�cHV���PZj6\WωOۂ�^9
����� -4�[�*h��`H�$�[p�笡��C �t�z�;l��쾮;� �|W���I b�t0�
y.�`�o($��d6�C�
C��K�!�ӼA��aX�T;�)�`CItL���Qn]��]Y^�!Z�;i.K~�E$p��[�t�;Vv��n�B:�S=f�^�J�9��H3�6Xa��YC��@b`�a��a���g�s�I3�H(oa�}hDYig�{n�c?*�$nk�<�NNs�6�A�N!��`VRy_Z�Uo�I��sN ��>�A		��z{�c�@,%�H�:j��KXdK�&U����; ��0��	�h滾���" ��H� |Ze�@+ ~��C�x4����� �����1�x 0D�`�*ʉ0����p���}��j� �剱 Z\YY�`9*�Ɖ��X�lt�Vr���ϔJ�$���	�(�e�K�@�&tW��"j< ��f���Rˮ�U�m��rB�/ْ֠�+�.bX*+Vu���_7W�wWMU<f
@���f5@��@�2u�Y��*�`��r���!��`��8�;8���lF-f��. �g�r��dB S�Q��s�gڋ���(��u}l�oQ(-T�If��<�j ��z�9Z*l�~t@G��i�KlP�u��(a#�J�X�����(�w#�Y�9Ft#��곯s�rt.�����ͧL@	L�Y��,(���^�'��Ք�����J�<2���eG*��w�O�
�W�rU�c�8-�,���A���
�M�Fnk�;<��Gz�é�N#������9�u�,�6b��p�\<'��j ����aPWC)�q��^2ZY�ul>t�]�a@t<n�Y�u� K[Z�aV�=hXT��Ih4XI�aw"�a)GA|f������i������#T�P�iT��k9�%� �o�x ѐ��XYM5�+1u;i5�1�_�pI��9�wV���w��f�����E�~�'�T������Ĭ8�oZ�T�-�vT^�?��-���E��r�������#w�����9���vAIt8�u:�����%? /dg�OG�b+��^�w�J�_*����p��#�BfPA�@J���
���)��Oz�͙��͊
8�mB,�[(�󷟗�s!��s3�<X�ˀ��ޓ�9��r	���*�����;��c�8*&�@���<:T{M)�
vK�������ؽ2ABL�)[�-#$4k8�<j�Cn�V���)�n$G�C����<���
@�-�R�7.�)���P;�H�/�l�h�jNV�ݱpu�on.��,R�b�i��m�߰U�F HC����R)m����w3���t�����G+������Tr;�oP=C�j�{K�����oR��sm���S5;9��k�D5��M�`���W�� �(.~�Co�{���R���(9�	
P�G�
A{:���6�lBI;� �C�
�8t݋%u��
~�)<o)�uOê�N"��NO��4gM��j2���"�%p��������v�h.���n�Fעu�94~�gn�"�m�l�M��^^����`p����hˋ��\+B��m�
��n��������=� ?
��9�w��*���[�&�	�
�8���@{��8��R���Q���,�[�c�-ǽr��WIL\��7�PB�fG����ph9��)�ر��B�_�:G�.a���~$oOձ[8��I�);~bܴK> v8�)�_
�����g��U�T�6r�b���J��>[G���Zrt�j���_�;Mr>�9$�ڶ�v_N��$N���ָ6綪�L��p�
1$R8�ŷ�4��Զ���~z�l"^��D4��nN�	 y�$>���
z��q��'&�ksn�޶�c��i�x�E\��(��rk�}�K�[9o�9i�����=í��XO�yB�'w�[0��,��5�F�mB�BPlPu���Xn5��;r+�m^�?�Bc�����4�x�ދ�������b�勋�50� u�$Nv�)�L @����+��/F���:��N6�*ۊp�V��|	H����S��=��t�(�H��u{�('��$�.�n|��X:�s�9�����yщ�)��^s� ���w*9���]�7�1&D �	�7q
�BsT�y:j�6NcxdWl���N,��� r�7�H,��g�l�G�)	A�b��\�� ���+��>Kp�W� n��||��L'�|w��uً�T9�P��l
�D{�D��9�K�
�P�"jUΔ��=�T��VbC�t�)�]�	�K���B��
,|E�{m�`C�Z���St����;}1�u60��F���A9�P'xy{������	rz�ʻ�f3m�)�݉j�#�n����m=&uO�Fs�I��{�	6�@�%$D��s���	��	��_k#�
͉�M�{��8�X��C�nub����*�o�(�J(-���!������+��9���ЫƖ�!�^QWb+��ÆĖ��+tRvg���,((�EP�����ԇ��9��B��h�������6���g�s-��Q�]t1�nOL��VW�$#5��iF� 8��3ct�r}��0U8#�t�����B9��[
�0t����`���x#����-�^��8}ձ<)��Ej�/799G���Հ M)sh�P-�,�|Ge���z:FKy�eC�MO8�`���OEA�m�G�%3H���
��,�M�i� }�:9�`l��
��)mz0L����)藗e�U�pG:9F52�m��w&~4$�#�G�;O�1qgOH ��l�V��4�q��AF{
���
�R_&R�>� �Vy�
��<�Z]��J�Q��e,��d+�bR�U:[�{���v��<�#��W�c�<Wj*�5�Y�"��l);1,��Q�^SA� `���ihR>k ��_�<�4�'�=�ruj���r���������zxZ�38"t7C�,:~���!UǍx?�k`a[�`�<.=u�.a�SA��lw@�F��;�e��L�d�,��IV�M�$7��k4��̲���0�MQ���
�P��ݰ�
�V< �����i#a�=Osac�g�V�	�Vc��� p/�K
����m�	�# /kOy�u\NX��u����=���î��v���݂�w�Dw� rVM�x���@%��3�b�[���3|aO�W�G
Y�≦XM��m)B�
lT��~~�f���^����
�f ��A;�l�(��(����~+�C- u��<-u��6�ƽ���' ��v��/��
�>0uF�B������<xu����UQ�%G�(hU^��ƪf���l;���B��M�
>4�<|p��)ڎf�;%�	�E؁+h��}ĳw97�.m��Z>MM�H�P-[���e�V��X����,x�c����U�Mď��Pu�9��& ��5 �<rml�R��Q�PMl*j[
�Z�,t��L�,�L�l:��sb��tn��`���@�0�(��
6�jxk Gۘ�P�z�mK�-==�bKP�&o0����$�M��I�N�	��*�
��ח�z�,<�Y�)�;�-ݨ�p�LrY�PPݑZ3�
;_�f�ʆ���6%�e�������F�!���	R�|	d<F�J�)�Mv�P:�s/s~�tx�	
J���~� �L���kԊDhݥmħ��U����/�`�bȍL�P���[ '����:�Dl�Ĺ�Y�3,�0�8|U T�X5�p�A7�;R0���� �,�v�`YaLUh@�Dfg��P{t ${�[���aB_~H��
�%S�	��CTAeh����;B�`U��fU�|�nU����۾|%�3;(�F/%@̀ ��(�͆�<����tV�5�@q+UM1�ބhт~*O ^����04�~m	��b����p�{�FRXÒf�8V��y��uTw/67z ���\_��~������ 
�
�)38�NĿ���X�C�,�-:7�8PS��|`�������8_��)�mM�^<N��C�HPT���N@��T��wDxLb��v�ә"}��ݕ%R���$�>#�]��T���;�
�*�2�6� �@��o������w�<�
�tlt*�r��_4��52`f�����(�u�'���0j���/!j�_Z��iX���@
2'����r����g!��G9��E��s�	8���1��p��  ءÐ����t�@�iU�aPO�N+��X��ظwY�j��bd��(
�4K��lK /$�eY�0�z���R�j$�~!n<(��-�,@D R4C�kDVL1�:e�mk0�>/�X"#cα�e���� ,4�C��8@DHL�@�CPT�,[ ;X\X��R �\7,FFne0�n048��M������HLPT� ��/����^c����;�䵸�&�⯻��û(��=J��S��I����tU����5b����	[[K�f/^q�ew�=y�j��7�	@FI�|��N�"_9x���ࣀx�{�,�#[�VP�����c����:IC����= �����X �S2�Y-�F�� .�t��C��WZvLr	�~�ɋ��V�//
�l�
�4t -��[�Xz0�I0 �-�Ǌ�3��_��T�n
U��ZD@�U�[E{���V� �
)��Q_
�t�*A�޾�b4�Scv
�?�E�ճ��/�Q�A�C���y�0t+�}�t# ��G�eѧ��U��>�>�0t<�����F*�O�~?�
)�5��*�4	�(D�(@J��͡�bH�d}uLVVo��I#T�:<
�]�� Iٗ,�/9�r�@�Uq�pb�*`+��tG� @��U� ������U�^�Ԁ/وD7��2���Rt�n���⵪�o�aU_+P>�tt��ݖt|�T�A�8+ �� hX84ž��ȣ�	���U�����C�������6�6=t/f0/��wQ�N+N��tZUm ��X�к�-9X&�=."
hc1�����*��L$1��ڝ�/f	�)h�A�/��[�m�3 \��|X�9g���-9uy����(qW�.TM�=�B�P5������"!�vD2��m'���X���p��}�Q(���G,nU�w. ���)�������� �"�f��<�7�A4qY'9�#�M%�� �QiG�����IE���^�&�)o;�s���U���^�ْߒ�CQ�AԤԷ�w�u&F@t���)���9�iʇu򄈡jlV��m���f9�wdSP>R�`��yUj
Rul$Y��ti��j��4�V�<
�	6`q����	�
z�o�46�)�)�)l)��j
��&�$>&u2y|CDM�� pk�oriPR�~��A��ʊ��#�
� � V�t=��@����Q9O6��'y3Նo��v(n'�H��9&����)�@PXjlc.ɘ��z����}� �y�x#��u#�`,��x�ؚ�
��@�v;��'"tif@.�v�)���+G��Y?R8�&0��.���[l���pJh[��=�U��'�$D0x��`Jw�ٷ�Xy�\,T
��:,!SO����1���9�p@
]�Ɲ(,&5��Jt�+ũ,\�
8���]�9�ЎG<:Dk�� N�G![{�L��[k4��u��N$�&ڋ-t���@��"�3���F �۬$���@�ن
&��LuX	��+��1�Q�@
�^�+�
�
�������hRu$���������ٞ���횩�L-��f��Z@��>��������؋��Y<6��[?u=��3 u(fχPp�f�ΰ�`j~a�3�
	j��$b��?xT���w�� �l�s#:0|�
����>�A�dd��	�
���f�������_�E���
�+l�Тvq
|��Ta�`�ec�^!hk����8{+l���at"�Ļ��((�w�k>��,`~1w!�ЭGt{o�.��^~F3H:.x���tG
p����I"���I�=nK�dX�ߋ+�ݥn�AmA� �Q��2�ܩ��n_� �f��N+����ۨ��R[D�tn���P��H6L�t �L�ɝ�)ϥ��P~"�cҊ��K����J�B�V�x.�;�,)�����;�C��_EpBx*�~C���Ճ������ ^�U�WmA���7��FP�����-[8��9ڨ�F����u�����ď#��-(b�>�=���g���n ɏ�h|Y�`�}�H��(ே�������@�ItV/0��A�<�����[0�x�Ȭo�^�C�3$�1�xs����V���ƃ����
�w+�f.�ˀB2��F�`�Ǵi(|?@{����s,q���o� ���@QE
�	��5��
�O
~4@��Uu"�,���L���3���{7�
��X������9�l
�B�'�R�!�ke(O�N��}B u�~ ��<��K��F�>%u1�m���LXA���PZ;���$�%���j��d])ױ�2��;�H��J��x�DA��&mؓ_��1/݈��D"�щ�{��+O�U+:��ߣ��r3~�_V �E
�O���{ ���(Y��á���6_��+:2%�Ta]c��O3��t�7!�� 2]��AT�
hK�$��'U�_�� �`8�� +��1��v��e�g�P�7U�\C��٧ %�����鈉 ���[xUVˮY�l���êt�xea�m!z[|2�-@�ECF�z?�"��p!^=�C�Wm}��\
(.��}��]uI�
$�]�HA�ST�a�&X6J�xcP�u@>�`��M�OY&t	0E�`��F	� u��}pܓ�xWP�b����c-���	ͨQ�5H_P����Ist9��IP���аJ�luX�D����P<�@<?���t����""�e� ���?F �˶��� ����H�
����[���
��ek����V�1țk���.�}��m^��vB�k����q��ϰ�)�I%	������1x���g�5z8*��g�c�B����8�@�
�܋DM.4�m�v8,��EǾ��H�
�t3VHRV$�G
"���=�� G^�B�XH�̞vt�N����+�.��@X�Bg���Z�i�C�����A'���Y����;��~��.x�S��X���=� �8����ˋꌅ�
boH(G�^�
V�V��e��=(k?#�  c��_��O<��(�w0R�GhrjW4YXnXt<�m6v0�R��;7��~����EgAƉ���cAZ�58�]v5�;yB��,K
s2	-��3r��<���i��H [	n#jg;���i�ۻU��n!��ʜٞ���&��9� ��bc��/�����Z9
�C���Y�%S��	�� ��A��Q�2Dؗ�?
�°��t"kn�#�8QF,�8�	��Bl�݉���.��WBH
�&pXM5�'P,3�ה���L�(f�(����ۭ|�W�Nu�D0���^L��{Bn<PC��J8����LrI����u�]��VeR	�v�/��	�O��JQ��*1����ց����~1���x�t �r�|,�VGn�k� �_W���w��č�J�	�V��ju�1H�U���
����Pt���GF�� ����41z����`��v|vq�}��� E^´/�����X@ �)w����hűC��*v�h� %��bf���Ba�X��n�L��!-�vo�/Hx�Pv	�P��Kd�̞W�6���T�.LP
�D`�����Ecf�>5UE� Sb��rPk�,��F���6�
��D�͢��.Ɂ�zuR�N�N��y��ŒD >�\U�&��1���/u��/N����,j)�,��EDPH\Q+!���d�l60H��S��ڞ�f��`����uf�U�Zzy`�O�c�	��+L_>	F���z[%mM�,U�e�[/�m uf�[�E��~Ǩp�� 6ܮ�Q�e�̏�����nU��C����v�}��1@�+�ɮ�֠�:[�"j{��j�U�.n��"�}�ۅ����9��'�oA��uzf���Q�}�u�L.du��R�����iq�{��m����n D��*��s�ӥ�Ru+l\�/�7B���`��
;<+�+�a�m[�[�P�<�Gظ�\���|Xl=��A'��Nz��� ��nD�::8t�7�b�^dЀ�P�.*�A�s�Tr��)�zn+-���)��X=�mo����x:Ruh��3�� �� $�W|�Ar uU�U��D���l��R�V�91�@�ƶ5
�
��� ���������,˪��!u�}��5���m����n�z���7�bHsQWa�e%�1J�X�olK7	XyFq�m���
J?rM��<H��].b�����-�ntu h�(T�*�pgjUY]�
 ^s��
y5p�g'�
���tC�S��Ve�F��a[9�s��	P{�<�V�p2�'1ȏ�� �*�%ق�j��E�l���b)��j��	����E�v��(��aj��>G}��ȣe�ڛ�=��/E�ʹm��	�� �7h@j|H�o�$��"�9�v*T"�[�`P5��;Lu�.��f�[��מJTQ��
�����/� �W�O��G��lm�Fג�
�c�ȶ�('Def��"6e�����*�5
2�]V�ÞK3ɠ��D��)רG�����*�I,��	��&g�
@[8 sage: %۾��s [ -C config_le ]q�w��m mapv N |.��bk 
`7s>
oUtalJlCto a����ciB �sc"(RAID-1)um�d2A /F/X UNv�¯K?qu
�'3;T hߔ�ح�li^dd[5�d�!�XH���Dmp-#A[7��*V��	�r�V.�s�nf�'
� �_1=0x%x23 �2BCM-���N`
CFLAGS = O��m�i�RcW�-DHAS_V9�r�ERSION_H��o��:bb920890@_BDATA`�DSECS=3
e���IGNORPEL���`	KEYBOARD�6��mE_SHOTP4S16m��mDICRFSWRIT�vk/�BLZSO�_C'���IN�
� �|� D ����/lba321u��[(
�nmk��cjLo.& 7(��'�syG)���apurA

�(f4�l̵O(�q%���0�[���Ɓ�%md�a���Ue8�mK�"dk<v�z%,����0�ҡ�\dQ�7-��y;`��ڑW8	:��Hy~eںC�EY�_i
6���o��hH���o#.��Z{�gU�(I�m[$hG�]�8bt��sDj
�KF
E'��
n\��r�l��z�N| vf�(.@�[d��4X �#K"sp�i�*5@[Ɲ'a(މ�}h)c+1+�3r
�R``��|
�A��]k���Q�7h ]�"��I�:��D;HN�h��H'e�\�17/�P�aI+K%�+�a�;�_��6��fe�Һ
:�qm,Ps5s
$�����2�K� �|]�s
4z��؉>>f@����ˢ�t��x��b��Ls��
�x��('F�1���,:S疢�A.BYWm+�5�Ǌl��%�g�zx���-KI�5;�r��r3��*�9�G��r+f��7ca�t0��0nLK�ށ�4'��b؛>��k&�I�s� ��d�)fceЗZHol�
f,ǔBH��/�v	)$ ;zW.@d)�����-[q�Ms�:<	�.�X;�Q�:+  �0�\�M�D.�C�%3��h-[�q*��y� y#�n��hm-d��c�R|H%�E+ya/8�=J��Q�D(| CX	�t�24D ��\�=��
�0}p@`xu>�j`!{j M%:���
	N`�  %:aV���n����á�
H @^����)�ֿ|�rm -��sS�Ѭ��B���� Z31^ߘ��?S��(��4X9�4�"4,�� N؞uTG)f��qy�*�p8 1&�@���ew_{1s&`� r��h�K�ׄmx-�k�B0*XkԱ'�kn�_���7}=���A_�#g8�u>l&��e�`|�a�	����:.S`��	��OMpu���H�#ǭ)DS��r��ogNACCESSI�!�[�q��$t��Fs0G>RM#Ā0�"?"8	� 39^7���:1��Bo�d��a���S�_��P;�jRf�	�{5RJٰz�Rf�ߒ>g#xF_B�NL*Ș��Z���l1PP;�C�DU�iM����lvm9a�`�g�h��k�ҷL`�le�%���%$���ܰ`��6~0ʖ�#x�4ؑ-�C�oTv.�5�Z��es/4@��g_i
��h�!'���'�'�*
�F�D�� Z��EG �l���p��ʢ%��HpK�nV�'&	WoGP�x%�2��)��`�Ä�H�et�#B�&L1����vC)�	�H��o� l�mD=6�U�255.�V���N63�)x�2u:1Y�.PUs�'�T��'��tK�w:w5(�`�Z)�.܁��Uw�,��� �
�m�]��1d�:��Qc]s\�oI� ��Ө{WX4.E�iD�w�x.q�V2r(FI0hH��BSZ<�R0`6'*�q�bQ_1r;�Y�I�?:�;5�f33�$	}b����YR���R�Q�[ ���
_UN�K
6�M`746454��:� �
d������q�)�=&�e[��-�	t�ƣ�� �l8+�l
B�a�P��SV�RY*UZe&�Zة$�vaqX�\�;�t���y�N��� �a�h"�^�Z�!GX��p -gu�$���X�,0����caF0�V%a�bGsD+�a�
:[lZ;�@�- s�ߌ�@��[�8& ��c60�6�6MJ5,�.AT�a3�ZG�D&�?f �Ց�Itqi$@��-2.!Y�2t$,sT��3{s���-�{����fzZ{�BL���<�b�on-S1$b�
X	1' &Ȇ�=5CgHq*'3%;)X�i<,<	&M�'T���e�eX�H�I�$IU�v�4�h(:'�w��G0��x�]�Z.LC��2e5����P�uy�I1�W� 
��*q�'fK(F+�"c��
�.�_�� 'H= ����9��Ѷ�4+1)C��{� .Bh'NP^�T�aP'�7#��xch���E�X�CrQ�Ų{�).u` f���[Y/n]N/y

�fj��X(�+ ���,C+���
���W>��x�� V����IIDF
�e�$�Wn~'{Q6-95S98�A��Zj38�I�
IbJt��fs�%�? ⃃V�{}..R��vr@*hR)�++:<��t	\�ס.��!U)C�p�����E�-����B���.�y��b�x�d&��d��C:
	�	��
�a�8Q�wn��nmF�I��E�B\�e�j
�B[��i/_�E�ZbVt��� n
E̲��ҟ9��J,(v�%�\�< jf_�e_I�E�sQ����>m6@�$�m/C2�t�3�L���b�
� U`x�:>:l�;ҴN�xX�K���ϞhR&n�Ál&�{d��@<�<&�e�!Ķf(�{̈wD+��D����D(g:�B�` "�Y� (�����@��&)~��b��$�ZE���=Ӝn�5{�p��IS�'zb�!,�H.�a�+2�X0�[c��5�B���K"�@���,}�|�� F�n�q��_DP-�t~��vU k�Ճ0�4��%%�4,\��	7"%"�N8p�%�U�+dl<�m�h�v,��	#$�3.A0C��md �4���/r�G,U ��0{F�-9(�r)SF-��u�!�d���jA���tE	{�&�-�!c�9�	�l���)Q�6Bzt]d�`���F0\-,�C(�� �>v��$�,�L��$��l0hH�'s��{<4U;W3�0�Z�F�
fԀ)²6{M}/�UlR��M逷�d�}#=�`��#F�<�Ԑ��tG�e=i.�"v�o��C`�ۧdA�Cd�=#��.�i�ce���7��N,H
�
����ӃΥ̑�bF��P� v��sE
���@^`�Q�\HEBs�6���يTy�z��*fE��m��Q˴�NV�$�D�F4F��pEݟd,���L OeS5�g�,Bc`���rH8��5����nxT��[�nh!��YŐF�c. ���װ����#�nk!�f���#�h��������!G�pC��e=��94
�su#%p+\�&Z)�&�jY1uݒ�Pw=t�Ǫ/'-Fu�rI=�B]F Fz�1�(i16AM8�y�
P�0#C? �5��&�al E��%è
)@&+?�p�*�4s%:�7
$:�hMKH6V�]䧯�(
��x�
EkR��0���m�"l��; * PhPsx'�D bc��e-p 6&�~,-P��a���H��	�C �h�>_���ONLY_�0�;.8��oFw  =3���K���/sLABEL�U�j�U�='D�`'��0��%�'P<�'��;8�-uKP$�
�� jC�a6��N�7�-�-������.,��U]m��KY]7u�=��J�,� c/%��DOCK�F�W ?{��n�XT�TACE8!  kAb��2�S4��Bm �V�Z��fw�TB��<�
�D��e؇�2��BPBn�X���2~�Hf�+�a� 2�
-� 7=o-����ur�CAkN|thKې8;h�I�O	��UT�20�Sc��s ��bYٍ*
�	�� i�-U��|E/�k��/
��bVx%m%7�T6��	)$ozmd���U�W��vYM�!��mȢpc��

�{��%�+9Rtf_B:���e%0��`&	0���j�D��&�(F� .�Ȩ7���bT;�k��j�*L�SYNuA�p	�H��mmZ.P
���-f_
�T��v/#g�,�8r%U8�/(^ઘFBAB�1�C,!�":b~Vf��I��*%N�0U{H�bc� ���k�SU Q@H����lB�z
VY��%4��ˈw%ߐ`�Ng�AU]�ě�)TK1F�;1d�䊞\rA� �^3�-�*dUmj(LW�V28�Ԯ��HS�`��PT:�L[�$	-{���q.þ`+(K(<��Tu.EFIX-1��[]�
f؂ԗL
If�a,�074�5(��C(<)��� �BB��}�jf�4cBo.�� E���	"��Y/4�BD!eA'�F�B	j�ڑ�FA1#���t.1bT�o����ID�N@C��@0�_���:�=�_��H�Z9G���ec���� �dTIC[V��W k���ON �"�&���';@�$�,��ae4[m�{�a�`�Z-N�!	$�˂��!7��+�NGE������8�"0"��C��� 
b"^D*{��A1�Q
�.UԵ�i42�����MGT %�E2CK%��7����	�L\b�$	�3u>����{cb
��Y�:v?2j&��s�3`�^��C��8G�x�
b�K|�X�� �!F0��.P0��a
��$���r��$SRhHĐ��*��qpy�8�
"CD$��KJmk�Ȑ<��E\�13E���禅8�d��48k;����
3/B�Z0�f���;e� fE84M��m�s��u6a=u����f(>)Т�!:>�?vY{�q+~HeF�~�Q�H63"	�2���D��_m�-��BE$�bV�N
{���Q���BO��(�^�9Z  
#'�=VG3�f�.�'-'6�X��2Rq�JA�0,H�z�<
	@�B{.H�R�bH/��!W��u��|�xn*��A��e+p���j�ƀ�ajor�duHҌ�:�ܒ(V��G���k�A���cvB���
zrbM��^s'�s�1Z�H����K
d:�A,k��'
����%����>�X�XDEIS���N6f�h^�:K�b
�GQ,u*�B�*x���k�V(��35W6
�)"�a��5�a"��T'�#	�:$p��e�7C�eV�b`A�(}+�f&sJt��Ƒ+:��-�(a��Ծ%Nl�*J��3���~a`�^�N� � �j	�+u*�	lD8B6kAP~Y) F}.��V�&Nq !1�
$� @�9�GcG� �(�	 yN΢? �`%�Ǩ�,E��DL4;z�M� fs|F�!�>(u
qx�F���{�j争A�L�~L�aD� PJtp[z/��4(l)``�@�S�I����VTC�R!LB��2uY E4+Z���@p<gaDA�s���F= <>��(訯$�%������B� .7/n	�&͂��HZPa ���6!@�A�WX����1�qHKgRr��`�G�ă��MCV/e?2� WINk���7s�
N���y�O�x�+>�} �݅�g 3�7� 89��0C123���<456���&�d���&ɚ�4�r@�;?DHXO�be�5�9۱��k�3)��iQ� ^i��ik�w���i�������  4M�]������4M�ܱ���M�4M�����ۥ�X2<C�(� ��a��+|�#�%���Rapy$�4�.K�R(Y(Dt����m�PНM:<NǢ�,F7
X�f�a���E�-Ln.&),ۣ6[�+
�`}c1�w��R#(Q A�9��.B�} ]t/p@�8� ��!A>�v�B�Ѵ�d �	Bi�\<ƚTf��IA��*7��+%|��\��Ed�Vf:R%�5��]�3X
��iBA!L)a�ح�0�C)!T)����Q)�W)��� H�[��N)(H)�t�6 D %I�%��'�ر

L�VD@�.�r�P)A
�@�tB)�� ֕�  � �Y�wUL-�$C�)b��8�oY�/���cA�E)����lI�^S�=�)9n;K+!��OY�'=�c#
#��d:za��]  �=�]/	ԥ,{�D};
$P1`6�[�L�$�o#Mh��<���ˈD�r?`��T�d�-{5h6�-�͈�t�
܄�&�Rp2r�%s?�p�J��,�x- �����E��Titp���َ|����/�S8((݇- qP `9�;c� �jr� N��
�>��U&�()[Y3��Ӧ�,�  ���   y�| `��.{a+!��쁅@?���;��GUB������[P,F�������������������������������������������������������������������������������������������������������������VA�����������������������������������������������������������������������������������������������������������������������������������������������������������������O 
E�V�g^�`�0H
mx #K+Tk#x - 5 �o��o� 3 4 5 6 7 8 9 �; <h�Qo>%p���)A B� D�V�/5 F G�� JhA5
L��ƌ Q� �A�����X�V� X Y Z [ \ ] ^ _ �1?{�
$�m�/�LjztqZA@,7��-]O���?�0̈́s��5c�R�� �xX��K�B�FeEgGaACScs� ����+0-#'W@3?���| 
��hqcw�  ��B_qx�**�ti�{%�:c,�m�{~]gs�i��}������i�������,��i���	
���]gq{��隦i����O��i�������t�%���4M� '.5<
'iuVD��Td�eB�cUurc�i�CnzTI��k�V� �� +ĠjA�:Ғ��^p�B��MћD�r�
�!Q2�A.����:R$�lG��K���rYp�U
�
fA,�p�0�2�dx�,D��oýx.$T��"f�aVFc�dD���NElw"^�Z���5�� ��mbo=� ho�
V1V�&|IK��G#X,\j�r�I��~6�Lc 2~��CE<B�;A3�7�XL���&0NP>���A�?�VQ�Z�aW�B*\�� ɘ
�jؕmtd1csmR+����ņ4+k�{o��mTQ�9�-� g3""��-s�� I�6[z6�` `t4,I�;�����N�L�2@mB�
F~|˚��H�� Lv��q�*IM�h�7�J����0|d,kB��Df3�wr�Ll`@���e,:�!{D<'�d�Hf�x	lvaA�ɂuU6p=(!"XA]ý(�ĺ�8$�k�N��T����=������ђ46�!4p��czI*8S��5��y#C��шŖ1���A�x�?�=j`M/��Wk�<��M��Y��a�'�e/�#
���8Qt5-�Pj�>q,�do'�=0ke�C���u�f
� r�L�`}'�2��h�F�
�r
i��
s�	@   8 $  �؃  �9     �f�� ��UT�uˑC�����/��8�t� <��n����H�+���;�� ��tMwr(��@?�]�}����$l_ ��` ��?��� 	}��a
M�4�Dl����i�H�g�Ǩ��~��ػ^���<�l��!�=-��d��Bf-�l��M�s������n�n��s�?�V��Y6'��~� ���	 Type  Boot g_�� Start End
S�5��ector#ss�xte�o��e!BIOS Da; Are(E�i�BDA)+<#vice�ɽ>s@���!�LILO��}� ���м �RS����V���1�`� �6�a�
�aL����\`���u��\�v�Ѐ�0�x
<��o�s�F@u.f�vf	�t#R���S�[r��/�W�ʺlf1�@�` f;��t��ZS�ߺ�D���ߘ�f���u)���^h�1��� u�����
������u��u
U�I�� ˴@� ��<� �N��� t��a�\����`UUf�Sjj������S��`tp t��U�A�r��U�u�k���uAR�r�Q�����Y�������@I��?A�ᓋD�T
9�s���9�w���$��o|����d��AZ����B[� `C����sMt��aM��YX�����~��dG�f��t
fF�����_�������$'�@`�H�n��+X��>�tb(�N
�ˎ�����Á�^�9�v��&����F�T	�O �R	��)����Ӊ̿�mP>RQ
�MAGE�_�u�>um�>Suf?��Fo����*�&�d�T�t��K�:~�df��u7��
�� Ɓ}����#r���fh���+����8t������@�������
s%�-��t�E2�tW�u6�6���m��u�_���6���
r�FȄ)��#������� d� ��#��#��#����C�?��u	�mk�k	�L�Gߺ7��F���q���90����oi%��������"�������Sf�[C9�v�#�֦�~ɽ���p������B�f���O�����u{w�
�[r�P��(��?�d��U�����4y��>� Dwt4/+0,w�o|+t^� 's�6�cG�*_ho����	3���V�GOt����!N��l�1�A)��m��WV�u���
�^���*��/р ^_�AQ�~�����.�Y��][	�m�o�xa��(����=�f�[����^V�-,�; �?�#�u��VCqP}׶��x6�mX=
��jU�=TS��°c/P�P����,��!��������PXjP��IԭU8�v�\
�\���tŋ�����ʻ��v�^�T&�Z�Lh7�A>����;n��6e�܌�9�v�������eQ� Y��[NG_&G�o5G�t&� >�=x�&�B&vv>m[ln+�O"�$m�m�i�^A*��t�&P�X.[��	�t����H�
��	>S�fغ������X���x(Z�������P�@�
04�o�i��#�.nۀ&!�+�t�>�u������ ������Z4]�aP��h�\�Xtu�a����h�@ �[PQV�Z�Zm�.
X:&�	��)��V�R�D����6n5�*�&*Rh��-��(Z-cj�ۻ�rg�skc����'���nl�]�࣠[ ש�V?���<S<zw, ���m:�#a3:Fm��3k�-<�eS�
�$ <�j�S�y�[zG��� Cu��!S}�?��[�R.8�c��[[Ã

¾n���<r�G6r��w�f����z��f����U�dⶰ����br;t�6���Ө��ЮE�����9�����z<�8��f]ȳ���u���.�cd<0v2�f��f�����n�
>�*���0 l:��o�7�x[~�PR�j@[ �.��Į�[���t�.���J���R���R��BOۛk�B�l
-�OW�Ựm�]��5��}�	��e��ō���`@)���*�6S2�=�4��<
3ז�\m�Eo�
���d��h�~�o�IG�"u�!H���h����n�D�;�E�w���/#*�U�)�
��ԭ�9���ށʀ�V���Z��7CC9����W��7��/��A�r���]�#9�o9}���s/P�x�s�V~YU���Չ�J_�� ��	Cf��@
Error: DuplicatkVoluXh�V� IDҵQo�Zq���2Yr!�m�8�s�ʹ������n�/���r&~���_���0VA�Ӏ�.7��#a�
.�'	8�
<��u�Vp�[X^�'�oћ�d�d��h�-�J��������@#���B*N�~�YQ���;&�>L 	�u;��J�s3z��`r.wl�.n[j0!"I�my�%=,Fz��ڷP v@R�vW���V�{Ah���Z^�O��;iLo�ذphJ~� ��K|�����8�H^�Kz�l��j��R.�7�3�̟Z����Tx���C:R<V�h2�W�H�M!�F��_"���FD`^`��j!>T���g�X=>V�_h+Ȅ嫓��8�Z���}�r{���n����wl�x����u_<r[o�4����Z�!C,6 �-��������O [5��M5!�'Ŷ����VEu!=SAu�O�#Tj��
{��r',̬�r�m��
�5���K�<,��ɻi7���=�������6����
��w5NNORMAL�Qo����>)l�� kt�7Ggt
m-�R.Nf�����n�c F�($�w?�Ou��V���r6(@�:��uuF��T+a��]�w|�
v]u��Bk��_�V���Y���+V�����R�	����<z<9wH0rCuFII�<Y��Xtx��F��.���'8�S��sR��F
�xCk�		Z�r�F�Ϩ]�(W&�J��=V�/�4����Ċ�����0rt%y�
\h�u��ں�6w�^�6V��^�_lp[�+[�-O�6���@�.��b�:#��joading�dch����ecksuccessful�bypa
�	�_	s 0x No ���w"h image. [Tab]hows Ck��@�st.-O - T F�m�[Vmp m+t2�L��Dcrip7qp��Lm e\Key4bl٥*�3d/!헪}rnelh�Initr����yJonf���tDSignquB nb�ޗ�foun�0/���:� [qui�n�m��7�c vaAe$Ma��
>�Cj�Zm����5l�r8dOl@ml{�bkAtvChl���a�I�7-�Z{�Vސ7l�ms9��a�buf(�8�f.@l6`h8�B�S�}���iyr08��zdGl�C�Q�� 4Mb����_��mpoiu$^��24.0 :�\H����Nau�BO%_I�	��� �vԝ $y ȕ�"ɀ`�Jɕ��"�r�"�" 輼�U7hV��m9�#�?�V�F4�2��%>�8��N~��,��+L��+�C&i,��J�ϗ h ��N,�TҼY,�Vm�[�DV�+
U���@�m��P(F�A3X�����u� ���+��Ȫ���Gu�����"���4�#y2X5#�(�������6+˲U�)�F!��k��,a{Yw�VRt�,����%t���V](��X&#u��p�d@F,\p���S��"�gk!�x��"�n���#@&���6�%�"&���##Py%�����"�r�#���tUac�U&_Q�9�xm��~��=��-\�����Ū���)�ti~���5x�F��9���7j���[�d��lSu2�~iC�UA%u����l�A�� /�r,##��A�"}"!Z�f������A
��`խ�KA2ܪoG��#�A#�i����"�
�il�!��VA(A�q��(_(��L �j4A#(�"y�l�"�9 ��"�"r���"%�� C�� ����!�*��/B{!�a�V
��A��e�"Q�"�"S��V�ޔA�"�/&�"���B���D�4�"� ��2��_��"E �z�O��-��+蚭�C��#�o�� D+��x0��"�Ȫg4C�"�
䀹"R"�E2���VT�G�\�"�u��ɕUC&�eխ��<ⴵ(<_ .��U�*�.�REW���A���\i6��}�'|'���'Q:6}s
�.�v�u��x�p[�D܋!��7Z*�Z��C��"�"�ue�%-�&�����ؕ*�#�@�"�"��<�"�"�*����"�"�<>O����"�"�"�"Ʉ|�"*9Y5������� �2��0ߒ!y� �!�E8� �&�*� �# ����"�(�C�"�"�@N��"�"����"�"�"�"����"�"�"�"rT�g"�����A>�"�"�V=@���(�F�� �"�"�j����� O.��"��"�"�lg9��?{��!���"J!#�@F*�L�222ɁL222!'�L222E�222C��2222ȕ 22ȁ�222�4�222rP%�222��"+�	�22��.�*qR���+e �J2+e�;�++~���ͷ2r�&2�"� 9H�2��+�2���
�� ���dY���������Љ����o�C��)Ó�۵<��h��.���ɉ|m����	f��X�h����05r��Y�6����
R$��0�����vW.X�'QSP�v�~XP��(�	
[Y=R������^t2����ZI����Q��y}� ����.?�tOPV%$�����(���Cv��Q��;.�e�Պ$�F����,�l�YQ��t�طۃ��^j`�L��aP��m�\*��-���OJ -������::�d:DS�������ct#�"��A��u����� ��������Ŀ������ͻ���Ⱥ�ķ���Ӻ�͸�������Գ�ͳ�Ŵ��׶��ص��ι���������������������GqGNp�`�P�R�,Ж&��u�B
XZ��	�V�w�m6�h�w&���w]۾�^�Q�.TR�R��x��F�H��-�ݸ�׻����	���m������V���H@�Z�Y(�u�p�����H��N��QRPO�K��_9������5��]�M�q�����J	:�UQ�F��^p�
@u�L�	�W����	t��t
����[��S۷�ژF_�	v1ҡ�9!����rd�Jt9�)\��Fq��ںZ]��ۿ��Pt���Ht�6+�[��Ot�GtŠ����Z�M�BvAr��!
Q� �Bڶ�Kuk�So~l����;�`�ꋰ����,��`e0��
��˭����.Xe�����--�����";�t��7�Q��#�&��6����Z���
 ��*�8�h�
1��R���P����� �:0ܠ�e�"P�Z�ۖ��4n0:* �խ-�@�<��u�B�OS�c��M�d6, AA�Bu��'�Q�)��� n�p�������Z�ڈ����X�>F�U�MEN3��W���_�5�	�G�����n��R�Q�=% sT�vQ>#�_p���GJ/L,ת�x -��	k?*�Me%X�-8: Hitiyl`0yfc�� 7t�outSUFM%�o�Us�#@�}
�.��-�`��<d��-.b"��|�7"�"���
. ͫ�
.�X
���-�_��*--��-�@*�3�%�6.�r G����$��%A
.��Y%��`���
�?9H���������乭���C't������E%u��~.9�jb+
.3�<Ӟ#�ʂH�[��9%
no���H'�$J�C�D%D%�<������%���$.�EV
>�%��!��'
�����$��D
/�%����`�oG���[�V����g�ӚH'D%.� 9Y��.<@^�D%D%%/���U���p� �AU�	�j�6)سJ�
��4
�%ʛ.�i�\�C%�!�!�6��$�tpe�.��&*=�ɐ�*#*�t�6�D%�d*���%r%C6�%�$F'� �vp#���r,�2��#�l�ڤ�PX�����#�$N�$���$Sޑ&�$� �#(�$H��r6r$ Wp4�K^%x"�>�I>�!�;�!�--�ahp�AΦ��] %�&-��?y6���$��6��"�$�$��+�$u��r�!�db�$�J
�<��Gb�d4+u
X ,���$��$L�!y ��$ %����,-���$��u!
%�-�o!>�$���y%p%
%0�i�{��)��$2�
���#�D�44��444r2�$444�\ 44$̀\444\� 2444ȑ�444H3Ȁ444U�444�A!�$-��!�44X虹J.���O-4;�e ---~rI���\%G�<4(��\4�$\
d9H44@��f\����2 ���A C��sɲL����u�\�v�`�l4^D�������-�d��n�h��D���[d=�_�rw^���wq����K�)�@��6.���ds�������
�������4-�H��:P-w�6-oP�K*v���U��k]@)�@�����H��#\+Mݙd?��-���ANr.���<y��� o[� ����
�d�4-4lK����8�`�9G���-N��a=���Z�M-�x^�X��Vo[��;_"J�e{�L,�&aW6c]���6��e�3�:hF-j��Pk�LV6N-�,�7.��i�:���x��h@-��pk
:-�J����FDK�AA��Qx�K&�k�\��X�fz_�!2-�0�67�j\9���8-),��������PQ�&s
v+{v ���-��P���%���X(�c����D'.�6�)ѯ��ֿ��wst~������XI$�l5���m9�+6� /��ǈ�)��s��$��@P(6�P�[�u��ϑ ���,&��ƀ����M�-
,��u�[�{���f��a��\zY��]����.�����@`�!����7ZN�����D����������oKk�P��׉F��F+���^ߖZ�&�喠P�Ъ���#P�g8'XtP�İ�
GE8tnk�ZD�4#m�
@l���P�u��ɡ�;(�������N�^�V�v��v�����2�v���cm����l��Ts?���'���P&�����l��������ت��Ю��W�u�[��_ko���~{9~��韛�P���K|+�G��?_��F��u�kE
-�.��E��W�����Q^�F�&-�z�?B�&���i��(tt_��P��m�/�t��/��B�]�V��<&�?�Kl.2}G&�g
�b������@㻿Y�uM�uEC��Ķ:G��01�i&�v�	�� ��P�ws͒��%�7�(�VBE2"�.����=O�wf�=��VEnYO�lo_�)\�����߶��Q	 �@�����u��$�f� f��A	�a�%�oշ ��{t��1�V��$<.�\�OAݻ[t1���. EP��<��a�tK�1c��\�8�,$��g��6�^�7b?c���S�w����mU(�?���L������Z[���7��~�=�F`^��P�·��l
WȂ`h7���	�˺%;ʡ��R�{��7v���
���D\����C�Nr�h��k�[��K��:��K�����τ�7��)ʻ�%W�
V���~�-������g��x�B�?���R��;"�U�9w��t�&��mi$��
D_&ki�
��\0��~o�[��
��Q;
~�Ș��2&_���)�@Nu���n���^Ţ'�86$A~�����N$��J�0 �%� ���#�1���6%C���%�"�����.��C6D%���A�P ���2�&�6.7�g+6����$Dd6Ģ7(�O �/�.
q,1�l�|^�]��	��F�� �����ͷ|���SV�D��R��"����ۥ�V�.�`/fRfю�����������_`+B}$B����达:E���x3�/����6@�p�i� a�_��ve
$y�e���VPT2��k����D
Z= ��K�6b}�X<��mK���^[��*XĦu s�int#v�jN`���E�	Pt�7�B�?R�CQ�"!��ѥ��|�"$�"-�7��\>��nM����D��UI�U.Vh���A>`绯[�d�g���s�	?�f��f�ݶ�>�m (}x!��#����\* �h�8 0d.
oq 9��DMt�Q��<U��|��(H�2o���
��$�ĉD8V
:P�Q XP�Q跢
�x 8��Z�������� �|����A�e����(~�����7X��þ
�,5/H莂i�O�V�.2�2 8�u����҆��I�=�,<��{���΁������/5��^PS6�?�t�u7P�G����@@dXu(6y����.f��L.���߿�w�&f��ֲ��D�P-#e�8��.M�$W�G�o�G&��%u� eb�(�>�V���C_��@t�H�zk��ah6���j�O�����-h���-�^��jTD;``����a4�0 �
,�����]�sA٠6�FvjSD���r; c�b��`:'���\���
<�w��t,�<w"8u�f������)�����������؃��a�QPR�
 $Info: This file is packed with the UPX executable packer http://upx.sf.net $
 $Id: UPX 3.07 Copyright (C) 1996-2010 the UPX Team. All Rights Reserved. $
 jZ�   PROT_EXEC|PROT_WRITE failed.
Yj[jX̀�jX̀^�E��8)���@H�  % ���jP1�j�j2�jQP��jZX̀;���������P��PQR�P��D$V�Ճ�,�]����=  \  I ۷��WS)ɺx  ���)��	 �Y
S�SH���
�� ���R)�f�����{u�P���G��H���T$`G�d���o��$Y[��@Z���PO6<��?��u�PP)ٰ[�'��w�ogu����	W�� s�����[u����@�H����_�S�\$jZ۷��[� WV��S��9��s
j�k��7����t�G�B��s)3�9���{U��/�Ӄ�E3}{����E܃: ��GU�������m� �M���UPX!u�>)��M��_um9�w�;�oo�w�s_E���u�P�wQ�}w��v�Ub�GϋU�;cuǊE�������t"��t�� �w9u��P�۶�E�PR9��4��F��<���
��U���v)�R��A�e��������t

�#/��ˈT�	�j-.�5\��
f`f1һ |fRfPSjj��f�6�{����Œ�6�{���A���{��dfa������}���  ��f`�廾� 1�SQ��t@�ރ���Ht[y9Y[�G<t$<u"f�Gf�Vf�f!�uf����r��f�F������fa��b Multiple active partitions.
f�DfFf�D�0�r�>�}U�����{Z_���� Operating system load error.
^���>b��<
u�����                                                                                                            ./.porteus_installer/extlinux.com                                                                   0000755 0000000 0000000 00000205310 12042203255 016124  0                                                                                                    ustar   root                            root                                                                                                                                                                                                                   ELF             �� 4           4    (             �  � �
 �
            ^^              f�hUPX!�
 w_��U��S�
  <���
��4[����]�1�^����PTRh,ChԀQVh۝����#�r����$�C���=, uJ�����p,-l���X��B�0������9�rD6 ��t��o�>hg�~�����K�]��o���^�� *PPh4v�ə.i�=tW t%���
��u�Ɵ��ht��H�k;�����19�Lu9�u
���~nu)s�j��6,+%΃KVMw0^uD � 0_��s�.� ����u��x�O�3i�o�p3dU5PJ�FSƭ�ĺ
r39[Dp?�=+ͻ��&1LC���\�����ȍ����P`��+x�u>��(\`_��J9Hu��$(PPQSWhx?��ƃ��Kp�P72�,H���`dY���HX��<d��\�����#YVuU��GF㋃��j�@��5���� �r0��T��\��ll6O V< �x]��t��- �t�fǋ�?�6IG��	��BJ��I��÷� U���hIN1=�?�>��E��ۍu�9
���3
��st"	Hl��=�v
+�~]�> h��s}�m��mV$f�-9}�¬��9E�8�W�m4�Stv���a�|�^ǒ�t.ռ��n�9�u"�6`�3���u�Y76���5��7ֹQrRR��˪dH�@��<��
�>=>h#�+=DM%��.=FUset=NTFS;�,�Y",�8�ɱDWW���Z��4V�%���f��#�BSL@���!3_�C����,�Sۿoe5~��
��oM �l������=htЂp�8����^�B<�Bp�	��%#�ڋ@�{����8/ua�{,y0;�"uS;�k.Q�6uKR��PH86ohd �u)�:.��`l���ߟ�9���[�uY����鉍�;[��'d�:K=H!�Fٝ���]$��R)�SvD�qj1.��8����`h�S_6ؓ8��SI�@�Y��H��'0Q�RR���dM<@�6�$=W#`H�VR����}(�� �j�3F%��?D6�H�wp;���� 9h� �f-<�S=�4W�e�aC���T��Ӱd�fp`tlٮ��^m�
�$��M��	�P�ȓ[��xKE���졓�!� �;dzw1�eB�t�O(u�Q��fE���'~Y��4$?���0dA*����윜�Ӛ�ROu�Y��!�p�S�}�xt
�lc�P��8�!�<�2J�p��YnlU̚kh����(I��t����;=tQ���!�;4��yȑ����_��Í�/�;/u_�j`�P�9�v�K/R�w�k��ǈ�x�eo/C�j/S`��h��
R/YK땻eQ��.KE�roWl_����wR���@�`  �1ݐ�e��K�R�d���1�'8���F�W����t���ۭ�ߠȉ��u�P�W�g�&�� �|��� �t�/�������n		��@�� wsvf��[!
�x:�hS�8�Y:�f�`	�b���v��d�@Pi
M����0
]�u4\��QK��~Ĭ�mM9fg��
-��n4
�%��=}�t�I�8��J�M�g5��i��%%�|	+�tR�K � @F6�?l�5��#VV����85#�h�a�N��{1�������L$��q��Q�[8�0j��(k�
�>�ZH�����V<�	 
AU؈� ��F�+�}\u]1�e�vh�b��C�PЃ�w6C3~
,�<��
�x��C�����8�@�rsPU�R �xuK!�Q��C�q�,�Y��@c ����O�x���0ѕ�@�/�9�����+��c��P���	�&x���܁���l[����9	�	��,�0�(�����5{t/����-�C����XGل؉��!ǉ{$7*��Hu�O-u�-,�ص8��A�Y4���xk&�5�V�NYFOWWWW���KW�E����V�/]�
<=<���Sl��E� >��|���>F��'�s^edYYZH�F��3��u�z��G�7L5�w����8��K9N u�Pw�m^PPR�vw���C(��=ҋ6n8�#�u�Ռ ��]��PR 4@��
��LSocĉ~��n_��f�A
>I��~1����G�[�[�&�Z~� ���k�����
�I��[�N�u���j�ء��� ���V�w�Dno����
�|�@}�6t�۷7m9�dY�x���	�X�ׁ��w+�1t�[�v�3�1�'1���m[-
T�#�J��������Ⱥ�u��S�Ǹ��9�[��{����Z���G�90�%ΔU�x�6%�����������T��Lޑ��L�,��}ԋ��PT���X�H� ����>�KF9�}��b�,H�v��M�(Gs�6� ���M9f���UBPPO(���방>C������f�+\ۍ�� @;,|�S䴄Ļ�R��%��Nċ�OZ��Ѓ�s%r_MG��9R�}H8��B�
I�Q)p+�=�I�z�_a`���e��).�AxYX1�K;��$|�KLIl��
g*�
k����}G]�@ǻ���+��fY�l��)wr
M*�.�}��+3,*�/+�	��)ьl�,UH!O�2�]�S�a���v�dO�r0
v���i9#hW�%��m�oasu%��%s!*t5Y>ېv+zb�(r�8���l��@ t8Rs�]�C��5�(s`���>�#��LP�#+�1^�+UW4�L�dҔ@����.$ +QK� '	����hQl���|���%�p��0xd��!^'T:��|�(��l�l�4�s<g@�L�[`��,F��,F5M�����*'h_i!Ċۢ�O��\z�O�Wӑ:7���(���-��r-�O׆���>�FG=(4'�~@����u=D�<�16(�aSS2p 2S��C�[XW:��K(IWRQj$2F9��!���">E4Cr Q��x��ذ�@)0���J���� Ӏ�ʾD��.�k�8�¶��)ԍ\[�z���𹡹9�h��R��	�}7ZM������;X��rw.�v��Iu������s3��KT�g�P^hf ��;$o����H���5:�l1�:xK��3%�Hk�8�DtF�g�� �we.k���Z�S(\�)xQ$b��.ڪ���| ��5�w�{��9H�`�drS2K���C��	�	Щ
䐩����՗�x�A��@u`���7�tj@�$R�u�Vhf�SۭԲK�P]�m+#��C��d�r*R�,��}YXA��DU��e���3%�6���F�o��+H�M��-���[��<�^S��`W�Co,�jw|R	Yj����D��uc�m1��P��PMH@���^?�Q�M����e��U�M�l�[�����4o���KT/�Qk�����r�u��F��� ��BCj4]�( 
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
f��Ӄ���� �U�LY�$G�B��@�O pK;%� ��>�׍]]���տ���v��uM�ϓe� V��l.�S 
�=�_��-�Bh�<
�#uWUR}j� *ZЁ+������&��JU��hа�,��WRd��*M�����rF�Ȁtnu	��K��k]�V�lP
;M�n�nReo���g�0_[]���0J�t���^����B�0yd3A�������l�J6F"XlJ$���3:��+0���Px�U�,B�V�y!W=����X(;d^
�|�9���$�E�O��L�t�;T���nmJ�
�|d',�C��Oۍl6C �0�<�ԅ\��G8����m�Â��C�2$�%_�^~�B\H(Z����uUU�*�<�6�C�Y_x~F0�2U�^��� f�&�l����v���f�F��ML�<$J�ⵌ.[Sh����^8��A���t-��Y��Jt(�K �ѾT"tp���j�Pk�����@ ~p)�f��&�[	x�xJ+P/D��o4�ۉ����6���Ǽ+�l��gs
�9�i9�|�J���yY���1Kǉ��
x+u�GXh�����o��sp��u�*�˞�jd��XffE�XӔF�Jt
`�k��f��7��	F�G����	�}Y���n��t",~��U��Y�b�B�; ��vlY�(�Z�Y�s��&@�	|�#ƥ���Fd{n�$�4I(CF��e,R0{4g�`<��?�ht\H��ti��|!OW�rv��|W�w�!�E�U���%`(0���`�>��5�,$�YG6�'���x�!,Zl� #�GI��ӷ�~
]l��t0��3��{,�AA00l
#5W:_��v Y~�B�$P4�� �V$^9v��I�2�X21�[�`�˝�5��<:<*��`+t/����oZj,>��>iV�m7���p)m�RU�9���<q+0���f e�w�x��E�$E��45:AL��Z�i[I7�͇v8�WdH�n�Q��+k�i�$ �M��N}%D��:�j����Hu�F����/��Ն wu���wp�o;OG�r.UnI�Z���s�$	)�U(5�7�P�_܉��W�8�X��M��$)��P,"��6�N2V�lH�x�I��`ٍ�|ۍh�+n�K��9�v>H)�(P�mR0ڧ�]��7�N������ue۫9v%O��~��`0���V3m�;�v���/�FѺ��fѠ�l65
T��ֽ5���H�_Z�[��都��~
u!�B�P�փ���ۣ�+��,��@ ��;Q�M�w��lr�w��7�ٿ?[��>��D Řy��Q�ݕ���R���f���Ht�����V�\��X���`l�!э��+�Q!E�P���s�p���c�v-�8-u�>�A�"��Ш{���	�pd��u�)�:�y��cO��,tt�R7���v�	��:x��M	9�wu
<0�G�;��0)�R9�����R����d�	���I=)�@9�a�e�r�	I��;Ȩ���H�%�_�aU�3�&�]�t���6�0�99�6x��ZACv+��'�����lI�{7�i8�*�'=u9�� �ձ$!�3Z;/X6�	�+A;�O#��W4_P�X�g�0JDP��lL��}V����7R��VQғI��m{�jQ�>���z��O�K�����v���)�̨N��r��,uR)�2BJh!�
Y�x�zu-���^i�-���L�oYQ�2�	�]̀ϓ�J�	w�/k���N�!8��fV(�	�����jH�����%�@�6("��.(��Uex�*Z��9B�G��9a^�<��h�L� "�N6���wNT�$�;ɢw�x/���C�Tǁx+�uqPL:��u{�HU�t�pP~��p�L�(G/�
 ���,�JP��g�C�"�PL�����*�>�
tp��({ix|��0���[�$Jk�z�����%d���o�y��#c�m�A��
ѭY!����!
�{?۶uM G9�0dt�>�Ԅ$*FF���/ D�\kA9��{��.�:u%2�Ѐ.�>Ǩw�2F���p.� �Р8u���F�%�/p���)щ�J
��Q,\�	F6@2\���EG�{��P�pE�:uU:#
�����{莄S�	Y�ys-�S�!�cHV Km���6\W ګ7q�O9
f5@@&��>�@'z���r�����ѿj`~�����!��E �8#4EK�;����C]�I�-P�I�;MG�(�^�胀�C.w��_Z�J��^��(��uT6�ػ��T�If�><�߸t���<~9~t���RaG��i�h�;w�u��(J�X��� "lq��UY��X��9Ft#�s�r�G���˧�[�L@	L�vV~&��(�&M�4�O��RCRgDJX�
|a�2i3Gh%�m��O��
9�X��r�8ۍn�-�ruF��
��TM�;<�tnu��d^:�+��8lǢ�P*_HVy	�9�u�X�
8�=B=�/_�W�|��ur�u�Ɔ��_W�5 C�)�;t�nX_����
�a�-�-�.�)��R��CH�/�l9�u�Z5��Vn���on.^8�ۉꋲm����H?j���6)ec��j�؉���ŏ��t��߸�rv����Tr;ݡ�{�oPX{�:�K��oR.hϺ����b�5^뜉�9D5����M��ͽW(K,�{o�'���R��jݷ��	
�A��d�H���M��;uu�r��R�RW%���{���6p� }lBI;[ �C�
�#�ZY|H���VO�ۆ��x8t��BÈ��@8��(7��S��犸��X�e/�g"~	�2����N*��+����o�7��D�s�Eu�a,��I�h�_�r��-+ZhEAh���Vt��D�T ^j�n�Dn��_#D��;w&��\����Z��� ��J�R8��٨�$n �h ���0���'I�v~��`�nd�S��
�8���`_�8�@�Q[�n���,�����h�WL7�׵�5PB��=�6�;e�9��)�Bǎ�_�:GK��1�p��~$oO�uI�u�F�);~�> v8��
~�)��E����mE9�#r0�hh��6��΁w�ʉ6 ���fŴKp�X��G$u
�������y��U��6;��rYJ�>:�u���tܥ���jw;Mr6�9mk� D+_N,����$z�綨�0L�!6�@��1��[��#�4��m[k��~z{"2� �D4�	��� yXx�N�$ z}�OL8|�f��#h�m���c��i��K\�OE\��Zrk�@lM �M8o�Q��9iGK�B�HD&Oy��B�'w�,�m�p��5�B�B�YXPlPu�n46r+�m��]V�A��������ދ����\쑆�勋�5ۆN0Ԑ;4���vB5@�q�ף���F��׶�N6�����V�VтK��l���~��t�(�H��us��b��!��$|�u�w��X:�i{�y�{���)��^sY�#��w*9��v�7�1&D�<$c	�7q)�T�y:c��8xd�������I�9�r�7�H,�.���G�)	A����\�� P�����ve�۱m�W�z||��L'|w���k9��T9�P�{���l
���9�K#�GD+"jU�x�r������.�ѯ�()��%`+�4��B�3[�U
fp_9�h�=m]�[t���;}1u6���8��ōA9Łot���oI�	zz������r�)��j�pX#n۫��@m=&uO�Bs�I��x'~7
@�l-$�`X9{p�	p�����
�f��͉�U8zOF�X��CSn=�/���2�ۂ+0�J(-���!�s ��+q�9��M�0��/�	j�2+kC,�I܏(�+���atRv�,((�E��{�P�܇>�^���J�h,}y����6��-��s-��Q�]�n�tl��VW�#5�1�iF� �$�(���qp����pm�thp;���B9�Ϣ��������lD�_�Mڃ�ﾨ�-�Y9�u:���D07|����)�h^��7�)�PfH��ڪ�T��DoN4�G�s!p����=��4����&8-p��~cq�'mE�s
\<�$����#Ox#���-�N����uڧ:6�8)�֭P�E799G��
�I)s�@��,tNFO����:FSyM��
�V|˿�f���� <$�><¥��������)Ŭ�+GJY�2�`��?�W���M��~5�v�LK�Z��c���ԑ����H%j
��wQxh��0��x�)��`�B��\`v�x���(���~*���y��� u�<+t<-,�W(6��'�j� Й�}
0�F��B���0�<xu'��q{4����10B�P�"wf�����<���B�<	�7h�? �(`v�����9�}6FLM}��:/vX�[ �Ap��"��X���ϺV��c�o�
����������Rh�U ���p�s����h@�_mC]��|7��Hm��(��`�V���V�/t�Z
�4_(�
9O�߳m�����+��K�ޱ�
u
 �	�Ŷ��q!����Q�	$9�=�*v9��ދ�~9
����ώ�B(�d3�p',�-�AB���U�9�04���P��*T�-_���"�;al���v�'���9�A�t7�jt%&X�Q�
�y�&g�_�Y�@�P�Q��A�<=�db�A 4�#I~1%�GΔ(�,�֪:
?T��\!�	W�D #�
Ae;�tƁ����u��=1�_�o�E���!?qA�xCgG$��
�	�b)�p�X�zX��刿]v���Q?�uT� ����S�sL\C�����`	��\� 
E
u���0���9�N��l6���D5�
lK�4 /$Y�B�H0��eBz�j$˲l��8�n<(,@D�@pk R4�VL��������lۉ>/�X�le@���� edd�,48@��DHLP@.�T;Ȳ-�X\X�\[Y�7,0�n����048L,��a���HL��,�PT��/��.7���kq;��(V�X����XJY#Սj��Gq�"��LN�~ ~Gv�=>}��
 Ѯ�%��
 �)
(n-�\wc��r�p~�6,�+���ą)�}W9N\�
ݟ���t�o���
5���וj�U�BGgU�@�X�`���<j
�2W���T�� ����l�Nݵ��'�()�PNE��uU�U��8v�(~���=�n�[�mOP�<���$
?*O�#�%�J��\u`O�'�͂pc:���\L$/�]X]��
mE0�.U[m[J�J	A���6h�R�_�L�ZH�@u�G�8f��{�G�T�W/]Z�>{�����5:{;W��K,j��	�0�uH
�E�l�)�1H��jE��
n.$���e� dY,NP�(�$�5��h#
)�%<('eC]���u9�y�؎
��GR�֨�EE���&`���)o;���vLwI����y8�Lէ,���uDԪQ��8��9�i�RWP���`0V���f9�a��wzPnOձ1~tyUj
i��tiP�}X�t^�4�V�CU�L��u���o�	�
�a��o��R6�)�)�)l}�.-�;�tD���/;c	��<��u�1�V�G��iPR-�A�m7P��7�
�(n��҉l�'�K��"t\��)�\�ҿ�Y�O
�!O���±�.����維��pJ=�N3^���.#�
�02����G�y���y�\�TV`��
,!c������A ��9�p@
����x
�ݡ��	�a+�u�fc�Q@
�+��+�
���hRu$������������ٞ���L�B{-���?��@��>vv-����
y{�u��Y<[?u=f�>X��B �Ppΰu*>�`j~�J�����3
�a�D�\j��?��v���X:�w� ����:���v0� ��=>d���#'G	\�
��m������f~q�r��
��B0��F�-�6Ȭ�faݍ������UB�B��f�*ܶ}@���l�8���=��4��+�w��9;>L@o�4$G��2_���0;��b�;|�
�+lq.[U
)W٨�_�tѥn(��T�j��$�ֺ<�h�����Hإ����@^��E@Ԅ�Q4�}��UW/���(�	� ]3���T�x/s8R�x$�1�u(������ƻ�!W_�k�f�r��%@�FID�p�� ����=�,�#�	Y��LUG3+��6�	�ۂR-xn�֛ u"�Pp)��Lo�șB1(W��7��UY�_U��Φ/��N�w�X��@����X)g�dᄋ� �����-��($v�0�'A���lt��֕8m��$��h
ҝ
�D8�MG�F��a۶V���B��~�3@��<_2����F�>%u߉A;�۟XX��H}��u��.��d� "l@S�d�2[��!$�=�{��R)��DA��&���(�1/� foP"	щ���a�+O�-�0��+���r3U=x��.B�O��P~����� _��ܫ����c6��l#�{7�T�n6�k��3�7!�5��]�Am�`�$�o?'U��ٹ�H`8�h"{� +y���5Q�qPZ=�T�uDu�u%�� �����0����W�&Q?_nnQ�Qy�^��J����.�0��,\�7Y��8�=e��XNA���o�N=Fơ/^
>t��
�-�+����@�$b{ۖ�L(/]uL)������>���-��'���5��<]8F�k=��q��
�k�u����fW,����:"�ct�i�E��\�9in���t9��w<�DJJ��>t?uuȆP<b�07@<�G�	�)�yY^ԃ��e�x˦�ISo���Qp�Ram��&�t����t�J<�H�os���(0x+4��T'n8.���؈c�H5z$`�N��'� n�5B��V,�>�-[	ض1F���^b����ĊP7���u
��6��%\S�
�B$��j"�~�m!J���Z��^��nѹ�Aj0v�J]�8>�E�
���7�\��-ͩ��.�\�h�}����D�*���lgP��4�)�j��I%	��n��,p��5r8*Gk���z8ug{�v��)�H�G+/9���xn�H��{P	3������ }#`{jE	��-���Em�f��
x���t3ǋP�tJ$��J�= G�;��^�B�XHvx���t�N>���+�.�-Q�<@	BBg��Z��iӔ,
�C-�������H�;��~��&x�۲,kL�=h�8��@�������˸
b���	(O�+:�p��a���� �n�� �O<p���Bm(�w0R��$�;B�W4YXnXt<0���m���;7F�1Er�AƉ��Z8|�5]v��p5�;�2�s��,
h@Xs7��I�<�����i6B���� j;+�����.iL�-hon!؋s�[�3�p��9��� c���f�؋/��7yF�Z9
A��b/���Y�`b%Ewt��¢Q���e� 0]��pԻ��t"k8��E�F,�8�	@�����Y��WB�
Π �XOI]��@q���`Y�wI��QD��X.����q����K�"!G�WBt�k�ZJ���B�8 
ԃ�	 m+�ߔ+�X�p�)��XD�q]Cw��U�h�^Y�q�Nf�
�=��"�9)#y�s
�nk�k�g��݅}��� ����}��AA��˒RE!�mE�7BK``J���'xk
����

�<�V耞�$��� �dJ%$9DF����I��E!QD	bn���t����ؓh?�E�\��~�.��j}���{sY�=��/��\E����Xr
� 
Z�QK��8HA���bA0B�x
2�mI���[��l4�w�&sҕ�Hލ,,�,bk9�пT
�o�~can'�rform h�[+�e searchJ5ult bt���hs�xt234 v澵[fu+lk nt S��o�LNoJa direcjry:h��/sta# +��v�nF, ?a/3�k��/4�r s��t[���em6/pr�/mou0o/����etWbM�P1�k�n�ic���ٰ�^hq is6�C�48�=�n1o� m�-X$W$nlg)������Z��'+fIgeom� (�}.H-%%�d�:wad�	s(s)
  �\�(oAh[ůk$�b��i�jually&چms.3�/.�njrt�lu�cc	͵�*x?�v��v �tu�
���nz���h���pd9w`̐,�FA� c�T12�6���|3:�;�U�)MS�K��WIN4.01�ritmdoVxbo�0HF[���\GǲE�)u6��	x�ldlLuxX�b�._=�6��neUu�9�m؃�v�XsͱFr]m8A�,���wo�1�c� ���ZE�� <-ȥ��R6r[!
�����	�{P�AN���599�@݋�U�� {$y��!<0���� �  ��[�tlf��� IV;��u�cie�څF�s}��bu�2����5r�Sub�
mR�	F������. �+��0voׄl*W��(-�UsaYL�:Z� [��]���ZS�- ����Y� -O!���8껵e�;�� D�{%��ar X�f��~���f�6S_ F�πk
�t�av��3[�M'V�e��-$l�
��2560\2�6�-�Ьn��D{���*s�,�}�HV��ۍ%C6��y�gha1m���9940yHP$g�u�A�Q�lvU�Mj�nk�w��%ch��|�aH�2N��+���@��)g�4Bk � �  �I� � W=�p�  4 	-[� < � d�q� � v�tB� * � %� >{��6�f�i~E��Yd/���t�U�n@�z/�S�ds�NsNH��r�f@�v?#h.i�/(O3f@�=M��GmKaiR�����t:f�:UuzsS:H:rvho:OM:v���
�hM �
B/Lh YSL����UXLXT-%����#AIFH�ܤ�4z��KSB.Z�)?
f[|����3��d% 	��[�m
�Znkw bq)���l��+60x��r�� 
�lLjztqZ����wA|f�[
qOA��B 0�s��5)����; npxX��X fFeEgGaACScsK X��+0-#'I<
L�=cpuOٚ)Y����,�%D:	 `|�mWJ������i�������Ͳi����}4M�4)3=G �7�Q}Wq{�4݅#[e�4Ͳ��#�}���f�
,x-a,�:����Ma�Z����,7y%c*��Dkq��%un�PCdooiz�$���%c۰��eg�9 V�jz1,���& �,�  ��  �| � `�{a+y�!���@.�?����;  F�/�E�O �F n ��K/ NAN� ,�e�@�Ȁ?ȁ��AȀCGO�
[y p3���Oi  �NE��А��Q�m6Dd����"h�1
nR�oG��-� C��8sG�EK`8 T*�yLq��6�3�XBap(�akoi��Xlb�X�qT�)ě�M�r��bf�5I�X0\{ek|0-��f�G���B�K�k�p�U�$�ˎ5��Z�7X�2.��ò b@�qrO�dx����o$��K���"��dVFc^kLi/��3��!weQ�B��-�els��~��`�o�c�b@sۣ�x�
&�y�v�IdY�e,Ds�6qvdCh�I���fM�Lc 2~���e�h44`�F
Wvs�wcod1cI�p`s���Ҭ`��k�����mT��7�Ti.�t6a�p�O-s�����M�*���sP�twlx�m�P��x�ߌ�Lbj2�6�p�
ɂ��=(T	á+zy�+��v$HgnAeN��K�N��9``.�x�-�3��4o|B�>q�cz��mI�f$/����9y#a��ز1����j,�b�	k``M/��s��՚� ��M�an�a�'��5a�#
8�#e�j��5�m�R>qj%�Zs���l�3�e�m?Y�u�f Hop�
r`Vr'�!h#�K��grrյ��w%azN4tE���[d0ST�+�Tsl��"?+XENIX���&c;���ڭΕ_Rv( �U2�Az��I/O�D����h]a��J�&�4\�NG� W`�6�zK�n
i��;	��z��zR|@e���<$��*6�QU+AB� ���
f�u���QQ������6|��� r �u��B�{�w�|��rl���U�A����m���[C��t�F} f�ﾭ�f������ �������>��;nut��f`{fd{����D+fRfPSjj��f`�B�w/a�m���dr�1��h��Y*�]�`f�6|>��&��/ܶ����5w��A�ň����ָ�/8D��1��ּh{�������@��}� �t	�� ���c�/��������t{>�Boo"err����or
���>7���?�� 4.06  �����3 �0�5�����
��^#o�;$b�m�m)q�ic�ځ� ������fIdf!���xׁ�I0��� ���u��QU� C8��L���W�������]z�f�� )����>�!h��	�_����Q]EUS؄��<��II�9�v����vw�����`�DOr=��oo��l�[�VXfZ��)ͻ���u�uMuٕ�.,�u����;v�|�0��* Loade��'� -�CHS EDD  �U7�������Z��J��ӷ�]�o����8��Nf�0�����K��fh����> xP��������!��0	��4^�-�8��3�~_4��F-B�
9�s#����
R�� d����]�D[X$"�����ņ
���p��������������c��ɋ� (����w�#&�0�<�<IV��х7w^��w�}��/uv�N�8��R|u�rB)_(?u��VJ3�t���u�Ԗ�h�zӛ�oܔ�O&�
'�\�f��P�]�� �.comMc
bt��<YX32�bss�e9r/	in ��ܺ�6 
�����������om���V��
�����^S�#@ �����&�>�U����V��~h��ش� �m�&N���7��q��&�G�.ut�~T�����W���F�u&�,+��������
f\���^hLi ÉyMw,l�G{Á�M�yǷ�B,�8�7&8����HdrS�&���8��mo��=r&)$��DHn�\�	&�,?��vs�W#�;� 
ύ�vr&���8�p{���T`k��v�@��������h�&C_z)�����ԃ���!���vጘU��������>�8�A��\<Ww*��]B�	�D�)��K���_���wt�v�d9�Jk�
A�|:�E��&��ݖ��ru����[���tS��d���
��<hn�0Q���^z$����؎м�z���� Pj �=����0�
��% �����ۣ����m�fHa�?�f_t%�nж��`07�*y$f���[.8�[>��þ�#��X������H�I�6��ѵ�sC��p8~����1��@ BX���$0� ������&���}�� ���B�&�����
�D��:F����������F,v��ϋF��v(j!ZI���hs���l����3�*6�+`���K����hx��[ci{)�ގƎ����o�ۿ� � ����������O�#������ 9X����ÊF��[�R�K�F�v�6Z�=$ѳ<��J��>���������Zۣ��oE��4�SYLIN�`�UX4h��un���P��;à
��o����9�L�8�
�� Է�^$��a�
�h/�t�B����h����eU��V�lvq�
�  l��4�
M.�؜��k���qj�''3�����@a��x��m&Uu5]��n��r{
EXW=���C�9k���f�#�]4l��(����	E��;0����	SS�[h��S��
ߪ��:��8P��ÿ���ԍ:y�:�W�7�_r�<-s���R*m�[��QU����1�����u�����St<9wM�
����
��Xe,0��-��_arfWk�Kot��H+r&�R�y�\�B�_Zr������^�%�3�u�eB������.��
Т���(l!��)�s���;\��������e��;��`�&��X_��A�����;�m�<tg<
:Jո�����+7��#bu*�C҅�4.���<��2<u��H�B��c'�L��f�`c7��m6Dz�6���<�W�u�0������hi�(���2�	C����#n��6��<%�7v�Ж�h���
.g��
�P� ���, D%� f=�6��ENDTu� XT)M����é���^
��n[�q�[�����u�Q�w��j%
8	���7l���)d�m��`���|��"�����/hMA��ϮŐ�Q $�6�k.����zQ�ڎ��A.7���.g�� �A��~�޺G.f@L�.un.�&�.�/qkMo��$����[?�-�V>�O�����m��d.���@l�
C��&��V}LL��vY�0������� jd���:�	`����j�
yx�0�0鸥���z<QY�?�Kt�mfv� &�/DWz����j���m�c�4���\����� �Y��É��,�DLB����j&��XXM�z0�}s;��6�g���oͯ ����ûƯ�,����U�.�8�]p�¥p��1������������r�(=Q��K|u�>w�~rox�ir� w�)r\h7��(g�����޵`�.0U Q;z��b���ڨ��K�	t�v��H�'Ž�40���� ����NL���H��r!P+-,������x���m�3�
��`����ۮ/��̈&*�Rmahh���;�_�PL�x���r|�ת��=�uq�XL��\d���qVL���H��a$-D�r���Z��Z�T�!^�L;)�����NWW���_;��mT^%p�`QW���^��Zo����(.� ��߾�6P���h�Z�4 8�t��V�Iu��$^�5���Q.�ТY)�w����.W ��af퍿������tc����ڭ���$A�AVU��
4uXY��Ku��G��w�����]^��v�ú��BH�¥�'�_�<v���q����<r@��O���
D�
ݡ�oݏS��l�a ��E{�t����Rp��[�ZB��f�}wo�m �=�PAMcɱ$��-@�u�u.�
9U�7L�#��P���׮V��C������Ankx������%~�X��{%VQ�~�7��j��	�6��JIc���>����Y^�Bf+��]���r	��l��W 7��������B-ly"�rb}�U�
���NXAk���:� ��Pr�ڭ�h�
˼Rko�}*��,ͨ��rco����˪[��+����_���T0�|~V)x	�x� �Mh���@
_�W�^8��e�����C�@�s(��
����b`�� tTh�T�D�5��h0���.�w���E$1���x��hr[

>U ����90�����E)t��UZ�#�~�΢� 6� а(�poO��؋%���3t��������nw���t$ �J��ay����WVSQR����(�|$0�V89�����v,�"��F4��t�D멐�F<s3..�*����1�RB���!��Ӊ;*���B)�)�'�/���@�������F)
������n<@r4=�W���Fo��$F!؃�9QR��5�m~L,0�oK��At/t�HQnmsn=C{74r:=��ݥ������5��
��ƃ��~9�r.����s�I���]p������V�����/��%�XZ[�+�9�w���|�.��<rNO>��;">���D{����JFGL��ȳ��{���{?ϫ˫��10�jh�������T����7w����)�bҍ��j��c������	�R8x�.}�;�݋K;��������Z0Q�^���牯�B,�oT��B�b����)��z�ҡ�m���/ l g�s�sD���v���>
m�۾ ��3�ʀ����/� appeWs your ���[�putehaonly 0 ���mK	f low ("DOS") R)�m��.
Ei#v+si(����!Syslinux needs8to b��~)D.  Ifa geqt8����>messa 2��Fd,sold dgn!ۻm�Ctrl ke�w.leE)gnm�n$an#I=wtaֶv��w?fME�
A.. ���·y(Chl-ܶ況�m"ski١��1 XZ�
CxKOM���N(V 4:.5�3`"32R!Y�	�E�r��?��jTP�Ec7a �}a�Sip_9 �[�7\��XKERNEL?)h��ۚ.-r���;��F�[O�-�x���"5p�%�����jCOUnkn2��taX3f�{��(�M	>F��^�aQ).���YH2��0���o�jA20�(e0c|��sp1�!yN
�
p�ҭ@>�chz��c}Vs�p	���|�N�u���|�7��t�;�����B�+���9/������$^��<K)��YQ̀X�����@�	�%�+���2 ��{�����R�P��̴h�)ӟ�6������0 � e��|����N���R2���7G������8:o�����_Y���L�h�G�����1���2���Rퟩ�Q���^��['n���h}��H���w�0
ȶ-ؑ�
8��6fg�X����N�]�2������c*����G�%�  ����2��XI6�=�V%Zy$�!�u������g��x
[]QQ�� ����ǋX�P��/ŷ�Ap!I�<$��m��n�+���aö���vEf�M�x'"�A;Ls�Z��m�8t�p+X��w��j���vJ�TP�
@\�o��!�CN�: aw�B�X����A~�	��z��|=
%�[ވ@K�ۚ9��o�����N���u��]��+M�M �UQ_(E��D�2�xQ ����Ê+lOv�l���ֿ���t��uf�=|J�o��~o���]d���pB��R�1�	�`5:��������Z�~��������D�P 9�rI��{���)�����	�r�|�W	ƉO�Z+z
�B	mPW �wл���K�S�X�
/U��	��	�R"��}��x�=N���ǈ
�1�+����#��xD(
�$�Y19�s���$��L����Ux� �}$�h�@M�N^��ZS!Ђ�����C��fPp�Hk��D^D��l:0�HVZ�ַo�l�,E�|d�9S������zCD}uT�8�J�H�P�D��[�v�x k��[��)�#h	~9�q�R��UN��
��bN��l$#U�*��ٌ�`X��UZ(�/���	8�׀|k��_�v�n�CM�l-	�)a���V[Q)S������/�Ql!�t����]�*��W{�o�F�\{(%*�	��C(_$�Y7��	]%��tf�'i��o�À2־X�a l���p�����I@Tb5K��C�ۅ�K���GA4�{ ���9�I/�Q�\���V�\�R��mm���^��NH5�>� �$�����k5h�r^+GX�@�/��U[�ƭq�
@ gC�
�:]	 Vz��E
�KU�L	Q@=�Y�|�(��5e0T��K[�F
	�W}�lFP!� ��-n}	XB
u��ɀ}�/�m�uT��<EluG���P�{M5�RwJP�Fi/p��jr�![�Y�]^߸Q�'�Q�NW] �p���tT��ڔQ,���u=]�	
��mS�	t	Rh��Z\ű�T����x0Q
L=�������D=���[���H6\ve�(�����Y6�@Q0�%���o��l�Ӄ�l��m��� /@�M4��SO~��x����YGvTmdb1�pf����/^QF
6^���~~R����m�V�$yd�=�7����Z 
�
&��x"dx���_:v���`G��i��� ^��
���=�����,A8��d
������n�ڃz��!s�y�%���	�����E7S�i�q	`,}����D��#y�c�$����K(@�fX�K��A������J���c(�[Z��������ӥ����o��Z�7�N<x,y^xSV��K��z:t����!�)�	Il@S		-���s���l	���
p݅\�M������>O�"b
X�Rp�B�RtQ�B5���5�7���\�0��P.`���x!/0�Ex+���t�7O�Ý������y	�4��yT���o���q�������.\R��9*�B���^�\��\��D"F��ڶ�%�[P�g{������Չ�	yS+5!�3�UX��QP,IK\L�x�
VR��^mx@ ��Q�Kk��Å���� CcXci��E:�#�!�^M~m|����9H�5�d��7����ߒ U)G��#&�>�w�����e��9Ge�X�*lR�i��@_F��_�%�k�� �UDDDK��B ����poV���(
�7,V���w�lkT+�B/[
N���G�U�|�MH�.
+
!*<�l��F$W�F,H ��/�0h4F(
	
yA
����/�������S"�5(bl#M7�/��=�X7���f�P���$�w
fǄ⩿�j���KB�Hl'��|�H+EM�`F};F2�}����XmCSPG��Bkt�FP����ƋKZ@G^Jh}��wD�WCe\�Lx>;�\z�/��2��
��/CQ��g��_�����,0`����1mM @p/�ݢt� M!�����߀p����� Y��h]�c��3WE7x��șO�-�X	��	M���B�	(�`,!A<�
h8E�U��m�k�B�dP�����TE�c�*CH	�����#�"�j_T$U*S��Q�.��QI!�M�H]�{m���&r�	�K4�nU�a�W�rK-��x
b�?��(-QQ�"�$)a�Z�L�]���\^sY7��^�"IS\E5��uJ�KKz8�<�7��K�Iq������ t���o�-kDp������-�^�aWgf`dZ
G����A��h�KE�
rATP:
ѠU�UP�f���ߦ�p<ZH�rLb'4/�+��[�$�j^,�7Z���TUGB!�.)w.z�W!���u0Dw��QS9
�ld������
z)M,L\�y�뿴�@�v!X`	9l$ޢ�Xw9�rRQ�$
KJ5����cѯ�K�o�
M�p?�&"�9�/���Z4Pj�����i��V��9KP���wr@�ݷ��r�=�L��q_0P��oj��ZP�aQ"�Ml R�/�f+�
���]r�Ԝ7����t�P�~k�R�ض��Y�8|���U� �;UY�X
��o[di�;M�
FR�Q��w�ܶ�Z�9j�z[��[ "u	@Xl*���7��XǁWP$J"�2!I"FWm�@�J���"tN����K
�Pi�X��[����xK\�U��&:6��o�@o!1$&! �#@ӿ�x�IuqfAl����
���I����ۗ�Mp���/�V�,ԍ!Y?�bV�`H����F@$B#�'3�ixm�rb�A�V�н���jZv��B
�]�H
(��4�aKեjP�o2[�
�pKd{"
�!@H" (#*4�8,� ��7W,� F��j�KoQ�rw���v������O&!x�F56�ė^�7!h%S)����tى�Ļ�R\K &�
��IND�(��XtFILE� ZK�V�Pf�n��I��z���T:�If92u;U��R0:L�
�
��0�"�c����[�h�W���p_�m)�lP�B �%�@K��U�i;�%�R��Q4�r�����/q��Znr"�% ��/��*$-�"x�*�#+!�)!�-wM��0U�4��GlAe��( ��`����82<Im 
��΁} �,d����
6�2t���B%?!�u��oP�#,	1J��!�o1[���oZ+Y0��#�/�<%�5�7jw�E�-z�O�K�o4�-qe/0K4�SZ�x���@)�%<U6�U2l"�'����\9J4c�to�6k�&�,�[-�[�a�Gv���nܾ��6GlXpe6  q����d^�6&�#�64.�76�V�m6(4@*����D0�6��-��,�6dX�8���.T����*xi5��5#8#�5�;��o�(3�,�504Q18�5��6�'̭�
�jk׭"�G)ǟ��@�ݐ�@>�@g�W�<���\��{A��֫a�r|�"��v�T�[OP׸zik�=�0W���/Qڗ"�3�Ƅ
ܕ�v���'�!�������9(�+�hQN K��e=p%@{�h�.QU�R�ۉ-.\�,�!g�-,��~�q0p:,c��-���"�+_F����va,��R�
��{�F;����E�r�A�1A�JA.+m/K,�	U�$���܋��[�B���E�p�/�B�S�I%.�,
E�P�7ha��M�QR썌�|���ZJ������$�Kw�f�J����b�?��hu�J(Z�h[�oy��LO�0�cO�A������'�WB\�Ir�Q�.�;���m�)� J	v6��|�H��z$I4uD��gI7��_%�	�@Mb3��|/r/Ap/�����W�G�e�8s�1`/,|���)oq3�e-�g
���PbfHP�BfL̌�f;���/\�r�*�4��s
�A��.��Z۠��w�
 U<c���/m�!��C
R�ј�!
_��P�/�P�Ę-CH�F�x��
�C�E�����`�{Y�!��@�\!�]��}C	�J���-Y�'ؘN�+5�#<dQ pV����o�#�E�4$!M"J�R`ޝ@#�[��B��ꄧa;zQ0@�wmDT�_������YO��6ne�C �z(�Q�ߋ r}j�-U} %��}X
Q!�EZ#�قW�!
����d�/�[� �U�z��eQ�R���LB�<� +�/@["�%u����'�I��<uh�<���.0.	�!�@_&~I}����U�J^�!� F��/�f�6Y�7|���Z�Ch��DR���nT�xk�K랫���l��h�zr� �j+Z��[��Be9���]^�������!41%$u.�T��"o�o���r7#gC��DXS��o�Y�A�
 �p�x\�i��R_��m4���(
P�Ћ"�/�ΈJ5�^ 
6���F}�!'�@	b"&j��Z��\y��~,��o �UE��
d�_*qz!b�:�.R,k]~^��ŷ�&Jy�L}A:%c/�b�!��/�xB�B�"o�@/�7J/��:/�j���R�xN�~zZ��� �� w�.Q��9�t�y�)�n2�te����j��lH���%7x����!��!��B;��w_o-�����&�iD�ED�!Qc0M�,T(�=�4��P��n��������[�Ɯ�xa�_�%J!�@� p�}�^co�v�
u�1�
��!mt"آ������G�lU$���
�)
���z��
I�(E�#5�\!~���V�"q�D!�+H3���@��#�x�] &�m��(!3K�xM+ �ǃ5A�_"(���/�D�]R���Q]*� st�O6Y�]]��o�Z�;$tkr;@��]�j7:�/`e*}B)	|��/�1C��R!�q�{$h�F$���)Y3K_��\1�����h����$,Y�X��_H�&У_��NJ�#��`e'\y��_b����H�@2]�|�C�n���7{{F(j$RP&LM	,e���*��$�x�e�D��/O�$����T�n\�F��?t�$ D��ۿ�RÅ`h�M@��HF����RX
Dk�R�@hT��ߺ�k,2)d^�x *���Y!�(��h��[���l	󤍕�d�*�p���]�VWV���^�
S޷lF�.%^l���a��(+�׀��i�T��b�։�@bdM�|�)�b��ߝ��`\$]\H!j<S��#.�x����[`#�܅#M���OUѠ^���J��$K@\��ip	.
�A)~�0� !��#B[�������o�� 'ml5�PX^s���s2�U5]"���E0;Y��l�{g�jul�Uh�����zL�@rl�	���L���Z�S�.�m���)�|�1��X�u�K�X	O������6D	]&M�L����2�'������3� ��FHM�@3.�	�JN�����Km�1���^������uTdGU��$Y2\
�=P@�����vh�m��Z���"�(�@o, �%�)����]�B��e��V[�����"${�qNZE�Q? !���� �+�fu�?(�jtټ �;'���7��T|$��颴M,���%���,����������������'�M���`<R9��8j�������8K2�0� d�}�u�*�#X��n|�	p:�@X�6蜗���In$���Xz��a-'�o���TW#9�PHV38H/�W_���<�,�E<�z<1��
�х�/� �@0����/�o�~$���&�,!%m�)}���_�$
������"dĆ�H@<"FU4!�it�@�{� S� gEc�㷺�s9���Pap�"i����A\G"ĆƟt��[��[�E!B�2dF4%J|����"������oo����!K���y�H%O#A�/����u�"��UD�!�l�$���_�*u &��%|"�I,��!7R$����K�N �}y#��^>K(j���p"�%,vc�������]XKR9!���SNXGB¿T�s�Q�	-�/ŧo����;w-;\+r'w�-��;�r+[B0� �x�շ�p��~X1���� �F�r�K$ne�d����[	sE%U>��r�P�d�/Ԣp0����E[��F���Z_��2FT�,��!�6Gc�C)��o�VTE;ltr�kai�z��+|��w��
�>
O���Q}.+��$CЄ.]!�K��_M�T ��;���V�wr9 sB�����HO5s;E��!��j+����!]���H�K,�
�!ʋH�����tt1�T��������G<�Y6V���.C	�Ess!D�C��loѣ���$�����D�
~��N=S
�
�����*�_��x�O��hz���_,�#�N�8@TPl�G8sCx���X�@�'� 4�X���񋣗^���	�x�����"���e:�mK�r�#�NV_F�/!�������#P���IYP!q�Ti�wL=/�#���V##^������Yt�)���q�!ͥ S��_������%l;A�+!�X�����[����#��"�SR<�b�dV"�Ka��$D?�@��M*V

�����^�9�� u	���m����`nK��[4}����P�/�L�,��B��V
��
�u�l!l"�oT��"wtH={�c������r ��!6#�$�#�/���tA/~!-*:G��u)��)�ߨ�E%��� t�x�M]Lt�Ɋ�`m\�
B@�[���u��)�.B#Pv)oo[+/
�5)�߂��~�i{9b\�}:�H�q��an_ |%!�'>N��(��P��#G��у���_�VX�XJb	�tw�kH�� ���X��6M���֍���R}A|��_#��߽	�u�"1>B�A"�P�|�	�܆U
$����x�!ق�]σ
P�D9\�mr`!])�dX����
��R�!��#�"6(%�ޝT,pa��)��Y384f�x�/�MT3	vHU.uMƄ����m K3~�7�׭6�L\�mt���^���_L
��B;<It�jW��p�:T�7��gxM�Jt+
��VsS��>؀9B��I�
J28�u@H`F���x!r�>�+$�
�]mWǋW+"x�v���!8_�y6�P`�h��Oʉ=�[�F�u4�z�"p�o��gM$���L [kJ��D,}ả!�K��x{+,�LOD�I	|ى�Z���� ��uE�o�-6�������<S����������zjH�Hi�jz�V��jMo6��K�҃[����T"NK�E������Doz�y���7��q R���I
�n���W��%;)�X[�7� �$ �!kS���C�������R�W'��[�`'%�KQ}YgG\�Y� ����(!�Dh��#Hw%s�{$\5|I7~�%C�pC"l�NT%�Ko��bC!����
D";4o����Sr	9C�����(�T&b��[�I�"�\�,&噱X�I�Y������	�y^x��+%"��մ�Zm�)��l�o����[��q#��
�[��ǅ�Z��?������wY;��;�ԍ��K�`^#uf"1�v%?���-�\��J9�(íU��G˗*��9���k�W����w t
�XdOu���j����"����\�$B�MD���EL"K_���0M lqp�lPR���|�lPhUJ�l�A0 ��%��O��u�	Ƿ/��A�������J�����)��&K���Z�i��	ޱ��ֿ�+b��O]�o>�$�$�NܽPt���FS�P�FIq�b!��,7��
H
R��Iި�71	a@�'�q�I����O!6�d=^92p�h���
NW�
9�b�C(�Oݨ��{�x�U��GS�[�f�jTh��g�Q��_|'�\�SqS��S+
��n���o�4�
��YTعT4yT�K�B31�����4�H��/��V#T�LyP�qj�(D�_^N����|mT������(�_QA�}��\!t1��K��tŉ�V*fX�]�i;�����ZOo�	|([_L��!:�Λ�PH�wJ,��TF����ƍ!��"�A40�4���,����u3!@�H��+�vAf�
�[�W(��C���#���m������+L)
ډF�-n�w�G#EPA�o�/��:#�!ݘٟrw������"�N "u����?@�B�ǒ���K��P�HVJ��9�Eo����i*�P���+(@S�o�DKs{8�sH#�L�x�7�
�DW0��!A{@kD�5(�)�^��m��7D"��S<<����w!����[��"�y8�qJT[ύSHa��ko�{Tj��9�C���_藋s@�vT��Jq��8Q*T�;s�KDV����댙!&��x�G�[��R�T��P@t���("L-8
)` �'��XhQgX�9�u9Zu
��A�M�]�Q
�B"IV���ߪm�NQ`�M�9�Qx�7�F9AU��k�q��r�W�J��-�� u��)ʗZb[ψ���-�#�/�Z�'��V�?_��2��r ׃����Xf���u\�x �ե4tJ�@�o�U�1��C!9�rB;_��|�J@5(k�@D�v5��^���RLU�
��jSQD�&"^
(]�k�+u�}�V�f�"�
�CiYo/�d )��Պ&i��Q
:��O���#�����%�,��X�X���0h�%J-J���M"إ��.��[�90U_v�W�H��CLz�� 
0���U"���rV ���ߊ�A�~�^�+�����d(�`G\@s�%�2U��[��G\�!.�^c"+x��/�ruTXN׋h!迡��XV[����6p%����q-��"��Z[a-d��TE�TAF0���xxz��&��,(���fݔ� ����YB'ť/�!9ALi�������(����<	�#�/�m��U|D�AB��^����d� ��x��@���x���
Z��� S#�h�MX\�%�<*u"|�M!�ߛT�A�/��`S闁�-^I�d^�v�q.y��[�v){�R�z+yE�m"m��A�\߈$DYp1` lt/-�:<ht:j�L��ѷd�ez�| �b��u+�h$��%��#gK��ZVm��}��Az��#S��~��_ ~y��4+W��<n�T>��)<cM�X9<�R<X���-�5X�]kth<i$@�����^<s&�`<ot<p'<��/�u$1<x<�J
�&���"e��V'� �2��o�!p�B,��(������n!�-	�N�cJ�K�V�{�t�Uu �F��v�����B	�N�ͫ�� �}
�&�$^e��s�7�����$���XRH,j��`�/�[Dt�������K�\���W�F����D
$(T'\�,�K/�ƾ"�f����ƍ_�"GX��'�yJ-YYD/�
�!�"���
X$��!�Q逭!�����&�,M 4L m5$S4sQ,�~��
39"�\l�H�H�ҷ�R�ZYGLrr^�+|�[��ntYq�-��H�uB�������,O BU*8z�����rg��mBP�~F�u�A8"��y�t#��"a��[�Qc|�lV3T$c��uQ`	��V���N	������I��;V�~_(�za��t"���Pc=�I��oQ�%�w�0"x5\�����R"��
!�Z�H(����� �+q��wf�M�E�����݆�'v��[�)0\#/u�/�x$p����|�6*���� %�DC��zlV7�V�������o���$H��OE�M��$�[��	c�/]��/�0%uETxƫ��7��h���d&^,WVo$ğ��m/�g�Y��𒙡���Y2���mgT�����M�eM�"�l�(��oQ�$4�_q�'�^ZQR!��ѷG���b�Z[��6��"�7'� 6\!8��KT��7�h?������ì!�( H��7"9;���	��CJ	�t�E����$��" ��������C͍tk�
-���Ƃ0�g�N �k$Բ�G!3�K���p �
V W �Y@[7��� \ �_ ` �b K�(�c d e f�i��n�k �m n o p q�Z��l� t \�w�E�7� y /v/���~} ~ � � � � � � � ����A�� � � |� � � � ���� � � � � � �> � ��K�Kˣ � � ��+ � � �Z���� �����#� � � � � � �%�%�%%����a%b%V%U%c%Q%W%]%\%[%%%4%,%�-P�%�^%_%Z%T%i�/��%f�%ql%g%h%d%e%Y����%X%R%S%k%j%%%�%�%�%�%�%�� ��R�-ԣ�������]���"�)�"�"d�o�#!#�]"��"���V�" � �%� � ��68*(��W9��M=�T=�R�
� ��3��� �MB�MC�>�5� ۭ�.��L�@؈��R'?�� � �U?� T߾�oF�_?��T?
������������� ���N��
ZO78-�%j�(��
kQ�-�ext2_V��mr)p_Rscb�_���k��>= �s_cH-P��*o7�� W,,�W�Ssb���_ipvstructeE|KD�can'���6�C
�e��r
so��ED �
err#it'����s�H��.�F_2/3'*Q��`(x��5YibS� .[k�X��e�a����_pnɂEML�-�`���~�"�[cheO_�����FTMc
cNd g)ǭп�����_�-_�C���k6��[	b��P��Volum��_h]�+�5tv��0'Y�����}Elu�y"XH��[�F�b
<t/��to~nyK_��`kJQ�MTb�s����CrXT	@2�/�V!'��
w	�m�o�U):�DPNo��gBTC�vic��[��_B�fS_M��ܺ��1�
vZ�w�i4gd�7\F1�5%04�����s�cA� (����%u/��lDD9� 
��,�'lf*<
���'6thPu���c�o/��h(C7).i./-��Y�!�1+v(�/8�=�s� ���@B��n#����\��}� (�5�Eﾅt5'�(��i�7Fool�*�p_�oaoUg��c{��� `c���(�:��?��a� �W       �         �       H �   H     m���GCC: (Gentoo 4.5.3-r2 p1	,��n�ie-0.7)  .shstrtas�۷b	inittexfm��}rodaeh_frame	c��d�Trsdjcr"{���)el-got.plX��=bs*comm�  �4�'Ԁ�2Ȁ4.�4��<���A,C,����O'P2�%�P�#%Jn�g�wD ��/'dd�f@�6lf@��l=t@�tBd i�xxO��i��hi�iT��.l ]w � �8ݕ\,�c'��|��5�I'	_��O0'-�f��
<�w��t,�<w"8u�f������)�����������؃��a�QPR�
 $Info: This file is packed with the UPX executable packer http://upx.sf.net $
 $Id: UPX 3.07 Copyright (C) 1996-2010 the UPX Team. All Rights Reserved. $
 jZ�   PROT_EXEC|PROT_WRITE failed.
Yj[jX̀�jX̀^�E��8)���@H�  % ���jP1�j�j2�jQP��jZX̀;���������P��PQR�P��D$V�Ճ�,�]����=  \  I
 ۷��WS)ɺx  ���)��	 �Y
S�SH���
�� ���R)�f�����{u�P���G��H���T$`G�d���o��$Y[��@Z���PO6<��?��u�PP)ٰ[�'��w�ogu����	W�� s�����[u����@�H����_�S�\$jZ۷��[� WV��S��9��s
j�k��7����t�G�B��s)3�9���{U��/�Ӄ�E3}{����E܃: ��GU�������m� �M���UPX!u�>)��M��_um9�w�;�oo�w�s_E���u�P�wQ�}w��v�Ub�GϋU�;cuǊE�������t"��t�� �w9u��P�۶�E�PR9��4��F��<���
��U���v)�R��A�e��������t

�#/��ˈT�	�j-.�5\��
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