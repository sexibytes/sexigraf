#!/usr/bin/perl -w

use strict;
use warnings;
use VMware::VIRuntime;
use VMware::VICredStore;
use JSON;
use Data::Dumper;
use Net::Graphite;
use HTML::Template;
use URI::URL;
use URI::Escape;
#use threads;
#use threads::shared;
use Log::Log4perl qw(:easy);
use Number::Bytes::Human qw(format_bytes);
use POSIX qw(strftime);
use utf8;
use Unicode::Normalize;

$Util::script_version = "0.48";
$ENV{'PERL_LWP_SSL_VERIFY_HOSTNAME'} = 0;


my %all_folder_views_name_table = ();
my %all_folder_views_type_table = ();
my %all_folder_views_parent_table = ();

sub getVmPath {
	my ($child_object) = @_;
	if (defined $child_object->{'parent'}) {
		if ($all_folder_views_name_table{$child_object->{'parent'}->value}) {
			my $VmPathTree = "/";
			my $parent_folder = $child_object->{'parent'}->value;

			while ($all_folder_views_type_table{$all_folder_views_parent_table{$parent_folder}}) {
				if ($all_folder_views_type_table{$parent_folder} eq "Folder") {
					$VmPathTree = "/" . "$all_folder_views_name_table{$parent_folder}" . "$VmPathTree";
				}
				if ($all_folder_views_type_table{$all_folder_views_parent_table{$parent_folder}}) {
					$parent_folder = $all_folder_views_parent_table{$parent_folder};
				}
			}
			return $VmPathTree;
		}
	}
}

