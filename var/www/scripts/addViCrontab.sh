#!/bin/bash
sessionFile="/tmp/vpx_$(sed s/\\./_/g <<<$1).dat"
crontabFile="/etc/cron.d/vi_$(sed s/\\./_/g <<<$1)"
echo "*/5  *    * * *   root   /usr/bin/perl /root/ViPullStatistics.pl --server $1 --sessionfile $sessionFile" >> $crontabFile
service cron reload
