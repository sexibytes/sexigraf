#
# Copyright 2006 VMware, Inc.  All rights reserved.
#

use 5.006001;
use strict;
use warnings;

use VMware::VICommon;
require VMware::VIMRuntime;
use Carp qw(confess croak);

Vim::set_server_version("25Vsanmgmt");
VIMRuntime::initialize();


##################################################################################
package AuthorizationManager;
our @ISA = qw(ViewBase AuthorizationManagerOperations);

VIMRuntime::make_get_set('AuthorizationManager', 'privilegeList', 'roleList', 'description');

our @property_list = (
   ['privilegeList', 'AuthorizationPrivilege', 'true'],
   ['roleList', 'AuthorizationRole', 'true'],
   ['description', 'AuthorizationDescription', undef],
);
sub get_property_list {
   return @property_list;
}

1;
##################################################################################

##################################################################################
package CertificateManager;
our @ISA = qw(ViewBase CertificateManagerOperations);

VIMRuntime::make_get_set('CertificateManager');

our @property_list = (
);
sub get_property_list {
   return @property_list;
}

1;
##################################################################################

##################################################################################
package ClusterComputeResource;
our @ISA = qw(ComputeResource ClusterComputeResourceOperations);

VIMRuntime::make_get_set('ClusterComputeResource', 'configuration', 'recommendation', 'drsRecommendation', 'hciConfig', 'migrationHistory', 'actionHistory', 'drsFault');

our @property_list = (
   ['configuration', 'ClusterConfigInfo', undef],
   ['recommendation', 'ClusterRecommendation', 'true'],
   ['drsRecommendation', 'ClusterDrsRecommendation', 'true'],
   ['hciConfig', 'ClusterComputeResourceHCIConfigInfo', undef],
   ['migrationHistory', 'ClusterDrsMigration', 'true'],
   ['actionHistory', 'ClusterActionHistory', 'true'],
   ['drsFault', 'ClusterDrsFaults', 'true'],
);
sub get_property_list {
   my $class = shift;
   my @super_list = $class->SUPER::get_property_list();
   return (@super_list, @property_list);
}

1;
##################################################################################

##################################################################################
package ComputeResource;
our @ISA = qw(ManagedEntity ComputeResourceOperations);

VIMRuntime::make_get_set('ComputeResource', 'resourcePool', 'host', 'datastore', 'network', 'summary', 'environmentBrowser', 'configurationEx');

our @property_list = (
   ['resourcePool', 'ResourcePool', undef],
   ['host', 'HostSystem', 'true'],
   ['datastore', 'Datastore', 'true'],
   ['network', 'Network', 'true'],
   ['summary', 'ComputeResourceSummary', undef],
   ['environmentBrowser', 'EnvironmentBrowser', undef],
   ['configurationEx', 'ComputeResourceConfigInfo', undef],
);
sub get_property_list {
   my $class = shift;
   my @super_list = $class->SUPER::get_property_list();
   return (@super_list, @property_list);
}

1;
##################################################################################

##################################################################################
package CustomFieldsManager;
our @ISA = qw(ViewBase CustomFieldsManagerOperations);

VIMRuntime::make_get_set('CustomFieldsManager', 'field');

our @property_list = (
   ['field', 'CustomFieldDef', 'true'],
);
sub get_property_list {
   my $class = shift;
   my @super_list = $class->SUPER::get_property_list();
   return (@super_list, @property_list);
}

1;
##################################################################################

##################################################################################
package CustomizationSpecManager;
our @ISA = qw(ViewBase CustomizationSpecManagerOperations);

VIMRuntime::make_get_set('CustomizationSpecManager', 'info', 'encryptionKey');

our @property_list = (
   ['info', 'CustomizationSpecInfo', 'true'],
   ['encryptionKey', undef, 'true'],
);
sub get_property_list {
   my $class = shift;
   my @super_list = $class->SUPER::get_property_list();
   return (@super_list, @property_list);
}

1;
##################################################################################

##################################################################################
package Datacenter;
our @ISA = qw(ManagedEntity DatacenterOperations);

VIMRuntime::make_get_set('Datacenter', 'vmFolder', 'hostFolder', 'datastoreFolder', 'networkFolder', 'datastore', 'network', 'configuration');

our @property_list = (
   ['vmFolder', 'Folder', undef],
   ['hostFolder', 'Folder', undef],
   ['datastoreFolder', 'Folder', undef],
   ['networkFolder', 'Folder', undef],
   ['datastore', 'Datastore', 'true'],
   ['network', 'Network', 'true'],
   ['configuration', 'DatacenterConfigInfo', undef],
);
sub get_property_list {
   my $class = shift;
   my @super_list = $class->SUPER::get_property_list();
   return (@super_list, @property_list);
}

1;
##################################################################################

##################################################################################
package Datastore;
our @ISA = qw(ManagedEntity DatastoreOperations);

VIMRuntime::make_get_set('Datastore', 'info', 'summary', 'host', 'vm', 'browser', 'capability', 'iormConfiguration');

our @property_list = (
   ['info', 'DatastoreInfo', undef],
   ['summary', 'DatastoreSummary', undef],
   ['host', 'DatastoreHostMount', 'true'],
   ['vm', 'VirtualMachine', 'true'],
   ['browser', 'HostDatastoreBrowser', undef],
   ['capability', 'DatastoreCapability', undef],
   ['iormConfiguration', 'StorageIORMInfo', undef],
);
sub get_property_list {
   my $class = shift;
   my @super_list = $class->SUPER::get_property_list();
   return (@super_list, @property_list);
}

1;
##################################################################################

##################################################################################
package DatastoreNamespaceManager;
our @ISA = qw(ViewBase DatastoreNamespaceManagerOperations);

VIMRuntime::make_get_set('DatastoreNamespaceManager');

our @property_list = (
);
sub get_property_list {
   my $class = shift;
   my @super_list = $class->SUPER::get_property_list();
   return (@super_list, @property_list);
}

1;
##################################################################################

##################################################################################
package DiagnosticManager;
our @ISA = qw(ViewBase DiagnosticManagerOperations);

VIMRuntime::make_get_set('DiagnosticManager');

our @property_list = (
);
sub get_property_list {
   my $class = shift;
   my @super_list = $class->SUPER::get_property_list();
   return (@super_list, @property_list);
}

1;
##################################################################################

##################################################################################
package DistributedVirtualSwitch;
our @ISA = qw(ManagedEntity DistributedVirtualSwitchOperations);

VIMRuntime::make_get_set('DistributedVirtualSwitch', 'uuid', 'capability', 'summary', 'config', 'networkResourcePool', 'portgroup', 'runtime');

our @property_list = (
   ['uuid', undef, undef],
   ['capability', 'DVSCapability', undef],
   ['summary', 'DVSSummary', undef],
   ['config', 'DVSConfigInfo', undef],
   ['networkResourcePool', 'DVSNetworkResourcePool', 'true'],
   ['portgroup', 'DistributedVirtualPortgroup', 'true'],
   ['runtime', 'DVSRuntimeInfo', undef],
);
sub get_property_list {
   my $class = shift;
   my @super_list = $class->SUPER::get_property_list();
   return (@super_list, @property_list);
}

1;
##################################################################################

##################################################################################
package EnvironmentBrowser;
our @ISA = qw(ViewBase EnvironmentBrowserOperations);

VIMRuntime::make_get_set('EnvironmentBrowser', 'datastoreBrowser');

our @property_list = (
   ['datastoreBrowser', 'HostDatastoreBrowser', undef],
);
sub get_property_list {
   my $class = shift;
   my @super_list = $class->SUPER::get_property_list();
   return (@super_list, @property_list);
}

1;
##################################################################################

##################################################################################
package ExtensibleManagedObject;
our @ISA = qw(ViewBase ExtensibleManagedObjectOperations);

VIMRuntime::make_get_set('ExtensibleManagedObject', 'value', 'availableField');

our @property_list = (
   ['value', 'CustomFieldValue', 'true'],
   ['availableField', 'CustomFieldDef', 'true'],
);
sub get_property_list {
   my $class = shift;
   my @super_list = $class->SUPER::get_property_list();
   return (@super_list, @property_list);
}

1;
##################################################################################

##################################################################################
package ExtensionManager;
our @ISA = qw(ViewBase ExtensionManagerOperations);

VIMRuntime::make_get_set('ExtensionManager', 'extensionList');

our @property_list = (
   ['extensionList', 'Extension', 'true'],
);
sub get_property_list {
   my $class = shift;
   my @super_list = $class->SUPER::get_property_list();
   return (@super_list, @property_list);
}

1;
##################################################################################

##################################################################################
package FileManager;
our @ISA = qw(ViewBase FileManagerOperations);

VIMRuntime::make_get_set('FileManager');

our @property_list = (
);
sub get_property_list {
   my $class = shift;
   my @super_list = $class->SUPER::get_property_list();
   return (@super_list, @property_list);
}

1;
##################################################################################

##################################################################################
package Folder;
our @ISA = qw(ManagedEntity FolderOperations);

VIMRuntime::make_get_set('Folder', 'childType', 'childEntity');

our @property_list = (
   ['childType', undef, 'true'],
   ['childEntity', 'ManagedEntity', 'true'],
);
sub get_property_list {
   my $class = shift;
   my @super_list = $class->SUPER::get_property_list();
   return (@super_list, @property_list);
}

1;
##################################################################################

##################################################################################
package HealthUpdateManager;
our @ISA = qw(ViewBase HealthUpdateManagerOperations);

VIMRuntime::make_get_set('HealthUpdateManager');

our @property_list = (
);
sub get_property_list {
   my $class = shift;
   my @super_list = $class->SUPER::get_property_list();
   return (@super_list, @property_list);
}

1;
##################################################################################

##################################################################################
package HistoryCollector;
our @ISA = qw(ViewBase HistoryCollectorOperations);

VIMRuntime::make_get_set('HistoryCollector', 'filter');

our @property_list = (
   ['filter', undef, undef],
);
sub get_property_list {
   my $class = shift;
   my @super_list = $class->SUPER::get_property_list();
   return (@super_list, @property_list);
}

1;
##################################################################################

##################################################################################
package HostSystem;
our @ISA = qw(ManagedEntity HostSystemOperations);

VIMRuntime::make_get_set('HostSystem', 'runtime', 'summary', 'hardware', 'capability', 'licensableResource', 'remediationState', 'precheckRemediationResult', 'remediationResult', 'complianceCheckState', 'complianceCheckResult', 'configManager', 'config', 'vm', 'datastore', 'network', 'datastoreBrowser', 'systemResources', 'answerFileValidationState', 'answerFileValidationResult');

our @property_list = (
   ['runtime', 'HostRuntimeInfo', undef],
   ['summary', 'HostListSummary', undef],
   ['hardware', 'HostHardwareInfo', undef],
   ['capability', 'HostCapability', undef],
   ['licensableResource', 'HostLicensableResourceInfo', undef],
   ['remediationState', 'HostSystemRemediationState', undef],
   ['precheckRemediationResult', 'ApplyHostProfileConfigurationSpec', undef],
   ['remediationResult', 'ApplyHostProfileConfigurationResult', undef],
   ['complianceCheckState', 'HostSystemComplianceCheckState', undef],
   ['complianceCheckResult', 'ComplianceResult', undef],
   ['configManager', 'HostConfigManager', undef],
   ['config', 'HostConfigInfo', undef],
   ['vm', 'VirtualMachine', 'true'],
   ['datastore', 'Datastore', 'true'],
   ['network', 'Network', 'true'],
   ['datastoreBrowser', 'HostDatastoreBrowser', undef],
   ['systemResources', 'HostSystemResourceInfo', undef],
   ['answerFileValidationState', 'AnswerFileStatusResult', undef],
   ['answerFileValidationResult', 'AnswerFileStatusResult', undef],
);
sub get_property_list {
   my $class = shift;
   my @super_list = $class->SUPER::get_property_list();
   return (@super_list, @property_list);
}

1;
##################################################################################

##################################################################################
package HttpNfcLease;
our @ISA = qw(ViewBase HttpNfcLeaseOperations);

VIMRuntime::make_get_set('HttpNfcLease', 'initializeProgress', 'transferProgress', 'mode', 'capabilities', 'info', 'state', 'error');

our @property_list = (
   ['initializeProgress', undef, undef],
   ['transferProgress', undef, undef],
   ['mode', undef, undef],
   ['capabilities', 'HttpNfcLeaseCapabilities', undef],
   ['info', 'HttpNfcLeaseInfo', undef],
   ['state', undef, undef],
   ['error', 'LocalizedMethodFault', undef],
);
sub get_property_list {
   my $class = shift;
   my @super_list = $class->SUPER::get_property_list();
   return (@super_list, @property_list);
}

1;
##################################################################################

##################################################################################
package IoFilterManager;
our @ISA = qw(ViewBase IoFilterManagerOperations);

VIMRuntime::make_get_set('IoFilterManager');

our @property_list = (
);
sub get_property_list {
   my $class = shift;
   my @super_list = $class->SUPER::get_property_list();
   return (@super_list, @property_list);
}

1;
##################################################################################

##################################################################################
package IpPoolManager;
our @ISA = qw(ViewBase IpPoolManagerOperations);

VIMRuntime::make_get_set('IpPoolManager');

our @property_list = (
);
sub get_property_list {
   my $class = shift;
   my @super_list = $class->SUPER::get_property_list();
   return (@super_list, @property_list);
}

1;
##################################################################################

##################################################################################
package LicenseAssignmentManager;
our @ISA = qw(ViewBase LicenseAssignmentManagerOperations);

VIMRuntime::make_get_set('LicenseAssignmentManager');

our @property_list = (
);
sub get_property_list {
   my $class = shift;
   my @super_list = $class->SUPER::get_property_list();
   return (@super_list, @property_list);
}

1;
##################################################################################

##################################################################################
package LicenseManager;
our @ISA = qw(ViewBase LicenseManagerOperations);

VIMRuntime::make_get_set('LicenseManager', 'source', 'sourceAvailable', 'diagnostics', 'featureInfo', 'licensedEdition', 'licenses', 'licenseAssignmentManager', 'evaluation');

our @property_list = (
   ['source', 'LicenseSource', undef],
   ['sourceAvailable', undef, undef],
   ['diagnostics', 'LicenseDiagnostics', undef],
   ['featureInfo', 'LicenseFeatureInfo', 'true'],
   ['licensedEdition', undef, undef],
   ['licenses', 'LicenseManagerLicenseInfo', 'true'],
   ['licenseAssignmentManager', 'LicenseAssignmentManager', undef],
   ['evaluation', 'LicenseManagerEvaluationInfo', undef],
);
sub get_property_list {
   my $class = shift;
   my @super_list = $class->SUPER::get_property_list();
   return (@super_list, @property_list);
}

1;
##################################################################################

##################################################################################
package LocalizationManager;
our @ISA = qw(ViewBase LocalizationManagerOperations);

VIMRuntime::make_get_set('LocalizationManager', 'catalog');

our @property_list = (
   ['catalog', 'LocalizationManagerMessageCatalog', 'true'],
);
sub get_property_list {
   my $class = shift;
   my @super_list = $class->SUPER::get_property_list();
   return (@super_list, @property_list);
}

1;
##################################################################################

##################################################################################
package ManagedEntity;
our @ISA = qw(EntityViewBase ExtensibleManagedObject);

VIMRuntime::make_get_set('ManagedEntity', 'parent', 'customValue', 'overallStatus', 'configStatus', 'configIssue', 'effectiveRole', 'permission', 'name', 'disabledMethod', 'recentTask', 'declaredAlarmState', 'triggeredAlarmState', 'alarmActionsEnabled', 'tag');

our @property_list = (
   ['parent', 'ManagedEntity', undef],
   ['customValue', 'CustomFieldValue', 'true'],
   ['overallStatus', undef, undef],
   ['configStatus', undef, undef],
   ['configIssue', 'Event', 'true'],
   ['effectiveRole', undef, 'true'],
   ['permission', 'Permission', 'true'],
   ['name', undef, undef],
   ['disabledMethod', undef, 'true'],
   ['recentTask', 'Task', 'true'],
   ['declaredAlarmState', 'AlarmState', 'true'],
   ['triggeredAlarmState', 'AlarmState', 'true'],
   ['alarmActionsEnabled', undef, undef],
   ['tag', 'Tag', 'true'],
);
sub get_property_list {
   my $class = shift;
   my @super_list = $class->SUPER::get_property_list();
   return (@super_list, @property_list);
}

1;
##################################################################################

##################################################################################
package Network;
our @ISA = qw(ManagedEntity NetworkOperations);

VIMRuntime::make_get_set('Network', 'summary', 'host', 'vm', 'name');

our @property_list = (
   ['summary', 'NetworkSummary', undef],
   ['host', 'HostSystem', 'true'],
   ['vm', 'VirtualMachine', 'true'],
   ['name', undef, undef],
);
sub get_property_list {
   my $class = shift;
   my @super_list = $class->SUPER::get_property_list();
   return (@super_list, @property_list);
}

1;
##################################################################################

##################################################################################
package OpaqueNetwork;
our @ISA = qw(Network OpaqueNetworkOperations);

VIMRuntime::make_get_set('OpaqueNetwork', 'capability', 'extraConfig');

our @property_list = (
   ['capability', 'OpaqueNetworkCapability', undef],
   ['extraConfig', 'OptionValue', 'true'],
);
sub get_property_list {
   my $class = shift;
   my @super_list = $class->SUPER::get_property_list();
   return (@super_list, @property_list);
}

1;
##################################################################################

##################################################################################
package OverheadMemoryManager;
our @ISA = qw(ViewBase OverheadMemoryManagerOperations);

VIMRuntime::make_get_set('OverheadMemoryManager');

our @property_list = (
);
sub get_property_list {
   my $class = shift;
   my @super_list = $class->SUPER::get_property_list();
   return (@super_list, @property_list);
}

1;
##################################################################################

##################################################################################
package OvfManager;
our @ISA = qw(ViewBase OvfManagerOperations);

VIMRuntime::make_get_set('OvfManager', 'ovfImportOption', 'ovfExportOption');

our @property_list = (
   ['ovfImportOption', 'OvfOptionInfo', 'true'],
   ['ovfExportOption', 'OvfOptionInfo', 'true'],
);
sub get_property_list {
   my $class = shift;
   my @super_list = $class->SUPER::get_property_list();
   return (@super_list, @property_list);
}

1;
##################################################################################

##################################################################################
package PerformanceManager;
our @ISA = qw(ViewBase PerformanceManagerOperations);

VIMRuntime::make_get_set('PerformanceManager', 'description', 'historicalInterval', 'perfCounter');

our @property_list = (
   ['description', 'PerformanceDescription', undef],
   ['historicalInterval', 'PerfInterval', 'true'],
   ['perfCounter', 'PerfCounterInfo', 'true'],
);
sub get_property_list {
   my $class = shift;
   my @super_list = $class->SUPER::get_property_list();
   return (@super_list, @property_list);
}

1;
##################################################################################

##################################################################################
package ResourcePlanningManager;
our @ISA = qw(ViewBase ResourcePlanningManagerOperations);

VIMRuntime::make_get_set('ResourcePlanningManager');

our @property_list = (
);
sub get_property_list {
   my $class = shift;
   my @super_list = $class->SUPER::get_property_list();
   return (@super_list, @property_list);
}

1;
##################################################################################

##################################################################################
package ResourcePool;
our @ISA = qw(ManagedEntity ResourcePoolOperations);

VIMRuntime::make_get_set('ResourcePool', 'summary', 'runtime', 'owner', 'resourcePool', 'vm', 'config', 'childConfiguration');

our @property_list = (
   ['summary', 'ResourcePoolSummary', undef],
   ['runtime', 'ResourcePoolRuntimeInfo', undef],
   ['owner', 'ComputeResource', undef],
   ['resourcePool', 'ResourcePool', 'true'],
   ['vm', 'VirtualMachine', 'true'],
   ['config', 'ResourceConfigSpec', undef],
   ['childConfiguration', 'ResourceConfigSpec', 'true'],
);
sub get_property_list {
   my $class = shift;
   my @super_list = $class->SUPER::get_property_list();
   return (@super_list, @property_list);
}

1;
##################################################################################

##################################################################################
package SearchIndex;
our @ISA = qw(ViewBase SearchIndexOperations);

VIMRuntime::make_get_set('SearchIndex');

our @property_list = (
);
sub get_property_list {
   my $class = shift;
   my @super_list = $class->SUPER::get_property_list();
   return (@super_list, @property_list);
}

1;
##################################################################################

##################################################################################
package ServiceInstance;
our @ISA = qw(ViewBase ServiceInstanceOperations);

VIMRuntime::make_get_set('ServiceInstance', 'serverClock', 'capability', 'content');

our @property_list = (
   ['serverClock', undef, undef],
   ['capability', 'Capability', undef],
   ['content', 'ServiceContent', undef],
);
sub get_property_list {
   my $class = shift;
   my @super_list = $class->SUPER::get_property_list();
   return (@super_list, @property_list);
}

1;
##################################################################################

##################################################################################
package ServiceManager;
our @ISA = qw(ViewBase ServiceManagerOperations);

VIMRuntime::make_get_set('ServiceManager', 'service');

our @property_list = (
   ['service', 'ServiceManagerServiceInfo', 'true'],
);
sub get_property_list {
   my $class = shift;
   my @super_list = $class->SUPER::get_property_list();
   return (@super_list, @property_list);
}

1;
##################################################################################

##################################################################################
package SessionManager;
our @ISA = qw(ViewBase SessionManagerOperations);

VIMRuntime::make_get_set('SessionManager', 'sessionList', 'currentSession', 'message', 'messageLocaleList', 'supportedLocaleList', 'defaultLocale');

our @property_list = (
   ['sessionList', 'UserSession', 'true'],
   ['currentSession', 'UserSession', undef],
   ['message', undef, undef],
   ['messageLocaleList', undef, 'true'],
   ['supportedLocaleList', undef, 'true'],
   ['defaultLocale', undef, undef],
);
sub get_property_list {
   my $class = shift;
   my @super_list = $class->SUPER::get_property_list();
   return (@super_list, @property_list);
}

1;
##################################################################################

##################################################################################
package SimpleCommand;
our @ISA = qw(ViewBase SimpleCommandOperations);

VIMRuntime::make_get_set('SimpleCommand', 'encodingType', 'entity');

our @property_list = (
   ['encodingType', undef, undef],
   ['entity', 'ServiceManagerServiceInfo', undef],
);
sub get_property_list {
   my $class = shift;
   my @super_list = $class->SUPER::get_property_list();
   return (@super_list, @property_list);
}

1;
##################################################################################

##################################################################################
package StoragePod;
our @ISA = qw(Folder StoragePodOperations);

VIMRuntime::make_get_set('StoragePod', 'summary', 'podStorageDrsEntry');

our @property_list = (
   ['summary', 'StoragePodSummary', undef],
   ['podStorageDrsEntry', 'PodStorageDrsEntry', undef],
);
sub get_property_list {
   my $class = shift;
   my @super_list = $class->SUPER::get_property_list();
   return (@super_list, @property_list);
}

1;
##################################################################################

##################################################################################
package StorageResourceManager;
our @ISA = qw(ViewBase StorageResourceManagerOperations);

VIMRuntime::make_get_set('StorageResourceManager');

our @property_list = (
);
sub get_property_list {
   my $class = shift;
   my @super_list = $class->SUPER::get_property_list();
   return (@super_list, @property_list);
}

1;
##################################################################################

##################################################################################
package Task;
our @ISA = qw(ExtensibleManagedObject TaskOperations);

VIMRuntime::make_get_set('Task', 'info');

our @property_list = (
   ['info', 'TaskInfo', undef],
);
sub get_property_list {
   my $class = shift;
   my @super_list = $class->SUPER::get_property_list();
   return (@super_list, @property_list);
}

1;
##################################################################################

##################################################################################
package TaskHistoryCollector;
our @ISA = qw(HistoryCollector TaskHistoryCollectorOperations);

VIMRuntime::make_get_set('TaskHistoryCollector', 'latestPage');

our @property_list = (
   ['latestPage', 'TaskInfo', 'true'],
);
sub get_property_list {
   my $class = shift;
   my @super_list = $class->SUPER::get_property_list();
   return (@super_list, @property_list);
}

1;
##################################################################################

##################################################################################
package TaskManager;
our @ISA = qw(ViewBase TaskManagerOperations);

VIMRuntime::make_get_set('TaskManager', 'recentTask', 'description', 'maxCollector');

our @property_list = (
   ['recentTask', 'Task', 'true'],
   ['description', 'TaskDescription', undef],
   ['maxCollector', undef, undef],
);
sub get_property_list {
   my $class = shift;
   my @super_list = $class->SUPER::get_property_list();
   return (@super_list, @property_list);
}

1;
##################################################################################

##################################################################################
package UserDirectory;
our @ISA = qw(ViewBase UserDirectoryOperations);

VIMRuntime::make_get_set('UserDirectory', 'domainList');

our @property_list = (
   ['domainList', undef, 'true'],
);
sub get_property_list {
   my $class = shift;
   my @super_list = $class->SUPER::get_property_list();
   return (@super_list, @property_list);
}

1;
##################################################################################

##################################################################################
package VirtualApp;
our @ISA = qw(ResourcePool VirtualAppOperations);

VIMRuntime::make_get_set('VirtualApp', 'parentFolder', 'datastore', 'network', 'vAppConfig', 'parentVApp', 'childLink');

our @property_list = (
   ['parentFolder', 'Folder', undef],
   ['datastore', 'Datastore', 'true'],
   ['network', 'Network', 'true'],
   ['vAppConfig', 'VAppConfigInfo', undef],
   ['parentVApp', 'ManagedEntity', undef],
   ['childLink', 'VirtualAppLinkInfo', 'true'],
);
sub get_property_list {
   my $class = shift;
   my @super_list = $class->SUPER::get_property_list();
   return (@super_list, @property_list);
}

1;
##################################################################################

##################################################################################
package VirtualDiskManager;
our @ISA = qw(ViewBase VirtualDiskManagerOperations);

VIMRuntime::make_get_set('VirtualDiskManager');

our @property_list = (
);
sub get_property_list {
   my $class = shift;
   my @super_list = $class->SUPER::get_property_list();
   return (@super_list, @property_list);
}

1;
##################################################################################

##################################################################################
package VirtualMachine;
our @ISA = qw(ManagedEntity VirtualMachineOperations);

VIMRuntime::make_get_set('VirtualMachine', 'capability', 'config', 'layout', 'layoutEx', 'storage', 'environmentBrowser', 'resourcePool', 'parentVApp', 'resourceConfig', 'runtime', 'guest', 'summary', 'datastore', 'network', 'snapshot', 'rootSnapshot', 'guestHeartbeatStatus');

our @property_list = (
   ['capability', 'VirtualMachineCapability', undef],
   ['config', 'VirtualMachineConfigInfo', undef],
   ['layout', 'VirtualMachineFileLayout', undef],
   ['layoutEx', 'VirtualMachineFileLayoutEx', undef],
   ['storage', 'VirtualMachineStorageInfo', undef],
   ['environmentBrowser', 'EnvironmentBrowser', undef],
   ['resourcePool', 'ResourcePool', undef],
   ['parentVApp', 'ManagedEntity', undef],
   ['resourceConfig', 'ResourceConfigSpec', undef],
   ['runtime', 'VirtualMachineRuntimeInfo', undef],
   ['guest', 'GuestInfo', undef],
   ['summary', 'VirtualMachineSummary', undef],
   ['datastore', 'Datastore', 'true'],
   ['network', 'Network', 'true'],
   ['snapshot', 'VirtualMachineSnapshotInfo', undef],
   ['rootSnapshot', 'VirtualMachineSnapshot', 'true'],
   ['guestHeartbeatStatus', undef, undef],
);
sub get_property_list {
   my $class = shift;
   my @super_list = $class->SUPER::get_property_list();
   return (@super_list, @property_list);
}

1;
##################################################################################

##################################################################################
package VirtualizationManager;
our @ISA = qw(ViewBase VirtualizationManagerOperations);

VIMRuntime::make_get_set('VirtualizationManager');

our @property_list = (
);
sub get_property_list {
   my $class = shift;
   my @super_list = $class->SUPER::get_property_list();
   return (@super_list, @property_list);
}

1;
##################################################################################

##################################################################################
package VsanMassCollector;
our @ISA = qw(ViewBase VsanMassCollectorOperations);

VIMRuntime::make_get_set('VsanMassCollector');

our @property_list = (
);
sub get_property_list {
   my $class = shift;
   my @super_list = $class->SUPER::get_property_list();
   return (@super_list, @property_list);
}

1;
##################################################################################

##################################################################################
package VsanPhoneHomeSystem;
our @ISA = qw(ViewBase VsanPhoneHomeSystemOperations);

VIMRuntime::make_get_set('VsanPhoneHomeSystem');

our @property_list = (
);
sub get_property_list {
   my $class = shift;
   my @super_list = $class->SUPER::get_property_list();
   return (@super_list, @property_list);
}

1;
##################################################################################

##################################################################################
package VsanUpgradeSystem;
our @ISA = qw(ViewBase VsanUpgradeSystemOperations);

VIMRuntime::make_get_set('VsanUpgradeSystem');

our @property_list = (
);
sub get_property_list {
   my $class = shift;
   my @super_list = $class->SUPER::get_property_list();
   return (@super_list, @property_list);
}

1;
##################################################################################

