#!/usr/bin/env python3

# A front end script to manage several things that is loteus specific. This will call other scripts to do the job

import re, sys, subprocess, os
from getpass import getpass

def run_cmd(cmd,sendtxt=None, working_dir=".", args=[], shell=True, DEBUG=False, shlex=False):
    if DEBUG:
        cmd2 = re.sub('root:([^\s])', 'root:xxxxx', cmd) # suppress the root password printout
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
    if sendtxt: output, err = popen.communicate(bytearray(sendtxt, 'utf-8'))
    else: _output, err = popen.communicate()
    code = popen.returncode
    output = _output.decode('utf-8')
    if not code == 0 or DEBUG:
        output = "Command string: '%s'\n\n%s" % (cmd, output)
    return (output.strip(), code, err.decode('utf-8'))

def get_info():
    output = {  }
    o,c,e = run_cmd('df --output=source,fstype,avail,target')
    acceptedfs = ['ext4', 'btrfs', 'f2fs', 'xfs', 'jfs']
    for line in o.splitlines():
        try:
            _dev, _fstype, avail, _mount = re.split('[\s]+', line.decode('utf-8'))
            if _fstype in acceptedfs:
                try:
                    output[_dev] = {}
                    output[_dev]['avail'] = int(avail)
                    output[_dev]['fstype'] = _fstype
                    output[_dev]['mountpoint'] = _mount
                    output[_dev]['dev'] = _dev
                except:
                    continue
        except: continue
    os, c, e = run_cmd("""grep -oP '(?<=os=)[^\s]+' /proc/cmdline""")
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
    o,c,e = run_cmd("""losetup -a | grep '\/base\/001' | grep -oP '(?<= \()[^\)]+'""")
    if c != 0:
        print(f"ERROR {e}")
        sys.exit(1)
    _tmp = o.split('/')
    mount_point = '/'.join(_tmp[1:3])
    return o, f"/{mount_point}", os.path.getsize(o)

def get_avail_size(disk_info, mountpoint):
    try:
        return [disk_info[x]['avail'] for x in disk_info if disk_info[x]['mountpoint'] == mountpoint][0]
    except:
        print("ERROR not found")
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
    run_cmd(command)
    print("Done")

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
        print(f"ERROR {e}")
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
    password = getpass("Enter password to encrypt the image: ")
    cmd = f"""export PASS={password}
    /opt/bin/make-changes-image-enc.sh {SIZE} {IMAGE_NAME} {IMAGE_PATH}
    """
    o,c,e = run_cmd(cmd)
    if c != 0:
        print(f"ERROR command {cmd}")
        print(f"ERROR {e}")
    else:
        print(f"Done {o}\n{e}")

def update_tools():
    repo_url = 'https://github.com/sunshine69/loteus-scripts.git'
    cmd = f'''if [ ! -d /tmp/loteus-scripts/.git ]; then
        git clone {repo_url} /tmp/loteus-scripts
        else
            cd /tmp/loteus-scripts && git pull
        fi
        rsync -avh /tmp/loteus-scripts/loteus-scripts/ /opt/bin/
    '''
    o,c,e = run_cmd(cmd)
    print(f"Output: {o}\nError: '{e}' (Ignore if empty)")

cmdlist = {
        'create_change_image': {
            'help': 'Create a encrypted change image. This will be used for the next reboot. The current changes data will be copied into the image and it will be encrypted.',
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
        print("ERROR -- ", e)
        help()

