#!/bin/bash
sessionFile="/tmp/vbr_$(sed s/\\./_/g <<<$1).key"
crontabFile="/etc/cron.d/vbr_$(sed s/\\./_/g <<<$1)"
echo "*/5  *    * * *   root   /usr/bin/pwsh -NonInteractive -NoProfile -f  /opt/sexigraf/VbrPullStatistics.ps1 -credstore /mnt/wfs/inventory/vbrpscredentials.xml -server $1 -sessionfile $sessionFile >/dev/null 2>&1" >> $crontabFile
service cron reload