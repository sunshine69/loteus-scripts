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
version_short_full_list = { '.'.join(x[0].split('.')[0:2]): x[0] for x in version_info1}

short_ver_to_check_list = ['5.15','5.18']

os.chdir('/mnt/portdata/tmp')
ptn = re.compile(r'SUBLEVEL = ([\d]+)')

output_ver_list = {}

for short_ver in short_ver_to_check_list:
    text = open('linux-'+short_ver+'/Makefile', 'r').read()
    m = ptn.search(text)
    if m:
        SUBLEVEL = m.group(1)
        local_full_ver = short_ver + '.' + SUBLEVEL
        if short_ver in version_short_full_list:
            remote_current_ver = version_short_full_list[short_ver]
            if version.parse(remote_current_ver) > version.parse(local_full_ver):
                output_ver_list[short_ver] = {'local': local_full_ver, 'remote': remote_current_ver }

if len(output_ver_list) > 0:
    print('New version detected from remote')
    print(output_ver_list)
    os.chdir('/home/stevek/src/kernel-build-scripts/porteus-scripts')
    os.system('''./sendmail.py -f steve345@gmail.com -t msh.computing@gmail.com -s '{subject}' -m '{msg}' --server smtp.gmail.com -u skieu345@gmail.com -p "{passwd}"'''.format(subject='New linux kernel version detected from remote', msg=output_ver_list, passwd=os.getenv(MAIL_PASSWORD)) )
