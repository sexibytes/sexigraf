#!/bin/bash
sessionFile="/tmp/vmw_$(sed s/\\./_/g <<<$1).key"
crontabFile="/etc/cron.d/vi_$(sed s/\\./_/g <<<$1)"
echo "*/5  *    * * *   root   /usr/bin/pwsh -NonInteractive -NoProfile -f  /opt/sexigraf/ViPullStatistics.ps1 -credstore /var/www/.vmware/credstore/vipscredentials.xml -server $1 -sessionfile $sessionFile >/dev/null 2>&1" >> $crontabFile
service cron reload