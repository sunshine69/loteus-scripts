#!/usr/bin/python3

import requests, sys, os

def DownloadFile(url):
    local_filename = ""
    try:
        local_filename = sys.argv[2]
    except:
        local_filename = url.split('/')[-1]
    if os.path.exists(local_filename):
        print("Target file {fname} exist. Aborting.".format(fname=local_filename))
        sys.exit(1)
    r = requests.get(url, stream=True)
    f = open(local_filename, 'wb')
    for chunk in r.iter_content(chunk_size=512 * 1024):
        if chunk: # filter out keep-alive new chunks
            f.write(chunk)
    f.close()
    return

if __name__ == "__main__":
    url = sys.argv[1]
    DownloadFile(url)

