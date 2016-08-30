#!/usr/bin/perl -w
#

use strict;
use warnings;
use VMware::VIRuntime;
use VMware::VICredStore;
use JSON;
use Data::Dumper;
use Net::Graphite;
use List::Util qw[shuffle max];
use Log::Log4perl qw(:easy);

$Data::Dumper::Indent = 1;
$Util::script_version = "0.9.39";
$ENV{'PERL_LWP_SSL_VERIFY_HOSTNAME'} = 0;

Opts::parse();
Opts::validate();

my $url = Opts::get_option('url');
my $vcenterserver = Opts::get_option('server');
my $username = Opts::get_option('username');
my $password = Opts::get_option('password');
my $sessionfile = Opts::get_option('sessionfile');
my $credstorefile = Opts::get_option('credstore');


my $exec_start = time;
my $logger = Log::Log4perl->get_logger('sexigraf.ViPullStatistics');
VMware::VICredStore::init (filename => $credstorefile) or $logger->logdie ("[ERROR] Unable to initialize Credential Store.");
my @user_list = VMware::VICredStore::get_usernames (server => $vcenterserver);

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

BEGIN {
        Log::Log4perl::init('/etc/log4perl.conf');
	$SIG{__WARN__} = sub {
		   my $logger = get_logger('sexigraf.ViPullStatistics');
		   local $Log::Log4perl::caller_depth = $Log::Log4perl::caller_depth + 1;
		   $logger->warn("WARN @_");
	   };
	$SIG{__DIE__} = sub {
		   my $logger = get_logger('sexigraf.ViPullStatistics');
		   local $Log::Log4perl::caller_depth = $Log::Log4perl::caller_depth + 1;
		   $logger->fatal("DIE @_");
	   };
}

$logger->info("[INFO] Start processing vCenter $vcenterserver");

# handling multiple run
$0 = "ViPullStatistics from $vcenterserver";
my $PullProcess = 0;
foreach my $file (glob("/proc/[0-9]*/cmdline")) {
        open FILE, "<$file";
        if (grep(/^ViPullStatistics from $vcenterserver/, <FILE>) ) {
                $PullProcess++;
        }
        close FILE;
}
if (scalar $PullProcess  > 1) {$logger->logdie ("[ERROR] ViPullStatistics from $vcenterserver is already running!")}


# handling sessionfile if missing or expired
if (scalar @user_list == 0) {
	$logger->logdie ("[ERROR] No credential store user detected for $vcenterserver");
} elsif (scalar @user_list > 1) {
	$logger->logdie ("[ERROR] Multiple credential store user detected for $vcenterserver");
} else {
		foreach my $username (@user_list) {
			$logger->info("[INFO] Login to vCenter $vcenterserver");
			$password = VMware::VICredStore::get_password (server => $vcenterserver, username => $username);
			$url = "https://" . $vcenterserver . "/sdk";
			if (defined($sessionfile) and -e $sessionfile) {
					eval { Vim::load_session(service_url => $url, session_file => $sessionfile); };
					if ($@) {
							Vim::login(service_url => $url, user_name => $username, password => $password) or $logger->logdie ("[ERROR] Unable to connect to $url with username $username");
					}
			} else {
					Vim::login(service_url => $url, user_name => $username, password => $password) or $logger->logdie ("[ERROR] Unable to connect to $url with username $username");
			}

			if (defined($sessionfile)) {
					Vim::save_session(session_file => $sessionfile);
					$logger->info("[INFO] vCenter $vcenterserver session file saved");
			}
		}
}

# retreive vcenter hostname
my $vcenter_fqdn = $vcenterserver;

$vcenter_fqdn =~ s/[ .]/_/g;
my $vcenter_name = lc ($vcenter_fqdn);

my $perfMgr = (Vim::get_view(mo_ref => Vim::get_service_content()->perfManager));
my %perfCntr = map { $_->groupInfo->key . "." . $_->nameInfo->key . "." . $_->rollupType->val => $_ } @{$perfMgr->perfCounter};

