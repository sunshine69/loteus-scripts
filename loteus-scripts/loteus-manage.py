#!/usr/bin/env python3

import argparse
import logging
import os
import re
import subprocess
import sys
from getpass import getpass

# Configure logging to output to stdout/stderr
logging.basicConfig(
    level=logging.INFO,
    format='%(levelname)s: %(message)s',
    stream=sys.stdout
)
logger = logging.getLogger(__name__)


def run_command(cmd, shell=True):
    """
    Runs a command and streams output to stdout in real-time.
    This is suitable for both CLI usage (interactive) and Go frontend integration.
    """
    try:
        process = subprocess.Popen(
            cmd,
            shell=shell,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,  # Merge stderr into stdout for consistent streaming
            text=True,
            bufsize=1
        )
        
        while True:
            line = process.stdout.readline()
            if not line and process.poll() is not None:
                break
            
            if line:
                print(line, end='')  # Print immediately for real-time feedback
        
        return_code = process.returncode
        
        if return_code != 0:
            logger.error(f"Command exited with code {return_code}")
            
        return return_code

    except Exception as e:
        logger.error(f"Command failed: {e}")
        return 1


def run_command_capture(cmd, shell=True):
    """
    Runs a command and captures the output string.
    Used for logic functions that need to parse the result.
    """
    try:
        result = subprocess.run(
            cmd,
            shell=shell,
            capture_output=True,
            text=True
        )
        return result.stdout.strip(), result.returncode, result.stderr.strip()
    except Exception as e:
        logger.error(f"Command failed: {e}")
        return "", 1, str(e)


def get_info():
    """Gathers system information (disk space, OS, arch)."""
    output = {}
    
    # df command to get disk info
    try:
        result = subprocess.run(['df', '--output=source,fstype,size,avail,target'], 
                                capture_output=True, text=True, check=True)
        acceptedfs = ['ext4', 'btrfs', 'f2fs', 'xfs', 'jfs']
        
        for line in result.stdout.splitlines()[1:]:  # Skip header
            try:
                parts = re.split(r'\s+', line.strip())
                if len(parts) >= 5 and parts[1] in acceptedfs:
                    output[parts[0]] = {
                        'size': int(parts[2]),
                        'avail': int(parts[3]),
                        'fstype': parts[1],
                        'mountpoint': parts[4],
                        'dev': parts[0]
                    }
            except (ValueError, IndexError):
                continue
    except Exception as e:
        logger.error(f"Failed to get disk info: {e}")

    # OS and Arch
    try:
        os_cmd = subprocess.run(['grep', '-oP', r'(?<=os=)[^\s]+', '/proc/cmdline'], 
                                capture_output=True, text=True)
        os_name = os_cmd.stdout.strip()
        
        arch_cmd = subprocess.run(['uname', '-m'], capture_output=True, text=True)
        arch = arch_cmd.stdout.strip()
    except Exception as e:
        logger.error(f"Failed to get OS info: {e}")
        os_name, arch = "unknown", "unknown"

    return {'os': os_name, 'arch': arch, 'disk_info': output}


def get_partion_with_max_available_size(disk_info):
    """Finds the partition with the most available space."""
    if not disk_info:
        raise ValueError("No disk info available")
        
    max_avail = -1
    best_key = None
    
    for k, v in disk_info.items():
        if v['avail'] > max_avail:
            max_avail = v['avail']
            best_key = k
            
    return disk_info[best_key]


def get_baseimage_location():
    """Finds the current base image loop device and mount point."""
    try:
        result = subprocess.run(
            "losetup -a | grep '/001' | grep '\\.xzm'", 
            shell=True, capture_output=True, text=True
        )
        if result.returncode != 0:
            raise Exception("No base image found")
            
        loop_device = result.stdout.strip()
        
        # Extract mount point from path (e.g., /mnt/live/memory -> /mnt/live)
        _tmp = loop_device.split('/')
        mount_point = '/'.join(_tmp[1:3])
        
        size = os.path.getsize(loop_device)
        
        return loop_device, f"/{mount_point}", size
        
    except Exception as e:
        logger.error(f"ERROR get_baseimage_location {e}")
        sys.exit(1)


