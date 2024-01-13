#!/bin/bash
# This script is used inside a module file. A custom module file a a squashfs image which has the directory structure
# /start-mod.sh
# /stop-mod.sh (which is a symlink to start-mod.sh
# /opt/
# /opt/app1
# /opt/app2 (etc..)
# When the module is activated using the `activate <path-to-module-file>` command it will be mounted at /mnt/live/memory/images/<mod-name> and each app1,2 will be symlink to the current root fs /opt; that is /opt/app1 -> /mnt/live/memory/images/<mod-file-name>/opt/app1 so on
# deactivate command will unmount it.
# The module file can be placed inside the loteus `base` dir or any path to automatically activated at boot. Remember if that is the case, /opt/app{1,2} will not be symlink anymore but a real union dir. And you can not use command `deactivate` it.

# For non loteus system this kind of module should work as well, as long as you have the script `activate` and `deactivate` installed in /opt/bin/

export SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
export SCRIPT_NAME=$(basename "$0")

pushd .

cd ${SCRIPT_DIR}/opt


for i in $(find . -maxdepth 1 -type d ); do
    echo $SCRIPT_NAME symlink $i /opt/${i};
    if [ "$i" == '.' ]; then continue; fi
    if [ -s /opt/${i} ]; then
        #if [ ! -e /opt/${i} ]; then
        #    echo "Symlink exists but dead, try to rm it"
            rm -f /opt/${i}
            RM_ERR=$?
        #fi
    else
        if [ -d /opt/${i} ]; then
            echo "ERROR directory /opt/${i} already exists. You need to clean it up first"
            exit 1
        else
            RM_ERR=0
        fi
    fi
    if [ "$SCRIPT_NAME" = "start-mod.sh" ]; then
    if [ "$RM_ERR" = "0" ]; then
            ln -sf ${SCRIPT_DIR}/opt/$i /opt/${i}
    fi
    fi
done

popd

