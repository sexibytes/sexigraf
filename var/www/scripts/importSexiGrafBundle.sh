#!/bin/bash

if [ -d "/mnt/wfs/whisper" ]; then

    # Import whiper files and re-apply Graphite ownership and correct access rights
    /etc/init.d/carbon-cache stop
    /etc/init.d/cron stop
    if [ -d "/media/cdrom/whisper" ]; then
        /bin/cp -fR /media/cdrom/whisper/* /mnt/wfs/whisper/
    else
        tar -zxvf /media/cdrom/whisper.tgz -C /mnt/wfs/whisper/
    fi
    # chown _graphite:_graphite -R /var/lib/graphite/whisper/*
    # find /var/lib/graphite/whisper/ -type d -exec chmod 755 {} \;
    # find /var/lib/graphite/whisper/ -type f -exec chmod 644 {} \;
    /usr/bin/find -L /mnt/wfs/whisper/ -type f \( -name '*numVmotions.wsp' \) -exec /usr/local/bin/whisper-set-aggregation-method.py {} sum 0 \;
    chown -R carbon /mnt/wfs/whisper

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

    # Import cron entries
    /bin/cp /media/cdrom/conf/cron.d/* /etc/cron.d/

else

    # Import whiper files and re-apply Graphite ownership and correct access rights
    /etc/init.d/carbon-cache stop
    /etc/init.d/cron stop
    if [ -d "/media/cdrom/whisper" ]; then
        /bin/cp -fR /media/cdrom/whisper/* /opt/graphite/storage/whisper/
    else
        tar -zxvf /media/cdrom/whisper.tgz -C /opt/graphite/storage/whisper/
    fi
    # chown _graphite:_graphite -R /var/lib/graphite/whisper/*
    # find /var/lib/graphite/whisper/ -type d -exec chmod 755 {} \;
    # find /var/lib/graphite/whisper/ -type f -exec chmod 644 {} \;
    /usr/bin/find -L /opt/graphite/storage/whisper/ -type f \( -name '*numVmotions.wsp' \) -exec /usr/local/bin/whisper-set-aggregation-method.py {} sum 0 \;
    chown -R carbon /opt/graphite/storage/whisper

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

    # Import cron entries
    /bin/cp /media/cdrom/conf/cron.d/* /etc/cron.d/

fi

# Restart services
/etc/init.d/carbon-cache start
/etc/init.d/cron start
/etc/init.d/collectd restart
/etc/init.d/grafana-server restart
apachectl restart

# 0.99g storage schema change #217
# nohup /usr/bin/find -L /mnt/wfs/whisper/vmw/ -type f \( -name '*.wsp' \) -exec /usr/local/bin/whisper-resize.py {} 5m:24h 10m:48h 80m:7d 240m:30d 720m:90d 2880m:1y 5760m:2y 17280m:5y --nobackup \; > /var/log/sexigraf/vmw_wsp_resize.log 2>&1 &
# nohup /usr/bin/find -L /mnt/wfs/whisper/esx/ -type f \( -name '*.wsp' \) -exec /usr/local/bin/whisper-resize.py {} 5m:24h 10m:48h 80m:7d 240m:30d 720m:90d 2880m:1y 5760m:2y 17280m:5y --nobackup \; > /var/log/sexigraf/esx_wsp_resize.log 2>&1 &

# Eject iso file to prevent a "code 40"
eject
