#!/bin/bash

if [ -d "/mnt/wfs/whisper" ]; then

    # Import whiper files and re-apply Graphite ownership and correct access rights
    /etc/init.d/carbon-cache stop
    /etc/init.d/carbon-relay stop
    /etc/init.d/cron stop
    if [ -d "/media/cdrom/whisper" ]; then
        /bin/cp -fR /media/cdrom/whisper/* /mnt/wfs/whisper/
    else
        tar -zxvf /media/cdrom/whisper.tgz -C /mnt/wfs/whisper/
    fi
    # chown _graphite:_graphite -R /var/lib/graphite/whisper/*
    # find /var/lib/graphite/whisper/ -type d -exec chmod 755 {} \;
    # find /var/lib/graphite/whisper/ -type f -exec chmod 644 {} \;
    ### XXX check sexigraf version
    /usr/bin/find -L /mnt/wfs/whisper/ -type f \( -name '*numVmotions.wsp' \) -exec /usr/local/bin/whisper-set-aggregation-method.py {} last 0 \;
    /usr/bin/find -L /mnt/wfs/whisper/ -type f \( -name '*droppedRx.wsp' \) -exec /usr/local/bin/whisper-set-aggregation-method.py {} sum 0 \;
    /usr/bin/find -L /mnt/wfs/whisper/ -type f \( -name '*droppedTx.wsp' \) -exec /usr/local/bin/whisper-set-aggregation-method.py {} sum 0 \;
    /usr/bin/find -L /mnt/wfs/whisper/ -type f \( -name '*errorsRx.wsp' \) -exec /usr/local/bin/whisper-set-aggregation-method.py {} sum 0 \;
    /usr/bin/find -L /mnt/wfs/whisper/ -type f \( -name '*errorsTx.wsp' \) -exec /usr/local/bin/whisper-set-aggregation-method.py {} sum 0 \;
    /usr/bin/find -L /mnt/wfs/whisper/vsan/*/*/*/vsan/spaceDetail -type f \( -name '*.wsp' \) -exec /usr/local/bin/whisper-resize.py {} 5m:24h 10m:48h 40m:7d 240m:30d 720m:90d 2880m:1y 5760m:2y 17280m:5y --nobackup \;
    chown -R carbon /mnt/wfs/whisper

    # Import Offline Inventory file
    /bin/cp -fR /media/cdrom/*.csv /mnt/wfs/inventory/
    # chown www-data:www-data /var/www/admin/offline-vminventory.html
    # chmod 644 /var/www/admin/offline-vminventory.html

    # Import credential store items
    if [ -a "/var/www/.vmware/credstore/vicredentials.xml" ]; then
        openssl des3 -d -salt -in /media/cdrom/conf/vicredentials.conf.ss -out /tmp/vicredentials.conf -pass pass:sexigraf -md md5
        # /usr/bin/pwsh -NonInteractive -NoProfile -f /opt/sexigraf/CredstoreAdmin.ps1 -createstore -credstore /var/www/.vmware/credstore/vipscredentials.xml
        for creditem in $(cat /tmp/vicredentials.conf)
            do
                vcenter=$(echo $creditem | cut -d ";" -f 1)
                username=$(echo $creditem | cut -d ";" -f 2)
                password=$(echo $creditem | cut -d ";" -f 3)
                # /usr/lib/vmware-vcli/apps/general/credstore_admin.pl --credstore /var/www/.vmware/credstore/vicredentials.xml add --server $vcenter --username $username --password $password
                /usr/bin/pwsh -NonInteractive -NoProfile -f /opt/sexigraf/CredstoreAdmin.ps1 -credstore /var/www/.vmware/credstore/vipscredentials.xml -add -server $vcenter -username $username -password $password
        done
        rm -f /tmp/vicredentials.conf
        # chown www-data:www-data /var/www/.vmware/credstore/vipscredentials.xml
    fi

    if [ -a "/media/cdrom/conf/vipscredentials.xml" ]; then
        /bin/cp -fR /media/cdrom/conf/vipscredentials.xml /var/www/.vmware/credstore/vipscredentials.xml
        chown www-data:www-data /var/www/.vmware/credstore/vipscredentials.xml
    fi

    # Import cron entries
    /bin/cp -fR /media/cdrom/conf/cron.d/* /etc/cron.d/

    # Switch from perl to powershell
    /bin/sed -i 's/\/usr\/bin\/perl \/root\/VsanPullStatistics\.pl --credstore \/var\/www\/\.vmware\/credstore\/vicredentials\.xml --server/\/usr\/bin\/pwsh -NonInteractive -NoProfile -f \/opt\/sexigraf\/VsanPullStatistics\.ps1 -credstore \/var\/www\/\.vmware\/credstore\/vipscredentials\.xml -server/g' /etc/cron.d/vsan_*
    /bin/sed -i 's/--sessionfile \/tmp\/vpx_/-sessionfile \/tmp\/vmw_/g' /etc/cron.d/vsan_*
    /bin/sed -i 's/\.dat$/.key >\/dev\/null 2\>\&1/g' /etc/cron.d/vsan_*

    /bin/sed -i 's/\/usr\/bin\/perl \/root\/ViPullStatistics\.pl --credstore \/var\/www\/\.vmware\/credstore\/vicredentials\.xml --server/\/usr\/bin\/pwsh -NonInteractive -NoProfile -f \/opt\/sexigraf\/ViPullStatistics\.ps1 -credstore \/var\/www\/\.vmware\/credstore\/vipscredentials\.xml -server/g' /etc/cron.d/vi_*
    /bin/sed -i 's/--sessionfile \/tmp\/vpx_/-sessionfile \/tmp\/vmw_/g' /etc/cron.d/vi_*
    /bin/sed -i 's/\.dat$/.key >\/dev\/null 2\>\&1/g' /etc/cron.d/vi_*   

    # Restart services
    /etc/init.d/carbon-cache start
    /etc/init.d/carbon-relay start
    /etc/init.d/cron start
    /etc/init.d/collectd restart
    /etc/init.d/grafana-server restart
    apachectl restart

    # 0.99g storage schema change #217
    # nohup /usr/bin/find -L /mnt/wfs/whisper/vmw/ -type f \( -name '*.wsp' \) -exec /usr/local/bin/whisper-resize.py {} 5m:24h 10m:48h 80m:7d 240m:30d 720m:90d 2880m:1y 5760m:2y 17280m:5y --nobackup \; > /var/log/sexigraf/vmw_wsp_resize.log 2>&1 &
    # nohup /usr/bin/find -L /mnt/wfs/whisper/esx/ -type f \( -name '*.wsp' \) -exec /usr/local/bin/whisper-resize.py {} 5m:24h 10m:48h 80m:7d 240m:30d 720m:90d 2880m:1y 5760m:2y 17280m:5y --nobackup \; > /var/log/sexigraf/esx_wsp_resize.log 2>&1 &

    # Eject iso file to prevent a "code 40"
    eject

fi