##################################################################################
package VsanUpgradeSystemEx;
our @ISA = qw(ViewBase VsanUpgradeSystemExOperations);

VIMRuntime::make_get_set('VsanUpgradeSystemEx');

our @property_list = (
);
sub get_property_list {
   my $class = shift;
   my @super_list = $class->SUPER::get_property_list();
   return (@super_list, @property_list);
}

1;
##################################################################################

##################################################################################
package Alarm;
our @ISA = qw(ExtensibleManagedObject AlarmOperations);

VIMRuntime::make_get_set('Alarm', 'info');

our @property_list = (
   ['info', 'AlarmInfo', undef],
);
sub get_property_list {
   my $class = shift;
   my @super_list = $class->SUPER::get_property_list();
   return (@super_list, @property_list);
}

1;
##################################################################################

##################################################################################
package AlarmManager;
our @ISA = qw(ViewBase AlarmManagerOperations);

VIMRuntime::make_get_set('AlarmManager', 'defaultExpression', 'description');

our @property_list = (
   ['defaultExpression', 'AlarmExpression', 'true'],
   ['description', 'AlarmDescription', undef],
);
sub get_property_list {
   my $class = shift;
   my @super_list = $class->SUPER::get_property_list();
   return (@super_list, @property_list);
}

1;
##################################################################################

##################################################################################
package ClusterEVCManager;
our @ISA = qw(ExtensibleManagedObject ClusterEVCManagerOperations);

VIMRuntime::make_get_set('ClusterEVCManager', 'managedCluster', 'evcState');

our @property_list = (
   ['managedCluster', 'ClusterComputeResource', undef],
   ['evcState', 'ClusterEVCManagerEVCState', undef],
);
sub get_property_list {
   my $class = shift;
   my @super_list = $class->SUPER::get_property_list();
   return (@super_list, @property_list);
}

1;
##################################################################################

##################################################################################
package VsanCapabilitySystem;
our @ISA = qw(ViewBase VsanCapabilitySystemOperations);

VIMRuntime::make_get_set('VsanCapabilitySystem');

our @property_list = (
);
sub get_property_list {
   my $class = shift;
   my @super_list = $class->SUPER::get_property_list();
   return (@super_list, @property_list);
}

1;
##################################################################################

##################################################################################
package VsanClusterHealthSystem;
our @ISA = qw(ViewBase VsanClusterHealthSystemOperations);

VIMRuntime::make_get_set('VsanClusterHealthSystem');

our @property_list = (
);
sub get_property_list {
   my $class = shift;
   my @super_list = $class->SUPER::get_property_list();
   return (@super_list, @property_list);
}

1;
##################################################################################

##################################################################################
package VsanClusterMgmtInternalSystem;
our @ISA = qw(ViewBase VsanClusterMgmtInternalSystemOperations);

VIMRuntime::make_get_set('VsanClusterMgmtInternalSystem');

our @property_list = (
);
sub get_property_list {
   my $class = shift;
   my @super_list = $class->SUPER::get_property_list();
   return (@super_list, @property_list);
}

1;
##################################################################################

##################################################################################
package VsanIscsiTargetSystem;
our @ISA = qw(ViewBase VsanIscsiTargetSystemOperations);

VIMRuntime::make_get_set('VsanIscsiTargetSystem');

our @property_list = (
);
sub get_property_list {
   my $class = shift;
   my @super_list = $class->SUPER::get_property_list();
   return (@super_list, @property_list);
}

1;
##################################################################################

##################################################################################
package VsanObjectSystem;
our @ISA = qw(ViewBase VsanObjectSystemOperations);

VIMRuntime::make_get_set('VsanObjectSystem');

our @property_list = (
);
sub get_property_list {
   my $class = shift;
   my @super_list = $class->SUPER::get_property_list();
   return (@super_list, @property_list);
}

1;
##################################################################################

##################################################################################
package VsanPerformanceManager;
our @ISA = qw(ViewBase VsanPerformanceManagerOperations);

VIMRuntime::make_get_set('VsanPerformanceManager');

our @property_list = (
);
sub get_property_list {
   my $class = shift;
   my @super_list = $class->SUPER::get_property_list();
   return (@super_list, @property_list);
}

1;
##################################################################################

##################################################################################
package VsanSpaceReportSystem;
our @ISA = qw(ViewBase VsanSpaceReportSystemOperations);

VIMRuntime::make_get_set('VsanSpaceReportSystem');

our @property_list = (
);
sub get_property_list {
   my $class = shift;
   my @super_list = $class->SUPER::get_property_list();
   return (@super_list, @property_list);
}

1;
##################################################################################

##################################################################################
package VsanVcClusterConfigSystem;
our @ISA = qw(ViewBase VsanVcClusterConfigSystemOperations);

VIMRuntime::make_get_set('VsanVcClusterConfigSystem');

our @property_list = (
);
sub get_property_list {
   my $class = shift;
   my @super_list = $class->SUPER::get_property_list();
   return (@super_list, @property_list);
}

1;
##################################################################################

##################################################################################
package VsanVcClusterHealthSystem;
our @ISA = qw(ViewBase VsanVcClusterHealthSystemOperations);

VIMRuntime::make_get_set('VsanVcClusterHealthSystem');

our @property_list = (
);
sub get_property_list {
   my $class = shift;
   my @super_list = $class->SUPER::get_property_list();
   return (@super_list, @property_list);
}

1;
##################################################################################

##################################################################################
package VimClusterVsanVcDiskManagementSystem;
our @ISA = qw(ViewBase VimClusterVsanVcDiskManagementSystemOperations);

VIMRuntime::make_get_set('VimClusterVsanVcDiskManagementSystem');

our @property_list = (
);
sub get_property_list {
   my $class = shift;
   my @super_list = $class->SUPER::get_property_list();
   return (@super_list, @property_list);
}

1;
##################################################################################

##################################################################################
package VimClusterVsanVcStretchedClusterSystem;
our @ISA = qw(ViewBase VimClusterVsanVcStretchedClusterSystemOperations);

VIMRuntime::make_get_set('VimClusterVsanVcStretchedClusterSystem');

our @property_list = (
);
sub get_property_list {
   my $class = shift;
   my @super_list = $class->SUPER::get_property_list();
   return (@super_list, @property_list);
}

1;
##################################################################################

##################################################################################
package VsanVumSystem;
our @ISA = qw(ViewBase VsanVumSystemOperations);

VIMRuntime::make_get_set('VsanVumSystem');

our @property_list = (
);
sub get_property_list {
   my $class = shift;
   my @super_list = $class->SUPER::get_property_list();
   return (@super_list, @property_list);
}

1;
##################################################################################

##################################################################################
package CnsVolumeManager;
our @ISA = qw(ViewBase CnsVolumeManagerOperations);

VIMRuntime::make_get_set('CnsVolumeManager');

our @property_list = (
);
sub get_property_list {
   my $class = shift;
   my @super_list = $class->SUPER::get_property_list();
   return (@super_list, @property_list);
}

1;
##################################################################################

##################################################################################
package DistributedVirtualPortgroup;
our @ISA = qw(Network DistributedVirtualPortgroupOperations);

VIMRuntime::make_get_set('DistributedVirtualPortgroup', 'key', 'config', 'portKeys');

our @property_list = (
   ['key', undef, undef],
   ['config', 'DVPortgroupConfigInfo', undef],
   ['portKeys', undef, 'true'],
);
sub get_property_list {
   my $class = shift;
   my @super_list = $class->SUPER::get_property_list();
   return (@super_list, @property_list);
}

1;
##################################################################################

##################################################################################
package DistributedVirtualSwitchManager;
our @ISA = qw(ViewBase DistributedVirtualSwitchManagerOperations);

VIMRuntime::make_get_set('DistributedVirtualSwitchManager');

our @property_list = (
);
sub get_property_list {
   my $class = shift;
   my @super_list = $class->SUPER::get_property_list();
   return (@super_list, @property_list);
}

1;
##################################################################################

##################################################################################
package VmwareDistributedVirtualSwitch;
our @ISA = qw(DistributedVirtualSwitch VmwareDistributedVirtualSwitchOperations);

VIMRuntime::make_get_set('VmwareDistributedVirtualSwitch');

our @property_list = (
);
sub get_property_list {
   my $class = shift;
   my @super_list = $class->SUPER::get_property_list();
   return (@super_list, @property_list);
}

1;
##################################################################################

##################################################################################
package CryptoManager;
our @ISA = qw(ViewBase CryptoManagerOperations);

VIMRuntime::make_get_set('CryptoManager', 'enabled');

our @property_list = (
   ['enabled', undef, undef],
);
sub get_property_list {
   my $class = shift;
   my @super_list = $class->SUPER::get_property_list();
   return (@super_list, @property_list);
}

1;
##################################################################################

##################################################################################
package CryptoManagerHost;
our @ISA = qw(CryptoManager CryptoManagerHostOperations);

VIMRuntime::make_get_set('CryptoManagerHost');

our @property_list = (
);
sub get_property_list {
   my $class = shift;
   my @super_list = $class->SUPER::get_property_list();
   return (@super_list, @property_list);
}

1;
##################################################################################

##################################################################################
package CryptoManagerHostKMS;
our @ISA = qw(CryptoManagerHost CryptoManagerHostKMSOperations);

VIMRuntime::make_get_set('CryptoManagerHostKMS');

our @property_list = (
);
sub get_property_list {
   my $class = shift;
   my @super_list = $class->SUPER::get_property_list();
   return (@super_list, @property_list);
}

1;
##################################################################################

##################################################################################
package CryptoManagerKmip;
our @ISA = qw(CryptoManager CryptoManagerKmipOperations);

VIMRuntime::make_get_set('CryptoManagerKmip', 'kmipServers');

our @property_list = (
   ['kmipServers', 'KmipClusterInfo', 'true'],
);
sub get_property_list {
   my $class = shift;
   my @super_list = $class->SUPER::get_property_list();
   return (@super_list, @property_list);
}

1;
##################################################################################

##################################################################################
package EventHistoryCollector;
our @ISA = qw(HistoryCollector EventHistoryCollectorOperations);

VIMRuntime::make_get_set('EventHistoryCollector', 'latestPage');

our @property_list = (
   ['latestPage', 'Event', 'true'],
);
sub get_property_list {
   my $class = shift;
   my @super_list = $class->SUPER::get_property_list();
   return (@super_list, @property_list);
}

1;
##################################################################################

##################################################################################
package EventManager;
our @ISA = qw(ViewBase EventManagerOperations);

VIMRuntime::make_get_set('EventManager', 'description', 'latestEvent', 'maxCollector');

our @property_list = (
   ['description', 'EventDescription', undef],
   ['latestEvent', 'Event', undef],
   ['maxCollector', undef, undef],
);
sub get_property_list {
   my $class = shift;
   my @super_list = $class->SUPER::get_property_list();
   return (@super_list, @property_list);
}

1;
##################################################################################

##################################################################################
package HostActiveDirectoryAuthentication;
our @ISA = qw(HostDirectoryStore HostActiveDirectoryAuthenticationOperations);

VIMRuntime::make_get_set('HostActiveDirectoryAuthentication');

our @property_list = (
);
sub get_property_list {
   my $class = shift;
   my @super_list = $class->SUPER::get_property_list();
   return (@super_list, @property_list);
}

1;
##################################################################################

##################################################################################
package HostAuthenticationManager;
our @ISA = qw(ViewBase HostAuthenticationManagerOperations);

VIMRuntime::make_get_set('HostAuthenticationManager', 'info', 'supportedStore');

our @property_list = (
   ['info', 'HostAuthenticationManagerInfo', undef],
   ['supportedStore', 'HostAuthenticationStore', 'true'],
);
sub get_property_list {
   my $class = shift;
   my @super_list = $class->SUPER::get_property_list();
   return (@super_list, @property_list);
}

1;
##################################################################################

##################################################################################
package HostAuthenticationStore;
our @ISA = qw(ViewBase HostAuthenticationStoreOperations);

VIMRuntime::make_get_set('HostAuthenticationStore', 'info');

our @property_list = (
   ['info', 'HostAuthenticationStoreInfo', undef],
);
sub get_property_list {
   my $class = shift;
   my @super_list = $class->SUPER::get_property_list();
   return (@super_list, @property_list);
}

1;
##################################################################################

##################################################################################
package HostAutoStartManager;
our @ISA = qw(ViewBase HostAutoStartManagerOperations);

VIMRuntime::make_get_set('HostAutoStartManager', 'config');

our @property_list = (
   ['config', 'HostAutoStartManagerConfig', undef],
);
sub get_property_list {
   my $class = shift;
   my @super_list = $class->SUPER::get_property_list();
   return (@super_list, @property_list);
}

1;
##################################################################################

##################################################################################
package HostBootDeviceSystem;
our @ISA = qw(ViewBase HostBootDeviceSystemOperations);

VIMRuntime::make_get_set('HostBootDeviceSystem');

our @property_list = (
);
sub get_property_list {
   my $class = shift;
   my @super_list = $class->SUPER::get_property_list();
   return (@super_list, @property_list);
}

1;
##################################################################################

##################################################################################
package HostCacheConfigurationManager;
our @ISA = qw(ViewBase HostCacheConfigurationManagerOperations);

VIMRuntime::make_get_set('HostCacheConfigurationManager', 'cacheConfigurationInfo');

our @property_list = (
   ['cacheConfigurationInfo', 'HostCacheConfigurationInfo', 'true'],
);
sub get_property_list {
   my $class = shift;
   my @super_list = $class->SUPER::get_property_list();
   return (@super_list, @property_list);
}

1;
##################################################################################

##################################################################################
package HostCertificateManager;
our @ISA = qw(ViewBase HostCertificateManagerOperations);

VIMRuntime::make_get_set('HostCertificateManager', 'certificateInfo');

our @property_list = (
   ['certificateInfo', 'HostCertificateManagerCertificateInfo', undef],
);
sub get_property_list {
   my $class = shift;
   my @super_list = $class->SUPER::get_property_list();
   return (@super_list, @property_list);
}

1;
##################################################################################

##################################################################################
package HostCpuSchedulerSystem;
our @ISA = qw(ExtensibleManagedObject HostCpuSchedulerSystemOperations);

VIMRuntime::make_get_set('HostCpuSchedulerSystem', 'hyperthreadInfo');

our @property_list = (
   ['hyperthreadInfo', 'HostHyperThreadScheduleInfo', undef],
);
sub get_property_list {
   my $class = shift;
   my @super_list = $class->SUPER::get_property_list();
   return (@super_list, @property_list);
}

1;
##################################################################################

##################################################################################
package HostDatastoreBrowser;
our @ISA = qw(ViewBase HostDatastoreBrowserOperations);

VIMRuntime::make_get_set('HostDatastoreBrowser', 'datastore', 'supportedType');

our @property_list = (
   ['datastore', 'Datastore', 'true'],
   ['supportedType', 'FileQuery', 'true'],
);
sub get_property_list {
   my $class = shift;
   my @super_list = $class->SUPER::get_property_list();
   return (@super_list, @property_list);
}

1;
##################################################################################

##################################################################################
package HostDatastoreSystem;
our @ISA = qw(ViewBase HostDatastoreSystemOperations);

VIMRuntime::make_get_set('HostDatastoreSystem', 'datastore', 'capabilities');

our @property_list = (
   ['datastore', 'Datastore', 'true'],
   ['capabilities', 'HostDatastoreSystemCapabilities', undef],
);
sub get_property_list {
   my $class = shift;
   my @super_list = $class->SUPER::get_property_list();
   return (@super_list, @property_list);
}

1;
##################################################################################

##################################################################################
package HostDateTimeSystem;
our @ISA = qw(ViewBase HostDateTimeSystemOperations);

VIMRuntime::make_get_set('HostDateTimeSystem', 'dateTimeInfo');

our @property_list = (
   ['dateTimeInfo', 'HostDateTimeInfo', undef],
);
sub get_property_list {
   my $class = shift;
   my @super_list = $class->SUPER::get_property_list();
   return (@super_list, @property_list);
}

1;
##################################################################################

##################################################################################
package HostDiagnosticSystem;
our @ISA = qw(ViewBase HostDiagnosticSystemOperations);

VIMRuntime::make_get_set('HostDiagnosticSystem', 'activePartition');

our @property_list = (
   ['activePartition', 'HostDiagnosticPartition', undef],
);
sub get_property_list {
   my $class = shift;
   my @super_list = $class->SUPER::get_property_list();
   return (@super_list, @property_list);
}

1;
##################################################################################

##################################################################################
package HostDirectoryStore;
our @ISA = qw(HostAuthenticationStore HostDirectoryStoreOperations);

VIMRuntime::make_get_set('HostDirectoryStore');

our @property_list = (
);
sub get_property_list {
   my $class = shift;
   my @super_list = $class->SUPER::get_property_list();
   return (@super_list, @property_list);
}

1;
##################################################################################

##################################################################################
package HostEsxAgentHostManager;
our @ISA = qw(ViewBase HostEsxAgentHostManagerOperations);

VIMRuntime::make_get_set('HostEsxAgentHostManager', 'configInfo');

our @property_list = (
   ['configInfo', 'HostEsxAgentHostManagerConfigInfo', undef],
);
sub get_property_list {
   my $class = shift;
   my @super_list = $class->SUPER::get_property_list();
   return (@super_list, @property_list);
}

1;
##################################################################################

##################################################################################
package HostFirewallSystem;
our @ISA = qw(ExtensibleManagedObject HostFirewallSystemOperations);

VIMRuntime::make_get_set('HostFirewallSystem', 'firewallInfo');

our @property_list = (
   ['firewallInfo', 'HostFirewallInfo', undef],
);
sub get_property_list {
   my $class = shift;
   my @super_list = $class->SUPER::get_property_list();
   return (@super_list, @property_list);
}

1;
##################################################################################

##################################################################################
package HostFirmwareSystem;
our @ISA = qw(ViewBase HostFirmwareSystemOperations);

VIMRuntime::make_get_set('HostFirmwareSystem');

our @property_list = (
);
sub get_property_list {
   my $class = shift;
   my @super_list = $class->SUPER::get_property_list();
   return (@super_list, @property_list);
}

1;
##################################################################################

##################################################################################
package HostGraphicsManager;
our @ISA = qw(ExtensibleManagedObject HostGraphicsManagerOperations);

VIMRuntime::make_get_set('HostGraphicsManager', 'graphicsInfo', 'graphicsConfig', 'sharedPassthruGpuTypes', 'sharedGpuCapabilities');

our @property_list = (
   ['graphicsInfo', 'HostGraphicsInfo', 'true'],
   ['graphicsConfig', 'HostGraphicsConfig', undef],
   ['sharedPassthruGpuTypes', undef, 'true'],
   ['sharedGpuCapabilities', 'HostSharedGpuCapabilities', 'true'],
);
sub get_property_list {
   my $class = shift;
   my @super_list = $class->SUPER::get_property_list();
   return (@super_list, @property_list);
}

1;
##################################################################################

##################################################################################
package HostHealthStatusSystem;
our @ISA = qw(ViewBase HostHealthStatusSystemOperations);

VIMRuntime::make_get_set('HostHealthStatusSystem', 'runtime');

our @property_list = (
   ['runtime', 'HealthSystemRuntime', undef],
);
sub get_property_list {
   my $class = shift;
   my @super_list = $class->SUPER::get_property_list();
   return (@super_list, @property_list);
}

1;
##################################################################################

##################################################################################
package HostAccessManager;
our @ISA = qw(ViewBase HostAccessManagerOperations);

VIMRuntime::make_get_set('HostAccessManager', 'lockdownMode');

our @property_list = (
   ['lockdownMode', undef, undef],
);
sub get_property_list {
   my $class = shift;
   my @super_list = $class->SUPER::get_property_list();
   return (@super_list, @property_list);
}

1;
##################################################################################

##################################################################################
package HostImageConfigManager;
our @ISA = qw(ViewBase HostImageConfigManagerOperations);

VIMRuntime::make_get_set('HostImageConfigManager');

our @property_list = (
);
sub get_property_list {
   my $class = shift;
   my @super_list = $class->SUPER::get_property_list();
   return (@super_list, @property_list);
}

1;
##################################################################################

##################################################################################
package IscsiManager;
our @ISA = qw(ViewBase IscsiManagerOperations);

VIMRuntime::make_get_set('IscsiManager');

our @property_list = (
);
sub get_property_list {
   my $class = shift;
   my @super_list = $class->SUPER::get_property_list();
   return (@super_list, @property_list);
}

1;
##################################################################################

##################################################################################
package HostKernelModuleSystem;
our @ISA = qw(ViewBase HostKernelModuleSystemOperations);

VIMRuntime::make_get_set('HostKernelModuleSystem');

our @property_list = (
);
sub get_property_list {
   my $class = shift;
   my @super_list = $class->SUPER::get_property_list();
   return (@super_list, @property_list);
}

1;
##################################################################################

##################################################################################
package HostLocalAccountManager;
our @ISA = qw(ViewBase HostLocalAccountManagerOperations);

VIMRuntime::make_get_set('HostLocalAccountManager');

our @property_list = (
);
sub get_property_list {
   my $class = shift;
   my @super_list = $class->SUPER::get_property_list();
   return (@super_list, @property_list);
}

1;
##################################################################################

##################################################################################
package HostLocalAuthentication;
our @ISA = qw(HostAuthenticationStore HostLocalAuthenticationOperations);

VIMRuntime::make_get_set('HostLocalAuthentication');

our @property_list = (
);
sub get_property_list {
   my $class = shift;
   my @super_list = $class->SUPER::get_property_list();
   return (@super_list, @property_list);
}

1;
##################################################################################

##################################################################################
package HostMemorySystem;
our @ISA = qw(ExtensibleManagedObject HostMemorySystemOperations);

VIMRuntime::make_get_set('HostMemorySystem', 'consoleReservationInfo', 'virtualMachineReservationInfo');

our @property_list = (
   ['consoleReservationInfo', 'ServiceConsoleReservationInfo', undef],
   ['virtualMachineReservationInfo', 'VirtualMachineMemoryReservationInfo', undef],
);
sub get_property_list {
   my $class = shift;
   my @super_list = $class->SUPER::get_property_list();
   return (@super_list, @property_list);
}

1;
##################################################################################

##################################################################################
package MessageBusProxy;
our @ISA = qw(ViewBase MessageBusProxyOperations);

VIMRuntime::make_get_set('MessageBusProxy');

our @property_list = (
);
sub get_property_list {
   my $class = shift;
   my @super_list = $class->SUPER::get_property_list();
   return (@super_list, @property_list);
}

1;
##################################################################################

##################################################################################
package HostNetworkSystem;
our @ISA = qw(ExtensibleManagedObject HostNetworkSystemOperations);

VIMRuntime::make_get_set('HostNetworkSystem', 'capabilities', 'networkInfo', 'offloadCapabilities', 'networkConfig', 'dnsConfig', 'ipRouteConfig', 'consoleIpRouteConfig');

our @property_list = (
   ['capabilities', 'HostNetCapabilities', undef],
   ['networkInfo', 'HostNetworkInfo', undef],
   ['offloadCapabilities', 'HostNetOffloadCapabilities', undef],
   ['networkConfig', 'HostNetworkConfig', undef],
   ['dnsConfig', 'HostDnsConfig', undef],
   ['ipRouteConfig', 'HostIpRouteConfig', undef],
   ['consoleIpRouteConfig', 'HostIpRouteConfig', undef],
);
sub get_property_list {
   my $class = shift;
   my @super_list = $class->SUPER::get_property_list();
   return (@super_list, @property_list);
}

1;
##################################################################################

##################################################################################
package HostNvdimmSystem;
our @ISA = qw(ViewBase HostNvdimmSystemOperations);

VIMRuntime::make_get_set('HostNvdimmSystem', 'nvdimmSystemInfo');

our @property_list = (
   ['nvdimmSystemInfo', 'NvdimmSystemInfo', undef],
);
sub get_property_list {
   my $class = shift;
   my @super_list = $class->SUPER::get_property_list();
   return (@super_list, @property_list);
}

1;
##################################################################################

##################################################################################
package HostPatchManager;
our @ISA = qw(ViewBase HostPatchManagerOperations);

VIMRuntime::make_get_set('HostPatchManager');

our @property_list = (
);
sub get_property_list {
   my $class = shift;
   my @super_list = $class->SUPER::get_property_list();
   return (@super_list, @property_list);
}

1;
##################################################################################

##################################################################################
package HostPciPassthruSystem;
our @ISA = qw(ExtensibleManagedObject HostPciPassthruSystemOperations);

VIMRuntime::make_get_set('HostPciPassthruSystem', 'pciPassthruInfo', 'sriovDevicePoolInfo');

our @property_list = (
   ['pciPassthruInfo', 'HostPciPassthruInfo', 'true'],
   ['sriovDevicePoolInfo', 'HostSriovDevicePoolInfo', 'true'],
);
sub get_property_list {
   my $class = shift;
   my @super_list = $class->SUPER::get_property_list();
   return (@super_list, @property_list);
}

1;
##################################################################################

##################################################################################
package HostPowerSystem;
our @ISA = qw(ViewBase HostPowerSystemOperations);

VIMRuntime::make_get_set('HostPowerSystem', 'capability', 'info');

our @property_list = (
   ['capability', 'PowerSystemCapability', undef],
   ['info', 'PowerSystemInfo', undef],
);
sub get_property_list {
   my $class = shift;
   my @super_list = $class->SUPER::get_property_list();
   return (@super_list, @property_list);
}

1;
##################################################################################

##################################################################################
package HostServiceSystem;
our @ISA = qw(ExtensibleManagedObject HostServiceSystemOperations);

VIMRuntime::make_get_set('HostServiceSystem', 'serviceInfo');

our @property_list = (
   ['serviceInfo', 'HostServiceInfo', undef],
);
sub get_property_list {
   my $class = shift;
   my @super_list = $class->SUPER::get_property_list();
   return (@super_list, @property_list);
}

1;
##################################################################################

##################################################################################
package HostSnmpSystem;
our @ISA = qw(ViewBase HostSnmpSystemOperations);

VIMRuntime::make_get_set('HostSnmpSystem', 'configuration', 'limits');

our @property_list = (
   ['configuration', 'HostSnmpConfigSpec', undef],
   ['limits', 'HostSnmpSystemAgentLimits', undef],
);
sub get_property_list {
   my $class = shift;
   my @super_list = $class->SUPER::get_property_list();
   return (@super_list, @property_list);
}

1;
##################################################################################

##################################################################################
package HostStorageSystem;
our @ISA = qw(ExtensibleManagedObject HostStorageSystemOperations);

VIMRuntime::make_get_set('HostStorageSystem', 'storageDeviceInfo', 'fileSystemVolumeInfo', 'systemFile', 'multipathStateInfo');

our @property_list = (
   ['storageDeviceInfo', 'HostStorageDeviceInfo', undef],
   ['fileSystemVolumeInfo', 'HostFileSystemVolumeInfo', undef],
   ['systemFile', undef, 'true'],
   ['multipathStateInfo', 'HostMultipathStateInfo', undef],
);
sub get_property_list {
   my $class = shift;
   my @super_list = $class->SUPER::get_property_list();
   return (@super_list, @property_list);
}

1;
##################################################################################

##################################################################################
package HostVFlashManager;
our @ISA = qw(ViewBase HostVFlashManagerOperations);

VIMRuntime::make_get_set('HostVFlashManager', 'vFlashConfigInfo');

our @property_list = (
   ['vFlashConfigInfo', 'HostVFlashManagerVFlashConfigInfo', undef],
);
sub get_property_list {
   my $class = shift;
   my @super_list = $class->SUPER::get_property_list();
   return (@super_list, @property_list);
}

1;
##################################################################################

##################################################################################
package HostVMotionSystem;
our @ISA = qw(ExtensibleManagedObject HostVMotionSystemOperations);

VIMRuntime::make_get_set('HostVMotionSystem', 'netConfig', 'ipConfig');

our @property_list = (
   ['netConfig', 'HostVMotionNetConfig', undef],
   ['ipConfig', 'HostIpConfig', undef],
);
sub get_property_list {
   my $class = shift;
   my @super_list = $class->SUPER::get_property_list();
   return (@super_list, @property_list);
}

1;
##################################################################################

##################################################################################
package HostVirtualNicManager;
our @ISA = qw(ExtensibleManagedObject HostVirtualNicManagerOperations);

VIMRuntime::make_get_set('HostVirtualNicManager', 'info');

our @property_list = (
   ['info', 'HostVirtualNicManagerInfo', undef],
);
sub get_property_list {
   my $class = shift;
   my @super_list = $class->SUPER::get_property_list();
   return (@super_list, @property_list);
}

1;
##################################################################################

##################################################################################
package HostVsanHealthSystem;
our @ISA = qw(ViewBase HostVsanHealthSystemOperations);

VIMRuntime::make_get_set('HostVsanHealthSystem');

our @property_list = (
);
sub get_property_list {
   my $class = shift;
   my @super_list = $class->SUPER::get_property_list();
   return (@super_list, @property_list);
}

1;
##################################################################################

##################################################################################
package HostVsanInternalSystem;
our @ISA = qw(ViewBase HostVsanInternalSystemOperations);

VIMRuntime::make_get_set('HostVsanInternalSystem');

our @property_list = (
);
sub get_property_list {
   my $class = shift;
   my @super_list = $class->SUPER::get_property_list();
   return (@super_list, @property_list);
}

1;
##################################################################################

##################################################################################
package HostVsanSystem;
our @ISA = qw(ViewBase HostVsanSystemOperations);

