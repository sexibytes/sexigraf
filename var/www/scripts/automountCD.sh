#!/bin/bash
blkid /dev/sr0 1>/dev/null
MSTATUS=$?

if [ $MSTATUS -eq 0 ]; then
        mkdir -p /media/cdrom
        mount -t iso9660 /dev/sr0 /media/cdrom
fi
