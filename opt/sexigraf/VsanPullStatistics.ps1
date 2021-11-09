#!/usr/bin/pwsh -NonInteractive -NoProfile -Command
#
param([Parameter (Mandatory=$true)] [string] $Server, [Parameter (Mandatory=$true)] [string] $SessionFile, [Parameter (Mandatory=$false)] [string] $CredStore)

$ScriptVersion = "0.9.71"

$ExecStart = $(Get-Date).ToUniversalTime()
# $stopwatch =  [system.diagnostics.stopwatch]::StartNew()

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
$AltAndCatchFire = $function:AltAndCatchFire.ToString()

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
$GetRootDc = $function:GetRootDc.ToString()

function NameCleaner {
    Param($NameToClean)
    $NameToClean = $NameToClean -replace "[ .]","_"
    [System.Text.NormalizationForm]$NormalizationForm = "FormD"
    $NameToClean = $NameToClean.Normalize($NormalizationForm)
    $NameToClean = $NameToClean -replace "[^[:ascii:]]","" -replace "[^A-Za-z0-9-_]","_"
    return $NameToClean.ToLower()
}
$NameCleaner = $function:NameCleaner.ToString()

function VmdkNameCleaner {
    Param($NameToClean)
    $NameToClean = $NameToClean -replace "[ .()?!+]","_"
    [System.Text.NormalizationForm]$NormalizationForm = "FormD"
    $NameToClean = $NameToClean.Normalize($NormalizationForm)
    $NameToClean = $NameToClean -replace "[^[:ascii:]]","" -replace "[^A-Za-z0-9-_]","_"
    return $NameToClean
}
$VmdkNameCleaner = $function:VmdkNameCleaner.ToString()

function GetParent {
    param ($parent)
    if ($parent.Parent) {
        GetParent $parent.Parent
    } else {
        return $parent
    }
}
$GetParent = $function:GetParent.ToString()

