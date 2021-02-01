#!/usr/bin/perl -w
#

use strict;
use warnings;
use VMware::VIRuntime;
use VMware::VICredStore;
use JSON;
use Data::Dumper;
use Scalar::Util qw(reftype);
use Net::Graphite;
use List::Util qw[shuffle max sum];
use Log::Log4perl qw(:easy);
use utf8;
use Unicode::Normalize;
use Time::Piece;
use Time::Seconds;
# use Sys::SigAction qw( timeout_call );

$Data::Dumper::Indent = 1;
$Util::script_version = "0.9.916";
$ENV{'PERL_LWP_SSL_VERIFY_HOSTNAME'} = 0;

my $BFG_MODE = 0;
if (defined ($ARGV[6]) &&  ($ARGV[6] eq "BFG_MODE")) {$BFG_MODE = 1};

Opts::parse();
Opts::validate();

my $url = Opts::get_option('url');
my $vmware_server = Opts::get_option('server');
my $username = Opts::get_option('username');
my $password = Opts::get_option('password');
my $sessionfile = Opts::get_option('sessionfile');
my $credstorefile = Opts::get_option('credstore');

my $exec_start = time;

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

my $logger = Log::Log4perl->get_logger('sexigraf.ViPullStatistics');
$logger->info("[DEBUG] ViPullStatistics v$Util::script_version for $vmware_server");

VMware::VICredStore::init (filename => $credstorefile) or $logger->logdie ("[ERROR] Unable to initialize Credential Store for $vmware_server");
my @user_list = VMware::VICredStore::get_usernames (server => $vmware_server);

### set graphite target
my $graphite = Net::Graphite->new(
	### except for host, these hopefully have reasonable defaults, so are optional
	host                  => '127.0.0.1',
	port                  => 2003,
	trace                 => 0,                ### if true, copy what's sent to STDERR
	proto                 => 'tcp',            ### can be 'udp'
	timeout               => 1,                ### timeout of socket connect in seconds
	fire_and_forget       => 1,                ### if true, ignore sending errors
	return_connect_error  => 0,                ### if true, forward connect error to caller
	flush_limit           => 0,                ### if true, send after this many metrics are ready
);

$logger->info("[INFO] Start processing $vmware_server");

### handling multiple run
$0 = "ViPullStatistics from $vmware_server";
my $PullProcess = 0;
foreach my $file (glob("/proc/[0-9]*/cmdline")) {
	open FILE, "<$file";
	if (grep(/^ViPullStatistics from $vmware_server/, <FILE>) ) {
		$PullProcess++;
	}
	close FILE;
}
if (scalar($PullProcess) > 1) {$logger->logdie ("[ERROR] ViPullStatistics from $vmware_server is already running!")}


### handling sessionfile if missing or expired
if (scalar(@user_list) == 0) {
	$logger->logdie ("[ERROR] No credential store user detected for $vmware_server");
} elsif (scalar(@user_list) > 1) {
	$logger->logdie ("[ERROR] Multiple credential store user detected for $vmware_server");
} else {
	foreach my $username (@user_list) {
		$logger->info("[INFO] Login to $vmware_server");
		$password = VMware::VICredStore::get_password (server => $vmware_server, username => $username);
		$url = "https://" . $vmware_server . "/sdk";
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
			$logger->info("[INFO] $vmware_server session file saved");
		}
	}
}

my $service_content = Vim::get_service_content();
my $service_instance = Vim::get_service_instance();
my $vmware_server_clock = (split /\./, $service_instance->CurrentTime())[0];
$vmware_server_clock = Time::Piece->strptime($vmware_server_clock,'%Y-%m-%dT%H:%M:%S');

my $vmware_server_clock_5 = $vmware_server_clock;
foreach my $i (0..4) {
	$vmware_server_clock_5 -= ONE_MINUTE;
}

my $apiType = $service_content->about->apiType;

my $perfMgr = (Vim::get_view(mo_ref => $service_content->perfManager, properties => ['perfCounter']));
my %perfCntr = map { $_->groupInfo->key . "." . $_->nameInfo->key . "." . $_->rollupType->val => $_ } @{$perfMgr->perfCounter};

sub MultiQueryPerfAll {
	my ($query_entity_views, @query_perfCntrs) = @_;

	my $perfKey;
	my @perfKeys = ();
	for my $row ( 0..$#query_perfCntrs ) {
		my $perfKey = $perfCntr{"$query_perfCntrs[$row][0].$query_perfCntrs[$row][1].$query_perfCntrs[$row][2]"}->key;
		push @perfKeys,$perfKey;
	}

	my $metricId;
	my @metricIDs = ();
	foreach (@perfKeys) {
		$metricId = PerfMetricId->new(counterId => $_, instance => '*');
		push @metricIDs,$metricId;
	}

	my $perfQuerySpec;
	my @perfQuerySpecs = ();
	foreach (@$query_entity_views) {
		$perfQuerySpec = PerfQuerySpec->new(entity => $_, maxSample => 15, intervalId => 20, metricId => \@metricIDs);
		push @perfQuerySpecs,$perfQuerySpec;
	}

	my $metrics = $perfMgr->QueryPerf(querySpec => [@perfQuerySpecs]);
	### https://kb.vmware.com/s/article/2107096

	my %fatmetrics = ();
	foreach(@$metrics) {
		my $VmMoref = $_->entity->value;
		my $perfValues = $_->value;
		my $perfavg;
		foreach(@$perfValues) {
			my $perfinstance = $_->id->instance;
			my $perfcountid = $_->id->counterId;
			my $values = $_->value;
			if (scalar @$values > 0) {
				$perfavg = median(@$values);
				$fatmetrics{$perfcountid}{$VmMoref}{$perfinstance} = $perfavg;
			}
		}
	}
	return %fatmetrics;
}

sub MultiQueryPerf {
	my ($query_entity_views, @query_perfCntrs) = @_;

	my $perfKey;
	my @perfKeys = ();
	for my $row ( 0..$#query_perfCntrs ) {
		my $perfKey = $perfCntr{"$query_perfCntrs[$row][0].$query_perfCntrs[$row][1].$query_perfCntrs[$row][2]"}->key;
		push @perfKeys,$perfKey;
	}

	my $metricId;
	my @metricIDs = ();
	foreach (@perfKeys) {
		$metricId = PerfMetricId->new(counterId => $_, instance => '');
		push @metricIDs,$metricId;
	}

	my $perfQuerySpec;
	my @perfQuerySpecs = ();
	foreach (@$query_entity_views) {
		$perfQuerySpec = PerfQuerySpec->new(entity => $_, maxSample => 15, intervalId => 20, metricId => \@metricIDs);
		push @perfQuerySpecs,$perfQuerySpec;
	}

	my $metrics = $perfMgr->QueryPerf(querySpec => [@perfQuerySpecs]);
	### https://kb.vmware.com/s/article/2107096

	my %fatmetrics = ();
	foreach(@$metrics) {
		my $VmMoref = $_->entity->value;
		my $perfValues = $_->value;
		my $perfavg;
		foreach(@$perfValues) {
			my $perfinstance = $_->id->instance;
			my $perfcountid = $_->id->counterId;
			my $values = $_->value;
			if (scalar @$values > 0) {
				$perfavg = median(@$values);
				$fatmetrics{$perfcountid}{$VmMoref}{$perfinstance} = $perfavg;
			}
		}
	}
	return %fatmetrics;
}

sub MultiQueryPerf300 {
	my ($query_entity_views, @query_perfCntrs) = @_;

	my $perfKey;
	my @perfKeys = ();
	for my $row ( 0..$#query_perfCntrs ) {
		my $perfKey = $perfCntr{"$query_perfCntrs[$row][0].$query_perfCntrs[$row][1].$query_perfCntrs[$row][2]"}->key;
		push @perfKeys,$perfKey;
	}

	my $metricId;
	my @metricIDs = ();
	foreach (@perfKeys) {
		$metricId = PerfMetricId->new(counterId => $_, instance => '');
		push @metricIDs,$metricId;
	}

	my $perfQuerySpec;
	my @perfQuerySpecs = ();
	foreach (@$query_entity_views) {
		$perfQuerySpec = PerfQuerySpec->new(entity => $_, intervalId => 300, metricId => \@metricIDs, startTime => $vmware_server_clock_5->datetime);
		push @perfQuerySpecs,$perfQuerySpec;
	}

	my $metrics = $perfMgr->QueryPerf(querySpec => [@perfQuerySpecs]);
	### https://kb.vmware.com/s/article/2107096

	my %fatmetrics = ();
	foreach(@$metrics) {
		my $VmMoref = $_->entity->value;
		my $perfValues = $_->value;
		my $perfavg;
		foreach(@$perfValues) {
			my $perfinstance = $_->id->instance;
			my $perfcountid = $_->id->counterId;
			my $values = $_->value;
			if (scalar @$values > 0) {
				$perfavg = max(@$values);
				$fatmetrics{$perfcountid}{$VmMoref}{$perfinstance} = $perfavg;
			}
		}
	}
	return %fatmetrics;
}

my @cluster_vm_view_snap_tree = ();
sub getSnapshotTreeRaw {
	my ($tree) = @_;
	foreach my $node (@$tree) {
		push (@cluster_vm_view_snap_tree, $node);
		if ($node->childSnapshotList) {
			getSnapshotTreeRaw($node->childSnapshotList);
		}
	}
	return;
}

my $all_xfolder = ();
my %all_xfolders_parent_table = ();
my %all_xfolders_type_table = ();
my %all_xfolders_name_table = ();

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

sub median {
    my @vals = sort {$a <=> $b} @_;
    my $len = @vals;
    if($len%2)
    {
        return $vals[int($len/2)];
    }
    else
    {
        return ($vals[int($len/2)-1] + $vals[int($len/2)])/2;
    }
}

sub nameCleaner {
	my ($nameToClean) = @_;
	my $nameCleaned = lc $nameToClean;
	$nameCleaned =~ s/[ .()]/_/g;
	$nameCleaned = NFD($nameCleaned);
	$nameCleaned =~ s/[^[:ascii:]]//g;
	$nameCleaned =~ s/[^A-Za-z0-9-_]/_/g;

	return $nameCleaned
}

