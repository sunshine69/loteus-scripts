#!/usr/bin/env python3

import os
import re
import requests
from packaging import version
from html import unescape
from bs4 import BeautifulSoup

xmldata = requests.get('https://www.kernel.org/feeds/kdist.xml')
mycontent = unescape( str(xmldata.content) )
s = BeautifulSoup(mycontent,'html.parser')
version_info = [x.find('title').text for x in s.find_all('item')]

# ['5.19-rc4: mainline',
# '5.18.8: stable',
# '5.17.15: stable',
# '5.15.51: longterm',
# '5.10.127: longterm',
# '5.4.202: longterm',
# '4.19.249: longterm',
# '4.14.285: longterm',
# '4.9.320: longterm',
# 'next-20220629: linux-next']

version_info1 = [ list(map(str.strip, x.split(':'))) for x in version_info ]
lookup_full_ver_by_short_ver_dict = { '.'.join(x[0].split('.')[0:2]): x[0] for x in version_info1}

short_ver_to_check_list = ['5.15','5.18']

ptn = re.compile(r'SUBLEVEL = ([\d]+)')
portetus_kernel_filename_ptn = re.compile(r'porteus-kernel\-([\d]+\.[\d]+\.[\d]+)')

output_ver_list, local_full_ver = {}, ""

for short_ver in short_ver_to_check_list:
    k_makefile = f'/mnt/portdata/tmp/linux-{short_ver}/Makefile'
    if os.path.isfile(k_makefile):
        text = open(k_makefile, 'r').read()
        m = ptn.search(text)
        if m:
            SUBLEVEL = m.group(1)
            local_full_ver = f'{short_ver}.{SUBLEVEL}'
    else:
        from glob import glob
        kfile_list = glob(f'/mnt/sdb4/doc/opc-backup/porteus-kernel-{short_ver}*.sfx')
        kfile_list.sort()
        m = portetus_kernel_filename_ptn.search( kfile_list[-1] )
        if m:
            local_full_ver = m.group(1)

    if short_ver in lookup_full_ver_by_short_ver_dict:
        remote_current_ver = lookup_full_ver_by_short_ver_dict[short_ver]
        if version.parse(remote_current_ver) > version.parse(local_full_ver):
            output_ver_list[short_ver] = {'local': local_full_ver, 'remote': remote_current_ver }

if len(output_ver_list) > 0:
    print('New version detected from remote')
    print(output_ver_list)
    os.system('''sendmail.py -f steve345@gmail.com -t msh.computing@gmail.com -s '{subject}' -m '{msg}' --server smtp.gmail.com -u skieu345@gmail.com -p "{passwd}"'''.format(subject='New linux kernel version detected from remote', msg=output_ver_list, passwd=os.getenv('MAIL_PASSWORD')))
