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
		if (my $cluster_root_pool_view = Vim::find_entity_view(view_type => 'ResourcePool', filter => {name => qr/^Resources$/}, properties => ['summary.quickStats'], begin_entity => $cluster_view)) {
			my $cluster_root_pool_quickStats = $cluster_root_pool_view->get_property('summary.quickStats');
			my $cluster_root_pool_view_h = {
				time() => {
					"$vcenter_name.$datacentre_name.$cluster_name" . ".quickstats.mem.ballooned", $cluster_root_pool_quickStats->balloonedMemory,
					"$vcenter_name.$datacentre_name.$cluster_name" . ".quickstats.mem.compressed", $cluster_root_pool_quickStats->compressedMemory,
					"$vcenter_name.$datacentre_name.$cluster_name" . ".quickstats.mem.consumedOverhead", $cluster_root_pool_quickStats->consumedOverheadMemory,
					"$vcenter_name.$datacentre_name.$cluster_name" . ".quickstats.cpu.distributedCpuEntitlement", $cluster_root_pool_quickStats->distributedCpuEntitlement,
					"$vcenter_name.$datacentre_name.$cluster_name" . ".quickstats.mem.distributedMemoryEntitlement", $cluster_root_pool_quickStats->distributedMemoryEntitlement,
					"$vcenter_name.$datacentre_name.$cluster_name" . ".quickstats.mem.guest", $cluster_root_pool_quickStats->guestMemoryUsage,
					"$vcenter_name.$datacentre_name.$cluster_name" . ".quickstats.mem.usage", $cluster_root_pool_quickStats->hostMemoryUsage,
					"$vcenter_name.$datacentre_name.$cluster_name" . ".quickstats.cpu.demand", $cluster_root_pool_quickStats->overallCpuDemand,
					"$vcenter_name.$datacentre_name.$cluster_name" . ".quickstats.cpu.usage", $cluster_root_pool_quickStats->overallCpuUsage,
					"$vcenter_name.$datacentre_name.$cluster_name" . ".quickstats.mem.overhead", $cluster_root_pool_quickStats->overheadMemory,
					"$vcenter_name.$datacentre_name.$cluster_name" . ".quickstats.mem.private", $cluster_root_pool_quickStats->privateMemory,
					"$vcenter_name.$datacentre_name.$cluster_name" . ".quickstats.cpu.staticCpuEntitlement", $cluster_root_pool_quickStats->staticCpuEntitlement,
					"$vcenter_name.$datacentre_name.$cluster_name" . ".quickstats.mem.staticMemoryEntitlement", $cluster_root_pool_quickStats->staticMemoryEntitlement,
					"$vcenter_name.$datacentre_name.$cluster_name" . ".quickstats.mem.shared", $cluster_root_pool_quickStats->sharedMemory,
					"$vcenter_name.$datacentre_name.$cluster_name" . ".quickstats.mem.swapped", $cluster_root_pool_quickStats->swappedMemory,
					"$vcenter_name.$datacentre_name.$cluster_name" . ".quickstats.mem.effective", $cluster_view->summary->effectiveMemory,
					"$vcenter_name.$datacentre_name.$cluster_name" . ".quickstats.mem.total", $cluster_view->summary->totalMemory,
					"$vcenter_name.$datacentre_name.$cluster_name" . ".quickstats.cpu.effective", $cluster_view->summary->effectiveCpu,
					"$vcenter_name.$datacentre_name.$cluster_name" . ".quickstats.cpu.total", $cluster_view->summary->totalCpu,					
					"$vcenter_name.$datacentre_name.$cluster_name" . ".quickstats.numVmotions", $cluster_view->summary->numVmotions,
				},
			};
			$graphite->send(path => "vmw.", data => $cluster_root_pool_view_h);
		}
		if (my $cluster_vm_views = Vim::find_entity_views(view_type => 'VirtualMachine', begin_entity => $cluster_view, properties => ['runtime'])) {
			my $cluster_vm_views_on = Vim::find_entity_views(view_type => 'VirtualMachine', begin_entity => $cluster_view, properties => ['runtime'], filter => {'runtime.powerState' => "poweredOn"});
			my $cluster_vm_views_h = {
				time() => {
					"$vcenter_name.$datacentre_name.$cluster_name" . ".runtime.vm.total", scalar(@$cluster_vm_views),
					"$vcenter_name.$datacentre_name.$cluster_name" . ".runtime.vm.on", scalar(@$cluster_vm_views_on),
				},
			};
			$graphite->send(path => "vmw.", data => $cluster_vm_views_h);
		}
		my $cluster_datastores = $cluster_view->datastore;
		foreach my $cluster_datastore (@$cluster_datastores) {
			my $cluster_datastore_view = Vim::get_view(mo_ref => $cluster_datastore, properties => ['summary']);
			if ($cluster_datastore_view->summary->accessible && $cluster_datastore_view->summary->multipleHostAccess) {
				my $shared_datastore_name = lc ($cluster_datastore_view->summary->name);
				$shared_datastore_name =~ s/[ .]/_/g;
				my $shared_datastore_uncommitted = 0;
				if ($cluster_datastore_view->summary->uncommitted) {
					$shared_datastore_uncommitted = $cluster_datastore_view->summary->uncommitted;
				}
				my $cluster_shared_datastore_view_h = {
					time() => {
						"$vcenter_name.$datacentre_name.$cluster_name.datastore.$shared_datastore_name" . ".summary.capacity", $cluster_datastore_view->summary->capacity,
						"$vcenter_name.$datacentre_name.$cluster_name.datastore.$shared_datastore_name" . ".summary.freeSpace", $cluster_datastore_view->summary->freeSpace,
						"$vcenter_name.$datacentre_name.$cluster_name.datastore.$shared_datastore_name" . ".summary.uncommitted", $shared_datastore_uncommitted,
					},
				};
				$graphite->send(path => "vmw.", data => $cluster_shared_datastore_view_h);		
			}
		}
		my $cluster_hosts_views = Vim::find_entity_views(view_type => 'HostSystem', begin_entity => $cluster_view , properties => ['config.network.dnsConfig.hostName', 'runtime', 'summary'], filter => {'runtime.connectionState' => "connected"});
		foreach my $cluster_host_view (@$cluster_hosts_views) {
			my $host_name = lc ($cluster_host_view->{'config.network.dnsConfig.hostName'});
			my $cluster_host_view_h = {
				time() => {
					"$vcenter_name.$datacentre_name.$cluster_name.esx.$host_name" . ".quickstats.distributedCpuFairness", $cluster_host_view->summary->quickStats->distributedCpuFairness,
					"$vcenter_name.$datacentre_name.$cluster_name.esx.$host_name" . ".quickstats.distributedMemoryFairness", $cluster_host_view->summary->quickStats->distributedMemoryFairness,
					"$vcenter_name.$datacentre_name.$cluster_name.esx.$host_name" . ".quickstats.overallCpuUsage", $cluster_host_view->summary->quickStats->overallCpuUsage,
					"$vcenter_name.$datacentre_name.$cluster_name.esx.$host_name" . ".quickstats.overallMemoryUsage", $cluster_host_view->summary->quickStats->overallMemoryUsage,						
				},
			};
			$graphite->send(path => "vmw.", data => $cluster_host_view_h);		
		}
	}
}

my $exec_duration = time - $exec_start;
my $vcenter_exec_duration_h = {
	time() => {
		"$vcenter_name.ha" . ".exec.duration", $exec_duration,
	},
};
$graphite->send(path => "vi.", data => $vcenter_exec_duration_h);

# disconnect from the server
# Util::disconnect();
