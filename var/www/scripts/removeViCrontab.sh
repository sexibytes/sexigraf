#!/bin/bash
crontabFile="/etc/cron.d/vi_$(sed s/\\./_/g <<<$1)"
rm -f $crontabFile
