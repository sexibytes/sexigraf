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

$Data::Dumper::Indent = 1;
$Util::script_version = "0.9.858";
$ENV{'PERL_LWP_SSL_VERIFY_HOSTNAME'} = 0;

my $BFG_Mode = 0;
if (defined ($ARGV[6]) &&  ($ARGV[6] eq "BFG_Mode")) {$BFG_Mode = 1};

Opts::parse();
Opts::validate();

my $url = Opts::get_option('url');
my $vcenterserver = Opts::get_option('server');
my $username = Opts::get_option('username');
my $password = Opts::get_option('password');
my $sessionfile = Opts::get_option('sessionfile');
my $credstorefile = Opts::get_option('credstore');

my $exec_start = time;
my $t_0 = localtime;
my $t_5 = localtime;

my $logger = Log::Log4perl->get_logger('sexigraf.ViPullStatistics');
$logger->info("[DEBUG] ViPullStatistics v$Util::script_version for vCenter $vcenterserver");

VMware::VICredStore::init (filename => $credstorefile) or $logger->logdie ("[ERROR] Unable to initialize Credential Store for vCenter $vcenterserver");
my @user_list = VMware::VICredStore::get_usernames (server => $vcenterserver);

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

### handling multiple run
$0 = "ViPullStatistics from $vcenterserver";
my $PullProcess = 0;
foreach my $file (glob("/proc/[0-9]*/cmdline")) {
	open FILE, "<$file";
	if (grep(/^ViPullStatistics from $vcenterserver/, <FILE>) ) {
		$PullProcess++;
	}
	close FILE;
}
if (scalar($PullProcess) > 1) {$logger->logdie ("[ERROR] ViPullStatistics from $vcenterserver is already running!")}


### handling sessionfile if missing or expired
if (scalar(@user_list) == 0) {
	$logger->logdie ("[ERROR] No credential store user detected for $vcenterserver");
} elsif (scalar(@user_list) > 1) {
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

### retreive vcenter hostname
my $vcenter_fqdn = $vcenterserver;

$vcenter_fqdn =~ s/[ .]/_/g;
my $vcenter_name = lc ($vcenter_fqdn);

my $perfMgr = (Vim::get_view(mo_ref => Vim::get_service_content()->perfManager));
my %perfCntr = map { $_->groupInfo->key . "." . $_->nameInfo->key . "." . $_->rollupType->val => $_ } @{$perfMgr->perfCounter};

sub MultiQueryPerfAll {
	my ($query_entity_views, @query_perfCntrs) = @_;

	my $perfKey;
	my @perfKeys;
	for my $row ( 0..$#query_perfCntrs ) {
		my $perfKey = $perfCntr{"$query_perfCntrs[$row][0].$query_perfCntrs[$row][1].$query_perfCntrs[$row][2]"}->key;
		push @perfKeys,$perfKey;
	}

	my $metricId;
	my @metricIDs;
	foreach (@perfKeys) {
		$metricId = PerfMetricId->new(counterId => $_, instance => '*');
		push @metricIDs,$metricId;
	}

	my $perfQuerySpec;
	my @perfQuerySpecs;
	foreach (@$query_entity_views) {
		$perfQuerySpec = PerfQuerySpec->new(entity => $_, maxSample => 15, intervalId => 20, metricId => \@metricIDs);
		push @perfQuerySpecs,$perfQuerySpec;
	}

	my $metrics = $perfMgr->QueryPerf(querySpec => [@perfQuerySpecs]);
	### https://kb.vmware.com/s/article/2107096

	my %fatmetrics;
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
	my @perfKeys;
	for my $row ( 0..$#query_perfCntrs ) {
		my $perfKey = $perfCntr{"$query_perfCntrs[$row][0].$query_perfCntrs[$row][1].$query_perfCntrs[$row][2]"}->key;
		push @perfKeys,$perfKey;
	}

	my $metricId;
	my @metricIDs;
	foreach (@perfKeys) {
		$metricId = PerfMetricId->new(counterId => $_, instance => '');
		push @metricIDs,$metricId;
	}

	my $perfQuerySpec;
	my @perfQuerySpecs;
	foreach (@$query_entity_views) {
		$perfQuerySpec = PerfQuerySpec->new(entity => $_, maxSample => 15, intervalId => 20, metricId => \@metricIDs);
		push @perfQuerySpecs,$perfQuerySpec;
	}

	my $metrics = $perfMgr->QueryPerf(querySpec => [@perfQuerySpecs]);
	### https://kb.vmware.com/s/article/2107096

	my %fatmetrics;
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

my @cluster_vm_view_snap_tree;
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

$logger->info("[INFO] Processing vCenter $vcenterserver objects");
if ($BFG_Mode) {$logger->info("[DEBUG] BFG Mode activated for vCenter $vcenterserver");}

### retreive viobjets and build moref-objects tables

my $all_folder_views = Vim::find_entity_views(view_type => 'Folder', properties => ['name', 'parent']);
my %all_folder_views_table = ();
foreach my $all_folder_view (@$all_folder_views) {
	$all_folder_views_table{$all_folder_view->{'mo_ref'}->value} = $all_folder_view;
}

my $all_datacentres_views = Vim::find_entity_views(view_type => 'Datacenter', properties => ['name', 'parent']);

my $all_cluster_root_pool_views = Vim::find_entity_views(view_type => 'ResourcePool', filter => {name => qr/^Resources$/}, properties => ['summary.quickStats', 'parent']);

my %all_cluster_root_pool_views_table = ();
foreach my $all_cluster_root_pool_view (@$all_cluster_root_pool_views) {
	$all_cluster_root_pool_views_table{$all_cluster_root_pool_view->{'parent'}->value} = $all_cluster_root_pool_view;
	# $all_cluster_root_pool_views_table{$all_cluster_root_pool_view->{'mo_ref'}->value} = $all_cluster_root_pool_view;
}

my $all_cluster_views;
my $all_compute_views;
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

my $all_host_views = Vim::find_entity_views(view_type => 'HostSystem', properties => ['config.network.pnic', 'config.network.vnic', 'config.network.dnsConfig.hostName', 'runtime.connectionState', 'summary.hardware.numCpuCores', 'summary.quickStats.distributedCpuFairness', 'summary.quickStats.distributedMemoryFairness', 'summary.quickStats.overallCpuUsage', 'summary.quickStats.overallMemoryUsage', 'summary.quickStats.uptime', 'overallStatus', 'config.storageDevice.hostBusAdapter', 'vm'], filter => {'runtime.connectionState' => "connected"});
my %all_host_views_table = ();
foreach my $all_host_view (@$all_host_views) {
	$all_host_views_table{$all_host_view->{'mo_ref'}->value} = $all_host_view;
}

my $all_datastore_views = Vim::find_entity_views(view_type => 'Datastore', properties => ['summary', 'iormConfiguration.enabled', 'iormConfiguration.statsCollectionEnabled', 'host'], filter => {'summary.multipleHostAccess' => "true"});
my %all_datastore_views_table = ();
foreach my $all_datastore_view (@$all_datastore_views) {
	$all_datastore_views_table{$all_datastore_view->{'mo_ref'}->value} = $all_datastore_view;
}

my $all_pod_views = Vim::find_entity_views(view_type => 'StoragePod', properties => ['name','summary','parent','childEntity']);
my %all_pod_views_table = ();
foreach my $all_pod_view (@$all_pod_views) {
	$all_pod_views_table{$all_pod_view->{'mo_ref'}->value} = $all_pod_view;
}

my $all_vm_views = Vim::find_entity_views(view_type => 'VirtualMachine', properties => ['name', 'runtime.maxCpuUsage', 'runtime.maxMemoryUsage', 'summary.quickStats.overallCpuUsage', 'summary.quickStats.overallCpuDemand', 'summary.quickStats.hostMemoryUsage', 'summary.quickStats.guestMemoryUsage', 'summary.quickStats.balloonedMemory', 'summary.quickStats.compressedMemory', 'summary.quickStats.swappedMemory', 'summary.storage.committed', 'summary.storage.uncommitted', 'config.hardware.numCPU', 'layoutEx.file', 'snapshot', 'runtime.host', 'summary.runtime.connectionState', 'summary.runtime.powerState', 'summary.config.numVirtualDisks', 'guest.disk', 'guest.disk'], filter => {'summary.runtime.connectionState' => "connected"});
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

my %hostmultistats;
my %vmmultistats;

if (!$BFG_Mode){

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
		# ["rescpu", "actav5", "latest"],
	);
	%hostmultistats = MultiQueryPerfAll($all_host_views, @hostmultimetrics);
	my $hostmultimetricsend = Time::HiRes::gettimeofday();
	my $hostmultimetricstimelapse = $hostmultimetricsend - $hostmultimetricsstart;
	$logger->info("[DEBUG] computed all hosts multi metrics in $hostmultimetricstimelapse sec for vCenter $vcenterserver");

	my $vmmultimetricsstart = Time::HiRes::gettimeofday();
	my @vmmultimetrics = (
		["cpu", "ready", "summation"],
		["cpu", "latency", "average"],
		["disk", "maxTotalLatency", "latest"],
		["disk", "usage", "average"],
		# ["disk", "commandsAveraged", "average"],
		["net", "usage", "average"],
	);
	%vmmultistats = MultiQueryPerf($all_vm_views, @vmmultimetrics);
	my $vmmultimetricsend = Time::HiRes::gettimeofday();
	my $vmmultimetricstimelapse = $vmmultimetricsend - $vmmultimetricsstart;
	$logger->info("[DEBUG] computed all vms multi metrics in $vmmultimetricstimelapse sec for vCenter $vcenterserver");

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
		["cpu", "latency", "average"],
	);
	%hostmultistats = MultiQueryPerfAll($all_host_views, @hostmultimetrics);
	my $hostmultimetricsend = Time::HiRes::gettimeofday();
	my $hostmultimetricstimelapse = $hostmultimetricsend - $hostmultimetricsstart;
	$logger->info("[DEBUG] computed all hosts multi metrics in $hostmultimetricstimelapse sec for vCenter $vcenterserver");

}

