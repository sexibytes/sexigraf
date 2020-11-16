# Changelog

## [0.99g](https://github.com/sexibytes/sexigraf/tree/0.99g) (2020-11-16)

[Full Changelog](https://github.com/sexibytes/sexigraf/compare/0.99f...0.99g)

**Implemented enhancements:**

- redesign vmware-multi-cluster-usage dashboard [\#222](https://github.com/sexibytes/sexigraf/issues/222)
- disable grafana 'includeAll' on $vcenter variable for big dashboard [\#216](https://github.com/sexibytes/sexigraf/issues/216)
- replace IORM by IOPS to clarify datastore performance dashboards [\#207](https://github.com/sexibytes/sexigraf/issues/207)
- limit All and Top N dashboards to first vcenter on load to avoid IO storm [\#206](https://github.com/sexibytes/sexigraf/issues/206)
- Remove access for Web admin dashboard for non admin roles [\#204](https://github.com/sexibytes/sexigraf/issues/204)
- enhance vmotions count [\#203](https://github.com/sexibytes/sexigraf/issues/203)
- add pfsense support [\#202](https://github.com/sexibytes/sexigraf/issues/202)
- group graphite calls [\#199](https://github.com/sexibytes/sexigraf/issues/199)
- add consumed Overhead Memory to quickstats dashboards [\#196](https://github.com/sexibytes/sexigraf/issues/196)
- exportSexiGrafBundle.sh sizing issue [\#186](https://github.com/sexibytes/sexigraf/issues/186)
- add vdmk per datastore metric [\#185](https://github.com/sexibytes/sexigraf/issues/185)
- Kindly Add Virtual Disk matrics [\#180](https://github.com/sexibytes/sexigraf/issues/180)
- switch unit from short to none in Right Y [\#161](https://github.com/sexibytes/sexigraf/issues/161)
- add datastore \# in shared datastores utilization graphs on clusters dashboards [\#158](https://github.com/sexibytes/sexigraf/issues/158)
- add 1 decimal instead of auto for % in dashboards [\#153](https://github.com/sexibytes/sexigraf/issues/153)
- Cluster of ESXi hosts not showing up [\#149](https://github.com/sexibytes/sexigraf/issues/149)
- regenerate ssh keys at first start up [\#139](https://github.com/sexibytes/sexigraf/issues/139)
- Add web admin tile for dashboard management [\#109](https://github.com/sexibytes/sexigraf/issues/109)
- \[Request\] Containerizing [\#106](https://github.com/sexibytes/sexigraf/issues/106)
- Add an admin tool to generate support bundle for troubleshooting [\#54](https://github.com/sexibytes/sexigraf/issues/54)
- Offline Inventory : Resource Pool name & vm folder path [\#42](https://github.com/sexibytes/sexigraf/issues/42)
- add refresh button in House Cleaner page [\#35](https://github.com/sexibytes/sexigraf/issues/35)
- support for unmanaged ESX [\#18](https://github.com/sexibytes/sexigraf/issues/18)

**Fixed bugs:**

- fix esx hardware sensor for standalone hosts [\#230](https://github.com/sexibytes/sexigraf/issues/230)
- fix apache empty scoreboard [\#226](https://github.com/sexibytes/sexigraf/issues/226)
- Avoid "Unsaved changes" when user select another variable than default \(i.e. cluster selection\) and move to another dashboard [\#223](https://github.com/sexibytes/sexigraf/issues/223)
- stack vmotion/svmotion metrics in vmotion dashboard [\#220](https://github.com/sexibytes/sexigraf/issues/220)
- update offline vminventory vm links [\#198](https://github.com/sexibytes/sexigraf/issues/198)
- Time sync for appliance [\#173](https://github.com/sexibytes/sexigraf/issues/173)
- DIE Can't call method "committed" on an undefined value at /root/getInventory.pl line 117. [\#137](https://github.com/sexibytes/sexigraf/issues/137)

**Closed issues:**

- HTTPS-SSL Configuration [\#219](https://github.com/sexibytes/sexigraf/issues/219)
- Debian 8 - EOL [\#218](https://github.com/sexibytes/sexigraf/issues/218)
- Disk expand  [\#214](https://github.com/sexibytes/sexigraf/issues/214)
- "No Data Points" Error [\#210](https://github.com/sexibytes/sexigraf/issues/210)
- add early SMART support dashboard for FreeNAS [\#209](https://github.com/sexibytes/sexigraf/issues/209)
- add ipmi data from telegraf agent [\#208](https://github.com/sexibytes/sexigraf/issues/208)
- add alerting dashboard template for vcenter bad events [\#205](https://github.com/sexibytes/sexigraf/issues/205)
- Add Netdata dashboard [\#200](https://github.com/sexibytes/sexigraf/issues/200)
- add All ESX VM stats dashboard [\#197](https://github.com/sexibytes/sexigraf/issues/197)
- Missing esxi hosts [\#195](https://github.com/sexibytes/sexigraf/issues/195)
- new dashboard "VMware All ESX VM Stats [\#194](https://github.com/sexibytes/sexigraf/issues/194)
- All graphs except Home & PullExec are showing empty datapoint [\#193](https://github.com/sexibytes/sexigraf/issues/193)
- Add wait-idle metric for VMs [\#192](https://github.com/sexibytes/sexigraf/issues/192)
- No datapoints in VMware vCenter Bad Events [\#189](https://github.com/sexibytes/sexigraf/issues/189)
- Collect strategic events to mimic SexiLog [\#178](https://github.com/sexibytes/sexigraf/issues/178)
- /var/log/carbon/listener.log.1 filling up [\#177](https://github.com/sexibytes/sexigraf/issues/177)
- add "purge old data" button with days parameter [\#164](https://github.com/sexibytes/sexigraf/issues/164)
- add support for datastore clusters [\#159](https://github.com/sexibytes/sexigraf/issues/159)
- Rename VSAN in vSAN in dashboards/tags [\#156](https://github.com/sexibytes/sexigraf/issues/156)
- Add SMART dashboard for NAS monitoring [\#148](https://github.com/sexibytes/sexigraf/issues/148)
- How to get disk health status? [\#105](https://github.com/sexibytes/sexigraf/issues/105)

**Merged pull requests:**

- Dev6 [\#232](https://github.com/sexibytes/sexigraf/pull/232) ([vmdude](https://github.com/vmdude))
- Dev [\#187](https://github.com/sexibytes/sexigraf/pull/187) ([vmdude](https://github.com/vmdude))
- Update addVsanCrontab.sh [\#128](https://github.com/sexibytes/sexigraf/pull/128) ([acederlund](https://github.com/acederlund))
- Update addViCrontab.sh [\#127](https://github.com/sexibytes/sexigraf/pull/127) ([acederlund](https://github.com/acederlund))

## [0.99f](https://github.com/sexibytes/sexigraf/tree/0.99f) (2019-05-12)

[Full Changelog](https://github.com/sexibytes/sexigraf/compare/0.99e...0.99f)

**Implemented enhancements:**

- speed up pulling process using hastables [\#168](https://github.com/sexibytes/sexigraf/issues/168)
- compute esx and datastore sum stats per cluster [\#167](https://github.com/sexibytes/sexigraf/issues/167)
- add iops for non iorm stats enabled datastore [\#157](https://github.com/sexibytes/sexigraf/issues/157)

**Fixed bugs:**

- bug in filetype and snashot measures  [\#169](https://github.com/sexibytes/sexigraf/issues/169)
- vCSA 6.7 Update 1 - DIE Can't call method "apiType" on an undefined value at /root/VsanPullStatistics.pl line 136. [\#165](https://github.com/sexibytes/sexigraf/issues/165)

**Closed issues:**

- Update VI pull stats frequence [\#184](https://github.com/sexibytes/sexigraf/issues/184)
- files.sexigraf.fr is down [\#183](https://github.com/sexibytes/sexigraf/issues/183)
- Issues with VSAN Capacity and API version 6.7.1 [\#181](https://github.com/sexibytes/sexigraf/issues/181)
- Alerts not working [\#175](https://github.com/sexibytes/sexigraf/issues/175)
- Offline Inventory: Add vm cpu usage, vm memory usage [\#172](https://github.com/sexibytes/sexigraf/issues/172)
- DIE Illegal division by zero at /root/ViPullStatistics.pl line 146. [\#171](https://github.com/sexibytes/sexigraf/issues/171)
- add cpu latency metric [\#166](https://github.com/sexibytes/sexigraf/issues/166)
- add vcenter events counter [\#163](https://github.com/sexibytes/sexigraf/issues/163)
- VsanPullStatistics.pl line 408 - DIE Illegal division by zero at /root/VsanPullStatistics.pl line 408 [\#160](https://github.com/sexibytes/sexigraf/issues/160)

## [0.99e](https://github.com/sexibytes/sexigraf/tree/0.99e) (2018-08-08)

[Full Changelog](https://github.com/sexibytes/sexigraf/compare/0.99d...0.99e)

**Implemented enhancements:**

- Rename standalone ESX dashboards to avoid misunderstanding [\#150](https://github.com/sexibytes/sexigraf/issues/150)
- Please make HTTPS/SSL as a default for the 0.99e version  [\#146](https://github.com/sexibytes/sexigraf/issues/146)
- Add host \# per cluster in every cluster related dashboard [\#145](https://github.com/sexibytes/sexigraf/issues/145)
- Change logrotate frequency to hourly [\#144](https://github.com/sexibytes/sexigraf/issues/144)
- Add Sync reasons in vSAN Resync dashboard [\#142](https://github.com/sexibytes/sexigraf/issues/142)
- add network packets dropped [\#141](https://github.com/sexibytes/sexigraf/issues/141)
- Change join separator in the offline inventory [\#136](https://github.com/sexibytes/sexigraf/issues/136)
- add disk.commandsAveraged.average for vms [\#135](https://github.com/sexibytes/sexigraf/issues/135)
- add net.usage.average for vms [\#134](https://github.com/sexibytes/sexigraf/issues/134)
- add disk.usage.average metric for vms [\#133](https://github.com/sexibytes/sexigraf/issues/133)
- transform mem distributed fairness metric to negative Y [\#124](https://github.com/sexibytes/sexigraf/issues/124)
- Display appliance version in SexiMenu [\#122](https://github.com/sexibytes/sexigraf/issues/122)
- remove cluster link for "N/A" cluster in offline inventory [\#119](https://github.com/sexibytes/sexigraf/issues/119)
- add mem.allocated to VMware Multi Cluster QuickStats dashboard [\#118](https://github.com/sexibytes/sexigraf/issues/118)
- Pull Exec Time does not show .vm metrics beyond 2d [\#115](https://github.com/sexibytes/sexigraf/issues/115)
- Add a backup/export feature [\#67](https://github.com/sexibytes/sexigraf/issues/67)
- Dashboard init failed Template variables could not be initialized: undefined [\#62](https://github.com/sexibytes/sexigraf/issues/62)

**Fixed bugs:**

- Wrong allocated memory value in cluster dashboards [\#152](https://github.com/sexibytes/sexigraf/issues/152)
- ViPullStatistics.pl - Illegal division by zero [\#132](https://github.com/sexibytes/sexigraf/issues/132)
- set decimals to auto in power usage gaph in All Cluster FullStats [\#123](https://github.com/sexibytes/sexigraf/issues/123)
- House Cleaner not expanding subfolders [\#120](https://github.com/sexibytes/sexigraf/issues/120)
- dashboard metrics definition  [\#26](https://github.com/sexibytes/sexigraf/issues/26)

**Closed issues:**

- add vmhba traffic counters [\#138](https://github.com/sexibytes/sexigraf/issues/138)
- Missing ESX Hosts [\#131](https://github.com/sexibytes/sexigraf/issues/131)
- fresh install: All vmware dashbords shows no data  [\#130](https://github.com/sexibytes/sexigraf/issues/130)
- Dashboard not working on a mix environment [\#129](https://github.com/sexibytes/sexigraf/issues/129)
- Slow fetch from vcsa [\#126](https://github.com/sexibytes/sexigraf/issues/126)
- create dashboard for vcenter sessionCount metric [\#121](https://github.com/sexibytes/sexigraf/issues/121)
- lower Y-Max from 180 to 150 on cpu/ram usage graph [\#117](https://github.com/sexibytes/sexigraf/issues/117)
- Time data request Error on graph [\#37](https://github.com/sexibytes/sexigraf/issues/37)

**Merged pull requests:**

- Update to 0.99e [\#155](https://github.com/sexibytes/sexigraf/pull/155) ([vmdude](https://github.com/vmdude))

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
- localhost hostname makes the script die [\#41](https://github.com/sexibytes/sexigraf/issues/41)

**Closed issues:**

- Add VM quickstats dashboard [\#46](https://github.com/sexibytes/sexigraf/issues/46)
- Add Resync/Rebuild/Rebalance dashboard for VSAN [\#45](https://github.com/sexibytes/sexigraf/issues/45)
- Add NAA latencies dashboard for VSAN [\#44](https://github.com/sexibytes/sexigraf/issues/44)

**Merged pull requests:**

- Upgrade to 0.99b "Xen" [\#51](https://github.com/sexibytes/sexigraf/pull/51) ([vmdude](https://github.com/vmdude))

## [0.99a](https://github.com/sexibytes/sexigraf/tree/0.99a) (2015-11-20)

[Full Changelog](https://github.com/sexibytes/sexigraf/compare/c8bd72d32dfb0f61e95ef12d2a05257345b1ab0d...0.99a)

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



\* *This Changelog was automatically generated by [github_changelog_generator](https://github.com/github-changelog-generator/github-changelog-generator)*
