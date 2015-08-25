#1/bin/bash
if [[ "$1" =~ ^\/var\/lib\/graphite\/whisper\/.*$ ]]
then
	rm -rf "$1"
fi
