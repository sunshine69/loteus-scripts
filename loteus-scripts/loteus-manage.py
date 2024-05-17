#!/usr/bin/env python3

# A front end script to manage several things that is loteus specific. This will call other scripts to do the job

import re, sys, subprocess, os
from getpass import getpass
import threading
import time

def stdout_printer(p, output_list: dict):
    for line in p.stdout:
        _l = line.decode('utf-8').rstrip()
        print(_l)
        output_list['stdout'].append(_l)
    for line in p.stderr:
        _l = line.decode('utf-8').rstrip()
        print(_l)
        output_list['stderr'].append(_l)

def run_cmd(cmd, sendtxt=None, working_dir=".", args=[], shell=True, DEBUG=False, shlex=False, printOutput=False):
    if DEBUG:
        cmd2 = re.sub(r'root:([^\s])', r'root:xxxxx', cmd) # suppress the root password printout
        print(cmd2)
    if sys.platform == "win32":
        args = cmd
    else:
        if shlex:
            import shlex
            args = shlex.split(cmd)
        else:
            args = cmd

    popen = subprocess.Popen(
            args,
            shell=shell,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            stdin=subprocess.PIPE,
            cwd=working_dir
        )

    output, code, errmsg = "", 0, ""
    if printOutput:
        output_list = {'stdout': [], 'stderr': []}
        t = threading.Thread(target=stdout_printer, args=(popen, output_list))
        t.start()
        if sendtxt: popen.stdin.write(sendtxt.encode('utf-8'))
        popen.stdin.flush()
        popen.stdin.close()
        while True:
            code = popen.poll()
            if code is None: time.sleep(1)
            else: break
        t.join()
        output = "\n".join( output_list['stdout'] )
        errmsg = "\n".join( output_list['stderr'] )
    else:
        if sendtxt: output, err = popen.communicate(bytearray(sendtxt, 'utf-8'))
        else: _output, err = popen.communicate()
        code = popen.returncode
        output = _output.decode('utf-8')
        if not code == 0 or DEBUG:
            output = "Command string: '%s'\n\n%s" % (cmd, output)
        errmsg = err.decode('utf-8')

    return (output.strip(), code, errmsg)

def get_info():
    output = {  }
    o,c,e = run_cmd('df --output=source,fstype,size,avail,target')
    acceptedfs = ['ext4', 'btrfs', 'f2fs', 'xfs', 'jfs']
    for line in o.splitlines():
        try:
            _dev, _fstype, size, avail, _mount = re.split(r'[\s]+', line)
            if _fstype in acceptedfs:
                try:
                    output[_dev] = {}
                    output[_dev]['size'] = int(size)
                    output[_dev]['avail'] = int(avail)
                    output[_dev]['fstype'] = _fstype
                    output[_dev]['mountpoint'] = _mount
                    output[_dev]['dev'] = _dev
                except Exception as e:
                    print(e)
                    continue
        except Exception as e:
            continue
    os, c, e = run_cmd(r"""grep -oP '(?<=os=)[^\s]+' /proc/cmdline""")
    arch, c, e = run_cmd("""uname -m""")

    return {'os': os, 'arch': arch, 'disk_info': output  }

def get_partion_with_max_available_size(disk_info):
    avail_num, key = 0, ''
    for k in disk_info:
        if avail_num < disk_info[k]['avail']:
            avail_num = disk_info[k]['avail']
            key = k

    return disk_info[key]

def get_baseimage_location(): # full_path, mount_point, size
    o,c,e = run_cmd(r"""losetup -a |  grep -P '\/001[^\s]+\.xzm' | grep -oP '(?<= \()[^\)]+'""")
    if c != 0:
        print(f"ERROR get_baseimage_location {e}")
        sys.exit(1)
    _tmp = o.split('/')
    mount_point = '/'.join(_tmp[1:3])
    return o, f"/{mount_point}", os.path.getsize(o)

def get_avail_size(disk_info, mountpoint):
    try:
        return [disk_info[x]['avail'] for x in disk_info if disk_info[x]['mountpoint'] == mountpoint][0]
    except:
        print("ERROR get_avail_size not found")
        return 0


def new_image_location(sys_info, full_path, base_mount_point, base_size): # return the path we should mv out.sqs to and the current img size
    size_need_in_byte = base_size * 2 + 100*1024*1024 # twice + 100M
    size_need = size_need_in_byte / 1024
    disk_info = sys_info['disk_info']
    if get_avail_size(disk_info, base_mount_point) < size_need:
        # Need to copy to the update image
        max_part = get_partion_with_max_available_size(disk_info)
        if max_part['avail'] < size_need:
            print(f"ERROR No partition has enough size needed {size_need} for the operation. base_size: {base_size} ")
            sys.exit(1)

        return f"{max_part['mountpoint']}/porteus-update-{sys_info['os']}-{sys_info['arch']}.squashfs"
    return f"{full_path}.new"

