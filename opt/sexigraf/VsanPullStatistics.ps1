#!/usr/bin/pwsh -Command
#
param([Parameter (Mandatory=$true)] [string] $Server, [Parameter (Mandatory=$true)] [string] $SessionFile, [Parameter (Mandatory=$false)] [string] $CredStore)

$ScriptVersion = "0.9.1"

$ExecStart = Get-Date

$ErrorActionPreference = "SilentlyContinue"
$WarningPreference = "SilentlyContinue"

function AltAndCatchFire {
    Param($ExitReason)
    Write-Host "$((Get-Date).ToString("o")) [ERROR] $ExitReason"
    Write-Host "$((Get-Date).ToString("o")) [ERROR] $($Error[0])"
    Write-Host "$((Get-Date).ToString("o")) [ERROR] Exit"
    Stop-Transcript
    exit
}

function GetRootDc {
	Param($child_object)	
	if ($xfolders_vcenter_parent_h[$child_object.Parent.value]) {	
		$Parent_folder = $child_object.Parent.value
		while ($xfolders_vcenter_type_h[$xfolders_vcenter_parent_h[$Parent_folder]] -notmatch "^Datacenter$") {
			if ($xfolders_vcenter_type_h[$xfolders_vcenter_parent_h[$Parent_folder]]) {$Parent_folder = $xfolders_vcenter_parent_h[$Parent_folder]}	
		}		
		return $xfolders_vcenter_name_h[$xfolders_vcenter_parent_h[$Parent_folder]]
	}
}

function NameCleaner {
    Param($NameToClean)
    $NameToClean = $NameToClean -replace "[ .]","_"
    [System.Text.NormalizationForm]$NormalizationForm = "FormD"
    $NameToClean = $NameToClean.Normalize($NormalizationForm)
    $NameToClean = $NameToClean -replace "[^[:ascii:]]","" -replace "[^A-Za-z0-9-_]","_"
    return $NameToClean
}

function VmdkNameCleaner {
    Param($NameToClean)
    $NameToClean = $NameToClean -replace "[ .()?!+]","_"
    [System.Text.NormalizationForm]$NormalizationForm = "FormD"
    $NameToClean = $NameToClean.Normalize($NormalizationForm)
    $NameToClean = $NameToClean -replace "[^[:ascii:]]","" -replace "[^A-Za-z0-9-_]","_"
    return $NameToClean
}

function GetParent {
    param ($parent)
    if ($parent.Parent) {
        GetParent $parent.Parent
    } else {
        return $parent
    }
}

function GetDomChild {
    param ($components,$CompChildren)
    foreach ($component in $components.psobject.Properties.name) {
        if ($component -match "child-") {
            GetDomChild $($components.$component) $CompChildren
        } elseif ($component -match "attributes") {
            foreach ($attribute in $components.attributes) {
                if ($attribute -match "bytesToSync") {
                    $CompChildren.bytesToSync += $components.attributes.bytesToSync
                    $CompChildren.Objs += 1
                } elseif ($attribute -match "recoveryETA") {
                    $CompChildren.recoveryETA += $components.attributes.recoveryETA
                }
            }
        }
    }
}

try {
    Start-Transcript -Path "/var/log/sexigraf/VsanDisksPullStatistics.$($Server).log" -Append -Confirm:$false -Force
    Write-Host "$((Get-Date).ToString("o")) [DEBUG] VsanDisksPullStatistics v$ScriptVersion"
} catch {
    Write-Host "$((Get-Date).ToString("o")) [ERROR] VsanDisksPullStatistics logging failure"
    Write-Host "$((Get-Date).ToString("o")) [ERROR] Exit"
    exit
}

try {
    Write-Host "$((Get-Date).ToString("o")) [DEBUG] Importing PowerCli and Graphite PowerShell modules ..."
    Import-Module VMware.VimAutomation.Common, VMware.VimAutomation.Core, VMware.VimAutomation.Sdk, VMware.VimAutomation.Storage
    Import-Module /usr/local/share/powershell/Modules/Graphite-PowerShell-Functions/Graphite-Powershell.psm1
} catch {
    AltAndCatchFire "Powershell modules import failure"
}

