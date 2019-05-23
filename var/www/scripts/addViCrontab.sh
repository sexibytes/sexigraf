#!/bin/bash
sessionFile="/tmp/vpx_$(sed s/\\./_/g <<<$1).dat"
crontabFile="/etc/cron.d/vi_$(sed s/\\./_/g <<<$1)"
echo "*/5  *    * * *   root   /usr/bin/perl /root/ViPullStatistics.pl --credstore /var/www/.vmware/credstore/vicredentials.xml --server $1 --sessionfile $sessionFile >/dev/null 2>&1" >> $crontabFile
service cron reload