sub QuickQueryPerf {
	my ($query_entity_view, $query_group, $query_counter, $query_rollup, $query_instance, $query_limit) = @_;
	my $perfKey = $perfCntr{"$query_group.$query_counter.$query_rollup"}->key;

	my @metricIDs = ();
	my $metricId = PerfMetricId->new(counterId => $perfKey, instance => $query_instance);
	push @metricIDs,$metricId;

	my $perfQuerySpec = PerfQuerySpec->new(entity => $query_entity_view, maxSample => 15, intervalId => 20, metricId => \@metricIDs);
	my $metrics = $perfMgr->QueryPerf(querySpec => [$perfQuerySpec]);

	foreach(@$metrics) {
		my $perfValues = $_->value;
			foreach(@$perfValues) {
				my $values = $_->value;
				my @s_values = sort { $a <=> $b } @$values;
				my $sum = 0;
				my $count = 0;
				foreach (@s_values) {
					if (($_ < $query_limit) && ($count < 13)) {
						$sum += $_;
						$count += 1;
					}
				}
				my $perfavg = $sum/$count;
				$perfavg =~ s/\.\d+$//;
				return $perfavg;
			}
	}

}

# retreive datacenter(s) list
my $datacentres_views = Vim::find_entity_views(view_type => 'Datacenter', properties => ['name']);

