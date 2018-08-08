#!/bin/bash
blkid /dev/sr0 1>/dev/null
MSTATUS=$?

if [ $MSTATUS -eq 0 ]; then
        mount /dev/sr0 /media/cdrom
fi
