#!/usr/bin/env python3

import smtplib
import mimetypes
from optparse import OptionParser
from email import encoders
from email.message import Message
from email.mime.audio import MIMEAudio
from email.mime.base import MIMEBase
from email.mime.image import MIMEImage
from email.mime.multipart import MIMEMultipart
from email.mime.text import MIMEText

COMMASPACE = ', '

import sys,getopt,os

FROM=TO=SUBJECT=ATTACH=MSG=SERVER=user_name=use_ssl=PORT=DEBUG=password=port=None

def  help():
    print ("Usage:  %s  -f[--from] from -t[--to] 'recipient1;recipeint2'  -s[--sub] subject -m[--msg] message_string -a[--attach] 'filepath1;filepath2' --server smtp_server  -u[--user] username -p[--passwd]  password -use-ssl " % sys.argv[0])


#  getopt( args, options[, long_options])
# gnu_getopt(   args, options[, long_options]) This will not stop processing if hit non-option argument

try: opts, args = getopt.getopt(sys.argv[1:], "f:t:s:a:m:u:p:d",  [ 'from=', 'to=', 'sub=', 'attach=', 'msg=', 'server=', 'user=', 'passwd=', 'use-ssl', 'port=', 'debug' ] )
except:  help()

for opt, arg in opts:
    if opt == '-f'  or opt == '--from': FROM=arg
    elif opt == '-t'  or opt == '--to': TO = arg
    elif opt == '-s'  or opt == '--sub': SUBJECT = arg
    elif opt == '-a'  or opt == '--attach': ATTACH = arg
    elif opt == '-m'  or opt == '--msg': MSG = arg
    elif opt == '--server': SERVER = arg
    elif opt == '-u'  or opt == '--user': user_name = arg
    elif opt == '-p'  or opt == '--passwd': password = arg
    elif opt == '--use-ssl': use_ssl = True
    elif opt == '--port': PORT = arg
    elif opt == '-d' or opt == '--debug': DEBUG = True

SERVER = SERVER if SERVER != None else (args[0]  if len(args) == 1 else  'smtp.gmail.com')

if SERVER == 'smtp.gmail.com':
    PORT = 587
    use_ssl = True

if TO == None:
    help()
    sys.exit(0)

#print("From: %s\nTo: %s\nSubject: %s\nAttaches: %s\nMSG: %s\nSERVER: %s\nuser_name: %s\nPass: %s\nuse_ssl: %s\nPort: %s" % (FROM, TO, SUBJECT, ATTACH, MSG, SERVER, user_name,password, use_ssl, port))

if ATTACH != None:
    paths = ATTACH.split(COMMASPACE)
    outer = MIMEMultipart()
    outer.attach( MIMEText(MSG , 'plain') )

    for path in paths:
        if os.path.isfile(path):
            filename = os.path.split(path)[1]
            ctype, encoding = mimetypes.guess_type(path)

            if ctype is None or encoding is not None:
                ctype = 'application/octet-stream'

            maintype, subtype = ctype.split('/', 1)

            if maintype == 'text':
                    fp = open(path)
                    # Note: we should handle calculating the charset
                    msg = MIMEText(fp.read(), _subtype=subtype)
                    fp.close()
            elif maintype == 'image':
                    fp = open(path, 'rb')
                    msg = MIMEImage(fp.read(), _subtype=subtype)
                    fp.close()
            elif maintype == 'audio':
                    fp = open(path, 'rb')
                    msg = MIMEAudio(fp.read(), _subtype=subtype)
                    fp.close()
            else:
                    fp = open(path, 'rb')
                    msg = MIMEBase(maintype, subtype)
                    msg.set_payload(fp.read())
                    fp.close()
            # Encode the payload using Base64
            encoders.encode_base64(msg)
            msg.add_header('Content-Disposition', 'attachment', filename=filename)
            outer.attach(msg)

else: outer = MIMEText(MSG)

outer['Subject'] = SUBJECT
outer['From'] = FROM
outer['To'] = TO

if PORT == None:
    port = ( 25 if use_ssl == None else 465 )
else: port = PORT

if DEBUG:
    print  ("From: %s\nTo: %s\nSubject: %s\nAttaches: %s\nMSG: %s\nSERVER: %s\nuser_name: %s\nPass: %s\nuse_ssl: %s\nPort: %s" % (FROM, TO, SUBJECT, ATTACH, MSG, SERVER, user_name,password, use_ssl, port))

mailer = smtplib.SMTP(SERVER, port)

if use_ssl:
    mailer.ehlo()
    mailer.starttls()

if user_name != None:
    mailer.login(user_name, password)

mailer.sendmail(FROM, TO.split(COMMASPACE), outer.as_string() )
mailer.quit()
