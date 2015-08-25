#!/bin/bash
sessionFile="/tmp/vpx_$(sed s/\\./_/g <<<$1).dat"
crontabFile="/etc/cron.d2/vsan_$(sed s/\\./_/g <<<$1)"
# /tmp/vpx_184_7_64_240.dat
#echo "*/5  *    * * *   root   /root/ViPullStatistics.pl --server $1 --sessionfile /tmp/$sessionFile" > $crontabFile
#echo "*/5  *    * * *   root   /root/ViPullStatistics.pl --server $1 --sessionfile $sessionFile > $crontabFile"
echo "*  *    * * *   root   /root/VsanPullStatistics.pl --server $1 --sessionfile $sessionFile" > $crontabFile
