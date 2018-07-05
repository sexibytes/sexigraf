#!/bin/bash
#
/bin/tar -xzf /root/VMware-vSphere-Perl-SDK-6.7.0-8156551.x86_64.tar.gz -C /root
/bin/sed -i 's/ubuntu/debian/g' /root/vmware-vsphere-cli-distrib/vmware-install.pl
yes | PAGER=/bin/cat /root/vmware-vsphere-cli-distrib/vmware-install.pl default
