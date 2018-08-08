# Change Log

## [Unreleased](https://github.com/sexibytes/sexigraf/tree/HEAD)

[Full Changelog](https://github.com/sexibytes/sexigraf/compare/0.99d...HEAD)

**Implemented enhancements:**

- Display appliance version in SexiMenu [\#122](https://github.com/sexibytes/sexigraf/issues/122)
- Dashboard init failed Template variables could not be initialized: undefined [\#62](https://github.com/sexibytes/sexigraf/issues/62)

**Fixed bugs:**

- House Cleaner not expanding subfolders [\#120](https://github.com/sexibytes/sexigraf/issues/120)
- Dashboard init failed Template variables could not be initialized: undefined [\#62](https://github.com/sexibytes/sexigraf/issues/62)
- dashboard metrics definition  [\#26](https://github.com/sexibytes/sexigraf/issues/26)

**Closed issues:**

- lower Y-Max from 180 to 150 on cpu/ram usage graph [\#117](https://github.com/sexibytes/sexigraf/issues/117)
- Time data request Error on graph [\#37](https://github.com/sexibytes/sexigraf/issues/37)

## [0.99d](https://github.com/sexibytes/sexigraf/tree/0.99d) (2017-07-13)
[Full Changelog](https://github.com/sexibytes/sexigraf/compare/0.99c...0.99d)

**Implemented enhancements:**

- Auto purge oldest wsp files and empty folders [\#112](https://github.com/sexibytes/sexigraf/issues/112)
- Error on testing vCenter status while connection to VC6.5 [\#102](https://github.com/sexibytes/sexigraf/issues/102)
- add storage consumption per file type per cluster [\#91](https://github.com/sexibytes/sexigraf/issues/91)
- add provisioned vRAM metric [\#90](https://github.com/sexibytes/sexigraf/issues/90)
- Unicode normalization [\#89](https://github.com/sexibytes/sexigraf/issues/89)
- increase logging [\#88](https://github.com/sexibytes/sexigraf/issues/88)
- add cluster vcpu/pcpu ratio metric [\#86](https://github.com/sexibytes/sexigraf/issues/86)
- Add link to filtered dashboard [\#81](https://github.com/sexibytes/sexigraf/issues/81)
- add datastore selection in capacity planning dashboards [\#80](https://github.com/sexibytes/sexigraf/issues/80)
- Add vSphere "ready" metric per vm [\#79](https://github.com/sexibytes/sexigraf/issues/79)
- Add https connection test before auth test against vCenter [\#73](https://github.com/sexibytes/sexigraf/issues/73)
- add auto archive/delete whisper files [\#69](https://github.com/sexibytes/sexigraf/issues/69)

**Fixed bugs:**

- /var/spool/exim4 filling up [\#107](https://github.com/sexibytes/sexigraf/issues/107)
- Error on testing vCenter status while connection to VC6.5 [\#102](https://github.com/sexibytes/sexigraf/issues/102)
- Typo in $graphite-\>send\(\) [\#82](https://github.com/sexibytes/sexigraf/issues/82)
- WARN Use of uninitialized value in multiplication \(\*\) at /root/ViPullStatistics.pl line 247 [\#78](https://github.com/sexibytes/sexigraf/issues/78)
- Syntax Error when using SexiGraf code on CentOS [\#77](https://github.com/sexibytes/sexigraf/issues/77)
- Use of uninitialized value $count in numeric lt \(\<\) at /root/ViPullStatistics.pl line 129 [\#76](https://github.com/sexibytes/sexigraf/issues/76)

**Closed issues:**

- Datacenter names with ÅÄÖ will cause problems [\#114](https://github.com/sexibytes/sexigraf/issues/114)
- VSAN Disk Utilization dashboard [\#113](https://github.com/sexibytes/sexigraf/issues/113)
- Document what the different graphs mean [\#108](https://github.com/sexibytes/sexigraf/issues/108)
- Only 1 host being discovered [\#104](https://github.com/sexibytes/sexigraf/issues/104)
- doesn't match vsan resyrn value. [\#101](https://github.com/sexibytes/sexigraf/issues/101)
- How to switch to HTTPS [\#99](https://github.com/sexibytes/sexigraf/issues/99)
- Issue with parenthesis in clusternames? [\#98](https://github.com/sexibytes/sexigraf/issues/98)
- Issues Getting ESXi Stats [\#97](https://github.com/sexibytes/sexigraf/issues/97)
- No vsan statistics for disk usage / capacity [\#96](https://github.com/sexibytes/sexigraf/issues/96)
- VSAN Congestion inconsistent between Multi VSAN Monitor & VSAN Monitor [\#95](https://github.com/sexibytes/sexigraf/issues/95)
- enable Grafana "starred" dashboards [\#94](https://github.com/sexibytes/sexigraf/issues/94)
- How do you extend disk for the sexigraf appliance? [\#93](https://github.com/sexibytes/sexigraf/issues/93)
- add top N lowest cpu/ram usage dashboard [\#92](https://github.com/sexibytes/sexigraf/issues/92)
- error after updating from 0.99a to 0.99c [\#87](https://github.com/sexibytes/sexigraf/issues/87)
- No ESX metrics [\#85](https://github.com/sexibytes/sexigraf/issues/85)
- Add LVM [\#84](https://github.com/sexibytes/sexigraf/issues/84)
- Error after adding vCenter to the list of credentials and attempting to view data. [\#83](https://github.com/sexibytes/sexigraf/issues/83)
- VI Offline Inventory not being populated and all datastore related graphs are empty with "Timeseries data request error". [\#70](https://github.com/sexibytes/sexigraf/issues/70)
- Rounding in FlambX [\#38](https://github.com/sexibytes/sexigraf/issues/38)

**Merged pull requests:**

- Update to 0.99d [\#116](https://github.com/sexibytes/sexigraf/pull/116) ([vmdude](https://github.com/vmdude))
- Import last DEV environment before master merge [\#111](https://github.com/sexibytes/sexigraf/pull/111) ([vmdude](https://github.com/vmdude))

## [0.99c](https://github.com/sexibytes/sexigraf/tree/0.99c) (2016-05-18)
[Full Changelog](https://github.com/sexibytes/sexigraf/compare/0.99b1...0.99c)

**Implemented enhancements:**

- Add support for OVF properties [\#74](https://github.com/sexibytes/sexigraf/issues/74)
- Add support for VSAN 6.2 SDK [\#68](https://github.com/sexibytes/sexigraf/issues/68)
- Support for more than 500KB update packages [\#66](https://github.com/sexibytes/sexigraf/issues/66)
- Use 80 percentile instead of mean formula in QuickQueryPerf  [\#63](https://github.com/sexibytes/sexigraf/issues/63)
- Display from\>to version on upgrade page [\#56](https://github.com/sexibytes/sexigraf/issues/56)

**Fixed bugs:**

- VMware VSAN NAA Latency dashboard for T10 devices ? [\#65](https://github.com/sexibytes/sexigraf/issues/65)
- WARN Use of uninitialized value $vsan\_cache\_ssd\_clean\_naa\[1\] in string at /root/VsanPullStatistics.pl line 288 [\#61](https://github.com/sexibytes/sexigraf/issues/61)

**Closed issues:**

- Add support for Windows [\#72](https://github.com/sexibytes/sexigraf/issues/72)
- Add support for FreeNAS [\#71](https://github.com/sexibytes/sexigraf/issues/71)
- add new VSAN All Flash Monitor dashboard [\#64](https://github.com/sexibytes/sexigraf/issues/64)
- Aggregated Datastore IOPS No datapoints [\#60](https://github.com/sexibytes/sexigraf/issues/60)
- FlambX dashboard issue with number of ESXi hosts [\#59](https://github.com/sexibytes/sexigraf/issues/59)
- add new dashboard to monitor multiple VSAN cluster [\#58](https://github.com/sexibytes/sexigraf/issues/58)
- ViPullStatistics very slow on HostSystem.runtime [\#52](https://github.com/sexibytes/sexigraf/issues/52)

**Merged pull requests:**

- Merging 0.99c [\#75](https://github.com/sexibytes/sexigraf/pull/75) ([rschitz](https://github.com/rschitz))

## [0.99b1](https://github.com/sexibytes/sexigraf/tree/0.99b1) (2016-03-10)
[Full Changelog](https://github.com/sexibytes/sexigraf/compare/0.99a...0.99b1)

**Implemented enhancements:**

- Enhance the SSD stats dashboard [\#49](https://github.com/sexibytes/sexigraf/issues/49)
- remove cluster configurationEx dependency for performace impact [\#48](https://github.com/sexibytes/sexigraf/issues/48)
- Handle VirtualSAN Witness ESXi [\#47](https://github.com/sexibytes/sexigraf/issues/47)
- Handle multiple puller on the same vcenter [\#43](https://github.com/sexibytes/sexigraf/issues/43)
- VMware Multi ESX QuickStats [\#39](https://github.com/sexibytes/sexigraf/issues/39)
- add icon next to "Upload Package" button [\#36](https://github.com/sexibytes/sexigraf/issues/36)
- VSAN capacity diskgroup templating [\#29](https://github.com/sexibytes/sexigraf/issues/29)

**Fixed bugs:**

- Issue fetching VSAN stats after upgrade to 0.99b [\#53](https://github.com/sexibytes/sexigraf/issues/53)
- Handle VirtualSAN Witness ESXi [\#47](https://github.com/sexibytes/sexigraf/issues/47)
- localhost hostname makes the script die [\#41](https://github.com/sexibytes/sexigraf/issues/41)

**Closed issues:**

- Add VM quickstats dashboard [\#46](https://github.com/sexibytes/sexigraf/issues/46)
- Add Resync/Rebuild/Rebalance dashboard for VSAN [\#45](https://github.com/sexibytes/sexigraf/issues/45)
- Add NAA latencies dashboard for VSAN [\#44](https://github.com/sexibytes/sexigraf/issues/44)

**Merged pull requests:**

- Upgrade to 0.99b "Xen" [\#51](https://github.com/sexibytes/sexigraf/pull/51) ([vmdude](https://github.com/vmdude))

## [0.99a](https://github.com/sexibytes/sexigraf/tree/0.99a) (2015-11-20)
**Implemented enhancements:**

- list old "orphaned" files in Stats Remover [\#28](https://github.com/sexibytes/sexigraf/issues/28)
- Add logs to VI and VSAN pull scripts [\#22](https://github.com/sexibytes/sexigraf/issues/22)
- add apache2 and carbon-cache services in the restart cycle of the SexiMenu [\#20](https://github.com/sexibytes/sexigraf/issues/20)
- add apache2 service state in seximenu [\#19](https://github.com/sexibytes/sexigraf/issues/19)
- Add MAC addresses on static inventory [\#13](https://github.com/sexibytes/sexigraf/issues/13)
- Re-inventory after vcenter entry removal [\#11](https://github.com/sexibytes/sexigraf/issues/11)
- Add 'Refresh' option for offline inventory [\#10](https://github.com/sexibytes/sexigraf/issues/10)
- New to add some 'Test' action on credential store [\#8](https://github.com/sexibytes/sexigraf/issues/8)

**Fixed bugs:**

- Issues during statistics pull [\#34](https://github.com/sexibytes/sexigraf/issues/34)
- Wrong logrotate file definition make log file unreadable by Log Viewer [\#33](https://github.com/sexibytes/sexigraf/issues/33)
- Can't see vm.left above 7j in Cluster Capacity Planning dashboard [\#25](https://github.com/sexibytes/sexigraf/issues/25)
- Incorrect path in service restart function [\#23](https://github.com/sexibytes/sexigraf/issues/23)
- ignore .gitignore file in Package Updater [\#15](https://github.com/sexibytes/sexigraf/issues/15)

**Closed issues:**

- Cluster Hosts basic stats dashboard [\#32](https://github.com/sexibytes/sexigraf/issues/32)
- Top 5 vmdk dashboard for VSAN [\#31](https://github.com/sexibytes/sexigraf/issues/31)
- change grafana.ini to enable dashboard saving [\#27](https://github.com/sexibytes/sexigraf/issues/27)
- /var/log/syslog tail GUI [\#17](https://github.com/sexibytes/sexigraf/issues/17)
- missing "refresh inventory" in Web Toolbox menu [\#16](https://github.com/sexibytes/sexigraf/issues/16)
- shrink sexigraf ASCII logo in seximenu [\#12](https://github.com/sexibytes/sexigraf/issues/12)
- carbon-cache status missing in seximenu [\#7](https://github.com/sexibytes/sexigraf/issues/7)
- need "dismissed" button on SexiGraf Package Update Runner log page [\#6](https://github.com/sexibytes/sexigraf/issues/6)
- crontab files not used after vi/vsan enabling [\#5](https://github.com/sexibytes/sexigraf/issues/5)
- strict search in VI Offline Inventory [\#4](https://github.com/sexibytes/sexigraf/issues/4)
- ViOfflineInventory run after vcentry addition ? [\#3](https://github.com/sexibytes/sexigraf/issues/3)
- cron files not removed after delete-vcentry [\#2](https://github.com/sexibytes/sexigraf/issues/2)
- web-admin.json wrong path [\#1](https://github.com/sexibytes/sexigraf/issues/1)



\* *This Change Log was automatically generated by [github_changelog_generator](https://github.com/skywinder/Github-Changelog-Generator)*