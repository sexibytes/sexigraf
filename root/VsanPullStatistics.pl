#!/usr/bin/perl -w
#

use strict;
use warnings;
use VMware::VIRuntime;
use VMware::VICredStore;
use JSON;
# use Data::Dumper;
use Net::Graphite;
use Log::Log4perl qw(:easy);
use List::Util qw[shuffle sum];

$Data::Dumper::Indent = 1;
$Util::script_version = "0.9.25";
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
my $logger = Log::Log4perl->get_logger('sexigraf.VsanDisksPullStatistics');
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
		   my $logger = get_logger('sexigraf.VsanDisksPullStatistics');
		   local $Log::Log4perl::caller_depth = $Log::Log4perl::caller_depth + 1;
		   $logger->warn("WARN @_");
	   };		
	$SIG{__DIE__} = sub {
		   my $logger = get_logger('sexigraf.VsanDisksPullStatistics');
		   local $Log::Log4perl::caller_depth = $Log::Log4perl::caller_depth + 1;
		   $logger->fatal("DIE @_");
	   };
}

$logger->info("[INFO] Looking for another VsanPullStatistics from $vcenterserver");

# handling multiple run
$0 = "VsanPullStatistics from $vcenterserver";
my $PullProcess = 0;
foreach my $file (glob("/proc/[0-9]*/cmdline")) {
        open FILE, "<$file";
        if (grep(/^VsanPullStatistics from $vcenterserver/, <FILE>) ) {
                $PullProcess++;
        }
        close FILE;
}
if (scalar $PullProcess  > 1) {$logger->logdie ("[ERROR] VsanPullStatistics from $vcenterserver is already running!")}

$logger->info("[INFO] Start processing vCenter $vcenterserver");

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
			if ($@) { Vim::login(service_url => $url, user_name => $username, password => $password) or $logger->logdie ("[ERROR] Unable to connect to $url with username $username"); }
		} else { Vim::login(service_url => $url, user_name => $username, password => $password) or $logger->logdie ("[ERROR] Unable to connect to $url with username $username"); }

		if (defined($sessionfile)) {
			Vim::save_session(session_file => $sessionfile);
			$logger->info("[INFO] vCenter $vcenterserver session file saved");
		}
	}
}

sub getParent {
        my ($parent) = @_;
        if($parent->parent) { getParent($parent->parent); }
	return $parent;
}

sub getObj {
	my ($obj, $keys, $ret) = @_;
	
	foreach my $key (keys %$obj) {
		
		if ($key eq 'attributes') {
			foreach my $attr (keys %{$obj->{$key}}) {
				if (grep $_ eq $attr, @$keys) {
					push(@{$ret->{$attr}}, $obj->{$key}->{$attr});
				}
			}
		}

		if ($key =~ /^child-/) {
			getObj($obj->{$key}, $keys, $ret);
		}
	}
}

my $fields = ['bytesToSync', 'recoveryETA'];

# retreive vcenter hostname
my $vcenter_fqdn = $vcenterserver;

$vcenter_fqdn =~ s/[ .]/_/g;
my $vcenter_name = lc ($vcenter_fqdn);

# retreive datacenter(s) list
my $datacentres_views = Vim::find_entity_views(view_type => 'Datacenter', properties => ['name']);

$logger->info("[INFO] Processing vCenter $vcenterserver datacenters");

