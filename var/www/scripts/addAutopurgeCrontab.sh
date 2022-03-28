#!/bin/bash
crontabFile="/etc/cron.d/graphite_autopurge"
if [ -z $1 ]
then
    MTIME=120
else
    MTIME=$1
fi
echo "37  13    * * *   root   /usr/bin/pwsh -NonInteractive -NoProfile -f  /opt/sexigraf/WhisperAutoPurge.ps1 -DaysOld $MTIME >/dev/null 2>&1" >> $crontabFile
service cron reload