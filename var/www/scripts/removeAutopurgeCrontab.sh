#!/bin/bash
crontabFile="/etc/cron.d/graphite_autopurge"
rm -f $crontabFile
service cron reload