function GetDomChild {
    param ($components,$CompChildren)
    foreach ($component in $components.keys) {
        if ($component -match "child-") {
            GetDomChild $($components.$component) $CompChildren
        } elseif ($component -match "attributes") {
            foreach ($attribute in $components.attributes.keys) {
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
$GetDomChild = $function:GetDomChild.ToString()

try {
    Start-Transcript -Path "/var/log/sexigraf/VsanDisksPullStatistics.$($Server).log" -Append -Confirm:$false -Force
    Start-Transcript -Path "/var/log/sexigraf/VsanDisksPullStatistics.log" -Append -Confirm:$false -Force
    Write-Host "$((Get-Date).ToString("o")) [DEBUG] VsanDisksPullStatistics v$ScriptVersion"
} catch {
    Write-Host "$((Get-Date).ToString("o")) [ERROR] VsanDisksPullStatistics logging failure"
    Write-Host "$((Get-Date).ToString("o")) [ERROR] Exit"
    exit
}

try {
    Write-Host "$((Get-Date).ToString("o")) [DEBUG] Importing PowerCli and Graphite PowerShell modules ..."
    Import-Module VMware.VimAutomation.Common, VMware.VimAutomation.Core, VMware.VimAutomation.Sdk, VMware.VimAutomation.Storage
    $PowerCliConfig = Set-PowerCLIConfiguration -ProxyPolicy NoProxy -DefaultVIServerMode Single -InvalidCertificateAction Ignore -ParticipateInCeip:$false -DisplayDeprecationWarnings:$false -Confirm:$false -Scope Session
    Import-Module -Name /usr/local/share/powershell/Modules/Graphite-PowerShell-Functions/Graphite-Powershell.psm1 -Global -Force -SkipEditionCheck
} catch {
    AltAndCatchFire "Powershell modules import failure"
}

try {
    Write-Host "$((Get-Date).ToString("o")) [INFO] Looking for another VsanPullStatistics for $Server ..."
    $DupVsanPullStatisticsProcess = Get-PSHostProcessInfo|%{$(Get-Content -LiteralPath "/proc/$($_.ProcessId)/cmdline") -replace "`0", ' '}|?{$_ -match "VsanPullStatistics" -and $_ -match "$Server"}
    # https://github.com/PowerShell/PowerShell/issues/13944
    if (($DupVsanPullStatisticsProcess|Measure-Object).Count -gt 1) {
        $DupVsanPullStatisticsProcessId = (Get-PSHostProcessInfo|?{$(Get-Content -LiteralPath "/proc/$($_.ProcessId)/cmdline") -replace "`0", ' '|?{$_ -match "$Server"}}).ProcessId[0]
        $DupVsanPullStatisticsProcessTime = [INT32](ps -p $DupVsanPullStatisticsProcessId -o etimes).split()[-1]
        if ($DupVsanPullStatisticsProcessTime -gt 300) {
            Write-Host "$((Get-Date).ToString("o")) [WARNING] VsanPullStatistics for $Server is already running for more than 5 minutes!"
            Write-Host "$((Get-Date).ToString("o")) [WARNING] Killing stunned VsanPullStatistics for $Server"
            Stop-Process -Id $DupVsanPullStatisticsProcessId -Force
        } else {
            AltAndCatchFire "VsanPullStatistics for $Server is already running!"
        }
    }
} catch {
    AltAndCatchFire "VsanDisksPullStatistics process lookup failure"
}

if ($SessionFile) {
    try {
        $SessionToken = Get-Content -Path $SessionFile -ErrorAction Stop
        Write-Host "$((Get-Date).ToString("o")) [INFO] SessionToken found in SessionFile, attempting connection to $Server ..."
        # https://zhengwu.org/validating-connection-result-of-connect-viserver/
        $ServerConnection = Connect-VIServer -Server $Server -Session $SessionToken -Force -ErrorAction Stop
        if ($ServerConnection.IsConnected) {
            $PwCliContext = Get-PowerCLIContext
            Write-Host "$((Get-Date).ToString("o")) [INFO] Connected to vCenter $($ServerConnection.Name) version $($ServerConnection.Version) build $($ServerConnection.Build)"
        }
    } catch {
        Write-Host "$((Get-Date).ToString("o")) [WARNING] SessionToken not found, invalid or connection failure"
        Write-Host "$((Get-Date).ToString("o")) [WARNING] Attempting explicit connection ..."

    }
    if (!$($global:DefaultVIServer)) {
        try {
            $createstorexml = New-Object -TypeName XML
            $createstorexml.Load($credstore)
            $XPath = '//passwordEntry[server="' + $Server + '"]'
            if ($(Select-XML -Xml $createstorexml -XPath $XPath)){
                $item = Select-XML -Xml $createstorexml -XPath $XPath
                $CredStoreLogin = $item.Node.username
                $CredStorePassword = [System.Text.Encoding]::Unicode.GetString([System.Convert]::FromBase64String($item.Node.password))
            } else {
                AltAndCatchFire "No $Server entry in CredStore"
            }
            $ServerConnection = Connect-VIServer -Server $Server -User $CredStoreLogin -Password $CredStorePassword -Force -ErrorAction Stop
            if ($ServerConnection.IsConnected) {
                $PwCliContext = Get-PowerCLIContext
                Write-Host "$((Get-Date).ToString("o")) [INFO] Connected to vCenter $($ServerConnection.Name) version $($ServerConnection.Version) build $($ServerConnection.Build)"
                $SessionSecretName = "vmw_" + $Server.Replace(".","_") + ".key"
                $ServerConnection.SessionSecret | Out-File -FilePath /tmp/$SessionSecretName -Force
            }
        } catch {
            AltAndCatchFire "Explicit connection failed, check the stored credentials!"
        }
    }
} else {
    AltAndCatchFire "No SessionFile somehow..."
}

try {
    if ($($global:DefaultVIServer)) {
        Write-Host "$((Get-Date).ToString("o")) [INFO] Start processing vCenter $Server ..."
        $ServiceInstance = Get-View ServiceInstance -Server $Server
        # $ServiceManager = Get-View $ServiceInstance.Content.serviceManager -property "" -Server $Server
    } else {
        AltAndCatchFire "global:DefaultVIServer variable check failure"
    }
} catch {
    AltAndCatchFire "Unable to verify vCenter connection"
}

if ($ServiceInstance.Content.About.ApiType -match "VirtualCenter") {

    $vcenter_name = $($Server.ToLower()) -replace "[. ]","_"
    
    try {
        if ($ServiceInstance.Content.About.ApiVersion -ge 6.7) {
            Write-Host "$((Get-Date).ToString("o")) [INFO] vCenter ApiVersion is 6.7+ so we can call vSAN API"
            $VsanObjectSystem = Get-VSANView -Id VsanObjectSystem-vsan-cluster-object-system -Server $Server
            $VsanPerformanceManager = Get-VSANView -Id VsanPerformanceManager-vsan-performance-manager -Server $Server
            if ($ExecStart.Minute % 5 -eq 0) {
                $VsanClusterHealthSystem = Get-VSANView -Id VsanVcClusterHealthSystem-vsan-cluster-health-system -Server $Server
                $VsanSpaceReportSystem = Get-VSANView -Id VsanSpaceReportSystem-vsan-cluster-space-report-system -Server $Server
            } else {
                $VsanClusterHealthSystem = $true # to avoid "The value of the using variable '$using:VsanClusterHealthSystem' cannot be retrieved because it has not been set in the local session."
                $VsanSpaceReportSystem = $true
                $VsanPerformanceManager = $true
            }
        } elseif ($ServiceInstance.Content.About.ApiVersion -ge 6) {
            $VsanObjectSystem = $true
            $VsanClusterHealthSystem = $true
            $VsanPerformanceManager = $true
            if ($ExecStart.Minute % 5 -eq 0) {
                Write-Host "$((Get-Date).ToString("o")) [INFO] vCenter ApiVersion is 6+ so we can call vSAN API"
                $VsanSpaceReportSystem = Get-VSANView -Id VsanSpaceReportSystem-vsan-cluster-space-report-system -Server $Server
            } else {
                $VsanSpaceReportSystem = $true 
            }
        } else {
            Write-Host "$((Get-Date).ToString("o")) [INFO] vCenter ApiVersion is not 6+ so we cannot call vSAN API"
            $VsanObjectSystem = $true
            $VsanClusterHealthSystem = $true
            $VsanSpaceReportSystem = $true
            $VsanPerformanceManager = $true
        }
    } catch {
        AltAndCatchFire "Unable to read ServiceInstance.Content.About.ApiVersion or call Get-VSANView"
    }

    Write-Host "$((Get-Date).ToString("o")) [INFO] vCenter objects collect ..."

    try {
        $vcenter_datacenters = Get-View -ViewType Datacenter -Property Name, Parent -Server $Server
        $vcenter_folders = Get-View -ViewType Folder -Property Name, Parent -Server $Server
        $vcenter_clusters = Get-View -ViewType ClusterComputeResource -Property Name, Parent, Host, ResourcePool -Server $Server
        $vcenter_resource_pools = Get-View -ViewType ResourcePool -Property Vm, Parent, Owner -Server $Server
        $vcenter_vmhosts = Get-View -ViewType HostSystem -Property Name, Parent, Config.Product.ApiVersion, Config.VsanHostConfig.ClusterInfo, Config.Network.DnsConfig.HostName, ConfigManager.VsanInternalSystem, Runtime.ConnectionState, Runtime.InMaintenanceMode, Config.OptionDef -filter @{"Config.VsanHostConfig.ClusterInfo.Uuid" = "-";"Runtime.ConnectionState" = "^connected$";"runtime.inMaintenanceMode" = "false"} -Server $Server
        $vcenter_vms = Get-View -ViewType VirtualMachine -Property Config.Hardware.Device, Runtime.Host -filter @{"Summary.Runtime.ConnectionState" = "^connected$"} -Server $Server
        $vcenter_vsan_ds = Get-View -ViewType Datastore -Property name,info.url,info.ContainerId -Server $Server |?{$_.info.url -match "/vsan:"}
        
    } catch {
        AltAndCatchFire "Get-View failure"
    }

    Write-Host "$((Get-Date).ToString("o")) [INFO] Building objects tables ..."

    $vcenter_resource_pools_owner_vms_h = @{}
    foreach ($vcenter_root_resource_pool in $vcenter_resource_pools) {
        try {
            if ($vcenter_root_resource_pool.owner -and $vcenter_root_resource_pool.vm) {
                $vcenter_resource_pools_owner_vms_h[$vcenter_root_resource_pool.owner.value] += $vcenter_root_resource_pool.vm
            }
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
    $vcenter_vmhosts_name_h = @{}
    $vcenter_vsan_clusters_h = @{}
    foreach ($vcenter_vmhost in $vcenter_vmhosts) {
        if ($vcenter_vmhost.Config.VsanHostConfig.ClusterInfo.NodeUuid) {
            try {
                $vcenter_vmhosts_h.add($vcenter_vmhost.MoRef.Value, $vcenter_vmhost)
                $vcenter_vmhosts_vsan_h.add($vcenter_vmhost.MoRef.Value, $vcenter_vmhost.configManager.vsanInternalSystem.value)
                $vcenter_vmhosts_name_h.add($vcenter_vmhost.name, $($vcenter_vmhost.config.network.dnsConfig.hostName).ToLower())
                if (!$vcenter_vsan_clusters_h[$vcenter_vmhost.parent.value]) {
                    if ($vcenter_clusters_h[$vcenter_vmhost.parent.value]) {
                        $vcenter_vsan_clusters_h.add($vcenter_vmhost.parent.value,$vcenter_clusters_h[$vcenter_vmhost.parent.value])
                    }
                }
            } catch {}
        }
    }

    if ($vcenter_vsan_clusters_h.Values.count -eq 0) {
        AltAndCatchFire "No vSAN cluster in vCenter $Server"
    }

    $vcenter_vms_h = @{}
    foreach ($vcenter_vm in $vcenter_vms) {
        try {
            $vcenter_vms_h.add($vcenter_vm.MoRef.Value, $vcenter_vm)
        } catch {}
    }

    $vcenter_vsan_ds_h = @{}
    foreach ($vcenter_vsan_d in $vcenter_vsan_ds) {
        try {
            $vcenter_vsan_ds_h.add($vcenter_vsan_d.info.ContainerId.replace("-",""),$vcenter_vsan_d.name)
        } catch {}
    }

	$xfolders_vcenter_name_h = @{}
	$xfolders_vcenter_parent_h = @{}
	$xfolders_vcenter_type_h = @{}

	Write-Host "$((Get-Date).ToString("o")) [INFO] vCenter objects relationship discover ..."
	
	foreach ($vcenter_xfolder in [array]$vcenter_datacenters + [array]$vcenter_folders + [array]$vcenter_clusters + [array]$vcenter_resource_pools + [array]$vcenter_vmhosts) {
		if (!$xfolders_vcenter_name_h[$vcenter_xfolder.moref.value]) {$xfolders_vcenter_name_h.add($vcenter_xfolder.moref.value,$vcenter_xfolder.name)}
		if (!$xfolders_vcenter_parent_h[$vcenter_xfolder.moref.value]) {$xfolders_vcenter_parent_h.add($vcenter_xfolder.moref.value,$vcenter_xfolder.Parent.value)}
		if (!$xfolders_vcenter_type_h[$vcenter_xfolder.moref.value]) {$xfolders_vcenter_type_h.add($vcenter_xfolder.moref.value,$vcenter_xfolder.moref.type)}
	}

    $ClusterPhysicalVsanDisks = [hashtable]::Synchronized(@{})
    $cluster_vdisks_id = [hashtable]::Synchronized(@{})
    $vsan_hosts_h = [hashtable]::Synchronized(@{})

    Write-Host "$((Get-Date).ToString("o")) [INFO] Start processing vSAN clusters ..."

    $vcenter_vsan_clusters_h.Values|foreach-object -Parallel {

        Import-Module -Name /usr/local/share/powershell/Modules/Graphite-PowerShell-Functions/Graphite-Powershell.psm1 -Global -Force -SkipEditionCheck
        Use-PowerCLIContext -PowerCLIContext $using:PwCliContext -SkipImportModuleChecks
        $function:AltAndCatchFire = $using:AltAndCatchFire
        $function:GetRootDc = $using:GetRootDc
        $function:NameCleaner = $using:NameCleaner
        $function:VmdkNameCleaner = $using:VmdkNameCleaner
        $function:GetParent = $using:GetParent
        $function:GetDomChild = $using:GetDomChild

        $VsanClusterHealthSystem = $using:VsanClusterHealthSystem
        $VsanSpaceReportSystem = $using:VsanSpaceReportSystem
        $VsanPerformanceManager = $using:VsanPerformanceManager

        $vcenter_resource_pools_owner_vms_h = $using:vcenter_resource_pools_owner_vms_h
        $ClusterPhysicalVsanDisks = $using:ClusterPhysicalVsanDisks
        $cluster_vdisks_id = $using:cluster_vdisks_id
        $VsanObjectSystem = $using:VsanObjectSystem
        $vcenter_name = $using:vcenter_name
        $vcenter_vms_h = $using:vcenter_vms_h
        $vcenter_vmhosts_h = $using:vcenter_vmhosts_h

        $xfolders_vcenter_name_h = $using:xfolders_vcenter_name_h
        $xfolders_vcenter_parent_h = $using:xfolders_vcenter_parent_h
        $xfolders_vcenter_type_h = $using:xfolders_vcenter_type_h

        $vsan_hosts_h  = $using:vsan_hosts_h 

        $vcenter_cluster = $_

        if (($vcenter_cluster.Host|Measure-Object).count -gt 0) {

            $cluster_name = NameCleaner $vcenter_cluster.Name
            $datacentre_name = NameCleaner $(GetRootDc $vcenter_cluster)

            [array]$cluster_hosts = @()
            foreach ($cluster_host in $vcenter_cluster.Host) {
                if ($vcenter_vmhosts_h[$cluster_host.Value]) {
                    $cluster_hosts += $vcenter_vmhosts_h[$cluster_host.Value]
                    $vsan_host = "" | Select-Object datacentre,cluster,host
                    $vsan_host.datacentre = $datacentre_name
                    $vsan_host.cluster = $cluster_name
                    $vsan_host.host = $vcenter_vmhosts_h[$cluster_host.Value]

                    $vsan_hosts_h.add($cluster_host.Value,$vsan_host)
                }
            }

            if ($cluster_hosts) {

                $cluster_host_random = $cluster_hosts|Get-Random -Count 1

                try {
                    $cluster_vsan_uuid = $cluster_host_random.Config.VsanHostConfig.ClusterInfo.Uuid
                    Write-Host "$((Get-Date).ToString("o")) [INFO] Start processing cluster $cluster_name $cluster_vsan_uuid in datacenter $datacentre_name ..."
                } catch {
                    AltAndCatchFire "Unable to retreive VsanHostConfig.ClusterInfo.Uuid from $($cluster_host_random.config.network.dnsConfig.hostName) in cluster $cluster_name"
                }

                if ($($using:ExecStart).Minute % 5 -eq 0 -and $cluster_host_random.Config.OptionDef.Key -match "VSAN.DedupScope") {
                    try {
                        Write-Host "$((Get-Date).ToString("o")) [INFO] Processing spaceUsageByObjectType in vSAN cluster $cluster_name (v6.2+) ..."

                        $ClusterVsanSpaceUsageReport = $VsanSpaceReportSystem.VsanQuerySpaceUsage($vcenter_cluster.Moref)
                        $ClusterVsanSpaceUsageReportObjList = $ClusterVsanSpaceUsageReport.spaceDetail.spaceUsageByObjectType
                        $ClusterVsanSpaceUsageReportObjType_h = @{}
                        $ClusterVsanSpaceUsageReportObjType_h.add("vsan.$vcenter_name.$datacentre_name.$cluster_name.vsan.spaceDetail.TotalCapacityB", $ClusterVsanSpaceUsageReport.TotalCapacityB)
                        $ClusterVsanSpaceUsageReportObjType_h.add("vsan.$vcenter_name.$datacentre_name.$cluster_name.vsan.spaceDetail.FreeCapacityB", $ClusterVsanSpaceUsageReport.FreeCapacityB)
                        foreach ($vsanObjType in $ClusterVsanSpaceUsageReportObjList) {
                            $ClusterVsanSpaceUsageReportObjType = $vsanObjType.objType
                            $ClusterVsanSpaceUsageReportObjType_h.add("vsan.$vcenter_name.$datacentre_name.$cluster_name.vsan.spaceDetail.spaceUsageByObjectType.$ClusterVsanSpaceUsageReportObjType.overheadB", $vsanObjType.overheadB)
                            $ClusterVsanSpaceUsageReportObjType_h.add("vsan.$vcenter_name.$datacentre_name.$cluster_name.vsan.spaceDetail.spaceUsageByObjectType.$ClusterVsanSpaceUsageReportObjType.physicalUsedB", $vsanObjType.physicalUsedB)
                            $ClusterVsanSpaceUsageReportObjType_h.add("vsan.$vcenter_name.$datacentre_name.$cluster_name.vsan.spaceDetail.spaceUsageByObjectType.$ClusterVsanSpaceUsageReportObjType.overReservedB", $vsanObjType.overReservedB)
                            $ClusterVsanSpaceUsageReportObjType_h.add("vsan.$vcenter_name.$datacentre_name.$cluster_name.vsan.spaceDetail.spaceUsageByObjectType.$ClusterVsanSpaceUsageReportObjType.usedB", $vsanObjType.usedB)
                            $ClusterVsanSpaceUsageReportObjType_h.add("vsan.$vcenter_name.$datacentre_name.$cluster_name.vsan.spaceDetail.spaceUsageByObjectType.$ClusterVsanSpaceUsageReportObjType.temporaryOverheadB", $vsanObjType.temporaryOverheadB)
                            $ClusterVsanSpaceUsageReportObjType_h.add("vsan.$vcenter_name.$datacentre_name.$cluster_name.vsan.spaceDetail.spaceUsageByObjectType.$ClusterVsanSpaceUsageReportObjType.primaryCapacityB", $vsanObjType.primaryCapacityB)
                            $ClusterVsanSpaceUsageReportObjType_h.add("vsan.$vcenter_name.$datacentre_name.$cluster_name.vsan.spaceDetail.spaceUsageByObjectType.$ClusterVsanSpaceUsageReportObjType.reservedCapacityB", $vsanObjType.reservedCapacityB)
                        }
                        # if ($ClusterVsanSpaceUsageReport.EfficientCapacity) {
                        #     $ClusterVsanSpaceUsageReportObjType_h.add("vsan.$vcenter_name.$datacentre_name.$cluster_name.vsan.EfficientCapacity.LogicalCapacity", $ClusterVsanSpaceUsageReport.EfficientCapacity.LogicalCapacity)
                        #     $ClusterVsanSpaceUsageReportObjType_h.add("vsan.$vcenter_name.$datacentre_name.$cluster_name.vsan.EfficientCapacity.LogicalCapacityUsed", $ClusterVsanSpaceUsageReport.EfficientCapacity.LogicalCapacityUsed)
                        #     $ClusterVsanSpaceUsageReportObjType_h.add("vsan.$vcenter_name.$datacentre_name.$cluster_name.vsan.EfficientCapacity.PhysicalCapacity", $ClusterVsanSpaceUsageReport.EfficientCapacity.PhysicalCapacity)
                        #     $ClusterVsanSpaceUsageReportObjType_h.add("vsan.$vcenter_name.$datacentre_name.$cluster_name.vsan.EfficientCapacity.PhysicalCapacityUsed", $ClusterVsanSpaceUsageReport.EfficientCapacity.PhysicalCapacityUsed)
                        #     if ($ClusterVsanSpaceUsageReport.EfficientCapacity.SpaceEfficiencyMetadataSize) {
                        #         $ClusterVsanSpaceUsageReportObjType_h.add("vsan.$vcenter_name.$datacentre_name.$cluster_name.vsan.SpaceEfficiencyMetadataSize.CompressionMetadataSize", $ClusterVsanSpaceUsageReport.EfficientCapacity.SpaceEfficiencyMetadataSize.CompressionMetadataSize)
                        #         $ClusterVsanSpaceUsageReportObjType_h.add("vsan.$vcenter_name.$datacentre_name.$cluster_name.vsan.SpaceEfficiencyMetadataSize.DedupMetadataSize", $ClusterVsanSpaceUsageReport.EfficientCapacity.SpaceEfficiencyMetadataSize.DedupMetadataSize)
                        #     } elseif ($ClusterVsanSpaceUsageReport.EfficientCapacity.DedupMetadataSize) {
                        #         $ClusterVsanSpaceUsageReportObjType_h.add("vsan.$vcenter_name.$datacentre_name.$cluster_name.vsan.SpaceEfficiencyMetadataSize.DedupMetadataSize", $ClusterVsanSpaceUsageReport.EfficientCapacity.DedupMetadataSize)
                        #     }
                        # }

                        Send-BulkGraphiteMetrics -CarbonServer 127.0.0.1 -CarbonServerPort 2003 -Metrics $ClusterVsanSpaceUsageReportObjType_h -DateTime $using:ExecStart

                    } catch {
                        Write-Host "$((Get-Date).ToString("o")) [WARNING] Unable to retreive VsanQuerySpaceUsage for cluster $cluster_name"
                        Write-Host "$((Get-Date).ToString("o")) [WARNING] $($Error[0])"
                    }

                }

                try {
                    if ($vcenter_resource_pools_owner_vms_h[$vcenter_cluster.moref.value]) {
                        Write-Host "$((Get-Date).ToString("o")) [INFO] Start processing VirtualDisk in cluster $cluster_name ..."
                        foreach ($cluster_vm_moref in $vcenter_resource_pools_owner_vms_h[$vcenter_cluster.moref.value]) {
                            foreach ($cluster_vm_vdisk in $vcenter_vms_h[$cluster_vm_moref.Value].Config.Hardware.Device|?{$_ -is [VMware.Vim.VirtualDisk] -and $_.Backing.BackingObjectId}) {
                                $cluster_vm_vdisk_base_name = VmdkNameCleaner $($cluster_vm_vdisk.Backing.FileName -split "[/.]")[1]
                                if (!$cluster_vdisks_id[$cluster_vm_vdisk.Backing.BackingObjectId]) {
                                    $cluster_vdisks_id.add($cluster_vm_vdisk.Backing.BackingObjectId, $cluster_vm_vdisk_base_name)
                                }

                                if ($cluster_vm_vdisk.Backing.Parent) {
                                    $cluster_vm_vdisk_parent = GetParent $cluster_vm_vdisk.Backing.Parent
                                    $cluster_vm_vdisk_parent_base_name = VmdkNameCleaner $($cluster_vm_vdisk_parent.FileName -split "[/.]")[1]
                                    if (!$cluster_vdisks_id[$($cluster_vm_vdisk.Backing.BackingObjectId + "_root")]) {
                                        $cluster_vdisks_id.add($($cluster_vm_vdisk.Backing.BackingObjectId + "_root"), $cluster_vm_vdisk_parent.BackingObjectId)
                                    }
                                    if (!$cluster_vdisks_id[$cluster_vm_vdisk_parent.BackingObjectId]) {
                                        $cluster_vdisks_id.add($cluster_vm_vdisk_parent.BackingObjectId, $cluster_vm_vdisk_parent_base_name)
                                    }
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
                    Write-Host "$((Get-Date).ToString("o")) [INFO] Start processing VsanInternalSystem from $($cluster_host_random.config.network.dnsConfig.hostName) in cluster $cluster_name ..."
                    $cluster_host_random_VsanInternalSystem = Get-View $cluster_host_random.ConfigManager.VsanInternalSystem -Server $Server
                } catch {
                    AltAndCatchFire "Unable to retreive VsanInternalSystem from $($cluster_host_random.config.network.dnsConfig.hostName) in cluster $cluster_name"
                }

                try {
                    Write-Host "$((Get-Date).ToString("o")) [INFO] Start processing PhysicalVsanDisks from $($cluster_host_random.config.network.dnsConfig.hostName) in cluster $cluster_name ..."
                    $cluster_PhysicalVsanDisks = $cluster_host_random_VsanInternalSystem.QueryPhysicalVsanDisks("devName")|ConvertFrom-Json -AsHashtable
                    $ClusterPhysicalVsanDisks.add($cluster_name,$cluster_PhysicalVsanDisks)
                } catch {
                    AltAndCatchFire "Unable to retreive PhysicalVsanDisks from $($cluster_host_random.config.network.dnsConfig.hostName) in cluster $cluster_name"
                }

                if ($cluster_host_random.Config.Product.ApiVersion -ge 6.7) {
                    try {
                        Write-Host "$((Get-Date).ToString("o")) [INFO] Start processing SyncingVsanObjectsSummary in cluster $cluster_name (v6.7+) ..."
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
                                    # Send-GraphiteMetric -CarbonServer 127.0.0.1 -CarbonServerPort 2003 -MetricPath "vsan.$vcenter_name.$datacentre_name.$cluster_name.vsan.SyncingVsanObjects.bytesToSync.$ReasonToSync" -MetricValue $ReasonsToSync.$ReasonToSync -DateTime $using:ExecStart
                                    $ReasonsToSyncHash.add("vsan.$vcenter_name.$datacentre_name.$cluster_name.vsan.SyncingVsanObjects.bytesToSync.$ReasonToSync",$ReasonsToSync.$ReasonToSync)
                                }

                                Send-BulkGraphiteMetrics -CarbonServer 127.0.0.1 -CarbonServerPort 2003 -Metrics $ReasonsToSyncHash -DateTime $using:ExecStart
                            }

                            $SyncingVsanObjectsHash = @{
                                "vsan.$vcenter_name.$datacentre_name.$cluster_name.vsan.SyncingVsanObjects.totalRecoveryETA" = $QuerySyncingVsanObjectsSummary.TotalRecoveryETA;
                                "vsan.$vcenter_name.$datacentre_name.$cluster_name.vsan.SyncingVsanObjects.totalBytesToSync" = $QuerySyncingVsanObjectsSummary.TotalBytesToSync;
                                "vsan.$vcenter_name.$datacentre_name.$cluster_name.vsan.SyncingVsanObjects.totalObjectsToSync" = $QuerySyncingVsanObjectsSummary.TotalObjectsToSync;
                                "vsan.$vcenter_name.$datacentre_name.$cluster_name.vsan.SyncingVsanObjects.totalComponentsToSync" = ($QuerySyncingVsanObjectsSummary.Objects.Components|Measure-Object -sum).count;
                            }

                            Send-BulkGraphiteMetrics -CarbonServer 127.0.0.1 -CarbonServerPort 2003 -Metrics $SyncingVsanObjectsHash -DateTime $using:ExecStart
                        }
                    } catch {
                        Write-Host "$((Get-Date).ToString("o")) [WARNING] Unable to retreive SyncingVsanObjectsSummary in cluster $cluster_name"
                        Write-Host "$((Get-Date).ToString("o")) [WARNING] $($Error[0])"
                    }

                    if ($($using:ExecStart).Minute % 5 -eq 0) {
                        try { 
                            Write-Host "$((Get-Date).ToString("o")) [INFO] Start processing SmartStatsSummary in cluster $cluster_name (v6.7+) ..."
                            # https://www.virtuallyghetto.com/2017/04/getting-started-wthe-new-powercli-6-5-1-get-vsanview-cmdlet.html
                            # https://github.com/lamw/vghetto-scripts/blob/master/powershell/VSANSmartsData.ps1
                            $VcClusterSmartStatsSummary = $VsanClusterHealthSystem.VsanQueryVcClusterSmartStatsSummary($vcenter_cluster.moref)
                            if ($VcClusterSmartStatsSummary.SmartStats) {
                                $VcClusterSmartStatsSummary_h = @{}
                                foreach ($SmartStatsEsx in $VcClusterSmartStatsSummary) {
                                    $SmartStatsEsxName = $($using:vcenter_vmhosts_name_h)[$SmartStatsEsx.Hostname]
                                    foreach ($SmartStatsEsxDisk in $SmartStatsEsx.SmartStats) {
                                        $SmartStatsEsxDiskName = NameCleaner $SmartStatsEsxDisk.Disk
                                        foreach ($SmartStatsEsxDiskStats in $SmartStatsEsxDisk.Stats|?{$_.Value -ne $null}) {
                                            if ($SmartStatsEsxDiskStats.Parameter -and !$VcClusterSmartStatsSummary_h["vsan.$vcenter_name.$datacentre_name.$cluster_name.esx.$SmartStatsEsxName.vsan.disks.smart.$SmartStatsEsxDiskName.$($SmartStatsEsxDiskStats.Parameter)"]) {
                                                $VcClusterSmartStatsSummary_h.add("vsan.$vcenter_name.$datacentre_name.$cluster_name.esx.$SmartStatsEsxName.vsan.disks.smart.$SmartStatsEsxDiskName.$($SmartStatsEsxDiskStats.Parameter)", $($SmartStatsEsxDiskStats.Value))
                                            }
                                        }
                                    }
                                }

                                Send-BulkGraphiteMetrics -CarbonServer 127.0.0.1 -CarbonServerPort 2003 -Metrics $VcClusterSmartStatsSummary_h -DateTime $using:ExecStart
                            }
                        } catch {
                            Write-Host "$((Get-Date).ToString("o")) [WARNING] Unable to retreive VcClusterSmartStatsSummary in cluster $cluster_name"
                            Write-Host "$((Get-Date).ToString("o")) [WARNING] $($Error[0])"
                        }

                        # try { 
                        #     Write-Host "$((Get-Date).ToString("o")) [INFO] Start processing VsanPerfQuery in cluster $cluster_name (v6.7+) ..."
                        #     # https://vdc-download.vmware.com/vmwb-repository/dcr-public/b21ba11d-4748-4796-97e2-7000e2543ee1/b4a40704-fbca-4222-902c-2500f5a90f3f/vim.cluster.VsanPerformanceManager.html#queryVsanPerf
                        #     $VsanClusterPerfQuerySpec = New-Object VMware.Vsan.Views.VsanPerfQuerySpec -property @{endTime=$($using:ExecStart);entityRefId="cluster-domclient:$cluster_vsan_uuid";labels="*";startTime=$($using:ExecStart).AddMinutes(-5)} 
                        #     # MethodInvocationException: Exception calling "VsanPerfQueryPerf" with "2" argument(s): "Invalid Argument. Only one wildcard query allowed in query specs." # Config.VsanHostConfig.ClusterInfo.NodeUuid
                        #     $VsanClusterPerfQuery = $VsanPerformanceManager.VsanPerfQueryPerf($VsanClusterPerfQuerySpec,$vcenter_cluster.moref)
                        #     $VsanClusterPerfQueryId = @{}
                        #     foreach ($VsanClusterPerfQueryValue in $VsanClusterPerfQuery.Value) {
                        #         $VsanClusterPerfQueryId.add($VsanClusterPerfQueryValue.MetricId.Label,$VsanClusterPerfQueryValue.Values)
                        #     }
                        #     $VsanClusterPerfMaxLatency = $(@($VsanClusterPerfQueryId["latencyAvgRead"],$VsanClusterPerfQueryId["latencyAvgWrite"])|Measure-Object -Maximum).Maximum
                        #     $VsanClusterPerfIops = $(@($VsanClusterPerfQueryId["iopsWrite"],$VsanClusterPerfQueryId["iopsRead"])|Measure-Object -Sum).Sum
                        #     $cluster_vsan_name = NameCleaner $($using:vcenter_vsan_ds_h)[$cluster_vsan_uuid.replace("-","")]
                        #     $VsanClusterPerf_h = @{
                        #         "vmw.$vcenter_name.$datacentre_name.$cluster_name.datastore.$cluster_vsan_name.iorm.datastoreIops" = $VsanClusterPerfIops;
                        #         "vmw.$vcenter_name.$datacentre_name.$cluster_name.datastore.$cluster_vsan_name.iorm.sizeNormalizedDatastoreLatency" = $VsanClusterPerfMaxLatency;
                        #     }
                        #     if ($VsanClusterPerf_h) {
                        #         Send-BulkGraphiteMetrics -CarbonServer 127.0.0.1 -CarbonServerPort 2003 -Metrics $VsanClusterPerf_h -DateTime $using:ExecStart
                        #     }
                        # } catch {
                        #     Write-Host "$((Get-Date).ToString("o")) [WARNING] Unable to retreive VsanPerfQuery in cluster $cluster_name"
                        #     Write-Host "$((Get-Date).ToString("o")) [WARNING] $($Error[0])"
                        # }
                    }
                } else {
                    try {
                        Write-Host "$((Get-Date).ToString("o")) [INFO] Start processing SyncingVsanObjects from $($cluster_host_random.config.network.dnsConfig.hostName) in cluster $cluster_name ..."
                        $cluster_SyncingVsanObjects = $cluster_host_random_VsanInternalSystem.QuerySyncingVsanObjects(@())|ConvertFrom-Json -AsHashtable
                        if ($cluster_SyncingVsanObjects."dom_objects".keys) {
                            Write-Host "$((Get-Date).ToString("o")) [DEBUG] Start processing SyncingVsanObjects dom_objects from $($cluster_host_random.config.network.dnsConfig.hostName) in cluster $cluster_name ..."
                            $SyncingVsanObjects = ""|Select-Object bytesToSync, recoveryETA, Objs
                            $SyncingVsanObjects.recoveryETA = 0
                            foreach ($cluster_SyncingVsanObjects_dom in $($cluster_SyncingVsanObjects."dom_objects").keys) {
                                GetDomChild $($cluster_SyncingVsanObjects."dom_objects")[$cluster_SyncingVsanObjects_dom].config.content $SyncingVsanObjects
                            }
                            if ($SyncingVsanObjects.Objs -gt 0 -and $SyncingVsanObjects.recoveryETA -gt 0) {
                                $SyncingVsanObjects.recoveryETA = $SyncingVsanObjects.recoveryETA / $SyncingVsanObjects.Objs
                            }
                            $SyncingVsanObjectsHash = @{
                                "vsan.$vcenter_name.$datacentre_name.$cluster_name.vsan.SyncingVsanObjects.totalRecoveryETA" = $SyncingVsanObjects.recoveryETA;
                                "vsan.$vcenter_name.$datacentre_name.$cluster_name.vsan.SyncingVsanObjects.totalBytesToSync" = $SyncingVsanObjects.bytesToSync;
                                "vsan.$vcenter_name.$datacentre_name.$cluster_name.vsan.SyncingVsanObjects.totalObjectsToSync" = $SyncingVsanObjects.Objs;
                            }

                            Send-BulkGraphiteMetrics -CarbonServer 127.0.0.1 -CarbonServerPort 2003 -Metrics $SyncingVsanObjectsHash -DateTime $using:ExecStart
                        }
                    } catch {
                        Write-Host "$((Get-Date).ToString("o")) [WARNING] Unable to retreive SyncingVsanObjects from $($cluster_host_random.config.network.dnsConfig.hostName) in cluster $cluster_name"
                        Write-Host "$((Get-Date).ToString("o")) [WARNING] $($Error[0])"
                    }
                }

                try {
                    Write-Host "$((Get-Date).ToString("o")) [INFO] Start processing VsanObjectIdentityAndHealth in cluster $cluster_name ..."
                    $vcenter_cluster_ObjectIdentities = $VsanObjectSystem.VsanQueryObjectIdentities($vcenter_cluster.moref,$null,$null,$true,$false,$false)
                    if ($vcenter_cluster_ObjectIdentities.Health.ObjectHealthDetail) {
                        $VcClusterObjectHealthDetail_h = @{}
                        foreach ($ObjectHealth in $vcenter_cluster_ObjectIdentities.Health.ObjectHealthDetail) {
                            if ($ObjectHealth.NumObjects -gt 0) {
                                $VcClusterObjectHealthDetail_h.add("vsan.$vcenter_name.$datacentre_name.$cluster_name.vsan.ObjectHealthDetail.$($ObjectHealth.Health)", $($ObjectHealth.NumObjects))
                            }
                        }

                        Send-BulkGraphiteMetrics -CarbonServer 127.0.0.1 -CarbonServerPort 2003 -Metrics $VcClusterObjectHealthDetail_h -DateTime $using:ExecStart
                    }
                } catch{
                    Write-Host "$((Get-Date).ToString("o")) [WARNING] Unable to retreive VsanObjectIdentityAndHealth from cluster $cluster_name"
                    Write-Host "$((Get-Date).ToString("o")) [WARNING] $($Error[0])"
                }

                Write-Host "$((Get-Date).ToString("o")) [INFO] End processing cluster $cluster_name in datacenter $datacentre_name"
            }
        }
    } -ThrottleLimit 4 -TimeoutSeconds 10

    Write-Host "$((Get-Date).ToString("o")) [INFO] Start processing vSAN hosts ..."

    $vsan_hosts_h.keys|foreach-object -Parallel {

        Import-Module -Name /usr/local/share/powershell/Modules/Graphite-PowerShell-Functions/Graphite-Powershell.psm1 -Global -Force -SkipEditionCheck
        Use-PowerCLIContext -PowerCLIContext $using:PwCliContext -SkipImportModuleChecks
        $function:AltAndCatchFire = $using:AltAndCatchFire
        $function:GetRootDc = $using:GetRootDc
        $function:NameCleaner = $using:NameCleaner
        $function:VmdkNameCleaner = $using:VmdkNameCleaner
        $function:GetParent = $using:GetParent
        $function:GetDomChild = $using:GetDomChild
    
        $vsan_hosts_h  = $using:vsan_hosts_h 

        $cluster_host = $vsan_hosts_h[$_].host
        $vcenter_name = $($using:vcenter_name)
        $datacentre_name = $vsan_hosts_h[$_].datacentre
        $cluster_name = $vsan_hosts_h[$_].cluster
        $ClusterPhysicalVsanDisks = $($using:ClusterPhysicalVsanDisks)
        $cluster_vdisks_id = $($using:cluster_vdisks_id)
    
        Write-Host "$((Get-Date).ToString("o")) [INFO] Start processing QueryVsanStatistics from $($cluster_host.config.network.dnsConfig.hostName) in cluster $cluster_name ..."
        $host_name = $($cluster_host.config.network.dnsConfig.hostName).ToLower()
    
        try {
            $cluster_host_vsanInternalSystem = Get-View $cluster_host.configManager.vsanInternalSystem -Server $Server
            $cluster_host_VsanStatistics = $cluster_host_vsanInternalSystem.QueryVsanStatistics(@('dom-objects', 'dom', 'lsom', 'disks', 'tcpip'))|ConvertFrom-Json -AsHashtable
    
            # 'worldlets', 'plog', 'mem', 'cpus', 'slabs', 'vscsi', 'cbrc', 'rdtassocsets',  'system-mem', 'pnics', 'rdtglobal', 'lsom-node', 'dom-objects-counts'
    
            $cluster_host_VsanStatistics_h = @{}
    
            foreach ($cluster_host_VsanStatistics_compmgr_stats in $cluster_host_VsanStatistics['dom.compmgr.stats'].keys|?{$_ -notmatch "Histogram"}) {
                $cluster_host_VsanStatistics_h.add("vsan.$vcenter_name.$datacentre_name.$cluster_name.esx.$host_name.vsan.compmgr.stats.$cluster_host_VsanStatistics_compmgr_stats", $cluster_host_VsanStatistics['dom.compmgr.stats'].$cluster_host_VsanStatistics_compmgr_stats)
            }
    
            foreach ($cluster_host_VsanStatistics_client_stats in $cluster_host_VsanStatistics['dom.client.stats'].keys) {
                $cluster_host_VsanStatistics_h.add("vsan.$vcenter_name.$datacentre_name.$cluster_name.esx.$host_name.vsan.client.stats.$cluster_host_VsanStatistics_client_stats", $cluster_host_VsanStatistics['dom.client.stats'].$cluster_host_VsanStatistics_client_stats)
            }
    
            foreach ($cluster_host_VsanStatistics_owner_stats in $cluster_host_VsanStatistics['dom.owner.stats'].keys) {
                $cluster_host_VsanStatistics_h.add("vsan.$vcenter_name.$datacentre_name.$cluster_name.esx.$host_name.vsan.owner.stats.$cluster_host_VsanStatistics_owner_stats", $cluster_host_VsanStatistics['dom.owner.stats'].$cluster_host_VsanStatistics_owner_stats)
            }
    
            foreach ($cluster_host_VsanStatistics_cachestats in $cluster_host_VsanStatistics['dom.client.cachestats'].keys) {
                $cluster_host_VsanStatistics_h.add("vsan.$vcenter_name.$datacentre_name.$cluster_name.esx.$host_name.vsan.client.cachestats.$cluster_host_VsanStatistics_cachestats", $cluster_host_VsanStatistics['dom.client.cachestats'].$cluster_host_VsanStatistics_cachestats)
            }
    
            foreach ($cluster_host_VsanStatistics_tcpstats in $cluster_host_VsanStatistics['tcpip.stats.tcp'].keys) {
                $cluster_host_VsanStatistics_h.add("vsan.$vcenter_name.$datacentre_name.$cluster_name.esx.$host_name.vsan.tcpip.stats.$cluster_host_VsanStatistics_tcpstats", $cluster_host_VsanStatistics['tcpip.stats.tcp'].$cluster_host_VsanStatistics_tcpstats)
            }
    
            foreach ($cluster_host_VsanStatistics_lsom_disks in $cluster_host_VsanStatistics['lsom.disks'].keys) {
                try {
                    if ($cluster_host_VsanStatistics['lsom.disks'].$cluster_host_VsanStatistics_lsom_disks.info.ssd -ne "NA" -and $cluster_host_VsanStatistics['lsom.disks'].$cluster_host_VsanStatistics_lsom_disks.info.capacity -gt 0) {
                        $cluster_host_VsanStatistics_lsom_disks_pct = $cluster_host_VsanStatistics['lsom.disks'].$cluster_host_VsanStatistics_lsom_disks.info.capacityUsed * 100 / $cluster_host_VsanStatistics['lsom.disks'].$cluster_host_VsanStatistics_lsom_disks.info.capacity
                        $cluster_host_VsanStatistics_lsom_disks_ssd = $ClusterPhysicalVsanDisks[$cluster_name][$cluster_host_VsanStatistics['lsom.disks'].$cluster_host_VsanStatistics_lsom_disks.info.ssd]["devName"]
                        if ($cluster_host_VsanStatistics_lsom_disks_ssd) {
                            $cluster_host_VsanStatistics_lsom_disks_ssd_clean_naa = $($cluster_host_VsanStatistics_lsom_disks_ssd -split "[.]",2 -split "[:]" -replace "[.]","_")[1]
                            $cluster_host_VsanStatistics_h.add("vsan.$vcenter_name.$datacentre_name.$cluster_name.esx.$host_name.vsan.lsom.disks.$cluster_host_VsanStatistics_lsom_disks.capacityUsed", $cluster_host_VsanStatistics['lsom.disks'].$cluster_host_VsanStatistics_lsom_disks.info.capacityUsed)
                            $cluster_host_VsanStatistics_h.add("vsan.$vcenter_name.$datacentre_name.$cluster_name.esx.$host_name.vsan.lsom.disks.$cluster_host_VsanStatistics_lsom_disks.capacity", $cluster_host_VsanStatistics['lsom.disks'].$cluster_host_VsanStatistics_lsom_disks.info.capacity)
                            $cluster_host_VsanStatistics_h.add("vsan.$vcenter_name.$datacentre_name.$cluster_name.esx.$host_name.vsan.lsom.disks.$cluster_host_VsanStatistics_lsom_disks.percentUsed", $cluster_host_VsanStatistics_lsom_disks_pct)
                            $cluster_host_VsanStatistics_h.add("vsan.$vcenter_name.$datacentre_name.$cluster_name.esx.$host_name.vsan.lsom.diskgroup.$cluster_host_VsanStatistics_lsom_disks_ssd_clean_naa.$cluster_host_VsanStatistics_lsom_disks.percentUsed", $cluster_host_VsanStatistics_lsom_disks_pct)
                        }
                    } elseif ($cluster_host_VsanStatistics['lsom.disks'].$cluster_host_VsanStatistics_lsom_disks.info.ssd -eq "NA" -and $cluster_host_VsanStatistics['lsom.disks'].$cluster_host_VsanStatistics_lsom_disks.info.capacity -gt 0) {
                        $cluster_host_VsanStatistics_h.add("vsan.$vcenter_name.$datacentre_name.$cluster_name.esx.$host_name.vsan.lsom.ssd.$cluster_host_VsanStatistics_lsom_disks.miss", $cluster_host_VsanStatistics['lsom.disks'].$cluster_host_VsanStatistics_lsom_disks.info.aggStats.miss)
                        $cluster_host_VsanStatistics_h.add("vsan.$vcenter_name.$datacentre_name.$cluster_name.esx.$host_name.vsan.lsom.ssd.$cluster_host_VsanStatistics_lsom_disks.quotaEvictions", $cluster_host_VsanStatistics['lsom.disks'].$cluster_host_VsanStatistics_lsom_disks.info.aggStats.quotaEvictions)
                        $cluster_host_VsanStatistics_h.add("vsan.$vcenter_name.$datacentre_name.$cluster_name.esx.$host_name.vsan.lsom.ssd.$cluster_host_VsanStatistics_lsom_disks.readIoCount", $cluster_host_VsanStatistics['lsom.disks'].$cluster_host_VsanStatistics_lsom_disks.info.aggStats.readIoCount)
                        $cluster_host_VsanStatistics_h.add("vsan.$vcenter_name.$datacentre_name.$cluster_name.esx.$host_name.vsan.lsom.ssd.$cluster_host_VsanStatistics_lsom_disks.wbSize", $cluster_host_VsanStatistics['lsom.disks'].$cluster_host_VsanStatistics_lsom_disks.info.wbSize)
                        $cluster_host_VsanStatistics_h.add("vsan.$vcenter_name.$datacentre_name.$cluster_name.esx.$host_name.vsan.lsom.ssd.$cluster_host_VsanStatistics_lsom_disks.wbFreeSpace", $cluster_host_VsanStatistics['lsom.disks'].$cluster_host_VsanStatistics_lsom_disks.info.wbFreeSpace)
                        $cluster_host_VsanStatistics_h.add("vsan.$vcenter_name.$datacentre_name.$cluster_name.esx.$host_name.vsan.lsom.ssd.$cluster_host_VsanStatistics_lsom_disks.writeIoCount", $cluster_host_VsanStatistics['lsom.disks'].$cluster_host_VsanStatistics_lsom_disks.info.aggStats.writeIoCount)
                        $cluster_host_VsanStatistics_h.add("vsan.$vcenter_name.$datacentre_name.$cluster_name.esx.$host_name.vsan.lsom.ssd.$cluster_host_VsanStatistics_lsom_disks.bytesRead", $cluster_host_VsanStatistics['lsom.disks'].$cluster_host_VsanStatistics_lsom_disks.info.aggStats.bytesRead)
                        $cluster_host_VsanStatistics_h.add("vsan.$vcenter_name.$datacentre_name.$cluster_name.esx.$host_name.vsan.lsom.ssd.$cluster_host_VsanStatistics_lsom_disks.bytesWritten", $cluster_host_VsanStatistics['lsom.disks'].$cluster_host_VsanStatistics_lsom_disks.info.aggStats.bytesWritten)
                        $cluster_host_VsanStatistics_h.add("vsan.$vcenter_name.$datacentre_name.$cluster_name.esx.$host_name.vsan.lsom.ssd.$cluster_host_VsanStatistics_lsom_disks.capacityUsed", $cluster_host_VsanStatistics['lsom.disks'].$cluster_host_VsanStatistics_lsom_disks.info.capacityUsed)
                        $cluster_host_VsanStatistics_h.add("vsan.$vcenter_name.$datacentre_name.$cluster_name.esx.$host_name.vsan.lsom.ssd.$cluster_host_VsanStatistics_lsom_disks.capacity", $cluster_host_VsanStatistics['lsom.disks'].$cluster_host_VsanStatistics_lsom_disks.info.capacity)
                    }
                } catch {}
            }
    
            foreach ($cluster_host_VsanStatistics_owners_stats in $cluster_host_VsanStatistics['dom.owners.stats'].keys) {
                try {
                    if ($cluster_vdisks_id[$cluster_host_VsanStatistics_owners_stats]) {
                        if ($cluster_vdisks_id["$cluster_host_VsanStatistics_owners_stats" + "_root"]) {
                            $cluster_host_VsanStatistics_h.add("vsan.$vcenter_name.$datacentre_name.$cluster_name.vsan.dom.owners.stats.$($cluster_vdisks_id["$cluster_host_VsanStatistics_owners_stats" + "_root"]).$($cluster_vdisks_id[$cluster_host_VsanStatistics_owners_stats]).readCount", $cluster_host_VsanStatistics['dom.owners.stats'].$cluster_host_VsanStatistics_owners_stats.readCount)
                            $cluster_host_VsanStatistics_h.add("vsan.$vcenter_name.$datacentre_name.$cluster_name.vsan.dom.owners.stats.$($cluster_vdisks_id["$cluster_host_VsanStatistics_owners_stats" + "_root"]).$($cluster_vdisks_id[$cluster_host_VsanStatistics_owners_stats]).writeCount", $cluster_host_VsanStatistics['dom.owners.stats'].$cluster_host_VsanStatistics_owners_stats.writeCount)
                            $cluster_host_VsanStatistics_h.add("vsan.$vcenter_name.$datacentre_name.$cluster_name.vsan.dom.owners.stats.$($cluster_vdisks_id["$cluster_host_VsanStatistics_owners_stats" + "_root"]).$($cluster_vdisks_id[$cluster_host_VsanStatistics_owners_stats]).readBytes", $cluster_host_VsanStatistics['dom.owners.stats'].$cluster_host_VsanStatistics_owners_stats.readBytes)
                            $cluster_host_VsanStatistics_h.add("vsan.$vcenter_name.$datacentre_name.$cluster_name.vsan.dom.owners.stats.$($cluster_vdisks_id["$cluster_host_VsanStatistics_owners_stats" + "_root"]).$($cluster_vdisks_id[$cluster_host_VsanStatistics_owners_stats]).writeBytes", $cluster_host_VsanStatistics['dom.owners.stats'].$cluster_host_VsanStatistics_owners_stats.writeBytes)
                        } else {
                            $cluster_host_VsanStatistics_h.add("vsan.$vcenter_name.$datacentre_name.$cluster_name.vsan.dom.owners.stats.$cluster_host_VsanStatistics_owners_stats.$($cluster_vdisks_id[$cluster_host_VsanStatistics_owners_stats]).readCount", $cluster_host_VsanStatistics['dom.owners.stats'].$cluster_host_VsanStatistics_owners_stats.readCount)
                            $cluster_host_VsanStatistics_h.add("vsan.$vcenter_name.$datacentre_name.$cluster_name.vsan.dom.owners.stats.$cluster_host_VsanStatistics_owners_stats.$($cluster_vdisks_id[$cluster_host_VsanStatistics_owners_stats]).writeCount", $cluster_host_VsanStatistics['dom.owners.stats'].$cluster_host_VsanStatistics_owners_stats.writeCount)
                            $cluster_host_VsanStatistics_h.add("vsan.$vcenter_name.$datacentre_name.$cluster_name.vsan.dom.owners.stats.$cluster_host_VsanStatistics_owners_stats.$($cluster_vdisks_id[$cluster_host_VsanStatistics_owners_stats]).readBytes", $cluster_host_VsanStatistics['dom.owners.stats'].$cluster_host_VsanStatistics_owners_stats.readBytes)
                            $cluster_host_VsanStatistics_h.add("vsan.$vcenter_name.$datacentre_name.$cluster_name.vsan.dom.owners.stats.$cluster_host_VsanStatistics_owners_stats.$($cluster_vdisks_id[$cluster_host_VsanStatistics_owners_stats]).writeBytes", $cluster_host_VsanStatistics['dom.owners.stats'].$cluster_host_VsanStatistics_owners_stats.writeBytes)
                        }
                    }
                } catch {}
            }
    
            foreach ($cluster_host_VsanStatistics_disks_stats in $cluster_host_VsanStatistics['disks.stats'].keys) {
                $cluster_host_VsanStatistics_h.add("vsan.$vcenter_name.$datacentre_name.$cluster_name.esx.$host_name.vsan.disks.stats.$cluster_host_VsanStatistics_disks_stats.totalTimeWrites", $cluster_host_VsanStatistics['disks.stats'].$cluster_host_VsanStatistics_disks_stats.latency.totalTimeWrites)
                $cluster_host_VsanStatistics_h.add("vsan.$vcenter_name.$datacentre_name.$cluster_name.esx.$host_name.vsan.disks.stats.$cluster_host_VsanStatistics_disks_stats.totalTimeReads", $cluster_host_VsanStatistics['disks.stats'].$cluster_host_VsanStatistics_disks_stats.latency.totalTimeReads)
                $cluster_host_VsanStatistics_h.add("vsan.$vcenter_name.$datacentre_name.$cluster_name.esx.$host_name.vsan.disks.stats.$cluster_host_VsanStatistics_disks_stats.queueTimeWrites", $cluster_host_VsanStatistics['disks.stats'].$cluster_host_VsanStatistics_disks_stats.latency.queueTimeWrites)
                $cluster_host_VsanStatistics_h.add("vsan.$vcenter_name.$datacentre_name.$cluster_name.esx.$host_name.vsan.disks.stats.$cluster_host_VsanStatistics_disks_stats.queueTimeReads", $cluster_host_VsanStatistics['disks.stats'].$cluster_host_VsanStatistics_disks_stats.latency.queueTimeReads)
                $cluster_host_VsanStatistics_h.add("vsan.$vcenter_name.$datacentre_name.$cluster_name.esx.$host_name.vsan.disks.stats.$cluster_host_VsanStatistics_disks_stats.readOps", $cluster_host_VsanStatistics['disks.stats'].$cluster_host_VsanStatistics_disks_stats.readOps)
                $cluster_host_VsanStatistics_h.add("vsan.$vcenter_name.$datacentre_name.$cluster_name.esx.$host_name.vsan.disks.stats.$cluster_host_VsanStatistics_disks_stats.writeOps", $cluster_host_VsanStatistics['disks.stats'].$cluster_host_VsanStatistics_disks_stats.writeOps)
            }
    
            Send-BulkGraphiteMetrics -CarbonServer 127.0.0.1 -CarbonServerPort 2003 -Metrics $cluster_host_VsanStatistics_h -DateTime $using:ExecStart
    
        } catch {
            Write-Host "$((Get-Date).ToString("o")) [WARNING] Unable to retreive QueryVsanStatistics from $host_name in cluster $cluster_name"
            Write-Host "$((Get-Date).ToString("o")) [WARNING] $($Error[0])"
        }
    } -ThrottleLimit 10
    
    $ExecDuration = $($(Get-Date) - $ExecStart).TotalSeconds.ToString().Split(".")[0]
    $ExecStartEpoc = $(New-TimeSpan -Start (Get-Date -Date "01/01/1970") -End $ExecStart).TotalSeconds.ToString().Split(".")[0]

    Send-GraphiteMetric -CarbonServer 127.0.0.1 -CarbonServerPort 2003 -MetricPath "vi.$vcenter_name.vsan.exec.duration" -MetricValue $ExecDuration -UnixTime $ExecStartEpoc

    Write-Host "$((Get-Date).ToString("o")) [INFO] End processing vCenter $Server ..."

} else {
    AltAndCatchFire "$Server is not a vcenter!"
}
