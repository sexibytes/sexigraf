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
    $NameToClean -replace "[ .]","_"
    [System.Text.NormalizationForm]$NormalizationForm = "FormD"
    $NameToClean = $NameToClean.Normalize($NormalizationForm)
    $NameToClean -replace "[^[:ascii:]]","" -replace "[^A-Za-z0-9-_]","_"
    return $NameToClean
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
    } else {
        AltAndCatchFire "global:DefaultVIServer variable check failure"
    }
} catch {
    AltAndCatchFire "Unable to verify vCenter connection"
}

if ($ServiceInstance.Content.About.ApiType -match "VirtualCenter") {

    $VcenterName = $($Server.ToLower()) -replace "[. ]","_"
    
    try {
        if ($ServiceInstance.Content.About.ApiVersion.Split(".")[0] -ge 6) {
            Write-Host "$((Get-Date).ToString("o")) [INFO] vCenter ApiVersion is =>6 so we can call vSAN API"
            $VsanSpaceReportSystem = Get-VSANView -Id "VsanSpaceReportSystem-vsan-cluster-space-report-system"
        } else {
            Write-Host "$((Get-Date).ToString("o")) [INFO] vCenter ApiVersion is not =>6 so we cannot call vSAN API"
        }
    } catch {
        AltAndCatchFire "Unable to read ServiceInstance.Content.About.ApiVersion"
    }

    Write-Host -ForegroundColor White "$((Get-Date).ToString("o")) [INFO] vCenter objects collect ..."

    try {
        $vcenter_datacenters = Get-View -ViewType datacenter -Property Name, Parent -Server $Server
        $vcenter_folders = Get-View -ViewType folder -Property Name, Parent -Server $Server
        $vcenter_clusters = Get-View -ViewType clustercomputeresource -Property Name, Parent, Host, ResourcePool -Server $Server
        $vcenter_root_resource_pools = Get-View -ViewType ResourcePool -Property Vm, Parent -filter @{"Name" = "^Resources$"} -Server $Server
        $vcenter_vmhosts = Get-View -ViewType hostsystem -Property Parent, Config.Product.ApiVersion, Config.VsanHostConfig.ClusterInfo.Uuid, Config.Network.DnsConfig.HostName, ConfigManager.VsanInternalSystem, Runtime.ConnectionState, Runtime.InMaintenanceMode, Config.OptionDef -filter @{"Config.VsanHostConfig.ClusterInfo.Uuid" = "-";"Runtime.ConnectionState" = "^connected$";"runtime.inMaintenanceMode" = "false"} -Server $Server
        $vcenter_vms = Get-View -ViewType hostsystem -Property Name, Parent -filter @{"Runtime.ConnectionState" = "^connected$"} -Server $Server
        
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

            foreach ($cluster_host in $vcenter_cluster.Host) {
                if ($vcenter_vmhosts_h[$cluster_host.MoRef.Value]) {
                    [array]$cluster_hosts += $vcenter_vmhosts_h[$cluster_host.MoRef.Value]
                }
            }

            if ($cluster_hosts) {

                $cluster_vsan_uuid = $cluster_hosts[0].Config.VsanHostConfig.ClusterInfo.Uuid

                Write-Host "$((Get-Date).ToString("o")) [INFO] Start processing cluster $cluster_name $cluster_vsan_uuid in datacenter $cluster_datacentre_name ..."

                if ($cluster_hosts[0].Config.OptionDef.Key -match "VSAN.DedupScope") {
                    try {
                        $ClusterVsanSpaceUsageReport = $VsanSpaceReportSystem.VsanQuerySpaceUsage($vcenter_cluster)
                        Write-Host "$((Get-Date).ToString("o")) [INFO] Processing spaceUsageByObjectType in vSAN cluster $cluster_name (v6.2+)"
                        $ClusterVsanSpaceUsageReportObjList = $ClusterVsanSpaceUsageReport.spaceDetail.spaceUsageByObjectType

                    } catch {
                        Write-Host "$((Get-Date).ToString("o")) [ERROR] Unable to retreive VsanQuerySpaceUsage for cluster $cluster_name"
                    }

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