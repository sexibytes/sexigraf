#!/bin/bash
crontabFile="/etc/cron.d2/vi_$(sed s/\\./_/g <<<$1)"
rm -f $crontabFile
