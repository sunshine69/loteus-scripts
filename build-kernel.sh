#!/bin/bash -x

# This is starting script

# dependencies
# pip3 install bs4
# apt install flex libssl-dev libncurses-dev

export INSTALL_MOD_PATH=/var/tmp/kernel-build

if [ "$(id -u)" != "0" ]; then
    exec sudo -E $0 $*
fi

export SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
export KSOURCE_DIR=$(pwd)

# Change this to match with what is in the https://kernel.org site
# From kernel.org what is longer and stable? Used to detect what version we will build
# This is the first number (version) and minor as now stable and longterm having the same version.
if [ -z "$LONGTERM" ]; then
  LONGTERM="5.15"
  LONGTERM="6.1"
fi
#STABLE="5.17"
STABLE="6.2"
MAINLINE="6.3"

# Change these to select what kernel we are going to build eg. 5.1. The first number (version)
# The combination needs to match with one of the above section
VERSION=${VERSION-5}
#VERSION=4
export VERSION
# Minor version (middle number)
#PATCHLEVEL=${PATCHLEVEL-}10
PATCHLEVEL=${PATCHLEVEL-15}
#PATCHLEVEL=${PATCHLEVEL-18
#PATCHLEVEL=${PATCHLEVEL-}${PATCHLEVEL:-8}
export PATCHLEVEL
####

if [ ! -d "${KSOURCE_DIR}/linux-${VERSION}.${PATCHLEVEL}" ]; then
    echo "Kenrel source dir ${KSOURCE_DIR}/linux-${VERSION}.${PATCHLEVEL} does not exist. Aborted!"
    exit 1
fi

pushd .
cd $KSOURCE_DIR

SUBLEVEL=$(grep -oP '(?<=SUBLEVEL \= )([\d]+)' linux-${VERSION}.${PATCHLEVEL}/Makefile)
OLD_KVER="${VERSION}.${PATCHLEVEL}.${SUBLEVEL}"

LOCAL_VER=$(grep -Po '(?<=CONFIG_LOCALVERSION=")([^"]+)' linux-${VERSION}.${PATCHLEVEL}/.config)

# To rebuild the current one - not fetching patch and update, just pass $1 with current version defined in makefile. This wont have the custom version string.

KVER="$1"

if [ -z "$KVER" ]; then
    if [ "${VERSION}.$PATCHLEVEL" == "$STABLE" ]; then
        KVER=`curl -Ls http://www.kernel.org | python3 -c "import sys; from bs4 import BeautifulSoup; s=BeautifulSoup(sys.stdin.read(), 'html.parser'); print([x.next_sibling.next_sibling.text for x in s.body.find('table',attrs={'id':'releases'}).find_all('td',text='stable:') if x.next_sibling.next_sibling.text.split('.')[1] == '$PATCHLEVEL'][0])"`
    elif [ "${VERSION}.$PATCHLEVEL" == "$LONGTERM" ]; then
    # Get the longterm
        KVER=`curl -Ls http://www.kernel.org | python3 -c "import sys; from bs4 import BeautifulSoup; s=BeautifulSoup(sys.stdin.read(), 'html.parser'); longterms = s.body.find_all('td', text='longterm:'); o = [x.next_sibling.next_sibling.text for x in longterms if x.next_sibling.next_sibling.text.split('.')[1] == '$PATCHLEVEL' ]; print(o[0])"`
    elif [ "${VERSION}.$PATCHLEVEL" == "$MAINLINE" ]; then
        KVER=`curl -Ls http://www.kernel.org | python3 -c "import sys; from bs4 import BeautifulSoup; s=BeautifulSoup(sys.stdin.read(), 'html.parser'); mainline = s.body.find_all('td', text='mainline:'); o = [x.next_sibling.next_sibling.text for x in mainline if x.next_sibling.next_sibling.text.split('.')[1] == '$PATCHLEVEL' ]; print(o[0])"`
    fi
fi

KVER=$(echo $KVER | sed 's/ \[EOL\]//g')

if [ "$KVER" == "$OLD_KVER" ] && [ -z "$REBUILD" ]; then echo "No new version. Do nothing"; exit 0; fi

if [ "NOTIFY_ONLY" = "yes" ]; then
    # TODO make sendmail.py
    sendmail.py -s "Kernel update available" -to msh.computing@gmail.com -from msh.computing@gmail.com -msg ''
    exit 0
fi

if [ ! -f "patch-$KVER.xz" ] && [ -z "$REBUILD" ]; then
    wget https://cdn.kernel.org/pub/linux/kernel/v${VERSION}.x/patch-$KVER.xz
fi

echo "Going to make kernel in linux-${VERSION}.${PATCHLEVEL}"

read junk

cd linux-${VERSION}.${PATCHLEVEL}

if [ "$KVER" != "$OLD_KVER" ]; then
    # if last version is missing or 0 we dont patch as it is beggining
    _TEST_LAST=$(echo $KVER | cut -f3 -d.)
    if [ "$_TEST_LAST" = "" ] || [ "$_TEST_LAST" = "0" ]; then
        echo "Skip patching as this is begin of stream line"
    else
        if [ -z "$REBUILD" ]; then
            [ -f "../patch-${OLD_KVER}.xz" ] && xzcat ../patch-${OLD_KVER}.xz | patch -p1 -R
            xzcat ../patch-${KVER}.xz | patch -p1
        fi
    fi
fi

if [ ! -z "$CONFIG_FILE" ]; then cp "$CONFIG_FILE" .config; fi

#make clean
make oldconfig

CORE=$(lscpu | grep '^CPU(s):' | awk '{print $2}')
if [[ $CORE -gt 2 ]]; then
    let "CORE=$CORE - 2"
fi
startbuild=`date +%s`

make -j $CORE bzImage modules
if [ $? != "0" ]; then
    echo "Build bzImage and modules return error"
    exit 1
fi

endbuild=`date +%s`
runtime=$((end-start))

echo "Make kernel spend start: $startbuild - end: $endbuild - runtime:  $(echo "$runtime/60" | bc -l) mins" > ${SCRIPT_DIR}/${0}-build-${KVER}-$(hostname -s)-runtime.txt

# KVER="${VERSION}.${PATCHLEVEL}.${SUBLEVEL}"

if [ "$_TEST_LAST" = "" ]; then KVERS="${KVER}.0"; fi

export KVERS="${KVER}${LOCAL_VER}"
export KDIR="$KSOURCE_DIR/linux-${VERSION}.${PATCHLEVEL}"
$SCRIPT_DIR/makekernel.sh xz

popd