VIMRuntime::make_get_set('HostVsanSystem', 'config');

our @property_list = (
   ['config', 'VsanHostConfigInfo', undef],
);
sub get_property_list {
   my $class = shift;
   my @super_list = $class->SUPER::get_property_list();
   return (@super_list, @property_list);
}

1;
##################################################################################

##################################################################################
package VsanSystemEx;
our @ISA = qw(ViewBase VsanSystemExOperations);

VIMRuntime::make_get_set('VsanSystemEx');

our @property_list = (
);
sub get_property_list {
   my $class = shift;
   my @super_list = $class->SUPER::get_property_list();
   return (@super_list, @property_list);
}

1;
##################################################################################

##################################################################################
package VsanUpdateManager;
our @ISA = qw(ViewBase VsanUpdateManagerOperations);

VIMRuntime::make_get_set('VsanUpdateManager');

our @property_list = (
);
sub get_property_list {
   my $class = shift;
   my @super_list = $class->SUPER::get_property_list();
   return (@super_list, @property_list);
}

1;
##################################################################################

##################################################################################
package VsanVcsaDeployerSystem;
our @ISA = qw(ViewBase VsanVcsaDeployerSystemOperations);

VIMRuntime::make_get_set('VsanVcsaDeployerSystem');

our @property_list = (
);
sub get_property_list {
   my $class = shift;
   my @super_list = $class->SUPER::get_property_list();
   return (@super_list, @property_list);
}

1;
##################################################################################

##################################################################################
package OptionManager;
our @ISA = qw(ViewBase OptionManagerOperations);

VIMRuntime::make_get_set('OptionManager', 'supportedOption', 'setting');

our @property_list = (
   ['supportedOption', 'OptionDef', 'true'],
   ['setting', 'OptionValue', 'true'],
);
sub get_property_list {
   my $class = shift;
   my @super_list = $class->SUPER::get_property_list();
   return (@super_list, @property_list);
}

1;
##################################################################################

##################################################################################
package ProfileComplianceManager;
our @ISA = qw(ViewBase ProfileComplianceManagerOperations);

VIMRuntime::make_get_set('ProfileComplianceManager');

our @property_list = (
);
sub get_property_list {
   my $class = shift;
   my @super_list = $class->SUPER::get_property_list();
   return (@super_list, @property_list);
}

1;
##################################################################################

##################################################################################
package Profile;
our @ISA = qw(ViewBase ProfileOperations);

VIMRuntime::make_get_set('Profile', 'config', 'description', 'name', 'createdTime', 'modifiedTime', 'entity', 'complianceStatus');

our @property_list = (
   ['config', 'ProfileConfigInfo', undef],
   ['description', 'ProfileDescription', undef],
   ['name', undef, undef],
   ['createdTime', undef, undef],
   ['modifiedTime', undef, undef],
   ['entity', 'ManagedEntity', 'true'],
   ['complianceStatus', undef, undef],
);
sub get_property_list {
   my $class = shift;
   my @super_list = $class->SUPER::get_property_list();
   return (@super_list, @property_list);
}

1;
##################################################################################

##################################################################################
package ProfileManager;
our @ISA = qw(ViewBase ProfileManagerOperations);

VIMRuntime::make_get_set('ProfileManager', 'profile');

our @property_list = (
   ['profile', 'Profile', 'true'],
);
sub get_property_list {
   my $class = shift;
   my @super_list = $class->SUPER::get_property_list();
   return (@super_list, @property_list);
}

1;
##################################################################################

##################################################################################
package ClusterProfile;
our @ISA = qw(Profile ClusterProfileOperations);

VIMRuntime::make_get_set('ClusterProfile');

our @property_list = (
);
sub get_property_list {
   my $class = shift;
   my @super_list = $class->SUPER::get_property_list();
   return (@super_list, @property_list);
}

1;
##################################################################################

##################################################################################
package ClusterProfileManager;
our @ISA = qw(ProfileManager ClusterProfileManagerOperations);

VIMRuntime::make_get_set('ClusterProfileManager');

our @property_list = (
);
sub get_property_list {
   my $class = shift;
   my @super_list = $class->SUPER::get_property_list();
   return (@super_list, @property_list);
}

1;
##################################################################################

##################################################################################
package HostProfile;
our @ISA = qw(Profile HostProfileOperations);

VIMRuntime::make_get_set('HostProfile', 'validationState', 'validationStateUpdateTime', 'validationFailureInfo', 'referenceHost');

our @property_list = (
   ['validationState', undef, undef],
   ['validationStateUpdateTime', undef, undef],
   ['validationFailureInfo', 'HostProfileValidationFailureInfo', undef],
   ['referenceHost', 'HostSystem', undef],
);
sub get_property_list {
   my $class = shift;
   my @super_list = $class->SUPER::get_property_list();
   return (@super_list, @property_list);
}

1;
##################################################################################

##################################################################################
package HostSpecificationManager;
our @ISA = qw(ViewBase HostSpecificationManagerOperations);

VIMRuntime::make_get_set('HostSpecificationManager');

our @property_list = (
);
sub get_property_list {
   my $class = shift;
   my @super_list = $class->SUPER::get_property_list();
   return (@super_list, @property_list);
}

1;
##################################################################################

##################################################################################
package HostProfileManager;
our @ISA = qw(ProfileManager HostProfileManagerOperations);

VIMRuntime::make_get_set('HostProfileManager');

our @property_list = (
);
sub get_property_list {
   my $class = shift;
   my @super_list = $class->SUPER::get_property_list();
   return (@super_list, @property_list);
}

1;
##################################################################################

##################################################################################
package ScheduledTask;
our @ISA = qw(ExtensibleManagedObject ScheduledTaskOperations);

VIMRuntime::make_get_set('ScheduledTask', 'info');

our @property_list = (
   ['info', 'ScheduledTaskInfo', undef],
);
sub get_property_list {
   my $class = shift;
   my @super_list = $class->SUPER::get_property_list();
   return (@super_list, @property_list);
}

1;
##################################################################################

##################################################################################
package ScheduledTaskManager;
our @ISA = qw(ViewBase ScheduledTaskManagerOperations);

VIMRuntime::make_get_set('ScheduledTaskManager', 'scheduledTask', 'description');

our @property_list = (
   ['scheduledTask', 'ScheduledTask', 'true'],
   ['description', 'ScheduledTaskDescription', undef],
);
sub get_property_list {
   my $class = shift;
   my @super_list = $class->SUPER::get_property_list();
   return (@super_list, @property_list);
}

1;
##################################################################################

##################################################################################
package FailoverClusterConfigurator;
our @ISA = qw(ViewBase FailoverClusterConfiguratorOperations);

VIMRuntime::make_get_set('FailoverClusterConfigurator', 'disabledConfigureMethod');

our @property_list = (
   ['disabledConfigureMethod', undef, 'true'],
);
sub get_property_list {
   my $class = shift;
   my @super_list = $class->SUPER::get_property_list();
   return (@super_list, @property_list);
}

1;
##################################################################################

##################################################################################
package FailoverClusterManager;
our @ISA = qw(ViewBase FailoverClusterManagerOperations);

VIMRuntime::make_get_set('FailoverClusterManager', 'disabledClusterMethod');

our @property_list = (
   ['disabledClusterMethod', undef, 'true'],
);
sub get_property_list {
   my $class = shift;
   my @super_list = $class->SUPER::get_property_list();
   return (@super_list, @property_list);
}

1;
##################################################################################

##################################################################################
package ContainerView;
our @ISA = qw(ManagedObjectView ContainerViewOperations);

VIMRuntime::make_get_set('ContainerView', 'container', 'type', 'recursive');

our @property_list = (
   ['container', 'ManagedEntity', undef],
   ['type', undef, 'true'],
   ['recursive', undef, undef],
);
sub get_property_list {
   my $class = shift;
   my @super_list = $class->SUPER::get_property_list();
   return (@super_list, @property_list);
}

1;
##################################################################################

##################################################################################
package InventoryView;
our @ISA = qw(ManagedObjectView InventoryViewOperations);

VIMRuntime::make_get_set('InventoryView');

our @property_list = (
);
sub get_property_list {
   my $class = shift;
   my @super_list = $class->SUPER::get_property_list();
   return (@super_list, @property_list);
}

1;
##################################################################################

##################################################################################
package ListView;
our @ISA = qw(ManagedObjectView ListViewOperations);

VIMRuntime::make_get_set('ListView');

our @property_list = (
);
sub get_property_list {
   my $class = shift;
   my @super_list = $class->SUPER::get_property_list();
   return (@super_list, @property_list);
}

1;
##################################################################################

##################################################################################
package ManagedObjectView;
our @ISA = qw(View ManagedObjectViewOperations);

VIMRuntime::make_get_set('ManagedObjectView', 'view');

our @property_list = (
   ['view', undef, 'true'],
);
sub get_property_list {
   my $class = shift;
   my @super_list = $class->SUPER::get_property_list();
   return (@super_list, @property_list);
}

1;
##################################################################################

##################################################################################
package View;
our @ISA = qw(ViewBase ViewOperations);

VIMRuntime::make_get_set('View');

our @property_list = (
);
sub get_property_list {
   my $class = shift;
   my @super_list = $class->SUPER::get_property_list();
   return (@super_list, @property_list);
}

1;
##################################################################################

##################################################################################
package ViewManager;
our @ISA = qw(ViewBase ViewManagerOperations);

VIMRuntime::make_get_set('ViewManager', 'viewList');

our @property_list = (
   ['viewList', 'View', 'true'],
);
sub get_property_list {
   my $class = shift;
   my @super_list = $class->SUPER::get_property_list();
   return (@super_list, @property_list);
}

1;
##################################################################################

##################################################################################
package VirtualMachineSnapshot;
our @ISA = qw(ExtensibleManagedObject VirtualMachineSnapshotOperations);

VIMRuntime::make_get_set('VirtualMachineSnapshot', 'config', 'childSnapshot', 'vm');

our @property_list = (
   ['config', 'VirtualMachineConfigInfo', undef],
   ['childSnapshot', 'VirtualMachineSnapshot', 'true'],
   ['vm', 'VirtualMachine', undef],
);
sub get_property_list {
   my $class = shift;
   my @super_list = $class->SUPER::get_property_list();
   return (@super_list, @property_list);
}

1;
##################################################################################

##################################################################################
package VirtualMachineCompatibilityChecker;
our @ISA = qw(ViewBase VirtualMachineCompatibilityCheckerOperations);

VIMRuntime::make_get_set('VirtualMachineCompatibilityChecker');

our @property_list = (
);
sub get_property_list {
   my $class = shift;
   my @super_list = $class->SUPER::get_property_list();
   return (@super_list, @property_list);
}

1;
##################################################################################

##################################################################################
package VirtualMachineProvisioningChecker;
our @ISA = qw(ViewBase VirtualMachineProvisioningCheckerOperations);

VIMRuntime::make_get_set('VirtualMachineProvisioningChecker');

our @property_list = (
);
sub get_property_list {
   my $class = shift;
   my @super_list = $class->SUPER::get_property_list();
   return (@super_list, @property_list);
}

1;
##################################################################################

##################################################################################
package GuestAliasManager;
our @ISA = qw(ViewBase GuestAliasManagerOperations);

VIMRuntime::make_get_set('GuestAliasManager');

our @property_list = (
);
sub get_property_list {
   my $class = shift;
   my @super_list = $class->SUPER::get_property_list();
   return (@super_list, @property_list);
}

1;
##################################################################################

##################################################################################
package GuestAuthManager;
our @ISA = qw(ViewBase GuestAuthManagerOperations);

VIMRuntime::make_get_set('GuestAuthManager');

our @property_list = (
);
sub get_property_list {
   my $class = shift;
   my @super_list = $class->SUPER::get_property_list();
   return (@super_list, @property_list);
}

1;
##################################################################################

##################################################################################
package GuestFileManager;
our @ISA = qw(ViewBase GuestFileManagerOperations);

VIMRuntime::make_get_set('GuestFileManager');

our @property_list = (
);
sub get_property_list {
   my $class = shift;
   my @super_list = $class->SUPER::get_property_list();
   return (@super_list, @property_list);
}

1;
##################################################################################

##################################################################################
package GuestOperationsManager;
our @ISA = qw(ViewBase GuestOperationsManagerOperations);

VIMRuntime::make_get_set('GuestOperationsManager', 'authManager', 'fileManager', 'processManager', 'guestWindowsRegistryManager', 'aliasManager');

our @property_list = (
   ['authManager', 'GuestAuthManager', undef],
   ['fileManager', 'GuestFileManager', undef],
   ['processManager', 'GuestProcessManager', undef],
   ['guestWindowsRegistryManager', 'GuestWindowsRegistryManager', undef],
   ['aliasManager', 'GuestAliasManager', undef],
);
sub get_property_list {
   my $class = shift;
   my @super_list = $class->SUPER::get_property_list();
   return (@super_list, @property_list);
}

1;
##################################################################################

##################################################################################
package GuestProcessManager;
our @ISA = qw(ViewBase GuestProcessManagerOperations);

VIMRuntime::make_get_set('GuestProcessManager');

our @property_list = (
);
sub get_property_list {
   my $class = shift;
   my @super_list = $class->SUPER::get_property_list();
   return (@super_list, @property_list);
}

1;
##################################################################################

##################################################################################
package GuestWindowsRegistryManager;
our @ISA = qw(ViewBase GuestWindowsRegistryManagerOperations);

VIMRuntime::make_get_set('GuestWindowsRegistryManager');

our @property_list = (
);
sub get_property_list {
   my $class = shift;
   my @super_list = $class->SUPER::get_property_list();
   return (@super_list, @property_list);
}

1;
##################################################################################

##################################################################################
package VsanFileServiceSystem;
our @ISA = qw(ViewBase VsanFileServiceSystemOperations);

VIMRuntime::make_get_set('VsanFileServiceSystem');

our @property_list = (
);
sub get_property_list {
   my $class = shift;
   my @super_list = $class->SUPER::get_property_list();
   return (@super_list, @property_list);
}

1;
##################################################################################

##################################################################################
package VsanHostVdsSystem;
our @ISA = qw(ViewBase VsanHostVdsSystemOperations);

VIMRuntime::make_get_set('VsanHostVdsSystem');

our @property_list = (
);
sub get_property_list {
   my $class = shift;
   my @super_list = $class->SUPER::get_property_list();
   return (@super_list, @property_list);
}

1;
##################################################################################

##################################################################################
package VsanResourceCheckSystem;
our @ISA = qw(ViewBase VsanResourceCheckSystemOperations);

VIMRuntime::make_get_set('VsanResourceCheckSystem');

our @property_list = (
);
sub get_property_list {
   my $class = shift;
   my @super_list = $class->SUPER::get_property_list();
   return (@super_list, @property_list);
}

1;
##################################################################################

##################################################################################
package VsanVdsSystem;
our @ISA = qw(ViewBase VsanVdsSystemOperations);

VIMRuntime::make_get_set('VsanVdsSystem');

our @property_list = (
);
sub get_property_list {
   my $class = shift;
   my @super_list = $class->SUPER::get_property_list();
   return (@super_list, @property_list);
}

1;
##################################################################################

##################################################################################
package VStorageObjectManagerBase;
our @ISA = qw(ViewBase VStorageObjectManagerBaseOperations);

VIMRuntime::make_get_set('VStorageObjectManagerBase');

our @property_list = (
);
sub get_property_list {
   my $class = shift;
   my @super_list = $class->SUPER::get_property_list();
   return (@super_list, @property_list);
}

1;
##################################################################################

##################################################################################
package HostVStorageObjectManager;
our @ISA = qw(VStorageObjectManagerBase HostVStorageObjectManagerOperations);

VIMRuntime::make_get_set('HostVStorageObjectManager');

our @property_list = (
);
sub get_property_list {
   my $class = shift;
   my @super_list = $class->SUPER::get_property_list();
   return (@super_list, @property_list);
}

1;
##################################################################################

##################################################################################
package VcenterVStorageObjectManager;
our @ISA = qw(VStorageObjectManagerBase VcenterVStorageObjectManagerOperations);

VIMRuntime::make_get_set('VcenterVStorageObjectManager');

our @property_list = (
);
sub get_property_list {
   my $class = shift;
   my @super_list = $class->SUPER::get_property_list();
   return (@super_list, @property_list);
}

1;
##################################################################################

##################################################################################
package PropertyCollector;
our @ISA = qw(ViewBase PropertyCollectorOperations);

VIMRuntime::make_get_set('PropertyCollector', 'filter');

our @property_list = (
   ['filter', 'PropertyFilter', 'true'],
);
sub get_property_list {
   my $class = shift;
   my @super_list = $class->SUPER::get_property_list();
   return (@super_list, @property_list);
}

1;
##################################################################################

##################################################################################
package PropertyFilter;
our @ISA = qw(ViewBase PropertyFilterOperations);

VIMRuntime::make_get_set('PropertyFilter', 'spec', 'partialUpdates');

our @property_list = (
   ['spec', 'PropertyFilterSpec', undef],
   ['partialUpdates', undef, undef],
);
sub get_property_list {
   my $class = shift;
   my @super_list = $class->SUPER::get_property_list();
   return (@super_list, @property_list);
}

1;
##################################################################################

##################################################################################
package AuthorizationManagerOperations;
sub AddAuthorizationRole {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('AddAuthorizationRole', %args));
   return $response
}

sub RemoveAuthorizationRole {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('RemoveAuthorizationRole', %args));
   return $response
}

sub UpdateAuthorizationRole {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('UpdateAuthorizationRole', %args));
   return $response
}

sub MergePermissions {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('MergePermissions', %args));
   return $response
}

sub RetrieveRolePermissions {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('RetrieveRolePermissions', %args));
   return $response
}

sub RetrieveEntityPermissions {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('RetrieveEntityPermissions', %args));
   return $response
}

sub RetrieveAllPermissions {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('RetrieveAllPermissions', %args));
   return $response
}

sub SetEntityPermissions {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('SetEntityPermissions', %args));
   return $response
}

sub ResetEntityPermissions {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('ResetEntityPermissions', %args));
   return $response
}

sub RemoveEntityPermission {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('RemoveEntityPermission', %args));
   return $response
}

sub HasPrivilegeOnEntity {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('HasPrivilegeOnEntity', %args));
   return $response
}

sub HasPrivilegeOnEntities {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('HasPrivilegeOnEntities', %args));
   return $response
}

sub HasUserPrivilegeOnEntities {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('HasUserPrivilegeOnEntities', %args));
   return $response
}

sub FetchUserPrivilegeOnEntities {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('FetchUserPrivilegeOnEntities', %args));
   return $response
}


1;
##################################################################################

##################################################################################
package CertificateManagerOperations;
sub CertMgrRefreshCACertificatesAndCRLs_Task {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('CertMgrRefreshCACertificatesAndCRLs_Task', %args));
   return $response
}

sub CertMgrRefreshCACertificatesAndCRLs {
   my ($self, %args) = @_;
   return $self->waitForTask($self->CertMgrRefreshCACertificatesAndCRLs_Task(%args));
}

sub CertMgrRefreshCertificates_Task {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('CertMgrRefreshCertificates_Task', %args));
   return $response
}

sub CertMgrRefreshCertificates {
   my ($self, %args) = @_;
   return $self->waitForTask($self->CertMgrRefreshCertificates_Task(%args));
}

sub CertMgrRevokeCertificates_Task {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('CertMgrRevokeCertificates_Task', %args));
   return $response
}

sub CertMgrRevokeCertificates {
   my ($self, %args) = @_;
   return $self->waitForTask($self->CertMgrRevokeCertificates_Task(%args));
}


1;
##################################################################################

##################################################################################
package ClusterComputeResourceOperations;
our @ISA = qw(ComputeResourceOperations);
sub ConfigureHCI_Task {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('ConfigureHCI_Task', %args));
   return $response
}

sub ConfigureHCI {
   my ($self, %args) = @_;
   return $self->waitForTask($self->ConfigureHCI_Task(%args));
}

sub ExtendHCI_Task {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('ExtendHCI_Task', %args));
   return $response
}

sub ExtendHCI {
   my ($self, %args) = @_;
   return $self->waitForTask($self->ExtendHCI_Task(%args));
}

sub AbandonHciWorkflow {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('AbandonHciWorkflow', %args));
   return $response
}

sub ValidateHCIConfiguration {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('ValidateHCIConfiguration', %args));
   return $response
}

sub ReconfigureCluster_Task {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('ReconfigureCluster_Task', %args));
   return $response
}

sub ReconfigureCluster {
   my ($self, %args) = @_;
   return $self->waitForTask($self->ReconfigureCluster_Task(%args));
}

sub ApplyRecommendation {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('ApplyRecommendation', %args));
   return $response
}

sub CancelRecommendation {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('CancelRecommendation', %args));
   return $response
}

sub RecommendHostsForVm {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('RecommendHostsForVm', %args));
   return $response
}

sub AddHost_Task {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('AddHost_Task', %args));
   return $response
}

sub AddHost {
   my ($self, %args) = @_;
   return $self->waitForTask($self->AddHost_Task(%args));
}

sub MoveInto_Task {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('MoveInto_Task', %args));
   return $response
}

sub MoveInto {
   my ($self, %args) = @_;
   return $self->waitForTask($self->MoveInto_Task(%args));
}

sub MoveHostInto_Task {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('MoveHostInto_Task', %args));
   return $response
}

sub MoveHostInto {
   my ($self, %args) = @_;
   return $self->waitForTask($self->MoveHostInto_Task(%args));
}

sub RefreshRecommendation {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('RefreshRecommendation', %args));
   return $response
}

sub EvcManager {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('EvcManager', %args));
   return $response
}

sub RetrieveDasAdvancedRuntimeInfo {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('RetrieveDasAdvancedRuntimeInfo', %args));
   return $response
}

sub ClusterEnterMaintenanceMode {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('ClusterEnterMaintenanceMode', %args));
   return $response
}

sub PlaceVm {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('PlaceVm', %args));
   return $response
}

sub FindRulesForVm {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('FindRulesForVm', %args));
   return $response
}

sub StampAllRulesWithUuid_Task {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('StampAllRulesWithUuid_Task', %args));
   return $response
}

sub StampAllRulesWithUuid {
   my ($self, %args) = @_;
   return $self->waitForTask($self->StampAllRulesWithUuid_Task(%args));
}

sub GetResourceUsage {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('GetResourceUsage', %args));
   return $response
}


1;
##################################################################################

##################################################################################
package ComputeResourceOperations;
our @ISA = qw(ManagedEntityOperations);
sub ReconfigureComputeResource_Task {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('ReconfigureComputeResource_Task', %args));
   return $response
}

sub ReconfigureComputeResource {
   my ($self, %args) = @_;
   return $self->waitForTask($self->ReconfigureComputeResource_Task(%args));
}


1;
##################################################################################

##################################################################################
package CustomFieldsManagerOperations;
sub AddCustomFieldDef {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('AddCustomFieldDef', %args));
   return $response
}

sub RemoveCustomFieldDef {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('RemoveCustomFieldDef', %args));
   return $response
}

sub RenameCustomFieldDef {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('RenameCustomFieldDef', %args));
   return $response
}

sub SetField {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('SetField', %args));
   return $response
}


1;
##################################################################################

##################################################################################
package CustomizationSpecManagerOperations;
sub DoesCustomizationSpecExist {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('DoesCustomizationSpecExist', %args));
   return $response
}

sub GetCustomizationSpec {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('GetCustomizationSpec', %args));
   return $response
}

sub CreateCustomizationSpec {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('CreateCustomizationSpec', %args));
   return $response
}

sub OverwriteCustomizationSpec {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('OverwriteCustomizationSpec', %args));
   return $response
}

sub DeleteCustomizationSpec {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('DeleteCustomizationSpec', %args));
   return $response
}

sub DuplicateCustomizationSpec {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('DuplicateCustomizationSpec', %args));
   return $response
}

sub RenameCustomizationSpec {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('RenameCustomizationSpec', %args));
   return $response
}

sub CustomizationSpecItemToXml {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('CustomizationSpecItemToXml', %args));
   return $response
}

sub XmlToCustomizationSpecItem {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('XmlToCustomizationSpecItem', %args));
   return $response
}

sub CheckCustomizationResources {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('CheckCustomizationResources', %args));
   return $response
}


1;
##################################################################################

##################################################################################
package DatacenterOperations;
our @ISA = qw(ManagedEntityOperations);
sub BatchQueryConnectInfo {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('BatchQueryConnectInfo', %args));
   return $response
}

sub QueryConnectionInfo {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('QueryConnectionInfo', %args));
   return $response
}

sub QueryConnectionInfoViaSpec {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('QueryConnectionInfoViaSpec', %args));
   return $response
}

sub PowerOnMultiVM_Task {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('PowerOnMultiVM_Task', %args));
   return $response
}

sub PowerOnMultiVM {
   my ($self, %args) = @_;
   return $self->waitForTask($self->PowerOnMultiVM_Task(%args));
}

sub queryDatacenterConfigOptionDescriptor {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('queryDatacenterConfigOptionDescriptor', %args));
   return $response
}

sub ReconfigureDatacenter_Task {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('ReconfigureDatacenter_Task', %args));
   return $response
}

sub ReconfigureDatacenter {
   my ($self, %args) = @_;
   return $self->waitForTask($self->ReconfigureDatacenter_Task(%args));
}


1;
##################################################################################

##################################################################################
package DatastoreOperations;
our @ISA = qw(ManagedEntityOperations);
sub RefreshDatastore {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('RefreshDatastore', %args));
   return $response
}

sub RefreshDatastoreStorageInfo {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('RefreshDatastoreStorageInfo', %args));
   return $response
}

sub UpdateVirtualMachineFiles_Task {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('UpdateVirtualMachineFiles_Task', %args));
   return $response
}

sub UpdateVirtualMachineFiles {
   my ($self, %args) = @_;
   return $self->waitForTask($self->UpdateVirtualMachineFiles_Task(%args));
}

sub RenameDatastore {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('RenameDatastore', %args));
   return $response
}

sub DestroyDatastore {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('DestroyDatastore', %args));
   return $response
}

sub DatastoreEnterMaintenanceMode {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('DatastoreEnterMaintenanceMode', %args));
   return $response
}

sub DatastoreExitMaintenanceMode_Task {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('DatastoreExitMaintenanceMode_Task', %args));
   return $response
}

sub DatastoreExitMaintenanceMode {
   my ($self, %args) = @_;
   return $self->waitForTask($self->DatastoreExitMaintenanceMode_Task(%args));
}

sub UpdateVVolVirtualMachineFiles_Task {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('UpdateVVolVirtualMachineFiles_Task', %args));
   return $response
}

sub UpdateVVolVirtualMachineFiles {
   my ($self, %args) = @_;
   return $self->waitForTask($self->UpdateVVolVirtualMachineFiles_Task(%args));
}


1;
##################################################################################

##################################################################################
package DatastoreNamespaceManagerOperations;
sub CreateDirectory {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('CreateDirectory', %args));
   return $response
}

sub DeleteDirectory {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('DeleteDirectory', %args));
   return $response
}

sub ConvertNamespacePathToUuidPath {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('ConvertNamespacePathToUuidPath', %args));
   return $response
}


1;
##################################################################################

##################################################################################
package DiagnosticManagerOperations;
sub QueryDescriptions {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('QueryDescriptions', %args));
   return $response
}

sub BrowseDiagnosticLog {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('BrowseDiagnosticLog', %args));
   return $response
}

sub GenerateLogBundles_Task {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('GenerateLogBundles_Task', %args));
   return $response
}

sub GenerateLogBundles {
   my ($self, %args) = @_;
   return $self->waitForTask($self->GenerateLogBundles_Task(%args));
}


1;
##################################################################################

##################################################################################
package DistributedVirtualSwitchOperations;
our @ISA = qw(ManagedEntityOperations);
sub FetchDVPortKeys {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('FetchDVPortKeys', %args));
   return $response
}

sub FetchDVPorts {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('FetchDVPorts', %args));
   return $response
}

sub QueryUsedVlanIdInDvs {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('QueryUsedVlanIdInDvs', %args));
   return $response
}

sub ReconfigureDvs_Task {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('ReconfigureDvs_Task', %args));
   return $response
}

sub ReconfigureDvs {
   my ($self, %args) = @_;
   return $self->waitForTask($self->ReconfigureDvs_Task(%args));
}

sub PerformDvsProductSpecOperation_Task {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('PerformDvsProductSpecOperation_Task', %args));
   return $response
}

sub PerformDvsProductSpecOperation {
   my ($self, %args) = @_;
   return $self->waitForTask($self->PerformDvsProductSpecOperation_Task(%args));
}

sub MergeDvs_Task {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('MergeDvs_Task', %args));
   return $response
}

sub MergeDvs {
   my ($self, %args) = @_;
   return $self->waitForTask($self->MergeDvs_Task(%args));
}

sub AddDVPortgroup_Task {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('AddDVPortgroup_Task', %args));
   return $response
}

sub AddDVPortgroup {
   my ($self, %args) = @_;
   return $self->waitForTask($self->AddDVPortgroup_Task(%args));
}

sub MoveDVPort_Task {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('MoveDVPort_Task', %args));
   return $response
}

sub MoveDVPort {
   my ($self, %args) = @_;
   return $self->waitForTask($self->MoveDVPort_Task(%args));
}

sub UpdateDvsCapability {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('UpdateDvsCapability', %args));
   return $response
}

