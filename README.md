# Welcome to Loteus!

I come up with a name for my linux distribution - Loteus!

I use the linuxrc start up script from a linux distro [porteus](http://www.porteus.org/) and modified it to support many functionalities I need. Still, keep the original idea which is to run linux from a compressed root image and mount overlayfs as root.

To try click below to view the folder contents. I recommend to use the LTS version of ubuntu image (2204) for old devices like Del Thin Client. The thin version is just smaller if you do not mind download big use the full feature one.

- [Browser linux folder](https://mega.nz/folder/gB5ShQII#_zlRO_lsbqZltxX1d7kcEQ)  

to download the USB image. This will fit any USB with a minimum size of 8GB.

Use an image burner program like [balenaEtcher](https://etcher.download/download-etcher/) to flash the image into a USB disk (your disk will be wiped off in the process so make sure you back up your data).

If you are on a linux host you can simply use dd command to write it.

```
# Put your USB in then run dmesg | tail -n 50 to see which device name is, like sda or sdb etc..
dmesg | tail -n 50
zcat <path-to-image.gz> | dd of=/dev/<your-usb-device-name> bs=1M 
sync
```

Then insert the USB into the target machine; boot it up and make sure it boots from the USB (by setting the BIOS or displaying the BIOS boot menu, please consult your specific bios system for the howto)

If all good then you will be auto login the initial user `loteus` running a simple icewm window manager.

If the boot process stop with green text saying something `porteus not found`. It is likely that the usb devie is not available fast enough. It only happens when using USB disk to boot. Turn off teh machine and boot it again, when you are presented with the boot grub menu, type `e` to edit the boot. Scroll down to where the boot parameters is (search a line that has the string `bzImage`). Within that line, add a new parameters at the end - remember parameters are sperated by space) `usb_delay=3`. Then press F10 to boot the system.

The initial password of user loteus is `1q2w3e`.

Note that user loteus is meant to be a media player user. This user does not have sudo or admin right. In order to login and setup your initial system or install it into your hard disk you should login using the user `admin`. The initial password for `admin` is `q1w2e3`.

By default, it will log you in an icewm windows session. You can change the session at the GDM3 login screen though to boot to a standard Ubuntu 22 gnome desktop which then no longer be a thin OS anymore :).

As of now, it is a live, data-persistent USB. That means any settings, data download, etc will be saved to the USB and available after reboot. It has:
- Web browsers, firefox, google chrome. 
- Kodi media player
- vmware horizon client for remote access to vmware horizon VDIs
- many text tools - ansible, python3, openvpn, gcc and g++, fish shell.

To resize the last partition of the USB so that you can use all disk space that your USB offer, as root run the command `resize-last-part.sh /dev/<your-usb-device>`. To find your usb device run `losetup -a | grep 001` it will print out where your root image is mounted; like `/mnt/<device-name>`.

To install into the internal hard disk, from the icewm menu click `INSTALL TO HARD DISK` menu.

If you are at the ubuntu gnome you start the terminal, become root, and run `ansible /opt/bin/install-porteus-to-hd.yaml`. 

Follow the prompt, and select the correct disk to install. It will take a while to copy the root image (around 3.5G) into the internal disk so be patient.

## Helper scripts
are in the directory `loteus-scripts` which is up-to-date. Most of them are in the USB image `/opt/bin` and will be updated from time to time, however, in this repo it is all up-to-date.

## Disk encryption

Check inside the folder `loteus-scripts/make-changes-image.sh`. Copy the content and save it to your current `/opt/bin/` and overwrite the existing one. 

To create an encrypted disk image with 1G size run `/opt/bin/make-changes-image-enc.sh 1024`. This is a symlink to the above script which enable it to encrypt the image.

## Script tools 

I have added a script that takes all loteus administration helpers. Run `/opt/bin/loteus-manage.py` to see what is available.

## Maintenance.

**REMEMBER to add a new user for you and change the default password of user loteus!**

The system is booted using a read-only base image and all changes are also saved to disk as normal so use it like
a normal Ubuntu system.

If you made changes and crash the system you can always reboot and select the second boot menu (reset) which removes all changes in the system. The user data is retained in your home directory.

You have the ability to merge to the read-only base image using the command `loteus-manage.py`. The example below - note you need to run the command as root user:

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

## Latest kernel update

Download the kernel file below and then run

```
chmod +x <file downloaded>
./<file downloaded>
# type y when it prompts 
reboot 
```

- [AMD CPU for thinclient](https://mega.nz/file/9cJw2aIK#oQ_aAY3s7Wl-BH21OQYVPE89xgZauM0IKSEpYuCmtpg)
- [Core2 CPU](https://mega.nz/file/sMJSQQyT#VX3n5ZjuKjZHhKfDg_mJ70jJR6qneQ_vWPlIT9uXvDw)
- [Generic x86_64](https://mega.nz/file/EYhRnZLC#OHc9YWXI9MIcTTv_PczA4lYF9MwYUrYWBBa6wVFMC_U)
