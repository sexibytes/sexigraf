#!/bin/bash
sessionFile="/tmp/vpx_$(sed s/\\./_/g <<<$1).dat"
crontabFile="/etc/cron.d/vsan_$(sed s/\\./_/g <<<$1)"
echo "*  *    * * *   root   /usr/bin/pwsh -f  /opt/sexigraf/VsanPullStatistics.ps1 -credstore /var/www/.vmware/credstore/vicredentials.xml -server $1 -sessionfile $sessionFile >/dev/null 2>&1" >> $crontabFile
service cron reload