try {
    Write-Host "$((Get-Date).ToString("o")) [INFO] Looking for another VsanPullStatistics for $Server ..."
    $DupVsanPullStatisticsProcess = Get-PSHostProcessInfo|%{$(Get-Content -LiteralPath "/proc/$($_.ProcessId)/cmdline") -replace "`0", ' '}|?{$_ -match "VsanPullStatistics" -and $_ -match "$Server"}
    # https://github.com/PowerShell/PowerShell/issues/13944
    if (($DupVsanPullStatisticsProcess|Measure-Object).Count -gt 1) {
        AltAndCatchFire "VsanPullStatistics for $Server is already running!"
    }
} catch {
    AltAndCatchFire "VsanDisksPullStatistics process lookup failure"
}

if ($SessionFile) {
    try {
        $SessionToken = (Get-Content -Path $SessionFile -Force -Delimiter '\"')[1]
        Write-Host "$((Get-Date).ToString("o")) [INFO] SessionToken found in SessionFile, attempting connection to $Server ..."
        $PowerCliConfig = Set-PowerCLIConfiguration -ProxyPolicy NoProxy -DefaultVIServerMode Single -InvalidCertificateAction Ignore -ParticipateInCeip:$false -DisplayDeprecationWarnings:$false -Confirm:$false -Scope Session
        $ServerConnection = Connect-VIServer -Server $Server -Session $SessionToken -Force
        if ($ServerConnection.IsConnected) {
            Write-Host "$((Get-Date).ToString("o")) [INFO] Connected to vCenter $($ServerConnection.Name) version $($ServerConnection.Version) build $($ServerConnection.Build)"
        }
    } catch {
        AltAndCatchFire "SessionToken not found, invalid or connection failure"
    }
} elseif ($CredStore) {

}

try {
    if ($($global:DefaultVIServer)) {
        Write-Host "$((Get-Date).ToString("o")) [INFO] Start processing vCenter $Server ..."
        $ServiceInstance = Get-View ServiceInstance -Server $Server
        $ServiceManager = Get-View $ServiceInstance.Content.serviceManager -property "" -Server $Server
    } else {
        AltAndCatchFire "global:DefaultVIServer variable check failure"
    }
} catch {
    AltAndCatchFire "Unable to verify vCenter connection"
}

