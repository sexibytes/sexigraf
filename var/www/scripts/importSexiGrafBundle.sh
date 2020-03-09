#!/bin/bash

if [ -d "/zfs/whisper" ]; then

    # Import whiper files and re-apply Graphite ownership and correct access rights
    /etc/init.d/carbon-cache stop
    if [ -d "/media/cdrom/whisper" ]; then
        /bin/cp -fR /media/cdrom/whisper/* /zfs/whisper/
    else
        tar -zxvf /media/cdrom/whisper.tgz -C /zfs/whisper/
    fi
    # chown _graphite:_graphite -R /var/lib/graphite/whisper/*
    # find /var/lib/graphite/whisper/ -type d -exec chmod 755 {} \;
    # find /var/lib/graphite/whisper/ -type f -exec chmod 644 {} \;
    chown -R carbon /zfs/whisper

    # Import cron entries
    /bin/cp /media/cdrom/conf/cron.d/* /etc/cron.d/

    # Import Offline Inventory file
    /bin/cp /media/cdrom/offline-vminventory.html /var/www/admin/
    chown www-data:www-data /var/www/admin/offline-vminventory.html
    chmod 644 /var/www/admin/offline-vminventory.html

    # Import credential store items
    openssl des3 -d -salt -in /media/cdrom/conf/vicredentials.conf.ss -out /root/vicredentials.conf -pass pass:sexigraf
    for creditem in $(cat /root/vicredentials.conf)
    do
        vcenter=$(echo $creditem | cut -d ";" -f 1)
        username=$(echo $creditem | cut -d ";" -f 2)
        password=$(echo $creditem | cut -d ";" -f 3)
        /usr/lib/vmware-vcli/apps/general/credstore_admin.pl --credstore /var/www/.vmware/credstore/vicredentials.xml add --server $vcenter --username $username --password $password
    done
    rm -f /root/vicredentials.conf

else

    # Import whiper files and re-apply Graphite ownership and correct access rights
    /etc/init.d/carbon-cache stop
    if [ -d "/media/cdrom/whisper" ]; then
        /bin/cp -fR /media/cdrom/whisper/* /opt/graphite/storage/whisper/
    else
        tar -zxvf /media/cdrom/whisper.tgz -C /opt/graphite/storage/whisper/
    fi
    # chown _graphite:_graphite -R /var/lib/graphite/whisper/*
    # find /var/lib/graphite/whisper/ -type d -exec chmod 755 {} \;
    # find /var/lib/graphite/whisper/ -type f -exec chmod 644 {} \;
    chown -R carbon /opt/graphite/storage/whisper

    # Import cron entries
    /bin/cp /media/cdrom/conf/cron.d/* /etc/cron.d/

    # Import Offline Inventory file
    /bin/cp /media/cdrom/offline-vminventory.html /var/www/admin/
    chown www-data:www-data /var/www/admin/offline-vminventory.html
    chmod 644 /var/www/admin/offline-vminventory.html

    # Import credential store items
    openssl des3 -d -salt -in /media/cdrom/conf/vicredentials.conf.ss -out /root/vicredentials.conf -pass pass:sexigraf
    for creditem in $(cat /root/vicredentials.conf)
    do
        vcenter=$(echo $creditem | cut -d ";" -f 1)
        username=$(echo $creditem | cut -d ";" -f 2)
        password=$(echo $creditem | cut -d ";" -f 3)
        /usr/lib/vmware-vcli/apps/general/credstore_admin.pl --credstore /var/www/.vmware/credstore/vicredentials.xml add --server $vcenter --username $username --password $password
    done
    rm -f /root/vicredentials.conf

fi

# Restart services
/etc/init.d/carbon-cache start
/etc/init.d/collectd restart
/etc/init.d/grafana-server restart
apachectl restart

# Eject iso file to prevent a "code 40"
eject
