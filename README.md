# Welcome to Loteus!

I come up with a name for my linux distribution - Loteus!

I use the linuxrc start up script from a linux distro [porteus](http://www.porteus.org/) modified it to support many functionalities I need. Still keep the original idea which is run linux from a compresses root image and mount overlayfs as root.

To try click:
[Ubuntu22.04](https://mega.nz/file/0Aw0ySxR#A6iMdK25IJMVV7qvoAZdWeE6ExHpYo9dtS57t0-Bzqk) 
[Ubuntu23.04](https://mega.nz/file/UdBnVTaA#yiMkDxn2Luh9OFMev_hjgNXVwkxpLUZEj7AOFNpTui4)

to download the USB image. This will fit any USB with minimum size of 8GB.

Use a image burner program like [balenaEtcher](https://etcher.download/download-etcher/) to flash the image into a USB disk (your disk will be wiped off in the process so make sure you back up your data).

If you are on a linux host you can simply using dd command to write it.

```
zcat <path-to-image.gz> | dd of=/dev/<your-usb-device-name> bs=1M 
sync
```

Then insert the USB into the target machine; boot it up make sure it boots from the USB (by setting the BIOS or display the BIOS boot menu, please consult your specific bios system for the howto)

If all good then you will be auto login the initial user `loteus` running simple icewm window manager.

The initial password of user loteus is `1q2w3e`.

By default it will log you in a icewm windows session. You can change the session at the GDM3 login screen though to boot to standard Ubuntu 22 gnome desktop which then no longer be a thin OS anymore :) .

As of now it is a live, data persistent USB. That means any settings, data download etc will be saved to the USB and available after reboot. It has:
- Web browsers, firefox, google chrome. 
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

## Script tools 

I have added a script which take all loteus administration helpers. Run `/opt/bin/loteus-manage.py` to see what available.

## Maintenance.

**REMEMBER to add new user for you and change the default password of user loteus!**

The system is boot using a read-only base image and all changes are also saved to disk as normal so use it like
a normal Ubuntu system.

If you made a changes and crash the system you can always reboot and select the second boot menu (reset) which remove all changes in the system. The user data is retained at your home directory.

You have the ability to merge to the readonly base image using the command `loteus-manage.py`. Example below - note you need to run the command as root user:

```
# become root 
sudo -i 
# Run apt update and apt upgrade to bring up the system to the latest from ubuntu 
apt update && apt upgrade 
# Save the system config like new users you have added, wifi password etc 
loteus-manage.py save_config
# Use it for a while test see everything works fine, maybe reboot etc. Then run this command to merge to the read-only base image 
loteus-manage.py merge_base
# After run the command above, reboot the system and select the second boot entry (reset) to clean up 
# Run without command to show help and all available commands
loteus-manage.py 
```
