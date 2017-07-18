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

no strict 'refs';
no warnings 'redefine';

# -----------------------------------------------------------------------------
# # Description: Monkey patch a class instance method
# # Input: subroutine style:
# #        monkey_patch_instance($instance,
#                                method_name => sub { #new code })
# #        where
# #           $instance     - The class instance
# # Output: None
# # ---------------------------------------------------------------------------
MONKEY_PATCH_INSTANCE:
{
  my $counter = 1; # could use a state var in perl 5.10

  sub monkey_patch_instance
  {
    my($instance, $method, $code) = @_;
    my $package = ref($instance) . '::MonkeyPatch' . $counter++;
    no strict 'refs';
    @{$package . '::ISA'} = (ref($instance));
    *{$package . '::' . $method} = $code;
    bless $_[0], $package;
  }
}

# -----------------------------------------------------------------------------
# Description: Get the VMODL namespace for subsequent calls.
# Input: subroutine style:
#        _query_vmodl_ns_version()
# Output: tuple (namespace, version).
# e.g ('vsan', '6.6') ('vim25', '6.5') etc.
# -----------------------------------------------------------------------------
sub _query_vmodl_ns_version {
   my $url = new URI::URL Vim::get_service_url();
   my $host = $url->host;
   my $namespace = undef;
   my $version = undef;

   my $xmlurl = 'https://' . $host . '/sdk/vsanServiceVersions.xml';
   my $user_agent = LWP::UserAgent->new(agent => "VI Perl");
   my $cookie_jar = HTTP::Cookies->new(ignore_discard => 1);
   $user_agent->cookie_jar($cookie_jar);
   $user_agent->protocols_allowed(['http', 'https']);

   my $http_header = HTTP::Headers->new(Content_Type => 'text/xml');
   my $request = HTTP::Request->new('GET', $xmlurl);

   my $response = $user_agent->request($request);
   if ($response->content =~ /urn:vsan/) {
      $namespace = "vsan";
      my $xml_parser = XML::LibXML->new;
      my $result;
      eval { $result = $xml_parser->parse_string($response->content) };
      if ($@) {
         die "vsanServiceVersions.xml version unavailable at '$xmlurl'\n";
         return (undef, undef);
      }
      my @body = $result->documentElement()->getChildrenByTagName('namespace');
      foreach my $ns (@body) {
         my $name = $ns->getChildrenByTagName("name")->shift;
         if ($name->textContent eq "urn:vsan") {
            $version = $ns->getChildrenByTagName("version")->shift;
            $version = $version->textContent;
         }
      }
   } else {
      my %supported_version = Vim::query_api_supported(Vim::get_service_url());
      $namespace = $Vim::vim_namespace; # vim25 here
      $version = $supported_version{"version"};
   }

   return ($namespace, $version);
}

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
      Util::trace(0, "loading $_\n");
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

   # Duplication code from VICommon.pm
   my $soap_header  = <<'END';
<?xml version="1.0" encoding="UTF-8"?>
   <soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/"
                     xmlns:xsd="http://www.w3.org/2001/XMLSchema"
                     xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
   <soapenv:Body>
END

   my $soap_footer = <<'END';
</soapenv:Body></soapenv:Envelope>
END

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

   my $vim_service = VimService->new($vsan_vim->{service_url});
   my $soap_client = $vim_service->{vim_soap};
   my ($namespace, $version) = _query_vmodl_ns_version;
   monkey_patch_instance($soap_client, request => sub {
         my ($self, $op_name, $body_content, $soap_action) = @_;
         my $user_agent = $self->{user_agent};
         my $url = $self->{url};

         $soap_action = "\"urn:$namespace/$version\"";
         if (!$soap_action) {
            $soap_action = '""';
         }

         confess "Not logged in and/or no XML namespace set" unless $namespace;
         my $request_envelope =
         "$soap_header<$op_name xmlns=\"urn:$namespace\">$body_content</$op_name>$soap_footer";
         # Downgrading the request envelope to work with utf8 character
         utf8::downgrade($request_envelope);
         # HTTP header
         my $http_header = HTTP::Headers->new(
            Content_Type => 'text/xml',
            SOAPAction => $soap_action,
            Content_Length => SoapClient::byte_length($request_envelope));
         my $request = HTTP::Request->new('POST',
            $url,
            $http_header,
            $request_envelope);
         my $response = $user_agent->request($request);

         my $xml_parser = XML::LibXML->new;
         my $result;
         eval { $result = $xml_parser->parse_string($response->content) };
         if ($@) {
            # response is not well formed xml - possibly be a setup issue
            die "SOAP request error - possibly a protocol issue: " . $response->content . "\n";
         }
         my $body = $result->documentElement()->getChildrenByTagName('soapenv:Body')->shift;
         my $return_val = $body->getChildrenByTagName("${op_name}Response")->shift;
         if (! $return_val) {
            # must be fault
            $return_val = $body->getChildrenByTagName('soapenv:Fault')->shift;
            if (! $return_val) {
            # neither a valid response or a fault - fatal error
               die "Unexpected response from server: " . $response->content . "\n";
            }
            # should be trapped by caller
            return (undef, $return_val);
         } else {
            my @returnvals = $return_val->getChildrenByTagName('returnval');
            return (\@returnvals, undef);
      }

   });
   $vsan_vim->{vim_service} = $vim_service;
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
                         vim => $vsan_vim),
      "vsan-cluster-iscsi-target-system" =>
         _create_mo_view(type => "VsanIscsiTargetSystem",
                         value => "vsan-cluster-iscsi-target-system",
                         vim => $vsan_vim),
      "vsan-vcsa-deployer-system" =>
         _create_mo_view(type => "VsanVcsaDeployerSystem",
                         value => "vsan-vcsa-deployer-system",
                         vim => $vsan_vim),
      "vsan-vds-system" =>
         _create_mo_view(type => "VsanVdsSystem",
                         value => "vsan-vds-system",
                         vim => $vsan_vim),
      "vsan-vc-capability-system" =>
         _create_mo_view(type => "VsanCapabilitySystem",
                         value => "vsan-vc-capability-system",
                         vim => $vsan_vim),
      "vsan-mass-collector" =>
         _create_mo_view(type => "VsanMassCollector",
                         value => "vsan-mass-collector",
                         vim => $vsan_vim),
      "vsan-phonehome-system" =>
         _create_mo_view(type => "VsanPhoneHomeSystem",
                         value => "vsan-phonehome-system",
                         vim => $vsan_vim),
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
      "vsan-vcsa-deployer-system" =>
         _create_mo_view(type => "VsanVcsaDeployerSystem",
                         value => "vsan-vcsa-deployer-system",
                         vim => $vsan_vim),
      "vsan-capability-system" =>
         _create_mo_view(type => "VsanCapabilitySystem",
                         value => "vsan-capability-system",
                         vim => $vsan_vim),
      "vsanSystemEx" =>
         _create_mo_view(type => "vsanSystemEx",
                         value => "vsanSystemEx",
                         vim => $vsan_vim),
      "vsan-update-manager" =>
         _create_mo_view(type => "VsanUpdateManager",
                         value => "vsan-update-manager",
                         vim => $vsan_vim),
   );

   return %esx_mos;
}

1;
