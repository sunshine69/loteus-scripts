#!/usr/bin/env python3

# Merge the base root image with current changes

import re, sys, subprocess, os

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
    else: output, err = popen.communicate()
    code = popen.returncode
    if not code == 0 or DEBUG:
        output = "Command string: '%s'\n\n%s" % (cmd, output)
    return (output.strip(), code, err)

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

    return {'os': os.decode('utf-8'), 'arch': arch.decode('utf-8'), 'disk_info': output  }

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
    o = o.decode('utf-8')
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

def main():
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

if __name__ == '__main__':
    main()
