#!/bin/bash
crontabFile="/etc/cron.d/graphite_autopurge"
echo "37  13    * * *   root   /usr/bin/find -L /zfs/whisper/vmw/ -type f \( -name '*.wsp' \) -mtime +120 -exec rm {} \; ; /usr/bin/find -L /zfs/whisper/ -type d -empty -delete" >> $crontabFile
service cron reload
