#!/usr/bin/pwsh
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
        $ServiceInstance = Get-View ServiceInstance
        $ServiceManager = Get-View $ServiceInstance.Content.serviceManager -property ""
    } else {
        AltAndCatchFire "global:DefaultVIServer variable check failure"
    }
} catch {
    AltAndCatchFire "Unable to verify vCenter connection"
}

if ($ServiceInstance.Content.About.ApiType -match "VirtualCenter") {

    $vcenter_name = $VcenterName = $($Server.ToLower()) -replace "[. ]","_"
    
    try {
        if ($ServiceInstance.Content.About.ApiVersion.Split(".")[0] -ge 6) {
            Write-Host "$((Get-Date).ToString("o")) [INFO] vCenter ApiVersion is =>6 so we can call vSAN API"
            $VsanSpaceReportSystem = Get-VSANView -Id VsanSpaceReportSystem-vsan-cluster-space-report-system
        } else {
            Write-Host "$((Get-Date).ToString("o")) [INFO] vCenter ApiVersion is not =>6 so we cannot call vSAN API"
        }
    } catch {
        AltAndCatchFire "Unable to read ServiceInstance.Content.About.ApiVersion"
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
        $vcenter_root_resource_pools_h.add($vcenter_root_resource_pool.MoRef.Value, $vcenter_root_resource_pool)
    }

    $vcenter_clusters_h = @{}
      foreach ($vcenter_cluster in $vcenter_clusters) {
        $vcenter_clusters_h.add($vcenter_cluster.MoRef.Value, $vcenter_cluster)
    }

    $vcenter_vmhosts_h = @{}
    foreach ($vcenter_vmhost in $vcenter_vmhosts) {
        $vcenter_vmhosts_h.add($vcenter_vmhost.MoRef.Value, $vcenter_vmhost)
    }

    $vcenter_vms_h = @{}
    foreach ($vcenter_vm in $vcenter_vms) {
        $vcenter_vms_h.add($vcenter_vm.MoRef.Value, $vcenter_vm)
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

        if (($vcenter_cluster.Host|Measure-Object).count -gt 1) {

            $cluster_name = NameCleaner $vcenter_cluster.Name
            $cluster_datacentre_name = NameCleaner $(GetRootDc $vcenter_cluster)

            [array]$cluster_hosts = @()
            foreach ($cluster_host in $vcenter_cluster.Host) {
                if ($vcenter_vmhosts_h[$cluster_host.Value]) {
                   $cluster_hosts += $vcenter_vmhosts_h[$cluster_host.Value]
                }
            }

            if ($cluster_hosts) {

                $cluster_host_random = $cluster_hosts|Get-Random -Count 1

                $cluster_vsan_uuid = $cluster_host_random.Config.VsanHostConfig.ClusterInfo.Uuid

                Write-Host "$((Get-Date).ToString("o")) [INFO] Start processing cluster $cluster_name $cluster_vsan_uuid in datacenter $cluster_datacentre_name ..."

                if ($cluster_host_random.Config.OptionDef.Key -match "VSAN.DedupScope") {
                    try {
                        Write-Host "$((Get-Date).ToString("o")) [INFO] Processing spaceUsageByObjectType in vSAN cluster $cluster_name (v6.2+)"

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




                Write-Host "$((Get-Date).ToString("o")) [INFO] Finish processing cluster $cluster_name in datacenter $cluster_datacentre_name"
            }
        }

    }

} else {
    AltAndCatchFire "$Server is not a vcenter!"
}

# https://www.virtuallyghetto.com/2017/04/getting-started-wthe-new-powercli-6-5-1-get-vsanview-cmdlet.html
# https://github.com/lamw/vghetto-scripts/blob/master/powershell/VSANSmartsData.ps1