#!/bin/bash
crontabFile="/etc/cron.d/graphite_autopurge"
echo "37  13    * * *   root   /usr/bin/find -L /var/lib/graphite/whisper/vmw/ -type f \( -name '*.wsp' \) -mtime +120 -exec rm {} \; ; /usr/bin/find -L /var/lib/graphite/whisper/ -type d -empty -delete" >> $crontabFile
service cron reload
