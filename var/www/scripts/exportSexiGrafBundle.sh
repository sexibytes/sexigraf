#!/bin/bash

# purge existing export files
rm -rf /root/sexigraf-export/
rm -f /var/www/admin/sexigraf-export.iso

# create root folders
mkdir /root/sexigraf-export/
mkdir /root/sexigraf-export/whisper/
mkdir /root/sexigraf-export/conf/
mkdir /root/sexigraf-export/conf/cron.d/

# Retrieve whiper files
cp -R /var/lib/graphite/whisper/ /root/sexigraf-export/whisper/

# Retrieve cron entries
cp /etc/cron.d/vi_* /root/sexigraf-export/conf/cron.d/
cp /etc/cron.d/vsan_* /root/sexigraf-export/conf/cron.d/

# Retrieve credential store items
for creditem in $(/usr/lib/vmware-vcli/apps/general/credstore_admin.pl --credstore /var/www/.vmware/credstore/vicredentials.xml list | egrep -v "Server|^$" | sed "s/\s/;/")
do
    vcenter=$(echo $creditem | cut -d ";" -f 1)
    username=$(echo $creditem | cut -d ";" -f 2)
    password="/usr/lib/vmware-vcli/apps/general/credstore_admin.pl --credstore /var/www/.vmware/credstore/vicredentials.xml get --server $vcenter --username '$username'"
    password=$(eval "$password" | cut -c 11-)
    echo "$vcenter;$username;$password" >> /root/sexigraf-export/conf/vicredentials.conf
done
# File encoding
openssl des3 -salt -in /root/sexigraf-export/conf/vicredentials.conf -out /root/sexigraf-export/conf/vicredentials.conf.ss -pass pass:sexigraf
rm -f /root/sexigraf-export/conf/vicredentials.conf
#openssl des3 -d -salt -in /root/sexigraf-export/conf/vicredentials.conf.ss -out /root/sexigraf-export/conf/vicredentials.conf2 -pass pass:sexigraf

# create ISO file from export folder
genisoimage -o /var/www/admin/sexigraf-export.iso /root/sexigraf-export
