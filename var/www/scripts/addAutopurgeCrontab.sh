#!/bin/bash
crontabFile="/etc/cron.d/graphite_autopurge"
if [ -z $1 ]
then
    MTIME=120
else
    MTIME=$1
fi
echo "37  13    * * *   root   /usr/bin/find -L /var/lib/graphite/whisper/ -type f \( -name '*.wsp' \) -mtime +$MTIME -exec rm {} \; ; /usr/bin/find -L /var/lib/graphite/whisper/ -type d -empty -delete" >> $crontabFile
service cron reload
