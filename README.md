[![SexiBanner](http://www.sexigraf.fr/wp-content/uploads/2017/07/SexiGrafBanner.png)](http://www.sexigraf.fr)

SexiGraf is a fully open-source vSphere centric Graphite VMware appliance with a Grafana frontend. It pulls VI and vSAN metrics from VMware vCenter APIs, push them to Graphite and let Grafana produces the gorgeous dashboards we love so much!

*Full changelog is available here: [CHANGELOG.md](CHANGELOG.md)*

*Official website for this awesome appliance is available at http://www.sexigraf.fr*

## VMware vSAN

The metrics used in the various VSAN dashboards are now collected every 5 minutes using to the `VsanPerfQueryPerf` API method of `VsanPerformanceManager` from the famous `vSAN performance service`. With some educated guesses, it is possible to access almost any metrics from the vSAN cluster. And guess what! We’re already working on more cool SexiPanels for vSAN: http://www.sexigraf.fr/vsan-sexipanels/

## VMware vSphere

Fast. Very fast. That’s what we had in mind when we designed SexiGraf. When you need vSphere metrics, the obvious way is the `PerformanceManager`, but we need something faster so we choosed managed object properties and quickstats like `ResourcePoolQuickStats`. If we have no other choice, we failback to the `PerformanceManager` but we only query the last 15 samples of the `RealTime samplingPeriod` since we pull vSphere metrics every 5 minutes. http://www.sexigraf.fr/vsphere-sexipanels/  

## FreeNAS

Starting from version 9.10, FreeNAS allows users to set a “Remote Graphite Server” target to send all the metrics harvested by Collectd. Guess what would make a nice Graphite target! http://www.sexigraf.fr/freenas-sexipanel/

## Windows

Leveraging the built-in Graphite listener of SexiGraf, we introduced Windows support in version 0.99c with basic cpu-ram-hdd metrics : http://www.sexigraf.fr/windows-sexipanel/

## pfSense

Because we love and use pfSense very much since the m0n0wall fork, we decided to make a great dashboard with system metrics, interface statistics but most importantly the pfinfo data which let you monitor the packet filtering service of the firewall.

## S.M.A.R.T.

Since the first release we wanted to add a SMART counters dashboard because we were so inspired by the Backblaze reports. But we never found a proper way to get those stats from any kind of NAS so we decided to rely on a custom script that pushes the data to graphite using netcat 😉

## License

This project is licensed under the MIT License - see the [LICENSE.md](LICENSE.md) file for details
