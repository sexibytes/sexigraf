#!/usr/bin/perl -w
#

use strict;
use warnings;
use VMware::VIRuntime;
use JSON;
use Data::Dumper;
use Net::Graphite;

$Util::script_version = "0.9";

Opts::parse();
Opts::validate();

my $url = Opts::get_option('url');
my $vcenterserver = Opts::get_option('server');
my $username = Opts::get_option('username');
my $password = Opts::get_option('password');
my $sessionfile = Opts::get_option('sessionfile');

my $exec_start = time;

# set graphite target
my $graphite = Net::Graphite->new(
	# except for host, these hopefully have reasonable defaults, so are optional
	host                  => '127.0.0.1',
	port                  => 2003,
	trace                 => 0,                # if true, copy what's sent to STDERR
	proto                 => 'tcp',            # can be 'udp'
	timeout               => 1,                # timeout of socket connect in seconds
	fire_and_forget       => 1,                # if true, ignore sending errors
	return_connect_error  => 0,                # if true, forward connect error to caller
);

# handling sessionfile if missing or expired
if (defined($sessionfile) and -e $sessionfile) {
	eval { Vim::load_session(service_url => $url, session_file => $sessionfile); };
	if ($@) {
		Vim::login(service_url => $url, user_name => $username, password => $password);
	}
} else {
	Vim::login(service_url => $url, user_name => $username, password => $password);
}

if (defined($sessionfile)) {
	Vim::save_session(session_file => $sessionfile);
}

# retreive vcenter hostname
my $vcenter_fqdn = $vcenterserver;

$vcenter_fqdn =~ s/[ .]/_/g;
my $vcenter_name = lc ($vcenter_fqdn);

# retreive datacenter(s) list
my $datacentres_views = Vim::find_entity_views(view_type => 'Datacenter', properties => ['name']);

foreach my $datacentre_view (@$datacentres_views) {	
	my $datacentre_name = lc ($datacentre_view->name);
	$datacentre_name =~ s/[ .]/_/g;
	my $clusters_views = Vim::find_entity_views(view_type => 'ClusterComputeResource', properties => ['name','configurationEx', 'summary', 'datastore', 'host'], begin_entity => $datacentre_view);
	foreach my $cluster_view (@$clusters_views) {
		my $cluster_name = lc ($cluster_view->name);
		$cluster_name =~ s/[ .]/_/g;
		if($cluster_view->configurationEx->vsanConfigInfo->enabled) {
		
			my $hosts_views = Vim::find_entity_views(view_type => 'HostSystem', begin_entity => $cluster_view , properties => ['config.network.dnsConfig.hostName','configManager.vsanInternalSystem', 'runtime']);

			foreach my $host_view (@$hosts_views) {
				
				if ($host_view->runtime->connectionState->val eq "connected") {
				
					my $host_vsan_view = Vim::get_view(mo_ref => $host_view->{'configManager.vsanInternalSystem'});
					
					my $host_vsan_stats = $host_vsan_view->QueryVsanStatistics(labels => ['dom']);
					my $host_vsan_stats_json = from_json($host_vsan_stats);
					
					if ($host_vsan_stats_json) {
						my $host_vsan_stats_json_compmgr = $host_vsan_stats_json->{'dom.compmgr.stats'};
						my $host_vsan_stats_json_client = $host_vsan_stats_json->{'dom.client.stats'};
						my $host_vsan_stats_json_owner = $host_vsan_stats_json->{'dom.owner.stats'};
						my $host_vsan_stats_json_sched = $host_vsan_stats_json->{'dom.compmgr.schedStats'};
						my $host_name = lc ($host_view->{'config.network.dnsConfig.hostName'});

						foreach my $compmgrkey (keys %{ $host_vsan_stats_json_compmgr }) {
							$graphite->send(
							path => "vmw." . "$vcenter_name.$datacentre_name.$cluster_name.esx.$host_name" . ".vsan.compmgr.stats." . "$compmgrkey",
							value => $host_vsan_stats_json_compmgr->{$compmgrkey},
							time => time(),
							);
						}
						
						foreach my $clientkey (keys %{ $host_vsan_stats_json_client }) {
							$graphite->send(
							path => "vmw." . "$vcenter_name.$datacentre_name.$cluster_name.esx.$host_name" . ".vsan.client.stats." . "$clientkey",
							value => $host_vsan_stats_json_client->{$clientkey},
							time => time(),
							);
						}
						
						foreach my $ownerkey (keys %{ $host_vsan_stats_json_owner }) {
							$graphite->send(
							path => "vmw." . "$vcenter_name.$datacentre_name.$cluster_name.esx.$host_name" . ".vsan.owner.stats." . "$ownerkey",
							value => $host_vsan_stats_json_owner->{$ownerkey},
							time => time(),
							);
						}
						
						foreach my $schedkey (keys %{ $host_vsan_stats_json_sched }) {
							$graphite->send(
							path => "vmw." . "$vcenter_name.$datacentre_name.$cluster_name.esx.$host_name" . ".vsan.compmgr.schedStats." . "$schedkey",
							value => $host_vsan_stats_json_sched->{$schedkey},
							time => time(),
							);
						}
					}
					
					my $host_vsan_lsom = $host_vsan_view->QueryVsanStatistics(labels => ['lsom']);
					my $host_vsan_lsom_json = from_json($host_vsan_lsom);
					
					if ($host_vsan_lsom_json) {
						my $host_vsan_lsom_json_disks = $host_vsan_lsom_json->{'lsom.disks'};
						my $host_name = lc ($host_view->{'config.network.dnsConfig.hostName'});

						foreach my $lsomkey (keys %{ $host_vsan_lsom_json_disks }) {
							if ($host_vsan_lsom_json_disks->{$lsomkey}->{info}->{ssd} ne "NA") {
								my $lsomkeyCapacityUsed = $host_vsan_lsom_json_disks->{$lsomkey}->{info}->{capacityUsed};
								my $lsomkeyCapacity = $host_vsan_lsom_json_disks->{$lsomkey}->{info}->{capacity};
								my $lsomkeyCapacityUsedPercent = $lsomkeyCapacityUsed * 100 / $lsomkeyCapacity;
								
								$graphite->send(
								path => "vmw." . "$vcenter_name.$datacentre_name.$cluster_name.esx.$host_name" . ".vsan.lsom.disks." . "$lsomkey" . ".capacityUsed",
								value => $lsomkeyCapacityUsed,
								time => time(),
								);
								$graphite->send(
								path => "vmw." . "$vcenter_name.$datacentre_name.$cluster_name.esx.$host_name" . ".vsan.lsom.disks." . "$lsomkey" . ".capacity",
								value => $lsomkeyCapacity,
								time => time(),
								);
								$graphite->send(
								path => "vmw." . "$vcenter_name.$datacentre_name.$cluster_name.esx.$host_name" . ".vsan.lsom.disks." . "$lsomkey" . ".percentUsed",
								value => $lsomkeyCapacityUsedPercent,
								time => time(),
								);								
							}
						}
					}
				}
			}
		}
	}
}

my $exec_duration = time - $exec_start;
my $vcenter_exec_duration_h = {
	time() => {
		"$vcenter_name.vsan" . ".exec.duration", $exec_duration,
	},
};
$graphite->send(path => "vi.", data => $vcenter_exec_duration_h);

# disconnect from the server
# Util::disconnect();
