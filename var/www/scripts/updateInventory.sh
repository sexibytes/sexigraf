#!/bin/bash
/usr/bin/pwsh -NonInteractive -NoProfile -f /opt/sexigraf/ViOfflineInventory.ps1 -credstore /var/www/.vmware/credstore/vipscredentials.xml >/dev/null 2>&1