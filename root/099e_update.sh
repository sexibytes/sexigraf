if grep -i -q "Nova Prospekt" /etc/sexigraf_version; then
 /bin/cp -rf /tmp/sexigraf-update/sexigraf-master/etc/* /etc/
 /bin/cp -rf /tmp/sexigraf-update/sexigraf-master/root/* /root/
 /bin/cp -rf /tmp/sexigraf-update/sexigraf-master/usr/* /usr/
 /bin/cp -rf /tmp/sexigraf-update/sexigraf-master/var/* /var/
 /bin/tar -xzf /root/VMware-vSphere-Perl-SDK-6.7.0-8156551.x86_64.tar.gz -C /root
 /bin/sed -i 's/ubuntu/debian/g' /root/vmware-vsphere-cli-distrib/vmware-install.pl
 yes | PAGER=/bin/cat /root/vmware-vsphere-cli-distrib/vmware-install.pl default
 mv /root/genisoimage /usr/bin/
 chmod +x /usr/bin/genisoimage
 chown grafana:grafana /var/lib/grafana/dashboards/*.json
 mv /etc/cron.daily/logrotate /etc/cron.hourly/
 service grafana-server restart
 a2enmod rewrite
 a2enmod ssl
 rm -rf /root/vmware-vsphere-cli-distrib
 rm -f /root/VMware-vSphere-Perl-SDK-6.7.0-8156551.x86_64.tar.gz
 echo "Pimp Your Stats!"
 apachectl graceful
 rm -f /root/099e_update.sh
else
 echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
 echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
 echo "     THIS UPDATE IS NOT SUPPORTED ON YOUR SEXIGRAF VERSION     "
 echo "            PLEASE UPGRADE TO 0.99d AND TRY AGAIN              "
 echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
 echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
 rm -f /root/099e_update.sh
 exit 1
fi
