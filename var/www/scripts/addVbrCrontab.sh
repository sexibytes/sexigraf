#!/bin/bash
sessionFile="/tmp/vbr_$(sed s/\\./_/g <<<$1).key"
crontabFile="/etc/cron.d/vbr_$(sed s/\\./_/g <<<$1)"
echo "*/5  *    * * *   root   /usr/bin/pwsh -NonInteractive -NoProfile -f  /opt/veeam/VbrPullStatistics.ps1 -credstore /mnt/wfs/inventory/vbrpscredentials.xml -server $1 -sessionfile $sessionFile >/dev/null 2>&1" >> $crontabFile
echo "3  */1    * * *   root /usr/bin/pwsh -NonInteractive -NoProfile -f /opt/veeam/VbrVmInventory.ps1 >/dev/null 2>&1" > "/etc/cron.d/VbrVmInventory"
service cron reload