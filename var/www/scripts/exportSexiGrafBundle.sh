#!/bin/bash

# purge existing export files
rm -rf /root/sexigraf-dump/
rm -f /var/www/admin/sexigraf-dump.iso

# create root folders
mkdir /root/sexigraf-dump/
mkdir /root/sexigraf-dump/whisper/
mkdir /root/sexigraf-dump/conf/
mkdir /root/sexigraf-dump/conf/cron.d/

# Retrieve whiper files
cp -R /var/lib/graphite/whisper/ /root/sexigraf-dump/whisper/

# Retrieve cron entries
cp /etc/cron.d/vi_* /root/sexigraf-dump/conf/cron.d/
cp /etc/cron.d/vsan_* /root/sexigraf-dump/conf/cron.d/

# Retrieve credential store items
for creditem in $(/usr/lib/vmware-vcli/apps/general/credstore_admin.pl --credstore /var/www/.vmware/credstore/vicredentials.xml list | egrep -v "Server|^$" | sed "s/\s/;/")
do
    vcenter=$(echo $creditem | cut -d ";" -f 1)
    username=$(echo $creditem | cut -d ";" -f 2)
    password="/usr/lib/vmware-vcli/apps/general/credstore_admin.pl --credstore /var/www/.vmware/credstore/vicredentials.xml get --server $vcenter --username '$username'"
    password=$(eval "$password" | cut -c 11-)
    echo "$vcenter;$username;$password" >> /root/sexigraf-dump/conf/vicredentials.conf
done
# File encoding
openssl des3 -salt -in /root/sexigraf-dump/conf/vicredentials.conf -out /root/sexigraf-dump/conf/vicredentials.conf.ss -pass pass:sexigraf
rm -f /root/sexigraf-dump/conf/vicredentials.conf
#openssl des3 -d -salt -in /root/sexigraf-dump/conf/vicredentials.conf.ss -out /root/sexigraf-dump/conf/vicredentials.conf2 -pass pass:sexigraf

# create ISO file from export folder
genisoimage -o /var/www/admin/sexigraf-dump.iso /root/sexigraf-dump