sub ReconfigureDVPort_Task {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('ReconfigureDVPort_Task', %args));
   return $response
}

sub ReconfigureDVPort {
   my ($self, %args) = @_;
   return $self->waitForTask($self->ReconfigureDVPort_Task(%args));
}

sub RefreshDVPortState {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('RefreshDVPortState', %args));
   return $response
}

sub RectifyDvsHost_Task {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('RectifyDvsHost_Task', %args));
   return $response
}

sub RectifyDvsHost {
   my ($self, %args) = @_;
   return $self->waitForTask($self->RectifyDvsHost_Task(%args));
}

sub UpdateNetworkResourcePool {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('UpdateNetworkResourcePool', %args));
   return $response
}

sub AddNetworkResourcePool {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('AddNetworkResourcePool', %args));
   return $response
}

sub RemoveNetworkResourcePool {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('RemoveNetworkResourcePool', %args));
   return $response
}

sub DvsReconfigureVmVnicNetworkResourcePool_Task {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('DvsReconfigureVmVnicNetworkResourcePool_Task', %args));
   return $response
}

sub DvsReconfigureVmVnicNetworkResourcePool {
   my ($self, %args) = @_;
   return $self->waitForTask($self->DvsReconfigureVmVnicNetworkResourcePool_Task(%args));
}

sub EnableNetworkResourceManagement {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('EnableNetworkResourceManagement', %args));
   return $response
}

sub DVSRollback_Task {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('DVSRollback_Task', %args));
   return $response
}

sub DVSRollback {
   my ($self, %args) = @_;
   return $self->waitForTask($self->DVSRollback_Task(%args));
}

sub CreateDVPortgroup_Task {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('CreateDVPortgroup_Task', %args));
   return $response
}

sub CreateDVPortgroup {
   my ($self, %args) = @_;
   return $self->waitForTask($self->CreateDVPortgroup_Task(%args));
}

sub UpdateDVSHealthCheckConfig_Task {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('UpdateDVSHealthCheckConfig_Task', %args));
   return $response
}

sub UpdateDVSHealthCheckConfig {
   my ($self, %args) = @_;
   return $self->waitForTask($self->UpdateDVSHealthCheckConfig_Task(%args));
}

sub LookupDvPortGroup {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('LookupDvPortGroup', %args));
   return $response
}


1;
##################################################################################

##################################################################################
package EnvironmentBrowserOperations;
sub QueryConfigOptionDescriptor {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('QueryConfigOptionDescriptor', %args));
   return $response
}

sub QueryConfigOption {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('QueryConfigOption', %args));
   return $response
}

sub QueryConfigOptionEx {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('QueryConfigOptionEx', %args));
   return $response
}

sub QueryConfigTarget {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('QueryConfigTarget', %args));
   return $response
}

sub QueryTargetCapabilities {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('QueryTargetCapabilities', %args));
   return $response
}


1;
##################################################################################

##################################################################################
package ExtensibleManagedObjectOperations;
sub setCustomValue {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('setCustomValue', %args));
   return $response
}


1;
##################################################################################

##################################################################################
package ExtensionManagerOperations;
sub UnregisterExtension {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('UnregisterExtension', %args));
   return $response
}

sub FindExtension {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('FindExtension', %args));
   return $response
}

sub RegisterExtension {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('RegisterExtension', %args));
   return $response
}

sub UpdateExtension {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('UpdateExtension', %args));
   return $response
}

sub GetPublicKey {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('GetPublicKey', %args));
   return $response
}

sub SetPublicKey {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('SetPublicKey', %args));
   return $response
}

sub SetExtensionCertificate {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('SetExtensionCertificate', %args));
   return $response
}

sub QueryManagedBy {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('QueryManagedBy', %args));
   return $response
}

sub QueryExtensionIpAllocationUsage {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('QueryExtensionIpAllocationUsage', %args));
   return $response
}


1;
##################################################################################

##################################################################################
package FileManagerOperations;
sub MoveDatastoreFile_Task {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('MoveDatastoreFile_Task', %args));
   return $response
}

sub MoveDatastoreFile {
   my ($self, %args) = @_;
   return $self->waitForTask($self->MoveDatastoreFile_Task(%args));
}

sub CopyDatastoreFile_Task {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('CopyDatastoreFile_Task', %args));
   return $response
}

sub CopyDatastoreFile {
   my ($self, %args) = @_;
   return $self->waitForTask($self->CopyDatastoreFile_Task(%args));
}

sub DeleteDatastoreFile_Task {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('DeleteDatastoreFile_Task', %args));
   return $response
}

sub DeleteDatastoreFile {
   my ($self, %args) = @_;
   return $self->waitForTask($self->DeleteDatastoreFile_Task(%args));
}

sub MakeDirectory {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('MakeDirectory', %args));
   return $response
}

sub ChangeOwner {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('ChangeOwner', %args));
   return $response
}


1;
##################################################################################

##################################################################################
package FolderOperations;
our @ISA = qw(ManagedEntityOperations);
sub CreateFolder {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('CreateFolder', %args));
   return $response
}

sub MoveIntoFolder_Task {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('MoveIntoFolder_Task', %args));
   return $response
}

sub MoveIntoFolder {
   my ($self, %args) = @_;
   return $self->waitForTask($self->MoveIntoFolder_Task(%args));
}

sub CreateVM_Task {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('CreateVM_Task', %args));
   return $response
}

sub CreateVM {
   my ($self, %args) = @_;
   return $self->waitForTask($self->CreateVM_Task(%args));
}

sub RegisterVM_Task {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('RegisterVM_Task', %args));
   return $response
}

sub RegisterVM {
   my ($self, %args) = @_;
   return $self->waitForTask($self->RegisterVM_Task(%args));
}

sub CreateCluster {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('CreateCluster', %args));
   return $response
}

sub CreateClusterEx {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('CreateClusterEx', %args));
   return $response
}

sub AddStandaloneHost_Task {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('AddStandaloneHost_Task', %args));
   return $response
}

sub AddStandaloneHost {
   my ($self, %args) = @_;
   return $self->waitForTask($self->AddStandaloneHost_Task(%args));
}

sub CreateDatacenter {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('CreateDatacenter', %args));
   return $response
}

sub UnregisterAndDestroy_Task {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('UnregisterAndDestroy_Task', %args));
   return $response
}

sub UnregisterAndDestroy {
   my ($self, %args) = @_;
   return $self->waitForTask($self->UnregisterAndDestroy_Task(%args));
}

sub CreateDVS_Task {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('CreateDVS_Task', %args));
   return $response
}

sub CreateDVS {
   my ($self, %args) = @_;
   return $self->waitForTask($self->CreateDVS_Task(%args));
}

sub CreateStoragePod {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('CreateStoragePod', %args));
   return $response
}

sub BatchAddStandaloneHosts_Task {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('BatchAddStandaloneHosts_Task', %args));
   return $response
}

sub BatchAddStandaloneHosts {
   my ($self, %args) = @_;
   return $self->waitForTask($self->BatchAddStandaloneHosts_Task(%args));
}

sub BatchAddHostsToCluster_Task {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('BatchAddHostsToCluster_Task', %args));
   return $response
}

sub BatchAddHostsToCluster {
   my ($self, %args) = @_;
   return $self->waitForTask($self->BatchAddHostsToCluster_Task(%args));
}


1;
##################################################################################

##################################################################################
package HealthUpdateManagerOperations;
sub RegisterHealthUpdateProvider {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('RegisterHealthUpdateProvider', %args));
   return $response
}

sub UnregisterHealthUpdateProvider {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('UnregisterHealthUpdateProvider', %args));
   return $response
}

sub QueryProviderList {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('QueryProviderList', %args));
   return $response
}

sub HasProvider {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('HasProvider', %args));
   return $response
}

sub QueryProviderName {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('QueryProviderName', %args));
   return $response
}

sub QueryHealthUpdateInfos {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('QueryHealthUpdateInfos', %args));
   return $response
}

sub AddMonitoredEntities {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('AddMonitoredEntities', %args));
   return $response
}

sub RemoveMonitoredEntities {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('RemoveMonitoredEntities', %args));
   return $response
}

sub QueryMonitoredEntities {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('QueryMonitoredEntities', %args));
   return $response
}

sub HasMonitoredEntity {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('HasMonitoredEntity', %args));
   return $response
}

sub QueryUnmonitoredHosts {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('QueryUnmonitoredHosts', %args));
   return $response
}

sub PostHealthUpdates {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('PostHealthUpdates', %args));
   return $response
}

sub QueryHealthUpdates {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('QueryHealthUpdates', %args));
   return $response
}

sub AddFilter {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('AddFilter', %args));
   return $response
}

sub QueryFilterList {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('QueryFilterList', %args));
   return $response
}

sub QueryFilterName {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('QueryFilterName', %args));
   return $response
}

sub QueryFilterInfoIds {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('QueryFilterInfoIds', %args));
   return $response
}

sub QueryFilterEntities {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('QueryFilterEntities', %args));
   return $response
}

sub AddFilterEntities {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('AddFilterEntities', %args));
   return $response
}

sub RemoveFilterEntities {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('RemoveFilterEntities', %args));
   return $response
}

sub RemoveFilter {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('RemoveFilter', %args));
   return $response
}


1;
##################################################################################

##################################################################################
package HistoryCollectorOperations;
sub SetCollectorPageSize {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('SetCollectorPageSize', %args));
   return $response
}

sub RewindCollector {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('RewindCollector', %args));
   return $response
}

sub ResetCollector {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('ResetCollector', %args));
   return $response
}

sub DestroyCollector {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('DestroyCollector', %args));
   return $response
}


1;
##################################################################################

##################################################################################
package HostSystemOperations;
our @ISA = qw(ManagedEntityOperations);
sub QueryTpmAttestationReport {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('QueryTpmAttestationReport', %args));
   return $response
}

sub QueryHostConnectionInfo {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('QueryHostConnectionInfo', %args));
   return $response
}

sub UpdateSystemResources {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('UpdateSystemResources', %args));
   return $response
}

sub UpdateSystemSwapConfiguration {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('UpdateSystemSwapConfiguration', %args));
   return $response
}

sub ReconnectHost_Task {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('ReconnectHost_Task', %args));
   return $response
}

sub ReconnectHost {
   my ($self, %args) = @_;
   return $self->waitForTask($self->ReconnectHost_Task(%args));
}

sub DisconnectHost_Task {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('DisconnectHost_Task', %args));
   return $response
}

sub DisconnectHost {
   my ($self, %args) = @_;
   return $self->waitForTask($self->DisconnectHost_Task(%args));
}

sub EnterMaintenanceMode_Task {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('EnterMaintenanceMode_Task', %args));
   return $response
}

sub EnterMaintenanceMode {
   my ($self, %args) = @_;
   return $self->waitForTask($self->EnterMaintenanceMode_Task(%args));
}

sub ExitMaintenanceMode_Task {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('ExitMaintenanceMode_Task', %args));
   return $response
}

sub ExitMaintenanceMode {
   my ($self, %args) = @_;
   return $self->waitForTask($self->ExitMaintenanceMode_Task(%args));
}

sub RebootHost_Task {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('RebootHost_Task', %args));
   return $response
}

sub RebootHost {
   my ($self, %args) = @_;
   return $self->waitForTask($self->RebootHost_Task(%args));
}

sub ShutdownHost_Task {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('ShutdownHost_Task', %args));
   return $response
}

sub ShutdownHost {
   my ($self, %args) = @_;
   return $self->waitForTask($self->ShutdownHost_Task(%args));
}

sub PowerDownHostToStandBy_Task {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('PowerDownHostToStandBy_Task', %args));
   return $response
}

sub PowerDownHostToStandBy {
   my ($self, %args) = @_;
   return $self->waitForTask($self->PowerDownHostToStandBy_Task(%args));
}

sub PowerUpHostFromStandBy_Task {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('PowerUpHostFromStandBy_Task', %args));
   return $response
}

sub PowerUpHostFromStandBy {
   my ($self, %args) = @_;
   return $self->waitForTask($self->PowerUpHostFromStandBy_Task(%args));
}

sub QueryMemoryOverhead {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('QueryMemoryOverhead', %args));
   return $response
}

sub QueryMemoryOverheadEx {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('QueryMemoryOverheadEx', %args));
   return $response
}

sub ReconfigureHostForDAS_Task {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('ReconfigureHostForDAS_Task', %args));
   return $response
}

sub ReconfigureHostForDAS {
   my ($self, %args) = @_;
   return $self->waitForTask($self->ReconfigureHostForDAS_Task(%args));
}

sub UpdateFlags {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('UpdateFlags', %args));
   return $response
}

sub EnterLockdownMode {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('EnterLockdownMode', %args));
   return $response
}

sub ExitLockdownMode {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('ExitLockdownMode', %args));
   return $response
}

sub AcquireCimServicesTicket {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('AcquireCimServicesTicket', %args));
   return $response
}

sub UpdateIpmi {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('UpdateIpmi', %args));
   return $response
}

sub RetrieveHardwareUptime {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('RetrieveHardwareUptime', %args));
   return $response
}

sub PrepareCrypto {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('PrepareCrypto', %args));
   return $response
}

sub EnableCrypto {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('EnableCrypto', %args));
   return $response
}

sub ConfigureCryptoKey {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('ConfigureCryptoKey', %args));
   return $response
}

sub QueryProductLockerLocation {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('QueryProductLockerLocation', %args));
   return $response
}

sub UpdateProductLockerLocation_Task {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('UpdateProductLockerLocation_Task', %args));
   return $response
}

sub UpdateProductLockerLocation {
   my ($self, %args) = @_;
   return $self->waitForTask($self->UpdateProductLockerLocation_Task(%args));
}


1;
##################################################################################

##################################################################################
package HttpNfcLeaseOperations;
sub HttpNfcLeaseGetManifest {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('HttpNfcLeaseGetManifest', %args));
   return $response
}

sub HttpNfcLeaseSetManifestChecksumType {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('HttpNfcLeaseSetManifestChecksumType', %args));
   return $response
}

sub HttpNfcLeaseComplete {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('HttpNfcLeaseComplete', %args));
   return $response
}

sub HttpNfcLeaseAbort {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('HttpNfcLeaseAbort', %args));
   return $response
}

sub HttpNfcLeaseProgress {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('HttpNfcLeaseProgress', %args));
   return $response
}

sub HttpNfcLeasePullFromUrls_Task {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('HttpNfcLeasePullFromUrls_Task', %args));
   return $response
}

sub HttpNfcLeasePullFromUrls {
   my ($self, %args) = @_;
   return $self->waitForTask($self->HttpNfcLeasePullFromUrls_Task(%args));
}


1;
##################################################################################

##################################################################################
package IoFilterManagerOperations;
sub InstallIoFilter_Task {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('InstallIoFilter_Task', %args));
   return $response
}

sub InstallIoFilter {
   my ($self, %args) = @_;
   return $self->waitForTask($self->InstallIoFilter_Task(%args));
}

sub UninstallIoFilter_Task {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('UninstallIoFilter_Task', %args));
   return $response
}

sub UninstallIoFilter {
   my ($self, %args) = @_;
   return $self->waitForTask($self->UninstallIoFilter_Task(%args));
}

sub UpgradeIoFilter_Task {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('UpgradeIoFilter_Task', %args));
   return $response
}

sub UpgradeIoFilter {
   my ($self, %args) = @_;
   return $self->waitForTask($self->UpgradeIoFilter_Task(%args));
}

sub QueryIoFilterIssues {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('QueryIoFilterIssues', %args));
   return $response
}

sub QueryIoFilterInfo {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('QueryIoFilterInfo', %args));
   return $response
}

sub ResolveInstallationErrorsOnHost_Task {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('ResolveInstallationErrorsOnHost_Task', %args));
   return $response
}

sub ResolveInstallationErrorsOnHost {
   my ($self, %args) = @_;
   return $self->waitForTask($self->ResolveInstallationErrorsOnHost_Task(%args));
}

sub ResolveInstallationErrorsOnCluster_Task {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('ResolveInstallationErrorsOnCluster_Task', %args));
   return $response
}

sub ResolveInstallationErrorsOnCluster {
   my ($self, %args) = @_;
   return $self->waitForTask($self->ResolveInstallationErrorsOnCluster_Task(%args));
}

sub QueryDisksUsingFilter {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('QueryDisksUsingFilter', %args));
   return $response
}


1;
##################################################################################

##################################################################################
package IpPoolManagerOperations;
sub QueryIpPools {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('QueryIpPools', %args));
   return $response
}

sub CreateIpPool {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('CreateIpPool', %args));
   return $response
}

sub UpdateIpPool {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('UpdateIpPool', %args));
   return $response
}

sub DestroyIpPool {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('DestroyIpPool', %args));
   return $response
}

sub AllocateIpv4Address {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('AllocateIpv4Address', %args));
   return $response
}

sub AllocateIpv6Address {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('AllocateIpv6Address', %args));
   return $response
}

sub ReleaseIpAllocation {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('ReleaseIpAllocation', %args));
   return $response
}

sub QueryIPAllocations {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('QueryIPAllocations', %args));
   return $response
}


1;
##################################################################################

##################################################################################
package LicenseAssignmentManagerOperations;
sub UpdateAssignedLicense {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('UpdateAssignedLicense', %args));
   return $response
}

sub RemoveAssignedLicense {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('RemoveAssignedLicense', %args));
   return $response
}

sub QueryAssignedLicenses {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('QueryAssignedLicenses', %args));
   return $response
}


1;
##################################################################################

##################################################################################
package LicenseManagerOperations;
sub QuerySupportedFeatures {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('QuerySupportedFeatures', %args));
   return $response
}

sub QueryLicenseSourceAvailability {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('QueryLicenseSourceAvailability', %args));
   return $response
}

sub QueryLicenseUsage {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('QueryLicenseUsage', %args));
   return $response
}

sub SetLicenseEdition {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('SetLicenseEdition', %args));
   return $response
}

sub CheckLicenseFeature {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('CheckLicenseFeature', %args));
   return $response
}

sub EnableFeature {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('EnableFeature', %args));
   return $response
}

sub DisableFeature {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('DisableFeature', %args));
   return $response
}

sub ConfigureLicenseSource {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('ConfigureLicenseSource', %args));
   return $response
}

sub UpdateLicense {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('UpdateLicense', %args));
   return $response
}

sub AddLicense {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('AddLicense', %args));
   return $response
}

sub RemoveLicense {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('RemoveLicense', %args));
   return $response
}

sub DecodeLicense {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('DecodeLicense', %args));
   return $response
}

sub UpdateLicenseLabel {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('UpdateLicenseLabel', %args));
   return $response
}

sub RemoveLicenseLabel {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('RemoveLicenseLabel', %args));
   return $response
}


1;
##################################################################################

##################################################################################
package LocalizationManagerOperations;

1;
##################################################################################

##################################################################################
package ManagedEntityOperations;
our @ISA = qw(ExtensibleManagedObjectOperations);
sub Reload {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('Reload', %args));
   return $response
}

sub Rename_Task {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('Rename_Task', %args));
   return $response
}

sub Rename {
   my ($self, %args) = @_;
   return $self->waitForTask($self->Rename_Task(%args));
}

sub Destroy_Task {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('Destroy_Task', %args));
   return $response
}

sub Destroy {
   my ($self, %args) = @_;
   return $self->waitForTask($self->Destroy_Task(%args));
}


1;
##################################################################################

##################################################################################
package NetworkOperations;
our @ISA = qw(ManagedEntityOperations);
sub DestroyNetwork {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('DestroyNetwork', %args));
   return $response
}


1;
##################################################################################

##################################################################################
package OpaqueNetworkOperations;
our @ISA = qw(NetworkOperations);

1;
##################################################################################

##################################################################################
package OverheadMemoryManagerOperations;
sub LookupVmOverheadMemory {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('LookupVmOverheadMemory', %args));
   return $response
}


1;
##################################################################################

##################################################################################
package OvfManagerOperations;
sub ValidateHost {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('ValidateHost', %args));
   return $response
}

sub ParseDescriptor {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('ParseDescriptor', %args));
   return $response
}

sub CreateImportSpec {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('CreateImportSpec', %args));
   return $response
}

sub CreateDescriptor {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('CreateDescriptor', %args));
   return $response
}


1;
##################################################################################

##################################################################################
package PerformanceManagerOperations;
sub QueryPerfProviderSummary {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('QueryPerfProviderSummary', %args));
   return $response
}

sub QueryAvailablePerfMetric {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('QueryAvailablePerfMetric', %args));
   return $response
}

sub QueryPerfCounter {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('QueryPerfCounter', %args));
   return $response
}

sub QueryPerfCounterByLevel {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('QueryPerfCounterByLevel', %args));
   return $response
}

sub QueryPerf {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('QueryPerf', %args));
   return $response
}

sub QueryPerfComposite {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('QueryPerfComposite', %args));
   return $response
}

sub CreatePerfInterval {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('CreatePerfInterval', %args));
   return $response
}

sub RemovePerfInterval {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('RemovePerfInterval', %args));
   return $response
}

sub UpdatePerfInterval {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('UpdatePerfInterval', %args));
   return $response
}

sub UpdateCounterLevelMapping {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('UpdateCounterLevelMapping', %args));
   return $response
}

sub ResetCounterLevelMapping {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('ResetCounterLevelMapping', %args));
   return $response
}


1;
##################################################################################

##################################################################################
package ResourcePlanningManagerOperations;
sub EstimateDatabaseSize {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('EstimateDatabaseSize', %args));
   return $response
}


1;
##################################################################################

##################################################################################
package ResourcePoolOperations;
our @ISA = qw(ManagedEntityOperations);
sub UpdateConfig {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('UpdateConfig', %args));
   return $response
}

sub MoveIntoResourcePool {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('MoveIntoResourcePool', %args));
   return $response
}

sub UpdateChildResourceConfiguration {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('UpdateChildResourceConfiguration', %args));
   return $response
}

sub CreateResourcePool {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('CreateResourcePool', %args));
   return $response
}

sub DestroyChildren {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('DestroyChildren', %args));
   return $response
}

sub CreateVApp {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('CreateVApp', %args));
   return $response
}

sub CreateChildVM_Task {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('CreateChildVM_Task', %args));
   return $response
}

sub CreateChildVM {
   my ($self, %args) = @_;
   return $self->waitForTask($self->CreateChildVM_Task(%args));
}

sub RegisterChildVM_Task {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('RegisterChildVM_Task', %args));
   return $response
}

sub RegisterChildVM {
   my ($self, %args) = @_;
   return $self->waitForTask($self->RegisterChildVM_Task(%args));
}

sub ImportVApp {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('ImportVApp', %args));
   return $response
}

sub QueryResourceConfigOption {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('QueryResourceConfigOption', %args));
   return $response
}

sub RefreshRuntime {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('RefreshRuntime', %args));
   return $response
}


1;
##################################################################################

##################################################################################
package SearchIndexOperations;
sub FindByUuid {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('FindByUuid', %args));
   return $response
}

sub FindByDatastorePath {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('FindByDatastorePath', %args));
   return $response
}

sub FindByDnsName {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('FindByDnsName', %args));
   return $response
}

sub FindByIp {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('FindByIp', %args));
   return $response
}

sub FindByInventoryPath {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('FindByInventoryPath', %args));
   return $response
}

sub FindChild {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('FindChild', %args));
   return $response
}

sub FindAllByUuid {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('FindAllByUuid', %args));
   return $response
}

sub FindAllByDnsName {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('FindAllByDnsName', %args));
   return $response
}

sub FindAllByIp {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('FindAllByIp', %args));
   return $response
}


1;
##################################################################################

##################################################################################
package ServiceInstanceOperations;
sub CurrentTime {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('CurrentTime', %args));
   return $response
}

sub RetrieveServiceContent {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('RetrieveServiceContent', %args));
   return $response
}

sub ValidateMigration {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('ValidateMigration', %args));
   return $response
}

sub QueryVMotionCompatibility {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('QueryVMotionCompatibility', %args));
   return $response
}

sub RetrieveProductComponents {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('RetrieveProductComponents', %args));
   return $response
}


1;
##################################################################################

##################################################################################
package ServiceManagerOperations;
sub QueryServiceList {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('QueryServiceList', %args));
   return $response
}


1;
##################################################################################

##################################################################################
package SessionManagerOperations;
sub UpdateServiceMessage {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('UpdateServiceMessage', %args));
   return $response
}

sub LoginByToken {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('LoginByToken', %args));
   return $response
}

sub Login {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('Login', %args));
   return $response
}

sub LoginBySSPI {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('LoginBySSPI', %args));
   return $response
}

sub Logout {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('Logout', %args));
   return $response
}

sub AcquireLocalTicket {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('AcquireLocalTicket', %args));
   return $response
}

sub AcquireGenericServiceTicket {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('AcquireGenericServiceTicket', %args));
   return $response
}

sub TerminateSession {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('TerminateSession', %args));
   return $response
}

sub SetLocale {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('SetLocale', %args));
   return $response
}

sub LoginExtensionBySubjectName {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('LoginExtensionBySubjectName', %args));
   return $response
}

sub LoginExtensionByCertificate {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('LoginExtensionByCertificate', %args));
   return $response
}

sub ImpersonateUser {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('ImpersonateUser', %args));
   return $response
}

sub SessionIsActive {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('SessionIsActive', %args));
   return $response
}

sub AcquireCloneTicket {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('AcquireCloneTicket', %args));
   return $response
}

sub CloneSession {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('CloneSession', %args));
   return $response
}


1;
##################################################################################

##################################################################################
package SimpleCommandOperations;
sub ExecuteSimpleCommand {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('ExecuteSimpleCommand', %args));
   return $response
}


1;
##################################################################################

##################################################################################
package StoragePodOperations;
our @ISA = qw(FolderOperations);

1;
##################################################################################

##################################################################################
package StorageResourceManagerOperations;
sub ConfigureDatastoreIORM_Task {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('ConfigureDatastoreIORM_Task', %args));
   return $response
}

sub ConfigureDatastoreIORM {
   my ($self, %args) = @_;
   return $self->waitForTask($self->ConfigureDatastoreIORM_Task(%args));
}

sub QueryIORMConfigOption {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('QueryIORMConfigOption', %args));
   return $response
}

sub QueryDatastorePerformanceSummary {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('QueryDatastorePerformanceSummary', %args));
   return $response
}

sub ApplyStorageDrsRecommendationToPod_Task {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('ApplyStorageDrsRecommendationToPod_Task', %args));
   return $response
}

sub ApplyStorageDrsRecommendationToPod {
   my ($self, %args) = @_;
   return $self->waitForTask($self->ApplyStorageDrsRecommendationToPod_Task(%args));
}

sub ApplyStorageDrsRecommendation_Task {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('ApplyStorageDrsRecommendation_Task', %args));
   return $response
}

sub ApplyStorageDrsRecommendation {
   my ($self, %args) = @_;
   return $self->waitForTask($self->ApplyStorageDrsRecommendation_Task(%args));
}

sub CancelStorageDrsRecommendation {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('CancelStorageDrsRecommendation', %args));
   return $response
}

sub RefreshStorageDrsRecommendation {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('RefreshStorageDrsRecommendation', %args));
   return $response
}

sub RefreshStorageDrsRecommendationsForPod_Task {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('RefreshStorageDrsRecommendationsForPod_Task', %args));
   return $response
}

sub RefreshStorageDrsRecommendationsForPod {
   my ($self, %args) = @_;
   return $self->waitForTask($self->RefreshStorageDrsRecommendationsForPod_Task(%args));
}

sub ConfigureStorageDrsForPod_Task {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('ConfigureStorageDrsForPod_Task', %args));
   return $response
}

sub ConfigureStorageDrsForPod {
   my ($self, %args) = @_;
   return $self->waitForTask($self->ConfigureStorageDrsForPod_Task(%args));
}

sub ValidateStoragePodConfig {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('ValidateStoragePodConfig', %args));
   return $response
}

sub RecommendDatastores {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('RecommendDatastores', %args));
   return $response
}


1;
##################################################################################

##################################################################################
package TaskOperations;
our @ISA = qw(ExtensibleManagedObjectOperations);
sub CancelTask {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('CancelTask', %args));
   return $response
}

sub UpdateProgress {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('UpdateProgress', %args));
   return $response
}

sub SetTaskState {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('SetTaskState', %args));
   return $response
}

sub SetTaskDescription {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('SetTaskDescription', %args));
   return $response
}


1;
##################################################################################

##################################################################################
package TaskHistoryCollectorOperations;
our @ISA = qw(HistoryCollectorOperations);
sub ReadNextTasks {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('ReadNextTasks', %args));
   return $response
}

sub ReadPreviousTasks {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('ReadPreviousTasks', %args));
   return $response
}


1;
##################################################################################

##################################################################################
package TaskManagerOperations;
sub CreateCollectorForTasks {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('CreateCollectorForTasks', %args));
   return $response
}

sub CreateTask {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('CreateTask', %args));
   return $response
}


1;
##################################################################################

##################################################################################
package UserDirectoryOperations;
sub RetrieveUserGroups {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('RetrieveUserGroups', %args));
   return $response
}


1;
##################################################################################

##################################################################################
package VirtualAppOperations;
our @ISA = qw(ResourcePoolOperations);
sub UpdateVAppConfig {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('UpdateVAppConfig', %args));
   return $response
}

sub UpdateLinkedChildren {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('UpdateLinkedChildren', %args));
   return $response
}

sub CloneVApp_Task {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('CloneVApp_Task', %args));
   return $response
}

