#!/bin/bash
sessionFile="/tmp/vpx_$(sed s/\\./_/g <<<$1).dat"
crontabFile="/etc/cron.d/vsan_$(sed s/\\./_/g <<<$1)"
echo "*  *    * * *   root   /usr/bin/perl /root/VsanPullStatistics.pl --server $1 --sessionfile $sessionFile" > $crontabFile