sub sexiprocess {
	my $logger = Log::Log4perl->get_logger('sexigraf.getInventory');
	my $u_item;
	my @user_list;
	my $password;
	my $url;
	my $vm_views;

	# set graphite target
	my $graphite = Net::Graphite->new(
          # except for host, these hopefully have reasonable defaults, so are optional
          host                  => '127.0.0.1',
          port                  => 2003,
          trace                 => 0,                # if true, copy what's sent to STDERR
          proto                 => 'udp',            # can be 'udp'
          timeout               => 1,                # timeout of socket connect in seconds
          fire_and_forget       => 1,                # if true, ignore sending errors
          return_connect_error  => 0,                # if true, forward connect error to caller
	);

	my ( $listVM_ref, $s_item ) = @_;
	my $exec_start = time;
	my $normalizedServerName = $s_item;
	@user_list = VMware::VICredStore::get_usernames (server => $s_item);
	if (scalar @user_list == 0) {
		$logger->logdie ("[ERROR] No credential store user detected for $s_item");
	} elsif (scalar @user_list > 1) {
		$logger->logdie ("[ERROR] Multiple credential store user detected for $s_item");
	} else {
		foreach $u_item (@user_list) {
			$password = VMware::VICredStore::get_password (server => $s_item, username => $u_item);
			$url = "https://" . $s_item . "/sdk";
			$normalizedServerName =~ s/[ .]/_/g;
			my $sessionfile = "/tmp/vpx_${normalizedServerName}.dat";
			if (defined($sessionfile) and -e $sessionfile) {
				eval { Vim::load_session(service_url => $url, session_file => $sessionfile); };
				if ($@) {
					Vim::login(service_url => $url, user_name => $u_item, password => $password) or $logger->logdie ("[ERROR] Unable to connect to $url with username $u_item");
				}
			} else {
				Vim::login(service_url => $url, user_name => $u_item, password => $password) or $logger->logdie ("[ERROR] Unable to connect to $url with username $u_item");
			}

			if (defined($sessionfile)) {
				Vim::save_session(session_file => $sessionfile);
			}
			my %h_cluster = ("domain-c000" => "N/A");
			my %h_host = ();
			my %h_hostcluster = ();
			my $clusters_views = Vim::find_entity_views(view_type => 'ClusterComputeResource', properties => ['name', 'host']);
			foreach my $cluster_view (@$clusters_views) {
				my $cluster_name = lc ($cluster_view->name);
				$h_cluster{%$cluster_view{'mo_ref'}->value} = $cluster_name;
			}

			my $cluster_hosts_views = Vim::find_entity_views(view_type => 'HostSystem', properties => ['name', 'parent']);
			foreach my $cluster_host_view (@$cluster_hosts_views) {
				my $host_name = lc ($cluster_host_view->{'name'});
				if ($cluster_host_view->{'parent'}->type eq "ClusterComputeResource") {
					$h_host{%$cluster_host_view{'mo_ref'}->value} = $host_name;
					$h_hostcluster{%$cluster_host_view{'mo_ref'}->value} = $cluster_host_view->{'parent'}->value;
				} else {
					$h_host{%$cluster_host_view{'mo_ref'}->value} = $host_name;
				}
			}

			%all_folder_views_name_table = ();
			%all_folder_views_type_table = ();
			%all_folder_views_parent_table = ();
			my $all_folder_views = Vim::find_entity_views(view_type => 'Folder', properties => ['name', 'parent']);
			foreach my $all_folder_view (@$all_folder_views) {
				if ($all_folder_view->{'parent'}) { # skip folder-group-d1
					$all_folder_views_name_table{$all_folder_view->{'mo_ref'}->value} = $all_folder_view->name;
					$all_folder_views_parent_table{$all_folder_view->{'mo_ref'}->value} = $all_folder_view->{'parent'}->value;
					$all_folder_views_type_table{$all_folder_view->{'mo_ref'}->value} = $all_folder_view->{'mo_ref'}->type;
				}
			}

			$vm_views = Vim::find_entity_views(view_type => 'VirtualMachine', properties => ['name','guest','summary.config.vmPathName','runtime.connectionState','runtime.host','network','summary.config.numCpu','summary.config.memorySizeMB','summary.storage', 'parent'], filter => {'runtime.connectionState' => "connected"});
			foreach my $vm_view (@$vm_views) {
				my $vnics = $vm_view->guest->net;
				my @vm_pg_string = ();
				my @vm_ip_string = ();
				my @vm_mac = ();
				# my $vmPath = Util::get_inventory_path($vm_view, Vim::get_vim());
				# $vmPath = (split(/\/([^\/]+)$/, $vmPath))[0] || "Unknown";
				my $vmPath = getVmPath $vm_view;
				$vmPath =~ s/[ .()]/_/g;
				$vmPath = NFD($vmPath);
				$vmPath =~ s/[^[:ascii:]]//g;
				$vmPath =~ s/[^A-Za-z0-9-_\/]/_/g;
				foreach (@$vnics) {
					($_->macAddress) ? push(@vm_mac, $_->macAddress) : push(@vm_mac, "N/A");
					($_->network) ? push(@vm_pg_string, $_->network) : push(@vm_pg_string, "N/A");
					if ($_->ipConfig) {
						my $ips = $_->ipConfig->ipAddress;
						foreach (@$ips) {
							if ($_->ipAddress and $_->prefixLength <= 32) {
								push(@vm_ip_string, $_->ipAddress);
							}
						}
					} else {
						push(@vm_ip_string, "N/A");
					}
				}
				my $vcentersdk = new URI::URL $vm_view->{'vim'}->{'service_url'};
				my $vcenter_clean_name = lc ($vcentersdk->host);
				$vcenter_clean_name =~ s/[ .]/_/g;
				$vcenter_clean_name = NFD($vcenter_clean_name);
				$vcenter_clean_name =~ s/[^[:ascii:]]//g;
				$vcenter_clean_name =~ s/[^A-Za-z0-9-_]/_/g;
				my $cluster = $h_cluster{($h_hostcluster{$vm_view->{'runtime.host'}->value} ? $h_hostcluster{$vm_view->{'runtime.host'}->value} : "domain-c000")};
				my $cluster_name;
				if ($cluster ne "N/A") {
					$cluster_name = lc ($cluster);
					$cluster_name =~ s/[ .]/_/g;
					$cluster_name = NFD($cluster_name);
					$cluster_name =~ s/[^[:ascii:]]//g;
					$cluster_name =~ s/[^A-Za-z0-9-_]/_/g;
				} else {
					$cluster_name = $cluster;
				}
				my $txtCluster = ($cluster_name eq "N/A") ? $cluster_name : '<a href="/d/2b9f2865/vmware-cluster-fullstats?orgId=1&var-vcenter=All&var-datacentre=All&var-cluster=' . $cluster_name . '&var-datastore=All" target="_blank">' . $cluster_name . '</a>';
				my $datastore_name = lc ((split /\[/, (split /\]/, $vm_view->{'summary.config.vmPathName'})[0])[1]);
				$datastore_name =~ s/[ .()]/_/g;
				$datastore_name = NFD($datastore_name);
				$datastore_name =~ s/[^[:ascii:]]//g;
				$datastore_name =~ s/[^A-Za-z0-9-_]/_/g;
				my $clean_vm_name = lc ($vm_view->name);
				$clean_vm_name =~ s/[ .()]/_/g;
				$clean_vm_name = NFD($clean_vm_name);
				$clean_vm_name =~ s/[^[:ascii:]]//g;
				$clean_vm_name =~ s/[^A-Za-z0-9-_]/_/g;
				my %h_vm : shared = (
					VM => '<a href="/d/beeee82d/vmware-all-cluster-vm-stats?orgId=1&var-vcenter=' . $vcenter_clean_name . '&var-datacentre=All&var-cluster=All&var-vm=' . $clean_vm_name . '" target="_blank">' . $clean_vm_name . '</a>',
					VCENTER => $vcentersdk->host,
					CLUSTER => $txtCluster,
					HOST => $h_host{$vm_view->{'runtime.host'}->value},
					VMXPATH => $vm_view->{'summary.config.vmPathName'},
					PORTGROUP => join(';', @vm_pg_string),
					IP => join(';', @vm_ip_string),
					NUMCPU => ($vm_view->{'summary.config.numCpu'} ? $vm_view->{'summary.config.numCpu'} : "N/A"),
					MEMORY => ($vm_view->{'summary.config.memorySizeMB'} ? $vm_view->{'summary.config.memorySizeMB'} : "N/A"),
					COMMITED => int($vm_view->{'summary.storage'}->committed / 1073741824),
					PROVISIONNED => int(($vm_view->{'summary.storage'}->committed + $vm_view->{'summary.storage'}->uncommitted) / 1073741824),
					DATASTORE => $datastore_name,
					MAC => join(';', @vm_mac),
					FOLDERPATH => $vmPath
				);
				push( @{$listVM_ref}, \%h_vm );
			}
		}
	}
	my $exec_duration = time - $exec_start;
	my $vm_exec_duration_h = { time() => { "$normalizedServerName.vm" . ".exec.duration", $exec_duration } };
	$graphite->send(path => "vi.", data => $vm_exec_duration_h);
	$logger->info("[INFO] Successfully retrieve " . scalar @$vm_views . " VM for vCenter server $s_item in ${exec_duration}s");
}