sub CloneVApp {
   my ($self, %args) = @_;
   return $self->waitForTask($self->CloneVApp_Task(%args));
}

sub ExportVApp {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('ExportVApp', %args));
   return $response
}

sub PowerOnVApp_Task {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('PowerOnVApp_Task', %args));
   return $response
}

sub PowerOnVApp {
   my ($self, %args) = @_;
   return $self->waitForTask($self->PowerOnVApp_Task(%args));
}

sub PowerOffVApp_Task {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('PowerOffVApp_Task', %args));
   return $response
}

sub PowerOffVApp {
   my ($self, %args) = @_;
   return $self->waitForTask($self->PowerOffVApp_Task(%args));
}

sub SuspendVApp_Task {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('SuspendVApp_Task', %args));
   return $response
}

sub SuspendVApp {
   my ($self, %args) = @_;
   return $self->waitForTask($self->SuspendVApp_Task(%args));
}

sub unregisterVApp_Task {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('unregisterVApp_Task', %args));
   return $response
}

sub unregisterVApp {
   my ($self, %args) = @_;
   return $self->waitForTask($self->unregisterVApp_Task(%args));
}


1;
##################################################################################

##################################################################################
package VirtualDiskManagerOperations;
sub CreateVirtualDisk_Task {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('CreateVirtualDisk_Task', %args));
   return $response
}

sub CreateVirtualDisk {
   my ($self, %args) = @_;
   return $self->waitForTask($self->CreateVirtualDisk_Task(%args));
}

sub DeleteVirtualDisk_Task {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('DeleteVirtualDisk_Task', %args));
   return $response
}

sub DeleteVirtualDisk {
   my ($self, %args) = @_;
   return $self->waitForTask($self->DeleteVirtualDisk_Task(%args));
}

sub MoveVirtualDisk_Task {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('MoveVirtualDisk_Task', %args));
   return $response
}

sub MoveVirtualDisk {
   my ($self, %args) = @_;
   return $self->waitForTask($self->MoveVirtualDisk_Task(%args));
}

sub CopyVirtualDisk_Task {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('CopyVirtualDisk_Task', %args));
   return $response
}

sub CopyVirtualDisk {
   my ($self, %args) = @_;
   return $self->waitForTask($self->CopyVirtualDisk_Task(%args));
}

sub ExtendVirtualDisk_Task {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('ExtendVirtualDisk_Task', %args));
   return $response
}

sub ExtendVirtualDisk {
   my ($self, %args) = @_;
   return $self->waitForTask($self->ExtendVirtualDisk_Task(%args));
}

sub QueryVirtualDiskFragmentation {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('QueryVirtualDiskFragmentation', %args));
   return $response
}

sub DefragmentVirtualDisk_Task {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('DefragmentVirtualDisk_Task', %args));
   return $response
}

sub DefragmentVirtualDisk {
   my ($self, %args) = @_;
   return $self->waitForTask($self->DefragmentVirtualDisk_Task(%args));
}

sub ShrinkVirtualDisk_Task {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('ShrinkVirtualDisk_Task', %args));
   return $response
}

sub ShrinkVirtualDisk {
   my ($self, %args) = @_;
   return $self->waitForTask($self->ShrinkVirtualDisk_Task(%args));
}

sub InflateVirtualDisk_Task {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('InflateVirtualDisk_Task', %args));
   return $response
}

sub InflateVirtualDisk {
   my ($self, %args) = @_;
   return $self->waitForTask($self->InflateVirtualDisk_Task(%args));
}

sub EagerZeroVirtualDisk_Task {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('EagerZeroVirtualDisk_Task', %args));
   return $response
}

sub EagerZeroVirtualDisk {
   my ($self, %args) = @_;
   return $self->waitForTask($self->EagerZeroVirtualDisk_Task(%args));
}

sub ZeroFillVirtualDisk_Task {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('ZeroFillVirtualDisk_Task', %args));
   return $response
}

sub ZeroFillVirtualDisk {
   my ($self, %args) = @_;
   return $self->waitForTask($self->ZeroFillVirtualDisk_Task(%args));
}

sub SetVirtualDiskUuid {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('SetVirtualDiskUuid', %args));
   return $response
}

sub QueryVirtualDiskUuid {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('QueryVirtualDiskUuid', %args));
   return $response
}

sub QueryVirtualDiskGeometry {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('QueryVirtualDiskGeometry', %args));
   return $response
}

sub ImportUnmanagedSnapshot {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('ImportUnmanagedSnapshot', %args));
   return $response
}

sub ReleaseManagedSnapshot {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('ReleaseManagedSnapshot', %args));
   return $response
}


1;
##################################################################################

##################################################################################
package VirtualMachineOperations;
our @ISA = qw(ManagedEntityOperations);
sub RefreshStorageInfo {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('RefreshStorageInfo', %args));
   return $response
}

sub CreateSnapshot_Task {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('CreateSnapshot_Task', %args));
   return $response
}

sub CreateSnapshot {
   my ($self, %args) = @_;
   return $self->waitForTask($self->CreateSnapshot_Task(%args));
}

sub CreateSnapshotEx_Task {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('CreateSnapshotEx_Task', %args));
   return $response
}

sub CreateSnapshotEx {
   my ($self, %args) = @_;
   return $self->waitForTask($self->CreateSnapshotEx_Task(%args));
}

sub RevertToCurrentSnapshot_Task {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('RevertToCurrentSnapshot_Task', %args));
   return $response
}

sub RevertToCurrentSnapshot {
   my ($self, %args) = @_;
   return $self->waitForTask($self->RevertToCurrentSnapshot_Task(%args));
}

sub RemoveAllSnapshots_Task {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('RemoveAllSnapshots_Task', %args));
   return $response
}

sub RemoveAllSnapshots {
   my ($self, %args) = @_;
   return $self->waitForTask($self->RemoveAllSnapshots_Task(%args));
}

sub ConsolidateVMDisks_Task {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('ConsolidateVMDisks_Task', %args));
   return $response
}

sub ConsolidateVMDisks {
   my ($self, %args) = @_;
   return $self->waitForTask($self->ConsolidateVMDisks_Task(%args));
}

sub EstimateStorageForConsolidateSnapshots_Task {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('EstimateStorageForConsolidateSnapshots_Task', %args));
   return $response
}

sub EstimateStorageForConsolidateSnapshots {
   my ($self, %args) = @_;
   return $self->waitForTask($self->EstimateStorageForConsolidateSnapshots_Task(%args));
}

sub ReconfigVM_Task {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('ReconfigVM_Task', %args));
   return $response
}

sub ReconfigVM {
   my ($self, %args) = @_;
   return $self->waitForTask($self->ReconfigVM_Task(%args));
}

sub UpgradeVM_Task {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('UpgradeVM_Task', %args));
   return $response
}

sub UpgradeVM {
   my ($self, %args) = @_;
   return $self->waitForTask($self->UpgradeVM_Task(%args));
}

sub ExtractOvfEnvironment {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('ExtractOvfEnvironment', %args));
   return $response
}

sub PowerOnVM_Task {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('PowerOnVM_Task', %args));
   return $response
}

sub PowerOnVM {
   my ($self, %args) = @_;
   return $self->waitForTask($self->PowerOnVM_Task(%args));
}

sub PowerOffVM_Task {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('PowerOffVM_Task', %args));
   return $response
}

sub PowerOffVM {
   my ($self, %args) = @_;
   return $self->waitForTask($self->PowerOffVM_Task(%args));
}

sub SuspendVM_Task {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('SuspendVM_Task', %args));
   return $response
}

sub SuspendVM {
   my ($self, %args) = @_;
   return $self->waitForTask($self->SuspendVM_Task(%args));
}

sub ResetVM_Task {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('ResetVM_Task', %args));
   return $response
}

sub ResetVM {
   my ($self, %args) = @_;
   return $self->waitForTask($self->ResetVM_Task(%args));
}

sub ShutdownGuest {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('ShutdownGuest', %args));
   return $response
}

sub RebootGuest {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('RebootGuest', %args));
   return $response
}

sub StandbyGuest {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('StandbyGuest', %args));
   return $response
}

sub AnswerVM {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('AnswerVM', %args));
   return $response
}

sub CustomizeVM_Task {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('CustomizeVM_Task', %args));
   return $response
}

sub CustomizeVM {
   my ($self, %args) = @_;
   return $self->waitForTask($self->CustomizeVM_Task(%args));
}

sub CheckCustomizationSpec {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('CheckCustomizationSpec', %args));
   return $response
}

sub MigrateVM_Task {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('MigrateVM_Task', %args));
   return $response
}

sub MigrateVM {
   my ($self, %args) = @_;
   return $self->waitForTask($self->MigrateVM_Task(%args));
}

sub RelocateVM_Task {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('RelocateVM_Task', %args));
   return $response
}

sub RelocateVM {
   my ($self, %args) = @_;
   return $self->waitForTask($self->RelocateVM_Task(%args));
}

sub CloneVM_Task {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('CloneVM_Task', %args));
   return $response
}

sub CloneVM {
   my ($self, %args) = @_;
   return $self->waitForTask($self->CloneVM_Task(%args));
}

sub InstantClone_Task {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('InstantClone_Task', %args));
   return $response
}

sub InstantClone {
   my ($self, %args) = @_;
   return $self->waitForTask($self->InstantClone_Task(%args));
}

sub ExportVm {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('ExportVm', %args));
   return $response
}

sub MarkAsTemplate {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('MarkAsTemplate', %args));
   return $response
}

sub MarkAsVirtualMachine {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('MarkAsVirtualMachine', %args));
   return $response
}

sub UnregisterVM {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('UnregisterVM', %args));
   return $response
}

sub ResetGuestInformation {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('ResetGuestInformation', %args));
   return $response
}

sub MountToolsInstaller {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('MountToolsInstaller', %args));
   return $response
}

sub UnmountToolsInstaller {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('UnmountToolsInstaller', %args));
   return $response
}

sub UpgradeTools_Task {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('UpgradeTools_Task', %args));
   return $response
}

sub UpgradeTools {
   my ($self, %args) = @_;
   return $self->waitForTask($self->UpgradeTools_Task(%args));
}

sub AcquireMksTicket {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('AcquireMksTicket', %args));
   return $response
}

sub AcquireTicket {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('AcquireTicket', %args));
   return $response
}

sub SetScreenResolution {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('SetScreenResolution', %args));
   return $response
}

sub DefragmentAllDisks {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('DefragmentAllDisks', %args));
   return $response
}

sub CreateSecondaryVM_Task {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('CreateSecondaryVM_Task', %args));
   return $response
}

sub CreateSecondaryVM {
   my ($self, %args) = @_;
   return $self->waitForTask($self->CreateSecondaryVM_Task(%args));
}

sub CreateSecondaryVMEx_Task {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('CreateSecondaryVMEx_Task', %args));
   return $response
}

sub CreateSecondaryVMEx {
   my ($self, %args) = @_;
   return $self->waitForTask($self->CreateSecondaryVMEx_Task(%args));
}

sub TurnOffFaultToleranceForVM_Task {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('TurnOffFaultToleranceForVM_Task', %args));
   return $response
}

sub TurnOffFaultToleranceForVM {
   my ($self, %args) = @_;
   return $self->waitForTask($self->TurnOffFaultToleranceForVM_Task(%args));
}

sub MakePrimaryVM_Task {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('MakePrimaryVM_Task', %args));
   return $response
}

sub MakePrimaryVM {
   my ($self, %args) = @_;
   return $self->waitForTask($self->MakePrimaryVM_Task(%args));
}

sub TerminateFaultTolerantVM_Task {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('TerminateFaultTolerantVM_Task', %args));
   return $response
}

sub TerminateFaultTolerantVM {
   my ($self, %args) = @_;
   return $self->waitForTask($self->TerminateFaultTolerantVM_Task(%args));
}

sub DisableSecondaryVM_Task {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('DisableSecondaryVM_Task', %args));
   return $response
}

sub DisableSecondaryVM {
   my ($self, %args) = @_;
   return $self->waitForTask($self->DisableSecondaryVM_Task(%args));
}

sub EnableSecondaryVM_Task {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('EnableSecondaryVM_Task', %args));
   return $response
}

sub EnableSecondaryVM {
   my ($self, %args) = @_;
   return $self->waitForTask($self->EnableSecondaryVM_Task(%args));
}

sub SetDisplayTopology {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('SetDisplayTopology', %args));
   return $response
}

sub StartRecording_Task {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('StartRecording_Task', %args));
   return $response
}

sub StartRecording {
   my ($self, %args) = @_;
   return $self->waitForTask($self->StartRecording_Task(%args));
}

sub StopRecording_Task {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('StopRecording_Task', %args));
   return $response
}

sub StopRecording {
   my ($self, %args) = @_;
   return $self->waitForTask($self->StopRecording_Task(%args));
}

sub StartReplaying_Task {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('StartReplaying_Task', %args));
   return $response
}

sub StartReplaying {
   my ($self, %args) = @_;
   return $self->waitForTask($self->StartReplaying_Task(%args));
}

sub StopReplaying_Task {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('StopReplaying_Task', %args));
   return $response
}

sub StopReplaying {
   my ($self, %args) = @_;
   return $self->waitForTask($self->StopReplaying_Task(%args));
}

sub PromoteDisks_Task {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('PromoteDisks_Task', %args));
   return $response
}

sub PromoteDisks {
   my ($self, %args) = @_;
   return $self->waitForTask($self->PromoteDisks_Task(%args));
}

sub CreateScreenshot_Task {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('CreateScreenshot_Task', %args));
   return $response
}

sub CreateScreenshot {
   my ($self, %args) = @_;
   return $self->waitForTask($self->CreateScreenshot_Task(%args));
}

sub PutUsbScanCodes {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('PutUsbScanCodes', %args));
   return $response
}

sub QueryChangedDiskAreas {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('QueryChangedDiskAreas', %args));
   return $response
}

sub QueryUnownedFiles {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('QueryUnownedFiles', %args));
   return $response
}

sub reloadVirtualMachineFromPath_Task {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('reloadVirtualMachineFromPath_Task', %args));
   return $response
}

sub reloadVirtualMachineFromPath {
   my ($self, %args) = @_;
   return $self->waitForTask($self->reloadVirtualMachineFromPath_Task(%args));
}

sub QueryFaultToleranceCompatibility {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('QueryFaultToleranceCompatibility', %args));
   return $response
}

sub QueryFaultToleranceCompatibilityEx {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('QueryFaultToleranceCompatibilityEx', %args));
   return $response
}

sub TerminateVM {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('TerminateVM', %args));
   return $response
}

sub SendNMI {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('SendNMI', %args));
   return $response
}

sub AttachDisk_Task {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('AttachDisk_Task', %args));
   return $response
}

sub AttachDisk {
   my ($self, %args) = @_;
   return $self->waitForTask($self->AttachDisk_Task(%args));
}

sub DetachDisk_Task {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('DetachDisk_Task', %args));
   return $response
}

sub DetachDisk {
   my ($self, %args) = @_;
   return $self->waitForTask($self->DetachDisk_Task(%args));
}

sub ApplyEvcModeVM_Task {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('ApplyEvcModeVM_Task', %args));
   return $response
}

sub ApplyEvcModeVM {
   my ($self, %args) = @_;
   return $self->waitForTask($self->ApplyEvcModeVM_Task(%args));
}

sub CryptoUnlock_Task {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('CryptoUnlock_Task', %args));
   return $response
}

sub CryptoUnlock {
   my ($self, %args) = @_;
   return $self->waitForTask($self->CryptoUnlock_Task(%args));
}


1;
##################################################################################

##################################################################################
package VirtualizationManagerOperations;

1;
##################################################################################

##################################################################################
package VsanMassCollectorOperations;
sub VsanRetrieveProperties {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('VsanRetrieveProperties', %args));
   return $response
}


1;
##################################################################################

##################################################################################
package VsanPhoneHomeSystemOperations;
sub QueryVsanCloudHealthStatus {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('QueryVsanCloudHealthStatus', %args));
   return $response
}

sub VsanPerformOnlineHealthCheck {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('VsanPerformOnlineHealthCheck', %args));
   return $response
}


1;
##################################################################################

##################################################################################
package VsanUpgradeSystemOperations;
sub PerformVsanUpgradePreflightCheck {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('PerformVsanUpgradePreflightCheck', %args));
   return $response
}

sub QueryVsanUpgradeStatus {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('QueryVsanUpgradeStatus', %args));
   return $response
}

sub PerformVsanUpgrade_Task {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('PerformVsanUpgrade_Task', %args));
   return $response
}

sub PerformVsanUpgrade {
   my ($self, %args) = @_;
   return $self->waitForTask($self->PerformVsanUpgrade_Task(%args));
}


1;
##################################################################################

##################################################################################
package VsanUpgradeSystemExOperations;
sub PerformVsanUpgradeEx {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('PerformVsanUpgradeEx', %args));
   return $response
}

sub VsanQueryUpgradeStatusEx {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('VsanQueryUpgradeStatusEx', %args));
   return $response
}

sub RetrieveSupportedVsanFormatVersion {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('RetrieveSupportedVsanFormatVersion', %args));
   return $response
}

sub PerformVsanUpgradePreflightCheckEx {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('PerformVsanUpgradePreflightCheckEx', %args));
   return $response
}

sub PerformVsanUpgradePreflightAsyncCheck_Task {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('PerformVsanUpgradePreflightAsyncCheck_Task', %args));
   return $response
}

sub PerformVsanUpgradePreflightAsyncCheck {
   my ($self, %args) = @_;
   return $self->waitForTask($self->PerformVsanUpgradePreflightAsyncCheck_Task(%args));
}


1;
##################################################################################

##################################################################################
package AlarmOperations;
our @ISA = qw(ExtensibleManagedObjectOperations);
sub RemoveAlarm {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('RemoveAlarm', %args));
   return $response
}

sub ReconfigureAlarm {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('ReconfigureAlarm', %args));
   return $response
}


1;
##################################################################################

##################################################################################
package AlarmManagerOperations;
sub CreateAlarm {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('CreateAlarm', %args));
   return $response
}

sub GetAlarm {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('GetAlarm', %args));
   return $response
}

sub AreAlarmActionsEnabled {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('AreAlarmActionsEnabled', %args));
   return $response
}

sub EnableAlarmActions {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('EnableAlarmActions', %args));
   return $response
}

sub GetAlarmState {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('GetAlarmState', %args));
   return $response
}

sub AcknowledgeAlarm {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('AcknowledgeAlarm', %args));
   return $response
}

sub ClearTriggeredAlarms {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('ClearTriggeredAlarms', %args));
   return $response
}


1;
##################################################################################

##################################################################################
package ClusterEVCManagerOperations;
our @ISA = qw(ExtensibleManagedObjectOperations);
sub ConfigureEvcMode_Task {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('ConfigureEvcMode_Task', %args));
   return $response
}

sub ConfigureEvcMode {
   my ($self, %args) = @_;
   return $self->waitForTask($self->ConfigureEvcMode_Task(%args));
}

sub DisableEvcMode_Task {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('DisableEvcMode_Task', %args));
   return $response
}

sub DisableEvcMode {
   my ($self, %args) = @_;
   return $self->waitForTask($self->DisableEvcMode_Task(%args));
}

sub CheckConfigureEvcMode_Task {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('CheckConfigureEvcMode_Task', %args));
   return $response
}

sub CheckConfigureEvcMode {
   my ($self, %args) = @_;
   return $self->waitForTask($self->CheckConfigureEvcMode_Task(%args));
}

sub CheckAddHostEvc_Task {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('CheckAddHostEvc_Task', %args));
   return $response
}

sub CheckAddHostEvc {
   my ($self, %args) = @_;
   return $self->waitForTask($self->CheckAddHostEvc_Task(%args));
}


1;
##################################################################################

##################################################################################
package VsanCapabilitySystemOperations;
sub VsanGetCapabilities {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('VsanGetCapabilities', %args));
   return $response
}


1;
##################################################################################

##################################################################################
package VsanClusterHealthSystemOperations;
sub VsanQueryClusterPhysicalDiskHealthSummary {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('VsanQueryClusterPhysicalDiskHealthSummary', %args));
   return $response
}

sub VsanQueryClusterNetworkPerfTest {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('VsanQueryClusterNetworkPerfTest', %args));
   return $response
}

sub VsanQueryClusterAdvCfgSync {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('VsanQueryClusterAdvCfgSync', %args));
   return $response
}

sub VsanRepairClusterImmediateObjects {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('VsanRepairClusterImmediateObjects', %args));
   return $response
}

sub VsanQueryVerifyClusterNetworkSettings {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('VsanQueryVerifyClusterNetworkSettings', %args));
   return $response
}

sub VsanQueryClusterCreateVmHealthTest {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('VsanQueryClusterCreateVmHealthTest', %args));
   return $response
}

sub VsanQueryClusterHealthSystemVersions {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('VsanQueryClusterHealthSystemVersions', %args));
   return $response
}

sub VsanClusterGetHclInfo {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('VsanClusterGetHclInfo', %args));
   return $response
}

sub VsanQueryClusterCheckLimits {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('VsanQueryClusterCheckLimits', %args));
   return $response
}

sub VsanQueryClusterCaptureVsanPcap {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('VsanQueryClusterCaptureVsanPcap', %args));
   return $response
}

sub VsanCheckClusterClomdLiveness {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('VsanCheckClusterClomdLiveness', %args));
   return $response
}


1;
##################################################################################

##################################################################################
package VsanClusterMgmtInternalSystemOperations;
sub VsanRemediateVsanCluster {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('VsanRemediateVsanCluster', %args));
   return $response
}

sub VsanRemediateVsanHost {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('VsanRemediateVsanHost', %args));
   return $response
}


1;
##################################################################################

##################################################################################
package VsanIscsiTargetSystemOperations;
sub VsanVitRemoveIscsiInitiatorsFromTarget {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('VsanVitRemoveIscsiInitiatorsFromTarget', %args));
   return $response
}

sub VsanVitRemoveIscsiInitiatorsFromGroup {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('VsanVitRemoveIscsiInitiatorsFromGroup', %args));
   return $response
}

sub VsanVitEditIscsiLUN {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('VsanVitEditIscsiLUN', %args));
   return $response
}

sub VsanVitGetIscsiLUN {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('VsanVitGetIscsiLUN', %args));
   return $response
}

sub VsanVitEditIscsiTarget {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('VsanVitEditIscsiTarget', %args));
   return $response
}

sub VsanVitAddIscsiInitiatorsToGroup {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('VsanVitAddIscsiInitiatorsToGroup', %args));
   return $response
}

sub VsanVitAddIscsiInitiatorsToTarget {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('VsanVitAddIscsiInitiatorsToTarget', %args));
   return $response
}

sub VsanVitQueryIscsiTargetServiceVersion {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('VsanVitQueryIscsiTargetServiceVersion', %args));
   return $response
}

sub VsanVitAddIscsiTargetToGroup {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('VsanVitAddIscsiTargetToGroup', %args));
   return $response
}

sub VsanVitRemoveIscsiTargetFromGroup {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('VsanVitRemoveIscsiTargetFromGroup', %args));
   return $response
}

sub VsanVitGetIscsiLUNs {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('VsanVitGetIscsiLUNs', %args));
   return $response
}

sub VsanVitRemoveIscsiLUN {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('VsanVitRemoveIscsiLUN', %args));
   return $response
}

sub VsanVitGetIscsiInitiatorGroup {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('VsanVitGetIscsiInitiatorGroup', %args));
   return $response
}

sub VsanVitRemoveIscsiInitiatorGroup {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('VsanVitRemoveIscsiInitiatorGroup', %args));
   return $response
}

sub VsanVitGetHomeObject {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('VsanVitGetHomeObject', %args));
   return $response
}

sub VsanVitGetIscsiTarget {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('VsanVitGetIscsiTarget', %args));
   return $response
}

sub VsanVitRemoveIscsiTarget {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('VsanVitRemoveIscsiTarget', %args));
   return $response
}

sub VsanVitAddIscsiLUN {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('VsanVitAddIscsiLUN', %args));
   return $response
}

sub VsanVitGetIscsiInitiatorGroups {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('VsanVitGetIscsiInitiatorGroups', %args));
   return $response
}

sub VsanVitGetIscsiTargets {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('VsanVitGetIscsiTargets', %args));
   return $response
}

sub VsanVitAddIscsiTarget {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('VsanVitAddIscsiTarget', %args));
   return $response
}

sub VsanVitAddIscsiInitiatorGroup {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('VsanVitAddIscsiInitiatorGroup', %args));
   return $response
}


1;
##################################################################################

##################################################################################
package VsanObjectSystemOperations;
sub VosSetVsanObjectPolicy {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('VosSetVsanObjectPolicy', %args));
   return $response
}

sub VsanDeleteObjects_Task {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('VsanDeleteObjects_Task', %args));
   return $response
}

sub VsanDeleteObjects {
   my ($self, %args) = @_;
   return $self->waitForTask($self->VsanDeleteObjects_Task(%args));
}

sub VosQueryVsanObjectInformation {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('VosQueryVsanObjectInformation', %args));
   return $response
}

sub VsanQueryInaccessibleVmSwapObjects {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('VsanQueryInaccessibleVmSwapObjects', %args));
   return $response
}

sub QuerySyncingVsanObjectsSummary {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('QuerySyncingVsanObjectsSummary', %args));
   return $response
}

sub VsanQueryObjectIdentities {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('VsanQueryObjectIdentities', %args));
   return $response
}


1;
##################################################################################

##################################################################################
package VsanPerformanceManagerOperations;
sub VsanPerfDiagnose {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('VsanPerfDiagnose', %args));
   return $response
}

sub VsanPerfQueryClusterHealth {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('VsanPerfQueryClusterHealth', %args));
   return $response
}

sub GetVsanPerfDiagnosisResult {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('GetVsanPerfDiagnosisResult', %args));
   return $response
}

sub VsanPerfToggleVerboseMode {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('VsanPerfToggleVerboseMode', %args));
   return $response
}

sub VsanPerfDiagnoseTask {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('VsanPerfDiagnoseTask', %args));
   return $response
}

sub VsanPerfQueryTimeRanges {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('VsanPerfQueryTimeRanges', %args));
   return $response
}

sub VsanPerfSetStatsObjectPolicy {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('VsanPerfSetStatsObjectPolicy', %args));
   return $response
}

sub VsanPerfCreateStatsObject {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('VsanPerfCreateStatsObject', %args));
   return $response
}

sub VsanPerfQueryPerf {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('VsanPerfQueryPerf', %args));
   return $response
}

sub VsanPerfCreateStatsObjectTask {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('VsanPerfCreateStatsObjectTask', %args));
   return $response
}

sub VsanPerfDeleteStatsObjectTask {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('VsanPerfDeleteStatsObjectTask', %args));
   return $response
}

sub VsanPerfGetAggregatedEntityTypes {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('VsanPerfGetAggregatedEntityTypes', %args));
   return $response
}

sub VsanPerfDeleteTimeRange {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('VsanPerfDeleteTimeRange', %args));
   return $response
}

sub VsanPerfQueryStatsObjectInformation {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('VsanPerfQueryStatsObjectInformation', %args));
   return $response
}

sub VsanPerfDeleteStatsObject {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('VsanPerfDeleteStatsObject', %args));
   return $response
}

sub VsanPerfSaveTimeRanges {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('VsanPerfSaveTimeRanges', %args));
   return $response
}

sub VsanPerfQueryNodeInformation {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('VsanPerfQueryNodeInformation', %args));
   return $response
}

sub VsanPerfGetSupportedDiagnosticExceptions {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('VsanPerfGetSupportedDiagnosticExceptions', %args));
   return $response
}

sub VsanPerfGetSupportedEntityTypes {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('VsanPerfGetSupportedEntityTypes', %args));
   return $response
}


1;
##################################################################################

##################################################################################
package VsanSpaceReportSystemOperations;
sub VsanQuerySpaceUsage {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('VsanQuerySpaceUsage', %args));
   return $response
}

sub VsanQueryEntitySpaceUsage {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('VsanQueryEntitySpaceUsage', %args));
   return $response
}


1;
##################################################################################

##################################################################################
package VsanVcClusterConfigSystemOperations;
sub VsanClusterReconfig {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('VsanClusterReconfig', %args));
   return $response
}

sub VsanClusterGetRuntimeStats {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('VsanClusterGetRuntimeStats', %args));
   return $response
}

sub VsanQueryClusterDrsStats {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('VsanQueryClusterDrsStats', %args));
   return $response
}

sub VsanClusterGetConfig {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('VsanClusterGetConfig', %args));
   return $response
}

sub VsanEncryptedClusterRekey_Task {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('VsanEncryptedClusterRekey_Task', %args));
   return $response
}

sub VsanEncryptedClusterRekey {
   my ($self, %args) = @_;
   return $self->waitForTask($self->VsanEncryptedClusterRekey_Task(%args));
}


1;
##################################################################################

##################################################################################
package VsanVcClusterHealthSystemOperations;
sub VsanPurgeHclFiles {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('VsanPurgeHclFiles', %args));
   return $response
}

sub VsanQueryVcClusterCreateVmHealthHistoryTest {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('VsanQueryVcClusterCreateVmHealthHistoryTest', %args));
   return $response
}

sub VsanQueryVcClusterObjExtAttrs {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('VsanQueryVcClusterObjExtAttrs', %args));
   return $response
}

sub VsanHealthSetLogLevel {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('VsanHealthSetLogLevel', %args));
   return $response
}