if ($apiType eq "VirtualCenter") {

	### retreive vcenter hostname
	my $vcenter_fqdn = $vmware_server;

	$vcenter_fqdn =~ s/[ .]/_/g;
	my $vmware_server_name = lc ($vcenter_fqdn);
		
	$logger->info("[INFO] Processing vCenter $vmware_server objects");
	if ($BFG_MODE) {$logger->info("[DEBUG] BFG Mode activated for vCenter $vmware_server");}

	### retreive viobjets and build moref-objects tables

	my $all_folder_views = Vim::find_entity_views(view_type => 'Folder', properties => ['name', 'parent']);
	my %all_folder_views_table = ();
	# my $FolderGroupD1 = ();
	foreach my $all_folder_view (@$all_folder_views) {
		$all_folder_views_table{$all_folder_view->{'mo_ref'}->value} = $all_folder_view;
		# if ($all_folder_view->{'mo_ref'}->value eq "group-d1") {
		# 	push (@$FolderGroupD1,$all_folder_view);
		# }
	}

	my $all_datacentres_views = Vim::find_entity_views(view_type => 'Datacenter', properties => ['name', 'parent']);

	my $all_cluster_root_pool_views = Vim::find_entity_views(view_type => 'ResourcePool', filter => {name => qr/^Resources$/}, properties => ['summary.quickStats', 'parent']);

	my %all_cluster_root_pool_views_table = ();
	foreach my $all_cluster_root_pool_view (@$all_cluster_root_pool_views) {
		$all_cluster_root_pool_views_table{$all_cluster_root_pool_view->{'parent'}->value} = $all_cluster_root_pool_view;
		# $all_cluster_root_pool_views_table{$all_cluster_root_pool_view->{'mo_ref'}->value} = $all_cluster_root_pool_view;
	}

	my $all_cluster_views = ();
	my $all_compute_views = ();
	my $all_compute_res_views = Vim::find_entity_views(view_type => 'ComputeResource', properties => ['name', 'parent', 'summary', 'resourcePool', 'host', 'datastore']); ### can't filter summary more because of numVmotions properties
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

	my $all_host_views = Vim::find_entity_views(view_type => 'HostSystem', properties => ['config.network.pnic', 'config.network.vnic', 'config.network.dnsConfig.hostName', 'runtime.connectionState', 'summary.hardware.numCpuCores', 'summary.quickStats.distributedCpuFairness', 'summary.quickStats.distributedMemoryFairness', 'summary.quickStats.overallCpuUsage', 'summary.quickStats.overallMemoryUsage', 'summary.quickStats.uptime', 'overallStatus', 'config.storageDevice.hostBusAdapter', 'vm', 'name', 'summary.runtime.healthSystemRuntime.systemHealthInfo.numericSensorInfo', 'config.product.version',  'config.product.build'], filter => {'runtime.connectionState' => "connected"});
	my %all_host_views_table = ();
	foreach my $all_host_view (@$all_host_views) {
		$all_host_views_table{$all_host_view->{'mo_ref'}->value} = $all_host_view;
	}

	my $all_datastore_views = Vim::find_entity_views(view_type => 'Datastore', properties => ['summary', 'iormConfiguration.enabled', 'iormConfiguration.statsCollectionEnabled', 'host'], filter => {'summary.multipleHostAccess' => "true", 'summary.accessible' => "true"});
	my %all_datastore_views_table = ();
	foreach my $all_datastore_view (@$all_datastore_views) {
		$all_datastore_views_table{$all_datastore_view->{'mo_ref'}->value} = $all_datastore_view;
	}

	my $all_pod_views = Vim::find_entity_views(view_type => 'StoragePod', properties => ['name','summary','parent','childEntity']);
	my %all_pod_views_table = ();
	foreach my $all_pod_view (@$all_pod_views) {
		$all_pod_views_table{$all_pod_view->{'mo_ref'}->value} = $all_pod_view;
	}

	my $all_vm_views = Vim::find_entity_views(view_type => 'VirtualMachine', properties => ['name', 'runtime.maxCpuUsage', 'runtime.maxMemoryUsage', 'summary.quickStats.overallCpuUsage', 'summary.quickStats.overallCpuDemand', 'summary.quickStats.hostMemoryUsage', 'summary.quickStats.guestMemoryUsage', 'summary.quickStats.balloonedMemory', 'summary.quickStats.compressedMemory', 'summary.quickStats.swappedMemory', 'summary.storage.committed', 'summary.storage.uncommitted', 'config.hardware.numCPU', 'layoutEx.file', 'snapshot', 'runtime.host', 'summary.runtime.connectionState', 'summary.runtime.powerState', 'summary.config.numVirtualDisks'], filter => {'summary.runtime.connectionState' => "connected"});
	my %all_vm_views_table = ();
	foreach my $all_vm_view (@$all_vm_views) {
		$all_vm_views_table{$all_vm_view->{'mo_ref'}->value} = $all_vm_view;
	}


	### create parents,types,names hashtables to get root datacenter when needed with getRootDc function

	if ($all_datacentres_views and $all_cluster_views and $all_compute_views and $all_host_views and $all_folder_views and $all_pod_views ) {
		foreach my $all_xfolder (@$all_datacentres_views, @$all_cluster_views, @$all_compute_views, @$all_host_views, @$all_folder_views, @$all_pod_views) {
			if ($all_xfolder->{'parent'}) { ### skip folder-group-d1
				if (!$all_xfolders_parent_table{$all_xfolder->{'mo_ref'}->value}) {$all_xfolders_parent_table{$all_xfolder->{'mo_ref'}->value} = $all_xfolder->{'parent'}->value}
				if (!$all_xfolders_type_table{$all_xfolder->{'mo_ref'}->value}) {$all_xfolders_type_table{$all_xfolder->{'mo_ref'}->value} = $all_xfolder->{'mo_ref'}->type}
				if (!$all_xfolders_name_table{$all_xfolder->{'mo_ref'}->value}) {$all_xfolders_name_table{$all_xfolder->{'mo_ref'}->value} = $all_xfolder->name}
			}
		}
	}

	### collect performance metrics

	my %hostmultistats = ();
	my %vmmultistats = ();
	my %vcmultistats = ();
	my %clumultistats = ();

	if (!$BFG_MODE){

		my $hostmultimetricsstart = Time::HiRes::gettimeofday();
		my @hostmultimetrics = (
			["net", "bytesRx", "average"],
			["net", "bytesTx", "average"],
			["net", "droppedRx", "summation"],
			["net", "droppedTx", "summation"],
			["net", "errorsRx", "summation"],
			["net", "errorsTx", "summation"],
			["storageAdapter", "read", "average"],
			["storageAdapter", "write", "average"],
			["power", "power", "average"],
			["datastore", "sizeNormalizedDatastoreLatency", "average"],
			["datastore", "datastoreIops", "average"],
			["datastore", "totalWriteLatency", "average"],
			["datastore", "totalReadLatency", "average"],
			["datastore", "numberWriteAveraged", "average"],
			["datastore", "numberReadAveraged", "average"],
			["cpu", "latency", "average"],
			["cpu", "totalCapacity", "average"],
			["mem", "totalCapacity", "average"]
		);

		eval {
			%hostmultistats = MultiQueryPerfAll($all_host_views, @hostmultimetrics);
		};
		my $hostmultimetricsend = Time::HiRes::gettimeofday();
		my $hostmultimetricstimelapse = $hostmultimetricsend - $hostmultimetricsstart;
		$logger->info("[DEBUG] computed all hosts multi metrics in $hostmultimetricstimelapse sec for vCenter $vmware_server");

		my $vmmultimetricsstart = Time::HiRes::gettimeofday();
		my @vmmultimetrics = (
			["cpu", "ready", "summation"],
			["cpu", "wait", "summation"],
			["cpu", "idle", "summation"],
			["cpu", "latency", "average"],
			["disk", "maxTotalLatency", "latest"],
			["disk", "usage", "average"],
			# ["disk", "commandsAveraged", "average"],
			["net", "usage", "average"],
			["cpu", "totalCapacity", "average"],
			["mem", "totalCapacity", "average"]
		);

		eval {
			%vmmultistats = MultiQueryPerf($all_vm_views, @vmmultimetrics);
		};
		my $vmmultimetricsend = Time::HiRes::gettimeofday();
		my $vmmultimetricstimelapse = $vmmultimetricsend - $vmmultimetricsstart;
		$logger->info("[DEBUG] computed all vms multi metrics in $vmmultimetricstimelapse sec for vCenter $vmware_server");

	} else {

		my $hostmultimetricsstart = Time::HiRes::gettimeofday();
		my @hostmultimetrics = (
			["net", "bytesRx", "average"],
			["net", "bytesTx", "average"],
			["storageAdapter", "read", "average"],
			["storageAdapter", "write", "average"],
			["power", "power", "average"],
			["datastore", "sizeNormalizedDatastoreLatency", "average"],
			["datastore", "datastoreIops", "average"],
			["datastore", "totalWriteLatency", "average"],
			["datastore", "totalReadLatency", "average"],
			["datastore", "numberWriteAveraged", "average"],
			["datastore", "numberReadAveraged", "average"],
			["cpu", "latency", "average"]
		);

		eval {
			%hostmultistats = MultiQueryPerfAll($all_host_views, @hostmultimetrics);
		};
		my $hostmultimetricsend = Time::HiRes::gettimeofday();
		my $hostmultimetricstimelapse = $hostmultimetricsend - $hostmultimetricsstart;
		$logger->info("[DEBUG] computed all hosts multi metrics in $hostmultimetricstimelapse sec for vCenter $vmware_server");

	}

	# my $vcmultimetricsstart = Time::HiRes::gettimeofday();
	# my @vcmultimetrics = (
	# 	["vcResources", "virtualmemusage", "average"],
	# 	["vcResources", "physicalmemusage", "average"],
	# 	["vcResources", "systemcpuusage", "average"],
	# );
	# eval {
	# 	%vcmultistats = MultiQueryPerf300($FolderGroupD1, @vcmultimetrics);
	# };
	# my $vcmultimetricsend = Time::HiRes::gettimeofday();
	# my $vcmultimetricstimelapse = $vcmultimetricsend - $vcmultimetricsstart;
	# $logger->info("[DEBUG] computed all vc multi metrics in $vcmultimetricstimelapse sec for vCenter $vmware_server");

	if ($all_cluster_views){
		my $clumultimetricsstart = Time::HiRes::gettimeofday();
		my @clumultimetrics = (
			["vmop", "numSVMotion", "latest"]
		);
		eval {
			%clumultistats = MultiQueryPerf300($all_cluster_views, @clumultimetrics);
		};
		my $clumultimetricsend = Time::HiRes::gettimeofday();
		my $clumultimetricstimelapse = $clumultimetricsend - $clumultimetricsstart;
		$logger->info("[DEBUG] computed all cluster multi metrics in $clumultimetricstimelapse sec for vCenter $vmware_server");
	}

	my $cluster_hosts_views_pcpus = 0;
	my @cluster_hosts_vms_moref = ();
	my @cluster_hosts_cpu_latency = ();
	my @cluster_hosts_net_bytesRx = ();
	my @cluster_hosts_net_bytesTx = ();
	my @cluster_hosts_hba_bytesRead = ();
	my @cluster_hosts_hba_bytesWrite = ();
	my @cluster_hosts_power_usage = ();
	# my %clusters_hosts_name_table = ();

	foreach my $cluster_view (@$all_cluster_views) {
		my $cluster_name = nameCleaner($cluster_view->name);

		my $datacentre_name = nameCleaner(getRootDc $cluster_view);

		my $clusterCarbonHash = ();

		$logger->info("[INFO] Processing vCenter $vmware_server cluster $cluster_name hosts in datacenter $datacentre_name");

		if (my $cluster_root_pool_view = $all_cluster_root_pool_views_table{$cluster_view->{'mo_ref'}->value}) {

			my $cluster_root_pool_quickStats = $cluster_root_pool_view->{'summary.quickStats'};

			$clusterCarbonHash->{$vmware_server_name}{$datacentre_name}{$cluster_name}{"quickstats"}{"mem"}{"ballooned"} = $cluster_root_pool_quickStats->balloonedMemory;
			$clusterCarbonHash->{$vmware_server_name}{$datacentre_name}{$cluster_name}{"quickstats"}{"mem"}{"compressed"} = $cluster_root_pool_quickStats->compressedMemory;
			$clusterCarbonHash->{$vmware_server_name}{$datacentre_name}{$cluster_name}{"quickstats"}{"mem"}{"consumedOverhead"} = $cluster_root_pool_quickStats->consumedOverheadMemory;
			$clusterCarbonHash->{$vmware_server_name}{$datacentre_name}{$cluster_name}{"quickstats"}{"mem"}{"guest"} = $cluster_root_pool_quickStats->guestMemoryUsage;
			$clusterCarbonHash->{$vmware_server_name}{$datacentre_name}{$cluster_name}{"quickstats"}{"mem"}{"usage"} = $cluster_root_pool_quickStats->hostMemoryUsage;
			$clusterCarbonHash->{$vmware_server_name}{$datacentre_name}{$cluster_name}{"quickstats"}{"cpu"}{"demand"} = $cluster_root_pool_quickStats->overallCpuDemand;
			$clusterCarbonHash->{$vmware_server_name}{$datacentre_name}{$cluster_name}{"quickstats"}{"cpu"}{"usage"} = $cluster_root_pool_quickStats->overallCpuUsage;
			$clusterCarbonHash->{$vmware_server_name}{$datacentre_name}{$cluster_name}{"quickstats"}{"mem"}{"private"} = $cluster_root_pool_quickStats->privateMemory;
			$clusterCarbonHash->{$vmware_server_name}{$datacentre_name}{$cluster_name}{"quickstats"}{"mem"}{"shared"} = $cluster_root_pool_quickStats->sharedMemory;
			$clusterCarbonHash->{$vmware_server_name}{$datacentre_name}{$cluster_name}{"quickstats"}{"mem"}{"swapped"} = $cluster_root_pool_quickStats->swappedMemory;
			$clusterCarbonHash->{$vmware_server_name}{$datacentre_name}{$cluster_name}{"quickstats"}{"mem"}{"effective"} = $cluster_view->summary->effectiveMemory;
			$clusterCarbonHash->{$vmware_server_name}{$datacentre_name}{$cluster_name}{"quickstats"}{"mem"}{"total"} = $cluster_view->summary->totalMemory;
			$clusterCarbonHash->{$vmware_server_name}{$datacentre_name}{$cluster_name}{"quickstats"}{"cpu"}{"effective"} = $cluster_view->summary->effectiveCpu;
			$clusterCarbonHash->{$vmware_server_name}{$datacentre_name}{$cluster_name}{"quickstats"}{"cpu"}{"total"} = $cluster_view->summary->totalCpu;
			$clusterCarbonHash->{$vmware_server_name}{$datacentre_name}{$cluster_name}{"quickstats"}{"numVmotions"} = $cluster_view->summary->numVmotions;


			my $cluster_view_numSVMotion = $clumultistats{$perfCntr{"vmop.numSVMotion.latest"}->key}{$cluster_view->{'mo_ref'}->value}{""};
			if ($cluster_view_numSVMotion) {
				$clusterCarbonHash->{$vmware_server_name}{$datacentre_name}{$cluster_name}{"quickstats"}{"numSVMotions"} = $cluster_view_numSVMotion;
			}

			if ($cluster_root_pool_quickStats->overallCpuUsage > 0 && $cluster_view->summary->effectiveCpu > 0) {
				my $cluster_root_pool_quickStats_cpu = $cluster_root_pool_quickStats->overallCpuUsage * 100 / $cluster_view->summary->effectiveCpu;
				$clusterCarbonHash->{$vmware_server_name}{$datacentre_name}{$cluster_name}{"superstats"}{"cpu"}{"utilization"} = $cluster_root_pool_quickStats_cpu;
			}

			if ($cluster_root_pool_quickStats->hostMemoryUsage > 0 && $cluster_view->summary->effectiveMemory > 0) {
				my $cluster_root_pool_quickStats_ram = $cluster_root_pool_quickStats->hostMemoryUsage * 100 / $cluster_view->summary->effectiveMemory;
				$clusterCarbonHash->{$vmware_server_name}{$datacentre_name}{$cluster_name}{"superstats"}{"mem"}{"utilization"} = $cluster_root_pool_quickStats_ram;
			}		
		}


		my @cluster_hosts_views = ();
		my $cluster_hosts_moref = $cluster_view->host;
		foreach my $cluster_host_moref (@$cluster_hosts_moref) {
			if ($all_host_views_table{$cluster_host_moref->{'value'}}) {
				push (@cluster_hosts_views,$all_host_views_table{$cluster_host_moref->{'value'}});
				# $clusters_hosts_name_table{($all_host_views_table{$cluster_host_moref->{'value'}})->name} = $cluster_name;
			}
		}

		$cluster_hosts_views_pcpus = 0;
		@cluster_hosts_vms_moref = ();
		@cluster_hosts_cpu_latency = ();
		@cluster_hosts_net_bytesRx = ();
		@cluster_hosts_net_bytesTx = ();
		@cluster_hosts_hba_bytesRead = ();
		@cluster_hosts_hba_bytesWrite = ();
		@cluster_hosts_power_usage = ();

		foreach my $cluster_host_view (@cluster_hosts_views) {

			
			my $host_name = lc ($cluster_host_view->{'config.network.dnsConfig.hostName'});
				if ($host_name eq "localhost") {
					my $cluster_host_view_Vmk0 = $cluster_host_view->{'config.network.vnic'}[0];
					my $cluster_host_view_Vmk0_Ip = $cluster_host_view_Vmk0->spec->ip->ipAddress;
					$cluster_host_view_Vmk0_Ip =~ s/[ .]/_/g;
					$host_name = $cluster_host_view_Vmk0_Ip;
			}

			if ($cluster_host_view->vm && (scalar($cluster_host_view->vm) > 0)) {
				my $cluster_host_view_vms = $cluster_host_view->vm;
				foreach my $cluster_host_view_vm (@$cluster_host_view_vms) {
					push (@cluster_hosts_vms_moref,$cluster_host_view_vm);
				}
			}

			my $cluster_host_view_product_version = nameCleaner($cluster_host_view->{'config.product.version'} . "." . $cluster_host_view->{'config.product.build'});
			print $cluster_host_view_product_version;

			$cluster_hosts_views_pcpus += $cluster_host_view->{'summary.hardware.numCpuCores'};

			my $cluster_hosts_sensors = $cluster_host_view->{'summary.runtime.healthSystemRuntime.systemHealthInfo.numericSensorInfo'};
			# https://vdc-download.vmware.com/vmwb-repository/dcr-public/b50dcbbf-051d-4204-a3e7-e1b618c1e384/538cf2ec-b34f-4bae-a332-3820ef9e7773/vim.host.NumericSensorInfo.html
			
			foreach my $cluster_hosts_sensor (@$cluster_hosts_sensors) {
				if ($cluster_hosts_sensor->name && $cluster_hosts_sensor->sensorType && $cluster_hosts_sensor->currentReading && $cluster_hosts_sensor->unitModifier) {
					my $cluster_hosts_sensor_computed_reading = $cluster_hosts_sensor->currentReading * (10**$cluster_hosts_sensor->unitModifier);
					my $cluster_hosts_sensor_name = nameCleaner($cluster_hosts_sensor->name);
					$clusterCarbonHash->{$vmware_server_name}{$datacentre_name}{$cluster_name}{"esx"}{$host_name}{"sensor"}{$cluster_hosts_sensor->sensorType}{$cluster_hosts_sensor_name} = $cluster_hosts_sensor_computed_reading;
				}
			}

			foreach my $cluster_host_vmnic (@{$cluster_host_view->{'config.network.pnic'}}) {
				if ($cluster_host_vmnic->linkSpeed && $cluster_host_vmnic->linkSpeed->speedMb >= 100) {
					my $cluster_host_vmnic_name = $cluster_host_vmnic->device;
					my $NetbytesRx = $hostmultistats{$perfCntr{"net.bytesRx.average"}->key}{$cluster_host_view->{'mo_ref'}->value}{$cluster_host_vmnic_name};
					my $NetbytesTx = $hostmultistats{$perfCntr{"net.bytesTx.average"}->key}{$cluster_host_view->{'mo_ref'}->value}{$cluster_host_vmnic_name};
					if (defined($NetbytesRx) && defined($NetbytesTx)) {
						push (@cluster_hosts_net_bytesRx,$NetbytesRx);
						push (@cluster_hosts_net_bytesTx,$NetbytesTx);

						$clusterCarbonHash->{$vmware_server_name}{$datacentre_name}{$cluster_name}{"esx"}{$host_name}{"net"}{$cluster_host_vmnic_name}{"bytesRx"} = $NetbytesRx;
						$clusterCarbonHash->{$vmware_server_name}{$datacentre_name}{$cluster_name}{"esx"}{$host_name}{"net"}{$cluster_host_vmnic_name}{"bytesTx"} = $NetbytesTx;
						$clusterCarbonHash->{$vmware_server_name}{$datacentre_name}{$cluster_name}{"esx"}{$host_name}{"net"}{$cluster_host_vmnic_name}{"linkSpeed"} = $cluster_host_vmnic->linkSpeed->speedMb; #ToClean
					}
				}
			}

			foreach my $cluster_host_vmnic (@{$cluster_host_view->{'config.network.pnic'}}) {
				if ($cluster_host_vmnic->linkSpeed && $cluster_host_vmnic->linkSpeed->speedMb >= 100) {
					my $NetdroppedRx = $hostmultistats{$perfCntr{"net.droppedRx.summation"}->key}{$cluster_host_view->{'mo_ref'}->value}{$cluster_host_vmnic->device};
					my $NetdroppedTx = $hostmultistats{$perfCntr{"net.droppedTx.summation"}->key}{$cluster_host_view->{'mo_ref'}->value}{$cluster_host_vmnic->device};
					if ((defined($NetdroppedTx) && defined($NetdroppedRx)) && ($NetdroppedTx > 0 or $NetdroppedRx > 0)) {
						my $cluster_host_vmnic_name = $cluster_host_vmnic->device;

						$clusterCarbonHash->{$vmware_server_name}{$datacentre_name}{$cluster_name}{"esx"}{$host_name}{"net"}{$cluster_host_vmnic_name}{"droppedRx"} = $NetdroppedRx;
						$clusterCarbonHash->{$vmware_server_name}{$datacentre_name}{$cluster_name}{"esx"}{$host_name}{"net"}{$cluster_host_vmnic_name}{"droppedTx"} = $NetdroppedTx;
					}
				}
			}

			foreach my $cluster_host_vmnic (@{$cluster_host_view->{'config.network.pnic'}}) {
				if ($cluster_host_vmnic->linkSpeed && $cluster_host_vmnic->linkSpeed->speedMb >= 100) {
					my $NeterrorsRx = $hostmultistats{$perfCntr{"net.errorsRx.summation"}->key}{$cluster_host_view->{'mo_ref'}->value}{$cluster_host_vmnic->device};
					my $NeterrorsTx = $hostmultistats{$perfCntr{"net.errorsTx.summation"}->key}{$cluster_host_vmnic->device};
					if (defined($NeterrorsRx) && defined($NeterrorsTx)) {
						my $cluster_host_vmnic_name = $cluster_host_vmnic->device;

						$clusterCarbonHash->{$vmware_server_name}{$datacentre_name}{$cluster_name}{"esx"}{$host_name}{"net"}{$cluster_host_vmnic_name}{"errorsRx"} = $NeterrorsRx;
						$clusterCarbonHash->{$vmware_server_name}{$datacentre_name}{$cluster_name}{"esx"}{$host_name}{"net"}{$cluster_host_vmnic_name}{"errorsTx"} = $NeterrorsTx;

					}
				}
			}

			foreach my $cluster_host_vmhba (@{$cluster_host_view->{'config.storageDevice.hostBusAdapter'}}) {
					my $HbabytesRead = $hostmultistats{$perfCntr{"storageAdapter.read.average"}->key}{$cluster_host_view->{'mo_ref'}->value}{$cluster_host_vmhba->device};
					my $HbabytesWrite = $hostmultistats{$perfCntr{"storageAdapter.write.average"}->key}{$cluster_host_view->{'mo_ref'}->value}{$cluster_host_vmhba->device};
					if (defined($HbabytesRead) && defined($HbabytesWrite)) {
						my $cluster_host_vmhba_name = $cluster_host_vmhba->device;
						push (@cluster_hosts_hba_bytesRead,$HbabytesRead);
						push (@cluster_hosts_hba_bytesWrite,$HbabytesWrite);

						$clusterCarbonHash->{$vmware_server_name}{$datacentre_name}{$cluster_name}{"esx"}{$host_name}{"hba"}{$cluster_host_vmhba_name}{"bytesRead"} = $HbabytesRead;
						$clusterCarbonHash->{$vmware_server_name}{$datacentre_name}{$cluster_name}{"esx"}{$host_name}{"hba"}{$cluster_host_vmhba_name}{"bytesWrite"} = $HbabytesWrite;

					}
			}

			my $cluster_host_view_power = $hostmultistats{$perfCntr{"power.power.average"}->key}{$cluster_host_view->{'mo_ref'}->value}{""};
			if (defined($cluster_host_view_power)) {
				push (@cluster_hosts_power_usage,$cluster_host_view_power);
				$clusterCarbonHash->{$vmware_server_name}{$datacentre_name}{$cluster_name}{"esx"}{$host_name}{"fatstats"}{"power"} = $cluster_host_view_power;

			}

			my $cluster_host_view_cpu_totalCapacity = $hostmultistats{$perfCntr{"cpu.totalCapacity.average"}->key}{$cluster_host_view->{'mo_ref'}->value}{""};
			if (defined($cluster_host_view_cpu_totalCapacity) && defined($cluster_host_view->{'summary.quickStats.overallCpuUsage'})) {
				$clusterCarbonHash->{$vmware_server_name}{$datacentre_name}{$cluster_name}{"esx"}{$host_name}{"fatstats"}{"overallCpuUtilization"} = ($cluster_host_view->{'summary.quickStats.overallCpuUsage'} * 100 / $cluster_host_view_cpu_totalCapacity);
			}

			my $cluster_host_view_mem_totalCapacity = $hostmultistats{$perfCntr{"mem.totalCapacity.average"}->key}{$cluster_host_view->{'mo_ref'}->value}{""};
			if (defined($cluster_host_view_mem_totalCapacity) && defined($cluster_host_view->{'summary.quickStats.overallMemoryUsage'})) {
				$clusterCarbonHash->{$vmware_server_name}{$datacentre_name}{$cluster_name}{"esx"}{$host_name}{"fatstats"}{"overallmemUtilization"} = ($cluster_host_view->{'summary.quickStats.overallMemoryUsage'} * 100 / $cluster_host_view_mem_totalCapacity);
			}

			my $cluster_host_view_cpu_latency = $hostmultistats{$perfCntr{"cpu.latency.average"}->key}{$cluster_host_view->{'mo_ref'}->value}{""};
			if (defined($cluster_host_view_cpu_latency)) {
				push (@cluster_hosts_cpu_latency,$cluster_host_view_cpu_latency); #to scale 0.01
			}

			# my $cluster_host_view_rescpu_actav5 = $hostmultistats{$perfCntr{"rescpu.actav5.latest"}->key}{$cluster_host_view->{'mo_ref'}->value}{""};

			my $cluster_host_view_status = $cluster_host_view->{'overallStatus'}->val; #ToClean
			my $cluster_host_view_status_val = 0;
			if ($cluster_host_view_status eq "green") {
				$cluster_host_view_status_val = 1;
			} elsif ($cluster_host_view_status eq "yellow") {
				$cluster_host_view_status_val = 2;
			} elsif ($cluster_host_view_status eq "red") {
				$cluster_host_view_status_val = 3;
			} elsif ($cluster_host_view_status eq "gray") {
				$cluster_host_view_status_val = 0;
			}

			$clusterCarbonHash->{$vmware_server_name}{$datacentre_name}{$cluster_name}{"esx"}{$host_name}{"quickstats"}{"distributedCpuFairness"} = $cluster_host_view->{'summary.quickStats.distributedCpuFairness'};
			$clusterCarbonHash->{$vmware_server_name}{$datacentre_name}{$cluster_name}{"esx"}{$host_name}{"quickstats"}{"distributedMemoryFairness"} = $cluster_host_view->{'summary.quickStats.distributedMemoryFairness'};
			$clusterCarbonHash->{$vmware_server_name}{$datacentre_name}{$cluster_name}{"esx"}{$host_name}{"quickstats"}{"overallCpuUsage"} = $cluster_host_view->{'summary.quickStats.overallCpuUsage'};
			$clusterCarbonHash->{$vmware_server_name}{$datacentre_name}{$cluster_name}{"esx"}{$host_name}{"quickstats"}{"overallMemoryUsage"} = $cluster_host_view->{'summary.quickStats.overallMemoryUsage'};
			$clusterCarbonHash->{$vmware_server_name}{$datacentre_name}{$cluster_name}{"esx"}{$host_name}{"quickstats"}{"Uptime"} = $cluster_host_view->{'summary.quickStats.uptime'};
			$clusterCarbonHash->{$vmware_server_name}{$datacentre_name}{$cluster_name}{"esx"}{$host_name}{"quickstats"}{"overallStatus"} = $cluster_host_view_status_val;
			# $clusterCarbonHash->{$vmware_server_name}{$datacentre_name}{$cluster_name}{"esx"}{$host_name}{"fatstats"}{"load"} = $cluster_host_view_rescpu_actav5;
		}

		if (scalar @cluster_hosts_views > 0) {
			$clusterCarbonHash->{$vmware_server_name}{$datacentre_name}{$cluster_name}{"superstats"}{"esx"}{"count"} = scalar @cluster_hosts_views;
		}

		if (scalar @cluster_hosts_cpu_latency > 0) {
			$clusterCarbonHash->{$vmware_server_name}{$datacentre_name}{$cluster_name}{"superstats"}{"cpu"}{"latency"} = median(@cluster_hosts_cpu_latency);
		}

		if (scalar @cluster_hosts_net_bytesRx > 0 && scalar @cluster_hosts_net_bytesTx > 0) {
			$clusterCarbonHash->{$vmware_server_name}{$datacentre_name}{$cluster_name}{"superstats"}{"net"}{"bytesRx"} = sum(@cluster_hosts_net_bytesRx);
			$clusterCarbonHash->{$vmware_server_name}{$datacentre_name}{$cluster_name}{"superstats"}{"net"}{"bytesTx"} = sum(@cluster_hosts_net_bytesTx);
		}

		if (scalar @cluster_hosts_hba_bytesRead > 0 && scalar @cluster_hosts_hba_bytesWrite > 0) {
			$clusterCarbonHash->{$vmware_server_name}{$datacentre_name}{$cluster_name}{"superstats"}{"hba"}{"bytesRead"} = sum(@cluster_hosts_hba_bytesRead);
			$clusterCarbonHash->{$vmware_server_name}{$datacentre_name}{$cluster_name}{"superstats"}{"hba"}{"bytesWrite"} = sum(@cluster_hosts_hba_bytesWrite);

		}

		if (scalar @cluster_hosts_power_usage > 0) {
			$clusterCarbonHash->{$vmware_server_name}{$datacentre_name}{$cluster_name}{"superstats"}{"power"} = sum(@cluster_hosts_power_usage);

		}

		$logger->info("[INFO] Processing vCenter $vmware_server cluster $cluster_name vms in datacenter $datacentre_name");

		my @cluster_vms_views = ();
		if (scalar(@cluster_hosts_vms_moref) > 0) {
			foreach my $cluster_vm_moref (@cluster_hosts_vms_moref) {
				if ($all_vm_views_table{$cluster_vm_moref->{'value'}}) {
					push (@cluster_vms_views,$all_vm_views_table{$cluster_vm_moref->{'value'}});
				}
			}
		}

		my $cluster_vm_views_vcpus = 0;
		my $cluster_vm_views_vram = 0;
		# my $cluster_vm_views_vnic_usage = 0;
		my $cluster_vm_views_files_dedup = {};
		my $cluster_vm_views_files_dedup_total = {};
		my $cluster_vm_views_files_snaps = 0;
		### my $cluster_vm_views_bak_snaps = 0;
		my $cluster_vm_views_vm_snaps = 0;
		my $cluster_vm_views_off = 0;
		my $cluster_vmdk_per_ds = {};

		if (scalar(@cluster_vms_views) > 0) {

			foreach my $cluster_vm_view (@cluster_vms_views) {

				if ($cluster_vm_view->{'summary.runtime.powerState'}->{'val'} eq "poweredOn") {

					my $cluster_vm_view_name = nameCleaner($cluster_vm_view->name);

					$cluster_vm_views_vcpus += $cluster_vm_view->{'config.hardware.numCPU'};
					$cluster_vm_views_vram += $cluster_vm_view->{'runtime.maxMemoryUsage'};

					my $cluster_vm_view_files = $cluster_vm_view->{'layoutEx.file'};
					### http://pubs.vmware.com/vsphere-60/topic/com.vmware.wssdk.apiref.doc/vim.vm.FileLayoutEx.FileType.html

					my $cluster_vm_view_snap_size = 0;
					my $cluster_vm_view_has_snap = 0;

					if ($cluster_vm_view->snapshot) {

						### getSnapshotTreeRaw($cluster_vm_view->snapshot->rootSnapshotList);

						### foreach my $snaps (@cluster_vm_view_snap_tree) {
						### 	if ($snaps->name =~ /(Consolidate|Helper|VEEAM|Veeam|TSM-VM|Restore Point)/ || $snaps->description =~ /(Consolidate|Helper|VEEAM|Veeam|TSM-VM|Restore Point)/) {
						### 		$cluster_vm_views_bak_snaps++;
						### 	}
						### }

						### @cluster_vm_view_snap_tree;
						$cluster_vm_view_has_snap = 1;
						$cluster_vm_views_vm_snaps++;

					}

					my $cluster_vm_view_num_vdisk = $cluster_vm_view->{'summary.config.numVirtualDisks'};
					my $cluster_vm_view_real_vdisk = 0;
					my $cluster_vm_view_has_diskExtent = 0;
					

					foreach my $cluster_vm_view_file (@$cluster_vm_view_files) {
						if ($cluster_vm_view_file->type eq "diskDescriptor") {
							$cluster_vm_view_real_vdisk++;
							(my $cluster_vm_view_file_ds_name) = ((split(/\s+/, $cluster_vm_view_file->name))[0] =~ /\[(.*)\]/);
							$cluster_vm_view_file_ds_name = nameCleaner($cluster_vm_view_file_ds_name);
							$cluster_vmdk_per_ds->{$cluster_vm_view_file_ds_name}++;
						} elsif ($cluster_vm_view_file->type eq "diskExtent") {
							$cluster_vm_view_has_diskExtent++;
						}
					}

					if (($cluster_vm_view_real_vdisk > $cluster_vm_view_num_vdisk)) {
						$cluster_vm_view_has_snap = 1;
					}

					foreach my $cluster_vm_view_file (@$cluster_vm_view_files) {
						if (!$cluster_vm_views_files_dedup->{$cluster_vm_view_file->name}) { #would need name & moref
							$cluster_vm_views_files_dedup->{$cluster_vm_view_file->name} = $cluster_vm_view_file->size;
							if (($cluster_vm_view_has_snap == 1) && ($cluster_vm_view_file->name =~ /-[0-9]{6}-delta\.vmdk/ or $cluster_vm_view_file->name =~ /-[0-9]{6}-sesparse\.vmdk/)) {
								$cluster_vm_views_files_dedup_total->{snapshotExtent} += $cluster_vm_view_file->size;
								$cluster_vm_view_snap_size += $cluster_vm_view_file->size;
								$cluster_vm_views_files_snaps++;
							} elsif (($cluster_vm_view_has_snap == 1) && ($cluster_vm_view_file->name =~ /-[0-9]{6}\.vmdk/)) {
								$cluster_vm_views_files_dedup_total->{snapshotDescriptor} += $cluster_vm_view_file->size;
								$cluster_vm_view_snap_size += $cluster_vm_view_file->size;
							} elsif ($cluster_vm_view_file->name =~ /-rdm\.vmdk/) {
								$cluster_vm_views_files_dedup_total->{rdmExtent} += $cluster_vm_view_file->size;
							} elsif ($cluster_vm_view_file->name =~ /-rdmp\.vmdk/) {
								$cluster_vm_views_files_dedup_total->{rdmpExtent} += $cluster_vm_view_file->size;
							} elsif (($cluster_vm_view_has_diskExtent == 0) && ($cluster_vm_view_file->type eq "diskDescriptor")) {
								$cluster_vm_views_files_dedup_total->{virtualExtent} += $cluster_vm_view_file->size;
							} else {
								$cluster_vm_views_files_dedup_total->{$cluster_vm_view_file->type} += $cluster_vm_view_file->size;
							}
						}
					}

					if (!$BFG_MODE) {

						if ($cluster_vm_view_snap_size > 0) {
							$clusterCarbonHash->{$vmware_server_name}{$datacentre_name}{$cluster_name}{"vm"}{$cluster_vm_view_name}{"storage"}{"delta"} = $cluster_vm_view_snap_size;
						}

						if ($cluster_vm_view->{'runtime.maxCpuUsage'} > 0 && $cluster_vm_view->{'summary.quickStats.overallCpuUsage'}) {
							my $cluster_vm_view_CpuUtilization = $cluster_vm_view->{'summary.quickStats.overallCpuUsage'} * 100 / $cluster_vm_view->{'runtime.maxCpuUsage'};
							$clusterCarbonHash->{$vmware_server_name}{$datacentre_name}{$cluster_name}{"vm"}{$cluster_vm_view_name}{"runtime"}{"CpuUtilization"} = $cluster_vm_view_CpuUtilization;
						}

						if ($cluster_vm_view->{'summary.quickStats.guestMemoryUsage'} > 0 && $cluster_vm_view->{'runtime.maxMemoryUsage'}) {
							my $cluster_vm_view_MemUtilization = $cluster_vm_view->{'summary.quickStats.guestMemoryUsage'} * 100 / $cluster_vm_view->{'runtime.maxMemoryUsage'};
							$clusterCarbonHash->{$vmware_server_name}{$datacentre_name}{$cluster_name}{"vm"}{$cluster_vm_view_name}{"runtime"}{"MemUtilization"} = $cluster_vm_view_MemUtilization;
						}

						$clusterCarbonHash->{$vmware_server_name}{$datacentre_name}{$cluster_name}{"vm"}{$cluster_vm_view_name}{"quickstats"}{"overallCpuUsage"} = $cluster_vm_view->{'summary.quickStats.overallCpuUsage'};
						$clusterCarbonHash->{$vmware_server_name}{$datacentre_name}{$cluster_name}{"vm"}{$cluster_vm_view_name}{"quickstats"}{"overallCpuDemand"} = $cluster_vm_view->{'summary.quickStats.overallCpuDemand'};
						$clusterCarbonHash->{$vmware_server_name}{$datacentre_name}{$cluster_name}{"vm"}{$cluster_vm_view_name}{"quickstats"}{"HostMemoryUsage"} = $cluster_vm_view->{'summary.quickStats.hostMemoryUsage'};
						$clusterCarbonHash->{$vmware_server_name}{$datacentre_name}{$cluster_name}{"vm"}{$cluster_vm_view_name}{"quickstats"}{"GuestMemoryUsage"} = $cluster_vm_view->{'summary.quickStats.guestMemoryUsage'};
						$clusterCarbonHash->{$vmware_server_name}{$datacentre_name}{$cluster_name}{"vm"}{$cluster_vm_view_name}{"storage"}{"committed"} = $cluster_vm_view->{'summary.storage.committed'};
						$clusterCarbonHash->{$vmware_server_name}{$datacentre_name}{$cluster_name}{"vm"}{$cluster_vm_view_name}{"storage"}{"uncommitted"} = $cluster_vm_view->{'summary.storage.uncommitted'};

						if ($cluster_vm_view->{'summary.quickStats.balloonedMemory'} > 0) {
							$clusterCarbonHash->{$vmware_server_name}{$datacentre_name}{$cluster_name}{"vm"}{$cluster_vm_view_name} {"quickstats"}{"BalloonedMemory"} = $cluster_vm_view->{'summary.quickStats.balloonedMemory'};
						}

						if ($cluster_vm_view->{'summary.quickStats.compressedMemory'} > 0) {
							$clusterCarbonHash->{$vmware_server_name}{$datacentre_name}{$cluster_name}{"vm"}{$cluster_vm_view_name} {"quickstats"}{"CompressedMemory"} = $cluster_vm_view->{'summary.quickStats.compressedMemory'};
						}

						if ($cluster_vm_view->{'summary.quickStats.swappedMemory'} > 0) {
							$clusterCarbonHash->{$vmware_server_name}{$datacentre_name}{$cluster_name}{"vm"}{$cluster_vm_view_name}{"quickstats"}{"SwappedMemory"} = $cluster_vm_view->{'summary.quickStats.swappedMemory'};
						}

						if ($vmmultistats{$perfCntr{"cpu.ready.summation"}->key}{$cluster_vm_view->{'mo_ref'}->value}{""}) {
							my $vmreadyavg = $vmmultistats{$perfCntr{"cpu.ready.summation"}->key}{$cluster_vm_view->{'mo_ref'}->value}{""} / $cluster_vm_view->{'config.hardware.numCPU'} / 20000 * 100;
							### https://kb.vmware.com/kb/2002181
							$clusterCarbonHash->{$vmware_server_name}{$datacentre_name}{$cluster_name}{"vm"}{$cluster_vm_view_name}{"fatstats"}{"cpu_ready_summation"} = $vmreadyavg;
						}

						if ($vmmultistats{$perfCntr{"cpu.wait.summation"}->key}{$cluster_vm_view->{'mo_ref'}->value}{""} && $vmmultistats{$perfCntr{"cpu.idle.summation"}->key}{$cluster_vm_view->{'mo_ref'}->value}{""}) {
							my $vmwaitavg = ($vmmultistats{$perfCntr{"cpu.wait.summation"}->key}{$cluster_vm_view->{'mo_ref'}->value}{""} - $vmmultistats{$perfCntr{"cpu.idle.summation"}->key}{$cluster_vm_view->{'mo_ref'}->value}{""}) / $cluster_vm_view->{'config.hardware.numCPU'} / 20000 * 100;
							### https://code.vmware.com/apis/358/vsphere#/doc/cpu_counters.html
							$clusterCarbonHash->{$vmware_server_name}{$datacentre_name}{$cluster_name}{"vm"}{$cluster_vm_view_name}{"fatstats"}{"cpu_wait_no_idle"} = $vmwaitavg;
						}

						if ($vmmultistats{$perfCntr{"cpu.latency.average"}->key}{$cluster_vm_view->{'mo_ref'}->value}{""}) {
							my $vmlatencyval = $vmmultistats{$perfCntr{"cpu.latency.average"}->key}{$cluster_vm_view->{'mo_ref'}->value}{""};
							$clusterCarbonHash->{$vmware_server_name}{$datacentre_name}{$cluster_name}{"vm"}{$cluster_vm_view_name}{"fatstats"}{"cpu_latency_average"} = $vmlatencyval;
						}

						if ($vmmultistats{$perfCntr{"disk.maxTotalLatency.latest"}->key}{$cluster_vm_view->{'mo_ref'}->value}{""}) {
							my $vmmaxtotallatencyval = $vmmultistats{$perfCntr{"disk.maxTotalLatency.latest"}->key}{$cluster_vm_view->{'mo_ref'}->value}{""};
							$clusterCarbonHash->{$vmware_server_name}{$datacentre_name}{$cluster_name}{"vm"}{$cluster_vm_view_name}{"fatstats"}{"maxTotalLatency"} = $vmmaxtotallatencyval;
						}

						if ($vmmultistats{$perfCntr{"disk.usage.average"}->key}{$cluster_vm_view->{'mo_ref'}->value}{""}) {
							my $vmdiskusageval = $vmmultistats{$perfCntr{"disk.usage.average"}->key}{$cluster_vm_view->{'mo_ref'}->value}{""};
							$clusterCarbonHash->{$vmware_server_name}{$datacentre_name}{$cluster_name}{"vm"}{$cluster_vm_view_name}{"fatstats"}{"diskUsage"} = $vmdiskusageval;
						}

						if ($vmmultistats{$perfCntr{"net.usage.average"}->key}{$cluster_vm_view->{'mo_ref'}->value}{""}) {
							my $vmnetusageval = $vmmultistats{$perfCntr{"net.usage.average"}->key}{$cluster_vm_view->{'mo_ref'}->value}{""};
							# $cluster_vm_views_vnic_usage += $vmnetusageval;
							$clusterCarbonHash->{$vmware_server_name}{$datacentre_name}{$cluster_name}{"vm"}{$cluster_vm_view_name}{"fatstats"}{"netUsage"} = $vmnetusageval;
						}

						# if ($vmmultistats{$perfCntr{"disk.commandsAveraged.average"}->key}{$cluster_vm_view->{'mo_ref'}->value}{""}) {
						# 	my $vmcommandsAveragedval = $vmmultistats{$perfCntr{"disk.commandsAveraged.average"}->key}{$cluster_vm_view->{'mo_ref'}->value}{""};
						# 	$clusterCarbonHash->{$vmware_server_name}{$datacentre_name}{$cluster_name}{"vm"}{$cluster_vm_view_name}{"fatstats"}{"diskCommands"} = $vmcommandsAveragedval;
						# }
					}

				} elsif ($cluster_vm_view->{'summary.runtime.powerState'}->{'val'} eq "poweredOff") {

					my $cluster_vm_view_off = $cluster_vm_view;
					$cluster_vm_views_off++;

					my $cluster_vm_view_off_name = nameCleaner($cluster_vm_view_off->name);

					my $cluster_vm_view_off_files = $cluster_vm_view_off->{'layoutEx.file'};
					### http://pubs.vmware.com/vsphere-60/topic/com.vmware.wssdk.apiref.doc/vim.vm.FileLayoutEx.FileType.html

					my $cluster_vm_view_off_snap_size = 0;
					my $cluster_vm_view_off_has_snap = 0;

					if ($cluster_vm_view_off->snapshot) {

						### getSnapshotTreeRaw($cluster_vm_view_off->snapshot->rootSnapshotList);

						### foreach my $snaps (@cluster_vm_view_snap_tree) {
						### 	if ($snaps->name =~ /(Consolidate|Helper|VEEAM|Veeam|TSM-VM|Restore Point)/ || $snaps->description =~ /(Consolidate|Helper|VEEAM|Veeam|TSM-VM|Restore Point)/) {
						### 		$cluster_vm_views_bak_snaps++;
						### 	}
						### }

						### @cluster_vm_view_snap_tree;
						$cluster_vm_view_off_has_snap = 1;
						$cluster_vm_views_vm_snaps++;

					}

					my $cluster_vm_view_off_num_vdisk = $cluster_vm_view_off->{'summary.config.numVirtualDisks'};
					my $cluster_vm_view_off_real_vdisk = 0;
					my $cluster_vm_view_off_has_diskExtent = 0;

					foreach my $cluster_vm_view_off_file (@$cluster_vm_view_off_files) {
						if ($cluster_vm_view_off_file->type eq "diskDescriptor") {
							$cluster_vm_view_off_real_vdisk++;
						} elsif ($cluster_vm_view_off_file->type eq "diskExtent") {
							$cluster_vm_view_off_has_diskExtent++;
						}
					}

					if (($cluster_vm_view_off_real_vdisk > $cluster_vm_view_off_num_vdisk)) {
						$cluster_vm_view_off_has_snap = 1;
					}

					foreach my $cluster_vm_view_off_file (@$cluster_vm_view_off_files) {
						if (!$cluster_vm_views_files_dedup->{$cluster_vm_view_off_file->name}) { #would need name & moref
							$cluster_vm_views_files_dedup->{$cluster_vm_view_off_file->name} = $cluster_vm_view_off_file->size;
							if (($cluster_vm_view_off_has_snap == 1) && ($cluster_vm_view_off_file->name =~ /-[0-9]{6}-delta\.vmdk/ or $cluster_vm_view_off_file->name =~ /-[0-9]{6}-sesparse\.vmdk/)) {
								$cluster_vm_views_files_dedup_total->{snapshotExtent} += $cluster_vm_view_off_file->size;
								$cluster_vm_view_off_snap_size += $cluster_vm_view_off_file->size;
							} elsif (($cluster_vm_view_off_has_snap == 1) && ($cluster_vm_view_off_file->name =~ /-[0-9]{6}\.vmdk/)) {
									$cluster_vm_views_files_snaps++;
									$cluster_vm_views_files_dedup_total->{snapshotDescriptor} += $cluster_vm_view_off_file->size;
									$cluster_vm_view_off_snap_size += $cluster_vm_view_off_file->size;
							} elsif ($cluster_vm_view_off_file->name =~ /-rdm\.vmdk/) {
									$cluster_vm_views_files_dedup_total->{rdmExtent} += $cluster_vm_view_off_file->size;
							} elsif ($cluster_vm_view_off_file->name =~ /-rdmp\.vmdk/) {
									$cluster_vm_views_files_dedup_total->{rdmpExtent} += $cluster_vm_view_off_file->size;
							} elsif (($cluster_vm_view_off_has_diskExtent == 0) && ($cluster_vm_view_off_file->type eq "diskDescriptor")) {
								$cluster_vm_views_files_dedup_total->{virtualExtent} += $cluster_vm_view_off_file->size;
							} else {
								$cluster_vm_views_files_dedup_total->{$cluster_vm_view_off_file->type} += $cluster_vm_view_off_file->size;
							}
						}
					}

					if (!$BFG_MODE) {

						if ($cluster_vm_view_off_snap_size > 0) {
							$clusterCarbonHash->{$vmware_server_name}{$datacentre_name}{$cluster_name}{"vm"}{$cluster_vm_view_off_name}{"storage.delta"} = $cluster_vm_view_off_snap_size;
						}

						$clusterCarbonHash->{$vmware_server_name}{$datacentre_name}{$cluster_name}{"vm"}{$cluster_vm_view_off_name}{"storage.committed"} = $cluster_vm_view_off->{'summary.storage.committed'};
						$clusterCarbonHash->{$vmware_server_name}{$datacentre_name}{$cluster_name}{"vm"}{$cluster_vm_view_off_name}{"storage.uncommitted"} = $cluster_vm_view_off->{'summary.storage.uncommitted'};
					}
				}
			}

			if ($cluster_vm_views_vcpus > 0 && $cluster_hosts_views_pcpus > 0) {
				$clusterCarbonHash->{$vmware_server_name}{$datacentre_name}{$cluster_name}{"quickstats"}{"vCPUs"} = $cluster_vm_views_vcpus;
				$clusterCarbonHash->{$vmware_server_name}{$datacentre_name}{$cluster_name}{"quickstats"}{"pCPUs"} = $cluster_hosts_views_pcpus;
			}

			if ($cluster_vm_views_vram > 0 && $cluster_view->summary->effectiveMemory > 0) {
				my $cluster_root_pool_quickStats_vram = $cluster_vm_views_vram * 100 / $cluster_view->summary->effectiveMemory;
				$clusterCarbonHash->{$vmware_server_name}{$datacentre_name}{$cluster_name}{"quickstats"}{"vRAM"} = $cluster_vm_views_vram;
				$clusterCarbonHash->{$vmware_server_name}{$datacentre_name}{$cluster_name}{"superstats"}{"mem"}{"allocated"} = $cluster_root_pool_quickStats_vram;
			}

			# if ($cluster_vm_views_vnic_usage > 0) {
			# 	$clusterCarbonHash->{$vmware_server_name}{$datacentre_name}{$cluster_name}{"superstats"}{"net"}{"vnicUsage"} = $cluster_vm_views_vnic_usage;
			# }

			if ($cluster_vm_views_files_dedup_total) {

				foreach my $FileType (keys %$cluster_vm_views_files_dedup_total) {
					$clusterCarbonHash->{$vmware_server_name}{$datacentre_name}{$cluster_name}{"storage"}{"FileType"}{$FileType} = $cluster_vm_views_files_dedup_total->{$FileType};
				}

				if ($cluster_vm_views_files_snaps) {
					$clusterCarbonHash->{$vmware_server_name}{$datacentre_name}{$cluster_name}{"storage"}{"SnapshotCount"} = $cluster_vm_views_files_snaps;
				}

				### if ($cluster_vm_views_bak_snaps) {
				###		$clusterCarbonHash->{$vmware_server_name}{$datacentre_name}{$cluster_name}{"storage"}{"BakSnapshotCount"} = $cluster_vm_views_bak_snaps;
				### }

				if ($cluster_vm_views_vm_snaps) {
					$clusterCarbonHash->{$vmware_server_name}{$datacentre_name}{$cluster_name}{"storage"}{"VmSnapshotCount"} = $cluster_vm_views_vm_snaps;
				}
			}
		}

		$clusterCarbonHash->{$vmware_server_name}{$datacentre_name}{$cluster_name}{"runtime"}{"vm"}{"total"} = scalar(@cluster_vms_views);
		$clusterCarbonHash->{$vmware_server_name}{$datacentre_name}{$cluster_name}{"runtime"}{"vm"}{"on"} = (scalar(@cluster_vms_views) - $cluster_vm_views_off);

		$logger->info("[INFO] Processing vCenter $vmware_server cluster $cluster_name datastores in datacenter $datacentre_name");

		my @cluster_datastores_views = ();
		my $cluster_datastores_moref = $cluster_view->datastore;
		foreach my $cluster_datastore_moref (@$cluster_datastores_moref) {
			if ($all_datastore_views_table{$cluster_datastore_moref->{'value'}}) {
				push (@cluster_datastores_views,$all_datastore_views_table{$cluster_datastore_moref->{'value'}});
			}
		}

		my $cluster_datastores_count = 0;
		my @cluster_datastores_capacity = ();
		my @cluster_datastores_freeSpace = ();
		my @cluster_datastores_uncommitted = ();
		my @cluster_datastores_latency = ();
		my @cluster_datastores_iops = ();


		foreach my $cluster_datastore_view (@cluster_datastores_views) {
			if ($cluster_datastore_view->summary->accessible && $cluster_datastore_view->summary->multipleHostAccess) {
				my $shared_datastore_name = nameCleaner($cluster_datastore_view->summary->name);

				$cluster_datastores_count++;

				my $ds_hosts_view = $cluster_datastore_view->host;

				my $shared_datastore_uncommitted = 0;
				if ($cluster_datastore_view->summary->uncommitted) {
					$shared_datastore_uncommitted = $cluster_datastore_view->summary->uncommitted;
				}

				$clusterCarbonHash->{$vmware_server_name}{$datacentre_name}{$cluster_name}{"datastore"}{$shared_datastore_name}{"summary"}{"capacity"} = $cluster_datastore_view->summary->capacity;
				$clusterCarbonHash->{$vmware_server_name}{$datacentre_name}{$cluster_name}{"datastore"}{$shared_datastore_name}{"summary"}{"freeSpace"} = $cluster_datastore_view->summary->freeSpace;
				$clusterCarbonHash->{$vmware_server_name}{$datacentre_name}{$cluster_name}{"datastore"}{$shared_datastore_name}{"summary"}{"uncommitted"} = $shared_datastore_uncommitted;

				if ($cluster_vmdk_per_ds->{$shared_datastore_name}) {
					$clusterCarbonHash->{$vmware_server_name}{$datacentre_name}{$cluster_name}{"datastore"}{$shared_datastore_name}{"summary"}{"vmdkCount"} = $cluster_vmdk_per_ds->{$shared_datastore_name};				
				}

				push (@cluster_datastores_capacity,$cluster_datastore_view->summary->capacity);
				push (@cluster_datastores_freeSpace,$cluster_datastore_view->summary->freeSpace);
				push (@cluster_datastores_uncommitted,$shared_datastore_uncommitted);

				if ($cluster_datastore_view->{'iormConfiguration.enabled'} or $cluster_datastore_view->{'iormConfiguration.statsCollectionEnabled'}) {

					my @vmpath = split("/", $cluster_datastore_view->summary->url);
					my $uuid = $vmpath[-1];

					my @dsiormlatencyuuid = ();
					my @dsiormiopsuuid = ();
					my $middsiormlatencyuuid = 0;
					my $middsiormiopsuuid = 0;
					
					foreach my $ds_host_view (@$ds_hosts_view) {
						if ($ds_host_view->{'mountInfo'}->{'mounted'} && $ds_host_view->{'mountInfo'}->{'accessible'}) {
							if ($hostmultistats{$perfCntr{"datastore.sizeNormalizedDatastoreLatency.average"}->key}{$ds_host_view->key->value}{$uuid}) {
								push @dsiormlatencyuuid,$hostmultistats{$perfCntr{"datastore.sizeNormalizedDatastoreLatency.average"}->key}{$ds_host_view->key->value}{$uuid};
							}
							if ($hostmultistats{$perfCntr{"datastore.datastoreIops.average"}->key}{$ds_host_view->key->value}{$uuid}) {
								push @dsiormiopsuuid,$hostmultistats{$perfCntr{"datastore.datastoreIops.average"}->key}{$ds_host_view->key->value}{$uuid};
							}
						}
					}

					if ((scalar(@dsiormlatencyuuid) > 0) && (scalar(@dsiormiopsuuid) > 0)) {
						$middsiormlatencyuuid = median(@dsiormlatencyuuid);
						$middsiormiopsuuid = median(@dsiormiopsuuid);

						push (@cluster_datastores_latency,$middsiormlatencyuuid);
						push (@cluster_datastores_iops,$middsiormiopsuuid);

						$clusterCarbonHash->{$vmware_server_name}{$datacentre_name}{$cluster_name}{"datastore"}{$shared_datastore_name}{"iorm"}{"sizeNormalizedDatastoreLatency"} = $middsiormlatencyuuid;
						$clusterCarbonHash->{$vmware_server_name}{$datacentre_name}{$cluster_name}{"datastore"}{$shared_datastore_name}{"iorm"}{"datastoreIops"} = $middsiormiopsuuid;
					}

				} elsif ($cluster_datastore_view->summary->type ne "vsan") {

					my @vmpath = split("/", $cluster_datastore_view->summary->url);
					my $uuid = $vmpath[-1];

					my @dstotalWriteLatencyuuid = ();
					my @dstotalReadLatencyuuid = ();
					my @dstotalReadIouuid = ();
					my @dstotalWriteIouuid = ();
					my $middstotalWriteLatencyuuid = 0;
					my $middstotalReadLatencyuuid = 0;
					my $middstotalReadIouuid = 0;
					my $middstotalWriteIouuid = 0;
					my $middsLegacylatencyuuid = 0;
					my $middsLegacyiopsuuid = 0;

					foreach my $ds_host_view (@$ds_hosts_view) {
						if ($ds_host_view->{'mountInfo'}->{'mounted'} && $ds_host_view->{'mountInfo'}->{'accessible'}) {
							if ($hostmultistats{$perfCntr{"datastore.totalReadLatency.average"}->key}{$ds_host_view->key->value}{$uuid}) {
								push @dstotalReadLatencyuuid,$hostmultistats{$perfCntr{"datastore.totalReadLatency.average"}->key}{$ds_host_view->key->value}{$uuid};
							}
							if ($hostmultistats{$perfCntr{"datastore.totalWriteLatency.average"}->key}{$ds_host_view->key->value}{$uuid}) {
								push @dstotalWriteLatencyuuid,$hostmultistats{$perfCntr{"datastore.totalWriteLatency.average"}->key}{$ds_host_view->key->value}{$uuid};
							}
							if ($hostmultistats{$perfCntr{"datastore.numberReadAveraged.average"}->key}{$ds_host_view->key->value}{$uuid}) {
								push @dstotalReadIouuid,$hostmultistats{$perfCntr{"datastore.numberReadAveraged.average"}->key}{$ds_host_view->key->value}{$uuid};
							}
							if ($hostmultistats{$perfCntr{"datastore.numberWriteAveraged.average"}->key}{$ds_host_view->key->value}{$uuid}) {
								push @dstotalWriteIouuid,$hostmultistats{$perfCntr{"datastore.numberWriteAveraged.average"}->key}{$ds_host_view->key->value}{$uuid};
							}
						}
					}

					if ((scalar(@dstotalWriteLatencyuuid) > 0) && (scalar(@dstotalReadLatencyuuid) > 0) && (scalar(@dstotalReadIouuid) > 0) && (scalar(@dstotalWriteIouuid) > 0)) {
						$middstotalWriteLatencyuuid = median(@dstotalWriteLatencyuuid);
						$middstotalReadLatencyuuid = median(@dstotalReadLatencyuuid);
						$middstotalWriteIouuid = sum(@dstotalWriteIouuid);
						$middstotalReadIouuid = sum(@dstotalReadIouuid);

						my $middsLegacylatencyuuid = max($middstotalWriteLatencyuuid,$middstotalReadLatencyuuid) * 1000;
						my $middsLegacyiopsuuid = sum($middstotalWriteIouuid,$middstotalReadIouuid);

						push (@cluster_datastores_latency,$middsLegacylatencyuuid);
						push (@cluster_datastores_iops,$middsLegacyiopsuuid);

						$clusterCarbonHash->{$vmware_server_name}{$datacentre_name}{$cluster_name}{"datastore"}{$shared_datastore_name}{"iorm"}{"sizeNormalizedDatastoreLatency"} = $middsLegacylatencyuuid;
						$clusterCarbonHash->{$vmware_server_name}{$datacentre_name}{$cluster_name}{"datastore"}{$shared_datastore_name}{"iorm"}{"datastoreIops"} = $middsLegacyiopsuuid;

					}
				}
			### } elsif ($cluster_datastore_view->summary->accessible && !$cluster_datastore_view->summary->multipleHostAccess) {
			### 	my $unshared_datastore_name = nameCleaner($cluster_datastore_view->summary->name);

			### 	my $unshared_datastore_uncommitted = 0;
			### 	if ($cluster_datastore_view->summary->uncommitted) {
			### 		$unshared_datastore_uncommitted = $cluster_datastore_view->summary->uncommitted;
			### 	}
			###		$clusterCarbonHash->{$vmware_server_name}{$datacentre_name}{$cluster_name}{"UNdatastore"}{$unshared_datastore_name}{"summary"}{"capacity"} = $cluster_datastore_view->summary->capacity;
			###		$clusterCarbonHash->{$vmware_server_name}{$datacentre_name}{$cluster_name}{"UNdatastore"}{$unshared_datastore_name}{"summary"}{"freeSpace"} = $cluster_datastore_view->summary->freeSpace;
			###		$clusterCarbonHash->{$vmware_server_name}{$datacentre_name}{$cluster_name}{"UNdatastore"}{$unshared_datastore_name}{"summary"}{"uncommitted"} = $unshared_datastore_uncommitted;
			}
		}

		if ($cluster_datastores_count > 0) {
			my $cluster_datastores_utilization = (sum(@cluster_datastores_capacity) - sum(@cluster_datastores_freeSpace)) * 100 / sum(@cluster_datastores_capacity);

			$clusterCarbonHash->{$vmware_server_name}{$datacentre_name}{$cluster_name}{"superstats"}{"datastore"}{"count"} = $cluster_datastores_count;
			$clusterCarbonHash->{$vmware_server_name}{$datacentre_name}{$cluster_name}{"superstats"}{"datastore"}{"capacity"} = sum(@cluster_datastores_capacity);
			$clusterCarbonHash->{$vmware_server_name}{$datacentre_name}{$cluster_name}{"superstats"}{"datastore"}{"freeSpace"} = sum(@cluster_datastores_freeSpace);
			$clusterCarbonHash->{$vmware_server_name}{$datacentre_name}{$cluster_name}{"superstats"}{"datastore"}{"utilization"} = $cluster_datastores_utilization;
			$clusterCarbonHash->{$vmware_server_name}{$datacentre_name}{$cluster_name}{"superstats"}{"datastore"}{"uncommitted"} = sum(@cluster_datastores_uncommitted);
			$clusterCarbonHash->{$vmware_server_name}{$datacentre_name}{$cluster_name}{"superstats"}{"datastore"}{"max_latency"} = max(@cluster_datastores_latency);
			$clusterCarbonHash->{$vmware_server_name}{$datacentre_name}{$cluster_name}{"superstats"}{"datastore"}{"mid_latency"} = median(@cluster_datastores_latency);
			$clusterCarbonHash->{$vmware_server_name}{$datacentre_name}{$cluster_name}{"superstats"}{"datastore"}{"iops"} = sum(@cluster_datastores_iops);
		}

		my $clusterCarbonHashTimed = {time() => $clusterCarbonHash};
		$graphite->send(path => "vmw", data => $clusterCarbonHashTimed);

	}

	foreach my $pod_view (@$all_pod_views) {
		if ($pod_view->childEntity) {	
			my $pod_name = nameCleaner($pod_view->name);

			my $datacentre_name = nameCleaner(getRootDc $pod_view);

			$logger->info("[INFO] Processing vCenter $vmware_server pod $pod_name in datacenter $datacentre_name");

			my @pod_datastores_views = ();
			my $pod_datastores_moref = $pod_view->childEntity;
			foreach my $pod_datastore_moref (@$pod_datastores_moref) {
				if ($all_datastore_views_table{$pod_datastore_moref->{'value'}}) {
					push (@pod_datastores_views,$all_datastore_views_table{$pod_datastore_moref->{'value'}});
				}
			}

			my @pod_datastores_uncommitted = ();
			foreach my $pod_datastores_view (@pod_datastores_views) {
				my $pod_datastore_uncommitted = 0;
				if ($pod_datastores_view->summary->uncommitted) {
					$pod_datastore_uncommitted = $pod_datastores_view->summary->uncommitted;
				}
				push (@pod_datastores_uncommitted,$pod_datastore_uncommitted);
			}

			my $pod_summary = $pod_view->{'summary'};
			my $pod_view_h = {
				time() => {
					"$vmware_server_name.$datacentre_name.$pod_name" . ".summary.capacity", $pod_summary->capacity,
					"$vmware_server_name.$datacentre_name.$pod_name" . ".summary.freeSpace", $pod_summary->freeSpace,
					"$vmware_server_name.$datacentre_name.$pod_name" . ".summary.uncommitted", sum(@pod_datastores_uncommitted),
				},
			};
			$graphite->send(path => "pod", data => $pod_view_h);
		}
	}

	if (!$BFG_MODE) {
		$logger->info("[INFO] Processing vCenter $vmware_server standalone hosts");

		foreach my $StandaloneComputeResource (@$all_compute_views) {

			eval {

				my $datacentre_name = nameCleaner(getRootDc $StandaloneComputeResource);

				my @StandaloneComputeResourceHosts = $StandaloneComputeResource->host;

				my $StandaloneResourceVMHost = $all_host_views_table{$StandaloneComputeResourceHosts[0][0]->value};

				if (!defined $StandaloneResourceVMHost or $StandaloneResourceVMHost->{'runtime.connectionState'}->val ne "connected") {next;}

				my $StandaloneResourcePool = $all_cluster_root_pool_views_table{$StandaloneComputeResource->{'mo_ref'}->value};

				my $StandaloneResourceVMHostName = $StandaloneResourceVMHost->{'config.network.dnsConfig.hostName'};
				if ($StandaloneResourceVMHostName eq "localhost") {
					my $StandaloneResourceVMHostVmk0 = $StandaloneResourceVMHost->{'config.network.vnic'}[0];
					my $StandaloneResourceVMHostVmk0Ip = $StandaloneResourceVMHostVmk0->spec->ip->ipAddress;
					$StandaloneResourceVMHostVmk0Ip =~ s/[ .]/_/g;
					$StandaloneResourceVMHostName = $StandaloneResourceVMHostVmk0Ip;
				}

				# https://www.tutorialspoint.com/perl/perl_switch_statement.htm #ToClean
				my $StandaloneResourceVMHost_status = $StandaloneResourceVMHost->{'overallStatus'}->val;
				my $StandaloneResourceVMHost_status_val = 0;
					if ($StandaloneResourceVMHost_status eq "green") {
						$StandaloneResourceVMHost_status_val = 1;
					} elsif ($StandaloneResourceVMHost_status eq "yellow") {
						$StandaloneResourceVMHost_status_val = 2;
					} elsif ($StandaloneResourceVMHost_status eq "red") {
						$StandaloneResourceVMHost_status_val = 3;
					} elsif ($StandaloneResourceVMHost_status eq "gray") {
						$StandaloneResourceVMHost_status_val = 0;
					}

				my $StandaloneResourceCarbonHash = ();

				$StandaloneResourceCarbonHash->{$vmware_server_name}{$datacentre_name}{$StandaloneResourceVMHostName}{"quickstats"}{"mem"}{"ballooned"} = $StandaloneResourcePool->{'summary.quickStats'}->balloonedMemory;
				$StandaloneResourceCarbonHash->{$vmware_server_name}{$datacentre_name}{$StandaloneResourceVMHostName}{"quickstats"}{"mem"}{"compressed"} = $StandaloneResourcePool->{'summary.quickStats'}->compressedMemory;
				$StandaloneResourceCarbonHash->{$vmware_server_name}{$datacentre_name}{$StandaloneResourceVMHostName}{"quickstats"}{"mem"}{"consumedOverhead"} = $StandaloneResourcePool->{'summary.quickStats'}->consumedOverheadMemory;
				$StandaloneResourceCarbonHash->{$vmware_server_name}{$datacentre_name}{$StandaloneResourceVMHostName}{"quickstats"}{"mem"}{"guest"} = $StandaloneResourcePool->{'summary.quickStats'}->guestMemoryUsage;
				$StandaloneResourceCarbonHash->{$vmware_server_name}{$datacentre_name}{$StandaloneResourceVMHostName}{"quickstats"}{"mem"}{"usage"} = $StandaloneResourcePool->{'summary.quickStats'}->hostMemoryUsage;
				$StandaloneResourceCarbonHash->{$vmware_server_name}{$datacentre_name}{$StandaloneResourceVMHostName}{"quickstats"}{"cpu"}{"demand"} = $StandaloneResourcePool->{'summary.quickStats'}->overallCpuDemand;
				$StandaloneResourceCarbonHash->{$vmware_server_name}{$datacentre_name}{$StandaloneResourceVMHostName}{"quickstats"}{"cpu"}{"usage"} = $StandaloneResourcePool->{'summary.quickStats'}->overallCpuUsage;
				# $StandaloneResourceCarbonHash->{$vmware_server_name}{$datacentre_name}{$StandaloneResourceVMHostName}{"quickstats"}{"mem"}{"overhead"} = $StandaloneResourcePool->{'summary.quickStats'}->overheadMemory;
				$StandaloneResourceCarbonHash->{$vmware_server_name}{$datacentre_name}{$StandaloneResourceVMHostName}{"quickstats"}{"mem"}{"private"} = $StandaloneResourcePool->{'summary.quickStats'}->privateMemory;
				$StandaloneResourceCarbonHash->{$vmware_server_name}{$datacentre_name}{$StandaloneResourceVMHostName}{"quickstats"}{"mem"}{"shared"} = $StandaloneResourcePool->{'summary.quickStats'}->sharedMemory;
				$StandaloneResourceCarbonHash->{$vmware_server_name}{$datacentre_name}{$StandaloneResourceVMHostName}{"quickstats"}{"mem"}{"swapped"} = $StandaloneResourcePool->{'summary.quickStats'}->swappedMemory;
				$StandaloneResourceCarbonHash->{$vmware_server_name}{$datacentre_name}{$StandaloneResourceVMHostName}{"quickstats"}{"mem"}{"effective"} = $StandaloneComputeResource->summary->effectiveMemory;
				$StandaloneResourceCarbonHash->{$vmware_server_name}{$datacentre_name}{$StandaloneResourceVMHostName}{"quickstats"}{"mem"}{"total"} = $StandaloneComputeResource->summary->totalMemory;
				$StandaloneResourceCarbonHash->{$vmware_server_name}{$datacentre_name}{$StandaloneResourceVMHostName}{"quickstats"}{"cpu"}{"effective"} = $StandaloneComputeResource->summary->effectiveCpu;
				$StandaloneResourceCarbonHash->{$vmware_server_name}{$datacentre_name}{$StandaloneResourceVMHostName}{"quickstats"}{"cpu"}{"total"} = $StandaloneComputeResource->summary->totalCpu;
				$StandaloneResourceCarbonHash->{$vmware_server_name}{$datacentre_name}{$StandaloneResourceVMHostName}{"quickstats"}{"overallStatus"} = $StandaloneResourceVMHost_status_val;

				$logger->info("[INFO] Processing vCenter $vmware_server standalone host $StandaloneResourceVMHostName datastores in datacenter $datacentre_name");

				my @StandaloneResourceDatastoresViews = ();
				my $StandaloneResourceDatastoresMoref = $StandaloneComputeResource->datastore;
				foreach my $StandaloneComputeResourceDatastoreMoref (@$StandaloneResourceDatastoresMoref) {
					if ($all_datastore_views_table{$StandaloneComputeResourceDatastoreMoref->{'value'}}) {
						push (@StandaloneResourceDatastoresViews,$all_datastore_views_table{$StandaloneComputeResourceDatastoreMoref->{'value'}})
					}
				}

				foreach my $StandaloneResourceDatastore (@StandaloneResourceDatastoresViews) {
					if ($StandaloneResourceDatastore->summary->accessible) {
						my $StandaloneResourceDatastore_name = nameCleaner($StandaloneResourceDatastore->summary->name);
						my $StandaloneResourceDatastore_uncommitted = 0;
						if ($StandaloneResourceDatastore->summary->uncommitted) {
							$StandaloneResourceDatastore_uncommitted = $StandaloneResourceDatastore->summary->uncommitted;
						}

						$StandaloneResourceCarbonHash->{$vmware_server_name}{$datacentre_name}{$StandaloneResourceVMHostName}{"datastore"}{$StandaloneResourceDatastore_name}{"summary"}{"capacity"} = $StandaloneResourceDatastore->summary->capacity;
						$StandaloneResourceCarbonHash->{$vmware_server_name}{$datacentre_name}{$StandaloneResourceVMHostName}{"datastore"}{$StandaloneResourceDatastore_name}{"summary"}{"freeSpace"} = $StandaloneResourceDatastore->summary->freeSpace;
						$StandaloneResourceCarbonHash->{$vmware_server_name}{$datacentre_name}{$StandaloneResourceVMHostName}{"datastore"}{$StandaloneResourceDatastore_name}{"summary"}{"uncommitted"} = $StandaloneResourceDatastore_uncommitted;
					}
				}

				foreach my $StandaloneResourceVMHost_vmnic (@{$StandaloneResourceVMHost->{'config.network.pnic'}}) {
					if ($StandaloneResourceVMHost_vmnic->linkSpeed && $StandaloneResourceVMHost_vmnic->linkSpeed->speedMb >= 100) {
						my $StandaloneResourceVMHost_vmnic_name = $StandaloneResourceVMHost_vmnic->device;
						my $NetbytesRx = $hostmultistats{$perfCntr{"net.bytesRx.average"}->key}{$StandaloneResourceVMHost->{'mo_ref'}->value}{$StandaloneResourceVMHost_vmnic_name};
						my $NetbytesTx = $hostmultistats{$perfCntr{"net.bytesTx.average"}->key}{$StandaloneResourceVMHost->{'mo_ref'}->value}{$StandaloneResourceVMHost_vmnic_name};

						if (defined($NetbytesRx) && defined($NetbytesTx)) {

							$StandaloneResourceCarbonHash->{$vmware_server_name}{$datacentre_name}{$StandaloneResourceVMHostName}{"net"}{$StandaloneResourceVMHost_vmnic_name}{"bytesRx"} = $NetbytesRx;
							$StandaloneResourceCarbonHash->{$vmware_server_name}{$datacentre_name}{$StandaloneResourceVMHostName}{"net"}{$StandaloneResourceVMHost_vmnic_name}{"bytesTx"} = $NetbytesTx;
							$StandaloneResourceCarbonHash->{$vmware_server_name}{$datacentre_name}{$StandaloneResourceVMHostName}{"net"}{$StandaloneResourceVMHost_vmnic_name}{"linkSpeed"} = $StandaloneResourceVMHost_vmnic->linkSpeed->speedMb; #ToClean?
						}
					}
				}

			foreach my $StandaloneResourceVMHost_vmhba (@{$StandaloneResourceVMHost->{'config.storageDevice.hostBusAdapter'}}) {
					my $HbabytesRead = $hostmultistats{$perfCntr{"storageAdapter.read.average"}->key}{$StandaloneResourceVMHost->{'mo_ref'}->value}{$StandaloneResourceVMHost_vmhba->device};
					my $HbabytesWrite = $hostmultistats{$perfCntr{"storageAdapter.write.average"}->key}{$StandaloneResourceVMHost->{'mo_ref'}->value}{$StandaloneResourceVMHost_vmhba->device};
					if (defined($HbabytesRead) && defined($HbabytesWrite)) {
						my $StandaloneResourceVMHost_vmhba_name = $StandaloneResourceVMHost_vmhba->device;

						$StandaloneResourceCarbonHash->{$vmware_server_name}{$datacentre_name}{$StandaloneResourceVMHostName}{"hba"}{$StandaloneResourceVMHost_vmhba_name}{"bytesRead"} = $HbabytesRead;
						$StandaloneResourceCarbonHash->{$vmware_server_name}{$datacentre_name}{$StandaloneResourceVMHostName}{"hba"}{$StandaloneResourceVMHost_vmhba_name}{"bytesWrite"} = $HbabytesWrite;
					}
			}

			my $StandaloneResourceVMHost_host_sensors = $StandaloneResourceVMHost->{'summary.runtime.healthSystemRuntime.systemHealthInfo.numericSensorInfo'};
			# https://vdc-download.vmware.com/vmwb-repository/dcr-public/b50dcbbf-051d-4204-a3e7-e1b618c1e384/538cf2ec-b34f-4bae-a332-3820ef9e7773/vim.host.NumericSensorInfo.html
			
			foreach my $StandaloneResourceVMHost_host_sensor (@$StandaloneResourceVMHost_host_sensors) {
				if ($StandaloneResourceVMHost_host_sensor->name && $StandaloneResourceVMHost_host_sensor->sensorType && $StandaloneResourceVMHost_host_sensor->currentReading && $StandaloneResourceVMHost_host_sensor->unitModifier) {
					my $StandaloneResourceVMHost_host_sensor_computed_reading = $StandaloneResourceVMHost_host_sensor->currentReading * (10**$StandaloneResourceVMHost_host_sensor->unitModifier);
					my $StandaloneResourceVMHost_host_sensor_name = nameCleaner($StandaloneResourceVMHost_host_sensor->name);
					$StandaloneResourceCarbonHash->{$vmware_server_name}{$datacentre_name}{$StandaloneResourceVMHostName}{"sensor"}{$StandaloneResourceVMHost_host_sensor->sensorType}{$StandaloneResourceVMHost_host_sensor_name} = $StandaloneResourceVMHost_host_sensor_computed_reading;
				}
			}

				my @StandaloneResourceVMHostVmsMoref = ();
				if ($StandaloneResourceVMHost->vm && (scalar($StandaloneResourceVMHost->vm) > 0)) {
					push (@StandaloneResourceVMHostVmsMoref,$StandaloneResourceVMHost->vm);
				}

				my @StandaloneResourceVMHostVmsViews = ();
				if (scalar(@StandaloneResourceVMHostVmsMoref) > 0) {
					my @StandaloneResourceVMHostVmsMorefs = map {@$_} @StandaloneResourceVMHostVmsMoref;
					foreach my $StandaloneResourceVMHostVmMoref (@StandaloneResourceVMHostVmsMorefs) {
						push (@StandaloneResourceVMHostVmsViews,$all_vm_views_table{$StandaloneResourceVMHostVmMoref->{'value'}});
					}
				}

				if (scalar(@StandaloneResourceVMHostVmsViews) > 0) {

					# my $Standalone_vm_views_vcpus = 0;
					my $Standalone_vm_views_on = 0;
					my $Standalone_vm_views_files_dedup = {};

					$logger->info("[INFO] Processing vCenter $vmware_server standalone host $StandaloneResourceVMHostName vms in datacenter $datacentre_name");

					foreach my $Standalone_vm_view (@StandaloneResourceVMHostVmsViews) {

						my $Standalone_vm_view_name = nameCleaner($Standalone_vm_view->name);

						if ($Standalone_vm_view->{'summary.runtime.powerState'}->{'val'} eq "poweredOn") {

							# $Standalone_vm_views_vcpus += $Standalone_vm_view->{'config.hardware.numCPU'};
							$Standalone_vm_views_on++;

							my $Standalone_vm_view_files = $Standalone_vm_view->{'layoutEx.file'};
							### http://pubs.vmware.com/vsphere-60/topic/com.vmware.wssdk.apiref.doc/vim.vm.FileLayoutEx.FileType.html

							my $Standalone_vm_view_snap_size = 0;
							my $Standalone_vm_view_has_snap = 0;

							if ($Standalone_vm_view->snapshot) {
								$Standalone_vm_view_has_snap = 1;
							}

							my $Standalone_vm_view_num_vdisk = $Standalone_vm_view->{'summary.config.numVirtualDisks'};
							my $Standalone_vm_view_real_vdisk = 0;
							

							foreach my $Standalone_vm_view_file (@$Standalone_vm_view_files) {
								if ($Standalone_vm_view_file->type eq "diskDescriptor") {
									$Standalone_vm_view_real_vdisk++;
								}
							}

							if (($Standalone_vm_view_real_vdisk > $Standalone_vm_view_num_vdisk)) {
								$Standalone_vm_view_has_snap = 1;
							}

							foreach my $Standalone_vm_view_file (@$Standalone_vm_view_files) {
								if (!$Standalone_vm_views_files_dedup->{$Standalone_vm_view_file->name}) { #would need name & moref
									$Standalone_vm_views_files_dedup->{$Standalone_vm_view_file->name} = $Standalone_vm_view_file->size;
									if (($Standalone_vm_view_has_snap == 1) && ($Standalone_vm_view_file->name =~ /-[0-9]{6}-delta\.vmdk/ or $Standalone_vm_view_file->name =~ /-[0-9]{6}-sesparse\.vmdk/)) {
										$Standalone_vm_view_snap_size += $Standalone_vm_view_file->size;
									} elsif (($Standalone_vm_view_has_snap == 1) && ($Standalone_vm_view_file->name =~ /-[0-9]{6}\.vmdk/)) {
										$Standalone_vm_view_snap_size += $Standalone_vm_view_file->size;
									}
								}
							}

							if ($Standalone_vm_view_snap_size > 0) {
								$StandaloneResourceCarbonHash->{$vmware_server_name}{$datacentre_name}{$StandaloneResourceVMHostName}{"vm"}{$Standalone_vm_view_name}{"storage"}{"delta"} = $Standalone_vm_view_snap_size;
							}

							my $Standalone_vm_view_CpuUtilization = 0;
							if ($Standalone_vm_view->{'runtime.maxCpuUsage'} > 0 && $Standalone_vm_view->{'summary.quickStats.overallCpuUsage'} > 0) {
								$Standalone_vm_view_CpuUtilization = $Standalone_vm_view->{'summary.quickStats.overallCpuUsage'} * 100 / $Standalone_vm_view->{'runtime.maxCpuUsage'};
							}

							my $Standalone_vm_view_MemUtilization = 0;
							if ($Standalone_vm_view->{'summary.quickStats.guestMemoryUsage'} > 0 && $Standalone_vm_view->{'runtime.maxMemoryUsage'} > 0) {
								$Standalone_vm_view_MemUtilization = $Standalone_vm_view->{'summary.quickStats.guestMemoryUsage'} * 100 / $Standalone_vm_view->{'runtime.maxMemoryUsage'};
							}

							$StandaloneResourceCarbonHash->{$vmware_server_name}{$datacentre_name}{$StandaloneResourceVMHostName}{"vm"}{$Standalone_vm_view_name}{"quickstats"}{"overallCpuUsage"} = $Standalone_vm_view->{'summary.quickStats.overallCpuUsage'};
							$StandaloneResourceCarbonHash->{$vmware_server_name}{$datacentre_name}{$StandaloneResourceVMHostName}{"vm"}{$Standalone_vm_view_name}{"quickstats"}{"overallCpuDemand"} = $Standalone_vm_view->{'summary.quickStats.overallCpuDemand'};
							$StandaloneResourceCarbonHash->{$vmware_server_name}{$datacentre_name}{$StandaloneResourceVMHostName}{"vm"}{$Standalone_vm_view_name}{"quickstats"}{"HostMemoryUsage"} = $Standalone_vm_view->{'summary.quickStats.hostMemoryUsage'};
							$StandaloneResourceCarbonHash->{$vmware_server_name}{$datacentre_name}{$StandaloneResourceVMHostName}{"vm"}{$Standalone_vm_view_name}{"quickstats"}{"GuestMemoryUsage"} = $Standalone_vm_view->{'summary.quickStats.guestMemoryUsage'};
							$StandaloneResourceCarbonHash->{$vmware_server_name}{$datacentre_name}{$StandaloneResourceVMHostName}{"vm"}{$Standalone_vm_view_name}{"storage"}{"committed"} = $Standalone_vm_view->{'summary.storage.committed'};
							$StandaloneResourceCarbonHash->{$vmware_server_name}{$datacentre_name}{$StandaloneResourceVMHostName}{"vm"}{$Standalone_vm_view_name}{"storage"}{"uncommitted"} = $Standalone_vm_view->{'summary.storage.uncommitted'};
							$StandaloneResourceCarbonHash->{$vmware_server_name}{$datacentre_name}{$StandaloneResourceVMHostName}{"vm"}{$Standalone_vm_view_name}{"runtime"}{"CpuUtilization"} = $Standalone_vm_view_CpuUtilization;
							$StandaloneResourceCarbonHash->{$vmware_server_name}{$datacentre_name}{$StandaloneResourceVMHostName}{"vm"}{$Standalone_vm_view_name}{"runtime"}{"MemUtilization"} = $Standalone_vm_view_MemUtilization;


							if ($Standalone_vm_view->{'summary.quickStats.balloonedMemory'} > 0) {
								$StandaloneResourceCarbonHash->{$vmware_server_name}{$datacentre_name}{$StandaloneResourceVMHostName}{"vm"}{$Standalone_vm_view_name}{"quickstats"}{"BalloonedMemory"} = $Standalone_vm_view->{'summary.quickStats.balloonedMemory'};
							}

							if ($Standalone_vm_view->{'summary.quickStats.compressedMemory'} > 0) {
								$StandaloneResourceCarbonHash->{$vmware_server_name}{$datacentre_name}{$StandaloneResourceVMHostName}{"vm"}{$Standalone_vm_view_name}{"quickstats"}{"CompressedMemory"} = $Standalone_vm_view->{'summary.quickStats.compressedMemory'};
							}

							if ($Standalone_vm_view->{'summary.quickStats.swappedMemory'} > 0) {
								$StandaloneResourceCarbonHash->{$vmware_server_name}{$datacentre_name}{$StandaloneResourceVMHostName}{"vm"}{$Standalone_vm_view_name}{"quickstats"}{"SwappedMemory"} = $Standalone_vm_view->{'summary.quickStats.swappedMemory'};
							}

							if ($vmmultistats{$perfCntr{"cpu.ready.summation"}->key}{$Standalone_vm_view->{'mo_ref'}->value}{""}) {
								my $vmreadyavg = $vmmultistats{$perfCntr{"cpu.ready.summation"}->key}{$Standalone_vm_view->{'mo_ref'}->value}{""} / $Standalone_vm_view->{'config.hardware.numCPU'} / 20000 * 100;
								### https://kb.vmware.com/kb/2002181
								$StandaloneResourceCarbonHash->{$vmware_server_name}{$datacentre_name}{$StandaloneResourceVMHostName}{"vm"}{$Standalone_vm_view_name}{"fatstats"}{"cpu_ready_summation"} = $vmreadyavg;
							}

							if ($vmmultistats{$perfCntr{"cpu.wait.summation"}->key}{$Standalone_vm_view->{'mo_ref'}->value}{""} && $vmmultistats{$perfCntr{"cpu.idle.summation"}->key}{$Standalone_vm_view->{'mo_ref'}->value}{""}) {
								my $vmwaitavg = ($vmmultistats{$perfCntr{"cpu.wait.summation"}->key}{$Standalone_vm_view->{'mo_ref'}->value}{""} - $vmmultistats{$perfCntr{"cpu.idle.summation"}->key}{$Standalone_vm_view->{'mo_ref'}->value}{""}) / $Standalone_vm_view->{'config.hardware.numCPU'} / 20000 * 100;
								### https://code.vmware.com/apis/358/vsphere#/doc/cpu_counters.html
								$StandaloneResourceCarbonHash->{$vmware_server_name}{$datacentre_name}{$StandaloneResourceVMHostName}{"vm"}{$Standalone_vm_view_name}{"fatstats"}{"cpu_wait_no_idle"} = $vmwaitavg;
							}

							if ($vmmultistats{$perfCntr{"cpu.latency.average"}->key}{$Standalone_vm_view->{'mo_ref'}->value}{""}) {
								my $vmlatencyval = $vmmultistats{$perfCntr{"cpu.latency.average"}->key}{$Standalone_vm_view->{'mo_ref'}->value}{""};
								$StandaloneResourceCarbonHash->{$vmware_server_name}{$datacentre_name}{$StandaloneResourceVMHostName}{"vm"}{$Standalone_vm_view_name}{"fatstats"}{"cpu_latency_average"} = $vmlatencyval;
							}

							if ($vmmultistats{$perfCntr{"disk.maxTotalLatency.latest"}->key}{$Standalone_vm_view->{'mo_ref'}->value}{""}) {
								my $vmmaxtotallatencyval = $vmmultistats{$perfCntr{"disk.maxTotalLatency.latest"}->key}{$Standalone_vm_view->{'mo_ref'}->value}{""};
								$StandaloneResourceCarbonHash->{$vmware_server_name}{$datacentre_name}{$StandaloneResourceVMHostName}{"vm"}{$Standalone_vm_view_name}{"fatstats"}{"maxTotalLatency"} = $vmmaxtotallatencyval;
							}

							if ($vmmultistats{$perfCntr{"disk.usage.average"}->key}{$Standalone_vm_view->{'mo_ref'}->value}{""}) {
								my $vmdiskusageval = $vmmultistats{$perfCntr{"disk.usage.average"}->key}{$Standalone_vm_view->{'mo_ref'}->value}{""};
								$StandaloneResourceCarbonHash->{$vmware_server_name}{$datacentre_name}{$StandaloneResourceVMHostName}{"vm"}{$Standalone_vm_view_name}{"fatstats"}{"diskUsage"} = $vmdiskusageval;
							}

							if ($vmmultistats{$perfCntr{"net.usage.average"}->key}{$Standalone_vm_view->{'mo_ref'}->value}{""}) {
								my $vmnetusageval = $vmmultistats{$perfCntr{"net.usage.average"}->key}{$Standalone_vm_view->{'mo_ref'}->value}{""};
								$StandaloneResourceCarbonHash->{$vmware_server_name}{$datacentre_name}{$StandaloneResourceVMHostName}{"vm"}{$Standalone_vm_view_name}{"fatstats"}{"netUsage"} = $vmnetusageval;
							}

						} elsif ($Standalone_vm_view->{'summary.runtime.powerState'}->{'val'} eq "poweredOff") {

							my $Standalone_vm_view_off = $Standalone_vm_view;

							my $Standalone_vm_view_off_name = nameCleaner($Standalone_vm_view_off->name);

							my $Standalone_vm_view_off_files = $Standalone_vm_view_off->{'layoutEx.file'};
							### http://pubs.vmware.com/vsphere-60/topic/com.vmware.wssdk.apiref.doc/vim.vm.FileLayoutEx.FileType.html

							my $Standalone_vm_view_off_snap_size = 0;
							my $Standalone_vm_view_off_has_snap = 0;

							if ($Standalone_vm_view_off->snapshot) {
								$Standalone_vm_view_off_has_snap = 1;
							}

							my $Standalone_vm_view_off_num_vdisk = $Standalone_vm_view_off->{'summary.config.numVirtualDisks'};
							my $Standalone_vm_view_off_real_vdisk = 0;

							foreach my $Standalone_vm_view_off_file (@$Standalone_vm_view_off_files) {
								if ($Standalone_vm_view_off_file->type eq "diskDescriptor") {
									$Standalone_vm_view_off_real_vdisk++;
								}
							}

							if (($Standalone_vm_view_off_real_vdisk > $Standalone_vm_view_off_num_vdisk)) {
								$Standalone_vm_view_off_has_snap = 1;
							}

							foreach my $Standalone_vm_view_off_file (@$Standalone_vm_view_off_files) {
								if (!$Standalone_vm_views_files_dedup->{$Standalone_vm_view_off_file->name}) { #would need name & moref
									$Standalone_vm_views_files_dedup->{$Standalone_vm_view_off_file->name} = $Standalone_vm_view_off_file->size;
									if (($Standalone_vm_view_off_has_snap == 1) && ($Standalone_vm_view_off_file->name =~ /-[0-9]{6}-delta\.vmdk/ or $Standalone_vm_view_off_file->name =~ /-[0-9]{6}-sesparse\.vmdk/)) {
										$Standalone_vm_view_off_snap_size += $Standalone_vm_view_off_file->size;
									} elsif (($Standalone_vm_view_off_has_snap == 1) && ($Standalone_vm_view_off_file->name =~ /-[0-9]{6}\.vmdk/)) {
											$Standalone_vm_view_off_snap_size += $Standalone_vm_view_off_file->size;
									}
								}
							}

							if ($Standalone_vm_view_off_snap_size > 0) {
								$StandaloneResourceCarbonHash->{$vmware_server_name}{$datacentre_name}{$StandaloneResourceVMHostName}{"vm"}{$Standalone_vm_view_off_name}{"storage.delta"} = $Standalone_vm_view_off_snap_size;
							}

							$StandaloneResourceCarbonHash->{$vmware_server_name}{$datacentre_name}{$StandaloneResourceVMHostName}{"vm"}{$Standalone_vm_view_off_name}{"storage.committed"} = $Standalone_vm_view_off->{'summary.storage.committed'};
							$StandaloneResourceCarbonHash->{$vmware_server_name}{$datacentre_name}{$StandaloneResourceVMHostName}{"vm"}{$Standalone_vm_view_off_name}{"storage.uncommitted"} = $Standalone_vm_view_off->{'summary.storage.uncommitted'};

						}

						$StandaloneResourceCarbonHash->{$vmware_server_name}{$datacentre_name}{$StandaloneResourceVMHostName}{"runtime"}{"vm"}{"total"} = scalar(@StandaloneResourceVMHostVmsViews);
						$StandaloneResourceCarbonHash->{$vmware_server_name}{$datacentre_name}{$StandaloneResourceVMHostName}{"runtime"}{"vm"}{"on"} = $Standalone_vm_views_on;

						my $StandaloneResourceCarbonHashTimed = {time() => $StandaloneResourceCarbonHash};
						$graphite->send(path => "esx", data => $StandaloneResourceCarbonHashTimed);

					}
				}
			};
		}
	}

	if (%vcmultistats) {
		my $vcresCarbonHash = ();

		my $vcres_virtualmemusage = $vcmultistats{$perfCntr{"vcResources.virtualmemusage.average"}->key}{"group-d1"}{""};
		$vcresCarbonHash->{$vmware_server_name}{"vi"}{"vcres"}{"virtualmemusage"} = $vcres_virtualmemusage;
		my $vcres_physicalmemusage = $vcmultistats{$perfCntr{"vcResources.physicalmemusage.average"}->key}{"group-d1"}{""};
		$vcresCarbonHash->{$vmware_server_name}{"vi"}{"vcres"}{"physicalmemusage"} = $vcres_physicalmemusage;
		my $vcres_systemcpuusage = $vcmultistats{$perfCntr{"vcResources.systemcpuusage.average"}->key}{"group-d1"}{""};
		$vcresCarbonHash->{$vmware_server_name}{"vi"}{"vcres"}{"systemcpuusage"} = $vcres_systemcpuusage;

		my $vcresCarbonHashTimed = {time() => $vcresCarbonHash};
		$graphite->send(path => "vi", data => $vcresCarbonHashTimed);
	}

	my $sessionCount = 0;
	my $sessionListH = ();
	my $sessionCarbonHash;
	my $sessionMgr = (Vim::get_view(mo_ref => $service_content->sessionManager, properties => ['sessionList']));
	my $sessionList = $sessionMgr->sessionList;

	if ($sessionList) {
		foreach my $sessionActive (@$sessionList) {
			$sessionListH->{$sessionActive->userName}++;
		}

		$sessionCount = scalar(@$sessionList);
		$sessionCarbonHash->{$vmware_server_name}{"vi"}{"exec"}{"sessionCount"} = $sessionCount;

		foreach my $sessionListNode (keys %{$sessionListH}) {
			my $sessionListNodeClean = lc $sessionListNode;
			$sessionListNodeClean =~ s/[ .]/_/g;
			$sessionListNodeClean = NFD($sessionListNodeClean);
			$sessionListNodeClean =~ s/[^[:ascii:]]//g;
			$sessionListNodeClean =~ s/[^A-Za-z0-9-_]/_/g;
			$sessionCarbonHash->{$vmware_server_name}{"vi"}{"exec"}{"sessionList"}{$sessionListNodeClean} = $sessionListH->{$sessionListNode};
		}

		my $sessionCarbonHashTimed = {time() => $sessionCarbonHash};
		$graphite->send(path => "vi", data => $sessionCarbonHashTimed);

	}

	$logger->info("[INFO] Processing vCenter $vmware_server events");

	eval {
		my $eventMgr = (Vim::get_view(mo_ref => $service_content->eventManager, properties => ['latestEvent', 'description']));

		my $eventCount = 0;
		my $eventCarbonHash = ();

		my $eventLast = $eventMgr->latestEvent;
		$eventCount = $eventLast->key;

		if ($eventCount > 0) {

			## https://github.com/lamw/vghetto-scripts/blob/master/perl/provisionedVMReport.pl
			my $eventsInfo = $eventMgr->description->eventInfo;
			my @filteredEvents = ();
			if ($eventsInfo) {
				foreach my $eventInfo (@$eventsInfo) {
					if ($eventInfo->key =~ m/(EventEx|ExtendedEvent)/) {
						if ((split(/\|/, $eventInfo->fullFormat))[0] =~ m/(nonviworkload|io\.latency|esx\.audit\.net\.firewall\.config\.changed)/) {
						} else {
							if ((split(/\|/, $eventInfo->fullFormat))[0] =~ m/(esx\.|com\.vmware\.vc\.ha|com\.vmware\.vc\.HA|vprob\.|com\.vmware\.vsan|vob\.)/) {
								push @filteredEvents,(split(/\|/, $eventInfo->fullFormat))[0];
							} elsif ((split(/\|/, $eventInfo->fullFormat))[0] =~ m/(com\.vmware\.vc\.)/ && $eventInfo->category =~ m/(warning|error)/) {
								push @filteredEvents,(split(/\|/, $eventInfo->fullFormat))[0];
							}
						}
					} else {
						if ($eventInfo->category =~ m/(warning|error)/ &&  $eventInfo->longDescription =~ m/(vim\.event\.)/) {
							push (@filteredEvents,$eventInfo->key);
						}
					}
				}
			}

			my $evtTimeSpec = EventFilterSpecByTime->new(beginTime => $vmware_server_clock_5->datetime, endTime => $vmware_server_clock->datetime);
			my $filterSpec = EventFilterSpec->new(time => $evtTimeSpec, eventTypeId => [@filteredEvents]);
			my $evtResults = $eventMgr->CreateCollectorForEvents(filter => $filterSpec);

			my $eventCollector = Vim::get_view(mo_ref => $evtResults);
			## $eventCollector->ResetCollector();
			## my $exEvents = $eventCollector->latestPage;
			my $exEvents = $eventCollector->ReadNextEvents(maxCount => 1000);
			
			my $vc_events_count_per_id = {};

			if ($exEvents) {
				foreach my $exEvent (@$exEvents) {

					if (%$exEvent{"eventTypeId"}) {
						if (%$exEvent{"datacenter"} && %$exEvent{"computeResource"}) {
							my $evt_datacentre_name = nameCleaner($exEvent->datacenter->name);
							my $evt_cluster_name = nameCleaner($exEvent->computeResource->name);

							$vc_events_count_per_id->{$evt_datacentre_name}->{$evt_cluster_name}->{$exEvent->eventTypeId} += 1;
						}
					} elsif (%$exEvent{"messageInfo"}) {
						eval {
							if (%$exEvent{"datacenter"} && %$exEvent{"computeResource"}) {
								my $evt_datacentre_name = nameCleaner($exEvent->datacenter->name);
								my $evt_cluster_name = nameCleaner($exEvent->computeResource->name);

								my $evt_msg_info = $exEvent->messageInfo;
								my $evt_msg_info_0 = @$evt_msg_info[0];
								my $evt_msg_info_id = %$evt_msg_info_0{"id"};
								my $evt_id_name = nameCleaner($evt_msg_info_id);

								$vc_events_count_per_id->{$evt_datacentre_name}->{$evt_cluster_name}->{$evt_id_name} += 1;
							}
						};
					} else {
						if (%$exEvent{"datacenter"} && %$exEvent{"computeResource"}) {
							my $exEventRef = ref($exEvent);
							my $evt_datacentre_name = nameCleaner($exEvent->datacenter->name);
							my $evt_cluster_name = nameCleaner($exEvent->computeResource->name);

							$vc_events_count_per_id->{$evt_datacentre_name}->{$evt_cluster_name}->{$exEventRef} += 1;
						}
					}
				}

				foreach my $dc_vc_event_id (keys %$vc_events_count_per_id) {
					my $clu_dc_vc_event_id_h = $vc_events_count_per_id->{$dc_vc_event_id};
					foreach my $clu_dc_vc_event_id (keys %$clu_dc_vc_event_id_h) {
						my $vc_events_count_per_id_h = $vc_events_count_per_id->{$dc_vc_event_id}->{$clu_dc_vc_event_id};
						foreach my $evt_clu_dc_vc_event_id (keys %$vc_events_count_per_id_h) {
							my $clean_evt_clu_dc_vc_event_id = $evt_clu_dc_vc_event_id;
							$clean_evt_clu_dc_vc_event_id =~ s/[ .]/_/g;
							$eventCarbonHash->{$vmware_server_name}{"vi"}{"exec"}{"ExEvent"}{$dc_vc_event_id}{$clu_dc_vc_event_id}{$clean_evt_clu_dc_vc_event_id} = $vc_events_count_per_id->{$dc_vc_event_id}->{$clu_dc_vc_event_id}->{$evt_clu_dc_vc_event_id};
						}
					}
				}
			}

			$eventCollector->DestroyCollector;

			my $eventCarbonHashTimed = {time() => $eventCarbonHash};
			$graphite->send(path => "vi", data => $eventCarbonHashTimed);

		}
	};
	if($@) {
		$logger->info("[ERROR] reset dead session file $sessionfile for vCenter $vmware_server");
		unlink $sessionfile;
	}

	# $logger->info("[INFO] Processing vCenter $vmware_server tasks");
	# my $taskCount;
	# eval {
		# my $taskMgr = (Vim::get_view(mo_ref => Vim::get_service_content()->taskManager));
		# my $recentTask = $taskMgr->recentTask;
		# if ($recentTask) {
		# 	$taskCount = (split(/-/, @$recentTask[-1]->value))[1];

		# 	if ($taskCount > 0) {
		# 		my $taskCount_h = {
		# 			time() => {
		# 				"$vmware_server_name.vi" . ".exec.tasks", $taskCount,
		# 			},
		# 		};
		# 		$graphite->send(path => "vi", data => $taskCount_h);
		# 	}
		# }
	# if($@) {
	# 	$logger->info("[ERROR] reset dead session file $sessionfile for vCenter $vmware_server");
	# 	unlink $sessionfile;
	# }

	my $exec_duration = time - $exec_start;
	my $vcenter_exec_duration_h = {
		time() => {
			"$vmware_server_name.vi" . ".exec.duration", $exec_duration,
		},
	};
	$graphite->send(path => "vi", data => $vcenter_exec_duration_h);

	$logger->info("[INFO] End processing vCenter $vmware_server");

} elsif ($apiType eq "HostAgent") {

	my $all_cluster_root_pool_views = Vim::find_entity_views(view_type => 'ResourcePool', filter => {name => qr/^Resources$/}, properties => ['summary.quickStats', 'parent']);

	my %all_cluster_root_pool_views_table = ();
	foreach my $all_cluster_root_pool_view (@$all_cluster_root_pool_views) {
		$all_cluster_root_pool_views_table{$all_cluster_root_pool_view->{'parent'}->value} = $all_cluster_root_pool_view;
		# $all_cluster_root_pool_views_table{$all_cluster_root_pool_view->{'mo_ref'}->value} = $all_cluster_root_pool_view;
	}

	my $all_compute_views = ();
	my $all_compute_res_views = Vim::find_entity_views(view_type => 'ComputeResource', properties => ['name', 'parent', 'summary', 'resourcePool', 'host', 'datastore']); ### can't filter summary more because of numVmotions properties
	foreach my $all_compute_res_view (@$all_compute_res_views) {
		if ($all_compute_res_view->{'mo_ref'}->type eq "ComputeResource") {
			push (@$all_compute_views,$all_compute_res_view);
		}
	}

	my %all_compute_views_table = ();
	foreach my $all_compute_view (@$all_compute_views) {
		$all_compute_views_table{$all_compute_view->{'mo_ref'}->value} = $all_compute_view;
	}

	my $all_host_views = Vim::find_entity_views(view_type => 'HostSystem', properties => ['config.network.pnic', 'config.network.vnic', 'config.network.dnsConfig.hostName', 'runtime.connectionState', 'summary.hardware.numCpuCores', 'summary.quickStats.overallCpuUsage', 'summary.quickStats.overallMemoryUsage', 'summary.quickStats.uptime', 'overallStatus', 'config.storageDevice.hostBusAdapter', 'vm', 'name', 'summary.runtime.healthSystemRuntime.systemHealthInfo.numericSensorInfo'], filter => {'runtime.connectionState' => "connected"});
	my %all_host_views_table = ();
	foreach my $all_host_view (@$all_host_views) {
		$all_host_views_table{$all_host_view->{'mo_ref'}->value} = $all_host_view;
	}

	my $all_datastore_views = Vim::find_entity_views(view_type => 'Datastore', properties => ['summary'], filter => {'summary.accessible' => "true"});
	my %all_datastore_views_table = ();
	foreach my $all_datastore_view (@$all_datastore_views) {
		$all_datastore_views_table{$all_datastore_view->{'mo_ref'}->value} = $all_datastore_view;
	}

	my $all_vm_views = Vim::find_entity_views(view_type => 'VirtualMachine', properties => ['name', 'runtime.maxCpuUsage', 'runtime.maxMemoryUsage', 'summary.quickStats.overallCpuUsage', 'summary.quickStats.overallCpuDemand', 'summary.quickStats.hostMemoryUsage', 'summary.quickStats.guestMemoryUsage', 'summary.quickStats.balloonedMemory', 'summary.quickStats.compressedMemory', 'summary.quickStats.swappedMemory', 'summary.storage.committed', 'summary.storage.uncommitted', 'config.hardware.numCPU', 'layoutEx.file', 'snapshot', 'runtime.host', 'summary.runtime.connectionState', 'summary.runtime.powerState', 'summary.config.numVirtualDisks', 'summary.quickStats.privateMemory', 'summary.quickStats.consumedOverheadMemory', 'summary.quickStats.sharedMemory'], filter => {'summary.runtime.connectionState' => "connected"});
	my %all_vm_views_table = ();
	foreach my $all_vm_view (@$all_vm_views) {
		$all_vm_views_table{$all_vm_view->{'mo_ref'}->value} = $all_vm_view;
	}

	my %hostmultistats = ();
	my %vmmultistats = ();

	my $hostmultimetricsstart = Time::HiRes::gettimeofday();
	my @hostmultimetrics = (
		["net", "bytesRx", "average"],
		["net", "bytesTx", "average"],
		# ["net", "droppedRx", "summation"],
		# ["net", "droppedTx", "summation"],
		# ["net", "errorsRx", "summation"],
		# ["net", "errorsTx", "summation"],
		["storageAdapter", "read", "average"],
		["storageAdapter", "write", "average"],
		# ["power", "power", "average"],
		# ["datastore", "datastoreVMObservedLatency", "latest"],
		# ["datastore", "totalWriteLatency", "average"],
		# ["datastore", "totalReadLatency", "average"],
		# ["datastore", "numberWriteAveraged", "average"],
		# ["datastore", "numberReadAveraged", "average"],
		# ["cpu", "latency", "average"],
		# ["mem", "sysUsage", "average"],
		# ["rescpu", "actav5", "latest"],
	);
	%hostmultistats = MultiQueryPerfAll($all_host_views, @hostmultimetrics);
	my $hostmultimetricsend = Time::HiRes::gettimeofday();
	my $hostmultimetricstimelapse = $hostmultimetricsend - $hostmultimetricsstart;
	$logger->info("[DEBUG] computed unmanaged host multi metrics in $hostmultimetricstimelapse sec for Unamaged host $vmware_server");

	my $vmmultimetricsstart = Time::HiRes::gettimeofday();
	my @vmmultimetrics = (
		["cpu", "ready", "summation"],
		["cpu", "wait", "summation"],
		["cpu", "idle", "summation"],
		["cpu", "latency", "average"],
		["disk", "maxTotalLatency", "latest"],
		["disk", "usage", "average"],
		# ["disk", "commandsAveraged", "average"],
		["net", "usage", "average"],
	);
	%vmmultistats = MultiQueryPerf($all_vm_views, @vmmultimetrics);
	my $vmmultimetricsend = Time::HiRes::gettimeofday();
	my $vmmultimetricstimelapse = $vmmultimetricsend - $vmmultimetricsstart;
	$logger->info("[DEBUG] computed all vms multi metrics in $vmmultimetricstimelapse sec for Unamaged host $vmware_server");


	### retreive esx hostname
	my $esx_fqdn = $vmware_server;

	$esx_fqdn =~ s/[ .]/_/g;
	my $esx_name = lc ($esx_fqdn);

	my $vmware_server_name = "_unmanaged_";
	my $datacentre_name = "_unmanaged_";

	$logger->info("[INFO] Processing ESX $vmware_server unmanaged host");

	foreach my $UnamagedComputeResource (@$all_compute_views) {

		eval {

			my @UnamagedComputeResourceHosts = $UnamagedComputeResource->host;

			my $UnamagedResourceVMHost = $all_host_views_table{$UnamagedComputeResourceHosts[0][0]->value};

			if (!defined $UnamagedResourceVMHost or $UnamagedResourceVMHost->{'runtime.connectionState'}->val ne "connected") {next;}

			my $UnamagedResourcePool = $all_cluster_root_pool_views_table{$UnamagedComputeResource->{'mo_ref'}->value};

			my $UnamagedResourceVMHostName = $UnamagedResourceVMHost->{'config.network.dnsConfig.hostName'};
			if ($UnamagedResourceVMHostName eq "localhost") {
				my $UnamagedResourceVMHostVmk0 = $UnamagedResourceVMHost->{'config.network.vnic'}[0];
				my $UnamagedResourceVMHostVmk0Ip = $UnamagedResourceVMHostVmk0->spec->ip->ipAddress;
				$UnamagedResourceVMHostVmk0Ip =~ s/[ .]/_/g;
				$UnamagedResourceVMHostName = $UnamagedResourceVMHostVmk0Ip;
			}

			my $UnamagedResourceVMHost_status = $UnamagedResourceVMHost->{'overallStatus'}->val; #ToClean
			my $UnamagedResourceVMHost_status_val = 0;
			if ($UnamagedResourceVMHost_status eq "green") {
				$UnamagedResourceVMHost_status_val = 1;
			} elsif ($UnamagedResourceVMHost_status eq "yellow") {
				$UnamagedResourceVMHost_status_val = 2;
			} elsif ($UnamagedResourceVMHost_status eq "red") {
				$UnamagedResourceVMHost_status_val = 3;
			} elsif ($UnamagedResourceVMHost_status eq "gray") {
				$UnamagedResourceVMHost_status_val = 0;
			}

			my $UnamagedComputeResourceMB = $UnamagedComputeResource->summary->effectiveMemory * 9.5367431640625e-7; # in bytes for unmanaged but in MB for managed

			my $UnamagedComputeResourceCarbonHash = ();

			my $UnamagedResourceVMHost_sensors = $UnamagedResourceVMHost->{'summary.runtime.healthSystemRuntime.systemHealthInfo.numericSensorInfo'};
			
			foreach my $UnamagedResourceVMHost_sensor (@$UnamagedResourceVMHost_sensors) {
				if ($UnamagedResourceVMHost_sensor->name && $UnamagedResourceVMHost_sensor->sensorType && $UnamagedResourceVMHost_sensor->currentReading && $UnamagedResourceVMHost_sensor->unitModifier) {
					my $UnamagedResourceVMHost_sensor_computed_reading = $UnamagedResourceVMHost_sensor->currentReading * (10**$UnamagedResourceVMHost_sensor->unitModifier);
					my $UnamagedResourceVMHost_sensor_name = nameCleaner($UnamagedResourceVMHost_sensor->name);
					$UnamagedComputeResourceCarbonHash->{$vmware_server_name}{$datacentre_name}{$UnamagedResourceVMHostName}{"sensor"}{$UnamagedResourceVMHost_sensor->sensorType}{$UnamagedResourceVMHost_sensor_name} = $UnamagedResourceVMHost_sensor_computed_reading;
				}
			}

			$UnamagedComputeResourceCarbonHash->{$vmware_server_name}{$datacentre_name}{$UnamagedResourceVMHostName}{"quickstats"}{"mem"}{"usage"} = $UnamagedResourceVMHost->{'summary.quickStats.overallMemoryUsage'};
			$UnamagedComputeResourceCarbonHash->{$vmware_server_name}{$datacentre_name}{$UnamagedResourceVMHostName}{"quickstats"}{"cpu"}{"usage"} = $UnamagedResourceVMHost->{'summary.quickStats.overallCpuUsage'};
			$UnamagedComputeResourceCarbonHash->{$vmware_server_name}{$datacentre_name}{$UnamagedResourceVMHostName}{"quickstats"}{"mem"}{"effective"} = $UnamagedComputeResourceMB;
			$UnamagedComputeResourceCarbonHash->{$vmware_server_name}{$datacentre_name}{$UnamagedResourceVMHostName}{"quickstats"}{"mem"}{"total"} = $UnamagedComputeResource->summary->totalMemory;
			$UnamagedComputeResourceCarbonHash->{$vmware_server_name}{$datacentre_name}{$UnamagedResourceVMHostName}{"quickstats"}{"cpu"}{"effective"} = $UnamagedComputeResource->summary->effectiveCpu;
			$UnamagedComputeResourceCarbonHash->{$vmware_server_name}{$datacentre_name}{$UnamagedResourceVMHostName}{"quickstats"}{"cpu"}{"total"} = $UnamagedComputeResource->summary->totalCpu;
			$UnamagedComputeResourceCarbonHash->{$vmware_server_name}{$datacentre_name}{$UnamagedResourceVMHostName}{"quickstats"}{"overallStatus"} = $UnamagedResourceVMHost_status_val;

			$logger->info("[INFO] Processing vCenter $vmware_server Unamaged host $UnamagedResourceVMHostName datastores in datacenter $datacentre_name");

			my @UnamagedResourceDatastoresViews = ();
			my $UnamagedResourceDatastoresMoref = $UnamagedComputeResource->datastore;
			foreach my $UnamagedComputeResourceDatastoreMoref (@$UnamagedResourceDatastoresMoref) {
				if ($all_datastore_views_table{$UnamagedComputeResourceDatastoreMoref->{'value'}}) {
					push (@UnamagedResourceDatastoresViews,$all_datastore_views_table{$UnamagedComputeResourceDatastoreMoref->{'value'}})
				}
			}

			foreach my $UnamagedResourceDatastore (@UnamagedResourceDatastoresViews) {
				if ($UnamagedResourceDatastore->summary->accessible) {

					my @vmpath = split("/", $UnamagedResourceDatastore->summary->url);
					my $uuid = $vmpath[-1];

					my $UnamagedResourceDatastore_name = nameCleaner($UnamagedResourceDatastore->summary->name);
					my $UnamagedResourceDatastore_uncommitted = 0;
					if ($UnamagedResourceDatastore->summary->uncommitted) {
						$UnamagedResourceDatastore_uncommitted = $UnamagedResourceDatastore->summary->uncommitted;
					}

					$UnamagedComputeResourceCarbonHash->{$vmware_server_name}{$datacentre_name}{$UnamagedResourceVMHostName}{"datastore"}{$UnamagedResourceDatastore_name}{"summary"}{"capacity"} = $UnamagedResourceDatastore->summary->capacity;
					$UnamagedComputeResourceCarbonHash->{$vmware_server_name}{$datacentre_name}{$UnamagedResourceVMHostName}{"datastore"}{$UnamagedResourceDatastore_name}{"summary"}{"freeSpace"} = $UnamagedResourceDatastore->summary->freeSpace;
					$UnamagedComputeResourceCarbonHash->{$vmware_server_name}{$datacentre_name}{$UnamagedResourceVMHostName}{"datastore"}{$UnamagedResourceDatastore_name}{"summary"}{"uncommitted"} = $UnamagedResourceDatastore_uncommitted;

					# if ($hostmultistats{$perfCntr{"datastore.datastoreVMObservedLatency.latest"}->key}{$UnamagedResourceVMHost->{'mo_ref'}->value}{$uuid}) {
					# 	my $UnamagedResourceDatastoreVmLatency = $hostmultistats{$perfCntr{"datastore.datastoreVMObservedLatency.latest"}->key}{$UnamagedResourceVMHost->{'mo_ref'}->value}{$uuid};
					# 	$UnamagedComputeResourceCarbonHash->{$vmware_server_name}{$datacentre_name}{$UnamagedResourceVMHostName}{"datastore"}{$UnamagedResourceDatastore_name}{"iorm"}{"sizeNormalizedDatastoreLatency"} = $UnamagedResourceDatastoreVmLatency;
					# }
				}
			}

			foreach my $UnamagedResourceVMHost_vmnic (@{$UnamagedResourceVMHost->{'config.network.pnic'}}) {
				if ($UnamagedResourceVMHost_vmnic->linkSpeed && $UnamagedResourceVMHost_vmnic->linkSpeed->speedMb >= 100) {
					my $UnamagedResourceVMHost_vmnic_name = $UnamagedResourceVMHost_vmnic->device;
					my $NetbytesRx = $hostmultistats{$perfCntr{"net.bytesRx.average"}->key}{$UnamagedResourceVMHost->{'mo_ref'}->value}{$UnamagedResourceVMHost_vmnic_name};
					my $NetbytesTx = $hostmultistats{$perfCntr{"net.bytesTx.average"}->key}{$UnamagedResourceVMHost->{'mo_ref'}->value}{$UnamagedResourceVMHost_vmnic_name};

					if (defined($NetbytesRx) && defined($NetbytesTx)) {
						$UnamagedComputeResourceCarbonHash->{$vmware_server_name}{$datacentre_name}{$UnamagedResourceVMHostName}{"net"}{$UnamagedResourceVMHost_vmnic_name}{"bytesRx"} = $NetbytesRx;
						$UnamagedComputeResourceCarbonHash->{$vmware_server_name}{$datacentre_name}{$UnamagedResourceVMHostName}{"net"}{$UnamagedResourceVMHost_vmnic_name}{"bytesTx"} = $NetbytesTx;
						$UnamagedComputeResourceCarbonHash->{$vmware_server_name}{$datacentre_name}{$UnamagedResourceVMHostName}{"net"}{$UnamagedResourceVMHost_vmnic_name}{"linkSpeed"} = $UnamagedResourceVMHost_vmnic->linkSpeed->speedMb;
					}
				}
			}

			foreach my $UnamagedResourceVMHost_vmhba (@{$UnamagedResourceVMHost->{'config.storageDevice.hostBusAdapter'}}) {
					my $HbabytesRead = $hostmultistats{$perfCntr{"storageAdapter.read.average"}->key}{$UnamagedResourceVMHost->{'mo_ref'}->value}{$UnamagedResourceVMHost_vmhba->device};
					my $HbabytesWrite = $hostmultistats{$perfCntr{"storageAdapter.write.average"}->key}{$UnamagedResourceVMHost->{'mo_ref'}->value}{$UnamagedResourceVMHost_vmhba->device};
					if (defined($HbabytesRead) && defined($HbabytesWrite)) {
						my $UnamagedResourceVMHost_vmhba_name = $UnamagedResourceVMHost_vmhba->device;

						$UnamagedComputeResourceCarbonHash->{$vmware_server_name}{$datacentre_name}{$UnamagedResourceVMHostName}{"hba"}{$UnamagedResourceVMHost_vmhba_name}{"bytesRead"} = $HbabytesRead;
						$UnamagedComputeResourceCarbonHash->{$vmware_server_name}{$datacentre_name}{$UnamagedResourceVMHostName}{"hba"}{$UnamagedResourceVMHost_vmhba_name}{"bytesWrite"} = $HbabytesWrite;
					}
			}

			my @UnamagedResourceVMHostVmsMoref = ();
			if ($UnamagedResourceVMHost->vm && (scalar($UnamagedResourceVMHost->vm) > 0)) {
				push (@UnamagedResourceVMHostVmsMoref,$UnamagedResourceVMHost->vm);
			}

			my @UnamagedResourceVMHostVmsViews = ();
			if (scalar(@UnamagedResourceVMHostVmsMoref) > 0) {
				my @UnamagedResourceVMHostVmsMorefs = map {@$_} @UnamagedResourceVMHostVmsMoref;
				foreach my $UnamagedResourceVMHostVmMoref (@UnamagedResourceVMHostVmsMorefs) {
					push (@UnamagedResourceVMHostVmsViews,$all_vm_views_table{$UnamagedResourceVMHostVmMoref->{'value'}});
				}
			}

			my @UnamagedResourcePoolPrivateMemory = ();
			push (@UnamagedResourcePoolPrivateMemory,0);
			my @UnamagedResourcePoolSharedMemory = ();
			push (@UnamagedResourcePoolSharedMemory,0);
			my @UnamagedResourcePoolBalloonedMemory = ();
			push (@UnamagedResourcePoolBalloonedMemory,0);
			my @UnamagedResourcePoolCompressedMemory = ();
			push (@UnamagedResourcePoolCompressedMemory,0);
			my @UnamagedResourcePoolSwappedMemory = ();
			push (@UnamagedResourcePoolSwappedMemory,0);
			my @UnamagedResourcePoolGuestMemoryUsage = ();
			push (@UnamagedResourcePoolGuestMemoryUsage,0);
			my @UnamagedResourcePoolConsumedOverheadMemory = ();
			push (@UnamagedResourcePoolConsumedOverheadMemory,0);
			
			# my $Unamaged_vm_views_vcpus = 0;
			my $Unamaged_vm_views_on = 0;
			my $Unamaged_vm_views_files_dedup = {};

			if (scalar(@UnamagedResourceVMHostVmsViews) > 0) {

				$logger->info("[INFO] Processing vCenter $vmware_server Unamaged host $UnamagedResourceVMHostName vms in datacenter $datacentre_name");

				foreach my $Unamaged_vm_view (@UnamagedResourceVMHostVmsViews) {

					my $Unamaged_vm_view_name = nameCleaner($Unamaged_vm_view->name);

					if ($Unamaged_vm_view->{'summary.runtime.powerState'}->{'val'} eq "poweredOn") {

						# $Unamaged_vm_views_vcpus += $Unamaged_vm_view->{'config.hardware.numCPU'};
						$Unamaged_vm_views_on++;

						my $Unamaged_vm_view_files = $Unamaged_vm_view->{'layoutEx.file'};
						### http://pubs.vmware.com/vsphere-60/topic/com.vmware.wssdk.apiref.doc/vim.vm.FileLayoutEx.FileType.html

						my $Unamaged_vm_view_snap_size = 0;
						my $Unamaged_vm_view_has_snap = 0;

						if ($Unamaged_vm_view->snapshot) {
							$Unamaged_vm_view_has_snap = 1;
						}

						my $Unamaged_vm_view_num_vdisk = $Unamaged_vm_view->{'summary.config.numVirtualDisks'};
						my $Unamaged_vm_view_real_vdisk = 0;
						

						foreach my $Unamaged_vm_view_file (@$Unamaged_vm_view_files) {
							if ($Unamaged_vm_view_file->type eq "diskDescriptor") {
								$Unamaged_vm_view_real_vdisk++;
							}
						}

						if (($Unamaged_vm_view_real_vdisk > $Unamaged_vm_view_num_vdisk)) {
							$Unamaged_vm_view_has_snap = 1;
						}

						foreach my $Unamaged_vm_view_file (@$Unamaged_vm_view_files) {
							if (!$Unamaged_vm_views_files_dedup->{$Unamaged_vm_view_file->name}) { #would need name & moref
								$Unamaged_vm_views_files_dedup->{$Unamaged_vm_view_file->name} = $Unamaged_vm_view_file->size;
								if (($Unamaged_vm_view_has_snap == 1) && ($Unamaged_vm_view_file->name =~ /-[0-9]{6}-delta\.vmdk/ or $Unamaged_vm_view_file->name =~ /-[0-9]{6}-sesparse\.vmdk/)) {
									$Unamaged_vm_view_snap_size += $Unamaged_vm_view_file->size;
								} elsif (($Unamaged_vm_view_has_snap == 1) && ($Unamaged_vm_view_file->name =~ /-[0-9]{6}\.vmdk/)) {
									$Unamaged_vm_view_snap_size += $Unamaged_vm_view_file->size;
								}
							}
						}

						if ($Unamaged_vm_view_snap_size > 0) {
							$UnamagedComputeResourceCarbonHash->{$vmware_server_name}{$datacentre_name}{$UnamagedResourceVMHostName}{"vm"}{$Unamaged_vm_view_name}{"storage"}{"delta"} = $Unamaged_vm_view_snap_size;
						}

						my $Unamaged_vm_view_CpuUtilization = 0;
						if ($Unamaged_vm_view->{'runtime.maxCpuUsage'} > 0 && $Unamaged_vm_view->{'summary.quickStats.overallCpuUsage'} > 0) {
							$Unamaged_vm_view_CpuUtilization = $Unamaged_vm_view->{'summary.quickStats.overallCpuUsage'} * 100 / $Unamaged_vm_view->{'runtime.maxCpuUsage'};
						}

						my $Unamaged_vm_view_MemUtilization = 0;
						if ($Unamaged_vm_view->{'summary.quickStats.guestMemoryUsage'} > 0 && $Unamaged_vm_view->{'runtime.maxMemoryUsage'} > 0) {
							$Unamaged_vm_view_MemUtilization = $Unamaged_vm_view->{'summary.quickStats.guestMemoryUsage'} * 100 / $Unamaged_vm_view->{'runtime.maxMemoryUsage'};
						}

						$UnamagedComputeResourceCarbonHash->{$vmware_server_name}{$datacentre_name}{$UnamagedResourceVMHostName}{"vm"}{$Unamaged_vm_view_name}{"quickstats"}{"overallCpuUsage"} = $Unamaged_vm_view->{'summary.quickStats.overallCpuUsage'};
						$UnamagedComputeResourceCarbonHash->{$vmware_server_name}{$datacentre_name}{$UnamagedResourceVMHostName}{"vm"}{$Unamaged_vm_view_name}{"quickstats"}{"HostMemoryUsage"} = $Unamaged_vm_view->{'summary.quickStats.hostMemoryUsage'};
						$UnamagedComputeResourceCarbonHash->{$vmware_server_name}{$datacentre_name}{$UnamagedResourceVMHostName}{"vm"}{$Unamaged_vm_view_name}{"quickstats"}{"GuestMemoryUsage"} = $Unamaged_vm_view->{'summary.quickStats.guestMemoryUsage'};
						$UnamagedComputeResourceCarbonHash->{$vmware_server_name}{$datacentre_name}{$UnamagedResourceVMHostName}{"vm"}{$Unamaged_vm_view_name}{"storage"}{"committed"} = $Unamaged_vm_view->{'summary.storage.committed'};
						$UnamagedComputeResourceCarbonHash->{$vmware_server_name}{$datacentre_name}{$UnamagedResourceVMHostName}{"vm"}{$Unamaged_vm_view_name}{"storage"}{"uncommitted"} = $Unamaged_vm_view->{'summary.storage.uncommitted'};
						$UnamagedComputeResourceCarbonHash->{$vmware_server_name}{$datacentre_name}{$UnamagedResourceVMHostName}{"vm"}{$Unamaged_vm_view_name}{"runtime"}{"CpuUtilization"} = $Unamaged_vm_view_CpuUtilization;
						$UnamagedComputeResourceCarbonHash->{$vmware_server_name}{$datacentre_name}{$UnamagedResourceVMHostName}{"vm"}{$Unamaged_vm_view_name}{"runtime"}{"MemUtilization"} = $Unamaged_vm_view_MemUtilization;

						if ($Unamaged_vm_view->{'summary.quickStats.balloonedMemory'} > 0) {
							push (@UnamagedResourcePoolBalloonedMemory,$Unamaged_vm_view->{'summary.quickStats.balloonedMemory'});
							$UnamagedComputeResourceCarbonHash->{$vmware_server_name}{$datacentre_name}{$UnamagedResourceVMHostName}{"vm"}{$Unamaged_vm_view_name}{"quickstats"}{"BalloonedMemory"} = $Unamaged_vm_view->{'summary.quickStats.balloonedMemory'};
						}

						if ($Unamaged_vm_view->{'summary.quickStats.compressedMemory'} > 0) {
							push (@UnamagedResourcePoolCompressedMemory,$Unamaged_vm_view->{'summary.quickStats.compressedMemory'});
							$UnamagedComputeResourceCarbonHash->{$vmware_server_name}{$datacentre_name}{$UnamagedResourceVMHostName}{"vm"}{$Unamaged_vm_view_name}{"quickstats"}{"CompressedMemory"} = $Unamaged_vm_view->{'summary.quickStats.compressedMemory'};
						}

						if ($Unamaged_vm_view->{'summary.quickStats.swappedMemory'} > 0) {
							push (@UnamagedResourcePoolSwappedMemory,$Unamaged_vm_view->{'summary.quickStats.swappedMemory'});
							$UnamagedComputeResourceCarbonHash->{$vmware_server_name}{$datacentre_name}{$UnamagedResourceVMHostName}{"vm"}{$Unamaged_vm_view_name}{"quickstats"}{"SwappedMemory"} = $Unamaged_vm_view->{'summary.quickStats.swappedMemory'};
						}

						if ($vmmultistats{$perfCntr{"cpu.ready.summation"}->key}{$Unamaged_vm_view->{'mo_ref'}->value}{""}) {
							my $vmreadyavg = $vmmultistats{$perfCntr{"cpu.ready.summation"}->key}{$Unamaged_vm_view->{'mo_ref'}->value}{""} / $Unamaged_vm_view->{'config.hardware.numCPU'} / 20000 * 100;
							### https://kb.vmware.com/kb/2002181
							$UnamagedComputeResourceCarbonHash->{$vmware_server_name}{$datacentre_name}{$UnamagedResourceVMHostName}{"vm"}{$Unamaged_vm_view_name}{"fatstats"}{"cpu_ready_summation"} = $vmreadyavg;
						}

						if ($vmmultistats{$perfCntr{"cpu.wait.summation"}->key}{$Unamaged_vm_view->{'mo_ref'}->value}{""} && $vmmultistats{$perfCntr{"cpu.idle.summation"}->key}{$Unamaged_vm_view->{'mo_ref'}->value}{""}) {
							my $vmwaitavg = ($vmmultistats{$perfCntr{"cpu.wait.summation"}->key}{$Unamaged_vm_view->{'mo_ref'}->value}{""} - $vmmultistats{$perfCntr{"cpu.idle.summation"}->key}{$Unamaged_vm_view->{'mo_ref'}->value}{""}) / $Unamaged_vm_view->{'config.hardware.numCPU'} / 20000 * 100;
							### https://code.vmware.com/apis/358/vsphere#/doc/cpu_counters.html
							$UnamagedComputeResourceCarbonHash->{$vmware_server_name}{$datacentre_name}{$UnamagedResourceVMHostName}{"vm"}{$Unamaged_vm_view_name}{"fatstats"}{"cpu_wait_no_idle"} = $vmwaitavg;
						}

						if ($vmmultistats{$perfCntr{"cpu.latency.average"}->key}{$Unamaged_vm_view->{'mo_ref'}->value}{""}) {
							my $vmlatencyval = $vmmultistats{$perfCntr{"cpu.latency.average"}->key}{$Unamaged_vm_view->{'mo_ref'}->value}{""};
							$UnamagedComputeResourceCarbonHash->{$vmware_server_name}{$datacentre_name}{$UnamagedResourceVMHostName}{"vm"}{$Unamaged_vm_view_name}{"fatstats"}{"cpu_latency_average"} = $vmlatencyval;
						}

						if ($vmmultistats{$perfCntr{"disk.maxTotalLatency.latest"}->key}{$Unamaged_vm_view->{'mo_ref'}->value}{""}) {
							my $vmmaxtotallatencyval = $vmmultistats{$perfCntr{"disk.maxTotalLatency.latest"}->key}{$Unamaged_vm_view->{'mo_ref'}->value}{""};
							$UnamagedComputeResourceCarbonHash->{$vmware_server_name}{$datacentre_name}{$UnamagedResourceVMHostName}{"vm"}{$Unamaged_vm_view_name}{"fatstats"}{"maxTotalLatency"} = $vmmaxtotallatencyval;
						}

						if ($vmmultistats{$perfCntr{"disk.usage.average"}->key}{$Unamaged_vm_view->{'mo_ref'}->value}{""}) {
							my $vmdiskusageval = $vmmultistats{$perfCntr{"disk.usage.average"}->key}{$Unamaged_vm_view->{'mo_ref'}->value}{""};
							$UnamagedComputeResourceCarbonHash->{$vmware_server_name}{$datacentre_name}{$UnamagedResourceVMHostName}{"vm"}{$Unamaged_vm_view_name}{"fatstats"}{"diskUsage"} = $vmdiskusageval;
						}

						if ($vmmultistats{$perfCntr{"net.usage.average"}->key}{$Unamaged_vm_view->{'mo_ref'}->value}{""}) {
							my $vmnetusageval = $vmmultistats{$perfCntr{"net.usage.average"}->key}{$Unamaged_vm_view->{'mo_ref'}->value}{""};
							$UnamagedComputeResourceCarbonHash->{$vmware_server_name}{$datacentre_name}{$UnamagedResourceVMHostName}{"vm"}{$Unamaged_vm_view_name}{"fatstats"}{"netUsage"} = $vmnetusageval;
						}

						if ($Unamaged_vm_view->{'summary.quickStats.privateMemory'} > 0) {
							push (@UnamagedResourcePoolPrivateMemory,$Unamaged_vm_view->{'summary.quickStats.privateMemory'});
						}

						if ($Unamaged_vm_view->{'summary.quickStats.sharedMemory'} > 0) {
							push (@UnamagedResourcePoolSharedMemory,$Unamaged_vm_view->{'summary.quickStats.sharedMemory'});
						}

						if ($Unamaged_vm_view->{'summary.quickStats.guestMemoryUsage'} > 0) {
							push (@UnamagedResourcePoolGuestMemoryUsage,$Unamaged_vm_view->{'summary.quickStats.guestMemoryUsage'});
						}

						if ($Unamaged_vm_view->{'summary.quickStats.consumedOverheadMemory'} > 0) {
							push (@UnamagedResourcePoolConsumedOverheadMemory,$Unamaged_vm_view->{'summary.quickStats.consumedOverheadMemory'});
						}

					} elsif ($Unamaged_vm_view->{'summary.runtime.powerState'}->{'val'} eq "poweredOff") {

						my $Unamaged_vm_view_off = $Unamaged_vm_view;

						my $Unamaged_vm_view_off_name = nameCleaner($Unamaged_vm_view_off->name);

						my $Unamaged_vm_view_off_files = $Unamaged_vm_view_off->{'layoutEx.file'};
						### http://pubs.vmware.com/vsphere-60/topic/com.vmware.wssdk.apiref.doc/vim.vm.FileLayoutEx.FileType.html

						my $Unamaged_vm_view_off_snap_size = 0;
						my $Unamaged_vm_view_off_has_snap = 0;

						if ($Unamaged_vm_view_off->snapshot) {
							$Unamaged_vm_view_off_has_snap = 1;
						}

						my $Unamaged_vm_view_off_num_vdisk = $Unamaged_vm_view_off->{'summary.config.numVirtualDisks'};
						my $Unamaged_vm_view_off_real_vdisk = 0;

						foreach my $Unamaged_vm_view_off_file (@$Unamaged_vm_view_off_files) {
							if ($Unamaged_vm_view_off_file->type eq "diskDescriptor") {
								$Unamaged_vm_view_off_real_vdisk++;
							}
						}

						if (($Unamaged_vm_view_off_real_vdisk > $Unamaged_vm_view_off_num_vdisk)) {
							$Unamaged_vm_view_off_has_snap = 1;
						}

						foreach my $Unamaged_vm_view_off_file (@$Unamaged_vm_view_off_files) {
							if (!$Unamaged_vm_views_files_dedup->{$Unamaged_vm_view_off_file->name}) { #would need name & moref
								$Unamaged_vm_views_files_dedup->{$Unamaged_vm_view_off_file->name} = $Unamaged_vm_view_off_file->size;
								if (($Unamaged_vm_view_off_has_snap == 1) && ($Unamaged_vm_view_off_file->name =~ /-[0-9]{6}-delta\.vmdk/ or $Unamaged_vm_view_off_file->name =~ /-[0-9]{6}-sesparse\.vmdk/)) {
									$Unamaged_vm_view_off_snap_size += $Unamaged_vm_view_off_file->size;
								} elsif (($Unamaged_vm_view_off_has_snap == 1) && ($Unamaged_vm_view_off_file->name =~ /-[0-9]{6}\.vmdk/)) {
										$Unamaged_vm_view_off_snap_size += $Unamaged_vm_view_off_file->size;
								}
							}
						}

						if ($Unamaged_vm_view_off_snap_size > 0) {
							$UnamagedComputeResourceCarbonHash->{$vmware_server_name}{$datacentre_name}{$UnamagedResourceVMHostName}{"vm"}{$Unamaged_vm_view_off_name}{"storage.delta"} = $Unamaged_vm_view_off_snap_size;
						}

						$UnamagedComputeResourceCarbonHash->{$vmware_server_name}{$datacentre_name}{$UnamagedResourceVMHostName}{"vm"}{$Unamaged_vm_view_off_name}{"storage.committed"} = $Unamaged_vm_view_off->{'summary.storage.committed'};
						$UnamagedComputeResourceCarbonHash->{$vmware_server_name}{$datacentre_name}{$UnamagedResourceVMHostName}{"vm"}{$Unamaged_vm_view_off_name}{"storage.uncommitted"} = $Unamaged_vm_view_off->{'summary.storage.uncommitted'};

					}
				}

				$UnamagedComputeResourceCarbonHash->{$vmware_server_name}{$datacentre_name}{$UnamagedResourceVMHostName}{"runtime"}{"vm"}{"total"} = scalar(@UnamagedResourceVMHostVmsViews);
				$UnamagedComputeResourceCarbonHash->{$vmware_server_name}{$datacentre_name}{$UnamagedResourceVMHostName}{"runtime"}{"vm"}{"on"} = $Unamaged_vm_views_on;
				$UnamagedComputeResourceCarbonHash->{$vmware_server_name}{$datacentre_name}{$UnamagedResourceVMHostName}{"quickstats"}{"mem"}{"ballooned"} = sum(@UnamagedResourcePoolBalloonedMemory);
				$UnamagedComputeResourceCarbonHash->{$vmware_server_name}{$datacentre_name}{$UnamagedResourceVMHostName}{"quickstats"}{"mem"}{"compressed"} = sum(@UnamagedResourcePoolCompressedMemory);
				$UnamagedComputeResourceCarbonHash->{$vmware_server_name}{$datacentre_name}{$UnamagedResourceVMHostName}{"quickstats"}{"mem"}{"guest"} = sum(@UnamagedResourcePoolGuestMemoryUsage);
				$UnamagedComputeResourceCarbonHash->{$vmware_server_name}{$datacentre_name}{$UnamagedResourceVMHostName}{"quickstats"}{"mem"}{"private"} = sum(@UnamagedResourcePoolPrivateMemory);
				$UnamagedComputeResourceCarbonHash->{$vmware_server_name}{$datacentre_name}{$UnamagedResourceVMHostName}{"quickstats"}{"mem"}{"shared"} = sum(@UnamagedResourcePoolSharedMemory);
				$UnamagedComputeResourceCarbonHash->{$vmware_server_name}{$datacentre_name}{$UnamagedResourceVMHostName}{"quickstats"}{"mem"}{"swapped"} = sum(@UnamagedResourcePoolSwappedMemory);
				$UnamagedComputeResourceCarbonHash->{$vmware_server_name}{$datacentre_name}{$UnamagedResourceVMHostName}{"quickstats"}{"mem"}{"consumedOverhead"} = sum(@UnamagedResourcePoolConsumedOverheadMemory);

				my $UnamagedComputeResourceCarbonHashTimed = {time() => $UnamagedComputeResourceCarbonHash};
				$graphite->send(path => "esx", data => $UnamagedComputeResourceCarbonHashTimed);

			}

			my $sessionCount = 0;
			my $sessionCarbonHash;
			my $sessionMgr = (Vim::get_view(mo_ref => $service_content->sessionManager, properties => ['sessionList']));

			$logger->info("[INFO] Processing vCenter $vmware_server events");

			eval {
				my $eventMgr = (Vim::get_view(mo_ref => $service_content->eventManager, properties => ['latestEvent', 'description']));

				my $eventCount = 0;
				my $eventCarbonHash = ();

				my $eventLast = $eventMgr->latestEvent;
				$eventCount = $eventLast->key;

				if ($eventCount > 0) {

					## https://github.com/lamw/vghetto-scripts/blob/master/perl/provisionedVMReport.pl
					my $eventsInfo = $eventMgr->description->eventInfo;

					my @filteredEvents;

					my @ViEvents70 = do "/root/ViEvents.pl";
					@filteredEvents = @ViEvents70;

					if ($eventsInfo) {
						foreach my $eventInfo (@$eventsInfo) {
							if ($eventInfo->category =~ m/(warning|error)/ &&  $eventInfo->longDescription =~ m/(vim\.event\.)/) {
								# my $EventLongDescriptionId = $eventInfo->longDescription;
								# $EventLongDescriptionId =~ /vim\.event\.([a-zA-Z0-9]+)/;
								# push (@filteredEvents,$1);
								push (@filteredEvents,$eventInfo->key);
							}
						}
					}

					my $evtTimeSpec = EventFilterSpecByTime->new(beginTime => $vmware_server_clock_5->datetime, endTime => $vmware_server_clock->datetime);
					my $filterSpec = EventFilterSpec->new(time => $evtTimeSpec, eventTypeId => [@filteredEvents]);
					my $evtResults = $eventMgr->CreateCollectorForEvents(filter => $filterSpec);

					my $eventCollector = Vim::get_view(mo_ref => $evtResults);
					# $eventCollector->ResetCollector();
					## my $exEvents = $eventCollector->latestPage;
					my $exEvents = $eventCollector->ReadNextEvents(maxCount => 1000);
					
					my $vc_events_count_per_id = {};

					if ($exEvents) {
						foreach my $exEvent (@$exEvents) {

							if (%$exEvent{"eventTypeId"}) {
								if (%$exEvent{"datacenter"} && %$exEvent{"computeResource"}) {
									my $evt_datacentre_name = $datacentre_name;
									my $evt_cluster_name = nameCleaner($exEvent->computeResource->name);

									$vc_events_count_per_id->{$evt_datacentre_name}->{$evt_cluster_name}->{$exEvent->eventTypeId} += 1;
								}
							} elsif (%$exEvent{"messageInfo"}) {
								eval {
									if (%$exEvent{"datacenter"} && %$exEvent{"computeResource"}) {
										my $evt_datacentre_name = $datacentre_name;
										my $evt_cluster_name = nameCleaner($exEvent->computeResource->name);

										my $evt_msg_info = $exEvent->messageInfo;
										my $evt_msg_info_0 = @$evt_msg_info[0];
										my $evt_msg_info_id = %$evt_msg_info_0{"id"};
										my $evt_id_name = nameCleaner($evt_msg_info_id);

										$vc_events_count_per_id->{$evt_datacentre_name}->{$evt_cluster_name}->{$evt_id_name} += 1;
									}
								};
							} else {
								if (%$exEvent{"datacenter"} && %$exEvent{"computeResource"}) {
									my $exEventRef = ref($exEvent);
									my $evt_datacentre_name = $datacentre_name;
									my $evt_cluster_name = nameCleaner($exEvent->computeResource->name);

									$vc_events_count_per_id->{$evt_datacentre_name}->{$evt_cluster_name}->{$exEventRef} += 1;
								}
							}
						}

						foreach my $dc_vc_event_id (keys %$vc_events_count_per_id) {
							my $clu_dc_vc_event_id_h = $vc_events_count_per_id->{$dc_vc_event_id};
							foreach my $clu_dc_vc_event_id (keys %$clu_dc_vc_event_id_h) {
								my $vc_events_count_per_id_h = $vc_events_count_per_id->{$dc_vc_event_id}->{$clu_dc_vc_event_id};
								foreach my $evt_clu_dc_vc_event_id (keys %$vc_events_count_per_id_h) {
									my $clean_evt_clu_dc_vc_event_id = $evt_clu_dc_vc_event_id;
									$clean_evt_clu_dc_vc_event_id =~ s/[ .]/_/g;
									$eventCarbonHash->{$vmware_server_name}{"vi"}{"exec"}{"ExEvent"}{$dc_vc_event_id}{$clu_dc_vc_event_id}{$clean_evt_clu_dc_vc_event_id} = $vc_events_count_per_id->{$dc_vc_event_id}->{$clu_dc_vc_event_id}->{$evt_clu_dc_vc_event_id};
								}
							}
						}
					}

					$eventCollector->DestroyCollector;

					my $eventCarbonHashTimed = {time() => $eventCarbonHash};
					$graphite->send(path => "vi", data => $eventCarbonHashTimed);

				}
			};
			if($@) {
				$logger->info("[ERROR] reset dead session file $sessionfile for vCenter $vmware_server");
				unlink $sessionfile;
			}
		};
	}

	my $exec_duration = time - $exec_start;
	my $esx_exec_duration_h = {
		time() => {
			"$esx_name.vi" . ".exec.duration", $exec_duration,
		},
	};
	$graphite->send(path => "vi", data => $esx_exec_duration_h);

	$logger->info("[INFO] End processing ESX $vmware_server");		
}	



### disconnect from the vmware server
# Util::disconnect();