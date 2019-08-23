#!/bin/bash -x

# dependencies
# pip3 install bs4
# apt install flex libssl-dev libncurses-dev

export INSTALL_MOD_PATH=/var/tmp/kernel-build

if [ "$(id -u)" != "0" ]; then
    exec sudo -E $0 $*
fi

export SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
export KSOURCE_DIR=/mnt/sda4/tmp

pushd .
cd $KSOURCE_DIR

# From kernel.org what is longter and stable? Used to detect what version we will build
#LONGTERM=19
LONGTERM=9
STABLE=2

# Kernel we are going to build eg. 5.1
#export VERSION=4
export VERSION=5
#export PATCHLEVEL=19
#export PATCHLEVEL=9
export PATCHLEVEL=2

SUBLEVEL=$(grep -oP '(?<=SUBLEVEL \= )([\d]+)' linux-${VERSION}.${PATCHLEVEL}/Makefile)

OLD_KVER="${VERSION}.${PATCHLEVEL}.${SUBLEVEL}"

LOCAL_VER=$(grep -Po '(?<=CONFIG_LOCALVERSION=")([^"]+)' linux-${VERSION}.${PATCHLEVEL}/.config)

# To rebuild the current one - not fetching patch and update, just pass $1 with current version defined in makefile. This wont have the custom version string.

KVER="$1"

if [ -z "$KVER" ]; then
    if [ "$PATCHLEVEL" == "$STABLE" ]; then
        KVER=`curl -Ls http://www.kernel.org | python3 -c "import sys; from bs4 import BeautifulSoup; s=BeautifulSoup(sys.stdin.read(), 'html.parser'); print([x.next_sibling.next_sibling.text for x in s.body.find('table',attrs={'id':'releases'}).find_all('td',text='stable:') if x.next_sibling.next_sibling.text.split('.')[1] == '$PATCHLEVEL'][0])"`
    elif [ "$PATCHLEVEL" == "$LONGTERM" ]; then
    # Get the longterm
        KVER=`curl -Ls http://www.kernel.org | python3 -c "import sys; from bs4 import BeautifulSoup; s=BeautifulSoup(sys.stdin.read(), 'html.parser'); longterms = s.body.find_all('td', text='longterm:'); o = [x.next_sibling.next_sibling.text for x in longterms if x.next_sibling.next_sibling.text.split('.')[1] == '$PATCHLEVEL' ]; print(o[0])"`
    fi
fi

if [ "$KVER" == "$OLD_KVER" ] && [ -z "$REBUILD" ]; then echo "No new version. Do nothing"; exit 0; fi

if [ ! -f "patch-$KVER.xz" ]; then
    wget https://cdn.kernel.org/pub/linux/kernel/v${VERSION}.x/patch-$KVER.xz
fi

echo "Going to make kernel in linux-${VERSION}.${PATCHLEVEL}"

read junk

cd linux-${VERSION}.${PATCHLEVEL}

if [ "$KVER" != "$OLD_KVER" ]; then
    [ -f "../patch-${OLD_KVER}.xz" ] && xzcat ../patch-${OLD_KVER}.xz | patch -p1 -R
    xzcat ../patch-${KVER}.xz | patch -p1
fi

if [ ! -z "$CONFIG_FILE" ]; then cp "$CONFIG_FILE" .config; fi

#make clean
make oldconfig
make -j 8 bzImage modules

# KVER="${VERSION}.${PATCHLEVEL}.${SUBLEVEL}"
export KVERS="${KVER}${LOCAL_VER}"
$SCRIPT_DIR/makekernel.sh xz

popd