sub VsanHealthTestVsanClusterTelemetryProxy {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('VsanHealthTestVsanClusterTelemetryProxy', %args));
   return $response
}

sub VsanVcUploadHclDb {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('VsanVcUploadHclDb', %args));
   return $response
}

sub VsanQueryVcClusterSmartStatsSummary {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('VsanQueryVcClusterSmartStatsSummary', %args));
   return $response
}

sub VsanVcUpdateHclDbFromWeb {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('VsanVcUpdateHclDbFromWeb', %args));
   return $response
}

sub VsanHealthGetVsanClusterSilentChecks {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('VsanHealthGetVsanClusterSilentChecks', %args));
   return $response
}

sub VsanClusterQueryFileServiceHealthSummary {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('VsanClusterQueryFileServiceHealthSummary', %args));
   return $response
}

sub VsanHealthRepairClusterObjectsImmediate {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('VsanHealthRepairClusterObjectsImmediate', %args));
   return $response
}

sub VsanQueryVcClusterNetworkPerfTest {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('VsanQueryVcClusterNetworkPerfTest', %args));
   return $response
}

sub VsanQueryVcClusterVmdkLoadHistoryTest {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('VsanQueryVcClusterVmdkLoadHistoryTest', %args));
   return $response
}

sub VsanHealthIsRebalanceRunning {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('VsanHealthIsRebalanceRunning', %args));
   return $response
}

sub VsanQueryVcClusterCreateVmHealthTest {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('VsanQueryVcClusterCreateVmHealthTest', %args));
   return $response
}

sub VsanHealthQueryVsanProxyConfig {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('VsanHealthQueryVsanProxyConfig', %args));
   return $response
}

sub VsanHealthQueryVsanClusterHealthCheckInterval {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('VsanHealthQueryVsanClusterHealthCheckInterval', %args));
   return $response
}

sub VsanQueryAllSupportedHealthChecks {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('VsanQueryAllSupportedHealthChecks', %args));
   return $response
}

sub VsanVcClusterGetHclInfo {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('VsanVcClusterGetHclInfo', %args));
   return $response
}

sub VsanQueryAttachToSrHistory {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('VsanQueryAttachToSrHistory', %args));
   return $response
}

sub VsanGetReleaseRecommendation {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('VsanGetReleaseRecommendation', %args));
   return $response
}

sub VsanGetHclConstraints {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('VsanGetHclConstraints', %args));
   return $response
}

sub VsanRebalanceCluster {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('VsanRebalanceCluster', %args));
   return $response
}

sub VsanVcClusterRunVmdkLoadTest {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('VsanVcClusterRunVmdkLoadTest', %args));
   return $response
}

sub VsanHealthSendVsanTelemetry {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('VsanHealthSendVsanTelemetry', %args));
   return $response
}

sub VsanQueryVcClusterNetworkPerfHistoryTest {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('VsanQueryVcClusterNetworkPerfHistoryTest', %args));
   return $response
}

sub VsanQueryVcClusterHealthSummary {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('VsanQueryVcClusterHealthSummary', %args));
   return $response
}

sub VsanQueryVcClusterHealthSummaryTask {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('VsanQueryVcClusterHealthSummaryTask', %args));
   return $response
}

sub VsanStopRebalanceCluster {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('VsanStopRebalanceCluster', %args));
   return $response
}

sub VsanHealthQueryVsanClusterHealthConfig {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('VsanHealthQueryVsanClusterHealthConfig', %args));
   return $response
}

sub VsanAttachVsanSupportBundleToSr {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('VsanAttachVsanSupportBundleToSr', %args));
   return $response
}

sub VsanDownloadHclFile_Task {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('VsanDownloadHclFile_Task', %args));
   return $response
}

sub VsanDownloadHclFile {
   my ($self, %args) = @_;
   return $self->waitForTask($self->VsanDownloadHclFile_Task(%args));
}

sub VsanQueryVcClusterVmdkWorkloadTypes {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('VsanQueryVcClusterVmdkWorkloadTypes', %args));
   return $response
}

sub VsanHealthSetVsanClusterSilentChecks {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('VsanHealthSetVsanClusterSilentChecks', %args));
   return $response
}

sub VsanVcClusterQueryVerifyHealthSystemVersions {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('VsanVcClusterQueryVerifyHealthSystemVersions', %args));
   return $response
}

sub VsanHealthSetVsanClusterTelemetryConfig {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('VsanHealthSetVsanClusterTelemetryConfig', %args));
   return $response
}

sub VsanDownloadAndInstallVendorTool_Task {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('VsanDownloadAndInstallVendorTool_Task', %args));
   return $response
}

sub VsanDownloadAndInstallVendorTool {
   my ($self, %args) = @_;
   return $self->waitForTask($self->VsanDownloadAndInstallVendorTool_Task(%args));
}

sub VsanHealthSetVsanClusterHealthCheckInterval {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('VsanHealthSetVsanClusterHealthCheckInterval', %args));
   return $response
}


1;
##################################################################################

##################################################################################
package VimClusterVsanVcDiskManagementSystemOperations;
sub InitializeDiskMappings {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('InitializeDiskMappings', %args));
   return $response
}

sub QueryDiskMappings {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('QueryDiskMappings', %args));
   return $response
}

sub QueryClusterDataEfficiencyCapacityState {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('QueryClusterDataEfficiencyCapacityState', %args));
   return $response
}

sub RetrieveAllFlashCapabilities {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('RetrieveAllFlashCapabilities', %args));
   return $response
}

sub RebuildDiskMapping {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('RebuildDiskMapping', %args));
   return $response
}


1;
##################################################################################

##################################################################################
package VimClusterVsanVcStretchedClusterSystemOperations;
sub VSANVcIsWitnessHost {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('VSANVcIsWitnessHost', %args));
   return $response
}

sub VSANVcSetPreferredFaultDomain {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('VSANVcSetPreferredFaultDomain', %args));
   return $response
}

sub VSANVcGetPreferredFaultDomain {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('VSANVcGetPreferredFaultDomain', %args));
   return $response
}

sub VSANIsWitnessVirtualAppliance {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('VSANIsWitnessVirtualAppliance', %args));
   return $response
}

sub VSANVcAddWitnessHost {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('VSANVcAddWitnessHost', %args));
   return $response
}

sub VSANVcGetWitnessHosts {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('VSANVcGetWitnessHosts', %args));
   return $response
}

sub VSANVcRetrieveStretchedClusterVcCapability {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('VSANVcRetrieveStretchedClusterVcCapability', %args));
   return $response
}

sub VSANVcConvertToStretchedCluster {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('VSANVcConvertToStretchedCluster', %args));
   return $response
}

sub VSANVcRemoveWitnessHost {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('VSANVcRemoveWitnessHost', %args));
   return $response
}


1;
##################################################################################

##################################################################################
package VsanVumSystemOperations;
sub VsanHostUpdateFirmware {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('VsanHostUpdateFirmware', %args));
   return $response
}

sub FetchIsoDepotCookie {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('FetchIsoDepotCookie', %args));
   return $response
}

sub GetVsanVumConfig {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('GetVsanVumConfig', %args));
   return $response
}

sub VsanVcUploadReleaseDb {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('VsanVcUploadReleaseDb', %args));
   return $response
}


1;
##################################################################################

##################################################################################
package CnsVolumeManagerOperations;
sub CnsCreateVolume {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('CnsCreateVolume', %args));
   return $response
}

sub CnsAttachVolume {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('CnsAttachVolume', %args));
   return $response
}

sub CnsUpdateVolumeMetadata {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('CnsUpdateVolumeMetadata', %args));
   return $response
}

sub CnsQueryVolume {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('CnsQueryVolume', %args));
   return $response
}

sub CnsDetachVolume {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('CnsDetachVolume', %args));
   return $response
}

sub CnsDeleteVolume {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('CnsDeleteVolume', %args));
   return $response
}


1;
##################################################################################

##################################################################################
package DistributedVirtualPortgroupOperations;
our @ISA = qw(NetworkOperations);
sub ReconfigureDVPortgroup_Task {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('ReconfigureDVPortgroup_Task', %args));
   return $response
}

sub ReconfigureDVPortgroup {
   my ($self, %args) = @_;
   return $self->waitForTask($self->ReconfigureDVPortgroup_Task(%args));
}

sub DVPortgroupRollback_Task {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('DVPortgroupRollback_Task', %args));
   return $response
}

sub DVPortgroupRollback {
   my ($self, %args) = @_;
   return $self->waitForTask($self->DVPortgroupRollback_Task(%args));
}


1;
##################################################################################

##################################################################################
package DistributedVirtualSwitchManagerOperations;
sub QueryAvailableDvsSpec {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('QueryAvailableDvsSpec', %args));
   return $response
}

sub QueryCompatibleHostForNewDvs {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('QueryCompatibleHostForNewDvs', %args));
   return $response
}

sub QueryCompatibleHostForExistingDvs {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('QueryCompatibleHostForExistingDvs', %args));
   return $response
}

sub QueryDvsCompatibleHostSpec {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('QueryDvsCompatibleHostSpec', %args));
   return $response
}

sub QueryDvsFeatureCapability {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('QueryDvsFeatureCapability', %args));
   return $response
}

sub QueryDvsByUuid {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('QueryDvsByUuid', %args));
   return $response
}

sub QueryDvsConfigTarget {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('QueryDvsConfigTarget', %args));
   return $response
}

sub QueryDvsCheckCompatibility {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('QueryDvsCheckCompatibility', %args));
   return $response
}

sub RectifyDvsOnHost_Task {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('RectifyDvsOnHost_Task', %args));
   return $response
}

sub RectifyDvsOnHost {
   my ($self, %args) = @_;
   return $self->waitForTask($self->RectifyDvsOnHost_Task(%args));
}

sub DVSManagerExportEntity_Task {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('DVSManagerExportEntity_Task', %args));
   return $response
}

sub DVSManagerExportEntity {
   my ($self, %args) = @_;
   return $self->waitForTask($self->DVSManagerExportEntity_Task(%args));
}

sub DVSManagerImportEntity_Task {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('DVSManagerImportEntity_Task', %args));
   return $response
}

sub DVSManagerImportEntity {
   my ($self, %args) = @_;
   return $self->waitForTask($self->DVSManagerImportEntity_Task(%args));
}

sub DVSManagerLookupDvPortGroup {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('DVSManagerLookupDvPortGroup', %args));
   return $response
}


1;
##################################################################################

##################################################################################
package VmwareDistributedVirtualSwitchOperations;
our @ISA = qw(DistributedVirtualSwitchOperations);
sub UpdateDVSLacpGroupConfig_Task {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('UpdateDVSLacpGroupConfig_Task', %args));
   return $response
}

sub UpdateDVSLacpGroupConfig {
   my ($self, %args) = @_;
   return $self->waitForTask($self->UpdateDVSLacpGroupConfig_Task(%args));
}


1;
##################################################################################

##################################################################################
package CryptoManagerOperations;
sub AddKey {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('AddKey', %args));
   return $response
}

sub AddKeys {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('AddKeys', %args));
   return $response
}

sub RemoveKey {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('RemoveKey', %args));
   return $response
}

sub RemoveKeys {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('RemoveKeys', %args));
   return $response
}

sub ListKeys {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('ListKeys', %args));
   return $response
}


1;
##################################################################################

##################################################################################
package CryptoManagerHostOperations;
our @ISA = qw(CryptoManagerOperations);
sub CryptoManagerHostPrepare {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('CryptoManagerHostPrepare', %args));
   return $response
}

sub CryptoManagerHostEnable {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('CryptoManagerHostEnable', %args));
   return $response
}

sub ChangeKey_Task {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('ChangeKey_Task', %args));
   return $response
}

sub ChangeKey {
   my ($self, %args) = @_;
   return $self->waitForTask($self->ChangeKey_Task(%args));
}


1;
##################################################################################

##################################################################################
package CryptoManagerHostKMSOperations;
our @ISA = qw(CryptoManagerHostOperations);

1;
##################################################################################

##################################################################################
package CryptoManagerKmipOperations;
our @ISA = qw(CryptoManagerOperations);
sub RegisterKmipServer {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('RegisterKmipServer', %args));
   return $response
}

sub MarkDefault {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('MarkDefault', %args));
   return $response
}

sub UpdateKmipServer {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('UpdateKmipServer', %args));
   return $response
}

sub RemoveKmipServer {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('RemoveKmipServer', %args));
   return $response
}

sub ListKmipServers {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('ListKmipServers', %args));
   return $response
}

sub RetrieveKmipServersStatus_Task {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('RetrieveKmipServersStatus_Task', %args));
   return $response
}

sub RetrieveKmipServersStatus {
   my ($self, %args) = @_;
   return $self->waitForTask($self->RetrieveKmipServersStatus_Task(%args));
}

sub GenerateKey {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('GenerateKey', %args));
   return $response
}

sub RetrieveKmipServerCert {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('RetrieveKmipServerCert', %args));
   return $response
}

sub UploadKmipServerCert {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('UploadKmipServerCert', %args));
   return $response
}

sub GenerateSelfSignedClientCert {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('GenerateSelfSignedClientCert', %args));
   return $response
}

sub GenerateClientCsr {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('GenerateClientCsr', %args));
   return $response
}

sub RetrieveSelfSignedClientCert {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('RetrieveSelfSignedClientCert', %args));
   return $response
}

sub RetrieveClientCsr {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('RetrieveClientCsr', %args));
   return $response
}

sub RetrieveClientCert {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('RetrieveClientCert', %args));
   return $response
}

sub UpdateSelfSignedClientCert {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('UpdateSelfSignedClientCert', %args));
   return $response
}

sub UpdateKmsSignedCsrClientCert {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('UpdateKmsSignedCsrClientCert', %args));
   return $response
}

sub UploadClientCert {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('UploadClientCert', %args));
   return $response
}


1;
##################################################################################

##################################################################################
package EventHistoryCollectorOperations;
our @ISA = qw(HistoryCollectorOperations);
sub ReadNextEvents {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('ReadNextEvents', %args));
   return $response
}

sub ReadPreviousEvents {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('ReadPreviousEvents', %args));
   return $response
}


1;
##################################################################################

##################################################################################
package EventManagerOperations;
sub RetrieveArgumentDescription {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('RetrieveArgumentDescription', %args));
   return $response
}

sub CreateCollectorForEvents {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('CreateCollectorForEvents', %args));
   return $response
}

sub LogUserEvent {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('LogUserEvent', %args));
   return $response
}

sub QueryEvents {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('QueryEvents', %args));
   return $response
}

sub PostEvent {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('PostEvent', %args));
   return $response
}


1;
##################################################################################

##################################################################################
package HostActiveDirectoryAuthenticationOperations;
our @ISA = qw(HostDirectoryStoreOperations);
sub JoinDomain_Task {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('JoinDomain_Task', %args));
   return $response
}

sub JoinDomain {
   my ($self, %args) = @_;
   return $self->waitForTask($self->JoinDomain_Task(%args));
}

sub JoinDomainWithCAM_Task {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('JoinDomainWithCAM_Task', %args));
   return $response
}

sub JoinDomainWithCAM {
   my ($self, %args) = @_;
   return $self->waitForTask($self->JoinDomainWithCAM_Task(%args));
}

sub ImportCertificateForCAM_Task {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('ImportCertificateForCAM_Task', %args));
   return $response
}

sub ImportCertificateForCAM {
   my ($self, %args) = @_;
   return $self->waitForTask($self->ImportCertificateForCAM_Task(%args));
}

sub LeaveCurrentDomain_Task {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('LeaveCurrentDomain_Task', %args));
   return $response
}

sub LeaveCurrentDomain {
   my ($self, %args) = @_;
   return $self->waitForTask($self->LeaveCurrentDomain_Task(%args));
}

sub EnableSmartCardAuthentication {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('EnableSmartCardAuthentication', %args));
   return $response
}

sub InstallSmartCardTrustAnchor {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('InstallSmartCardTrustAnchor', %args));
   return $response
}

sub ReplaceSmartCardTrustAnchors {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('ReplaceSmartCardTrustAnchors', %args));
   return $response
}

sub RemoveSmartCardTrustAnchor {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('RemoveSmartCardTrustAnchor', %args));
   return $response
}

sub RemoveSmartCardTrustAnchorByFingerprint {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('RemoveSmartCardTrustAnchorByFingerprint', %args));
   return $response
}

sub ListSmartCardTrustAnchors {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('ListSmartCardTrustAnchors', %args));
   return $response
}

sub DisableSmartCardAuthentication {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('DisableSmartCardAuthentication', %args));
   return $response
}


1;
##################################################################################

##################################################################################
package HostAuthenticationManagerOperations;

1;
##################################################################################

##################################################################################
package HostAuthenticationStoreOperations;

1;
##################################################################################

##################################################################################
package HostAutoStartManagerOperations;
sub ReconfigureAutostart {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('ReconfigureAutostart', %args));
   return $response
}

sub AutoStartPowerOn {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('AutoStartPowerOn', %args));
   return $response
}

sub AutoStartPowerOff {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('AutoStartPowerOff', %args));
   return $response
}


1;
##################################################################################

##################################################################################
package HostBootDeviceSystemOperations;
sub QueryBootDevices {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('QueryBootDevices', %args));
   return $response
}

sub UpdateBootDevice {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('UpdateBootDevice', %args));
   return $response
}


1;
##################################################################################

##################################################################################
package HostCacheConfigurationManagerOperations;
sub ConfigureHostCache_Task {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('ConfigureHostCache_Task', %args));
   return $response
}

sub ConfigureHostCache {
   my ($self, %args) = @_;
   return $self->waitForTask($self->ConfigureHostCache_Task(%args));
}


1;
##################################################################################

##################################################################################
package HostCertificateManagerOperations;
sub GenerateCertificateSigningRequest {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('GenerateCertificateSigningRequest', %args));
   return $response
}

sub GenerateCertificateSigningRequestByDn {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('GenerateCertificateSigningRequestByDn', %args));
   return $response
}

sub InstallServerCertificate {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('InstallServerCertificate', %args));
   return $response
}

sub ReplaceCACertificatesAndCRLs {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('ReplaceCACertificatesAndCRLs', %args));
   return $response
}

sub ListCACertificates {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('ListCACertificates', %args));
   return $response
}

sub ListCACertificateRevocationLists {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('ListCACertificateRevocationLists', %args));
   return $response
}


1;
##################################################################################

##################################################################################
package HostCpuSchedulerSystemOperations;
our @ISA = qw(ExtensibleManagedObjectOperations);
sub EnableHyperThreading {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('EnableHyperThreading', %args));
   return $response
}

sub DisableHyperThreading {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('DisableHyperThreading', %args));
   return $response
}


1;
##################################################################################

##################################################################################
package HostDatastoreBrowserOperations;
sub SearchDatastore_Task {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('SearchDatastore_Task', %args));
   return $response
}

sub SearchDatastore {
   my ($self, %args) = @_;
   return $self->waitForTask($self->SearchDatastore_Task(%args));
}

sub SearchDatastoreSubFolders_Task {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('SearchDatastoreSubFolders_Task', %args));
   return $response
}

sub SearchDatastoreSubFolders {
   my ($self, %args) = @_;
   return $self->waitForTask($self->SearchDatastoreSubFolders_Task(%args));
}

sub DeleteFile {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('DeleteFile', %args));
   return $response
}


1;
##################################################################################

##################################################################################
package HostDatastoreSystemOperations;
sub UpdateLocalSwapDatastore {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('UpdateLocalSwapDatastore', %args));
   return $response
}

sub QueryAvailableDisksForVmfs {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('QueryAvailableDisksForVmfs', %args));
   return $response
}

sub QueryVmfsDatastoreCreateOptions {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('QueryVmfsDatastoreCreateOptions', %args));
   return $response
}

sub CreateVmfsDatastore {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('CreateVmfsDatastore', %args));
   return $response
}

sub QueryVmfsDatastoreExtendOptions {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('QueryVmfsDatastoreExtendOptions', %args));
   return $response
}

sub QueryVmfsDatastoreExpandOptions {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('QueryVmfsDatastoreExpandOptions', %args));
   return $response
}

sub ExtendVmfsDatastore {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('ExtendVmfsDatastore', %args));
   return $response
}

sub ExpandVmfsDatastore {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('ExpandVmfsDatastore', %args));
   return $response
}

sub CreateNasDatastore {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('CreateNasDatastore', %args));
   return $response
}

sub CreateLocalDatastore {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('CreateLocalDatastore', %args));
   return $response
}

sub CreateVvolDatastore {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('CreateVvolDatastore', %args));
   return $response
}

sub RemoveDatastore {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('RemoveDatastore', %args));
   return $response
}

sub RemoveDatastoreEx_Task {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('RemoveDatastoreEx_Task', %args));
   return $response
}

sub RemoveDatastoreEx {
   my ($self, %args) = @_;
   return $self->waitForTask($self->RemoveDatastoreEx_Task(%args));
}

sub ConfigureDatastorePrincipal {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('ConfigureDatastorePrincipal', %args));
   return $response
}

sub QueryUnresolvedVmfsVolumes {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('QueryUnresolvedVmfsVolumes', %args));
   return $response
}

sub ResignatureUnresolvedVmfsVolume_Task {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('ResignatureUnresolvedVmfsVolume_Task', %args));
   return $response
}

sub ResignatureUnresolvedVmfsVolume {
   my ($self, %args) = @_;
   return $self->waitForTask($self->ResignatureUnresolvedVmfsVolume_Task(%args));
}


1;
##################################################################################

##################################################################################
package HostDateTimeSystemOperations;
sub UpdateDateTimeConfig {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('UpdateDateTimeConfig', %args));
   return $response
}

sub QueryAvailableTimeZones {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('QueryAvailableTimeZones', %args));
   return $response
}

sub QueryDateTime {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('QueryDateTime', %args));
   return $response
}

sub UpdateDateTime {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('UpdateDateTime', %args));
   return $response
}

sub RefreshDateTimeSystem {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('RefreshDateTimeSystem', %args));
   return $response
}


1;
##################################################################################

##################################################################################
package HostDiagnosticSystemOperations;
sub QueryAvailablePartition {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('QueryAvailablePartition', %args));
   return $response
}

sub SelectActivePartition {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('SelectActivePartition', %args));
   return $response
}

sub QueryPartitionCreateOptions {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('QueryPartitionCreateOptions', %args));
   return $response
}

sub QueryPartitionCreateDesc {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('QueryPartitionCreateDesc', %args));
   return $response
}

sub CreateDiagnosticPartition {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('CreateDiagnosticPartition', %args));
   return $response
}


1;
##################################################################################

##################################################################################
package HostDirectoryStoreOperations;
our @ISA = qw(HostAuthenticationStoreOperations);

1;
##################################################################################

##################################################################################
package HostEsxAgentHostManagerOperations;
sub EsxAgentHostManagerUpdateConfig {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('EsxAgentHostManagerUpdateConfig', %args));
   return $response
}


1;
##################################################################################

##################################################################################
package HostFirewallSystemOperations;
our @ISA = qw(ExtensibleManagedObjectOperations);
sub UpdateDefaultPolicy {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('UpdateDefaultPolicy', %args));
   return $response
}

sub EnableRuleset {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('EnableRuleset', %args));
   return $response
}

sub DisableRuleset {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('DisableRuleset', %args));
   return $response
}

sub UpdateRuleset {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('UpdateRuleset', %args));
   return $response
}

sub RefreshFirewall {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('RefreshFirewall', %args));
   return $response
}


1;
##################################################################################

##################################################################################
package HostFirmwareSystemOperations;
sub ResetFirmwareToFactoryDefaults {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('ResetFirmwareToFactoryDefaults', %args));
   return $response
}

sub BackupFirmwareConfiguration {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('BackupFirmwareConfiguration', %args));
   return $response
}

sub QueryFirmwareConfigUploadURL {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('QueryFirmwareConfigUploadURL', %args));
   return $response
}

sub RestoreFirmwareConfiguration {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('RestoreFirmwareConfiguration', %args));
   return $response
}


1;
##################################################################################

##################################################################################
package HostGraphicsManagerOperations;
our @ISA = qw(ExtensibleManagedObjectOperations);
sub RefreshGraphicsManager {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('RefreshGraphicsManager', %args));
   return $response
}

sub IsSharedGraphicsActive {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('IsSharedGraphicsActive', %args));
   return $response
}

sub UpdateGraphicsConfig {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('UpdateGraphicsConfig', %args));
   return $response
}


1;
##################################################################################

##################################################################################
package HostHealthStatusSystemOperations;
sub RefreshHealthStatusSystem {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('RefreshHealthStatusSystem', %args));
   return $response
}

sub ResetSystemHealthInfo {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('ResetSystemHealthInfo', %args));
   return $response
}

sub ClearSystemEventLog {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('ClearSystemEventLog', %args));
   return $response
}

sub FetchSystemEventLog {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('FetchSystemEventLog', %args));
   return $response
}


1;
##################################################################################

##################################################################################
package HostAccessManagerOperations;
sub RetrieveHostAccessControlEntries {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('RetrieveHostAccessControlEntries', %args));
   return $response
}

sub ChangeAccessMode {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('ChangeAccessMode', %args));
   return $response
}

sub QuerySystemUsers {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('QuerySystemUsers', %args));
   return $response
}

sub UpdateSystemUsers {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('UpdateSystemUsers', %args));
   return $response
}

sub QueryLockdownExceptions {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('QueryLockdownExceptions', %args));
   return $response
}

sub UpdateLockdownExceptions {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('UpdateLockdownExceptions', %args));
   return $response
}

sub ChangeLockdownMode {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('ChangeLockdownMode', %args));
   return $response
}


1;
##################################################################################

##################################################################################
package HostImageConfigManagerOperations;
sub HostImageConfigGetAcceptance {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('HostImageConfigGetAcceptance', %args));
   return $response
}

sub HostImageConfigGetProfile {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('HostImageConfigGetProfile', %args));
   return $response
}

sub UpdateHostImageAcceptanceLevel {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('UpdateHostImageAcceptanceLevel', %args));
   return $response
}

sub fetchSoftwarePackages {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('fetchSoftwarePackages', %args));
   return $response
}

sub installDate {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('installDate', %args));
   return $response
}


1;
##################################################################################

##################################################################################
package IscsiManagerOperations;
sub QueryVnicStatus {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('QueryVnicStatus', %args));
   return $response
}

sub QueryPnicStatus {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('QueryPnicStatus', %args));
   return $response
}

sub QueryBoundVnics {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('QueryBoundVnics', %args));
   return $response
}

sub QueryCandidateNics {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('QueryCandidateNics', %args));
   return $response
}

sub BindVnic {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('BindVnic', %args));
   return $response
}

sub UnbindVnic {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('UnbindVnic', %args));
   return $response
}

sub QueryMigrationDependencies {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('QueryMigrationDependencies', %args));
   return $response
}


1;
##################################################################################

##################################################################################
package HostKernelModuleSystemOperations;
sub QueryModules {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('QueryModules', %args));
   return $response
}

sub UpdateModuleOptionString {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('UpdateModuleOptionString', %args));
   return $response
}

sub QueryConfiguredModuleOptionString {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('QueryConfiguredModuleOptionString', %args));
   return $response
}


1;
##################################################################################

##################################################################################
package HostLocalAccountManagerOperations;
sub CreateUser {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('CreateUser', %args));
   return $response
}

sub UpdateUser {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('UpdateUser', %args));
   return $response
}

sub CreateGroup {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('CreateGroup', %args));
   return $response
}

sub RemoveUser {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('RemoveUser', %args));
   return $response
}

sub RemoveGroup {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('RemoveGroup', %args));
   return $response
}

sub AssignUserToGroup {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('AssignUserToGroup', %args));
   return $response
}

sub UnassignUserFromGroup {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('UnassignUserFromGroup', %args));
   return $response
}


1;
##################################################################################

##################################################################################
package HostLocalAuthenticationOperations;
our @ISA = qw(HostAuthenticationStoreOperations);

1;
##################################################################################

##################################################################################
package HostMemorySystemOperations;
our @ISA = qw(ExtensibleManagedObjectOperations);
sub ReconfigureServiceConsoleReservation {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('ReconfigureServiceConsoleReservation', %args));
   return $response
}

sub ReconfigureVirtualMachineReservation {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('ReconfigureVirtualMachineReservation', %args));
   return $response
}


1;
##################################################################################

##################################################################################
package MessageBusProxyOperations;

1;
##################################################################################

##################################################################################
package HostNetworkSystemOperations;
our @ISA = qw(ExtensibleManagedObjectOperations);
sub UpdateNetworkConfig {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('UpdateNetworkConfig', %args));
   return $response
}

sub UpdateDnsConfig {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('UpdateDnsConfig', %args));
   return $response
}

sub UpdateIpRouteConfig {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('UpdateIpRouteConfig', %args));
   return $response
}

sub UpdateConsoleIpRouteConfig {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('UpdateConsoleIpRouteConfig', %args));
   return $response
}

sub UpdateIpRouteTableConfig {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('UpdateIpRouteTableConfig', %args));
   return $response
}

sub AddVirtualSwitch {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('AddVirtualSwitch', %args));
   return $response
}

sub RemoveVirtualSwitch {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('RemoveVirtualSwitch', %args));
   return $response
}

sub UpdateVirtualSwitch {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('UpdateVirtualSwitch', %args));
   return $response
}

sub AddPortGroup {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('AddPortGroup', %args));
   return $response
}

sub RemovePortGroup {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('RemovePortGroup', %args));
   return $response
}

