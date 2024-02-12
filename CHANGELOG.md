# Changelog

## [0.99j](https://github.com/sexibytes/sexigraf/tree/0.99j) (2024-02-12)

[Full Changelog](https://github.com/sexibytes/sexigraf/compare/0.99i...0.99j)

**Implemented enhancements:**

- Fix log files exclusive lock [\#358](https://github.com/sexibytes/sexigraf/issues/358)
- Adding VMNIC CRC error check [\#344](https://github.com/sexibytes/sexigraf/issues/344)
- vCenter: privileg check failed for user \(missing permission Sessions.TerminateSession [\#341](https://github.com/sexibytes/sexigraf/issues/341)
- Mimic com.vmware.vc.vm.DstVmMigratedEvent behaviour in vROps for VMs and ESXs [\#325](https://github.com/sexibytes/sexigraf/issues/325)
- Add inventory history [\#275](https://github.com/sexibytes/sexigraf/issues/275)
- add scsi path state count per esx [\#258](https://github.com/sexibytes/sexigraf/issues/258)
- Rename or Move ESXI - Automatically integrated  [\#243](https://github.com/sexibytes/sexigraf/issues/243)
- Veeam Backup Integration [\#147](https://github.com/sexibytes/sexigraf/issues/147)

**Fixed bugs:**

- \[EROR\] Cluster xxx root resource pool not found ?! \[EROR\] Cannot index into a null array. [\#357](https://github.com/sexibytes/sexigraf/issues/357)
- datastoreVMObservedLatency empty \(NFS?\) [\#354](https://github.com/sexibytes/sexigraf/issues/354)
- No more storage metrics when some cluster members are not responding [\#347](https://github.com/sexibytes/sexigraf/issues/347)
- Issues in VMware vSAN Disk Latency and VMware vSAN Disk Utilization dashboards [\#343](https://github.com/sexibytes/sexigraf/issues/343)
- Cluster multi ESX LiteStats -null  [\#342](https://github.com/sexibytes/sexigraf/issues/342)

**Closed issues:**

- Sexigraf "Victory Mine" impacted by Grafana CVE-2023-4822 ? [\#371](https://github.com/sexibytes/sexigraf/issues/371)
- Add VMware asset version evolution dashboard [\#365](https://github.com/sexibytes/sexigraf/issues/365)
- Where do you get the data to display com\_vmware\_vc\_authorization\_nopermission? [\#363](https://github.com/sexibytes/sexigraf/issues/363)
- Error add vcenter [\#362](https://github.com/sexibytes/sexigraf/issues/362)
- VMware Multi Datastore Usage missing [\#355](https://github.com/sexibytes/sexigraf/issues/355)
- Export Dashboard data to CSV or Excel using Grafana or poweshell [\#352](https://github.com/sexibytes/sexigraf/issues/352)
- adding extra retention the first 4 days 30m:96h [\#351](https://github.com/sexibytes/sexigraf/issues/351)
- vm iops limit affects datastoreVMObservedLatency [\#350](https://github.com/sexibytes/sexigraf/issues/350)
- CPU ready in Sexigraf for vmware vm does not match the data in Vcenter [\#348](https://github.com/sexibytes/sexigraf/issues/348)
- Â¿Remove old cluster? [\#346](https://github.com/sexibytes/sexigraf/issues/346)
- no data [\#345](https://github.com/sexibytes/sexigraf/issues/345)
- Latest ova for downloading are unavailible  [\#340](https://github.com/sexibytes/sexigraf/issues/340)
- Problem with export  [\#339](https://github.com/sexibytes/sexigraf/issues/339)
- Appliance network settings [\#338](https://github.com/sexibytes/sexigraf/issues/338)
- Protect against 0 vm and/or 0 host in the inventory [\#337](https://github.com/sexibytes/sexigraf/issues/337)
- Unable to collect performance [\#336](https://github.com/sexibytes/sexigraf/issues/336)
- Datastores used space metric [\#334](https://github.com/sexibytes/sexigraf/issues/334)
- OVA Download Link not working [\#333](https://github.com/sexibytes/sexigraf/issues/333)
- VsanPerfQueryPerf issue [\#332](https://github.com/sexibytes/sexigraf/issues/332)
- Can't download OVA [\#331](https://github.com/sexibytes/sexigraf/issues/331)
- After update - Variable "ErrorActionPreference" or common parameter is set to Stop [\#329](https://github.com/sexibytes/sexigraf/issues/329)
- How to change timezone JST? [\#310](https://github.com/sexibytes/sexigraf/issues/310)
- ESX LiteStats - Detail? [\#307](https://github.com/sexibytes/sexigraf/issues/307)
- sexigraf 0.99h : vulnerability moderate on Grafana software \(CVE-2022-24812 Grafana Enterprise fine-grained access control API Key privilege escalation : https://github.com/grafana/grafana/security/advisories/GHSA-82gq-xfg3-5j7v\), need to update it [\#305](https://github.com/sexibytes/sexigraf/issues/305)
- VMware All Cluster VM Stats: Add Graph of IOPS and Blocksize [\#284](https://github.com/sexibytes/sexigraf/issues/284)

**Merged pull requests:**

- Merge before release 0.99j - St. Olga [\#377](https://github.com/sexibytes/sexigraf/pull/377) ([rschitz](https://github.com/rschitz))
- Update CHANGELOG.md [\#324](https://github.com/sexibytes/sexigraf/pull/324) ([rschitz](https://github.com/rschitz))

## [0.99i](https://github.com/sexibytes/sexigraf/tree/0.99i) (2023-01-09)

[Full Changelog](https://github.com/sexibytes/sexigraf/compare/0.99h...0.99i)

**Implemented enhancements:**

- Force Https [\#309](https://github.com/sexibytes/sexigraf/issues/309)
- Feature request - Scale storage on Capacity planning [\#304](https://github.com/sexibytes/sexigraf/issues/304)
- get rid of += in ps1 scripts [\#299](https://github.com/sexibytes/sexigraf/issues/299)
- Enhance PullGuestInfo [\#278](https://github.com/sexibytes/sexigraf/issues/278)
- add ntp servers option during ova deploy [\#211](https://github.com/sexibytes/sexigraf/issues/211)

**Fixed bugs:**

- fix empty network vm metrics [\#314](https://github.com/sexibytes/sexigraf/issues/314)
- near 0 values not written [\#311](https://github.com/sexibytes/sexigraf/issues/311)

**Closed issues:**

- force legacy dashboard alerting [\#320](https://github.com/sexibytes/sexigraf/issues/320)
- add grafana annotation limits [\#319](https://github.com/sexibytes/sexigraf/issues/319)
- add Datastores info inventory [\#318](https://github.com/sexibytes/sexigraf/issues/318)
- add ServiceTag in ESX inventory [\#317](https://github.com/sexibytes/sexigraf/issues/317)
- Add ability to load interface in HomeAssistant as iFrame [\#316](https://github.com/sexibytes/sexigraf/issues/316)
- Is Alerting possible for other dashboards too like vcenter bad events [\#315](https://github.com/sexibytes/sexigraf/issues/315)
- add full vSAN ESA support [\#312](https://github.com/sexibytes/sexigraf/issues/312)
- CPU and RAM Utilization above 100% [\#308](https://github.com/sexibytes/sexigraf/issues/308)
- Add IOPS per VM data [\#303](https://github.com/sexibytes/sexigraf/issues/303)
- VM per host count \(HA risk monitoring\) [\#302](https://github.com/sexibytes/sexigraf/issues/302)
- Direct link rendered image not working [\#301](https://github.com/sexibytes/sexigraf/issues/301)
- multiple ip in vm not listed in inventory [\#300](https://github.com/sexibytes/sexigraf/issues/300)
- Increase performance of Send-BulkGraphiteMetrics [\#298](https://github.com/sexibytes/sexigraf/issues/298)
- No data but show machines inventory [\#296](https://github.com/sexibytes/sexigraf/issues/296)
- add a way to identify vm restart by ha [\#295](https://github.com/sexibytes/sexigraf/issues/295)
- sexigraf 0.99g : OS vulnerabilities detected in banner reporting \(PCI-DSS check\) / severity high / CVSS v2 7.5 [\#294](https://github.com/sexibytes/sexigraf/issues/294)
- pre-install MIBs for collectd agent [\#293](https://github.com/sexibytes/sexigraf/issues/293)
- SHA1 checksum incorrect? [\#292](https://github.com/sexibytes/sexigraf/issues/292)
- fix cpu count in All Version dashboard [\#291](https://github.com/sexibytes/sexigraf/issues/291)
- "QueryPerf" with "1" argument\(s\): "A specified parameter was not correct: querySpec.interval"" [\#290](https://github.com/sexibytes/sexigraf/issues/290)
- Sexigraf Powershell version:  "Exception calling "QueryPerf" with "1" argument\(s\): "XML document element count exceeds configured maximum 500000" [\#287](https://github.com/sexibytes/sexigraf/issues/287)
-  VMware Multi Datastore Usage: monitor unused vmdks [\#283](https://github.com/sexibytes/sexigraf/issues/283)
- Add DRS score dashboard [\#228](https://github.com/sexibytes/sexigraf/issues/228)

**Merged pull requests:**

- Merge before release 0.99i - Victory Mine  [\#323](https://github.com/sexibytes/sexigraf/pull/323) ([rschitz](https://github.com/rschitz))

## [0.99h](https://github.com/sexibytes/sexigraf/tree/0.99h) (2022-03-28)

[Full Changelog](https://github.com/sexibytes/sexigraf/compare/0.99g...0.99h)

**Implemented enhancements:**

- unify datastore iops and latency measure [\#272](https://github.com/sexibytes/sexigraf/issues/272)
- Implementation of a certificate [\#270](https://github.com/sexibytes/sexigraf/issues/270)
- inventory export in csv from commandline [\#269](https://github.com/sexibytes/sexigraf/issues/269)
- add non connected vm status count to VM graph in cluster dashboards [\#268](https://github.com/sexibytes/sexigraf/issues/268)
- Derivative to nonNegativeDerivative in vSAN dashboards [\#265](https://github.com/sexibytes/sexigraf/issues/265)
- Switch from VsanInternalSystem to VsanPerfQueryPerf [\#264](https://github.com/sexibytes/sexigraf/issues/264)
- add vSAN memory metrics [\#263](https://github.com/sexibytes/sexigraf/issues/263)
- add vSphere Replication events  [\#259](https://github.com/sexibytes/sexigraf/issues/259)
- Add 7.0 U2 sdk [\#255](https://github.com/sexibytes/sexigraf/issues/255)
- Perl-SDK to PowerCLI migration [\#254](https://github.com/sexibytes/sexigraf/issues/254)
- add vSAN tcpip metrics [\#250](https://github.com/sexibytes/sexigraf/issues/250)
- add stunned process killer [\#249](https://github.com/sexibytes/sexigraf/issues/249)
- add EfficientCapacity metrics [\#248](https://github.com/sexibytes/sexigraf/issues/248)
- add VsanObjectIdentityAndHealth to resync dashboard [\#247](https://github.com/sexibytes/sexigraf/issues/247)
- increase inodes on sdb1 [\#238](https://github.com/sexibytes/sexigraf/issues/238)
- add allocated to all ram utilization dashboards [\#229](https://github.com/sexibytes/sexigraf/issues/229)
- Reduce whisper aggregation aggressivity during the first 48h to enhance troubleshooting capability [\#217](https://github.com/sexibytes/sexigraf/issues/217)
- improve purge script [\#215](https://github.com/sexibytes/sexigraf/issues/215)
- split ViPullStatistics.log and VsanDisksPullStatistics.log per server for troubleshooting purpose [\#212](https://github.com/sexibytes/sexigraf/issues/212)
- enhance vmotions count [\#203](https://github.com/sexibytes/sexigraf/issues/203)
- Kindly Add Virtual Disk matrics [\#180](https://github.com/sexibytes/sexigraf/issues/180)
- Frequently \(every 1 minute\) VsanPullStatistics from \<vcenter\> is already running! at /root/VsanPullStatistics.pl line 76 [\#174](https://github.com/sexibytes/sexigraf/issues/174)
- VMware Multi Cluster Usage Dashboard \(missing resource\) [\#162](https://github.com/sexibytes/sexigraf/issues/162)
- create a VMware\_Multi\_VSAN\_Monitor\_66 dashboard [\#154](https://github.com/sexibytes/sexigraf/issues/154)
- Empty vSAN latency/iops metrics in cluster fullstats dashboards [\#143](https://github.com/sexibytes/sexigraf/issues/143)
- Create some CHANGELOG file [\#55](https://github.com/sexibytes/sexigraf/issues/55)

**Fixed bugs:**

- disable ScriptBlockLogging to avoid flooding /var/log/syslog [\#261](https://github.com/sexibytes/sexigraf/issues/261)
- getinventory error  [\#253](https://github.com/sexibytes/sexigraf/issues/253)
- VMs in resource pools are not processed [\#252](https://github.com/sexibytes/sexigraf/issues/252)
- VSAN Top vmdk [\#251](https://github.com/sexibytes/sexigraf/issues/251)
- ImportError: No module named 'graphite' in /etc/cron.hourly/graphite-build-index [\#242](https://github.com/sexibytes/sexigraf/issues/242)
- Vmware ESXi 6.0/6.5 import ova error [\#241](https://github.com/sexibytes/sexigraf/issues/241)
- standalone managed hosts only get multipleHostAccess datastores [\#237](https://github.com/sexibytes/sexigraf/issues/237)
- Export feature failed if data bigger than 4gb [\#233](https://github.com/sexibytes/sexigraf/issues/233)
- VMware\_Multi\_Cluster\_Top\_N\_VM\_Stats no Datapoint for disk usage [\#182](https://github.com/sexibytes/sexigraf/issues/182)

**Closed issues:**

- Maximum vCenter amount [\#288](https://github.com/sexibytes/sexigraf/issues/288)
- SexiGraf VI Offline Inventory panel does not refresh [\#286](https://github.com/sexibytes/sexigraf/issues/286)
- Can't connect to xxxxx.xxxxxx.xxx:443 \(Name or service not known\) [\#285](https://github.com/sexibytes/sexigraf/issues/285)
- Add "datastore - vm" association to "VMware Multi Cluster Top N VM Latency" [\#282](https://github.com/sexibytes/sexigraf/issues/282)
- configure e-mail server for grafana alerts via SexiGraf Web Admin [\#281](https://github.com/sexibytes/sexigraf/issues/281)
- Description for "VMware All Cluster Capacity Planning" [\#280](https://github.com/sexibytes/sexigraf/issues/280)
- Replace FlambX by BroStats dashboard [\#277](https://github.com/sexibytes/sexigraf/issues/277)
- Make export/import possible via vmdk swap [\#276](https://github.com/sexibytes/sexigraf/issues/276)
- How to change interval of collecting date ?  [\#271](https://github.com/sexibytes/sexigraf/issues/271)
- Sexigraf Ports [\#267](https://github.com/sexibytes/sexigraf/issues/267)
- Is there an easy way to change credentials for vcenters in credential store [\#266](https://github.com/sexibytes/sexigraf/issues/266)
- Error downloading older SUP-files [\#262](https://github.com/sexibytes/sexigraf/issues/262)
- Removing cluster in vcentre, loses historical data in sexigrafs [\#260](https://github.com/sexibytes/sexigraf/issues/260)
- Similar to \#204 - Limiting web admin access to view only users [\#256](https://github.com/sexibytes/sexigraf/issues/256)
- Increase storage retention storage-schema.conf [\#246](https://github.com/sexibytes/sexigraf/issues/246)
- components version dashboard [\#244](https://github.com/sexibytes/sexigraf/issues/244)
- ova import error [\#240](https://github.com/sexibytes/sexigraf/issues/240)
- configure SexiGraph [\#236](https://github.com/sexibytes/sexigraf/issues/236)
- Number of hosts - no history [\#234](https://github.com/sexibytes/sexigraf/issues/234)
- add vsan smart metric [\#221](https://github.com/sexibytes/sexigraf/issues/221)

**Merged pull requests:**

- Merge before release 0.99h - Highway 17 [\#289](https://github.com/sexibytes/sexigraf/pull/289) ([vmdude](https://github.com/vmdude))

## [0.99g](https://github.com/sexibytes/sexigraf/tree/0.99g) (2020-11-16)

[Full Changelog](https://github.com/sexibytes/sexigraf/compare/0.99f...0.99g)

**Implemented enhancements:**

- redesign vmware-multi-cluster-usage dashboard [\#222](https://github.com/sexibytes/sexigraf/issues/222)
- disable grafana 'includeAll' on $vcenter variable for big dashboard [\#216](https://github.com/sexibytes/sexigraf/issues/216)
- replace IORM by IOPS to clarify datastore performance dashboards [\#207](https://github.com/sexibytes/sexigraf/issues/207)
- limit All and Top N dashboards to first vcenter on load to avoid IO storm [\#206](https://github.com/sexibytes/sexigraf/issues/206)
- Remove access for Web admin dashboard for non admin roles [\#204](https://github.com/sexibytes/sexigraf/issues/204)
- add pfsense support [\#202](https://github.com/sexibytes/sexigraf/issues/202)
- group graphite calls [\#199](https://github.com/sexibytes/sexigraf/issues/199)
- add consumed Overhead Memory to quickstats dashboards [\#196](https://github.com/sexibytes/sexigraf/issues/196)
- exportSexiGrafBundle.sh sizing issue [\#186](https://github.com/sexibytes/sexigraf/issues/186)
- add vdmk per datastore metric [\#185](https://github.com/sexibytes/sexigraf/issues/185)
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

- Datacenter names with Ã…Ã„Ã– will cause problems [\#114](https://github.com/sexibytes/sexigraf/issues/114)
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
