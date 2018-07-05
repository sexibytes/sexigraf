#!/bin/bash
#
tar -xzf VMware-vSphere-Perl-SDK-6.7.0-8156551.x86_64.tar.gz -C /root
sed -i 's/ubuntu/debian/g' /root/vmware-vsphere-cli-distrib/vmware-install.pl
yes | PAGER=cat /root/vmware-vsphere-cli-distrib/vmware-install.pl default