sub UpdatePortGroup {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('UpdatePortGroup', %args));
   return $response
}

sub UpdatePhysicalNicLinkSpeed {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('UpdatePhysicalNicLinkSpeed', %args));
   return $response
}

sub QueryNetworkHint {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('QueryNetworkHint', %args));
   return $response
}

sub AddVirtualNic {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('AddVirtualNic', %args));
   return $response
}

sub RemoveVirtualNic {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('RemoveVirtualNic', %args));
   return $response
}

sub UpdateVirtualNic {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('UpdateVirtualNic', %args));
   return $response
}

sub AddServiceConsoleVirtualNic {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('AddServiceConsoleVirtualNic', %args));
   return $response
}

sub RemoveServiceConsoleVirtualNic {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('RemoveServiceConsoleVirtualNic', %args));
   return $response
}

sub UpdateServiceConsoleVirtualNic {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('UpdateServiceConsoleVirtualNic', %args));
   return $response
}

sub RestartServiceConsoleVirtualNic {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('RestartServiceConsoleVirtualNic', %args));
   return $response
}

sub RefreshNetworkSystem {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('RefreshNetworkSystem', %args));
   return $response
}


1;
##################################################################################

##################################################################################
package HostNvdimmSystemOperations;
sub CreateNvdimmNamespace_Task {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('CreateNvdimmNamespace_Task', %args));
   return $response
}

sub CreateNvdimmNamespace {
   my ($self, %args) = @_;
   return $self->waitForTask($self->CreateNvdimmNamespace_Task(%args));
}

sub CreateNvdimmPMemNamespace_Task {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('CreateNvdimmPMemNamespace_Task', %args));
   return $response
}

sub CreateNvdimmPMemNamespace {
   my ($self, %args) = @_;
   return $self->waitForTask($self->CreateNvdimmPMemNamespace_Task(%args));
}

sub DeleteNvdimmNamespace_Task {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('DeleteNvdimmNamespace_Task', %args));
   return $response
}

sub DeleteNvdimmNamespace {
   my ($self, %args) = @_;
   return $self->waitForTask($self->DeleteNvdimmNamespace_Task(%args));
}

sub DeleteNvdimmBlockNamespaces_Task {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('DeleteNvdimmBlockNamespaces_Task', %args));
   return $response
}

sub DeleteNvdimmBlockNamespaces {
   my ($self, %args) = @_;
   return $self->waitForTask($self->DeleteNvdimmBlockNamespaces_Task(%args));
}


1;
##################################################################################

##################################################################################
package HostPatchManagerOperations;
sub CheckHostPatch_Task {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('CheckHostPatch_Task', %args));
   return $response
}

sub CheckHostPatch {
   my ($self, %args) = @_;
   return $self->waitForTask($self->CheckHostPatch_Task(%args));
}

sub ScanHostPatch_Task {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('ScanHostPatch_Task', %args));
   return $response
}

sub ScanHostPatch {
   my ($self, %args) = @_;
   return $self->waitForTask($self->ScanHostPatch_Task(%args));
}

sub ScanHostPatchV2_Task {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('ScanHostPatchV2_Task', %args));
   return $response
}

sub ScanHostPatchV2 {
   my ($self, %args) = @_;
   return $self->waitForTask($self->ScanHostPatchV2_Task(%args));
}

sub StageHostPatch_Task {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('StageHostPatch_Task', %args));
   return $response
}

sub StageHostPatch {
   my ($self, %args) = @_;
   return $self->waitForTask($self->StageHostPatch_Task(%args));
}

sub InstallHostPatch_Task {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('InstallHostPatch_Task', %args));
   return $response
}

sub InstallHostPatch {
   my ($self, %args) = @_;
   return $self->waitForTask($self->InstallHostPatch_Task(%args));
}

sub InstallHostPatchV2_Task {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('InstallHostPatchV2_Task', %args));
   return $response
}

sub InstallHostPatchV2 {
   my ($self, %args) = @_;
   return $self->waitForTask($self->InstallHostPatchV2_Task(%args));
}

sub UninstallHostPatch_Task {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('UninstallHostPatch_Task', %args));
   return $response
}

sub UninstallHostPatch {
   my ($self, %args) = @_;
   return $self->waitForTask($self->UninstallHostPatch_Task(%args));
}

sub QueryHostPatch_Task {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('QueryHostPatch_Task', %args));
   return $response
}

sub QueryHostPatch {
   my ($self, %args) = @_;
   return $self->waitForTask($self->QueryHostPatch_Task(%args));
}


1;
##################################################################################

##################################################################################
package HostPciPassthruSystemOperations;
our @ISA = qw(ExtensibleManagedObjectOperations);
sub Refresh {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('Refresh', %args));
   return $response
}

sub UpdatePassthruConfig {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('UpdatePassthruConfig', %args));
   return $response
}


1;
##################################################################################

##################################################################################
package HostPowerSystemOperations;
sub ConfigurePowerPolicy {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('ConfigurePowerPolicy', %args));
   return $response
}


1;
##################################################################################

##################################################################################
package HostServiceSystemOperations;
our @ISA = qw(ExtensibleManagedObjectOperations);
sub UpdateServicePolicy {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('UpdateServicePolicy', %args));
   return $response
}

sub StartService {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('StartService', %args));
   return $response
}

sub StopService {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('StopService', %args));
   return $response
}

sub RestartService {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('RestartService', %args));
   return $response
}

sub UninstallService {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('UninstallService', %args));
   return $response
}

sub RefreshServices {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('RefreshServices', %args));
   return $response
}


1;
##################################################################################

##################################################################################
package HostSnmpSystemOperations;
sub ReconfigureSnmpAgent {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('ReconfigureSnmpAgent', %args));
   return $response
}

sub SendTestNotification {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('SendTestNotification', %args));
   return $response
}


1;
##################################################################################

##################################################################################
package HostStorageSystemOperations;
our @ISA = qw(ExtensibleManagedObjectOperations);
sub RetrieveDiskPartitionInfo {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('RetrieveDiskPartitionInfo', %args));
   return $response
}

sub ComputeDiskPartitionInfo {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('ComputeDiskPartitionInfo', %args));
   return $response
}

sub ComputeDiskPartitionInfoForResize {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('ComputeDiskPartitionInfoForResize', %args));
   return $response
}

sub UpdateDiskPartitions {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('UpdateDiskPartitions', %args));
   return $response
}

sub FormatVmfs {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('FormatVmfs', %args));
   return $response
}

sub MountVmfsVolume {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('MountVmfsVolume', %args));
   return $response
}

sub UnmountVmfsVolume {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('UnmountVmfsVolume', %args));
   return $response
}

sub UnmountVmfsVolumeEx_Task {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('UnmountVmfsVolumeEx_Task', %args));
   return $response
}

sub UnmountVmfsVolumeEx {
   my ($self, %args) = @_;
   return $self->waitForTask($self->UnmountVmfsVolumeEx_Task(%args));
}

sub MountVmfsVolumeEx_Task {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('MountVmfsVolumeEx_Task', %args));
   return $response
}

sub MountVmfsVolumeEx {
   my ($self, %args) = @_;
   return $self->waitForTask($self->MountVmfsVolumeEx_Task(%args));
}

sub UnmapVmfsVolumeEx_Task {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('UnmapVmfsVolumeEx_Task', %args));
   return $response
}

sub UnmapVmfsVolumeEx {
   my ($self, %args) = @_;
   return $self->waitForTask($self->UnmapVmfsVolumeEx_Task(%args));
}

sub DeleteVmfsVolumeState {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('DeleteVmfsVolumeState', %args));
   return $response
}

sub RescanVmfs {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('RescanVmfs', %args));
   return $response
}

sub AttachVmfsExtent {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('AttachVmfsExtent', %args));
   return $response
}

sub ExpandVmfsExtent {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('ExpandVmfsExtent', %args));
   return $response
}

sub UpgradeVmfs {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('UpgradeVmfs', %args));
   return $response
}

sub UpgradeVmLayout {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('UpgradeVmLayout', %args));
   return $response
}

sub QueryUnresolvedVmfsVolume {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('QueryUnresolvedVmfsVolume', %args));
   return $response
}

sub ResolveMultipleUnresolvedVmfsVolumes {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('ResolveMultipleUnresolvedVmfsVolumes', %args));
   return $response
}

sub ResolveMultipleUnresolvedVmfsVolumesEx_Task {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('ResolveMultipleUnresolvedVmfsVolumesEx_Task', %args));
   return $response
}

sub ResolveMultipleUnresolvedVmfsVolumesEx {
   my ($self, %args) = @_;
   return $self->waitForTask($self->ResolveMultipleUnresolvedVmfsVolumesEx_Task(%args));
}

sub UnmountForceMountedVmfsVolume {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('UnmountForceMountedVmfsVolume', %args));
   return $response
}

sub RescanHba {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('RescanHba', %args));
   return $response
}

sub RescanAllHba {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('RescanAllHba', %args));
   return $response
}

sub UpdateSoftwareInternetScsiEnabled {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('UpdateSoftwareInternetScsiEnabled', %args));
   return $response
}

sub UpdateInternetScsiDiscoveryProperties {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('UpdateInternetScsiDiscoveryProperties', %args));
   return $response
}

sub UpdateInternetScsiAuthenticationProperties {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('UpdateInternetScsiAuthenticationProperties', %args));
   return $response
}

sub UpdateInternetScsiDigestProperties {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('UpdateInternetScsiDigestProperties', %args));
   return $response
}

sub UpdateInternetScsiAdvancedOptions {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('UpdateInternetScsiAdvancedOptions', %args));
   return $response
}

sub UpdateInternetScsiIPProperties {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('UpdateInternetScsiIPProperties', %args));
   return $response
}

sub UpdateInternetScsiName {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('UpdateInternetScsiName', %args));
   return $response
}

sub UpdateInternetScsiAlias {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('UpdateInternetScsiAlias', %args));
   return $response
}

sub AddInternetScsiSendTargets {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('AddInternetScsiSendTargets', %args));
   return $response
}

sub RemoveInternetScsiSendTargets {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('RemoveInternetScsiSendTargets', %args));
   return $response
}

sub AddInternetScsiStaticTargets {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('AddInternetScsiStaticTargets', %args));
   return $response
}

sub RemoveInternetScsiStaticTargets {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('RemoveInternetScsiStaticTargets', %args));
   return $response
}

sub EnableMultipathPath {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('EnableMultipathPath', %args));
   return $response
}

sub DisableMultipathPath {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('DisableMultipathPath', %args));
   return $response
}

sub SetMultipathLunPolicy {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('SetMultipathLunPolicy', %args));
   return $response
}

sub QueryPathSelectionPolicyOptions {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('QueryPathSelectionPolicyOptions', %args));
   return $response
}

sub QueryStorageArrayTypePolicyOptions {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('QueryStorageArrayTypePolicyOptions', %args));
   return $response
}

sub UpdateScsiLunDisplayName {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('UpdateScsiLunDisplayName', %args));
   return $response
}

sub DetachScsiLun {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('DetachScsiLun', %args));
   return $response
}

sub DetachScsiLunEx_Task {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('DetachScsiLunEx_Task', %args));
   return $response
}

sub DetachScsiLunEx {
   my ($self, %args) = @_;
   return $self->waitForTask($self->DetachScsiLunEx_Task(%args));
}

sub DeleteScsiLunState {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('DeleteScsiLunState', %args));
   return $response
}

sub AttachScsiLun {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('AttachScsiLun', %args));
   return $response
}

sub AttachScsiLunEx_Task {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('AttachScsiLunEx_Task', %args));
   return $response
}

sub AttachScsiLunEx {
   my ($self, %args) = @_;
   return $self->waitForTask($self->AttachScsiLunEx_Task(%args));
}

sub RefreshStorageSystem {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('RefreshStorageSystem', %args));
   return $response
}

sub DiscoverFcoeHbas {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('DiscoverFcoeHbas', %args));
   return $response
}

sub MarkForRemoval {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('MarkForRemoval', %args));
   return $response
}

sub FormatVffs {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('FormatVffs', %args));
   return $response
}

sub ExtendVffs {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('ExtendVffs', %args));
   return $response
}

sub DestroyVffs {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('DestroyVffs', %args));
   return $response
}

sub MountVffsVolume {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('MountVffsVolume', %args));
   return $response
}

sub UnmountVffsVolume {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('UnmountVffsVolume', %args));
   return $response
}

sub DeleteVffsVolumeState {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('DeleteVffsVolumeState', %args));
   return $response
}

sub RescanVffs {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('RescanVffs', %args));
   return $response
}

sub QueryAvailableSsds {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('QueryAvailableSsds', %args));
   return $response
}

sub SetNFSUser {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('SetNFSUser', %args));
   return $response
}

sub ChangeNFSUserPassword {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('ChangeNFSUserPassword', %args));
   return $response
}

sub QueryNFSUser {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('QueryNFSUser', %args));
   return $response
}

sub ClearNFSUser {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('ClearNFSUser', %args));
   return $response
}

sub TurnDiskLocatorLedOn_Task {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('TurnDiskLocatorLedOn_Task', %args));
   return $response
}

sub TurnDiskLocatorLedOn {
   my ($self, %args) = @_;
   return $self->waitForTask($self->TurnDiskLocatorLedOn_Task(%args));
}

sub TurnDiskLocatorLedOff_Task {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('TurnDiskLocatorLedOff_Task', %args));
   return $response
}

sub TurnDiskLocatorLedOff {
   my ($self, %args) = @_;
   return $self->waitForTask($self->TurnDiskLocatorLedOff_Task(%args));
}

sub MarkAsSsd_Task {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('MarkAsSsd_Task', %args));
   return $response
}

sub MarkAsSsd {
   my ($self, %args) = @_;
   return $self->waitForTask($self->MarkAsSsd_Task(%args));
}

sub MarkAsNonSsd_Task {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('MarkAsNonSsd_Task', %args));
   return $response
}

sub MarkAsNonSsd {
   my ($self, %args) = @_;
   return $self->waitForTask($self->MarkAsNonSsd_Task(%args));
}

sub MarkAsLocal_Task {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('MarkAsLocal_Task', %args));
   return $response
}

sub MarkAsLocal {
   my ($self, %args) = @_;
   return $self->waitForTask($self->MarkAsLocal_Task(%args));
}

sub MarkAsNonLocal_Task {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('MarkAsNonLocal_Task', %args));
   return $response
}

sub MarkAsNonLocal {
   my ($self, %args) = @_;
   return $self->waitForTask($self->MarkAsNonLocal_Task(%args));
}

sub UpdateVmfsUnmapPriority {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('UpdateVmfsUnmapPriority', %args));
   return $response
}

sub UpdateVmfsUnmapBandwidth {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('UpdateVmfsUnmapBandwidth', %args));
   return $response
}

sub QueryVmfsConfigOption {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('QueryVmfsConfigOption', %args));
   return $response
}


1;
##################################################################################

##################################################################################
package HostVFlashManagerOperations;
sub ConfigureVFlashResourceEx_Task {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('ConfigureVFlashResourceEx_Task', %args));
   return $response
}

sub ConfigureVFlashResourceEx {
   my ($self, %args) = @_;
   return $self->waitForTask($self->ConfigureVFlashResourceEx_Task(%args));
}

sub HostConfigureVFlashResource {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('HostConfigureVFlashResource', %args));
   return $response
}

sub HostRemoveVFlashResource {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('HostRemoveVFlashResource', %args));
   return $response
}

sub HostConfigVFlashCache {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('HostConfigVFlashCache', %args));
   return $response
}

sub HostGetVFlashModuleDefaultConfig {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('HostGetVFlashModuleDefaultConfig', %args));
   return $response
}


1;
##################################################################################

##################################################################################
package HostVMotionSystemOperations;
our @ISA = qw(ExtensibleManagedObjectOperations);
sub UpdateIpConfig {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('UpdateIpConfig', %args));
   return $response
}

sub SelectVnic {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('SelectVnic', %args));
   return $response
}

sub DeselectVnic {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('DeselectVnic', %args));
   return $response
}


1;
##################################################################################

##################################################################################
package HostVirtualNicManagerOperations;
our @ISA = qw(ExtensibleManagedObjectOperations);
sub QueryNetConfig {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('QueryNetConfig', %args));
   return $response
}

sub SelectVnicForNicType {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('SelectVnicForNicType', %args));
   return $response
}

sub DeselectVnicForNicType {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('DeselectVnicForNicType', %args));
   return $response
}


1;
##################################################################################

##################################################################################
package HostVsanHealthSystemOperations;
sub VsanHostQueryAdvCfg {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('VsanHostQueryAdvCfg', %args));
   return $response
}

sub VsanHostQueryRunIperfClient {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('VsanHostQueryRunIperfClient', %args));
   return $response
}

sub VsanHostQueryObjectHealthSummary {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('VsanHostQueryObjectHealthSummary', %args));
   return $response
}

sub VsanStopProactiveRebalance {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('VsanStopProactiveRebalance', %args));
   return $response
}

sub VsanHostQueryFileServiceHealthSummary {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('VsanHostQueryFileServiceHealthSummary', %args));
   return $response
}

sub VsanHostClomdLiveness {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('VsanHostClomdLiveness', %args));
   return $response
}

sub VsanHostRepairImmediateObjects {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('VsanHostRepairImmediateObjects', %args));
   return $response
}

sub VsanHostQueryVerifyNetworkSettings {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('VsanHostQueryVerifyNetworkSettings', %args));
   return $response
}

sub VsanHostCleanupVmdkLoadTest {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('VsanHostCleanupVmdkLoadTest', %args));
   return $response
}

sub VsanStartProactiveRebalance {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('VsanStartProactiveRebalance', %args));
   return $response
}

sub VsanHostQueryEncryptionHealthSummary {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('VsanHostQueryEncryptionHealthSummary', %args));
   return $response
}

sub VsanFlashScsiControllerFirmware_Task {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('VsanFlashScsiControllerFirmware_Task', %args));
   return $response
}

sub VsanFlashScsiControllerFirmware {
   my ($self, %args) = @_;
   return $self->waitForTask($self->VsanFlashScsiControllerFirmware_Task(%args));
}

sub VsanQueryHostEMMState {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('VsanQueryHostEMMState', %args));
   return $response
}

sub VsanWaitForVsanHealthGenerationIdChange {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('VsanWaitForVsanHealthGenerationIdChange', %args));
   return $response
}

sub VsanHostQueryHealthSystemVersion {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('VsanHostQueryHealthSystemVersion', %args));
   return $response
}

sub VsanGetHclInfo {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('VsanGetHclInfo', %args));
   return $response
}

sub VsanHostRunVmdkLoadTest {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('VsanHostRunVmdkLoadTest', %args));
   return $response
}

sub VsanHostQuerySmartStats {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('VsanHostQuerySmartStats', %args));
   return $response
}

sub VsanHostPrepareVmdkLoadTest {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('VsanHostPrepareVmdkLoadTest', %args));
   return $response
}

sub VsanHostQueryRunIperfServer {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('VsanHostQueryRunIperfServer', %args));
   return $response
}

sub VsanGetProactiveRebalanceInfo {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('VsanGetProactiveRebalanceInfo', %args));
   return $response
}

sub VsanHostQueryPhysicalDiskHealthSummary {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('VsanHostQueryPhysicalDiskHealthSummary', %args));
   return $response
}

sub VsanHostQueryHostInfoByUuids {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('VsanHostQueryHostInfoByUuids', %args));
   return $response
}

sub VsanHostCreateVmHealthTest {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('VsanHostCreateVmHealthTest', %args));
   return $response
}

sub VsanHostQueryCheckLimits {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('VsanHostQueryCheckLimits', %args));
   return $response
}


1;
##################################################################################

##################################################################################
package HostVsanInternalSystemOperations;
sub QueryCmmds {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('QueryCmmds', %args));
   return $response
}

sub QueryPhysicalVsanDisks {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('QueryPhysicalVsanDisks', %args));
   return $response
}

sub QueryVsanObjects {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('QueryVsanObjects', %args));
   return $response
}

sub QueryObjectsOnPhysicalVsanDisk {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('QueryObjectsOnPhysicalVsanDisk', %args));
   return $response
}

sub AbdicateDomOwnership {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('AbdicateDomOwnership', %args));
   return $response
}

sub QueryVsanStatistics {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('QueryVsanStatistics', %args));
   return $response
}

sub ReconfigureDomObject {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('ReconfigureDomObject', %args));
   return $response
}

sub QuerySyncingVsanObjects {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('QuerySyncingVsanObjects', %args));
   return $response
}

sub RunVsanPhysicalDiskDiagnostics {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('RunVsanPhysicalDiskDiagnostics', %args));
   return $response
}

sub GetVsanObjExtAttrs {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('GetVsanObjExtAttrs', %args));
   return $response
}

sub ReconfigurationSatisfiable {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('ReconfigurationSatisfiable', %args));
   return $response
}

sub CanProvisionObjects {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('CanProvisionObjects', %args));
   return $response
}

sub DeleteVsanObjects {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('DeleteVsanObjects', %args));
   return $response
}

sub UpgradeVsanObjects {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('UpgradeVsanObjects', %args));
   return $response
}

sub QueryVsanObjectUuidsByFilter {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('QueryVsanObjectUuidsByFilter', %args));
   return $response
}


1;
##################################################################################

##################################################################################
package HostVsanSystemOperations;
sub QueryDisksForVsan {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('QueryDisksForVsan', %args));
   return $response
}

sub AddDisks_Task {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('AddDisks_Task', %args));
   return $response
}

sub AddDisks {
   my ($self, %args) = @_;
   return $self->waitForTask($self->AddDisks_Task(%args));
}

sub InitializeDisks_Task {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('InitializeDisks_Task', %args));
   return $response
}

sub InitializeDisks {
   my ($self, %args) = @_;
   return $self->waitForTask($self->InitializeDisks_Task(%args));
}

sub RemoveDisk_Task {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('RemoveDisk_Task', %args));
   return $response
}

sub RemoveDisk {
   my ($self, %args) = @_;
   return $self->waitForTask($self->RemoveDisk_Task(%args));
}

sub RemoveDiskMapping_Task {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('RemoveDiskMapping_Task', %args));
   return $response
}

sub RemoveDiskMapping {
   my ($self, %args) = @_;
   return $self->waitForTask($self->RemoveDiskMapping_Task(%args));
}

sub UnmountDiskMapping_Task {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('UnmountDiskMapping_Task', %args));
   return $response
}

sub UnmountDiskMapping {
   my ($self, %args) = @_;
   return $self->waitForTask($self->UnmountDiskMapping_Task(%args));
}

sub UpdateVsan_Task {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('UpdateVsan_Task', %args));
   return $response
}

sub UpdateVsan {
   my ($self, %args) = @_;
   return $self->waitForTask($self->UpdateVsan_Task(%args));
}

sub QueryHostStatus {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('QueryHostStatus', %args));
   return $response
}

sub EvacuateVsanNode_Task {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('EvacuateVsanNode_Task', %args));
   return $response
}

sub EvacuateVsanNode {
   my ($self, %args) = @_;
   return $self->waitForTask($self->EvacuateVsanNode_Task(%args));
}

sub RecommissionVsanNode_Task {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('RecommissionVsanNode_Task', %args));
   return $response
}

sub RecommissionVsanNode {
   my ($self, %args) = @_;
   return $self->waitForTask($self->RecommissionVsanNode_Task(%args));
}


1;
##################################################################################

##################################################################################
package VsanSystemExOperations;
sub VsanUnmountDiskMappingEx {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('VsanUnmountDiskMappingEx', %args));
   return $response
}

sub VsanQuerySyncingVsanObjects {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('VsanQuerySyncingVsanObjects', %args));
   return $response
}

sub VsanQueryHostDrsStats {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('VsanQueryHostDrsStats', %args));
   return $response
}

sub VsanQueryWhatIfEvacuationResult {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('VsanQueryWhatIfEvacuationResult', %args));
   return $response
}

sub VsanHostGetRuntimeStats {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('VsanHostGetRuntimeStats', %args));
   return $response
}

sub VsanGetAboutInfoEx {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('VsanGetAboutInfoEx', %args));
   return $response
}


1;
##################################################################################

##################################################################################
package VsanUpdateManagerOperations;
sub VsanVibInstall_Task {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('VsanVibInstall_Task', %args));
   return $response
}

sub VsanVibInstall {
   my ($self, %args) = @_;
   return $self->waitForTask($self->VsanVibInstall_Task(%args));
}

sub VsanVibInstallPreflightCheck {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('VsanVibInstallPreflightCheck', %args));
   return $response
}

sub VsanVibScan {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('VsanVibScan', %args));
   return $response
}


1;
##################################################################################

##################################################################################
package VsanVcsaDeployerSystemOperations;
sub VsanPostConfigForVcsa {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('VsanPostConfigForVcsa', %args));
   return $response
}

sub VsanVcsaGetBootstrapProgress {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('VsanVcsaGetBootstrapProgress', %args));
   return $response
}

sub VsanPrepareVsanForVcsa {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('VsanPrepareVsanForVcsa', %args));
   return $response
}


1;
##################################################################################

##################################################################################
package OptionManagerOperations;
sub QueryOptions {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('QueryOptions', %args));
   return $response
}

sub UpdateOptions {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('UpdateOptions', %args));
   return $response
}


1;
##################################################################################

##################################################################################
package ProfileComplianceManagerOperations;
sub CheckCompliance_Task {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('CheckCompliance_Task', %args));
   return $response
}

sub CheckCompliance {
   my ($self, %args) = @_;
   return $self->waitForTask($self->CheckCompliance_Task(%args));
}

sub QueryComplianceStatus {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('QueryComplianceStatus', %args));
   return $response
}

sub ClearComplianceStatus {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('ClearComplianceStatus', %args));
   return $response
}

sub QueryExpressionMetadata {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('QueryExpressionMetadata', %args));
   return $response
}


1;
##################################################################################

##################################################################################
package ProfileOperations;
sub RetrieveDescription {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('RetrieveDescription', %args));
   return $response
}

sub DestroyProfile {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('DestroyProfile', %args));
   return $response
}

sub AssociateProfile {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('AssociateProfile', %args));
   return $response
}

sub DissociateProfile {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('DissociateProfile', %args));
   return $response
}

sub CheckProfileCompliance_Task {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('CheckProfileCompliance_Task', %args));
   return $response
}

sub CheckProfileCompliance {
   my ($self, %args) = @_;
   return $self->waitForTask($self->CheckProfileCompliance_Task(%args));
}

sub ExportProfile {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('ExportProfile', %args));
   return $response
}


1;
##################################################################################

##################################################################################
package ProfileManagerOperations;
sub CreateProfile {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('CreateProfile', %args));
   return $response
}

sub QueryPolicyMetadata {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('QueryPolicyMetadata', %args));
   return $response
}

sub FindAssociatedProfile {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('FindAssociatedProfile', %args));
   return $response
}


1;
##################################################################################

##################################################################################
package ClusterProfileOperations;
our @ISA = qw(ProfileOperations);
sub UpdateClusterProfile {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('UpdateClusterProfile', %args));
   return $response
}


1;
##################################################################################

##################################################################################
package ClusterProfileManagerOperations;
our @ISA = qw(ProfileManagerOperations);

1;
##################################################################################

##################################################################################
package HostProfileOperations;
our @ISA = qw(ProfileOperations);
sub HostProfileResetValidationState {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('HostProfileResetValidationState', %args));
   return $response
}

sub UpdateReferenceHost {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('UpdateReferenceHost', %args));
   return $response
}

sub UpdateHostProfile {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('UpdateHostProfile', %args));
   return $response
}

sub ExecuteHostProfile {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('ExecuteHostProfile', %args));
   return $response
}


1;
##################################################################################

##################################################################################
package HostSpecificationManagerOperations;
sub UpdateHostSpecification {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('UpdateHostSpecification', %args));
   return $response
}

sub UpdateHostSubSpecification {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('UpdateHostSubSpecification', %args));
   return $response
}

sub RetrieveHostSpecification {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('RetrieveHostSpecification', %args));
   return $response
}

sub DeleteHostSubSpecification {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('DeleteHostSubSpecification', %args));
   return $response
}

sub DeleteHostSpecification {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('DeleteHostSpecification', %args));
   return $response
}

sub HostSpecGetUpdatedHosts {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('HostSpecGetUpdatedHosts', %args));
   return $response
}


1;
##################################################################################

##################################################################################
package HostProfileManagerOperations;
our @ISA = qw(ProfileManagerOperations);
sub ApplyHostConfig_Task {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('ApplyHostConfig_Task', %args));
   return $response
}

sub ApplyHostConfig {
   my ($self, %args) = @_;
   return $self->waitForTask($self->ApplyHostConfig_Task(%args));
}

sub GenerateConfigTaskList {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('GenerateConfigTaskList', %args));
   return $response
}

sub GenerateHostProfileTaskList_Task {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('GenerateHostProfileTaskList_Task', %args));
   return $response
}

sub GenerateHostProfileTaskList {
   my ($self, %args) = @_;
   return $self->waitForTask($self->GenerateHostProfileTaskList_Task(%args));
}

sub QueryHostProfileMetadata {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('QueryHostProfileMetadata', %args));
   return $response
}

sub QueryProfileStructure {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('QueryProfileStructure', %args));
   return $response
}

sub CreateDefaultProfile {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('CreateDefaultProfile', %args));
   return $response
}

sub UpdateAnswerFile_Task {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('UpdateAnswerFile_Task', %args));
   return $response
}

