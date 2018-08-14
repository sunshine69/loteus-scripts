#!/bin/bash -ex

if [ "$(id -u)" != "0" ]; then
    exec sudo $0
fi

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
KSOURCE_DIR=/mnt/sda4/tmp

LONGTERM=14
STABLE=17

VERSION=4
PATCHLEVEL=14
SUBLEVEL=$(grep -oP '(?<=SUBLEVEL \= )([\d]+)' linux-${VERSION}.${PATCHLEVEL}/Makefile)

OLD_KVER="${VERSION}.${PATCHLEVEL}.${SUBLEVEL}"

LOCAL_VER=$(grep -Po '(?<=CONFIG_LOCALVERSION=")([^"]+)' linux-${VERSION}.${PATCHLEVEL}/.config)

KVER="$1"

if [ -z "$KVER" ]; then
    if [ "$PATCHLEVEL" == "$STABLE" ]; then
        KVER=`curl -Ls http://www.kernel.org | python3 -c 'import sys; from bs4 import BeautifulSoup; s=BeautifulSoup(sys.stdin.read(), "html.parser"); print(s.body.find("td", attrs={"id":"latest_link"}).text.replace("\n","") )'`
    elif [ "$PATCHLEVEL" == "$LONGTERM" ]; then
    # Get the longterm
        KVER=`curl -Ls http://www.kernel.org | python3 -c 'import sys; from bs4 import BeautifulSoup; s=BeautifulSoup(sys.stdin.read(), "html.parser"); print(s.body.find("td", text="longterm:").next_sibling.next_sibling.text)'`
    fi
fi

if [ "$KVER" == "$OLD_KVER" ]; then echo "No new version. Do nothing"; exit 0; fi

pushd .

cd $KSOURCE_DIR

wget https://cdn.kernel.org/pub/linux/kernel/v4.x/patch-$KVER.xz

cd linux-${VERSION}.${PATCHLEVEL}

if [ "$SUBLEVEL" != "0" ]; then
    xzcat ../patch-${OLD_KVER}.xz | patch -p1 -R
fi

xzcat ../patch-${KVER}.xz | patch -p1

if [ ! -z "$CONFIG_FILE" ]; then cp "$CONFIG_FILE" .config; fi

make clean oldconfig
make -j 8 bzImage modules

# KVER="${VERSION}.${PATCHLEVEL}.${SUBLEVEL}"
export KVERS="${KVER}${LOCAL_VER}"
$SCRIPT_DIR/makekernel.sh xz

popd
