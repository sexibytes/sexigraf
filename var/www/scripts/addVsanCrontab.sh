#!/bin/bash
sessionFile="/tmp/vmw_$(sed s/\\./_/g <<<$1).key"
crontabFile="/etc/cron.d/vsan_$(sed s/\\./_/g <<<$1)"
echo "*  *    * * *   root   /usr/bin/pwsh -NonInteractive -NoProfile -f  /opt/sexigraf/VsanPullStatistics.ps1 -credstore /mnt/wfs/inventory/vipscredentials.xml -server $1 -sessionfile $sessionFile >/dev/null 2>&1" >> $crontabFile
service cron reload