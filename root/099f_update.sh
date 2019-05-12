if grep -i -q "White Forest" /etc/sexigraf_version; then
 /bin/cp -rf /tmp/sexigraf-update/sexigraf-master/etc/* /etc/
 /bin/cp -rf /tmp/sexigraf-update/sexigraf-master/root/* /root/
 dpkg -i grafana_4.6.5_amd64.deb
 /bin/cp -rf /tmp/sexigraf-update/sexigraf-master/usr/* /usr/
 /bin/cp -rf /tmp/sexigraf-update/sexigraf-master/var/* /var/
 rm -f /root/grafana_4.6.5_amd64.deb
 mv -f /usr/share/grafana/public/img/grafana_icon.svg /usr/share/grafana/public/img/grafana_icon_orig.svg
 ln -s /usr/share/grafana/public/img/sexigraf.svg /usr/share/grafana/public/img/grafana_icon.svg
 sqlite3 /var/lib/grafana/grafana.db "UPDATE data_source SET json_data= X'7B22677261706869746556657273696F6E223A22302E39227D' WHERE id = '1';"
 service grafana-server restart
 echo "Pimp Your Stats!"
 apachectl graceful
 rm -f /root/099f_update.sh
else
 echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
 echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
 echo "     THIS UPDATE IS NOT SUPPORTED ON YOUR SEXIGRAF VERSION     "
 echo "            PLEASE UPGRADE TO 0.99e AND TRY AGAIN              "
 echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
 echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
 rm -f /root/099f_update.sh
 exit 1
fi