$logger->info("[INFO] Processing vCenter $vcenterserver datacenters");

 foreach my $datacentre_view (@$datacentres_views) {
	my $datacentre_name = lc ($datacentre_view->name);
	$datacentre_name =~ s/[ .]/_/g;
	my $clusters_views = Vim::find_entity_views(view_type => 'ClusterComputeResource', properties => ['name','configurationEx', 'summary', 'datastore', 'host'], begin_entity => $datacentre_view);

	$logger->info("[INFO] Processing vCenter $vcenterserver clusters in datacenter $datacentre_name");

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
			$graphite->send(path => "vmw", data => $cluster_root_pool_view_h);
		}
		if (my $cluster_vm_views = Vim::find_entity_views(view_type => 'VirtualMachine', begin_entity => $cluster_view, properties => ['runtime.powerState'])) {
			my $cluster_vm_views_on = Vim::find_entity_views(view_type => 'VirtualMachine', begin_entity => $cluster_view, properties => ['runtime.powerState'], filter => {'runtime.powerState' => "poweredOn"});

			my $cluster_vm_views_h = {
				time() => {
					"$vcenter_name.$datacentre_name.$cluster_name" . ".runtime.vm.total", scalar(@$cluster_vm_views),
					"$vcenter_name.$datacentre_name.$cluster_name" . ".runtime.vm.on", scalar(@$cluster_vm_views_on),
				},
			};
			$graphite->send(path => "vmw", data => $cluster_vm_views_h);
		}
		my $cluster_datastores = $cluster_view->datastore;
		foreach my $cluster_datastore (@$cluster_datastores) {
			my $cluster_datastore_view = Vim::get_view(mo_ref => $cluster_datastore, properties => ['summary','iormConfiguration','host']);
			if ($cluster_datastore_view->summary->accessible && $cluster_datastore_view->summary->multipleHostAccess) {
				my $shared_datastore_name = lc ($cluster_datastore_view->summary->name);
				$shared_datastore_name =~ s/[ .()]/_/g;
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
				$graphite->send(path => "vmw", data => $cluster_shared_datastore_view_h);

				if (($cluster_datastore_view->iormConfiguration->enabled or $cluster_datastore_view->iormConfiguration->statsCollectionEnabled) and !$cluster_datastore_view->iormConfiguration->statsAggregationDisabled) {
					foreach (shuffle @{$cluster_datastore_view->host}) {

						my $target_host_view = Vim::get_view(mo_ref => $_->key, properties => ['runtime']);

						if ($_->mountInfo->accessible and $_->mountInfo->mounted and $target_host_view->runtime->connectionState->val eq "connected") {

						my @vmpath = split("/", $_->mountInfo->path);
						my $uuid = $vmpath[-1];

						my $DsNormalizedDatastoreLatency = QuickQueryPerf($_->key, 'datastore', 'sizeNormalizedDatastoreLatency', 'average', $uuid, 30000000);
						my $DsdatastoreIops = QuickQueryPerf($_->key, 'datastore', 'datastoreIops', 'average', $uuid, 500000);

						my $DsQuickQueryPerf_h = {
							time() => {
								"$vcenter_name.$datacentre_name.$cluster_name.datastore.$shared_datastore_name" . ".iorm.sizeNormalizedDatastoreLatency", $DsNormalizedDatastoreLatency,
								"$vcenter_name.$datacentre_name.$cluster_name.datastore.$shared_datastore_name" . ".iorm.datastoreIops", $DsdatastoreIops,
							},
						};
						$graphite->send(path => "vmw", data => $DsQuickQueryPerf_h);
						last;
						}
					}
				} elsif ($cluster_datastore_view->summary->type ne "vsan") {
					foreach (shuffle @{$cluster_datastore_view->host}) {

						my $target_host_view = Vim::get_view(mo_ref => $_->key, properties => ['runtime']);

						if ($_->mountInfo->accessible and $_->mountInfo->mounted and $target_host_view->runtime->connectionState->val eq "connected") {

						my @vmpath = split("/", $_->mountInfo->path);
						my $uuid = $vmpath[-1];

						my $WriteDatastoreLatency = QuickQueryPerf($_->key, 'datastore', 'totalWriteLatency', 'average', $uuid, 30000) * 1000;
						my $ReadDatastoreLatency = QuickQueryPerf($_->key, 'datastore', 'totalReadLatency', 'average', $uuid, 30000) * 1000;
						my $sizeNormalizedDatastoreLatency = max($ReadDatastoreLatency,$WriteDatastoreLatency);

						my $DsQuickQueryPerf_h = {
							time() => {
								"$vcenter_name.$datacentre_name.$cluster_name.datastore.$shared_datastore_name" . ".iorm.sizeNormalizedDatastoreLatency", $sizeNormalizedDatastoreLatency
							},
						};
						$graphite->send(path => "vmw", data => $DsQuickQueryPerf_h);
						last;
						}
					}
				}
			}
		}

		my $cluster_hosts_views = Vim::find_entity_views(view_type => 'HostSystem', begin_entity => $cluster_view , properties => ['config.network.pnic', 'config.network.vnic', 'config.network.dnsConfig.hostName', 'runtime', 'summary', 'overallStatus'], filter => {'runtime.connectionState' => "connected"});

		my $cluster_hosts_views_pcpus = 0;

		foreach my $cluster_host_view (@$cluster_hosts_views) {
			my $host_name = lc ($cluster_host_view->{'config.network.dnsConfig.hostName'});
				if ($host_name eq "localhost") {
					my $cluster_host_view_Vmk0 = $cluster_host_view->{'config.network.vnic'}[0];
					my $cluster_host_view_Vmk0_Ip = $cluster_host_view_Vmk0->spec->ip->ipAddress;
					$cluster_host_view_Vmk0_Ip =~ s/[ .]/_/g;
					$host_name = $cluster_host_view_Vmk0_Ip;
			}
			
			$cluster_hosts_views_pcpus += $cluster_host_view->summary->hardware->numCpuCores;

			foreach my $cluster_host_vmnic (@{$cluster_host_view->{'config.network.pnic'}}) {
				if ($cluster_host_vmnic->linkSpeed && $cluster_host_vmnic->linkSpeed->speedMb >= 100) {
					my $NetbytesRx = QuickQueryPerf($cluster_host_view, 'net', 'bytesRx', 'average', $cluster_host_vmnic->device, 100000000);
					if (!defined($NetbytesRx)) { $NetbytesRx = 0; }
					my $NetbytesTx = QuickQueryPerf($cluster_host_view, 'net', 'bytesTx', 'average', $cluster_host_vmnic->device, 100000000);
					if (!defined($NetbytesTx)) { $NetbytesTx = 0; }
					my $cluster_host_vmnic_name = $cluster_host_vmnic->device;

					my $cluster_host_vmnic_h = {
						time() => {
							"$vcenter_name.$datacentre_name.$cluster_name.esx.$host_name" . ".net.$cluster_host_vmnic_name.bytesRx", $NetbytesRx,
							"$vcenter_name.$datacentre_name.$cluster_name.esx.$host_name" . ".net.$cluster_host_vmnic_name.bytesTx", $NetbytesTx,
							"$vcenter_name.$datacentre_name.$cluster_name.esx.$host_name" . ".net.$cluster_host_vmnic_name.linkSpeed", $cluster_host_vmnic->linkSpeed->speedMb,
						},
					};
					$graphite->send(path => "vmw", data => $cluster_host_vmnic_h);
				}
			}

			my $cluster_host_view_status = $cluster_host_view->{'overallStatus'}->val;
			my $cluster_host_view_status_val;
				if ($cluster_host_view_status eq "green") {
					$cluster_host_view_status_val = 1;
				} elsif ($cluster_host_view_status eq "yellow") {
					$cluster_host_view_status_val = 2;
				} elsif ($cluster_host_view_status eq "red") {
					$cluster_host_view_status_val = 3;
				} elsif ($cluster_host_view_status eq "gray") {
					$cluster_host_view_status_val = 0;
				}

			my $cluster_host_view_h = {
				time() => {
					"$vcenter_name.$datacentre_name.$cluster_name.esx.$host_name" . ".quickstats.distributedCpuFairness", $cluster_host_view->summary->quickStats->distributedCpuFairness,
					"$vcenter_name.$datacentre_name.$cluster_name.esx.$host_name" . ".quickstats.distributedMemoryFairness", $cluster_host_view->summary->quickStats->distributedMemoryFairness,
					"$vcenter_name.$datacentre_name.$cluster_name.esx.$host_name" . ".quickstats.overallCpuUsage", $cluster_host_view->summary->quickStats->overallCpuUsage,
					"$vcenter_name.$datacentre_name.$cluster_name.esx.$host_name" . ".quickstats.overallMemoryUsage", $cluster_host_view->summary->quickStats->overallMemoryUsage,
					"$vcenter_name.$datacentre_name.$cluster_name.esx.$host_name" . ".quickstats.Uptime", $cluster_host_view->summary->quickStats->uptime,
					"$vcenter_name.$datacentre_name.$cluster_name.esx.$host_name" . ".quickstats.overallStatus", $cluster_host_view_status_val,
				},
			};
			$graphite->send(path => "vmw", data => $cluster_host_view_h);
		}

		my $cluster_vm_views = Vim::find_entity_views(view_type => 'VirtualMachine', begin_entity => $cluster_view , properties => ['name', 'runtime.maxCpuUsage', 'summary.quickStats.overallCpuUsage', 'summary.quickStats.overallCpuDemand', 'summary.quickStats.hostMemoryUsage', 'summary.quickStats.guestMemoryUsage', 'summary.quickStats.balloonedMemory', 'summary.quickStats.compressedMemory', 'summary.quickStats.swappedMemory', 'summary.storage.committed', 'summary.storage.uncommitted', 'config.hardware.numCPU'], filter => {'summary.runtime.powerState' => "poweredOn"});
		
		my $cluster_vm_views_vcpus = 0;

		foreach my $cluster_vm_view (@$cluster_vm_views) {
			my $cluster_vm_view_name = lc ($cluster_vm_view->name);
			$cluster_vm_view_name =~ s/[ .()]/_/g;
			
			$cluster_vm_views_vcpus += $cluster_vm_view->{'config.hardware.numCPU'};
			
			my $cluster_vm_view_CpuUtilization;
			if ($cluster_vm_view->{'runtime.maxCpuUsage'} > 0 && $cluster_vm_view->{'summary.quickStats.overallCpuUsage'} > 0) {
				$cluster_vm_view_CpuUtilization = $cluster_vm_view->{'summary.quickStats.overallCpuUsage'} * 100 / $cluster_vm_view->{'runtime.maxCpuUsage'};
			} else {
				$cluster_vm_view_CpuUtilization = -1
			}
			
			my $cluster_vm_view_MemUtilization;
			if ($cluster_vm_view->{'summary.quickStats.guestMemoryUsage'} > 0 && $cluster_vm_view->{'summary.quickStats.hostMemoryUsage'} > 0) {
				$cluster_vm_view_MemUtilization = $cluster_vm_view->{'summary.quickStats.guestMemoryUsage'} * 100 / $cluster_vm_view->{'summary.quickStats.hostMemoryUsage'};
			} else {
				$cluster_vm_view_MemUtilization = -1
			}			

			my $cluster_vm_view_h = {
				time() => {
					"$vcenter_name.$datacentre_name.$cluster_name.vm.$cluster_vm_view_name" . ".quickstats.overallCpuUsage", $cluster_vm_view->{'summary.quickStats.overallCpuUsage'},
					"$vcenter_name.$datacentre_name.$cluster_name.vm.$cluster_vm_view_name" . ".quickstats.overallCpuDemand", $cluster_vm_view->{'summary.quickStats.overallCpuDemand'},
					"$vcenter_name.$datacentre_name.$cluster_name.vm.$cluster_vm_view_name" . ".quickstats.HostMemoryUsage", $cluster_vm_view->{'summary.quickStats.hostMemoryUsage'},
					"$vcenter_name.$datacentre_name.$cluster_name.vm.$cluster_vm_view_name" . ".quickstats.GuestMemoryUsage", $cluster_vm_view->{'summary.quickStats.guestMemoryUsage'},
					"$vcenter_name.$datacentre_name.$cluster_name.vm.$cluster_vm_view_name" . ".storage.committed", $cluster_vm_view->{'summary.storage.committed'},
					"$vcenter_name.$datacentre_name.$cluster_name.vm.$cluster_vm_view_name" . ".storage.uncommitted", $cluster_vm_view->{'summary.storage.uncommitted'},
					"$vcenter_name.$datacentre_name.$cluster_name.vm.$cluster_vm_view_name" . ".runtime.CpuUtilization", $cluster_vm_view_CpuUtilization,
					"$vcenter_name.$datacentre_name.$cluster_name.vm.$cluster_vm_view_name" . ".runtime.MemUtilization", $cluster_vm_view_MemUtilization,
				},
			};
			$graphite->send(path => "vmw", data => $cluster_vm_view_h);

			if ($cluster_vm_view->{'summary.quickStats.balloonedMemory'} > 0) {
				my $cluster_vm_view_ballooned_h = {
					time() => {
						"$vcenter_name.$datacentre_name.$cluster_name.vm.$cluster_vm_view_name" . ".quickstats.BalloonedMemory", $cluster_vm_view->{'summary.quickStats.balloonedMemory'},
					},
				};
				$graphite->send(path => "vmw", data => $cluster_vm_view_ballooned_h);
			}

			if ($cluster_vm_view->{'summary.quickStats.compressedMemory'} > 0) {
				my $cluster_vm_view_compressed_h = {
					time() => {
						"$vcenter_name.$datacentre_name.$cluster_name.vm.$cluster_vm_view_name" . ".quickstats.CompressedMemory", $cluster_vm_view->{'summary.quickStats.compressedMemory'},
					},
				};
				$graphite->send(path => "vmw", data => $cluster_vm_view_compressed_h);
			}

			if ($cluster_vm_view->{'summary.quickStats.swappedMemory'} > 0) {
				my $cluster_vm_view_swapped_h = {
					time() => {
						"$vcenter_name.$datacentre_name.$cluster_name.vm.$cluster_vm_view_name" . ".quickstats.SwappedMemory", $cluster_vm_view->{'summary.quickStats.swappedMemory'},
					},
				};
				$graphite->send(path => "vmw", data => $cluster_vm_view_swapped_h);
			}
		}
		
		if ($cluster_vm_views_vcpus > 0 && $cluster_hosts_views_pcpus > 0) {
			my $cluster_vcpus_pcpus_h = {
				time() => {
					"$vcenter_name.$datacentre_name.$cluster_name" . ".quickstats.vCPUs", $cluster_vm_views_vcpus,
					"$vcenter_name.$datacentre_name.$cluster_name" . ".quickstats.pCPUs", $cluster_hosts_views_pcpus,
				},
			};
			$graphite->send(path => "vmw", data => $cluster_vcpus_pcpus_h);			
		}
	}

	my $StandaloneComputeResources = Vim::find_entity_views(view_type => 'ComputeResource', filter => {'summary.numHosts' => "1"}, properties => ['summary', 'resourcePool', 'host', 'datastore'], begin_entity => $datacentre_view);

	$logger->info("[INFO] Processing vCenter $vcenterserver standalone hosts in datacenter $datacentre_name");

	foreach my $StandaloneComputeResource (@$StandaloneComputeResources) {
		if  ($StandaloneComputeResource->{'mo_ref'}->type eq "ComputeResource" ) {

			my @StandaloneResourceVMHost = Vim::get_views(mo_ref_array => $StandaloneComputeResource->host, properties => ['config.network.dnsConfig.hostName', 'config.network.vnic', 'config.network.pnic', 'overallStatus', 'runtime.connectionState']);
			if ($StandaloneResourceVMHost[0][0]->{'runtime.connectionState'}->val ne "connected") { next; }
			my $StandaloneResourcePool = Vim::get_view(mo_ref => $StandaloneComputeResource->resourcePool, properties => ['summary.quickStats']);
			my $StandaloneResourceDatastores = Vim::get_views(mo_ref_array => $StandaloneComputeResource->datastore, properties => ['summary']);

			my $StandaloneResourceVMHostName = $StandaloneResourceVMHost[0][0]->{'config.network.dnsConfig.hostName'};
			if ($StandaloneResourceVMHostName eq "localhost") {
				my $StandaloneResourceVMHostVmk0 = $StandaloneResourceVMHost[0][0]->{'config.network.vnic'}[0];
				my $StandaloneResourceVMHostVmk0Ip = $StandaloneResourceVMHostVmk0->spec->ip->ipAddress;
				$StandaloneResourceVMHostVmk0Ip =~ s/[ .]/_/g;
				$StandaloneResourceVMHostName = $StandaloneResourceVMHostVmk0Ip;
			}

			my $StandaloneResourceVMHost_status = $StandaloneResourceVMHost[0][0]->{'overallStatus'}->val;
			my $StandaloneResourceVMHost_status_val;
				if ($StandaloneResourceVMHost_status eq "green") {
					$StandaloneResourceVMHost_status_val = 1;
				} elsif ($StandaloneResourceVMHost_status eq "yellow") {
					$StandaloneResourceVMHost_status_val = 2;
				} elsif ($StandaloneResourceVMHost_status eq "red") {
					$StandaloneResourceVMHost_status_val = 3;
				} elsif ($StandaloneResourceVMHost_status eq "gray") {
					$StandaloneResourceVMHost_status_val = 0;
				}

			my $StandaloneComputeResource_h = {
				time() => {
					"$vcenter_name.$datacentre_name.$StandaloneResourceVMHostName" . ".quickstats.mem.ballooned", $StandaloneResourcePool->{'summary.quickStats'}->balloonedMemory,
					"$vcenter_name.$datacentre_name.$StandaloneResourceVMHostName" . ".quickstats.mem.compressed", $StandaloneResourcePool->{'summary.quickStats'}->compressedMemory,
					"$vcenter_name.$datacentre_name.$StandaloneResourceVMHostName" . ".quickstats.mem.consumedOverhead", $StandaloneResourcePool->{'summary.quickStats'}->consumedOverheadMemory,
					"$vcenter_name.$datacentre_name.$StandaloneResourceVMHostName" . ".quickstats.mem.guest", $StandaloneResourcePool->{'summary.quickStats'}->guestMemoryUsage,
					"$vcenter_name.$datacentre_name.$StandaloneResourceVMHostName" . ".quickstats.mem.usage", $StandaloneResourcePool->{'summary.quickStats'}->hostMemoryUsage,
					"$vcenter_name.$datacentre_name.$StandaloneResourceVMHostName" . ".quickstats.cpu.demand", $StandaloneResourcePool->{'summary.quickStats'}->overallCpuDemand,
					"$vcenter_name.$datacentre_name.$StandaloneResourceVMHostName" . ".quickstats.cpu.usage", $StandaloneResourcePool->{'summary.quickStats'}->overallCpuUsage,
					"$vcenter_name.$datacentre_name.$StandaloneResourceVMHostName" . ".quickstats.mem.overhead", $StandaloneResourcePool->{'summary.quickStats'}->overheadMemory,
					"$vcenter_name.$datacentre_name.$StandaloneResourceVMHostName" . ".quickstats.mem.private", $StandaloneResourcePool->{'summary.quickStats'}->privateMemory,
					"$vcenter_name.$datacentre_name.$StandaloneResourceVMHostName" . ".quickstats.mem.shared", $StandaloneResourcePool->{'summary.quickStats'}->sharedMemory,
					"$vcenter_name.$datacentre_name.$StandaloneResourceVMHostName" . ".quickstats.mem.swapped", $StandaloneResourcePool->{'summary.quickStats'}->swappedMemory,
					"$vcenter_name.$datacentre_name.$StandaloneResourceVMHostName" . ".quickstats.mem.effective", $StandaloneComputeResource->summary->effectiveMemory,
					"$vcenter_name.$datacentre_name.$StandaloneResourceVMHostName" . ".quickstats.mem.total", $StandaloneComputeResource->summary->totalMemory,
					"$vcenter_name.$datacentre_name.$StandaloneResourceVMHostName" . ".quickstats.cpu.effective", $StandaloneComputeResource->summary->effectiveCpu,
					"$vcenter_name.$datacentre_name.$StandaloneResourceVMHostName" . ".quickstats.cpu.total", $StandaloneComputeResource->summary->totalCpu,
					"$vcenter_name.$datacentre_name.$StandaloneResourceVMHostName" . ".quickstats.overallStatus", $StandaloneResourceVMHost_status_val,
				},
			};
			$graphite->send(path => "esx", data => $StandaloneComputeResource_h);

			foreach my $StandaloneResourceDatastore (@$StandaloneResourceDatastores) {
				if ($StandaloneResourceDatastore->summary->accessible) {
					my $StandaloneResourceDatastore_name = lc ($StandaloneResourceDatastore->summary->name);
					$StandaloneResourceDatastore_name =~ s/[ .()]/_/g;
					my $StandaloneResourceDatastore_uncommitted = 0;
					if ($StandaloneResourceDatastore->summary->uncommitted) {
						$StandaloneResourceDatastore_uncommitted = $StandaloneResourceDatastore->summary->uncommitted;
					}
					my $StandaloneResourceVMHost_datastore_view_h = {
						time() => {
							"$vcenter_name.$datacentre_name.$StandaloneResourceVMHostName.datastore.$StandaloneResourceDatastore_name" . ".summary.capacity", $StandaloneResourceDatastore->summary->capacity,
							"$vcenter_name.$datacentre_name.$StandaloneResourceVMHostName.datastore.$StandaloneResourceDatastore_name" . ".summary.freeSpace", $StandaloneResourceDatastore->summary->freeSpace,
							"$vcenter_name.$datacentre_name.$StandaloneResourceVMHostName.datastore.$StandaloneResourceDatastore_name" . ".summary.uncommitted", $StandaloneResourceDatastore_uncommitted,
						},
					};
					$graphite->send(path => "esx", data => $StandaloneResourceVMHost_datastore_view_h);
				}
			}

			foreach my $StandaloneResourceVMHost_vmnic (@{$StandaloneResourceVMHost[0][0]->{'config.network.pnic'}}) {
				if ($StandaloneResourceVMHost_vmnic->linkSpeed && $StandaloneResourceVMHost_vmnic->linkSpeed->speedMb >= 100) {
					my $NetbytesRx = QuickQueryPerf($StandaloneResourceVMHost[0][0], 'net', 'bytesRx', 'average', $StandaloneResourceVMHost_vmnic->device, 100000000);
					my $NetbytesTx = QuickQueryPerf($StandaloneResourceVMHost[0][0], 'net', 'bytesTx', 'average', $StandaloneResourceVMHost_vmnic->device, 100000000);
					my $StandaloneResourceVMHost_vmnic_name = $StandaloneResourceVMHost_vmnic->device;

					my $StandaloneResourceVMHost_vmnic_h = {
						time() => {
							"$vcenter_name.$datacentre_name.$StandaloneResourceVMHostName" . ".net.$StandaloneResourceVMHost_vmnic_name.bytesRx", $NetbytesRx,
							"$vcenter_name.$datacentre_name.$StandaloneResourceVMHostName" . ".net.$StandaloneResourceVMHost_vmnic_name.bytesTx", $NetbytesTx,
							"$vcenter_name.$datacentre_name.$StandaloneResourceVMHostName" . ".net.$StandaloneResourceVMHost_vmnic_name.linkSpeed", $StandaloneResourceVMHost_vmnic->linkSpeed->speedMb,
						},
					};
					$graphite->send(path => "esx", data => $StandaloneResourceVMHost_vmnic_h);
				}
			}

			if (my $Standalone_vm_views = Vim::find_entity_views(view_type => 'VirtualMachine', begin_entity => $StandaloneResourceVMHost[0][0], properties => ['runtime'])) {
				my $Standalone_vm_views_on = Vim::find_entity_views(view_type => 'VirtualMachine', begin_entity => $StandaloneResourceVMHost[0][0], properties => ['runtime'], filter => {'runtime.powerState' => "poweredOn"});
				my $Standalone_vm_views_h = {
					time() => {
						"$vcenter_name.$datacentre_name.$StandaloneResourceVMHostName" . ".runtime.vm.total", scalar(@$Standalone_vm_views),
						"$vcenter_name.$datacentre_name.$StandaloneResourceVMHostName" . ".runtime.vm.on", scalar(@$Standalone_vm_views_on),
					},
				};
				$graphite->send(path => "esx", data => $Standalone_vm_views_h);
			}

		}
	}
}

my $exec_duration = time - $exec_start;
my $vcenter_exec_duration_h = {
	time() => {
		"$vcenter_name.vi" . ".exec.duration", $exec_duration,
	},
};
$graphite->send(path => "vi", data => $vcenter_exec_duration_h);

$logger->info("[INFO] End processing vCenter $vcenterserver");

# disconnect from the server
# Util::disconnect();