def new_image_location(sys_info, full_path, base_mount_point, base_size):
    """Determines where to store the new image based on available space."""
    size_need_in_byte = base_size * 2 + 100*1024*1024
    # df output is in KB, so we convert bytes to KB for comparison
    size_need = size_need_in_byte / 1024 
    
    disk_info = sys_info['disk_info']
    
    try:
        avail = next((v['avail'] for k, v in disk_info.items() if v['mountpoint'] == base_mount_point), 0)
    except StopIteration:
        avail = 0
        
    if avail < size_need:
        max_part = get_partion_with_max_available_size(disk_info)
        if max_part['avail'] < size_need:
            logger.error(f"No partition has enough space. Need {size_need}KB, have {max_part['avail']}KB")
            sys.exit(1)
        return f"{max_part['mountpoint']}/porteus-update-{sys_info['os']}-{sys_info['arch']}.squashfs"
        
    return f"{full_path}.new"


def merge_base():
    """Merges current changes into the base image."""
    sys_info = get_info()
    disk_info = sys_info['disk_info']
    
    try:
        full_path, mountpoint, size = get_baseimage_location()
    except Exception as e:
        logger.error(f"Failed to locate base image: {e}")
        return

    image_location = new_image_location(sys_info, full_path, mountpoint, size)
    work_dir = get_partion_with_max_available_size(disk_info)['mountpoint']
    
    command = f"""
/opt/bin/clean-snap.sh
mkdir {work_dir}/tmp_$$ || true
cd {work_dir}/tmp_$$
/opt/bin/save-session {full_path} n {work_dir}/tmp_$$
mv out.sqs {image_location}
cd {work_dir}
rm -rf tmp_$$
"""
    logger.info("Please wait. It may take up to 30 minutes to finish")
    run_command(command)
    logger.info("Done")


def do_update():
    """Runs system update and merges base."""
    logger.info("Running apt update && upgrade...")
    run_command("apt update; apt -y upgrade")
    logger.info("Merging base image...")
    merge_base()


def save_config():
    """Saves current configuration to the base image."""
    sys_info = get_info()
    disk_info = sys_info['disk_info']
    work_dir = get_partion_with_max_available_size(disk_info)['mountpoint']
    
    command = f'''mkdir {work_dir}/tmp_$$ || true
        cd {work_dir}/tmp_$$
        save-session 999 n {work_dir}/tmp_$$
        cd ..
        rm -rf tmp_$$
        '''
    logger.info(f"Saving config to {command}")
    run_command(command)
    logger.info("Done")


def create_change_image():
    """Creates an encrypted change image for persistence."""
    SIZE = os.getenv('IMAGE_SIZE', '1024')
    IMAGE_NAME = os.getenv('IMAGE_NAME', 'c.img')
    
    # Default path logic
    if not os.getenv('IMAGE_PATH'):
        try:
            sys_info = get_info()
            disk_info = sys_info['disk_info']
            IMAGE_PATH = get_partion_with_max_available_size(disk_info)['mountpoint']
            logger.info(f"Default IMAGE_PATH is {IMAGE_PATH}")
        except Exception as e:
            logger.error(f"Could not determine default path: {e}")
            IMAGE_PATH = "/mnt/live/memory" # Fallback
    else:
        IMAGE_PATH = os.getenv('IMAGE_PATH')

    MKFS = os.getenv('MKFS', 'mkfs.btrfs')
    BOOT_MOUNT = os.getenv('BOOT_MOUNT', '')
    BTRFS_COMPRESSION = os.getenv('BTRFS_COMPRESSION', 'zstd')
    XCHACHA_ENABLED = os.getenv('XCHACHA_ENABLED', '')

    # Password prompt
    try:
        password = getpass("Enter password to encrypt the image: ")
    except EOFError:
        logger.error("Password input failed (no TTY?). Aborting.")
        sys.exit(1)

    cmd = f"""export PASS={password}
    export BOOT_MOUNT={BOOT_MOUNT}
    export XCHACHA_ENABLED={XCHACHA_ENABLED}
    export BTRFS_COMPRESSION={BTRFS_COMPRESSION}
    /opt/bin/make-changes-image-enc.sh {SIZE} {IMAGE_PATH}/{IMAGE_NAME} {MKFS}
    """
    
    logger.info(f"Creating change image...")
    run_command(cmd)
    logger.info("Done")


