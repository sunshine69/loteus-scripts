#!/bin/bash
if [ $(whoami) != "root" ]; then echo "Need to install as root"; exit 1; fi
sed -e '1,/^##EOS##$/d' "$0" | sudo tar xf -
echo "Run porteus-install-kernel script? y/n"
read ans
if [ "$ans" == "y" ]; then
     cd porteus-kernel && ./porteus-install-kernel.sh
fi
exit 0
##EOS##
