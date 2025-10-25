#!/bin/bash
crontabFile="/etc/cron.d/ViOfflineInventory"
if [ -z $1 ]
then
    MTIME=10
else
    MTIME=$1
fi
echo "3  */1    * * *   root /usr/bin/pwsh -NonInteractive -NoProfile -f /opt/sexigraf/ViOfflineInventory.ps1 -credstore /mnt/wfs/inventory/vipscredentials.xml -InvWeeks $MTIME >/dev/null 2>&1" > $crontabFile
service cron reload >/dev/null 2>&1