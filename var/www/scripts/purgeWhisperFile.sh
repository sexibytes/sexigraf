#!/bin/bash
if [[ "$1" =~ ^\/var\/lib\/graphite\/whisper\/.*$|^\/tmp\/.*$ ]]
then
        rm -rf "$1"
fi