if ($ServiceInstance.Content.About.ApiType -match "VirtualCenter") {

    $vcenter_name = $VcenterName = $($Server.ToLower()) -replace "[. ]","_"
    
    try {
        if ($ServiceInstance.Content.About.ApiVersion -ge 6.7) {
            Write-Host "$((Get-Date).ToString("o")) [INFO] vCenter ApiVersion is 6.7+ so we can call vSAN API"
            $VsanSpaceReportSystem = Get-VSANView -Id VsanSpaceReportSystem-vsan-cluster-space-report-system -Server $Server
            $VsanObjectSystem = Get-VSANView -Id VsanObjectSystem-vsan-cluster-object-system -Server $Server
        } elseif ($ServiceInstance.Content.About.ApiVersion -ge 6) {
            Write-Host "$((Get-Date).ToString("o")) [INFO] vCenter ApiVersion is 6+ so we can call vSAN API"
            $VsanSpaceReportSystem = Get-VSANView -Id VsanSpaceReportSystem-vsan-cluster-space-report-system -Server $Server
        } else {
            Write-Host "$((Get-Date).ToString("o")) [INFO] vCenter ApiVersion is not 6+ so we cannot call vSAN API"
        }
    } catch {
        AltAndCatchFire "Unable to read ServiceInstance.Content.About.ApiVersion or call Get-VSANView"
    }

    Write-Host -ForegroundColor White "$((Get-Date).ToString("o")) [INFO] vCenter objects collect ..."

    try {
        $vcenter_datacenters = Get-View -ViewType Datacenter -Property Name, Parent -Server $Server
        $vcenter_folders = Get-View -ViewType Folder -Property Name, Parent -Server $Server
        $vcenter_clusters = Get-View -ViewType ClusterComputeResource -Property Name, Parent, Host, ResourcePool -Server $Server
        $vcenter_root_resource_pools = Get-View -ViewType ResourcePool -Property Vm, Parent -filter @{"Name" = "^Resources$"} -Server $Server
        $vcenter_vmhosts = Get-View -ViewType HostSystem -Property Parent, Config.Product.ApiVersion, Config.VsanHostConfig.ClusterInfo.Uuid, Config.Network.DnsConfig.HostName, ConfigManager.VsanInternalSystem, Runtime.ConnectionState, Runtime.InMaintenanceMode, Config.OptionDef -filter @{"Config.VsanHostConfig.ClusterInfo.Uuid" = "-";"Runtime.ConnectionState" = "^connected$";"runtime.inMaintenanceMode" = "false"} -Server $Server
        $vcenter_vms = Get-View -ViewType VirtualMachine -Property Config.Hardware.Device, Runtime.Host -filter @{"Summary.Runtime.ConnectionState" = "^connected$"} -Server $Server
        
    } catch {
        AltAndCatchFire "Get-View failure"
    }

    Write-Host -ForegroundColor White "$((Get-Date).ToString("o")) [INFO] Building objects tables ..."

    $vcenter_root_resource_pools_h = @{}
    foreach ($vcenter_root_resource_pool in $vcenter_root_resource_pools) {
        try {
            $vcenter_root_resource_pools_h.add($vcenter_root_resource_pool.MoRef.Value, $vcenter_root_resource_pool)
        } catch {}
    }

    $vcenter_clusters_h = @{}
      foreach ($vcenter_cluster in $vcenter_clusters) {
        try {
            $vcenter_clusters_h.add($vcenter_cluster.MoRef.Value, $vcenter_cluster)
        } catch {}
    }

    $vcenter_vmhosts_h = @{}
    $vcenter_vmhosts_vsan_h = @{}
    foreach ($vcenter_vmhost in $vcenter_vmhosts) {
        try {
            $vcenter_vmhosts_h.add($vcenter_vmhost.MoRef.Value, $vcenter_vmhost)
            $vcenter_vmhosts_vsan_h.add($vcenter_vmhost.MoRef.Value, $vcenter_vmhost.configManager.vsanInternalSystem.value)
        } catch {}
    }

    $vcenter_vms_h = @{}
    foreach ($vcenter_vm in $vcenter_vms) {
        try {
            $vcenter_vms_h.add($vcenter_vm.MoRef.Value, $vcenter_vm)
        } catch {}
    }

	$xfolders_vcenter_name_h = @{}
	$xfolders_vcenter_parent_h = @{}
	$xfolders_vcenter_type_h = @{}

	Write-Host -ForegroundColor White "$((Get-Date).ToString("o")) [INFO] vCenter objects relationship discover ..."
	
	foreach ($vcenter_xfolder in [array]$vcenter_datacenters + [array]$vcenter_folders + [array]$vcenter_clusters + [array]$vcenter_root_resource_pools + [array]$vcenter_vmhosts) {
		if (!$xfolders_vcenter_name_h[$vcenter_xfolder.moref.value]) {$xfolders_vcenter_name_h.add($vcenter_xfolder.moref.value,$vcenter_xfolder.name)}
		if (!$xfolders_vcenter_parent_h[$vcenter_xfolder.moref.value]) {$xfolders_vcenter_parent_h.add($vcenter_xfolder.moref.value,$vcenter_xfolder.Parent.value)}
		if (!$xfolders_vcenter_type_h[$vcenter_xfolder.moref.value]) {$xfolders_vcenter_type_h.add($vcenter_xfolder.moref.value,$vcenter_xfolder.moref.type)}
	}

    Write-Host "$((Get-Date).ToString("o")) [INFO] Start processing clusters ..."

    foreach ($vcenter_cluster in $vcenter_clusters) {

        if (($vcenter_cluster.Host|Measure-Object).count -gt 0) {

            $cluster_name = NameCleaner $($vcenter_cluster.Name).ToLower()
            $datacentre_name = NameCleaner $(GetRootDc $vcenter_cluster).ToLower()

            [array]$cluster_hosts = @()
            foreach ($cluster_host in $vcenter_cluster.Host) {
                if ($vcenter_vmhosts_h[$cluster_host.Value]) {
                   $cluster_hosts += $vcenter_vmhosts_h[$cluster_host.Value]
                }
            }

            if ($cluster_hosts) {

                Write-Host "$((Get-Date).ToString("o")) [INFO] Start processing cluster $cluster_name $cluster_vsan_uuid in datacenter $datacentre_name ..."

                $cluster_host_random = $cluster_hosts|Get-Random -Count 1

                try {
                    $cluster_vsan_uuid = $cluster_host_random.Config.VsanHostConfig.ClusterInfo.Uuid
                } catch {
                    AltAndCatchFire "Unable to retreive VsanHostConfig.ClusterInfo.Uuid from $($cluster_host_random.config.network.dnsConfig.hostName) in cluster $cluster_name"
                }

                try {
                    Write-Host "$((Get-Date).ToString("o")) [INFO] Processing vsanInternalSystem in vSAN cluster $cluster_name ..."
                    $cluster_hosts_vsanInternalSystem = Get-View $cluster_hosts.configManager.vsanInternalSystem -Server $Server
                    $cluster_host_vsanInternalSystem_h = @{}
                    foreach ($cluster_host_vsanInternalSystem in $cluster_hosts_vsanInternalSystem) {
                        $cluster_host_vsanInternalSystem_h.add($cluster_host_vsanInternalSystem.moref.value,$cluster_host_vsanInternalSystem)
                    }
                } catch {
                    AltAndCatchFire "Unable to retreive vsanInternalSystem in cluster $cluster_name"
                }

                if ($cluster_host_random.Config.OptionDef.Key -match "VSAN.DedupScope") {
                    try {
                        Write-Host "$((Get-Date).ToString("o")) [INFO] Processing spaceUsageByObjectType in vSAN cluster $cluster_name (v6.2+) ..."

                        $ClusterVsanSpaceUsageReport = $VsanSpaceReportSystem.VsanQuerySpaceUsage($vcenter_cluster.Moref)
                        $ClusterVsanSpaceUsageReportObjList = $ClusterVsanSpaceUsageReport.spaceDetail.spaceUsageByObjectType
                        foreach ($vsanObjType in $ClusterVsanSpaceUsageReportObjList) {
                            $ClusterVsanSpaceUsageReportObjType = $vsanObjType.objType
                            $ClusterVsanSpaceUsageReportObjTypeHash = @{
                                "vsan.$vcenter_name.$datacentre_name.$cluster_name.vsan.spaceDetail.spaceUsageByObjectType.$ClusterVsanSpaceUsageReportObjType.overheadB" = $vsanObjType.overheadB;
                                "vsan.$vcenter_name.$datacentre_name.$cluster_name.vsan.spaceDetail.spaceUsageByObjectType.$ClusterVsanSpaceUsageReportObjType.physicalUsedB" = $vsanObjType.physicalUsedB;
                                "vsan.$vcenter_name.$datacentre_name.$cluster_name.vsan.spaceDetail.spaceUsageByObjectType.$ClusterVsanSpaceUsageReportObjType.overReservedB" = $vsanObjType.overReservedB;
                                "vsan.$vcenter_name.$datacentre_name.$cluster_name.vsan.spaceDetail.spaceUsageByObjectType.$ClusterVsanSpaceUsageReportObjType.usedB" = $vsanObjType.usedB;
                                "vsan.$vcenter_name.$datacentre_name.$cluster_name.vsan.spaceDetail.spaceUsageByObjectType.$ClusterVsanSpaceUsageReportObjType.temporaryOverheadB" = $vsanObjType.temporaryOverheadB;
                                "vsan.$vcenter_name.$datacentre_name.$cluster_name.vsan.spaceDetail.spaceUsageByObjectType.$ClusterVsanSpaceUsageReportObjType.primaryCapacityB" = $vsanObjType.primaryCapacityB;
                                "vsan.$vcenter_name.$datacentre_name.$cluster_name.vsan.spaceDetail.spaceUsageByObjectType.$ClusterVsanSpaceUsageReportObjType.reservedCapacityB" = $vsanObjType.reservedCapacityB
                            }
                            Send-BulkGraphiteMetrics -CarbonServer 127.0.0.1 -CarbonServerPort 2003 -Metrics $ClusterVsanSpaceUsageReportObjTypeHash -DateTime $ExecStart
                            # Send-GraphiteMetric -CarbonServer 127.0.0.1 -CarbonServerPort 2003 -MetricPath "toto1.toto2.toto3" -MetricValue 1 -UnixTime (New-TimeSpan -Start (Get-Date -Date "01/01/1970") -End (get-date).ToUniversalTime()).TotalSeconds
                        }

                    } catch {
                        Write-Host "$((Get-Date).ToString("o")) [WARNING] Unable to retreive VsanQuerySpaceUsage for cluster $cluster_name"
                    }

                }

                try {
                    if ($vcenter_root_resource_pools_h[$vcenter_cluster.ResourcePool.Value].Vm) {
                        Write-Host "$((Get-Date).ToString("o")) [INFO] Processing VirtualDisk in cluster $cluster_name ..."
                        $cluster_vdisks_id = @{}
                        foreach ($cluster_vm_moref in $vcenter_root_resource_pools_h[$vcenter_cluster.ResourcePool.Value].Vm) {
                            foreach ($cluster_vm_vdisk in $vcenter_vms_h[$cluster_vm_moref.Value].Config.Hardware.Device|?{$_ -is [VMware.Vim.VirtualDisk] -and $_.Backing.BackingObjectId}) {
                                $cluster_vm_vdisk_base_name = VmdkNameCleaner $($cluster_vm_vdisk.Backing.FileName -split "[/.]")[1]
                                $cluster_vdisks_id.add($cluster_vm_vdisk.Backing.BackingObjectId, $cluster_vm_vdisk_base_name)

                                if ($cluster_vm_vdisk.Backing.Parent) {
                                    $cluster_vm_vdisk_parent = GetParent $cluster_vm_vdisk.Backing.Parent
                                    $cluster_vm_vdisk_parent_base_name = VmdkNameCleaner $($cluster_vm_vdisk_parent.FileName -split "[/.]")[1]
                                    $cluster_vdisks_id.add($($cluster_vm_vdisk.Backing.BackingObjectId + "_root"), $cluster_vm_vdisk_parent.BackingObjectId)
                                    $cluster_vdisks_id.add($cluster_vm_vdisk_parent.BackingObjectId, $cluster_vm_vdisk_parent_base_name)
                                }
                            }
                        }
                    } else {
                        Write-Host "$((Get-Date).ToString("o")) [WARNING] No VM in cluster $cluster_name"
                    }
                } catch {
                    AltAndCatchFire "Unable to retreive VirtualDisk in cluster $cluster_name"
                }

                try {
                    Write-Host "$((Get-Date).ToString("o")) [INFO] Processing VsanInternalSystem from $($cluster_host_random.config.network.dnsConfig.hostName) in cluster $cluster_name ..."
                    $cluster_host_random_VsanInternalSystem = get-view $cluster_host_random.ConfigManager.VsanInternalSystem
                } catch {
                    AltAndCatchFire "Unable to retreive VsanInternalSystem from $($cluster_host_random.config.network.dnsConfig.hostName) in cluster $cluster_name"
                }

                try {
                    Write-Host "$((Get-Date).ToString("o")) [INFO] Processing PhysicalVsanDisks from $($cluster_host_random.config.network.dnsConfig.hostName) in cluster $cluster_name ..."
                    # $cluster_PhysicalVsanDisks = $cluster_host_random_VsanInternalSystem.QueryPhysicalVsanDisks(@())|ConvertFrom-Json
                    $cluster_PhysicalVsanDisks = $cluster_host_random_VsanInternalSystem.QueryPhysicalVsanDisks("devName")|ConvertFrom-Json -AsHashtable
                } catch {
                    AltAndCatchFire "Unable to retreive PhysicalVsanDisks from $($cluster_host_random.config.network.dnsConfig.hostName) in cluster $cluster_name"
                }

                if ($cluster_host_random.Config.Product.ApiVersion -gt 6.7) {
                    try {
                        Write-Host "$((Get-Date).ToString("o")) [INFO] Processing SyncingVsanObjectsSummary in cluster $cluster_name (v6.7+) ..."
                        # https://vdc-download.vmware.com/vmwb-repository/dcr-public/b21ba11d-4748-4796-97e2-7000e2543ee1/b4a40704-fbca-4222-902c-2500f5a90f3f/vim.cluster.VsanObjectSystem.html#querySyncingVsanObjectsSummary
                        # https://vdc-download.vmware.com/vmwb-repository/dcr-public/9ab58fbf-b389-4e15-bfd4-a915910be724/7872dcb2-3287-40e1-ba00-71071d0e19ff/vim.vsan.VsanSyncReason.html
                        $QuerySyncingVsanObjectsSummary = $VsanObjectSystem.QuerySyncingVsanObjectsSummary($vcenter_cluster.Moref,$(new-object VMware.Vsan.Views.VsanSyncingObjectFilter -property @{NumberOfObjects="200"}))
                        if ($QuerySyncingVsanObjectsSummary.TotalObjectsToSync -gt 0) {
                            if ($QuerySyncingVsanObjectsSummary.Objects) {
                                $ReasonsToSync = @{}
                                foreach ($SyncingComponent in $QuerySyncingVsanObjectsSummary.Objects.Components) {
                                    $SyncingComponentJoinReason = $SyncingComponent.Reasons -join "-"
                                    $ReasonsToSync.$SyncingComponentJoinReason += $SyncingComponent.BytesToSync
                                }
                                $ReasonsToSyncHash = @{}
                                foreach ($ReasonToSync in $ReasonsToSync.keys) {
                                    # Send-GraphiteMetric -CarbonServer 127.0.0.1 -CarbonServerPort 2003 -MetricPath "vsan.$vcenter_name.$datacentre_name.$cluster_name.vsan.SyncingVsanObjects.bytesToSync.$ReasonToSync" -MetricValue $ReasonsToSync.$ReasonToSync -DateTime $ExecStart
                                    $ReasonsToSyncHash.add("vsan.$vcenter_name.$datacentre_name.$cluster_name.vsan.SyncingVsanObjects.bytesToSync.$ReasonToSync",$ReasonsToSync.$ReasonToSync)
                                }
                                Send-BulkGraphiteMetrics -CarbonServer 127.0.0.1 -CarbonServerPort 2003 -Metrics $ReasonsToSyncHash -DateTime $ExecStart  
                            }

                            $SyncingVsanObjectsHash = @{
                                "vsan.$vcenter_name.$datacentre_name.$cluster_name.vsan.SyncingVsanObjects.totalRecoveryETA" = $QuerySyncingVsanObjectsSummary.TotalRecoveryETA;
                                "vsan.$vcenter_name.$datacentre_name.$cluster_name.vsan.SyncingVsanObjects.totalBytesToSync" = $QuerySyncingVsanObjectsSummary.TotalBytesToSync;
                                "vsan.$vcenter_name.$datacentre_name.$cluster_name.vsan.SyncingVsanObjects.totalObjectsToSync" = $QuerySyncingVsanObjectsSummary.TotalObjectsToSync;
                                "vsan.$vcenter_name.$datacentre_name.$cluster_name.vsan.SyncingVsanObjects.totalComponentsToSync" = ($QuerySyncingVsanObjectsSummary.Objects.Components|Measure-Object -sum).count;
                            }
                            Send-BulkGraphiteMetrics -CarbonServer 127.0.0.1 -CarbonServerPort 2003 -Metrics $SyncingVsanObjectsHash -DateTime $ExecStart    
                        }
                    } catch {
                        Write-Host "$((Get-Date).ToString("o")) [WARNING] Unable to retreive SyncingVsanObjectsSummary in cluster $cluster_name"
                    }
                } else {
                    try {
                        Write-Host "$((Get-Date).ToString("o")) [INFO] Processing SyncingVsanObjects from $($cluster_host_random.config.network.dnsConfig.hostName) in cluster $cluster_name ..."
                        $cluster_SyncingVsanObjects = $cluster_host_random_VsanInternalSystem.QuerySyncingVsanObjects(@())|ConvertFrom-Json -AsHashtable
                        if ($cluster_SyncingVsanObjects."dom_objects".keys) {
                            Write-Host "$((Get-Date).ToString("o")) [DEBUG] Processing SyncingVsanObjects dom_objects from $($cluster_host_random.config.network.dnsConfig.hostName) in cluster $cluster_name ..."
                            $SyncingVsanObjects = ""|Select-Object bytesToSync, recoveryETA, Objs
                            $SyncingVsanObjects.recoveryETA = 0
                            foreach ($cluster_SyncingVsanObjects_dom in $($cluster_SyncingVsanObjects."dom_objects").keys) {
                                GetDomChild $($cluster_SyncingVsanObjects."dom_objects").$cluster_SyncingVsanObjects_dom.config.content $SyncingVsanObjects
                            }
                            if ($SyncingVsanObjects.Objs -gt 0 -and $SyncingVsanObjects.recoveryETA -gt 0) {
                                $SyncingVsanObjects.recoveryETA = $SyncingVsanObjects.recoveryETA / $SyncingVsanObjects.Objs
                            }
                            $SyncingVsanObjectsHash = @{
                                "vsan.$vcenter_name.$datacentre_name.$cluster_name.vsan.SyncingVsanObjects.totalRecoveryETA" = $SyncingVsanObjects.recoveryETA;
                                "vsan.$vcenter_name.$datacentre_name.$cluster_name.vsan.SyncingVsanObjects.totalBytesToSync" = $SyncingVsanObjects.bytesToSync;
                                "vsan.$vcenter_name.$datacentre_name.$cluster_name.vsan.SyncingVsanObjects.totalObjectsToSync" = $SyncingVsanObjects.Objs;
                            }
                            Send-BulkGraphiteMetrics -CarbonServer 127.0.0.1 -CarbonServerPort 2003 -Metrics $SyncingVsanObjectsHash -DateTime $ExecStart
                        }
                    } catch {
                        Write-Host "$((Get-Date).ToString("o")) [WARNING] Unable to retreive SyncingVsanObjects from $($cluster_host_random.config.network.dnsConfig.hostName) in cluster $cluster_name"
                    }
                }

                foreach ($cluster_host in $cluster_hosts) {
                    Write-Host "$((Get-Date).ToString("o")) [INFO] Processing QueryVsanStatistics from $($cluster_host.config.network.dnsConfig.hostName) in cluster $cluster_name ..."
                    $host_name = $($cluster_host.config.network.dnsConfig.hostName).ToLower()
                    try {
                        $cluster_host_VsanStatistics = $cluster_host_vsanInternalSystem_h[$vcenter_vmhosts_vsan_h[$cluster_host.moref.value]].QueryVsanStatistics(@('dom', 'lsom', 'dom-objects', 'disks'))|ConvertFrom-Json -AsHashtable
                        # [
                        #     'dom', 'lsom', 'worldlets', 'plog', 
                        #     'dom-objects',
                        #     'mem', 'cpus', 'slabs',
                        #     'vscsi', 'cbrc',
                        #     'disks',
                        #     'rdtassocsets', 
                        #     'system-mem', 'pnics',
                        # ]
                    } catch {
                        Write-Host "$((Get-Date).ToString("o")) [WARNING] Unable to retreive QueryVsanStatistics from $host_name in cluster $cluster_name"
                    }
                    
                }

                Write-Host "$((Get-Date).ToString("o")) [INFO] Finish processing cluster $cluster_name in datacenter $datacentre_name"
            }
        }

    }

} else {
    AltAndCatchFire "$Server is not a vcenter!"
}

# https://www.virtuallyghetto.com/2017/04/getting-started-wthe-new-powercli-6-5-1-get-vsanview-cmdlet.html
# https://github.com/lamw/vghetto-scripts/blob/master/powershell/VSANSmartsData.ps1