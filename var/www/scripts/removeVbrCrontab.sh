#!/bin/bash
crontabFile="/etc/cron.d/vbr_$(sed s/\\./_/g <<<$1)"
rm -f $crontabFile
service cron reload