my $cluster_hosts_views_pcpus;
my @cluster_hosts_vms_moref;
my @cluster_hosts_cpu_latency;
my @cluster_hosts_net_bytesRx;
my @cluster_hosts_net_bytesTx;
my @cluster_hosts_hba_bytesRead;
my @cluster_hosts_hba_bytesWrite;
my @cluster_hosts_power_usage;

foreach my $cluster_view (@$all_cluster_views) {
	my $cluster_name = nameCleaner($cluster_view->name);

	my $datacentre_name = nameCleaner(getRootDc $cluster_view);


	$logger->info("[INFO] Processing vCenter $vcenterserver cluster $cluster_name hosts in datacenter $datacentre_name");

	if (my $cluster_root_pool_view = $all_cluster_root_pool_views_table{$cluster_view->{'mo_ref'}->value}) {

		my $cluster_root_pool_quickStats = $cluster_root_pool_view->{'summary.quickStats'};
		my $cluster_root_pool_view_h = {
			time() => {
				"$vcenter_name.$datacentre_name.$cluster_name" . ".quickstats.mem.ballooned", $cluster_root_pool_quickStats->balloonedMemory,
				"$vcenter_name.$datacentre_name.$cluster_name" . ".quickstats.mem.compressed", $cluster_root_pool_quickStats->compressedMemory,
				"$vcenter_name.$datacentre_name.$cluster_name" . ".quickstats.mem.consumedOverhead", $cluster_root_pool_quickStats->consumedOverheadMemory,
				### "$vcenter_name.$datacentre_name.$cluster_name" . ".quickstats.cpu.distributedCpuEntitlement", $cluster_root_pool_quickStats->distributedCpuEntitlement,
				### "$vcenter_name.$datacentre_name.$cluster_name" . ".quickstats.mem.distributedMemoryEntitlement", $cluster_root_pool_quickStats->distributedMemoryEntitlement,
				"$vcenter_name.$datacentre_name.$cluster_name" . ".quickstats.mem.guest", $cluster_root_pool_quickStats->guestMemoryUsage,
				"$vcenter_name.$datacentre_name.$cluster_name" . ".quickstats.mem.usage", $cluster_root_pool_quickStats->hostMemoryUsage,
				"$vcenter_name.$datacentre_name.$cluster_name" . ".quickstats.cpu.demand", $cluster_root_pool_quickStats->overallCpuDemand,
				"$vcenter_name.$datacentre_name.$cluster_name" . ".quickstats.cpu.usage", $cluster_root_pool_quickStats->overallCpuUsage,
				"$vcenter_name.$datacentre_name.$cluster_name" . ".quickstats.mem.overhead", $cluster_root_pool_quickStats->overheadMemory,
				"$vcenter_name.$datacentre_name.$cluster_name" . ".quickstats.mem.private", $cluster_root_pool_quickStats->privateMemory,
				### "$vcenter_name.$datacentre_name.$cluster_name" . ".quickstats.cpu.staticCpuEntitlement", $cluster_root_pool_quickStats->staticCpuEntitlement,
				### "$vcenter_name.$datacentre_name.$cluster_name" . ".quickstats.mem.staticMemoryEntitlement", $cluster_root_pool_quickStats->staticMemoryEntitlement,
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

		if ($cluster_root_pool_quickStats->overallCpuUsage > 0 && $cluster_view->summary->effectiveCpu > 0) {
			my $cluster_root_pool_quickStats_cpu = $cluster_root_pool_quickStats->overallCpuUsage * 100 / $cluster_view->summary->effectiveCpu;
			my $cluster_host_view_h = {
				time() => {
					"$vcenter_name.$datacentre_name.$cluster_name" . ".superstats.cpu.utilization", $cluster_root_pool_quickStats_cpu,
				},
			};
			$graphite->send(path => "vmw", data => $cluster_host_view_h);	
		}

		if ($cluster_root_pool_quickStats->hostMemoryUsage > 0 && $cluster_view->summary->effectiveMemory > 0) {
			my $cluster_root_pool_quickStats_ram = $cluster_root_pool_quickStats->hostMemoryUsage * 100 / $cluster_view->summary->effectiveMemory;
			my $cluster_host_view_h = {
				time() => {
					"$vcenter_name.$datacentre_name.$cluster_name" . ".superstats.mem.utilization", $cluster_root_pool_quickStats_ram,
				},
			};
			$graphite->send(path => "vmw", data => $cluster_host_view_h);	
		}		
	}


	my @cluster_hosts_views;
	my $cluster_hosts_moref = $cluster_view->host;
	foreach my $cluster_host_moref (@$cluster_hosts_moref) {
		if ($all_host_views_table{$cluster_host_moref->{'value'}}) {
			push (@cluster_hosts_views,$all_host_views_table{$cluster_host_moref->{'value'}});
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

		$cluster_hosts_views_pcpus += $cluster_host_view->{'summary.hardware.numCpuCores'};

		foreach my $cluster_host_vmnic (@{$cluster_host_view->{'config.network.pnic'}}) {
			if ($cluster_host_vmnic->linkSpeed && $cluster_host_vmnic->linkSpeed->speedMb >= 100) {
				my $cluster_host_vmnic_name = $cluster_host_vmnic->device;
				my $NetbytesRx = $hostmultistats{$perfCntr{"net.bytesRx.average"}->key}{$cluster_host_view->{'mo_ref'}->value}{$cluster_host_vmnic_name};
				my $NetbytesTx = $hostmultistats{$perfCntr{"net.bytesTx.average"}->key}{$cluster_host_view->{'mo_ref'}->value}{$cluster_host_vmnic_name};
				if (defined($NetbytesRx) && defined($NetbytesTx)) {
					push (@cluster_hosts_net_bytesRx,$NetbytesRx);
					push (@cluster_hosts_net_bytesTx,$NetbytesTx);
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
		}

		foreach my $cluster_host_vmnic (@{$cluster_host_view->{'config.network.pnic'}}) {
			if ($cluster_host_vmnic->linkSpeed && $cluster_host_vmnic->linkSpeed->speedMb >= 100) {
				my $NetdroppedRx = $hostmultistats{$perfCntr{"net.droppedRx.summation"}->key}{$cluster_host_view->{'mo_ref'}->value}{$cluster_host_vmnic->device};
				my $NetdroppedTx = $hostmultistats{$perfCntr{"net.droppedTx.summation"}->key}{$cluster_host_view->{'mo_ref'}->value}{$cluster_host_vmnic->device};
				if ((defined($NetdroppedTx) && defined($NetdroppedRx)) && ($NetdroppedTx > 0 or $NetdroppedRx > 0)) {
					my $cluster_host_vmnic_name = $cluster_host_vmnic->device;
					my $cluster_host_vmnic_h = {
						time() => {
							"$vcenter_name.$datacentre_name.$cluster_name.esx.$host_name" . ".net.$cluster_host_vmnic_name.droppedRx", $NetdroppedRx,
							"$vcenter_name.$datacentre_name.$cluster_name.esx.$host_name" . ".net.$cluster_host_vmnic_name.droppedTx", $NetdroppedTx,
						},
					};
					$graphite->send(path => "vmw", data => $cluster_host_vmnic_h);
				}
			}
		}

		foreach my $cluster_host_vmnic (@{$cluster_host_view->{'config.network.pnic'}}) {
			if ($cluster_host_vmnic->linkSpeed && $cluster_host_vmnic->linkSpeed->speedMb >= 100) {
				my $NeterrorsRx = $hostmultistats{$perfCntr{"net.errorsRx.summation"}->key}{$cluster_host_view->{'mo_ref'}->value}{$cluster_host_vmnic->device};
				my $NeterrorsTx = $hostmultistats{$perfCntr{"net.errorsTx.summation"}->key}{$cluster_host_vmnic->device};
				if (defined($NeterrorsRx) && defined($NeterrorsTx)) {
					my $cluster_host_vmnic_name = $cluster_host_vmnic->device;
					my $cluster_host_vmnic_h = {
						time() => {
							"$vcenter_name.$datacentre_name.$cluster_name.esx.$host_name" . ".net.$cluster_host_vmnic_name.errorsRx", $NeterrorsRx,
							"$vcenter_name.$datacentre_name.$cluster_name.esx.$host_name" . ".net.$cluster_host_vmnic_name.errorsTx", $NeterrorsTx,
						},
					};
					$graphite->send(path => "vmw", data => $cluster_host_vmnic_h);
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
					my $cluster_host_vmhba_h = {
						time() => {
							"$vcenter_name.$datacentre_name.$cluster_name.esx.$host_name" . ".hba.$cluster_host_vmhba_name.bytesRead", $HbabytesRead,
							"$vcenter_name.$datacentre_name.$cluster_name.esx.$host_name" . ".hba.$cluster_host_vmhba_name.bytesWrite", $HbabytesWrite,
						},
					};
					$graphite->send(path => "vmw", data => $cluster_host_vmhba_h);
				}
		}

		my $cluster_host_view_power = $hostmultistats{$perfCntr{"power.power.average"}->key}{$cluster_host_view->{'mo_ref'}->value}{""};
		if (defined($cluster_host_view_power)) {
			push (@cluster_hosts_power_usage,$cluster_host_view_power);
			my $cluster_host_view_h = {
				time() => {
					"$vcenter_name.$datacentre_name.$cluster_name.esx.$host_name" . ".fatstats.power", $cluster_host_view_power,
				},
			};
			$graphite->send(path => "vmw", data => $cluster_host_view_h);
		}

		my $cluster_host_view_cpu_latency = $hostmultistats{$perfCntr{"cpu.latency.average"}->key}{$cluster_host_view->{'mo_ref'}->value}{""};
		if (defined($cluster_host_view_cpu_latency)) {
			push (@cluster_hosts_cpu_latency,$cluster_host_view_cpu_latency); #to scale 0.01
		}

		# my $cluster_host_view_rescpu_actav5 = $hostmultistats{$perfCntr{"rescpu.actav5.latest"}->key}{$cluster_host_view->{'mo_ref'}->value}{""};

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
				"$vcenter_name.$datacentre_name.$cluster_name.esx.$host_name" . ".quickstats.distributedCpuFairness", $cluster_host_view->{'summary.quickStats.distributedCpuFairness'},
				"$vcenter_name.$datacentre_name.$cluster_name.esx.$host_name" . ".quickstats.distributedMemoryFairness", $cluster_host_view->{'summary.quickStats.distributedMemoryFairness'},
				"$vcenter_name.$datacentre_name.$cluster_name.esx.$host_name" . ".quickstats.overallCpuUsage", $cluster_host_view->{'summary.quickStats.overallCpuUsage'},
				"$vcenter_name.$datacentre_name.$cluster_name.esx.$host_name" . ".quickstats.overallMemoryUsage", $cluster_host_view->{'summary.quickStats.overallMemoryUsage'},
				"$vcenter_name.$datacentre_name.$cluster_name.esx.$host_name" . ".quickstats.Uptime", $cluster_host_view->{'summary.quickStats.uptime'},
				"$vcenter_name.$datacentre_name.$cluster_name.esx.$host_name" . ".quickstats.overallStatus", $cluster_host_view_status_val,
				# "$vcenter_name.$datacentre_name.$cluster_name.esx.$host_name" . ".fatstats.load", $cluster_host_view_rescpu_actav5,
			},
		};
		$graphite->send(path => "vmw", data => $cluster_host_view_h);
	}

	if (scalar @cluster_hosts_views > 0) {
		my $cluster_host_view_h = {
			time() => {
				"$vcenter_name.$datacentre_name.$cluster_name" . ".superstats.esx.count", (scalar @cluster_hosts_views),
			},
		};
		$graphite->send(path => "vmw", data => $cluster_host_view_h);	
	}

	if (scalar @cluster_hosts_cpu_latency > 0) {
		my $cluster_host_view_h = {
			time() => {
				"$vcenter_name.$datacentre_name.$cluster_name" . ".superstats.cpu.latency", median(@cluster_hosts_cpu_latency),
			},
		};
		$graphite->send(path => "vmw", data => $cluster_host_view_h);		
	}

	if (scalar @cluster_hosts_net_bytesRx > 0 && scalar @cluster_hosts_net_bytesTx > 0) {
		my $cluster_host_view_h = {
			time() => {
				"$vcenter_name.$datacentre_name.$cluster_name" . ".superstats.net.bytesRx", sum(@cluster_hosts_net_bytesRx),
				"$vcenter_name.$datacentre_name.$cluster_name" . ".superstats.net.bytesTx", sum(@cluster_hosts_net_bytesTx),
			},
		};
		$graphite->send(path => "vmw", data => $cluster_host_view_h);		
	}

	if (scalar @cluster_hosts_hba_bytesRead > 0 && scalar @cluster_hosts_hba_bytesWrite > 0) {
		my $cluster_host_view_h = {
			time() => {
				"$vcenter_name.$datacentre_name.$cluster_name" . ".superstats.hba.bytesRead", sum(@cluster_hosts_hba_bytesRead),
				"$vcenter_name.$datacentre_name.$cluster_name" . ".superstats.hba.bytesWrite", sum(@cluster_hosts_hba_bytesWrite),
			},
		};
		$graphite->send(path => "vmw", data => $cluster_host_view_h);		
	}

	if (scalar @cluster_hosts_power_usage > 0) {
		my $cluster_host_view_h = {
			time() => {
				"$vcenter_name.$datacentre_name.$cluster_name" . ".superstats.power", sum(@cluster_hosts_power_usage),
			},
		};
		$graphite->send(path => "vmw", data => $cluster_host_view_h);		
	}

	$logger->info("[INFO] Processing vCenter $vcenterserver cluster $cluster_name vms in datacenter $datacentre_name");

	my @cluster_vms_views;
	if (scalar(@cluster_hosts_vms_moref) > 0) {
		foreach my $cluster_vm_moref (@cluster_hosts_vms_moref) {
			if ($all_vm_views_table{$cluster_vm_moref->{'value'}}) {
				push (@cluster_vms_views,$all_vm_views_table{$cluster_vm_moref->{'value'}});
			}
		}
	}

	my $cluster_vm_views_vcpus = 0;
	my $cluster_vm_views_vram = 0;
	my $cluster_vm_views_vnic_usage = 0;	
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

					### @cluster_vm_view_snap_tree = ();
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

				if (!$BFG_Mode) {

					if ($cluster_vm_view_snap_size > 0) {
						my $cluster_vm_view_snap_size_h = {
							time() => {
								"$vcenter_name.$datacentre_name.$cluster_name.vm.$cluster_vm_view_name" . ".storage.delta", $cluster_vm_view_snap_size,
							},
						};
						$graphite->send(path => "vmw", data => $cluster_vm_view_snap_size_h);
					}

					if ($cluster_vm_view->{'runtime.maxCpuUsage'} > 0 && $cluster_vm_view->{'summary.quickStats.overallCpuUsage'}) {
						my $cluster_vm_view_CpuUtilization = $cluster_vm_view->{'summary.quickStats.overallCpuUsage'} * 100 / $cluster_vm_view->{'runtime.maxCpuUsage'};
						my $cluster_vm_view_CpuUtilization_h = {
							time() => {
								"$vcenter_name.$datacentre_name.$cluster_name.vm.$cluster_vm_view_name" . ".runtime.CpuUtilization", $cluster_vm_view_CpuUtilization,
							},
						};
						$graphite->send(path => "vmw", data => $cluster_vm_view_CpuUtilization_h);
					}

					if ($cluster_vm_view->{'summary.quickStats.guestMemoryUsage'} > 0 && $cluster_vm_view->{'runtime.maxMemoryUsage'}) {
						my $cluster_vm_view_MemUtilization = $cluster_vm_view->{'summary.quickStats.guestMemoryUsage'} * 100 / $cluster_vm_view->{'runtime.maxMemoryUsage'};
						my $cluster_vm_view_MemUtilization_h = {
							time() => {
								"$vcenter_name.$datacentre_name.$cluster_name.vm.$cluster_vm_view_name" . ".runtime.MemUtilization", $cluster_vm_view_MemUtilization,
							},
						};
						$graphite->send(path => "vmw", data => $cluster_vm_view_MemUtilization_h);
					}

					my $cluster_vm_view_h = {
						time() => {
							"$vcenter_name.$datacentre_name.$cluster_name.vm.$cluster_vm_view_name" . ".quickstats.overallCpuUsage", $cluster_vm_view->{'summary.quickStats.overallCpuUsage'},
							"$vcenter_name.$datacentre_name.$cluster_name.vm.$cluster_vm_view_name" . ".quickstats.overallCpuDemand", $cluster_vm_view->{'summary.quickStats.overallCpuDemand'},
							"$vcenter_name.$datacentre_name.$cluster_name.vm.$cluster_vm_view_name" . ".quickstats.HostMemoryUsage", $cluster_vm_view->{'summary.quickStats.hostMemoryUsage'},
							"$vcenter_name.$datacentre_name.$cluster_name.vm.$cluster_vm_view_name" . ".quickstats.GuestMemoryUsage", $cluster_vm_view->{'summary.quickStats.guestMemoryUsage'},
							"$vcenter_name.$datacentre_name.$cluster_name.vm.$cluster_vm_view_name" . ".storage.committed", $cluster_vm_view->{'summary.storage.committed'},
							"$vcenter_name.$datacentre_name.$cluster_name.vm.$cluster_vm_view_name" . ".storage.uncommitted", $cluster_vm_view->{'summary.storage.uncommitted'},
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

					if ($vmmultistats{$perfCntr{"cpu.ready.summation"}->key}{$cluster_vm_view->{'mo_ref'}->value}{""}) {
						my $vmreadyavg = $vmmultistats{$perfCntr{"cpu.ready.summation"}->key}{$cluster_vm_view->{'mo_ref'}->value}{""} / $cluster_vm_view->{'config.hardware.numCPU'} / 20000 * 100;
						### https://kb.vmware.com/kb/2002181
						my $cluster_vm_view_ready_h = {
							time() => {
								"$vcenter_name.$datacentre_name.$cluster_name.vm.$cluster_vm_view_name" . ".fatstats.cpu_ready_summation", $vmreadyavg,
							},
						};
						$graphite->send(path => "vmw", data => $cluster_vm_view_ready_h);
					}

					if ($vmmultistats{$perfCntr{"cpu.latency.average"}->key}{$cluster_vm_view->{'mo_ref'}->value}{""}) {
						my $vmlatencyval = $vmmultistats{$perfCntr{"cpu.latency.average"}->key}{$cluster_vm_view->{'mo_ref'}->value}{""};
						my $cluster_vm_view_latency_h = {
							time() => {
								"$vcenter_name.$datacentre_name.$cluster_name.vm.$cluster_vm_view_name" . ".fatstats.cpu_latency_average", $vmlatencyval,
							},
						};
						$graphite->send(path => "vmw", data => $cluster_vm_view_latency_h);
					}

					if ($vmmultistats{$perfCntr{"disk.maxTotalLatency.latest"}->key}{$cluster_vm_view->{'mo_ref'}->value}{""}) {
						my $vmmaxtotallatencyval = $vmmultistats{$perfCntr{"disk.maxTotalLatency.latest"}->key}{$cluster_vm_view->{'mo_ref'}->value}{""};
						my $cluster_vm_view_maxtotallatency_h = {
							time() => {
								"$vcenter_name.$datacentre_name.$cluster_name.vm.$cluster_vm_view_name" . ".fatstats.maxTotalLatency", $vmmaxtotallatencyval,
							},
						};
						$graphite->send(path => "vmw", data => $cluster_vm_view_maxtotallatency_h);
					}

					if ($vmmultistats{$perfCntr{"disk.usage.average"}->key}{$cluster_vm_view->{'mo_ref'}->value}{""}) {
						my $vmdiskusageval = $vmmultistats{$perfCntr{"disk.usage.average"}->key}{$cluster_vm_view->{'mo_ref'}->value}{""};
						my $cluster_vm_view_diskusage_h = {
							time() => {
								"$vcenter_name.$datacentre_name.$cluster_name.vm.$cluster_vm_view_name" . ".fatstats.diskUsage", $vmdiskusageval,
							},
						};
						$graphite->send(path => "vmw", data => $cluster_vm_view_diskusage_h);
					}

					if ($vmmultistats{$perfCntr{"net.usage.average"}->key}{$cluster_vm_view->{'mo_ref'}->value}{""}) {
						my $vmnetusageval = $vmmultistats{$perfCntr{"net.usage.average"}->key}{$cluster_vm_view->{'mo_ref'}->value}{""};
						$cluster_vm_views_vnic_usage += $vmnetusageval;
						my $cluster_vm_view_netusage_h = {
							time() => {
								"$vcenter_name.$datacentre_name.$cluster_name.vm.$cluster_vm_view_name" . ".fatstats.netUsage", $vmnetusageval,
							},
						};
						$graphite->send(path => "vmw", data => $cluster_vm_view_netusage_h);
					}

					# if ($vmmultistats{$perfCntr{"disk.commandsAveraged.average"}->key}{$cluster_vm_view->{'mo_ref'}->value}{""}) {
					# 	my $vmcommandsAveragedval = $vmmultistats{$perfCntr{"disk.commandsAveraged.average"}->key}{$cluster_vm_view->{'mo_ref'}->value}{""};
					# 	my $cluster_vm_view_commandsAveraged_h = {
					# 		time() => {
					# 			"$vcenter_name.$datacentre_name.$cluster_name.vm.$cluster_vm_view_name" . ".fatstats.diskCommands", $vmcommandsAveragedval,
					# 		},
					# 	};
					# 	$graphite->send(path => "vmw", data => $cluster_vm_view_commandsAveraged_h);
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

					### @cluster_vm_view_snap_tree = ();
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

				if (!$BFG_Mode) {

					if ($cluster_vm_view_off_snap_size > 0) {
						my $cluster_vm_view_off_snap_size_h = {
							time() => {
								"$vcenter_name.$datacentre_name.$cluster_name.vm.$cluster_vm_view_off_name" . ".storage.delta", $cluster_vm_view_off_snap_size,
							},
						};
						$graphite->send(path => "vmw", data => $cluster_vm_view_off_snap_size_h);
					}

					my $cluster_vm_view_off_h = {
						time() => {
							"$vcenter_name.$datacentre_name.$cluster_name.vm.$cluster_vm_view_off_name" . ".storage.committed", $cluster_vm_view_off->{'summary.storage.committed'},
							"$vcenter_name.$datacentre_name.$cluster_name.vm.$cluster_vm_view_off_name" . ".storage.uncommitted", $cluster_vm_view_off->{'summary.storage.uncommitted'},
						},
					};
					$graphite->send(path => "vmw", data => $cluster_vm_view_off_h);
				}
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

		if ($cluster_vm_views_vram > 0) {
			my $cluster_root_pool_quickStats_vram = $cluster_vm_views_vram * 100 / $cluster_view->summary->effectiveMemory;
			my $cluster_vm_views_vram_h = {
				time() => {
					"$vcenter_name.$datacentre_name.$cluster_name" . ".quickstats.vRAM", $cluster_vm_views_vram,
					"$vcenter_name.$datacentre_name.$cluster_name" . ".superstats.mem.allocated", $cluster_root_pool_quickStats_vram,
				},
			};
			$graphite->send(path => "vmw", data => $cluster_vm_views_vram_h);
		}

		if ($cluster_vm_views_vnic_usage > 0) {
			my $cluster_vm_views_vnic_usage_h = {
				time() => {
					"$vcenter_name.$datacentre_name.$cluster_name" . ".superstats.net.vmnicUsage", $cluster_vm_views_vnic_usage,
				},
			};
			$graphite->send(path => "vmw", data => $cluster_vm_views_vnic_usage_h);
		}

		if ($cluster_vm_views_files_dedup_total) {

			foreach my $FileType (keys %$cluster_vm_views_files_dedup_total) {
				my $cluster_vm_views_files_type_h = {
					time() => {
						"$vcenter_name.$datacentre_name.$cluster_name" . ".storage.FileType." . "$FileType", $cluster_vm_views_files_dedup_total->{$FileType},
					},
				};
				$graphite->send(path => "vmw", data => $cluster_vm_views_files_type_h);
			}

			if ($cluster_vm_views_files_snaps) {
				my $cluster_vm_views_files_snaps_h = {
					time() => {
						"$vcenter_name.$datacentre_name.$cluster_name" . ".storage." . "SnapshotCount", $cluster_vm_views_files_snaps,
					},
				};
				$graphite->send(path => "vmw", data => $cluster_vm_views_files_snaps_h);
			}

			### if ($cluster_vm_views_bak_snaps) {
			### 	my $cluster_vm_views_bak_snaps_h = {
			### 		time() => {
			### 			"$vcenter_name.$datacentre_name.$cluster_name" . ".storage." . "BakSnapshotCount", $cluster_vm_views_bak_snaps,
			### 		},
			### 	};
			### 	$graphite->send(path => "vmw", data => $cluster_vm_views_bak_snaps_h);
			### }

			if ($cluster_vm_views_vm_snaps) {
				my $cluster_vm_views_vm_snaps_h = {
					time() => {
						"$vcenter_name.$datacentre_name.$cluster_name" . ".storage." . "VmSnapshotCount", $cluster_vm_views_vm_snaps,
					},
				};
				$graphite->send(path => "vmw", data => $cluster_vm_views_vm_snaps_h);
			}
		}
	}

	my $cluster_vm_views_h = {
		time() => {
			"$vcenter_name.$datacentre_name.$cluster_name" . ".runtime.vm.total", scalar(@cluster_vms_views),
			"$vcenter_name.$datacentre_name.$cluster_name" . ".runtime.vm.on", (scalar(@cluster_vms_views) - $cluster_vm_views_off),
		},
	};
	$graphite->send(path => "vmw", data => $cluster_vm_views_h);

	$logger->info("[INFO] Processing vCenter $vcenterserver cluster $cluster_name datastores in datacenter $datacentre_name");

	my @cluster_datastores_views;
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

			my $cluster_shared_datastore_view_h = {
				time() => {
					"$vcenter_name.$datacentre_name.$cluster_name.datastore.$shared_datastore_name" . ".summary.capacity", $cluster_datastore_view->summary->capacity,
					"$vcenter_name.$datacentre_name.$cluster_name.datastore.$shared_datastore_name" . ".summary.freeSpace", $cluster_datastore_view->summary->freeSpace,
					"$vcenter_name.$datacentre_name.$cluster_name.datastore.$shared_datastore_name" . ".summary.uncommitted", $shared_datastore_uncommitted,
				},
			};
			$graphite->send(path => "vmw", data => $cluster_shared_datastore_view_h);

			if ($cluster_vmdk_per_ds->{$shared_datastore_name}) {
				my $cluster_shared_datastorevmdk_per_ds_view_h = {
					time() => {
						"$vcenter_name.$datacentre_name.$cluster_name.datastore.$shared_datastore_name" . ".summary.vmdkCount", $cluster_vmdk_per_ds->{$shared_datastore_name},
					},
				};
				$graphite->send(path => "vmw", data => $cluster_shared_datastorevmdk_per_ds_view_h);				
			}

			push (@cluster_datastores_capacity,$cluster_datastore_view->summary->capacity);
			push (@cluster_datastores_freeSpace,$cluster_datastore_view->summary->freeSpace);
			push (@cluster_datastores_uncommitted,$shared_datastore_uncommitted);

			if ($cluster_datastore_view->{'iormConfiguration.enabled'} or $cluster_datastore_view->{'iormConfiguration.statsCollectionEnabled'}) {

				my @vmpath = split("/", $cluster_datastore_view->summary->url);
				my $uuid = $vmpath[-1];

				my @dsiormlatencyuuid;
				my @dsiormiopsuuid;
				my $middsiormlatencyuuid;
				my $middsiormiopsuuid;
				
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

					my $DsIormPerf_h = {
						time() => {
							"$vcenter_name.$datacentre_name.$cluster_name.datastore.$shared_datastore_name" . ".iorm.sizeNormalizedDatastoreLatency", $middsiormlatencyuuid,
							"$vcenter_name.$datacentre_name.$cluster_name.datastore.$shared_datastore_name" . ".iorm.datastoreIops", $middsiormiopsuuid,
						},
					};
					$graphite->send(path => "vmw", data => $DsIormPerf_h);
				}

			} elsif ($cluster_datastore_view->summary->type ne "vsan") {

				my @vmpath = split("/", $cluster_datastore_view->summary->url);
				my $uuid = $vmpath[-1];

				my @dstotalWriteLatencyuuid;
				my @dstotalReadLatencyuuid;
				my @dstotalReadIouuid;
				my @dstotalWriteIouuid;
				my $middstotalWriteLatencyuuid;
				my $middstotalReadLatencyuuid;
				my $middstotalReadIouuid;
				my $middstotalWriteIouuid;
				my $middsLegacylatencyuuid;
				my $middsLegacyiopsuuid;

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

					my $DsLegacyPerf_h = {
						time() => {
							"$vcenter_name.$datacentre_name.$cluster_name.datastore.$shared_datastore_name" . ".iorm.sizeNormalizedDatastoreLatency", $middsLegacylatencyuuid,
							"$vcenter_name.$datacentre_name.$cluster_name.datastore.$shared_datastore_name" . ".iorm.datastoreIops", $middsLegacyiopsuuid,
						},
					};
					$graphite->send(path => "vmw", data => $DsLegacyPerf_h);

				}
			}
		### } elsif ($cluster_datastore_view->summary->accessible && !$cluster_datastore_view->summary->multipleHostAccess) {
		### 	my $unshared_datastore_name = nameCleaner($cluster_datastore_view->summary->name);

		### 	my $unshared_datastore_uncommitted = 0;
		### 	if ($cluster_datastore_view->summary->uncommitted) {
		### 		$unshared_datastore_uncommitted = $cluster_datastore_view->summary->uncommitted;
		### 	}
		### 	my $cluster_unshared_datastore_view_h = {
		### 		time() => {
		### 			"$vcenter_name.$datacentre_name.$cluster_name.UNdatastore.$unshared_datastore_name" . ".summary.capacity", $cluster_datastore_view->summary->capacity,
		### 			"$vcenter_name.$datacentre_name.$cluster_name.UNdatastore.$unshared_datastore_name" . ".summary.freeSpace", $cluster_datastore_view->summary->freeSpace,
		### 			"$vcenter_name.$datacentre_name.$cluster_name.UNdatastore.$unshared_datastore_name" . ".summary.uncommitted", $unshared_datastore_uncommitted,
		### 		},
		### 	};
		### 	$graphite->send(path => "vmw", data => $cluster_unshared_datastore_view_h);
		}
	}

	if ($cluster_datastores_count > 0) {
		my $cluster_datastores_utilization = (sum(@cluster_datastores_capacity) - sum(@cluster_datastores_freeSpace)) * 100 / sum(@cluster_datastores_capacity);
		my $cluster_shared_datastore_view_h = {
			time() => {
				"$vcenter_name.$datacentre_name.$cluster_name" . ".superstats.datastore.count", $cluster_datastores_count,
				"$vcenter_name.$datacentre_name.$cluster_name" . ".superstats.datastore.capacity", sum(@cluster_datastores_capacity),
				"$vcenter_name.$datacentre_name.$cluster_name" . ".superstats.datastore.freeSpace", sum(@cluster_datastores_freeSpace),
				"$vcenter_name.$datacentre_name.$cluster_name" . ".superstats.datastore.utilization", $cluster_datastores_utilization,
				"$vcenter_name.$datacentre_name.$cluster_name" . ".superstats.datastore.uncommitted", sum(@cluster_datastores_uncommitted),
				"$vcenter_name.$datacentre_name.$cluster_name" . ".superstats.datastore.max_latency", max(@cluster_datastores_latency),
				"$vcenter_name.$datacentre_name.$cluster_name" . ".superstats.datastore.mid_latency", median(@cluster_datastores_latency),
				"$vcenter_name.$datacentre_name.$cluster_name" . ".superstats.datastore.iops", sum(@cluster_datastores_iops),
			},
		};
		$graphite->send(path => "vmw", data => $cluster_shared_datastore_view_h);		
	}

}

foreach my $pod_view (@$all_pod_views) {
	if ($pod_view->childEntity) {	
		my $pod_name = nameCleaner($pod_view->name);

		my $datacentre_name = nameCleaner(getRootDc $pod_view);

		$logger->info("[INFO] Processing vCenter $vcenterserver pod $pod_name in datacenter $datacentre_name");

		my @pod_datastores_views;
		my $pod_datastores_moref = $pod_view->childEntity;
		foreach my $pod_datastore_moref (@$pod_datastores_moref) {
			if ($all_datastore_views_table{$pod_datastore_moref->{'value'}}) {
				push (@pod_datastores_views,$all_datastore_views_table{$pod_datastore_moref->{'value'}});
			}
		}

		my @pod_datastores_uncommitted;
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
				"$vcenter_name.$datacentre_name.$pod_name" . ".summary.capacity", $pod_summary->capacity,
				"$vcenter_name.$datacentre_name.$pod_name" . ".summary.freeSpace", $pod_summary->freeSpace,
				"$vcenter_name.$datacentre_name.$pod_name" . ".summary.uncommitted", sum(@pod_datastores_uncommitted),
			},
		};
		$graphite->send(path => "pod", data => $pod_view_h);
	}
}

