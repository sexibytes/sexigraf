#!/bin/bash
if [ -z $1 ]
then
    MTIME=120
else
    MTIME=$1
fi
/usr/bin/pwsh -NonInteractive -NoProfile -f  /opt/sexigraf/WhisperAutoPurge.ps1 -DaysOld $MTIME >/dev/null 2>&1
