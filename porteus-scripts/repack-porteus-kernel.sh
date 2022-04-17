#!/bin/bash

[ ! -d porteus-kernel ] && echo "porteus-kernel dir deos not exists - abort" && exit 1

TARGET_FNAME=$1

[ -z "$TARGET_FNAME" ] && echo "first arg required " && exit 1

TAR_FNAME=${TARGET_FNAME%.sfx}

[ -z "$KVER" ] && KVER=$(echo $TARGET_FNAME | grep -oP '(?<=porteus\-kernel\-)[\d\.]+')

if ! $(ls porteus-kernel/000-${KVER}* >/dev/null 2>&1); then
    echo "No matching kernel version detected, abort"
    exit 1
fi
tar cf $TAR_FNAME porteus-kernel
cat <<EOF > /tmp/self-extract
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
cat /tmp/self-extract $TAR_FNAME > $TARGET_FNAME
rm -rf $TAR_FNAME porteus-kernel /tmp/self-extract
