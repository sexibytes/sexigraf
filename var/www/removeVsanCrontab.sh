#!/bin/bash
crontabFile="/etc/cron.d2/vsan_$(sed s/\\./_/g <<<$1)"
rm -f $crontabFile