def update_tools():
    """Updates tools from GitHub."""
    repo_url = 'https://github.com/sunshine69/loteus-scripts.git'
    cmd = f'''if [ ! -d /tmp/loteus-scripts/.git ]; then
        git clone {repo_url} /tmp/loteus-scripts
        else
            cd /tmp/loteus-scripts && git reset --hard; git clean -fd; git pull
        fi
        rsync -avh /tmp/loteus-scripts/loteus-scripts/ /opt/bin/
        chmod +x /opt/bin/*
    '''
    logger.info("Updating tools from GitHub...")
    run_command(cmd)


def resize_usb_root():
    """Resizes the last partition of a live USB."""
    # Check if running interactively? 
    if not sys.stdin.isatty():
        logger.warning("Not running in interactive terminal. Skipping confirmation.")
    else:
        confirm = input("TYPE 'yes' in CAPITAL to continue: ")
        if confirm != 'YES':
            logger.info("Aborted...")
            return

    try:
        full_path, mount_point, size = get_baseimage_location()
        dev_name = f"/dev/{mount_point.split('/')[2]}"
        
        # Re-fetch disk info to get current size (might have changed)
        sys_info = get_info()
        if dev_name in sys_info['disk_info']:
            size = sys_info['disk_info'][dev_name]['size']
            logger.info(f"Detected Mount Point: {mount_point}, Size: {int(size/1024/1024)} GB")
        else:
            logger.warning("Could not detect disk size.")

        if sys.stdin.isatty():
            confirm = input("TYPE 'yes' in CAPITAL to continue: ")
            if confirm != 'YES':
                logger.info("Aborted...")
                return
                
    except Exception as e:
        logger.error(f"Error detecting device: {e}")
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
    
    run_command(cmd)


def install_mod(mod_url):
    """Installs a module package."""
    if mod_url.startswith('http'):
        logger.error("URL download not supported. Please download manually.")
        sys.exit(1)

    mod_file_name = os.path.basename(mod_url)
    
    try:
        full_path, mountpoint, size = get_baseimage_location()
        base_dir_name = os.path.dirname(full_path)
        
        run_command(f"mv {mod_url} {base_dir_name}/{mod_file_name}")
        run_command(f"activate {base_dir_name}/{mod_file_name}")
        logger.info("Completed. New module activated on /opt/")
        
    except Exception as e:
        logger.error(f"Failed to install mod: {e}")


def main():
    parser = argparse.ArgumentParser(description="Loteus System Manager")
    subparsers = parser.add_subparsers(dest='command', help='Available commands')

    # Define subcommands matching original keys for compatibility with Go frontend
    subparsers.add_parser('do_update', help='Run apt update ; apt -y upgrade and then merge it to base.')
    subparsers.add_parser('update_kernel', help='Update kernel to the latest version (Not implemented).')
    
    p_create = subparsers.add_parser('create_change_image', help='Create an encrypted change image.')
    
    subparsers.add_parser('merge_base', help='Save current changes into the system base image.')
    subparsers.add_parser('save_config', help='Save current config into system config.')
    
    p_update_tools = subparsers.add_parser('update_tools', help='Update loteus tools scripts from github.')
    
    subparsers.add_parser('resize_usb_root', help='Resize the last partition of the live USB.')
    
    p_install_mod = subparsers.add_parser('install_mod', help='Install a module package.')
    p_install_mod.add_argument('mod_url', nargs='?', default=None, help='URL or file path to the module')

    args = parser.parse_args()

    if not args.command:
        parser.print_help()
        return

    try:
        if args.command == 'do_update':
            do_update()
        elif args.command == 'update_kernel':
            logger.info("Kernel update is currently a placeholder.")
        elif args.command == 'create_change_image':
            create_change_image()
        elif args.command == 'merge_base':
            merge_base()
        elif args.command == 'save_config':
            save_config()
        elif args.command == 'update_tools':
            update_tools()
        elif args.command == 'resize_usb_root':
            resize_usb_root()
        elif args.command == 'install_mod':
            if not args.mod_url:
                logger.error("Missing mod URL/file path")
                sys.exit(1)
            install_mod(args.mod_url)
    except Exception as e:
        logger.error(f"Main error: {e}")

if __name__ == '__main__':
    main()
