#!/bin/bash
if [ -z $1 ]
then
    MTIME=120
else
    MTIME=$1
fi
/usr/bin/find -L /mnt/wfs/whisper/ -type f \( -name '*.wsp' \) -mtime +$MTIME -exec rm {} \; ; /usr/bin/find -L /mnt/wfs/whisper/ -type d -empty -delete
