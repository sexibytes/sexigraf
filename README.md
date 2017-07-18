# SexiGraf

[![Join the chat at https://gitter.im/sexibytes/sexigraf](https://badges.gitter.im/sexibytes/sexigraf.svg)](https://gitter.im/sexibytes/sexigraf?utm_source=badge&utm_medium=badge&utm_campaign=pr-badge&utm_content=badge)

SexiGraf is a vSphere centric Graphite appliance with a Grafana frontend.
SexiGraf is a fully open-source vSphere centric Graphite VMware appliance with a Grafana frontend. It pulls VI and VSAN metrics from VMware vCenter APIs, push them to Graphite and let Grafana produces the gorgeous dashboards we love so much!

*Official website for this awesome appliance is available at http://www.sexigraf.fr*

## VMware VSAN

The metrics used in the various VSAN dashboards are collected every minutes using to the `QueryVsanStatistics` API method of `HostVsanInternalSystem`. With some json ticks, it is possible to access any metrics from the VSAN cluster. And guess what! We’re already working on other cool SexiPanels for VSAN: http://www.sexigraf.fr/vsan-sexipanels/

## VMware vSphere

Fast. Very fast. That’s what we had in mind when we designed SexiGraf. When you need vSphere metrics, the obvious way is the PerformanceManager, but we need something faster so we choosed managed object properties and quickstats like ResourcePoolQuickStats. If we have no other choice, we failback to the PerformanceManager but we only query the last 15 samples of the RealTime samplingPeriod since we pull vSphere metrics every 5 minutes. http://www.sexigraf.fr/vsphere-sexipanels/  

## VMware VSAN
## VMware VSAN
## VMware VSAN
## VMware VSAN
