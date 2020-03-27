#!/bin/bash

if [ -d "/zfs/whisper" ]; then

    # purge existing export files
    rm -rf /zfs/sexigraf-dump/
    rm -f /zfs/sexigraf-dump.iso
    rm -f /var/www/admin/sexigraf-dump.iso

    # create root folders
    mkdir /zfs/sexigraf-dump/
    # mkdir /root/sexigraf-dump/whisper/
    mkdir /zfs/sexigraf-dump/conf/
    mkdir /zfs/sexigraf-dump/conf/cron.d/

    # Info file
    echo "Built on server" $(hostname) "on" $(date) > /zfs/sexigraf-dump/dump.info

    # Retrieve whiper files
    # cp -R /var/lib/graphite/whisper/* /root/sexigraf-dump/whisper/
    # ln -s /var/lib/graphite/whisper /root/sexigraf-dump/
    # tar -zcvf /root/sexigraf-dump/whisper.tgz -C /var/lib/graphite/whisper .
    tar -zcvf /zfs/sexigraf-dump/whisper.tgz -C /zfs/whisper .

    # Retrieve cron entries
    cp /etc/cron.d/vi_* /zfs/sexigraf-dump/conf/cron.d/
    cp /etc/cron.d/vsan_* /zfs/sexigraf-dump/conf/cron.d/

    # Retrieve version file
    cp /etc/sexigraf_version /zfs/sexigraf-dump/

    # Retrieve Offline Inventory
    cp /var/www/admin/offline-vminventory.html /zfs/sexigraf-dump/

    # Retrieve credential store items
    for creditem in $(/usr/lib/vmware-vcli/apps/general/credstore_admin.pl --credstore /var/www/.vmware/credstore/vicredentials.xml list | egrep -v "Server|^$" | sed "s/[[:space:]]\+/;/")
    do
        vcenter=$(echo $creditem | cut -d ";" -f 1)
        username=$(echo $creditem | cut -d ";" -f 2)
        password="/usr/lib/vmware-vcli/apps/general/credstore_admin.pl --credstore /var/www/.vmware/credstore/vicredentials.xml get --server $vcenter --username '$username'"
        password=$(eval "$password" | cut -c 11-)
        echo "$vcenter;$username;$password" >> /zfs/sexigraf-dump/conf/vicredentials.conf
    done
    # File encoding
    openssl des3 -salt -in /zfs/sexigraf-dump/conf/vicredentials.conf -out /zfs/sexigraf-dump/conf/vicredentials.conf.ss -pass pass:sexigraf
    rm -f /zfs/sexigraf-dump/conf/vicredentials.conf

    # create ISO file from export folder
    /usr/bin/genisoimage -f -J -joliet-long -r -U -iso-level 4 -o /zfs/sexigraf-dump.iso /zfs/sexigraf-dump
    ln -s /zfs/sexigraf-dump.iso /var/www/admin/sexigraf-dump.iso

    # cleanup
    rm -rf /zfs/sexigraf-dump/

else

    # purge existing export files
    rm -rf /root/sexigraf-dump/
    rm -f /var/www/admin/sexigraf-dump.iso

    # create root folders
    mkdir /root/sexigraf-dump/
    # mkdir /root/sexigraf-dump/whisper/
    mkdir /root/sexigraf-dump/conf/
    mkdir /root/sexigraf-dump/conf/cron.d/

    # Info file
    echo "Built on server" $(hostname) "on" $(date) > /root/sexigraf-dump/dump.info

    # Retrieve whiper files
    # cp -R /var/lib/graphite/whisper/* /root/sexigraf-dump/whisper/
    # ln -s /var/lib/graphite/whisper /root/sexigraf-dump/
    # tar -zcvf /root/sexigraf-dump/whisper.tgz -C /var/lib/graphite/whisper .
    tar -zcvf /root/sexigraf-dump/whisper.tgz -C /opt/graphite/storage/whisper .

    # Retrieve cron entries
    cp /etc/cron.d/vi_* /root/sexigraf-dump/conf/cron.d/
    cp /etc/cron.d/vsan_* /root/sexigraf-dump/conf/cron.d/

    # Retrieve version file
    cp /etc/sexigraf_version /root/sexigraf-dump/

    # Retrieve Offline Inventory
    cp /var/www/admin/offline-vminventory.html /root/sexigraf-dump/

    # Retrieve credential store items
    for creditem in $(/usr/lib/vmware-vcli/apps/general/credstore_admin.pl --credstore /var/www/.vmware/credstore/vicredentials.xml list | egrep -v "Server|^$" | sed "s/[[:space:]]\+/;/")
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

    # create ISO file from export folder
    /usr/bin/genisoimage -f -J -joliet-long -r -U -iso-level 4 -o /var/www/admin/sexigraf-dump.iso /root/sexigraf-dump

    # cleanup
    rm -rf /root/sexigraf-dump/

fi
