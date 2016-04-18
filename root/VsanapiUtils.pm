#
# Copyright (c) 2016 VMware, Inc.  All rights reserved.
#
# This module defines basic helper functions used in the sample codes.
#

package VsanapiUtils;
use strict;
use warnings;

use Carp;
use Exporter;
use URI::URL;

use VMware::VIRuntime;
use VMware::VIMRuntime;

our @ISA= qw( Exporter );
our @EXPORT = qw(load_vsanmgmt_binding_files
                 get_vsan_vc_mos
                 get_vsan_esx_mos );

# -----------------------------------------------------------------------------
# Description: Load the vsanapi binding files.
# Input: subroutine style:
#        load_vsanmgmt_binding_files($binding_file1_path,
#                                    $binding_file2_path,
#                                    ...)
#        where
#           $binding_file1_path - file path to the 1st binding files.
#           $binding_file2_path - file path to the 2nd binding files.
# Output: None
# -----------------------------------------------------------------------------
sub load_vsanmgmt_binding_files {
   my @stub = ();
   local $/;
   for(@_) {
      # Util::trace(0, "loading $_\n");
      open STUB, $_ or die $!;
      push @stub, split /\n####+?\n/, <STUB>;
      close STUB or die $!;
   }
   for (@stub) {
      my ($package) = /\bpackage\s+(\w+)/;
      $VIMRuntime::stub_class{$package} = $_ if defined $package;
   }
   eval $VIMRuntime::stub_class{'VimService'};
}


# -----------------------------------------------------------------------------
# Description: Get vsan specific vim object for accessing related managed
#              objects.
# Input: subroutine style:
#        _get_vsan_vim($host => $host,
#                      $api_type => $api_type)
#        where
#           $host     - The connected host ip address, can be a VC host or
#                       ESXi host.
#           $api_type - Either "VirtualCenter" for VC or "HostAgent" for
#                       ESXi host.
# Output: The newly created vim
# -----------------------------------------------------------------------------
sub _get_vsan_vim {
   my %args = @_;
   my $session_id = Vim::get_session_id();
   my $host = delete($args{host});
   my $api_type = delete($args{api_type});

   my $service_url_path = "sdk/vimService";
   my $path = "vsanHealth";

   if ($api_type ne "VirtualCenter" and $api_type ne "HostAgent") {
      croak "host_type can only be one of \"VirtualCenter\" or \"HostAgent\"";
   }

   if ($api_type eq "HostAgent") {
      $service_url_path = "sdk";
      $path = "vsan";
   }

   my $vsan_vim = Vim->new(service_url =>
                           "https://$host/$service_url_path",
                           server => $host,
                           protocol => "https",
                           path => $path,
                           port => "443");

   $vsan_vim->{vim_service} = VimService->new($vsan_vim->{service_url});
   $vsan_vim->{vim_service}->load_session_id($session_id);
   $vsan_vim->unset_logout_on_disconnect;

   return $vsan_vim;
}


# -----------------------------------------------------------------------------
# Description: create a certain type of managed object.
# Input: subroutine style:
#        _create_mo_view($type => $type, $value => $value)
#        where
#           $type  -  type of the managed object.
#           $value -  the mo value of the managed object.
#           $vim   -  the vim object representing this connection.
# Output: The newly managed object view that can be used for vsan api call.
# -----------------------------------------------------------------------------
sub _create_mo_view {
   my %args = @_;
   my $type = delete($args{type});
   my $value = delete($args{value});
   my $vim = delete($args{vim});
   my $moref = ManagedObjectReference->new(type => $type,
                                           value => $value);

   my $view_type = $moref->type;
   my $mo_view = $view_type->new($moref, $vim);
   return $mo_view;
}


# -----------------------------------------------------------------------------
# Description: Return a hash that includes all vc mo views of vsanapi.
# Input: subroutine style:
#        get_vsan_vc_mos()
# Output: as description
# -----------------------------------------------------------------------------
sub get_vsan_vc_mos {
   my $url = new URI::URL Vim::get_service_url();
   my $vsan_vim = _get_vsan_vim(host => $url->host,
                                api_type => "VirtualCenter");
   my %vc_mos = (
      "vsan-disk-management-system" =>
         _create_mo_view(type => "VimClusterVsanVcDiskManagementSystem",
                         value => "vsan-disk-management-system",
                         vim => $vsan_vim),
      "vsan-stretched-cluster-system" =>
         _create_mo_view(type => "VimClusterVsanVcStretchedClusterSystem",
                         value => "vsan-stretched-cluster-system",
                         vim => $vsan_vim),
      "vsan-cluster-config-system" =>
         _create_mo_view(type => "VsanVcClusterConfigSystem",
                         value => "vsan-cluster-config-system",
                         vim => $vsan_vim),
      "vsan-performance-manager" =>
         _create_mo_view(type => "VsanPerformanceManager",
                         value => "vsan-performance-manager",
                         vim => $vsan_vim),
      "vsan-cluster-health-system" =>
         _create_mo_view(type => "VsanVcClusterHealthSystem",
                         value => "vsan-cluster-health-system",
                         vim => $vsan_vim),
      "vsan-upgrade-systemex" =>
         _create_mo_view(type =>"VsanUpgradeSystemEx",
                         value => "vsan-upgrade-systemex",
                         vim => $vsan_vim),
      "vsan-cluster-space-report-system" =>
         _create_mo_view(type => "VsanSpaceReportSystem",
                         value => "vsan-cluster-space-report-system",
                         vim => $vsan_vim),
      "vsan-cluster-object-system" =>
         _create_mo_view(type => "VsanObjectSystem",
                         value => "vsan-cluster-object-system",
                         vim => $vsan_vim)

   );

   return %vc_mos;
}


# -----------------------------------------------------------------------------
# Description: Return a hash that includes all esx mo views of vsanapi.
# Input: subroutine style:
#        get_vsan_esx_mos()
# Output: as description
# -----------------------------------------------------------------------------
sub get_vsan_esx_mos {
   my $url = new URI::URL Vim::get_service_url();
   my $vsan_vim = _get_vsan_vim(host => $url->host,
                                api_type => "HostAgent");
   my %esx_mos = (
      "vsan-performance-manager" =>
         _create_mo_view(type => "VsanPerformanceManager",
                         value => "vsan-performance-manager",
                         vim => $vsan_vim),
      "ha-vsan-health-system" =>
         _create_mo_view(type => "HostVsanHealthSystem",
                         value => "ha-vsan-health-system",
                         vim => $vsan_vim),
      "vsan-object-system" =>
         _create_mo_view(type => "VsanObjectSystem",
                         value => "vsan-object-system",
                         vim => $vsan_vim),
   );

   return %esx_mos;
}

1;