if (!$BFG_Mode) {
	$logger->info("[INFO] Processing vCenter $vcenterserver standalone hosts");

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

			my $StandaloneResourceVMHost_status = $StandaloneResourceVMHost->{'overallStatus'}->val;
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

			$logger->info("[INFO] Processing vCenter $vcenterserver standalone host $StandaloneResourceVMHostName datastores in datacenter $datacentre_name");

			my @StandaloneResourceDatastoresViews;
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

			foreach my $StandaloneResourceVMHost_vmnic (@{$StandaloneResourceVMHost->{'config.network.pnic'}}) {
				if ($StandaloneResourceVMHost_vmnic->linkSpeed && $StandaloneResourceVMHost_vmnic->linkSpeed->speedMb >= 100) {
					my $StandaloneResourceVMHost_vmnic_name = $StandaloneResourceVMHost_vmnic->device;
					my $NetbytesRx = $hostmultistats{$perfCntr{"net.bytesRx.average"}->key}{$StandaloneResourceVMHost->{'mo_ref'}->value}{$StandaloneResourceVMHost_vmnic_name};
					my $NetbytesTx = $hostmultistats{$perfCntr{"net.bytesTx.average"}->key}{$StandaloneResourceVMHost->{'mo_ref'}->value}{$StandaloneResourceVMHost_vmnic_name};

					if (defined($NetbytesRx) && defined($NetbytesTx)) {
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
			}

			my @StandaloneResourceVMHostVmsMoref;
			if ($StandaloneResourceVMHost->vm && (scalar($StandaloneResourceVMHost->vm) > 0)) {
				push (@StandaloneResourceVMHostVmsMoref,$StandaloneResourceVMHost->vm);
			}

			my @StandaloneResourceVMHostVmsViews;
			if (scalar(@StandaloneResourceVMHostVmsMoref) > 0) {
				my @StandaloneResourceVMHostVmsMorefs = map {@$_} @StandaloneResourceVMHostVmsMoref;
				foreach my $StandaloneResourceVMHostVmMoref (@StandaloneResourceVMHostVmsMorefs) {
					push (@StandaloneResourceVMHostVmsViews,$all_vm_views_table{$StandaloneResourceVMHostVmMoref->{'value'}});
				}
			}

			if (scalar(@StandaloneResourceVMHostVmsViews) > 0) {

				my $standalone_vm_views_vcpus = 0;
				my $Standalone_vm_views_on;

				$logger->info("[INFO] Processing vCenter $vcenterserver standalone host $StandaloneResourceVMHostName vms in datacenter $datacentre_name");

				foreach my $standalone_vm_view (@StandaloneResourceVMHostVmsViews) {

					my $standalone_vm_view_name = nameCleaner($standalone_vm_view->name);

					if ($standalone_vm_view->{'summary.runtime.powerState'}->{'val'} eq "poweredOn") {

						$standalone_vm_views_vcpus += $standalone_vm_view->{'config.hardware.numCPU'};
						$Standalone_vm_views_on++;

						my $standalone_vm_view_CpuUtilization = 0;
						if ($standalone_vm_view->{'runtime.maxCpuUsage'} > 0 && $standalone_vm_view->{'summary.quickStats.overallCpuUsage'} > 0) {
							$standalone_vm_view_CpuUtilization = $standalone_vm_view->{'summary.quickStats.overallCpuUsage'} * 100 / $standalone_vm_view->{'runtime.maxCpuUsage'};
						}

						my $standalone_vm_view_MemUtilization = 0;
						if ($standalone_vm_view->{'summary.quickStats.guestMemoryUsage'} > 0 && $standalone_vm_view->{'runtime.maxMemoryUsage'} > 0) {
							$standalone_vm_view_MemUtilization = $standalone_vm_view->{'summary.quickStats.guestMemoryUsage'} * 100 / $standalone_vm_view->{'runtime.maxMemoryUsage'};
						}

						my $standalone_vm_view_h = {
							time() => {
								"$vcenter_name.$datacentre_name.$StandaloneResourceVMHostName.vm.$standalone_vm_view_name" . ".quickstats.overallCpuUsage", $standalone_vm_view->{'summary.quickStats.overallCpuUsage'},
								"$vcenter_name.$datacentre_name.$StandaloneResourceVMHostName.vm.$standalone_vm_view_name" . ".quickstats.overallCpuDemand", $standalone_vm_view->{'summary.quickStats.overallCpuDemand'},
								"$vcenter_name.$datacentre_name.$StandaloneResourceVMHostName.vm.$standalone_vm_view_name" . ".quickstats.HostMemoryUsage", $standalone_vm_view->{'summary.quickStats.hostMemoryUsage'},
								"$vcenter_name.$datacentre_name.$StandaloneResourceVMHostName.vm.$standalone_vm_view_name" . ".quickstats.GuestMemoryUsage", $standalone_vm_view->{'summary.quickStats.guestMemoryUsage'},
								"$vcenter_name.$datacentre_name.$StandaloneResourceVMHostName.vm.$standalone_vm_view_name" . ".storage.committed", $standalone_vm_view->{'summary.storage.committed'},
								"$vcenter_name.$datacentre_name.$StandaloneResourceVMHostName.vm.$standalone_vm_view_name" . ".storage.uncommitted", $standalone_vm_view->{'summary.storage.uncommitted'},
								"$vcenter_name.$datacentre_name.$StandaloneResourceVMHostName.vm.$standalone_vm_view_name" . ".runtime.CpuUtilization", $standalone_vm_view_CpuUtilization,
								"$vcenter_name.$datacentre_name.$StandaloneResourceVMHostName.vm.$standalone_vm_view_name" . ".runtime.MemUtilization", $standalone_vm_view_MemUtilization,
							},
						};
						$graphite->send(path => "esx", data => $standalone_vm_view_h);

						if ($standalone_vm_view->{'summary.quickStats.balloonedMemory'} > 0) {
							my $standalone_vm_view_ballooned_h = {
								time() => {
									"$vcenter_name.$datacentre_name.$StandaloneResourceVMHostName.vm.$standalone_vm_view_name" . ".quickstats.BalloonedMemory", $standalone_vm_view->{'summary.quickStats.balloonedMemory'},
								},
							};
							$graphite->send(path => "esx", data => $standalone_vm_view_ballooned_h);
						}

						if ($standalone_vm_view->{'summary.quickStats.compressedMemory'} > 0) {
							my $standalone_vm_view_compressed_h = {
								time() => {
									"$vcenter_name.$datacentre_name.$StandaloneResourceVMHostName.vm.$standalone_vm_view_name" . ".quickstats.CompressedMemory", $standalone_vm_view->{'summary.quickStats.compressedMemory'},
								},
							};
							$graphite->send(path => "esx", data => $standalone_vm_view_compressed_h);
						}

						if ($standalone_vm_view->{'summary.quickStats.swappedMemory'} > 0) {
							my $standalone_vm_view_swapped_h = {
								time() => {
									"$vcenter_name.$datacentre_name.$StandaloneResourceVMHostName.vm.$standalone_vm_view_name" . ".quickstats.SwappedMemory", $standalone_vm_view->{'summary.quickStats.swappedMemory'},
								},
							};
							$graphite->send(path => "esx", data => $standalone_vm_view_swapped_h);
						}
					}

					my $Standalone_vm_views_h = {
						time() => {
							"$vcenter_name.$datacentre_name.$StandaloneResourceVMHostName" . ".runtime.vm.total", scalar(@StandaloneResourceVMHostVmsViews),
							"$vcenter_name.$datacentre_name.$StandaloneResourceVMHostName" . ".runtime.vm.on", $Standalone_vm_views_on,
						},
					};
					$graphite->send(path => "esx", data => $Standalone_vm_views_h);
				}
			}
		};
	}
}


