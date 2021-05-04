#!/bin/bash

if [ -d "/mnt/wfs/whisper" ]; then

    # purge existing export files
    rm -rf /mnt/wfs/sexigraf-dump/
    rm -f /mnt/wfs/sexigraf-dump.iso
    rm -f /var/www/admin/sexigraf-dump.iso

    # create root folders
    mkdir /mnt/wfs/sexigraf-dump/
    # mkdir /root/sexigraf-dump/whisper/
    mkdir /mnt/wfs/sexigraf-dump/conf/
    mkdir /mnt/wfs/sexigraf-dump/conf/cron.d/

    # Info file
    echo "Built on server" $(hostname) "on" $(date) > /mnt/wfs/sexigraf-dump/dump.info

    # Retrieve whiper files
    # cp -R /var/lib/graphite/whisper/* /root/sexigraf-dump/whisper/
    # ln -s /var/lib/graphite/whisper /root/sexigraf-dump/
    # tar -zcvf /root/sexigraf-dump/whisper.tgz -C /var/lib/graphite/whisper .
    tar -zcvf /mnt/wfs/sexigraf-dump/whisper.tgz -C /mnt/wfs/whisper .

    # Retrieve cron entries
    cp /etc/cron.d/vi_* /mnt/wfs/sexigraf-dump/conf/cron.d/
    cp /etc/cron.d/vsan_* /mnt/wfs/sexigraf-dump/conf/cron.d/

    # Retrieve version file
    cp /etc/sexigraf_version /mnt/wfs/sexigraf-dump/

    # Retrieve Offline Inventory
    cp /var/www/admin/offline-vminventory.html /mnt/wfs/sexigraf-dump/

    # Retrieve credential store items
    for creditem in $(/usr/lib/vmware-vcli/apps/general/credstore_admin.pl --credstore /var/www/.vmware/credstore/vicredentials.xml list | egrep -v "Server|^$" | sed "s/[[:space:]]\+/;/")
    do
        vcenter=$(echo $creditem | cut -d ";" -f 1)
        username=$(echo $creditem | cut -d ";" -f 2)
        password="/usr/lib/vmware-vcli/apps/general/credstore_admin.pl --credstore /var/www/.vmware/credstore/vicredentials.xml get --server $vcenter --username '$username'"
        password=$(eval "$password" | cut -c 11-)
        echo "$vcenter;$username;$password" >> /mnt/wfs/sexigraf-dump/conf/vicredentials.conf
    done
    cp /var/www/.vmware/credstore/vipscredentials.xml /mnt/wfs/sexigraf-dump/conf/vipscredentials.xml
    
    # File encoding
    openssl des3 -salt -in /mnt/wfs/sexigraf-dump/conf/vicredentials.conf -out /mnt/wfs/sexigraf-dump/conf/vicredentials.conf.ss -pass pass:sexigraf
    rm -f /mnt/wfs/sexigraf-dump/conf/vicredentials.conf

    # create ISO file from export folder
    /usr/bin/genisoimage --allow-limited-size -udf -f -J -joliet-long -r -U -iso-level 4 -o /mnt/wfs/sexigraf-dump.iso /mnt/wfs/sexigraf-dump
    ln -s /mnt/wfs/sexigraf-dump.iso /var/www/admin/sexigraf-dump.iso

    # cleanup
    rm -rf /mnt/wfs/sexigraf-dump/

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
    /usr/bin/genisoimage --allow-limited-size -udf -f -J -joliet-long -r -U -iso-level 4 -o /var/www/admin/sexigraf-dump.iso /root/sexigraf-dump

    # cleanup
    rm -rf /root/sexigraf-dump/

fi
