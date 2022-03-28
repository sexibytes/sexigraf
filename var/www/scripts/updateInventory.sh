#!/bin/bash
/usr/bin/pwsh -NonInteractive -NoProfile -f /opt/sexigraf/ViOfflineInventory.ps1 -credstore /mnt/wfs/inventory/vipscredentials.xml >/dev/null 2>&1