my $sessionCount;
my $sessionListH = {};
my $sessionMgr = (Vim::get_view(mo_ref => Vim::get_service_content()->sessionManager));
my $sessionList = $sessionMgr->sessionList;

if ($sessionList) {
	foreach my $sessionActive (@$sessionList) {
		$sessionListH->{$sessionActive->userName}++;
	}
	$sessionCount = scalar(@$sessionList);

	my $vcenter_session_count_h = {
		time() => {
			"$vcenter_name.vi" . ".exec.sessionCount", $sessionCount,
		},
	};

	$graphite->send(path => "vi", data => $vcenter_session_count_h);

	foreach my $sessionListNode (keys %{$sessionListH}) {
		my $sessionListNodeClean = lc $sessionListNode;
		$sessionListNodeClean =~ s/[ .]/_/g;
		$sessionListNodeClean = NFD($sessionListNodeClean);
		$sessionListNodeClean =~ s/[^[:ascii:]]//g;
		$sessionListNodeClean =~ s/[^A-Za-z0-9-_]/_/g;
		$graphite->send(
		path => "vi." . "$vcenter_name.vi" . ".exec.sessionList." . "$sessionListNodeClean",
		value => $sessionListH->{$sessionListNode},
		time => time(),
		);
	}
}


$logger->info("[INFO] Processing vCenter $vcenterserver events");
eval {
	my $eventMgr = (Vim::get_view(mo_ref => Vim::get_service_content()->eventManager));

	my $eventCount;
	my $eventLast = $eventMgr->latestEvent;
	$eventCount = $eventLast->key;

	if ($eventCount > 0) {
		my $eventCount_h = {
			time() => {
				"$vcenter_name.vi" . ".exec.events", $eventCount,
			},
		};
		$graphite->send(path => "vi", data => $eventCount_h);

		## https://github.com/lamw/vghetto-scripts/blob/master/perl/provisionedVMReport.pl
		my $eventsInfo = $eventMgr->description->eventInfo;
		my @filteredEvents;
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

		foreach my $i (0..5) {
			$t_5 -= ONE_MINUTE;
		}

		my $evtTimeSpec = EventFilterSpecByTime->new(beginTime => $t_5->datetime, endTime => $t_0->datetime);
		my $filterSpec = EventFilterSpec->new(time => $evtTimeSpec, eventTypeId => [@filteredEvents]);
		my $evtResults = $eventMgr->CreateCollectorForEvents(filter => $filterSpec);

		my $eventCollector;
		my $exEvents;

		$eventCollector = Vim::get_view(mo_ref => $evtResults);
		## $eventCollector->ResetCollector();
		## my $exEvents = $eventCollector->latestPage;
		$exEvents = $eventCollector->ReadNextEvents(maxCount => 1000);
		
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
						my $events_count_per_id_h = {
							time() => {
								"$vcenter_name.vi" . ".exec.ExEvent." . "$dc_vc_event_id.$clu_dc_vc_event_id.$clean_evt_clu_dc_vc_event_id", $vc_events_count_per_id->{$dc_vc_event_id}->{$clu_dc_vc_event_id}->{$evt_clu_dc_vc_event_id},
							},
						};
						$graphite->send(path => "vi", data => $events_count_per_id_h);
					}
				}
			}
		}

		$eventCollector->DestroyCollector;
	}
};
if($@) {
	$logger->info("[ERROR] reset dead session file $sessionfile for vCenter $vcenterserver");
	unlink $sessionfile;
}

# $logger->info("[INFO] Processing vCenter $vcenterserver tasks");
# my $taskCount;
# eval {
	# my $taskMgr = (Vim::get_view(mo_ref => Vim::get_service_content()->taskManager));
	# my $recentTask = $taskMgr->recentTask;
	# if ($recentTask) {
	# 	$taskCount = (split(/-/, @$recentTask[-1]->value))[1];

	# 	if ($taskCount > 0) {
	# 		my $taskCount_h = {
	# 			time() => {
	# 				"$vcenter_name.vi" . ".exec.tasks", $taskCount,
	# 			},
	# 		};
	# 		$graphite->send(path => "vi", data => $taskCount_h);
	# 	}
	# }
# if($@) {
# 	$logger->info("[ERROR] reset dead session file $sessionfile for vCenter $vcenterserver");
# 	unlink $sessionfile;
# }

my $exec_duration = time - $exec_start;
my $vcenter_exec_duration_h = {
	time() => {
		"$vcenter_name.vi" . ".exec.duration", $exec_duration,
	},
};
$graphite->send(path => "vi", data => $vcenter_exec_duration_h);

$logger->info("[INFO] End processing vCenter $vcenterserver");

### disconnect from the server
### Util::disconnect();