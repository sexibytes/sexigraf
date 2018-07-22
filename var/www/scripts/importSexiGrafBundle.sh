#!/bin/bash

# Import whiper files and re-apply Graphite ownership and correct access rights
/etc/init.d/carbon-cache stop
/bin/cp -fR /media/cdrom/whisper/* /var/lib/graphite/whisper/
chown _graphite:_graphite -R /var/lib/graphite/whisper/*
find /var/lib/graphite/whisper/ -type d -exec chmod 755 {} \;
find /var/lib/graphite/whisper/ -type f -exec chmod 644 {} \;

# Import cron entries
/bin/cp /media/cdrom/conf/cron.d/* /etc/cron.d/

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

# Restart services
/etc/init.d/carbon-cache start
/etc/init.d/collectd restart
/etc/init.d/grafana-server restart
/etc/init.d/apache2 restart

# Eject iso file to prevent a "code 40"
eject -v /dev/cdrom
