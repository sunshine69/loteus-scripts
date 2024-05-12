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
    o,c,e = lm.run_cmd("blkid | grep -v squashfs | grep -v '/dev/loop' | grep -v '/dev/zram' | grep -v 'crypto_LUKS' | grep -v 'EFI System' | grep -v 'BIOS boot partition'")
    if c != 0:
        return e
    info = lm.get_info()
    part_with_max_size = lm.get_partion_with_max_available_size(info['disk_info'])
    return f"""{o}

part_with_max_size: {part_with_max_size}

Click the button `Exec Gparted` to run the parition tool to create/resize new partition to use. AFter exiting the disk infor will be refreshed.

Then type the device name below. It can be a full disk, or just a single partition.

CAREFULL - For any case the data in the full disk or the partition will be erased.

"""

class main:

    class Handler:
        def __init__(self, main):
            self.main = main
        def onDestroy(self, *args):
            Gtk.main_quit()
        def bt_cancel_activate_cb(self, *args):
            Gtk.main_quit()
        def bt_next_activate_cb(self, button):
            self.main.textview_disk_info.get_buffer().set_text("You click Next")
        def bt_gparted_activate_cb(self, button):
            lm.run_cmd("gparted")
            self.main.textview_disk_info.get_buffer().set_text(get_disk_info() )


    def __init__(self):
        self.builder = Gtk.Builder()
        self.builder.add_from_string(gladesource)
        self.builder.connect_signals(self.Handler(self))
        w = self.builder.get_object("mainwindow")
        self.textview_disk_info = self.builder.get_object("textview_disk_info")
        self.textview_disk_info.get_buffer().set_text(get_disk_info() )

        w.show_all()
        Gtk.main()

m = main()