BEGIN {
	Log::Log4perl::init('/etc/log4perl.conf');
	$SIG{__WARN__} = sub {
		my $logger = get_logger('sexigraf.getInventory');
		local $Log::Log4perl::caller_depth = $Log::Log4perl::caller_depth + 1;
		$logger->warn("WARN @_");
	};
	$SIG{__DIE__} = sub {
		my $logger = get_logger('sexigraf.getInventory');
		local $Log::Log4perl::caller_depth = $Log::Log4perl::caller_depth + 1;
		$logger->fatal("DIE @_");
	};
}

my $logger = Log::Log4perl->get_logger('sexigraf.getInventory');

$0 = "getInventory from VICredStore";
my $PullProcess = 0;
foreach my $file (glob("/proc/[0-9]*/cmdline")) {
	open FILE, "<$file";
	if (grep(/^getInventory from VICredStore/, <FILE>) ) {
		$PullProcess++;
	}
	close FILE;
}
if (scalar $PullProcess  > 1) {$logger->logdie ("[ERROR] getInventory from VICredStore is already running!")}

my $filename = "/var/www/.vmware/credstore/vicredentials.xml";
#my $s_item : shared;
my $s_item;
my @server_list;
#my @listVM : shared = ();
my @listVM = ();
my $fileOutput = '/var/www/admin/offline-vminventory.html';
my $template = HTML::Template->new(filename => '/var/www/admin/template/inventory.tmpl');

VMware::VICredStore::init (filename => $filename) or $logger->logdie ("[ERROR] Unable to initialize Credential Store.");
#my @threads;
@server_list = VMware::VICredStore::get_hosts ();
foreach $s_item (@server_list) {
	#my $threadVC = threads->new(\&sexiprocess, \@listVM, $s_item);
	$logger->info("[INFO] Start processing vCenter $s_item");
	sexiprocess(\@listVM, $s_item);
	#push(@threads, $threadVC);
	$logger->info("[INFO] End processing vCenter $s_item");
}

#foreach (@threads) {
#  $_->join();
#  $logger->info("[INFO] Process " . $_->tid() . " terminated");
#}

$template->param( VM => \@listVM );
$template->param( GENERATED => "Page generated @ " . (strftime "%F %R %Z", localtime) );
open(my $fh, '>', $fileOutput);
$template->output(print_to => $fh);
close($fh);
my ($login,$pass,$uid,$gid) = getpwnam("www-data");
chown $uid, $gid, $fileOutput or $logger->logdie ("[ERROR] Unable to chown inventory file $fileOutput");
