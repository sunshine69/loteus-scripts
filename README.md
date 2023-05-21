# Kernel build scripts

This is a set of porteus custom kernel build script.

## Welcome to Loteus!

I come up with a name for my linux distribution - Loteus!

I use the linuxrc start up script from a linux distro [porteus](http://www.porteus.org/) modified it to support many functionalities I need. Still keep the original idea which is run linux from a compresses root image and mount overlayfs as root.

To try click [this](https://mega.nz/file/tQAXibhQ#N0dBfz7EZPRbcFeiOFdV9wxl8fDLYgFKAIoUrzEBrTA) to download the USB image. This will fit any USB with minimum size of 8GB.

Use a image burner program like [balenaEtcher](https://etcher.download/download-etcher/) to flash the image into a USB disk (your disk will be wiped off in the process so make sure you back up your data).

If you are on a linux host you can simply using dd command to write it.

Then insert the USB into the target machine; boot it up make sure it boots from the USB (by setting the BIOS or display the BIOS boot menu, please consult your specific bios system for the howto)

If all good then you will be presented with GDM3 login and with the initial user `chrome`.

Login using the initial password `1q2w3e`.

By default it will log you in a icewm windows session. You can change the session at the GDM3 login screen though to boot to standard Ubuntu 22 gnome desktop which then no longer be a thin OS anymore :) .

As of now it is a live, data persistent USB. That means any settings, data download etc will be saved to the USB and available after reboot. It has:
- Three web browsers, firefox, edge and google chrome. I recommend edge which is pretty fast and less memory usage for a small box. 
- Kodi media player
- vmware horizon client for remote access to vmware horizon VDIs
- many text tools - ansible, python3, openvpn, gcc and g++, fish shell.

To resize the last partition of the USB so that you can use all disk space that your USB offer, as root run the command `resize-last-part.sh /dev/<your-usb-device>`. To find your usb device run `losetup -a | grep 001` it will print out where your root image mounted; like `/mnt/<device-name>`.

To install into the internal hard disk, from the icewm menu click `INSTALL TO HARD DISK` menu.

If you at the ubuntu gnome you start the terminal, become root and run `ansible /opt/bin/install-porteus-to-hd.yaml`. 

Follow the prompt, and select the correct disk to install. It will take a while to copy the root image (around 3.5G) into the internal disk so be patient.

## Helper scripts
are in the directory `loteus-scripts` which is up-to-date. Most of them are in the usb image `/opt/bin` and will be updated from time to time, however in this repo it is all up-to-date.

## Disk encryption

Check inside the folder `loteus-scripts/make-changes-image.sh`. Copy the content and save it to your current `/opt/bin/` overwrite the existing one. 

To create an encrypted disk image with 1G size run `/opt/bin/make-changes-image-enc.sh 1024`. This is a symlink to the above script which enable it to encrypt the image.