def merge_base():
    sys_info = get_info()
    disk_info = sys_info['disk_info']
    full_path, mountpoint, size = get_baseimage_location()
    image_location = new_image_location(sys_info, full_path, mountpoint, size )
    work_dir = get_partion_with_max_available_size(disk_info)['mountpoint']
    command = f"""/opt/bin/clean-snap.sh
    mkdir {work_dir}/tmp_$$ || true
    cd {work_dir}/tmp_$$
    /opt/bin/save-session {full_path} n {work_dir}/tmp_$$
    mv out.sqs {image_location}
    cd {work_dir}
    rm -rf tmp_$$
    """
    print(f"COMMAND: {command}")
    run_cmd(command, printOutput=True)
    print("Done")

def do_update():
    cmd = "apt update; apt -y upgrade"
    print(f"Run {cmd}")
    run_cmd(cmd, printOutput=True)
    print("Run merge_base")
    merge_base()

def save_config():
    sys_info = get_info()
    disk_info = sys_info['disk_info']
    work_dir = get_partion_with_max_available_size(disk_info)['mountpoint']
    cmd = f'''mkdir {work_dir}/tmp_$$ || true
        cd {work_dir}/tmp_$$
        save-session 999 n {work_dir}/tmp_$$
        cd ..
        rm -rf tmp_$$
        '''
    print(cmd)
    o, c, e = run_cmd(cmd)
    if c != 0:
        print(f"ERROR save_config {e}")
    else:
        print(f"Done {o}\n{e}")

def create_change_image():
    SIZE = os.getenv('IMAGE_SIZE', '')
    if SIZE == '':
        print("INFO Use size 1024M. To set size eg. `export IMAGE_SIZE=2048` will create 2G image")
        SIZE = '1024'
    IMAGE_NAME = os.getenv('IMAGE_NAME', '')
    if IMAGE_NAME == '':
        IMAGE_NAME = 'c.img'
        print("INFO Image name is c.img - set env var IMAGE_NAME to change")
    IMAGE_PATH = os.getenv('IMAGE_PATH', '')
    if IMAGE_PATH == '':
        sys_info = get_info()
        disk_info = sys_info['disk_info']
        IMAGE_PATH = get_partion_with_max_available_size(disk_info)['mountpoint']
        print(f"INFO default IMAGE_PATH is {IMAGE_PATH}, set env var IMAGE_PATH to change. It needs to be the root mount point of the partition")
    MKFS = os.getenv('MKFS', '')
    if MKFS == '':
        print(f"INFO Use {MKFS} to create file system. Set your env var MKFS to change")
        MKFS = 'mkfs.btrfs'
    BOOT_MOUNT = os.getenv('BOOT_MOUNT','')
    if BOOT_MOUNT == '':
        print("INFO BOOT_MOUNT not set, will parse as default but might not correct. You need to edit your own grub file if so. Set BOOT_MOUNT manually mount point to where your /boot/grub partition is - eg /mnt/sda2")

    BTRFS_COMPRESSION = os.getenv('BTRFS_COMPRESSION','zstd')
    if BOOT_MOUNT == '':
        print("INFO BTRFS_COMPRESSION not set, default to zstd")
    XCHACHA_ENABLED = os.getenv('XCHACHA_ENABLED', '')
    password = getpass("Enter password to encrypt the image: ")
    cmd = f"""export PASS={password}
    export BOOT_MOUNT={BOOT_MOUNT}
    export XCHACHA_ENABLED={XCHACHA_ENABLED}
    export BTRFS_COMPRESSION={BTRFS_COMPRESSION}
    /opt/bin/make-changes-image-enc.sh {SIZE} {IMAGE_PATH}/{IMAGE_NAME} {MKFS}
    """
    print(cmd)
    o,c,e = run_cmd(cmd)
    if c != 0:
        print(f"ERROR command {cmd}")
        print(f"ERROR {e}")
    else:
        print(f"Done {o}\n{e}")


def update_kernel():
    pass


def update_tools():
    repo_url = 'https://github.com/sunshine69/loteus-scripts.git'
    cmd = f'''if [ ! -d /tmp/loteus-scripts/.git ]; then
        git clone {repo_url} /tmp/loteus-scripts
        else
            cd /tmp/loteus-scripts && git reset --hard; git clean -fd; git pull
        fi
        rsync -avh /tmp/loteus-scripts/loteus-scripts/ /opt/bin/
        chmod +x /opt/bin/*
    '''
    o,c,e = run_cmd(cmd, printOutput=True)


