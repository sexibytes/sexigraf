#!/bin/bash
if [[ "$1" =~ ^\/mnt\/wfs\/whisper\/.*$|^\/tmp\/.*$ ]]
then
        rm -rf "$1"
fi