foreach my $datacentre_view (@$datacentres_views) {	
	my $datacentre_name = lc ($datacentre_view->name);
	$datacentre_name =~ s/[ .]/_/g;
	
	my $clusters_views = Vim::find_entity_views(view_type => 'ClusterComputeResource', properties => ['name','host'], begin_entity => $datacentre_view);
	
	$logger->info("[INFO] Processing vCenter $vcenterserver clusters");
	
	foreach my $cluster_view (@$clusters_views) {
		my $cluster_name = lc ($cluster_view->name);
		$cluster_name =~ s/[ .]/_/g;
		if(scalar $cluster_view->host > 1) {
			
			my $hosts_views = Vim::find_entity_views(view_type => 'HostSystem' , properties => ['config.vsanHostConfig.clusterInfo.uuid'] , filter => {'config.vsanHostConfig.clusterInfo.uuid' => qr/-/}, begin_entity => $cluster_view);
			
			if (@$hosts_views[0]) {
			
				my $vsan_cluster_uuid = @$hosts_views[0]->{'config.vsanHostConfig.clusterInfo.uuid'};
				$logger->info("[INFO] Processing vCenter $vcenterserver VSAN cluster $cluster_name $vsan_cluster_uuid");
				
				$hosts_views = Vim::find_entity_views(view_type => 'HostSystem' , properties => ['config.network.dnsConfig.hostName','configManager.vsanInternalSystem','runtime.connectionState','runtime.inMaintenanceMode'] , filter => {'config.vsanHostConfig.clusterInfo.uuid' => $vsan_cluster_uuid});
				
				my $vm_views_device = Vim::find_entity_views(view_type => 'VirtualMachine', begin_entity => $cluster_view , properties => ['config.hardware.device']);
				my $VirtualDisks = {};

				foreach my $vm_view_device (@$vm_views_device) {
					my $vmDevices = $vm_view_device->{'config.hardware.device'};

					foreach(@$vmDevices) {
						if($_->isa('VirtualDisk')) {
												
							my @vmdkpath = split("/", $_->backing->fileName);
							my $vmdk = substr($vmdkpath[-1], 0, -5);
							$vmdk =~ s/[ .()]/_/g;
							$VirtualDisks->{ $_->backing->backingObjectId } = $vmdk;
							
							if ($_->backing->parent) {
								my $rootparent = getParent($_->backing->parent);
								my @rootvmdkpath = split("/", $rootparent->fileName);
								my $rootvmdk = substr($rootvmdkpath[-1], 0, -5);
								$rootvmdk =~ s/[ .()]/_/g;
								$VirtualDisks->{ $_->backing->backingObjectId . "_root"} = $rootparent->backingObjectId;
								$VirtualDisks->{ $rootparent->backingObjectId} = $rootvmdk;
							}
						}
					}
				}

				my $host_vsan_physical_disks_json;

				foreach (shuffle @{$hosts_views}) {

					if ($_->{'runtime.connectionState'}->val eq "connected" && $_->{'runtime.inMaintenanceMode'} eq "false") {
				
						my $shuffle_host_vsan_view = Vim::get_view(mo_ref => $_->{'configManager.vsanInternalSystem'});
						
						my $host_vsan_physical_disks = $shuffle_host_vsan_view->QueryPhysicalVsanDisks();
						$host_vsan_physical_disks_json = from_json($host_vsan_physical_disks);

						my $host_vsan_syncing_objects = $shuffle_host_vsan_view->QuerySyncingVsanObjects();
						my $host_vsan_syncing_objects_json = from_json($host_vsan_syncing_objects);
						my $host_vsan_syncing_objects_json_domobjs = $host_vsan_syncing_objects_json->{dom_objects};

						if ($host_vsan_syncing_objects_json_domobjs) {
						
							$logger->info("[INFO] Processing resync objects of VSAN cluster $cluster_name");
						
							my $vsan_bytesToSync = 0;
							my $vsan_recoveryETA = 0;
							my $vsan_sync_objs = 0;

							foreach my $uuid (keys %$host_vsan_syncing_objects_json_domobjs) {
								my $return = {};
								getObj($host_vsan_syncing_objects_json_domobjs->{$uuid}->{'config'}->{'content'}, $fields, $return);

								$vsan_bytesToSync += sum(@{$return->{bytesToSync}});
								$vsan_recoveryETA += sum(@{$return->{recoveryETA}});
								$vsan_sync_objs += @{$return->{bytesToSync}};
							}
							
							my $vsan_syncing_objects_attributes_h = {
								time() => {
									"$vcenter_name.$datacentre_name.$cluster_name.vsan.dom_objects.config.content.attributes.bytesToSync", $vsan_bytesToSync,
									"$vcenter_name.$datacentre_name.$cluster_name.vsan.dom_objects.config.content.attributes.recoveryETA", $vsan_recoveryETA,
									"$vcenter_name.$datacentre_name.$cluster_name.vsan.dom_objects.config.content.attributes.objectsToSync", $vsan_sync_objs,
								},
							};
							$graphite->send(path => "vsan.", data => $vsan_syncing_objects_attributes_h);
							last;
						}	
					}
				}
				
				foreach my $host_view (@$hosts_views) {
					
					if ($host_view->{'runtime.connectionState'}->val eq "connected" && $host_view->{'runtime.inMaintenanceMode'} eq "false") {
					
						my $host_vsan_view = Vim::get_view(mo_ref => $host_view->{'configManager.vsanInternalSystem'});
						my $host_vsan_query_vsan_stats = $host_vsan_view->QueryVsanStatistics(labels => ['dom', 'lsom', 'dom-objects', 'disks']);
						my $host_vsan_query_vsan_stats_json = from_json($host_vsan_query_vsan_stats);
						my $host_name = lc ($host_view->{'config.network.dnsConfig.hostName'});
											
						if ($host_vsan_query_vsan_stats_json) {
							
							# processing dom
							my $host_vsan_stats_json_compmgr = $host_vsan_query_vsan_stats_json->{'dom.compmgr.stats'};
							my $host_vsan_stats_json_client = $host_vsan_query_vsan_stats_json->{'dom.client.stats'};
							my $host_vsan_stats_json_owner = $host_vsan_query_vsan_stats_json->{'dom.owner.stats'};
							my $host_vsan_stats_json_sched = $host_vsan_query_vsan_stats_json->{'dom.compmgr.schedStats'};

							foreach my $compmgrkey (keys %{ $host_vsan_stats_json_compmgr }) {
								$graphite->send(
								path => "vsan." . "$vcenter_name.$datacentre_name.$cluster_name.esx.$host_name" . ".vsan.compmgr.stats." . "$compmgrkey",
								value => $host_vsan_stats_json_compmgr->{$compmgrkey},
								time => time(),
								);
							}
							
							foreach my $clientkey (keys %{ $host_vsan_stats_json_client }) {
								$graphite->send(
								path => "vsan." . "$vcenter_name.$datacentre_name.$cluster_name.esx.$host_name" . ".vsan.client.stats." . "$clientkey",
								value => $host_vsan_stats_json_client->{$clientkey},
								time => time(),
								);
							}
							
							foreach my $ownerkey (keys %{ $host_vsan_stats_json_owner }) {
								$graphite->send(
								path => "vsan." . "$vcenter_name.$datacentre_name.$cluster_name.esx.$host_name" . ".vsan.owner.stats." . "$ownerkey",
								value => $host_vsan_stats_json_owner->{$ownerkey},
								time => time(),
								);
							}
							
							foreach my $schedkey (keys %{ $host_vsan_stats_json_sched }) {
								$graphite->send(
								path => "vsan." . "$vcenter_name.$datacentre_name.$cluster_name.esx.$host_name" . ".vsan.compmgr.schedStats." . "$schedkey",
								value => $host_vsan_stats_json_sched->{$schedkey},
								time => time(),
								);
							}

							# processing lsom
							my $host_vsan_lsom_json_disks = $host_vsan_query_vsan_stats_json->{'lsom.disks'};

							foreach my $lsomkey (keys %{ $host_vsan_lsom_json_disks }) {
								if ($host_vsan_lsom_json_disks->{$lsomkey}->{info}->{ssd} ne "NA") {
									my $lsomkeyCapacityUsed = $host_vsan_lsom_json_disks->{$lsomkey}->{info}->{capacityUsed};
									my $lsomkeyCapacity = $host_vsan_lsom_json_disks->{$lsomkey}->{info}->{capacity};
									my $lsomkeyCapacityUsedPercent = $lsomkeyCapacityUsed * 100 / $lsomkeyCapacity;
									my $lsomkeySsdUuid = $host_vsan_lsom_json_disks->{$lsomkey}->{info}->{ssd};
									my $vsan_cache_ssd_naa = $host_vsan_physical_disks_json->{$lsomkeySsdUuid}->{devName};
									my @vsan_cache_ssd_clean_naa = split /[.:]/, $vsan_cache_ssd_naa;
									my $host_vsan_lsom_json_disks_h = {
										time() => {
											"$vcenter_name.$datacentre_name.$cluster_name.esx.$host_name" . ".vsan.lsom.disks." . "$lsomkey" . ".capacityUsed", $lsomkeyCapacityUsed,
											"$vcenter_name.$datacentre_name.$cluster_name.esx.$host_name" . ".vsan.lsom.disks." . "$lsomkey" . ".capacity", $lsomkeyCapacity,
											"$vcenter_name.$datacentre_name.$cluster_name.esx.$host_name" . ".vsan.lsom.disks." . "$lsomkey" . ".percentUsed", $lsomkeyCapacityUsedPercent,
											"$vcenter_name.$datacentre_name.$cluster_name.esx.$host_name" . ".vsan.lsom.diskgroup." . "$vsan_cache_ssd_clean_naa[1]" . "." . "$lsomkey" . ".percentUsed", $lsomkeyCapacityUsedPercent,
										},
									};
									$graphite->send(path => "vsan.", data => $host_vsan_lsom_json_disks_h);
								}
								elsif ($host_vsan_lsom_json_disks->{$lsomkey}->{info}->{ssd} eq "NA") {
									my $lsomkeyMiss = $host_vsan_lsom_json_disks->{$lsomkey}->{info}->{aggStats}->{miss};
									my $lsomkeyQuotaEvictions = $host_vsan_lsom_json_disks->{$lsomkey}->{info}->{aggStats}->{quotaEvictions};
									my $lsomkeyReadIoCount = $host_vsan_lsom_json_disks->{$lsomkey}->{info}->{aggStats}->{readIoCount};
									my $lsomkeyWBsize = $host_vsan_lsom_json_disks->{$lsomkey}->{info}->{wbSize};
									my $lsomkeyWBfreeSpace = $host_vsan_lsom_json_disks->{$lsomkey}->{info}->{wbFreeSpace};
									my $lsomkeyWBwriteIoCount = $host_vsan_lsom_json_disks->{$lsomkey}->{info}->{aggStats}->{writeIoCount};
									my $lsomkeyBytesRead = $host_vsan_lsom_json_disks->{$lsomkey}->{info}->{aggStats}->{bytesRead};
									my $lsomkeyBytesWritten = $host_vsan_lsom_json_disks->{$lsomkey}->{info}->{aggStats}->{bytesWritten};
									my $lsomkeyCapacityUsed = $host_vsan_lsom_json_disks->{$lsomkey}->{info}->{capacityUsed};
									my $lsomkeyCapacity = $host_vsan_lsom_json_disks->{$lsomkey}->{info}->{capacity};

									my $host_vsan_lsom_json_ssd_h = {
										time() => {
											"$vcenter_name.$datacentre_name.$cluster_name.esx.$host_name" . ".vsan.lsom.ssd." . "$lsomkey" . ".miss", $lsomkeyMiss,
											"$vcenter_name.$datacentre_name.$cluster_name.esx.$host_name" . ".vsan.lsom.ssd." . "$lsomkey" . ".quotaEvictions", $lsomkeyQuotaEvictions,
											"$vcenter_name.$datacentre_name.$cluster_name.esx.$host_name" . ".vsan.lsom.ssd." . "$lsomkey" . ".readIoCount", $lsomkeyReadIoCount,
											"$vcenter_name.$datacentre_name.$cluster_name.esx.$host_name" . ".vsan.lsom.ssd." . "$lsomkey" . ".wbSize", $lsomkeyWBsize,
											"$vcenter_name.$datacentre_name.$cluster_name.esx.$host_name" . ".vsan.lsom.ssd." . "$lsomkey" . ".wbFreeSpace", $lsomkeyWBfreeSpace,
											"$vcenter_name.$datacentre_name.$cluster_name.esx.$host_name" . ".vsan.lsom.ssd." . "$lsomkey" . ".writeIoCount", $lsomkeyWBwriteIoCount,
											"$vcenter_name.$datacentre_name.$cluster_name.esx.$host_name" . ".vsan.lsom.ssd." . "$lsomkey" . ".bytesRead", $lsomkeyBytesRead,
											"$vcenter_name.$datacentre_name.$cluster_name.esx.$host_name" . ".vsan.lsom.ssd." . "$lsomkey" . ".bytesWritten", $lsomkeyBytesWritten,
											"$vcenter_name.$datacentre_name.$cluster_name.esx.$host_name" . ".vsan.lsom.ssd." . "$lsomkey" . ".capacityUsed", $lsomkeyCapacityUsed,
											"$vcenter_name.$datacentre_name.$cluster_name.esx.$host_name" . ".vsan.lsom.ssd." . "$lsomkey" . ".capacity", $lsomkeyCapacity,
										},
									};
									$graphite->send(path => "vsan.", data => $host_vsan_lsom_json_ssd_h);
								}
							}
							
							# processing dom-objects
							my $host_vsan_dom_objects_json_stats = $host_vsan_query_vsan_stats_json->{'dom.owners.stats'};

							foreach my $dom_objects_key (keys %{ $host_vsan_dom_objects_json_stats }) {
								if ($VirtualDisks->{$dom_objects_key}) {
									if ($VirtualDisks->{$dom_objects_key . "_root"}) {
										my $root_dom_objects_key = $VirtualDisks->{$dom_objects_key . "_root"};
										my $host_vsan_dom_objects_json_stats_h_snap = {
											time() => {
												"$vcenter_name.$datacentre_name.$cluster_name" . ".vsan.dom.owners.stats." . "$root_dom_objects_key.$VirtualDisks->{$dom_objects_key}" . ".readCount", $host_vsan_dom_objects_json_stats->{$dom_objects_key}->{readCount},
												"$vcenter_name.$datacentre_name.$cluster_name" . ".vsan.dom.owners.stats." . "$root_dom_objects_key.$VirtualDisks->{$dom_objects_key}" . ".writeCount", $host_vsan_dom_objects_json_stats->{$dom_objects_key}->{writeCount},
												"$vcenter_name.$datacentre_name.$cluster_name" . ".vsan.dom.owners.stats." . "$root_dom_objects_key.$VirtualDisks->{$dom_objects_key}" . ".readBytes", $host_vsan_dom_objects_json_stats->{$dom_objects_key}->{readBytes},
												"$vcenter_name.$datacentre_name.$cluster_name" . ".vsan.dom.owners.stats." . "$root_dom_objects_key.$VirtualDisks->{$dom_objects_key}" . ".writeBytes", $host_vsan_dom_objects_json_stats->{$dom_objects_key}->{writeBytes},
											},
										};
										$graphite->send(path => "vsan.", data => $host_vsan_dom_objects_json_stats_h_snap);
									} else {
										my $host_vsan_dom_objects_json_stats_h = {
											time() => {
												"$vcenter_name.$datacentre_name.$cluster_name" . ".vsan.dom.owners.stats." . "$dom_objects_key.$VirtualDisks->{$dom_objects_key}" . ".readCount", $host_vsan_dom_objects_json_stats->{$dom_objects_key}->{readCount},
												"$vcenter_name.$datacentre_name.$cluster_name" . ".vsan.dom.owners.stats." . "$dom_objects_key.$VirtualDisks->{$dom_objects_key}" . ".writeCount", $host_vsan_dom_objects_json_stats->{$dom_objects_key}->{writeCount},
												"$vcenter_name.$datacentre_name.$cluster_name" . ".vsan.dom.owners.stats." . "$dom_objects_key.$VirtualDisks->{$dom_objects_key}" . ".readBytes", $host_vsan_dom_objects_json_stats->{$dom_objects_key}->{readBytes},
												"$vcenter_name.$datacentre_name.$cluster_name" . ".vsan.dom.owners.stats." . "$dom_objects_key.$VirtualDisks->{$dom_objects_key}" . ".writeBytes", $host_vsan_dom_objects_json_stats->{$dom_objects_key}->{writeBytes},
											},
										};
										$graphite->send(path => "vsan.", data => $host_vsan_dom_objects_json_stats_h);
									}
								}
							}

							# processing disks
							my $host_vsan_disks_json_stats = $host_vsan_query_vsan_stats_json->{'disks.stats'};

							foreach my $naa (keys %{ $host_vsan_disks_json_stats }) {
								my $host_vsan_disks_json_stats_latency = $host_vsan_disks_json_stats->{$naa}->{latency};
								
								my $host_vsan_disks_json_stats_latency_h = {
									time() => {
										"$vcenter_name.$datacentre_name.$cluster_name.esx.$host_name.vsan.disks.stats.$naa.totalTimeWrites", $host_vsan_disks_json_stats_latency->{totalTimeWrites},
										"$vcenter_name.$datacentre_name.$cluster_name.esx.$host_name.vsan.disks.stats.$naa.totalTimeReads", $host_vsan_disks_json_stats_latency->{totalTimeReads},
										"$vcenter_name.$datacentre_name.$cluster_name.esx.$host_name.vsan.disks.stats.$naa.queueTimeWrites", $host_vsan_disks_json_stats_latency->{queueTimeWrites},
										"$vcenter_name.$datacentre_name.$cluster_name.esx.$host_name.vsan.disks.stats.$naa.queueTimeReads", $host_vsan_disks_json_stats_latency->{queueTimeReads},
										"$vcenter_name.$datacentre_name.$cluster_name.esx.$host_name.vsan.disks.stats.$naa.readOps", $host_vsan_disks_json_stats->{$naa}->{readOps},
										"$vcenter_name.$datacentre_name.$cluster_name.esx.$host_name.vsan.disks.stats.$naa.writeOps", $host_vsan_disks_json_stats->{$naa}->{writeOps},
									},
								};
								$graphite->send(path => "vsan.", data => $host_vsan_disks_json_stats_latency_h);
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

$logger->info("[INFO] End processing vCenter $vcenterserver");

# disconnect from the server
# Util::disconnect();
