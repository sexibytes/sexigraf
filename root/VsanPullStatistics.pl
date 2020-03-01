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
use utf8;
use Unicode::Normalize;

use lib '/root';
use VsanapiUtils;
load_vsanmgmt_binding_files("/root/VIM25VsanmgmtStub.pm","/root/VIM25VsanmgmtRuntime.pm");

# $Data::Dumper::Indent = 1;
$Util::script_version = "0.9.200";
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
$logger->info("[DEBUG] VsanDisksPullStatistics v$Util::script_version");

VMware::VICredStore::init (filename => $credstorefile) or $logger->logdie ("[ERROR] Unable to initialize Credential Store.");
my @user_list = VMware::VICredStore::get_usernames (server => $vcenterserver);

# set graphite target
my $graphite = Net::Graphite->new(
	### except for host, these hopefully have reasonable defaults, so are optional
	host                  => '127.0.0.1',
	port                  => 2003,
	trace                 => 0,                ### if true, copy what's sent to STDERR
	proto                 => 'udp',            ### can be 'udp'
	timeout               => 1,                ### timeout of socket connect in seconds
	fire_and_forget       => 1,                ### if true, ignore sending errors
	return_connect_error  => 0,                ### if true, forward connect error to caller
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
if (scalar $PullProcess	> 1) {$logger->logdie ("[ERROR] VsanPullStatistics from $vcenterserver is already running!")}

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

my $service_content = Vim::get_service_content();
my $apiType = $service_content->about->apiType;

if ($apiType eq "VirtualCenter") {

	my $fullApiVersion = $service_content->about->apiVersion;
	my $majorApiVersion = (split /\./, $fullApiVersion)[0];
	$logger->info("[INFO] The Virtual Center $vcenterserver version is $fullApiVersion");
	my $vsan_cluster_space_report_system;
	if (int $majorApiVersion >= 6) {
		my %vc_mos = get_vsan_vc_mos();
		$vsan_cluster_space_report_system = $vc_mos{"vsan-cluster-space-report-system"};
	}

	my $all_xfolder;
	my %all_xfolders_parent_table;
	my %all_xfolders_type_table;
	my %all_xfolders_name_table;

	sub getRootDc {
		my ($child_object) = @_;
		if ($all_xfolders_parent_table{$child_object->{'parent'}->value}) {
			my $parent_folder = $child_object->{'parent'}->value;

			while ($all_xfolders_type_table{$all_xfolders_parent_table{$parent_folder}} ne "Datacenter") {
				if ($all_xfolders_type_table{$all_xfolders_parent_table{$parent_folder}}) {
					$parent_folder = $all_xfolders_parent_table{$parent_folder};
				}
			}

			return $all_xfolders_name_table{$all_xfolders_parent_table{$parent_folder}};
		}
	}

	$logger->info("[INFO] Processing vCenter $vcenterserver objects");

	## retreive viobjets and build moref-objects tables

	my $all_folder_views = Vim::find_entity_views(view_type => 'Folder', properties => ['name', 'parent']);
	my %all_folder_views_table = ();
	foreach my $all_folder_view (@$all_folder_views) {
		$all_folder_views_table{$all_folder_view->{'mo_ref'}->value} = $all_folder_view;
	}

	my $all_datacentres_views = Vim::find_entity_views(view_type => 'Datacenter', properties => ['name', 'parent']);

	my $all_cluster_root_pool_views = Vim::find_entity_views(view_type => 'ResourcePool', filter => {name => qr/^Resources$/}, properties => ['vm','parent']);

	my %all_cluster_root_pool_views_table = ();
	foreach my $all_cluster_root_pool_view (@$all_cluster_root_pool_views) {
		$all_cluster_root_pool_views_table{$all_cluster_root_pool_view->{'mo_ref'}->value} = $all_cluster_root_pool_view;
	}

	my $all_cluster_views;
	my $all_compute_views;
	my $all_compute_res_views = Vim::find_entity_views(view_type => 'ComputeResource', properties => ['resourcePool','name', 'parent', 'host']);
	foreach my $all_compute_res_view (@$all_compute_res_views) {
		if ($all_compute_res_view->{'mo_ref'}->type eq "ClusterComputeResource") {
			push (@$all_cluster_views,$all_compute_res_view);
		} elsif ($all_compute_res_view->{'mo_ref'}->type eq "ComputeResource") {
			push (@$all_compute_views,$all_compute_res_view);
		}
	}

	my %all_cluster_views_table = ();
	foreach my $all_cluster_view (@$all_cluster_views) {
		$all_cluster_views_table{$all_cluster_view->{'mo_ref'}->value} = $all_cluster_view;
	}

	my %all_compute_views_table = ();
	foreach my $all_compute_view (@$all_compute_views) {
		$all_compute_views_table{$all_compute_view->{'mo_ref'}->value} = $all_compute_view;
	}

	my $all_host_views = Vim::find_entity_views(view_type => 'HostSystem', properties => ['parent','config.product.apiVersion','config.vsanHostConfig.clusterInfo.uuid','config.network.dnsConfig.hostName','configManager.vsanInternalSystem','runtime.connectionState','runtime.inMaintenanceMode','config.optionDef'] , filter => {'config.vsanHostConfig.clusterInfo.uuid' => qr/-/});
	my %all_host_views_table = ();
	my %all_host_vsan_views_table = ();
	foreach my $all_host_view (@$all_host_views) {
		$all_host_views_table{$all_host_view->{'mo_ref'}->value} = $all_host_view;
		$all_host_vsan_views_table{$all_host_view->{'configManager.vsanInternalSystem'}->value} = $all_host_view->{'mo_ref'}->value;
	}

	my $all_vm_views = Vim::find_entity_views(view_type => 'VirtualMachine', properties => ['config.hardware.device','runtime.host'], filter => {'summary.runtime.connectionState' => "connected"});
	my %all_vm_views_table = ();
	foreach my $all_vm_view (@$all_vm_views) {
		$all_vm_views_table{$all_vm_view->{'mo_ref'}->value} = $all_vm_view;
	}


	### create parents,types,names hashtables to get root datacenter when needed with getRootDc function

	if ($all_datacentres_views and $all_cluster_views and $all_compute_views and $all_host_views and $all_folder_views) {
		foreach my $all_xfolder (@$all_datacentres_views, @$all_cluster_views, @$all_compute_views, @$all_host_views, @$all_folder_views) {
			if ($all_xfolder->{'parent'}) { ### skip folder-group-d1
				if (!$all_xfolders_parent_table{$all_xfolder->{'mo_ref'}->value}) {$all_xfolders_parent_table{$all_xfolder->{'mo_ref'}->value} = $all_xfolder->{'parent'}->value}
				if (!$all_xfolders_type_table{$all_xfolder->{'mo_ref'}->value}) {$all_xfolders_type_table{$all_xfolder->{'mo_ref'}->value} = $all_xfolder->{'mo_ref'}->type}
				if (!$all_xfolders_name_table{$all_xfolder->{'mo_ref'}->value}) {$all_xfolders_name_table{$all_xfolder->{'mo_ref'}->value} = $all_xfolder->name}
			}
		}
	}

	my @cluster_hosts_vms_moref;
	my $configManagerVsanInternalSystemView;
	my %hosts_vsan_views_table;

	foreach my $cluster_view (@$all_cluster_views) {
		my $cluster_name = lc ($cluster_view->name);
		$cluster_name =~ s/[ .]/_/g;
		$cluster_name = NFD($cluster_name);
		$cluster_name =~ s/[^[:ascii:]]//g;
		$cluster_name =~ s/[^A-Za-z0-9-_]/_/g;

		my $datacentre_name = lc (getRootDc $cluster_view);
		$datacentre_name =~ s/[ .]/_/g;
		$datacentre_name = NFD($datacentre_name);
		$datacentre_name =~ s/[^[:ascii:]]//g;
		$datacentre_name =~ s/[^A-Za-z0-9-_]/_/g;

		%hosts_vsan_views_table = ();

		if(scalar $cluster_view->host > 1) {

			my @cluster_hosts_views;
			my $cluster_hosts_moref = $cluster_view->host;
			foreach my $cluster_host_moref (@$cluster_hosts_moref) {
				if ($all_host_views_table{$cluster_host_moref->{'value'}}) {
					push (@cluster_hosts_views,$all_host_views_table{$cluster_host_moref->{'value'}});
					push (@$configManagerVsanInternalSystemView,$all_host_views_table{$cluster_host_moref->{'value'}}->{'configManager.vsanInternalSystem'});
				}
			}

			my $hosts_vsan_views = Vim::get_views(mo_ref_array => $configManagerVsanInternalSystemView);

			foreach my $hosts_vsan_view (@$hosts_vsan_views) {
				$hosts_vsan_views_table{$all_host_vsan_views_table{$hosts_vsan_view->{'mo_ref'}->value}} = $hosts_vsan_view;
			}

			if ($cluster_hosts_views[0]) {

				$logger->info("[INFO] Processing vCenter $vcenterserver cluster $cluster_name hosts in datacenter $datacentre_name");

				my $vsan_cluster_uuid = $cluster_hosts_views[0]->{'config.vsanHostConfig.clusterInfo.uuid'};
				$logger->info("[INFO] Processing vCenter $vcenterserver VSAN cluster $cluster_name $vsan_cluster_uuid");

				my $advSupportedOptions = $cluster_hosts_views[0]->{'config.optionDef'};
				my $VsanSpaceUsageReport;

				foreach my $advSupportedOption (@$advSupportedOptions) {
					if ($advSupportedOption->key eq "VSAN.DedupScope") {
						if ($vsan_cluster_space_report_system) {
							eval { $VsanSpaceUsageReport = $vsan_cluster_space_report_system->VsanQuerySpaceUsage(cluster => $cluster_view) };
							if (!$@ and $VsanSpaceUsageReport) {
								$logger->info("[INFO] Processing spaceUsageByObjectType in VSAN cluster $cluster_name (v6.2+)");
								my $VsanSpaceUsageReportObjList	= $VsanSpaceUsageReport->{'spaceDetail'}->{'spaceUsageByObjectType'};
								foreach my $vsanObjType (@$VsanSpaceUsageReportObjList) {
									my $VsanSpaceUsageReportObjType = $vsanObjType->{objType};
									my $VsanSpaceUsageReportObjType_h = {
										time() => {
											"$vcenter_name.$datacentre_name.$cluster_name.vsan.spaceDetail.spaceUsageByObjectType.$VsanSpaceUsageReportObjType.overheadB", $vsanObjType->overheadB,
											"$vcenter_name.$datacentre_name.$cluster_name.vsan.spaceDetail.spaceUsageByObjectType.$VsanSpaceUsageReportObjType.physicalUsedB", $vsanObjType->physicalUsedB,
											"$vcenter_name.$datacentre_name.$cluster_name.vsan.spaceDetail.spaceUsageByObjectType.$VsanSpaceUsageReportObjType.overReservedB", $vsanObjType->{'overReservedB'},
											"$vcenter_name.$datacentre_name.$cluster_name.vsan.spaceDetail.spaceUsageByObjectType.$VsanSpaceUsageReportObjType.usedB", $vsanObjType->usedB,
											"$vcenter_name.$datacentre_name.$cluster_name.vsan.spaceDetail.spaceUsageByObjectType.$VsanSpaceUsageReportObjType.temporaryOverheadB", $vsanObjType->temporaryOverheadB,
											"$vcenter_name.$datacentre_name.$cluster_name.vsan.spaceDetail.spaceUsageByObjectType.$VsanSpaceUsageReportObjType.primaryCapacityB", $vsanObjType->primaryCapacityB,
											"$vcenter_name.$datacentre_name.$cluster_name.vsan.spaceDetail.spaceUsageByObjectType.$VsanSpaceUsageReportObjType.reservedCapacityB", $vsanObjType->reservedCapacityB,
										},
									};
									$graphite->send(path => "vsan", data => $VsanSpaceUsageReportObjType_h);
								}
							}
						}
					}
				}

				my $cluster_view_root_pool = $all_cluster_root_pool_views_table{$cluster_view->{'resourcePool'}->value};
				my $cluster_host_view_vms  = $cluster_view_root_pool->vm;
				foreach my $cluster_host_view_vm (@$cluster_host_view_vms) {
					push (@cluster_hosts_vms_moref,$cluster_host_view_vm);
				}

				my @cluster_vms_views;
				if (scalar(@cluster_hosts_vms_moref) > 0) {
					foreach my $cluster_vm_moref (@cluster_hosts_vms_moref) {
						if ($all_vm_views_table{$cluster_vm_moref->{'value'}}) {
							push (@cluster_vms_views,$all_vm_views_table{$cluster_vm_moref->{'value'}});
						}
					}
				}

				my $VirtualDisks = {};

				foreach my $vm_view_device (@cluster_vms_views) {
					my $vmDevices = $vm_view_device->{'config.hardware.device'};

					foreach(@$vmDevices) {
						if($_->isa('VirtualDisk') && $_->backing->backingObjectId) {
							my @vmdkpath = split("/", $_->backing->fileName);
							my $vmdk = substr($vmdkpath[-1], 0, -5);
							$vmdk =~ s/[ .()?!+]/_/g;
							$vmdk = NFD($vmdk);
							$vmdk =~ s/[^[:ascii:]]//g;
							$vmdk =~ s/[^A-Za-z0-9-_]/_/g;
							$VirtualDisks->{ $_->backing->backingObjectId } = $vmdk;

							if ($_->backing->parent) {
								my $rootparent = getParent($_->backing->parent);
								my @rootvmdkpath = split("/", $rootparent->fileName);
								my $rootvmdk = substr($rootvmdkpath[-1], 0, -5);
								$rootvmdk =~ s/[ .()?!+]/_/g;
								$rootvmdk = NFD($rootvmdk);
								$rootvmdk =~ s/[^[:ascii:]]//g;
								$rootvmdk =~ s/[^A-Za-z0-9-_]/_/g;
								$VirtualDisks->{ $_->backing->backingObjectId . "_root"} = $rootparent->backingObjectId;
								$VirtualDisks->{ $rootparent->backingObjectId} = $rootvmdk;
							}
						}
					}
				}

				my $host_vsan_physical_disks_json;

				foreach (shuffle @cluster_hosts_views) {

					if ($_->{'runtime.connectionState'}->val eq "connected" && $_->{'runtime.inMaintenanceMode'} eq "false") {
						my $VsanSystemEx;
						my $VsanHostVsanObjectSyncQueryResult;
						my $host_api = $_->{'config.product.apiVersion'};
						(my $major_host_api) = $host_api =~ m/(^\d\.\d)*/;

						my $shuffle_host_vsan_view = $hosts_vsan_views_table{$_->{'mo_ref'}->value};
						my $host_vsan_physical_disks = $shuffle_host_vsan_view->QueryPhysicalVsanDisks();
						$host_vsan_physical_disks_json = from_json($host_vsan_physical_disks);

						if ($major_host_api >= 6.7) {
							my $VsanSystemExSync = {};
							my $VsanHostVsanObjectSyncQueryResultObjs;
							my $VsanHostVsanObjectSyncQueryResultUuids = 0;
							$logger->info("[INFO] Processing SyncingVsanObjects of VSAN cluster $cluster_name (v6.7+)");
							my @morefval = split /[-]/, $_->{'mo_ref'}->{'value'};
							my $esx_moid = $morefval[1];
							my %esx_mos_ex = get_vsan_esx_mos_ex($esx_moid);
							my $VsanSystemEx = $esx_mos_ex{"vsanSystemEx"};
							#https://code.vmware.com/apis/398/vsan#/doc/vim.vsan.host.VsanComponentSyncState.html
							eval { $VsanHostVsanObjectSyncQueryResult = $VsanSystemEx->VsanQuerySyncingVsanObjects(includeSummary => 1)->objects };
							if (!$@ and $VsanHostVsanObjectSyncQueryResult) {
								my $VsanHostVsanObjectSyncQueryResult = $VsanSystemEx->VsanQuerySyncingVsanObjects(includeSummary => 1);
								$VsanHostVsanObjectSyncQueryResultObjs = $VsanHostVsanObjectSyncQueryResult->objects;
								my $VsanHostVsanObjectSyncQueryResultEta = $VsanHostVsanObjectSyncQueryResult->totalRecoveryETA;
								my $VsanHostVsanObjectSyncQueryResultBytes = $VsanHostVsanObjectSyncQueryResult->totalBytesToSync;
								my $VsanHostVsanObjectSyncQueryResultObj = $VsanHostVsanObjectSyncQueryResult->totalObjectsToSync;
								foreach my $VsanSystemExSyncComponents (@$VsanHostVsanObjectSyncQueryResultObjs) {
									foreach my $VsanSystemExSyncComponentsUuid ($VsanSystemExSyncComponents->components) {
										foreach my $VsanSystemExSyncComponentsDiskUuid (@$VsanSystemExSyncComponentsUuid) {
											my $VsanSystemExSyncComponentsBytesToSync = $VsanSystemExSyncComponentsDiskUuid->{bytesToSync};
											my $VsanSystemExSyncComponentsReasons = $VsanSystemExSyncComponentsDiskUuid->{reasons};
											my $VsanSystemExSyncComponentsReason = join('-', @$VsanSystemExSyncComponentsReasons);
											$VsanSystemExSync->{$VsanSystemExSyncComponentsReason} += $VsanSystemExSyncComponentsBytesToSync;
											$VsanHostVsanObjectSyncQueryResultUuids++;
										}
									}
								}
								foreach my $VsanSystemExSyncReason (keys %{$VsanSystemExSync}) {
									$graphite->send(
										path => "vsan." . "$vcenter_name.$datacentre_name.$cluster_name.vsan.SyncingVsanObjects.bytesToSync." . "$VsanSystemExSyncReason",
										value => $VsanSystemExSync->{$VsanSystemExSyncReason},
										time => time(),
									);
								}

								my $VsanSystemExSync_h = {
									time() => {
										"$vcenter_name.$datacentre_name.$cluster_name.vsan.SyncingVsanObjects.totalRecoveryETA", $VsanHostVsanObjectSyncQueryResultEta,
										"$vcenter_name.$datacentre_name.$cluster_name.vsan.SyncingVsanObjects.totalBytesToSync", $VsanHostVsanObjectSyncQueryResultBytes,
										"$vcenter_name.$datacentre_name.$cluster_name.vsan.SyncingVsanObjects.totalObjectsToSync", $VsanHostVsanObjectSyncQueryResultObj,
										"$vcenter_name.$datacentre_name.$cluster_name.vsan.SyncingVsanObjects.totalComponentsToSync", $VsanHostVsanObjectSyncQueryResultUuids,
									},
								};
								$graphite->send(path => "vsan", data => $VsanSystemExSync_h);
							}

						} else {

							my $host_vsan_syncing_objects = $shuffle_host_vsan_view->QuerySyncingVsanObjects();
							my $host_vsan_syncing_objects_json = from_json($host_vsan_syncing_objects);
							my $host_vsan_syncing_objects_json_domobjs = $host_vsan_syncing_objects_json->{dom_objects};

							if ($host_vsan_syncing_objects_json_domobjs) {

								$logger->info("[INFO] Processing resync objects of VSAN cluster $cluster_name");

								my $vsan_bytesToSync = 0;
								my $vsan_recoveryETA = 0;
								my $vsan_sync_objs = 0;
								my $vsan_recoveryETAmid = 0;

								foreach my $uuid (keys %$host_vsan_syncing_objects_json_domobjs) {
									my $return = {};
									getObj($host_vsan_syncing_objects_json_domobjs->{$uuid}->{'config'}->{'content'}, $fields, $return);
									$vsan_bytesToSync += sum(@{$return->{bytesToSync}});
									$vsan_recoveryETA += sum(@{$return->{recoveryETA}});
									$vsan_sync_objs += @{$return->{bytesToSync}};
								}

								if ($vsan_sync_objs >= 1) {
									$vsan_recoveryETAmid = $vsan_recoveryETA / $vsan_sync_objs;
								}

								my $vsan_syncing_objects_attributes_h = {
									time() => {
										"$vcenter_name.$datacentre_name.$cluster_name.vsan.SyncingVsanObjects.totalRecoveryETA", $vsan_recoveryETAmid,
										"$vcenter_name.$datacentre_name.$cluster_name.vsan.SyncingVsanObjects.totalBytesToSync", $vsan_bytesToSync,
										"$vcenter_name.$datacentre_name.$cluster_name.vsan.SyncingVsanObjects.totalObjectsToSync", $vsan_sync_objs,
									},
								};
								$graphite->send(path => "vsan", data => $vsan_syncing_objects_attributes_h);
							}
						}
					}
					last;
				}

				foreach my $host_view (@cluster_hosts_views) {

					if ($host_view->{'runtime.connectionState'}->val eq "connected" && $host_view->{'runtime.inMaintenanceMode'} eq "false") {

						my $host_vsan_view = $hosts_vsan_views_table{$host_view->{'mo_ref'}->value};
						my $host_vsan_query_vsan_stats = $host_vsan_view->QueryVsanStatistics(labels => ['dom', 'lsom', 'dom-objects', 'disks']);
						my $host_vsan_query_vsan_stats_json = from_json($host_vsan_query_vsan_stats);
						my $host_name = lc ($host_view->{'config.network.dnsConfig.hostName'});

						$logger->info("[INFO] Processing $host_name in VSAN cluster $cluster_name");

						if ($host_vsan_query_vsan_stats_json) {

							# processing dom
							my $host_vsan_stats_json_compmgr = $host_vsan_query_vsan_stats_json->{'dom.compmgr.stats'};
							my $host_vsan_stats_json_client = $host_vsan_query_vsan_stats_json->{'dom.client.stats'};
							my $host_vsan_stats_json_owner = $host_vsan_query_vsan_stats_json->{'dom.owner.stats'};
							my $host_vsan_stats_json_sched = $host_vsan_query_vsan_stats_json->{'dom.compmgr.schedStats'};
							my $host_vsan_stats_json_cachestats = $host_vsan_query_vsan_stats_json->{'dom.client.cachestats'};

							foreach my $compmgrkey (keys %{ $host_vsan_stats_json_compmgr }) {
								if (!$compmgrkey =~ /Histogram/) {
									$graphite->send(
										path => "vsan." . "$vcenter_name.$datacentre_name.$cluster_name.esx.$host_name" . ".vsan.compmgr.stats." . "$compmgrkey",
										value => $host_vsan_stats_json_compmgr->{$compmgrkey},
										time => time(),
									);
								}
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

							foreach my $cachestats (keys %{ $host_vsan_stats_json_cachestats }) {
								$graphite->send(
									path => "vsan." . "$vcenter_name.$datacentre_name.$cluster_name.esx.$host_name" . ".vsan.client.cachestats." . "$cachestats",
									value => $host_vsan_stats_json_cachestats->{$cachestats},
									time => time(),
								);
							}

							# processing lsom
							my $host_vsan_lsom_json_disks = $host_vsan_query_vsan_stats_json->{'lsom.disks'};

							foreach my $lsomkey (keys %{ $host_vsan_lsom_json_disks }) {
								if ($host_vsan_lsom_json_disks->{$lsomkey}->{info}->{ssd} ne "NA" && $host_vsan_lsom_json_disks->{$lsomkey}->{info}->{capacity}) {
									my $lsomkeyCapacityUsed = $host_vsan_lsom_json_disks->{$lsomkey}->{info}->{capacityUsed};
									my $lsomkeyCapacity = $host_vsan_lsom_json_disks->{$lsomkey}->{info}->{capacity};
									my $lsomkeyCapacityUsedPercent = $lsomkeyCapacityUsed * 100 / $lsomkeyCapacity;
									my $lsomkeySsdUuid = $host_vsan_lsom_json_disks->{$lsomkey}->{info}->{ssd};
									my $vsan_cache_ssd_naa = $host_vsan_physical_disks_json->{$lsomkeySsdUuid}->{devName};
										if ($vsan_cache_ssd_naa) {
											my @vsan_cache_ssd_clean_naa = split /[.:]/, $vsan_cache_ssd_naa;
											my $host_vsan_lsom_json_disks_h = {
												time() => {
													"$vcenter_name.$datacentre_name.$cluster_name.esx.$host_name" . ".vsan.lsom.disks." . "$lsomkey" . ".capacityUsed", $lsomkeyCapacityUsed,
													"$vcenter_name.$datacentre_name.$cluster_name.esx.$host_name" . ".vsan.lsom.disks." . "$lsomkey" . ".capacity", $lsomkeyCapacity,
													"$vcenter_name.$datacentre_name.$cluster_name.esx.$host_name" . ".vsan.lsom.disks." . "$lsomkey" . ".percentUsed", $lsomkeyCapacityUsedPercent,
													"$vcenter_name.$datacentre_name.$cluster_name.esx.$host_name" . ".vsan.lsom.diskgroup." . "$vsan_cache_ssd_clean_naa[1]" . "." . "$lsomkey" . ".percentUsed", $lsomkeyCapacityUsedPercent,
												},
											};
											$graphite->send(path => "vsan", data => $host_vsan_lsom_json_disks_h);
										}
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
									$graphite->send(path => "vsan", data => $host_vsan_lsom_json_ssd_h);
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
										$graphite->send(path => "vsan", data => $host_vsan_dom_objects_json_stats_h_snap);
									} else {
										my $host_vsan_dom_objects_json_stats_h = {
											time() => {
												"$vcenter_name.$datacentre_name.$cluster_name" . ".vsan.dom.owners.stats." . "$dom_objects_key.$VirtualDisks->{$dom_objects_key}" . ".readCount", $host_vsan_dom_objects_json_stats->{$dom_objects_key}->{readCount},
												"$vcenter_name.$datacentre_name.$cluster_name" . ".vsan.dom.owners.stats." . "$dom_objects_key.$VirtualDisks->{$dom_objects_key}" . ".writeCount", $host_vsan_dom_objects_json_stats->{$dom_objects_key}->{writeCount},
												"$vcenter_name.$datacentre_name.$cluster_name" . ".vsan.dom.owners.stats." . "$dom_objects_key.$VirtualDisks->{$dom_objects_key}" . ".readBytes", $host_vsan_dom_objects_json_stats->{$dom_objects_key}->{readBytes},
												"$vcenter_name.$datacentre_name.$cluster_name" . ".vsan.dom.owners.stats." . "$dom_objects_key.$VirtualDisks->{$dom_objects_key}" . ".writeBytes", $host_vsan_dom_objects_json_stats->{$dom_objects_key}->{writeBytes},
											},
										};
										$graphite->send(path => "vsan", data => $host_vsan_dom_objects_json_stats_h);
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
								$graphite->send(path => "vsan", data => $host_vsan_disks_json_stats_latency_h);
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
} else {
	$logger->info("[ERROR] $vcenterserver is not a vcenter!!!");
}