sub UpdateAnswerFile {
   my ($self, %args) = @_;
   return $self->waitForTask($self->UpdateAnswerFile_Task(%args));
}

sub RetrieveAnswerFile {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('RetrieveAnswerFile', %args));
   return $response
}

sub RetrieveAnswerFileForProfile {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('RetrieveAnswerFileForProfile', %args));
   return $response
}

sub ExportAnswerFile_Task {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('ExportAnswerFile_Task', %args));
   return $response
}

sub ExportAnswerFile {
   my ($self, %args) = @_;
   return $self->waitForTask($self->ExportAnswerFile_Task(%args));
}

sub CheckAnswerFileStatus_Task {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('CheckAnswerFileStatus_Task', %args));
   return $response
}

sub CheckAnswerFileStatus {
   my ($self, %args) = @_;
   return $self->waitForTask($self->CheckAnswerFileStatus_Task(%args));
}

sub QueryAnswerFileStatus {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('QueryAnswerFileStatus', %args));
   return $response
}

sub UpdateHostCustomizations_Task {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('UpdateHostCustomizations_Task', %args));
   return $response
}

sub UpdateHostCustomizations {
   my ($self, %args) = @_;
   return $self->waitForTask($self->UpdateHostCustomizations_Task(%args));
}

sub RetrieveHostCustomizations {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('RetrieveHostCustomizations', %args));
   return $response
}

sub RetrieveHostCustomizationsForProfile {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('RetrieveHostCustomizationsForProfile', %args));
   return $response
}

sub GenerateHostConfigTaskSpec_Task {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('GenerateHostConfigTaskSpec_Task', %args));
   return $response
}

sub GenerateHostConfigTaskSpec {
   my ($self, %args) = @_;
   return $self->waitForTask($self->GenerateHostConfigTaskSpec_Task(%args));
}

sub ApplyEntitiesConfig_Task {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('ApplyEntitiesConfig_Task', %args));
   return $response
}

sub ApplyEntitiesConfig {
   my ($self, %args) = @_;
   return $self->waitForTask($self->ApplyEntitiesConfig_Task(%args));
}

sub ValidateHostProfileComposition_Task {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('ValidateHostProfileComposition_Task', %args));
   return $response
}

sub ValidateHostProfileComposition {
   my ($self, %args) = @_;
   return $self->waitForTask($self->ValidateHostProfileComposition_Task(%args));
}

sub CompositeHostProfile_Task {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('CompositeHostProfile_Task', %args));
   return $response
}

sub CompositeHostProfile {
   my ($self, %args) = @_;
   return $self->waitForTask($self->CompositeHostProfile_Task(%args));
}


1;
##################################################################################

##################################################################################
package ScheduledTaskOperations;
our @ISA = qw(ExtensibleManagedObjectOperations);
sub RemoveScheduledTask {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('RemoveScheduledTask', %args));
   return $response
}

sub ReconfigureScheduledTask {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('ReconfigureScheduledTask', %args));
   return $response
}

sub RunScheduledTask {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('RunScheduledTask', %args));
   return $response
}


1;
##################################################################################

##################################################################################
package ScheduledTaskManagerOperations;
sub CreateScheduledTask {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('CreateScheduledTask', %args));
   return $response
}

sub RetrieveEntityScheduledTask {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('RetrieveEntityScheduledTask', %args));
   return $response
}

sub CreateObjectScheduledTask {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('CreateObjectScheduledTask', %args));
   return $response
}

sub RetrieveObjectScheduledTask {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('RetrieveObjectScheduledTask', %args));
   return $response
}


1;
##################################################################################

##################################################################################
package FailoverClusterConfiguratorOperations;
sub prepareVcha_Task {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('prepareVcha_Task', %args));
   return $response
}

sub prepareVcha {
   my ($self, %args) = @_;
   return $self->waitForTask($self->prepareVcha_Task(%args));
}

sub deployVcha_Task {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('deployVcha_Task', %args));
   return $response
}

sub deployVcha {
   my ($self, %args) = @_;
   return $self->waitForTask($self->deployVcha_Task(%args));
}

sub configureVcha_Task {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('configureVcha_Task', %args));
   return $response
}

sub configureVcha {
   my ($self, %args) = @_;
   return $self->waitForTask($self->configureVcha_Task(%args));
}

sub createPassiveNode_Task {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('createPassiveNode_Task', %args));
   return $response
}

sub createPassiveNode {
   my ($self, %args) = @_;
   return $self->waitForTask($self->createPassiveNode_Task(%args));
}

sub createWitnessNode_Task {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('createWitnessNode_Task', %args));
   return $response
}

sub createWitnessNode {
   my ($self, %args) = @_;
   return $self->waitForTask($self->createWitnessNode_Task(%args));
}

sub getVchaConfig {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('getVchaConfig', %args));
   return $response
}

sub destroyVcha_Task {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('destroyVcha_Task', %args));
   return $response
}

sub destroyVcha {
   my ($self, %args) = @_;
   return $self->waitForTask($self->destroyVcha_Task(%args));
}


1;
##################################################################################

##################################################################################
package FailoverClusterManagerOperations;
sub setClusterMode_Task {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('setClusterMode_Task', %args));
   return $response
}

sub setClusterMode {
   my ($self, %args) = @_;
   return $self->waitForTask($self->setClusterMode_Task(%args));
}

sub getClusterMode {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('getClusterMode', %args));
   return $response
}

sub GetVchaClusterHealth {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('GetVchaClusterHealth', %args));
   return $response
}

sub initiateFailover_Task {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('initiateFailover_Task', %args));
   return $response
}

sub initiateFailover {
   my ($self, %args) = @_;
   return $self->waitForTask($self->initiateFailover_Task(%args));
}


1;
##################################################################################

##################################################################################
package ContainerViewOperations;
our @ISA = qw(ManagedObjectViewOperations);

1;
##################################################################################

##################################################################################
package InventoryViewOperations;
our @ISA = qw(ManagedObjectViewOperations);
sub OpenInventoryViewFolder {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('OpenInventoryViewFolder', %args));
   return $response
}

sub CloseInventoryViewFolder {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('CloseInventoryViewFolder', %args));
   return $response
}


1;
##################################################################################

##################################################################################
package ListViewOperations;
our @ISA = qw(ManagedObjectViewOperations);
sub ModifyListView {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('ModifyListView', %args));
   return $response
}

sub ResetListView {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('ResetListView', %args));
   return $response
}

sub ResetListViewFromView {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('ResetListViewFromView', %args));
   return $response
}


1;
##################################################################################

##################################################################################
package ManagedObjectViewOperations;
our @ISA = qw(ViewOperations);

1;
##################################################################################

##################################################################################
package ViewOperations;
sub DestroyView {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('DestroyView', %args));
   return $response
}


1;
##################################################################################

##################################################################################
package ViewManagerOperations;
sub CreateInventoryView {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('CreateInventoryView', %args));
   return $response
}

sub CreateContainerView {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('CreateContainerView', %args));
   return $response
}

sub CreateListView {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('CreateListView', %args));
   return $response
}

sub CreateListViewFromView {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('CreateListViewFromView', %args));
   return $response
}


1;
##################################################################################

##################################################################################
package VirtualMachineSnapshotOperations;
our @ISA = qw(ExtensibleManagedObjectOperations);
sub RevertToSnapshot_Task {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('RevertToSnapshot_Task', %args));
   return $response
}

sub RevertToSnapshot {
   my ($self, %args) = @_;
   return $self->waitForTask($self->RevertToSnapshot_Task(%args));
}

sub RemoveSnapshot_Task {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('RemoveSnapshot_Task', %args));
   return $response
}

sub RemoveSnapshot {
   my ($self, %args) = @_;
   return $self->waitForTask($self->RemoveSnapshot_Task(%args));
}

sub RenameSnapshot {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('RenameSnapshot', %args));
   return $response
}

sub ExportSnapshot {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('ExportSnapshot', %args));
   return $response
}


1;
##################################################################################

##################################################################################
package VirtualMachineCompatibilityCheckerOperations;
sub CheckCompatibility_Task {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('CheckCompatibility_Task', %args));
   return $response
}

sub CheckCompatibility {
   my ($self, %args) = @_;
   return $self->waitForTask($self->CheckCompatibility_Task(%args));
}

sub CheckVmConfig_Task {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('CheckVmConfig_Task', %args));
   return $response
}

sub CheckVmConfig {
   my ($self, %args) = @_;
   return $self->waitForTask($self->CheckVmConfig_Task(%args));
}

sub CheckPowerOn_Task {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('CheckPowerOn_Task', %args));
   return $response
}

sub CheckPowerOn {
   my ($self, %args) = @_;
   return $self->waitForTask($self->CheckPowerOn_Task(%args));
}


1;
##################################################################################

##################################################################################
package VirtualMachineProvisioningCheckerOperations;
sub QueryVMotionCompatibilityEx_Task {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('QueryVMotionCompatibilityEx_Task', %args));
   return $response
}

sub QueryVMotionCompatibilityEx {
   my ($self, %args) = @_;
   return $self->waitForTask($self->QueryVMotionCompatibilityEx_Task(%args));
}

sub CheckMigrate_Task {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('CheckMigrate_Task', %args));
   return $response
}

sub CheckMigrate {
   my ($self, %args) = @_;
   return $self->waitForTask($self->CheckMigrate_Task(%args));
}

sub CheckRelocate_Task {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('CheckRelocate_Task', %args));
   return $response
}

sub CheckRelocate {
   my ($self, %args) = @_;
   return $self->waitForTask($self->CheckRelocate_Task(%args));
}

sub CheckClone_Task {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('CheckClone_Task', %args));
   return $response
}

sub CheckClone {
   my ($self, %args) = @_;
   return $self->waitForTask($self->CheckClone_Task(%args));
}

sub CheckInstantClone_Task {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('CheckInstantClone_Task', %args));
   return $response
}

sub CheckInstantClone {
   my ($self, %args) = @_;
   return $self->waitForTask($self->CheckInstantClone_Task(%args));
}


1;
##################################################################################

##################################################################################
package GuestAliasManagerOperations;
sub AddGuestAlias {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('AddGuestAlias', %args));
   return $response
}

sub RemoveGuestAlias {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('RemoveGuestAlias', %args));
   return $response
}

sub RemoveGuestAliasByCert {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('RemoveGuestAliasByCert', %args));
   return $response
}

sub ListGuestAliases {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('ListGuestAliases', %args));
   return $response
}

sub ListGuestMappedAliases {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('ListGuestMappedAliases', %args));
   return $response
}


1;
##################################################################################

##################################################################################
package GuestAuthManagerOperations;
sub ValidateCredentialsInGuest {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('ValidateCredentialsInGuest', %args));
   return $response
}

sub AcquireCredentialsInGuest {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('AcquireCredentialsInGuest', %args));
   return $response
}

sub ReleaseCredentialsInGuest {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('ReleaseCredentialsInGuest', %args));
   return $response
}


1;
##################################################################################

##################################################################################
package GuestFileManagerOperations;
sub MakeDirectoryInGuest {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('MakeDirectoryInGuest', %args));
   return $response
}

sub DeleteFileInGuest {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('DeleteFileInGuest', %args));
   return $response
}

sub DeleteDirectoryInGuest {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('DeleteDirectoryInGuest', %args));
   return $response
}

sub MoveDirectoryInGuest {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('MoveDirectoryInGuest', %args));
   return $response
}

sub MoveFileInGuest {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('MoveFileInGuest', %args));
   return $response
}

sub CreateTemporaryFileInGuest {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('CreateTemporaryFileInGuest', %args));
   return $response
}

sub CreateTemporaryDirectoryInGuest {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('CreateTemporaryDirectoryInGuest', %args));
   return $response
}

sub ListFilesInGuest {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('ListFilesInGuest', %args));
   return $response
}

sub ChangeFileAttributesInGuest {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('ChangeFileAttributesInGuest', %args));
   return $response
}

sub InitiateFileTransferFromGuest {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('InitiateFileTransferFromGuest', %args));
   return $response
}

sub InitiateFileTransferToGuest {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('InitiateFileTransferToGuest', %args));
   return $response
}


1;
##################################################################################

##################################################################################
package GuestOperationsManagerOperations;

1;
##################################################################################

##################################################################################
package GuestProcessManagerOperations;
sub StartProgramInGuest {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('StartProgramInGuest', %args));
   return $response
}

sub ListProcessesInGuest {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('ListProcessesInGuest', %args));
   return $response
}

sub TerminateProcessInGuest {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('TerminateProcessInGuest', %args));
   return $response
}

sub ReadEnvironmentVariableInGuest {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('ReadEnvironmentVariableInGuest', %args));
   return $response
}


1;
##################################################################################

##################################################################################
package GuestWindowsRegistryManagerOperations;
sub CreateRegistryKeyInGuest {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('CreateRegistryKeyInGuest', %args));
   return $response
}

sub ListRegistryKeysInGuest {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('ListRegistryKeysInGuest', %args));
   return $response
}

sub DeleteRegistryKeyInGuest {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('DeleteRegistryKeyInGuest', %args));
   return $response
}

sub SetRegistryValueInGuest {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('SetRegistryValueInGuest', %args));
   return $response
}

sub ListRegistryValuesInGuest {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('ListRegistryValuesInGuest', %args));
   return $response
}

sub DeleteRegistryValueInGuest {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('DeleteRegistryValueInGuest', %args));
   return $response
}


1;
##################################################################################

##################################################################################
package VsanFileServiceSystemOperations;
sub VsanDownloadFileServiceOvf {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('VsanDownloadFileServiceOvf', %args));
   return $response
}

sub VsanClusterCreateFsDomain {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('VsanClusterCreateFsDomain', %args));
   return $response
}

sub VsanPerformFileServiceEnablePreflightCheck {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('VsanPerformFileServiceEnablePreflightCheck', %args));
   return $response
}

sub VsanCreateFileShare {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('VsanCreateFileShare', %args));
   return $response
}

sub VsanClusterQueryFsDomains {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('VsanClusterQueryFsDomains', %args));
   return $response
}

sub VsanQueryFileServiceOvfs {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('VsanQueryFileServiceOvfs', %args));
   return $response
}

sub VsanReconfigureFileShare {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('VsanReconfigureFileShare', %args));
   return $response
}

sub VsanClusterReconfigureFsDomain {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('VsanClusterReconfigureFsDomain', %args));
   return $response
}

sub VsanFindOvfDownloadUrl {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('VsanFindOvfDownloadUrl', %args));
   return $response
}

sub VsanClusterQueryFileShares {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('VsanClusterQueryFileShares', %args));
   return $response
}

sub VsanClusterRemoveShare {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('VsanClusterRemoveShare', %args));
   return $response
}

sub VsanClusterRemoveFsDomain {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('VsanClusterRemoveFsDomain', %args));
   return $response
}

sub VsanUpgradeFsvm {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('VsanUpgradeFsvm', %args));
   return $response
}


1;
##################################################################################

##################################################################################
package VsanHostVdsSystemOperations;
sub VsanCompleteMigrateVmsToVds {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('VsanCompleteMigrateVmsToVds', %args));
   return $response
}

sub VsanMigrateVmsToVds {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('VsanMigrateVmsToVds', %args));
   return $response
}


1;
##################################################################################

##################################################################################
package VsanResourceCheckSystemOperations;
sub VsanGetResourceCheckStatus {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('VsanGetResourceCheckStatus', %args));
   return $response
}

sub VsanPerformResourceCheck {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('VsanPerformResourceCheck', %args));
   return $response
}

sub VsanHostCancelResourceCheck {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('VsanHostCancelResourceCheck', %args));
   return $response
}

sub VsanHostPerformResourceCheck {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('VsanHostPerformResourceCheck', %args));
   return $response
}


1;
##################################################################################

##################################################################################
package VsanVdsSystemOperations;
sub VsanVdsMigrateVss {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('VsanVdsMigrateVss', %args));
   return $response
}

sub VsanVdsGetMigrationPlan {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('VsanVdsGetMigrationPlan', %args));
   return $response
}

sub VsanVssMigrateVds {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('VsanVssMigrateVds', %args));
   return $response
}

sub VsanRollbackVdsToVss {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('VsanRollbackVdsToVss', %args));
   return $response
}


1;
##################################################################################

##################################################################################
package VStorageObjectManagerBaseOperations;

1;
##################################################################################

##################################################################################
package HostVStorageObjectManagerOperations;
our @ISA = qw(VStorageObjectManagerBaseOperations);
sub HostCreateDisk_Task {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('HostCreateDisk_Task', %args));
   return $response
}

sub HostCreateDisk {
   my ($self, %args) = @_;
   return $self->waitForTask($self->HostCreateDisk_Task(%args));
}

sub HostRegisterDisk {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('HostRegisterDisk', %args));
   return $response
}

sub HostExtendDisk_Task {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('HostExtendDisk_Task', %args));
   return $response
}

sub HostExtendDisk {
   my ($self, %args) = @_;
   return $self->waitForTask($self->HostExtendDisk_Task(%args));
}

sub HostInflateDisk_Task {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('HostInflateDisk_Task', %args));
   return $response
}

sub HostInflateDisk {
   my ($self, %args) = @_;
   return $self->waitForTask($self->HostInflateDisk_Task(%args));
}

sub HostRenameVStorageObject {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('HostRenameVStorageObject', %args));
   return $response
}

sub HostRetrieveVStorageInfrastructureObjectPolicy {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('HostRetrieveVStorageInfrastructureObjectPolicy', %args));
   return $response
}

sub HostDeleteVStorageObject_Task {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('HostDeleteVStorageObject_Task', %args));
   return $response
}

sub HostDeleteVStorageObject {
   my ($self, %args) = @_;
   return $self->waitForTask($self->HostDeleteVStorageObject_Task(%args));
}

sub HostRetrieveVStorageObject {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('HostRetrieveVStorageObject', %args));
   return $response
}

sub HostRetrieveVStorageObjectState {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('HostRetrieveVStorageObjectState', %args));
   return $response
}

sub HostListVStorageObject {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('HostListVStorageObject', %args));
   return $response
}

sub HostCloneVStorageObject_Task {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('HostCloneVStorageObject_Task', %args));
   return $response
}

sub HostCloneVStorageObject {
   my ($self, %args) = @_;
   return $self->waitForTask($self->HostCloneVStorageObject_Task(%args));
}

sub HostRelocateVStorageObject_Task {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('HostRelocateVStorageObject_Task', %args));
   return $response
}

sub HostRelocateVStorageObject {
   my ($self, %args) = @_;
   return $self->waitForTask($self->HostRelocateVStorageObject_Task(%args));
}

sub HostSetVStorageObjectControlFlags {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('HostSetVStorageObjectControlFlags', %args));
   return $response
}

sub HostClearVStorageObjectControlFlags {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('HostClearVStorageObjectControlFlags', %args));
   return $response
}

sub HostReconcileDatastoreInventory_Task {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('HostReconcileDatastoreInventory_Task', %args));
   return $response
}

sub HostReconcileDatastoreInventory {
   my ($self, %args) = @_;
   return $self->waitForTask($self->HostReconcileDatastoreInventory_Task(%args));
}

sub HostScheduleReconcileDatastoreInventory {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('HostScheduleReconcileDatastoreInventory', %args));
   return $response
}

sub HostVStorageObjectCreateSnapshot_Task {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('HostVStorageObjectCreateSnapshot_Task', %args));
   return $response
}

sub HostVStorageObjectCreateSnapshot {
   my ($self, %args) = @_;
   return $self->waitForTask($self->HostVStorageObjectCreateSnapshot_Task(%args));
}

sub HostVStorageObjectDeleteSnapshot_Task {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('HostVStorageObjectDeleteSnapshot_Task', %args));
   return $response
}

sub HostVStorageObjectDeleteSnapshot {
   my ($self, %args) = @_;
   return $self->waitForTask($self->HostVStorageObjectDeleteSnapshot_Task(%args));
}

sub HostVStorageObjectRetrieveSnapshotInfo {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('HostVStorageObjectRetrieveSnapshotInfo', %args));
   return $response
}

sub HostVStorageObjectCreateDiskFromSnapshot_Task {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('HostVStorageObjectCreateDiskFromSnapshot_Task', %args));
   return $response
}

sub HostVStorageObjectCreateDiskFromSnapshot {
   my ($self, %args) = @_;
   return $self->waitForTask($self->HostVStorageObjectCreateDiskFromSnapshot_Task(%args));
}

sub HostVStorageObjectRevert_Task {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('HostVStorageObjectRevert_Task', %args));
   return $response
}

sub HostVStorageObjectRevert {
   my ($self, %args) = @_;
   return $self->waitForTask($self->HostVStorageObjectRevert_Task(%args));
}


1;
##################################################################################

##################################################################################
package VcenterVStorageObjectManagerOperations;
our @ISA = qw(VStorageObjectManagerBaseOperations);
sub CreateDisk_Task {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('CreateDisk_Task', %args));
   return $response
}

sub CreateDisk {
   my ($self, %args) = @_;
   return $self->waitForTask($self->CreateDisk_Task(%args));
}

sub RegisterDisk {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('RegisterDisk', %args));
   return $response
}

sub ExtendDisk_Task {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('ExtendDisk_Task', %args));
   return $response
}

sub ExtendDisk {
   my ($self, %args) = @_;
   return $self->waitForTask($self->ExtendDisk_Task(%args));
}

sub InflateDisk_Task {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('InflateDisk_Task', %args));
   return $response
}

sub InflateDisk {
   my ($self, %args) = @_;
   return $self->waitForTask($self->InflateDisk_Task(%args));
}

sub RenameVStorageObject {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('RenameVStorageObject', %args));
   return $response
}

sub UpdateVStorageObjectPolicy_Task {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('UpdateVStorageObjectPolicy_Task', %args));
   return $response
}

sub UpdateVStorageObjectPolicy {
   my ($self, %args) = @_;
   return $self->waitForTask($self->UpdateVStorageObjectPolicy_Task(%args));
}

sub UpdateVStorageInfrastructureObjectPolicy_Task {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('UpdateVStorageInfrastructureObjectPolicy_Task', %args));
   return $response
}

sub UpdateVStorageInfrastructureObjectPolicy {
   my ($self, %args) = @_;
   return $self->waitForTask($self->UpdateVStorageInfrastructureObjectPolicy_Task(%args));
}

sub RetrieveVStorageInfrastructureObjectPolicy {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('RetrieveVStorageInfrastructureObjectPolicy', %args));
   return $response
}

sub DeleteVStorageObject_Task {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('DeleteVStorageObject_Task', %args));
   return $response
}

sub DeleteVStorageObject {
   my ($self, %args) = @_;
   return $self->waitForTask($self->DeleteVStorageObject_Task(%args));
}

sub RetrieveVStorageObject {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('RetrieveVStorageObject', %args));
   return $response
}

sub RetrieveVStorageObjectState {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('RetrieveVStorageObjectState', %args));
   return $response
}

sub RetrieveVStorageObjectAssociations {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('RetrieveVStorageObjectAssociations', %args));
   return $response
}

sub ListVStorageObject {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('ListVStorageObject', %args));
   return $response
}

sub CloneVStorageObject_Task {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('CloneVStorageObject_Task', %args));
   return $response
}

sub CloneVStorageObject {
   my ($self, %args) = @_;
   return $self->waitForTask($self->CloneVStorageObject_Task(%args));
}

sub RelocateVStorageObject_Task {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('RelocateVStorageObject_Task', %args));
   return $response
}

sub RelocateVStorageObject {
   my ($self, %args) = @_;
   return $self->waitForTask($self->RelocateVStorageObject_Task(%args));
}

sub SetVStorageObjectControlFlags {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('SetVStorageObjectControlFlags', %args));
   return $response
}

sub ClearVStorageObjectControlFlags {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('ClearVStorageObjectControlFlags', %args));
   return $response
}

sub AttachTagToVStorageObject {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('AttachTagToVStorageObject', %args));
   return $response
}

sub DetachTagFromVStorageObject {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('DetachTagFromVStorageObject', %args));
   return $response
}

sub ListVStorageObjectsAttachedToTag {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('ListVStorageObjectsAttachedToTag', %args));
   return $response
}

sub ListTagsAttachedToVStorageObject {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('ListTagsAttachedToVStorageObject', %args));
   return $response
}

sub ReconcileDatastoreInventory_Task {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('ReconcileDatastoreInventory_Task', %args));
   return $response
}

sub ReconcileDatastoreInventory {
   my ($self, %args) = @_;
   return $self->waitForTask($self->ReconcileDatastoreInventory_Task(%args));
}

sub ScheduleReconcileDatastoreInventory {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('ScheduleReconcileDatastoreInventory', %args));
   return $response
}

sub VStorageObjectCreateSnapshot_Task {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('VStorageObjectCreateSnapshot_Task', %args));
   return $response
}

sub VStorageObjectCreateSnapshot {
   my ($self, %args) = @_;
   return $self->waitForTask($self->VStorageObjectCreateSnapshot_Task(%args));
}

sub DeleteSnapshot_Task {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('DeleteSnapshot_Task', %args));
   return $response
}

sub DeleteSnapshot {
   my ($self, %args) = @_;
   return $self->waitForTask($self->DeleteSnapshot_Task(%args));
}

sub RetrieveSnapshotInfo {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('RetrieveSnapshotInfo', %args));
   return $response
}

sub CreateDiskFromSnapshot_Task {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('CreateDiskFromSnapshot_Task', %args));
   return $response
}

sub CreateDiskFromSnapshot {
   my ($self, %args) = @_;
   return $self->waitForTask($self->CreateDiskFromSnapshot_Task(%args));
}

sub RevertVStorageObject_Task {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('RevertVStorageObject_Task', %args));
   return $response
}

sub RevertVStorageObject {
   my ($self, %args) = @_;
   return $self->waitForTask($self->RevertVStorageObject_Task(%args));
}


1;
##################################################################################

##################################################################################
package PropertyCollectorOperations;
sub CreateFilter {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('CreateFilter', %args));
   return $response
}

sub RetrieveProperties {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('RetrieveProperties', %args));
   return $response
}

sub CheckForUpdates {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('CheckForUpdates', %args));
   return $response
}

sub WaitForUpdates {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('WaitForUpdates', %args));
   return $response
}

sub CancelWaitForUpdates {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('CancelWaitForUpdates', %args));
   return $response
}

sub WaitForUpdatesEx {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('WaitForUpdatesEx', %args));
   return $response
}

sub RetrievePropertiesEx {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('RetrievePropertiesEx', %args));
   return $response
}

sub ContinueRetrievePropertiesEx {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('ContinueRetrievePropertiesEx', %args));
   return $response
}

sub CancelRetrievePropertiesEx {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('CancelRetrievePropertiesEx', %args));
   return $response
}

sub CreatePropertyCollector {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('CreatePropertyCollector', %args));
   return $response
}

sub DestroyPropertyCollector {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('DestroyPropertyCollector', %args));
   return $response
}


1;
##################################################################################

##################################################################################
package PropertyFilterOperations;
sub DestroyPropertyFilter {
   my ($self, %args) = @_;
   my $response = Util::check_fault($self->invoke('DestroyPropertyFilter', %args));
   return $response
}


1;
##################################################################################

__END__
=head1 NAME

VMware::VIRuntime - VI Perl Toolkit runtime module

=head1 SYNOPSIS

   use strict;
   use VMware::VIRuntime;

   # login
   Vim::login(service_url => 'https://localhost/sdk/vimService',
              user_name => 'Administrator',
              password => 'mypassword');

   # get 'VirtualMachineView' for all VM's that are poweredOn and is running a Windows guest
   my $vm_views = Vim::find_entity_views(view_type => 'VirtualMachine',
                                         filter => { 'guest.guestFullName' => '.*Windows.*',
                                                     'runtime.powerState' => 'poweredOn' });

   # snapshot all running / powered on Windows vm's
   foreach (@$vm_views) {
      $_->CreateSnapshot(name => 'nightly backup',
                         description => 'Nightly backup of Windows machines',
                         memory => 0,
                         quiesce => 1);
   }

   # logout
   Vim::logout();
  
=head1 DESCRIPTION

VMware::VIRuntime module provides an interface to discover and interact with
managed objects as specified by VMware Infrastructure API.  The module provides
views that correspond to managed objec type definitions detailed in reference guide
(available for download with SDK package at http://www.vmware.com/download/sdk/).
Managed object views in this runtime module provides access to methods
and properties.

Object discovery is provided through Vim::find_entity_view subroutine
which allows for constraint based search/filtering of inventory objects
based on filter parameter.

This modules also provides synchronous version of methods that return
Task object (methods with '_Task' appended to their names). For example,
PowerOnVM_Task method for VirtualMachine view provides PowerOnVM operation
that blocks until task completion.  

The module is built(depends) on Perl binding for VI API (VMware::VIStub)

=head1 SEE ALSO

VI Perl Toolkit Guide is available at ./doc/guide.html in module package.

VI API Programming guide and reference guide is available for download at
<http://www.vmware.com/download/sdk/>


=head1 COPYRIGHT AND LICENSE

The Original Software is licensed under the CDDL v. 1.0 only and cannot 
be distributed or otherwise made available under any subsequent version 
of the license.  This License hall be governed by and construed in 
accordance with the laws of the State of California, excluding its 
conflict-of-law provisions.  Any litigation relating to this License 
will be brought solely in the federal court in the Northern District 
of California or the state court in the County of Santa Clara.  

A copy of the CDDL license is included in this distribution.


Copyright (c) 2006, VMware, Inc.  All rights not expressly granted herein 
are reserved. 

=cut

