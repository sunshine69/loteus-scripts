#!/usr/bin/env python3

import json
import os, sys
import gi
gi.require_version("Gtk", "3.0")
from gi.repository import Gtk

if hasattr(sys, 'ps1'):
    script_dir = os.getcwd()
else:
    script_dir = os.path.dirname(os.path.realpath(__file__))

os.chdir(script_dir)

# import importlib
# lm = importlib.import_module("loteus-manage")
import loteus_manage as lm

gladesource = open(f'{script_dir}/LoteusInstall.glade','r').read()

def get_disk_info()-> str:
    o,c,e = lm.run_cmd("lsblk --list --noheadings | grep -v memory | grep -v squashfs | grep -v 'loop' | grep -v 'zram' | grep -v 'crypto_LUKS' | grep -v 'EFI System' | grep -v 'BIOS boot partition'")
    if c != 0:
        return e
    info = lm.get_info()
    # part_with_max_size = lm.get_partion_with_max_available_size(info['disk_info'])
    _, mount_point, size = lm.get_baseimage_location()

    return f"""{o}

Click the button `Exec Gparted` to run the parition tool to create/resize
new partition to use. After exiting the disk infor will be refreshed.

Then type the device name below. It can be a full disk, or just a single
partition.

CAREFULL
  - For any case the data in the full disk or the partition will be erased.
  - You can not select the disk or partition that the current live
    system runs. They are

  mount at {mount_point}
  with size {size}


"""

class install_loteus:

    class Handler:
        def __init__(self, main):
            self.main = main
        def onDestroy(self, *args):
            self.main.w.close()
        def bt_cancel_activate_cb(self, *args):
            self.main.w.close()
        def bt_next_activate_cb(self, button):
            device = self.main.builder.get_object("dev_input").get_text()
            if device != "":
                install_out,install_c,e = lm.run_cmd(f'''xterm -e bash -c 'echo will run /opt/bin/build-usb-hybrid-grub-boot.sh {device}; echo "Review the command and type YES and hit enter to continue. "; read c; if [ "$c" = "YES" ]; then /opt/bin/build-usb-hybrid-grub-boot.sh {device} | tee /tmp/install.log; echo "Review the result and Hit enter to continue"; read ; else echo Aborted!; fi  ' ''')
                status = "SUCCESS" if install_c == 0 else "FAIL"
                install_out = open('/tmp/install.log','r').read()
                o,c,e = lm.run_cmd("efibootmgr")
                if c == 0:
                    msg = f"""List the current EFI boot order
{o}

Make sure the entry `ubuntu` is the first one to boot if you want Ubuntu to boot first. If not then you can set the boot order the way you want by running the command

sudo efibootmgr --bootorder XXXX,YYYY,ZZZZ

Explain:
    Explicitly set BootOrder (hex).  Any value from 0 to FFFF is accepted so long as it corresponds to  an  existing
    Boot#### variable, and zero padding is not required.

Install completed with status {status}. The command output is below

{install_out}"""

                else:
                    msg = f"""Install completed with status {status}. The command output is below

{install_out}"""
                self.main.textview_disk_info.get_buffer().set_text(msg)

        def bt_gparted_activate_cb(self, button):
            o,c,e = lm.run_cmd("gparted")
            print(f"DEBUG {o} error {e}")
            self.main.textview_disk_info.get_buffer().set_text(get_disk_info() )


    def __init__(self):
        self.builder = Gtk.Builder()
        self.builder.add_from_string(gladesource)
        self.builder.connect_signals(self.Handler(self))
        self.w = self.builder.get_object("install_window")
        self.textview_disk_info = self.builder.get_object("textview_disk_info")
        self.textview_disk_info.get_buffer().set_text(get_disk_info() )


class main:
    class Handler:
        def __init__(self, main):
            self.main = main
        def onDestroy(self, *args):
            Gtk.main_quit()

        def BT_INSTALL_clicked_cb(self, *arg):
            i_win = install_loteus()
            i_win.w.show_all()

        def BT_UPDATE_clicked_cb(self, *arg):
            lm.run_cmd(f"""xterm -e bash -c "{script_dir}/loteus-manage.py do_update; echo 'Hit enter to close'; read _junk"  """)
            # lm.run_cmd(f"""xterm -e bash -c "apt update; echo 'Hit enter to close'; read _junk" """)
        def BT_SAVE_CONFIG_clicked_cb(self, *arg):
            lm.run_cmd(f"""xterm -e bash -c "{script_dir}/loteus-manage.py save_config; echo 'Hit enter to close'; read _junk" """)
        def BT_SYS_UPGRADE_clicked_cb(self, *arg):
            lm.run_cmd(f"""xterm -e bash -c "echo 'The feature is currently not implemented yet. Hit enter to conitnue'; read junk" """)
        def BT_HELP_clicked_cb(self, *arg):
            lm.run_cmd(f"""xterm -e bash -c "echo 'The feature is currently not implemented yet. Hit enter to conitnue'; read junk" """)
        def BT_RESIZE_USB_clicked_cb(self, *arg):
            lm.run_cmd(f"""xterm -e bash -c "{script_dir}/loteus-manage.py resize_usb_root; echo 'Hit enter to close'; read _junk" """)
        def BT_CREATE_CHANGE_IMAGE_clicked_cb(self, *arg):
            lm.run_cmd(f"""xterm -e bash -c "echo 'Enter the size of the container. Hit enter to choose default 1G. To create 5G container enter 5000. You should make it as large as your disk space allows it. '; read IMAGE_SIZE; [ -z \"$IMAGE_SIZE\" ] && IMAGE_SIZE=1024; export IMAGE_SIZE; {script_dir}/loteus-manage.py create_change_image; echo 'Hit enter to close'; read _junk" """)
        def BT_UPDATE_TOOLS_clicked_cb(self, *arg):
            lm.run_cmd(f"""xterm -e bash -c "{script_dir}/loteus-manage.py update_tools; echo 'Hit enter to close'; read _junk" """)


    def __init__(self, builder):
        self.builder = builder
        self.builder.connect_signals(self.Handler(self))
        self.w = self.builder.get_object("main_window")

def start()        :
    builder = Gtk.Builder()
    builder.add_from_string(gladesource)
    mainclass = main(builder)
    mainclass.w.show_all()
    Gtk.main()

if __name__ == "__main__":
    start()