def resize_usb_root():
    print("**** WARNING ****\nTHIS SCRIPT ONLE RESIZE THE LIVE USB ROOT CREATED BY THE USB IMAGE\nIF YOU ALREADY INSTALL IT INTO THE INTERNAL DISK THEN DO NOT RUN THIS COMMAND\nBACKUP BEFORE PROCEED IF YOU ALREADY HAVE DATA")
    confirm = input("TYPE 'yes' in CAPITAL to continue: ")
    if confirm != 'YES':
        print("Aborted...")
        return
    full_path, mount_point, size = get_baseimage_location()
    dev_name = f"/dev/{mount_point.split('/')[2]}"
    disk_info = get_info()['disk_info']
    size = disk_info[dev_name]['size']
    confirm = input(f"DETECTED MOUNT POINT {mount_point} WITH SIZE {int(size/1024/1024)} GB\nTYPE 'yes' in CAPITAL to continue: ")
    if confirm != 'YES':
        print("Aborted...")
        return
    cmd = f"""
    dev_name=$(echo {dev_name} | sed 's/[0-9]\\+//g')
    mydev=$(basename $dev_name)
    if `ls -lha /sys/block/$mydev | grep '/usb[0-9]\\+' >/dev/null 2>&1`; then
      _x_is_usb=yes
    else
      _x_is_usb=no
    fi
    if [ "$_x_is_usb" = "yes" ]; then
        dev_name=$(ls -l /sys/block/ | grep '/usb[0-9]\\+' | grep -oP '(?<=block\\/).*$')
        echo "DEBUG: $_x_is_usb: dev_name: $dev_name "
        /opt/bin/resize-last-part.sh /dev/$dev_name
    fi"""
    o,c,e = run_cmd(cmd)
    print(f"DEBUG Output: {o}\nDEBUG Error: '{e}' ignore if empty")

def install_mod():
    try:
        mod_url = sys.argv[2]
    except:
        print("[ERROR] Need to provide url or file path to the module")
        sys.exit(1)
    if mod_url.startswith('http'):
        print("URL download has not yet supported. You download it using normal browser and then run this script using the file path")
        sys.exit(1)

    mod_file = mod_url
    mod_file_name, o, e = run_cmd(f"basename {mod_file}")

    full_path, mountpoint, size = get_baseimage_location()
    base_dir_name, c, e = run_cmd(f"dirname {full_path}")
    run_cmd(f"mv {mod_file} {base_dir_name}/{mod_file_name}")
    run_cmd(f"activate {base_dir_name}/{mod_file_name}")
    print("Completed. New module activated on /opt/ you can try to get in there and run the program in its bin folder\nYou can create short cut by yourself")
    o,c,e = run_cmd('ls -lha /opt')
    print(o)

cmdlist = {
        'do_update': {
            'help': 'Run apt update ; apt -y upgrade and then merge it to base. You need to restart the system after that',
            'run': do_update
        },
        'update_kernel': {
            'help': 'Update kernel to the latest version',
            'run': update_kernel
        },
        'create_change_image': {
            'help': 'Create a encrypted change image. This will be used for the next reboot. The current changes data will be copied into the image and it will be encrypted. Controll Vars: IMAGE_SIZE[in MB like 3000 for 3G], IMAGE_NAME[default:c.img], IMAGE_PATH[auto detect], MKFS[default:mkfs.btrfs], BOOT_MOUNT[auto detect], XCHACHA_ENABLED[default: n y|n], BTRFS_COMPRESSION[default: zstd zstd|lzo|zlib]',
            'run':  create_change_image
        },
        'merge_base': {
            'help': 'Save the current changes into the system base image. Next reboot you should select teh boot menu RESET to use the new updated sase system image',
            'run': merge_base
        },
        'save_config': {
            'help': 'Save current config into system config so if you boot with reset option it will retain',
            'run': save_config,
        },
        'update_tools': {
            'help': 'Update loteus tools scripts from github. This will download and update cripts tools in /opt/bin/ ',
            'run': update_tools,
        },
        'resize_usb_root': {
            'help': 'Resize the last partition of the live USB to maximum size supported by the usb disk. DO NOT NEED TO RUN IT IF YOU HAVE INSTALL THE SYSTEM TO THE INTERNAL DISK',
            'run': resize_usb_root,
        },
        'install_mod': {
            'help': 'Download and install the loteus module package. Need to give it the URL or module file name',
            'run': install_mod,
        }
}

def help():
    print(f"\n***** Usage *****\n{sys.argv[0]} <command>\n")
    for _cmd in cmdlist:
        print(f"command `{_cmd}`:\n{cmdlist[_cmd]['help']}\n")

if __name__ == '__main__':
    try:
        command = sys.argv[1]
        cmdlist[command]['run']()
    except Exception as e:
        print("ERROR main", e)
        help()

