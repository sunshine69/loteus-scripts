#!/bin/bash

echo "Extracting archive ..."
sed -e '1,/^##EOS##$/d' "$0" | sudo tar xf -
echo "Run porteus-install-kernel script? y/n"
read ans
if [ "$ans" == "y" ]; then
     cd porteus-kernel && sudo ./porteus-install-kernel.sh
fi
exit 0
##EOS##
