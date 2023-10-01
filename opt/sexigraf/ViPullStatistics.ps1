#!/usr/bin/pwsh -Command
#
param([Parameter (Mandatory=$true)] [string] $Server, [Parameter (Mandatory=$true)] [string] $SessionFile, [Parameter (Mandatory=$false)] [string] $CredStore)

$ScriptVersion = "0.9.1028"

$ExecStart = $(Get-Date).ToUniversalTime()
# $stopwatch =  [system.diagnostics.stopwatch]::StartNew()

$ErrorActionPreference = "SilentlyContinue"
$WarningPreference = "SilentlyContinue"
(Get-Process -Id $pid).PriorityClass = 'Idle'

function AltAndCatchFire {
    Param($ExitReason)
    Write-Host "$((Get-Date).ToString("o")) [EROR] $ExitReason"
    Write-Host "$((Get-Date).ToString("o")) [EROR] $($Error[0])"
    Write-Host "$((Get-Date).ToString("o")) [EROR] Exit"
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
    return $NameToClean.ToLower()
}

function GetParent {
    param ($parent)
    if ($parent.Parent) {
        GetParent $parent.Parent
    } else {
        return $parent
    }
}

function GetMedian {
    param($numberSeries)
    if ($($numberSeries|Measure-Object).count -gt 1) {
        $sortedNumbers = @($numberSeries | Sort-Object)
        if ($numberSeries.Count % 2) {
            return $sortedNumbers[($sortedNumbers.Count / 2) - 1]
        } else {
            return ($sortedNumbers[($sortedNumbers.Count / 2)] + $sortedNumbers[($sortedNumbers.Count / 2) - 1]) / 2
        }
    } else {
        return $numberSeries
    }
}
# https://www.powershellgallery.com/packages/Formulaic/0.2.1.0/Content/Get-Median.ps1

function MultiQueryPerfAll {
    param($query_entity_views, $query_perfCntrs)
    [ARRAY]$PerfMetrics = $(foreach ($query_perfCntr in $query_perfCntrs) {
        New-Object VMware.Vim.PerfMetricId -Property @{counterId=$PerfCounterTable[$query_perfCntr];instance='*'}
    })
    [ARRAY]$PerfQuerySpecs = $(foreach ($query_entity_view in $query_entity_views) {
        New-Object VMware.Vim.PerfQuerySpec -Property @{entity=$query_entity_view;maxSample="15";intervalId="20";metricId=$PerfMetrics}
    })
    $metrics = $PerformanceManager.QueryPerf($PerfQuerySpecs)
    # https://kb.vmware.com/s/article/2107096
    $fatmetrics = @{}
    foreach ($metric in $metrics) {
        foreach ($metricValue in $metric.value) {
            if(!$fatmetrics[$($metricValue.id.counterId)]) {
                $fatmetrics[$($metricValue.id.counterId)] = @{}
                if (!$fatmetrics[$($metricValue.id.counterId)][$($metric.Entity.Value)]) {
                    $fatmetrics[$($metricValue.id.counterId)][$($metric.Entity.Value)] = @{}
                    $fatmetrics[$($metricValue.id.counterId)][$($metric.Entity.Value)][$($metricValue.id.instance)] = $(GetMedian $metricValue.value)
                } else {
                    $fatmetrics[$($metricValue.id.counterId)][$($metric.Entity.Value)][$($metricValue.id.instance)] = $(GetMedian $metricValue.value)
                }
            } else {
                if (!$fatmetrics[$($metricValue.id.counterId)][$($metric.Entity.Value)]) {
                    $fatmetrics[$($metricValue.id.counterId)][$($metric.Entity.Value)] = @{}
                    $fatmetrics[$($metricValue.id.counterId)][$($metric.Entity.Value)][$($metricValue.id.instance)] = $(GetMedian $metricValue.value)
                } else {
                    $fatmetrics[$($metricValue.id.counterId)][$($metric.Entity.Value)][$($metricValue.id.instance)] = $(GetMedian $metricValue.value)
                }
            }
        }
        # https://stackoverflow.com/questions/60687333/sort-a-nested-hash-table-by-value
    }
    return $fatmetrics
}

function MultiQueryPerf {
    param($query_entity_views, $query_perfCntrs)
    [ARRAY]$PerfMetrics = $(foreach ($query_perfCntr in $query_perfCntrs) {
        New-Object VMware.Vim.PerfMetricId -Property @{counterId=$PerfCounterTable[$query_perfCntr];instance=''}
    })
    [ARRAY]$PerfQuerySpecs = $(foreach ($query_entity_view in $query_entity_views) {
        New-Object VMware.Vim.PerfQuerySpec -Property @{entity=$query_entity_view;maxSample="15";intervalId="20";metricId=$PerfMetrics}
    })
    $metrics = $PerformanceManager.QueryPerf($PerfQuerySpecs)
    # https://kb.vmware.com/s/article/2107096
    $fatmetrics = @{}
    foreach ($metric in $metrics) {
        foreach ($metricValue in $metric.value) {
            if(!$fatmetrics[$($metricValue.id.counterId)]) {
                $fatmetrics[$($metricValue.id.counterId)] = @{}
                if (!$fatmetrics[$($metricValue.id.counterId)][$($metric.Entity.Value)]) {
                    $fatmetrics[$($metricValue.id.counterId)][$($metric.Entity.Value)] = @{}
                    $fatmetrics[$($metricValue.id.counterId)][$($metric.Entity.Value)][$($metricValue.id.instance)] = $(GetMedian $metricValue.value)
                } else {
                    $fatmetrics[$($metricValue.id.counterId)][$($metric.Entity.Value)][$($metricValue.id.instance)] = $(GetMedian $metricValue.value)
                }
            } else {
                if (!$fatmetrics[$($metricValue.id.counterId)][$($metric.Entity.Value)]) {
                    $fatmetrics[$($metricValue.id.counterId)][$($metric.Entity.Value)] = @{}
                    $fatmetrics[$($metricValue.id.counterId)][$($metric.Entity.Value)][$($metricValue.id.instance)] = $(GetMedian $metricValue.value)
                } else {
                    $fatmetrics[$($metricValue.id.counterId)][$($metric.Entity.Value)][$($metricValue.id.instance)] = $(GetMedian $metricValue.value)
                }
            }
        }
        # https://stackoverflow.com/questions/60687333/sort-a-nested-hash-table-by-value
    }
    return $fatmetrics
}

function MultiQueryPerf300 {
    param($query_entity_views, $query_perfCntrs)
    [ARRAY]$PerfMetrics = $(foreach ($query_perfCntr in $query_perfCntrs) {
        New-Object VMware.Vim.PerfMetricId -Property @{counterId=$PerfCounterTable[$query_perfCntr];instance=''}
    })
    [ARRAY]$PerfQuerySpecs = $(foreach ($query_entity_view in $query_entity_views) {
        New-Object VMware.Vim.PerfQuerySpec -Property @{entity=$query_entity_view;startTime=$ServiceInstanceServerClock_5;intervalId="300";metricId=$PerfMetrics}
    })
    $metrics = $PerformanceManager.QueryPerf($PerfQuerySpecs)
    # https://kb.vmware.com/s/article/2107096
    $fatmetrics = @{}
    foreach ($metric in $metrics) {
        foreach ($metricValue in $metric.value) {
            if(!$fatmetrics[$($metricValue.id.counterId)]) {
                $fatmetrics[$($metricValue.id.counterId)] = @{}
                if (!$fatmetrics[$($metricValue.id.counterId)][$($metric.Entity.Value)]) {
                    $fatmetrics[$($metricValue.id.counterId)][$($metric.Entity.Value)] = @{}
                    $fatmetrics[$($metricValue.id.counterId)][$($metric.Entity.Value)][$($metricValue.id.instance)] = $(GetMedian $metricValue.value)
                } else {
                    $fatmetrics[$($metricValue.id.counterId)][$($metric.Entity.Value)][$($metricValue.id.instance)] = $(GetMedian $metricValue.value)
                }
            } else {
                if (!$fatmetrics[$($metricValue.id.counterId)][$($metric.Entity.Value)]) {
                    $fatmetrics[$($metricValue.id.counterId)][$($metric.Entity.Value)] = @{}
                    $fatmetrics[$($metricValue.id.counterId)][$($metric.Entity.Value)][$($metricValue.id.instance)] = $(GetMedian $metricValue.value)
                } else {
                    $fatmetrics[$($metricValue.id.counterId)][$($metric.Entity.Value)][$($metricValue.id.instance)] = $(GetMedian $metricValue.value)
                }
            }
        }
        # https://stackoverflow.com/questions/60687333/sort-a-nested-hash-table-by-value
    }
    return $fatmetrics
}

try {
    Start-Transcript -Path "/var/log/sexigraf/ViPullStatistics.$($Server).log" -Append -Confirm:$false -Force -UseMinimalHeader
    Start-Transcript -Path "/var/log/sexigraf/ViPullStatistics.log" -Append -Confirm:$false -Force -UseMinimalHeader
    Write-Host "$((Get-Date).ToString("o")) [INFO] ViPullStatistics v$ScriptVersion"
    if ($vSanPull = Test-Path -Path $("/etc/cron.d/vsan_" + $Server.Replace(".","_"))) {
        Start-Transcript -Path "/var/log/sexigraf/VsanDisksPullStatistics.$($Server).log" -Append -Confirm:$false -Force -UseMinimalHeader
        Start-Transcript -Path "/var/log/sexigraf/VsanDisksPullStatistics.log" -Append -Confirm:$false -Force -UseMinimalHeader
    }
} catch {
    Write-Host "$((Get-Date).ToString("o")) [EROR] ViPullStatistics logging failure"
    Write-Host "$((Get-Date).ToString("o")) [EROR] Exit"
    exit
}

try {
    Write-Host "$((Get-Date).ToString("o")) [INFO] Importing PowerCli and Graphite PowerShell modules ..."
    Import-Module VMware.VimAutomation.Common, VMware.VimAutomation.Core, VMware.VimAutomation.Sdk, VMware.VimAutomation.Storage
    $PowerCliConfig = Set-PowerCLIConfiguration -ProxyPolicy NoProxy -DefaultVIServerMode Single -InvalidCertificateAction Ignore -ParticipateInCeip:$false -DisplayDeprecationWarnings:$false -Confirm:$false -Scope Session
    Import-Module -Name /usr/local/share/powershell/Modules/Graphite-PowerShell-Functions/Graphite-Powershell.psm1 -Global -Force -SkipEditionCheck
} catch {
    AltAndCatchFire "Powershell modules import failure"
}

try {
    Write-Host "$((Get-Date).ToString("o")) [INFO] Looking for another ViPullStatistics for $Server ..."
    $DupViPullStatisticsProcess = Get-PSHostProcessInfo|%{$(Get-Content -LiteralPath "/proc/$($_.ProcessId)/cmdline") -replace "`0", ' '}|?{$_ -match "ViPullStatistics" -and $_ -match "$Server"}
    # https://github.com/PowerShell/PowerShell/issues/13944
    if (($DupViPullStatisticsProcess|Measure-Object).Count -gt 1) {
        $DupViPullStatisticsProcessId = (Get-PSHostProcessInfo|?{$(Get-Content -LiteralPath "/proc/$($_.ProcessId)/cmdline") -replace "`0", ' '|?{$_ -match "$Server"}}).ProcessId[0]
        $DupViPullStatisticsProcessTime = [INT32](ps -p $DupViPullStatisticsProcessId -o etimes).split()[-1]
        if ($DupViPullStatisticsProcessTime -gt 300) {
            Write-Host "$((Get-Date).ToString("o")) [WARN] ViPullStatistics for $Server is already running for more than 5 minutes!"
            Write-Host "$((Get-Date).ToString("o")) [WARN] Killing stunned ViPullStatistics for $Server"
            Stop-Process -Id $DupViPullStatisticsProcessId -Force
        } else {
            AltAndCatchFire "ViPullStatistics for $Server is already running!"
        }
    }
} catch {
    AltAndCatchFire "ViPullStatistics process lookup failure"
}

if ($SessionFile) {
    try {
        $SessionToken = Get-Content -Path $SessionFile -ErrorAction Stop
        Write-Host "$((Get-Date).ToString("o")) [INFO] SessionToken found in SessionFile, attempting connection to $Server ..."
        # https://zhengwu.org/validating-connection-result-of-connect-viserver/
        $ServerConnection = Connect-VIServer -Server $Server -Session $SessionToken -Force -ErrorAction Stop
        if ($ServerConnection.IsConnected) {
            # $PwCliContext = Get-PowerCLIContext
            Write-Host "$((Get-Date).ToString("o")) [INFO] Connected to vCenter $($ServerConnection.Name) version $($ServerConnection.Version) build $($ServerConnection.Build)"
        }
    } catch {
        Write-Host "$((Get-Date).ToString("o")) [WARN] SessionToken not found, invalid or connection failure"
        Write-Host "$((Get-Date).ToString("o")) [WARN] Attempting explicit connection ..."
    }
    
    if (!$($global:DefaultVIServer)) {
        ### The session is not authenticated
        # https://github.com/guyrleech/VMware/blob/master/VMware%20GUI.ps1#L2940
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
                # $PwCliContext = Get-PowerCLIContext
                Write-Host "$((Get-Date).ToString("o")) [INFO] Connected to vCenter $($ServerConnection.Name) version $($ServerConnection.Version) build $($ServerConnection.Build)"
                $SessionSecretName = "vmw_" + $Server.Replace(".","_") + ".key"
                $ServerConnection.SessionSecret | Out-File -FilePath /tmp/$SessionSecretName -Force
            }
        } catch {
            AltAndCatchFire "Explicit connection failed, check the stored credentials!"
        }
    }
} else {
    AltAndCatchFire "No SessionFile somehow ..."
}

try {
    if ($($global:DefaultVIServer)) {
        Write-Host "$((Get-Date).ToString("o")) [INFO] Start processing vCenter/ESX $Server ..."
        $ServiceInstance = Get-View ServiceInstance -Server $Server
        # $ServiceManager = Get-View $ServiceInstance.Content.serviceManager -property "" -Server $Server
        $ServiceInstanceServerClock = $ServiceInstance.CurrentTime()
        $ServiceInstanceServerClock_5 = $ServiceInstanceServerClock.AddMinutes(-5)
    } else {
        AltAndCatchFire "global:DefaultVIServer variable check failure"
    }
} catch {
    AltAndCatchFire "Unable to verify vCenter connection"
}

try {
    if ($ServiceInstance) {
        Write-Host "$((Get-Date).ToString("o")) [INFO] Processing SessionManager & EventManager ..."
        try {
            $AuthorizationManager = Get-View $ServiceInstance.Content.AuthorizationManager -Server $Server
            $group_d1 = Get-View $ServiceInstance.Content.RootFolder
            $UserRoleId = $($group_d1.Permission|?{$_.Principal -eq $ServerConnection.User}).RoleId
            $UserRole = $AuthorizationManager.RoleList|?{$_.RoleId -eq $UserRoleId}
            # $UserTerminateSessionCheck = $AuthorizationManager.HasUserPrivilegeOnEntities($ServiceInstance.Content.RootFolder,$ServerConnection.User,"Sessions.TerminateSession")
            if ($UserRole.Privilege -match "Sessions.TerminateSession") {
                $SessionManager = Get-View $ServiceInstance.Content.SessionManager -Property SessionList -Server $Server # Permission to perform this operation was denied. Required privilege 'Sessions.TerminateSession' on managed object with id 'Folder-group-d1'.
            } else {
                Write-Host "$((Get-Date).ToString("o")) [INFO] Sessions.TerminateSession privilege not detected, SessionManager skipped ..."
            }
            $EventManager = Get-View $ServiceInstance.Content.EventManager -Property latestEvent, description -Server $Server
        } catch {
            AltAndCatchFire "AuthorizationManager or  SessionManager check failure"
        }
    } else {
        AltAndCatchFire "ServiceInstance check failure"
    }
} catch {
    Write-Host "$((Get-Date).ToString("o")) [EROR] $($Error[0])"
}

try {
    if ($ServiceInstance) {
        $PerformanceManager = Get-View $ServiceInstance.Content.PerfManager -Property perfCounter -Server $Server
        $PerfCounterInfos = $PerformanceManager.PerfCounter
        $script:PerfCounterTable = @{}
        foreach ($PerfCounterInfo in $PerfCounterInfos) {
            if (!$PerfCounterTable[$($PerfCounterInfo.GroupInfo.Key + "." + $PerfCounterInfo.NameInfo.Key + "." + $PerfCounterInfo.RollupType)]) {
                $PerfCounterTable.Add($($PerfCounterInfo.GroupInfo.Key + "." + $PerfCounterInfo.NameInfo.Key + "." + $PerfCounterInfo.RollupType),$PerfCounterInfo.key)
            }
        }
    } else {
        AltAndCatchFire "ServiceInstance variable check failure"
    }
} catch {
    AltAndCatchFire "Unable to initialize ServiceInstance"
}

if ($ServiceInstance.Content.About.ApiType -match "VirtualCenter") {

    $vcenter_name = $($Server.ToLower()) -replace "[. ]","_"

    $vmware_version_h = @{}
    $vcenter_version = NameCleaner $($ServiceInstance.Content.About.Version + "." + $ServiceInstance.Content.About.Build)
    $vmware_version_h["vi.$vcenter_name.vi.version.vpx.product.$vcenter_version"] ++

    Write-Host "$((Get-Date).ToString("o")) [INFO] vCenter objects collect ..."

    try {
        $vcenter_folders = Get-View -ViewType Folder -Property Name, Parent -Server $Server
        $vcenter_datacenters = Get-View -ViewType Datacenter -Property Name, Parent -Server $Server
        $vcenter_resource_pools = Get-View -ViewType ResourcePool -Property Vm, Parent, Owner, summary.quickStats -Server $Server
        $vcenter_clusters = Get-View -ViewType ComputeResource -Property name, parent, summary, resourcePool, host, datastore, ConfigurationEx -Server $Server
        $vcenter_vmhosts = Get-View -ViewType HostSystem -Property config.network.pnic, config.network.vnic, config.network.dnsConfig.hostName, runtime.connectionState, summary.hardware.numCpuCores, summary.quickStats.distributedCpuFairness, summary.quickStats.distributedMemoryFairness, summary.quickStats.overallCpuUsage, summary.quickStats.overallMemoryUsage, summary.quickStats.uptime, overallStatus, config.storageDevice.hostBusAdapter, vm, name, summary.runtime.healthSystemRuntime.systemHealthInfo.numericSensorInfo, config.product.version, config.product.build, summary.hardware.vendor, summary.hardware.model, summary.hardware.cpuModel, summary.hardware.NumCpuPkgs, Config.VsanHostConfig.ClusterInfo, Config.MultipathState -filter @{"Runtime.ConnectionState" = "^connected$"} -Server $Server
        $vcenter_datastores = Get-View -ViewType Datastore -Property summary, iormConfiguration.enabled, iormConfiguration.statsCollectionEnabled, host -filter @{"summary.accessible" = "true"} -Server $Server
        $vcenter_pods = Get-View -ViewType StoragePod -Property name, summary, parent, childEntity -Server $Server
        $vcenter_vms = Get-View -ViewType VirtualMachine -Property name, runtime.maxCpuUsage, runtime.maxMemoryUsage, summary.quickStats.overallCpuUsage, summary.quickStats.overallCpuDemand, summary.quickStats.hostMemoryUsage, summary.quickStats.guestMemoryUsage, summary.quickStats.balloonedMemory, summary.quickStats.compressedMemory, summary.quickStats.swappedMemory, summary.storage.committed, summary.storage.uncommitted, config.hardware.numCPU, layoutEx.file, snapshot, runtime.host, summary.runtime.connectionState, summary.runtime.powerState, summary.config.numVirtualDisks, config.version, config.guestId, config.tools.toolsVersion, summary.quickStats.privateMemory, summary.quickStats.consumedOverheadMemory, summary.quickStats.sharedMemory -filter @{"Summary.Runtime.ConnectionState" = "^connected$"} -Server $Server       
    } catch {
        AltAndCatchFire "Get-View failure"
    }

    Write-Host "$((Get-Date).ToString("o")) [INFO] Building objects tables ..."

    $vcenter_resource_pools_h = @{}
    $vcenter_resource_pools_owner_vms_h = @{}
    foreach ($vcenter_root_resource_pool in $vcenter_resource_pools) {
        try {
            if ($vcenter_root_resource_pool.owner -and $vcenter_root_resource_pool.vm) {
                $vcenter_resource_pools_owner_vms_h[$vcenter_root_resource_pool.owner.value] += $vcenter_root_resource_pool.vm
            }
        } catch {}
        try {
            $vcenter_resource_pools_h.add($vcenter_root_resource_pool.parent.value,$vcenter_root_resource_pool)
        } catch {}
    }

    $vcenter_clusters_h = @{}
    $vcenter_compute_h = @{}
    $vcenter_clusters_vsan_Ssd_uuid_naa_h = @{}
    $vcenter_clusters_vsan_nonSsd_uuid_naa_h = @{}
    $vcenter_vmhosts_vsan_disk_moref_h = @{}
    $vcenter_vmhosts_vsan_disk_capa_h = @{}
    $vcenter_clusters_vsan_efa_h = @{}
    foreach ($vcenter_cluster in $vcenter_clusters) {
        $vcenter_vmhosts_vsan_Ssd_uuid_naa_h = @{}
        $vcenter_vmhosts_vsan_nonSsd_uuid_naa_h = @{}
        if ($vcenter_cluster.MoRef.Type -eq "ClusterComputeResource") {
            try {
                $vcenter_clusters_h.add($vcenter_cluster.MoRef.Value, $vcenter_cluster)
            } catch {}
            if ($vcenter_cluster.ConfigurationEx.VsanHostConfig -and $vSanPull) {
                if (($vcenter_cluster.ConfigurationEx.VsanHostConfig.VsanEsaEnabled|Measure-Object).count -gt 0) {
                    try {
                        $vcenter_clusters_vsan_efa_h.add($vcenter_cluster.MoRef.Value,$vcenter_cluster)
                    } catch {}
                } else {
                    foreach ($ClusterVsanHostConfig in $vcenter_cluster.ConfigurationEx.VsanHostConfig) {
                        if ($ClusterVsanHostConfig.Enabled -and $ClusterVsanHostConfig.StorageInfo.diskMapInfo.mounted) {
                            foreach ($ClusterVsanHostConfigSsd in $ClusterVsanHostConfig.StorageInfo.diskMapInfo.mapping.Ssd) {
                                try {
                                    $vcenter_vmhosts_vsan_Ssd_uuid_naa_h.add($ClusterVsanHostConfigSsd.VsanDiskInfo.VsanUuid,$(NameCleaner $ClusterVsanHostConfigSsd.CanonicalName))
                                    $vcenter_vmhosts_vsan_disk_moref_h.add($ClusterVsanHostConfigSsd.VsanDiskInfo.VsanUuid,$ClusterVsanHostConfig.HostSystem.Value)
                                    $vcenter_vmhosts_vsan_disk_capa_h.add($ClusterVsanHostConfigSsd.VsanDiskInfo.VsanUuid,$($ClusterVsanHostConfigSsd.Capacity.BlockSize * $ClusterVsanHostConfigSsd.Capacity.Block))
                                } catch {}
                            }
                            foreach ($ClusterVsanHostConfigNonSsd in $ClusterVsanHostConfig.StorageInfo.diskMapInfo.mapping.nonSsd) {
                                try {
                                    $vcenter_vmhosts_vsan_nonSsd_uuid_naa_h.add($ClusterVsanHostConfigNonSsd.VsanDiskInfo.VsanUuid,$(NameCleaner $ClusterVsanHostConfigNonSsd.CanonicalName))
                                    $vcenter_vmhosts_vsan_disk_moref_h.add($ClusterVsanHostConfigNonSsd.VsanDiskInfo.VsanUuid,$ClusterVsanHostConfig.HostSystem.Value)
                                    $vcenter_vmhosts_vsan_disk_capa_h.add($ClusterVsanHostConfigNonSsd.VsanDiskInfo.VsanUuid,$($ClusterVsanHostConfigNonSsd.Capacity.BlockSize * $ClusterVsanHostConfigNonSsd.Capacity.Block))
                                } catch {}
                            }
                        }
                    }
                    $vcenter_clusters_vsan_Ssd_uuid_naa_h.add($vcenter_cluster.MoRef.Value,$vcenter_vmhosts_vsan_Ssd_uuid_naa_h)
                    $vcenter_clusters_vsan_nonSsd_uuid_naa_h.add($vcenter_cluster.MoRef.Value,$vcenter_vmhosts_vsan_nonSsd_uuid_naa_h)
                }
            }
        } elseif ($vcenter_cluster.MoRef.Type -eq "ComputeResource"){
            try {
                $vcenter_compute_h.add($vcenter_cluster.MoRef.Value, $vcenter_cluster)
            } catch {}
        }
    }

    $vcenter_vmhosts_h = @{}
    $vcenter_vmhosts_short_h = @{}
    $vcenter_vmhosts_NodeUuid_name_h = @{}
    $vcenter_vmhosts_moref_NodeUuid_h = @{}
    foreach ($vcenter_vmhost in $vcenter_vmhosts) {
        try {
            $vcenter_vmhosts_h.add($vcenter_vmhost.MoRef.Value, $vcenter_vmhost)
        } catch {}
        if ($vcenter_vmhost.Config.VsanHostConfig.ClusterInfo.NodeUuid -and $vSanPull) {
            try {
                $vcenter_vmhosts_NodeUuid_name_h.add($vcenter_vmhost.Config.VsanHostConfig.ClusterInfo.NodeUuid,$($vcenter_vmhost.config.network.dnsConfig.hostName).ToLower())
                $vcenter_vmhosts_moref_NodeUuid_h.add($vcenter_vmhost.MoRef.Value,$vcenter_vmhost.Config.VsanHostConfig.ClusterInfo.NodeUuid)
                $vcenter_vmhosts_short_h.add($vcenter_vmhost.name, $($vcenter_vmhost.config.network.dnsConfig.hostName).ToLower())
            } catch {}
        }
    }

    $vcenter_datastores_h = @{}
    foreach ($vcenter_datastore in $vcenter_datastores) {
        try {
            $vcenter_datastores_h.add($vcenter_datastore.MoRef.Value,$vcenter_datastore)
        } catch {}
    }

    $vcenter_pods_h = @{}
    foreach ($vcenter_pod in $vcenter_pods) {
        try {
            $vcenter_pods_h.add($vcenter_pod.MoRef.Value,$vcenter_pod)
        } catch {}
    }

    $vcenter_vms_h = @{}
    foreach ($vcenter_vm in $vcenter_vms) {
        try {
            $vcenter_vms_h.add($vcenter_vm.MoRef.Value, $vcenter_vm)
        } catch {}
    }

	$script:xfolders_vcenter_name_h = @{}
	$script:xfolders_vcenter_parent_h = @{}
	$script:xfolders_vcenter_type_h = @{}

	Write-Host "$((Get-Date).ToString("o")) [INFO] vCenter objects relationship discover ..."
	
	foreach ($vcenter_xfolder in [array]$vcenter_datacenters + [array]$vcenter_folders + [array]$vcenter_clusters + [array]$vcenter_resource_pools + [array]$vcenter_vmhosts + [array]$vcenter_pods) {
        try {
            if (!$xfolders_vcenter_name_h[$vcenter_xfolder.moref.value]) {$xfolders_vcenter_name_h.add($vcenter_xfolder.moref.value,$vcenter_xfolder.name)}
            if (!$xfolders_vcenter_parent_h[$vcenter_xfolder.moref.value]) {$xfolders_vcenter_parent_h.add($vcenter_xfolder.moref.value,$vcenter_xfolder.Parent.value)}
            if (!$xfolders_vcenter_type_h[$vcenter_xfolder.moref.value]) {$xfolders_vcenter_type_h.add($vcenter_xfolder.moref.value,$vcenter_xfolder.moref.type)}
        } catch {}
	}

    Write-Host "$((Get-Date).ToString("o")) [INFO] Performance metrics collection ..."

    $HostMultiMetrics = @(
        "net.bytesRx.average",
        "net.bytesTx.average",
        "net.droppedRx.summation",
        "net.droppedTx.summation",
        "net.errorsRx.summation",
        "net.errorsTx.summation",
        "storageAdapter.read.average",
        "storageAdapter.write.average",
        "power.power.average",
        "datastore.sizeNormalizedDatastoreLatency.average",
		"datastore.totalWriteLatency.average",
		# "datastore.totalReadLatency.average",
        "datastore.numberWriteAveraged.average",
        "datastore.numberReadAveraged.average",
        "cpu.latency.average",
        "cpu.totalCapacity.average",
        "mem.totalCapacity.average"
    )

    if (($vcenter_vmhosts|Measure-Object).Count -gt 0) {
        try {
            $HostMultiStatsTime = Measure-Command {$HostMultiStats = MultiQueryPerfAll $($vcenter_vmhosts.moref) $HostMultiMetrics}
            Write-Host "$((Get-Date).ToString("o")) [INFO] All hosts multi metrics collected in $($HostMultiStatsTime.TotalSeconds) sec for vCenter $vcenter_name"
        } catch {
            AltAndCatchFire "ESX MultiQueryPerfAll failure"
        }
    } else {
        Write-Host "$((Get-Date).ToString("o")) [INFO] No ESX in vCenter $vcenter_name"
    }

    if (($vcenter_vms|Measure-Object).Count -eq 0) {
        Write-Host "$((Get-Date).ToString("o")) [INFO] No VMs in vCenter $vcenter_name"
    } elseif (($vcenter_vms|Measure-Object).Count -gt 10000) {
        Write-Host "$((Get-Date).ToString("o")) [INFO] 10K+ VMs mode for vCenter $vcenter_name"

        $VmMultiMetricsR1 = @(
            "cpu.ready.summation",
            "cpu.wait.summation",
            "cpu.idle.summation",
            "cpu.latency.average"
        )

        try {
            $VmMultiStatsTime = Measure-Command {$VmMultiStats = MultiQueryPerf $($vcenter_vms.moref) $VmMultiMetricsR1}
            Write-Host "$((Get-Date).ToString("o")) [INFO] All vms multi metrics 1st round collected in $($VmMultiStatsTime.TotalSeconds) sec for vCenter $vcenter_name"
        } catch {
            AltAndCatchFire "VM MultiQueryPerf R1 failure"
        }

        $VmMultiMetricsR2 = @(
            "disk.maxTotalLatency.latest",
            "virtualdisk.write.average",
            "virtualdisk.read.average",
            "net.usage.average"
        )

        try {
            $VmMultiStatsTime = Measure-Command {$VmMultiStats += MultiQueryPerf $($vcenter_vms.moref) $VmMultiMetricsR2}
            Write-Host "$((Get-Date).ToString("o")) [INFO] All vms multi metrics 2nd round collected in $($VmMultiStatsTime.TotalSeconds) sec for vCenter $vcenter_name"
        } catch {
            AltAndCatchFire "VM MultiQueryPerf R2 failure"
        }

        # $VmMultiMetricsAll = @(
        #     "virtualdisk.numberWriteAveraged.average",
        #     "virtualdisk.numberReadAveraged.average",
        #     "net.packetsRx.summation",
        #     "net.packetsTx.summation"
        # )

        # try {
        #     $VmMultiStatsTime = Measure-Command {$VmMultiStats += MultiQueryPerfAll $($vcenter_vms.moref) $VmMultiMetricsAll}
        #     Write-Host "$((Get-Date).ToString("o")) [INFO] All vms multi metrics instanced collected in $($VmMultiStatsTime.TotalSeconds) sec for vCenter $vcenter_name"
        # } catch {
        #     AltAndCatchFire "VM MultiQueryPerfAll failure"
        # }

    } else {
        $VmMultiMetrics = @(
            "cpu.ready.summation",
            "cpu.wait.summation",
            "cpu.idle.summation",
            "cpu.latency.average",
            "disk.maxTotalLatency.latest",
            "virtualdisk.write.average",
            "virtualdisk.read.average",
            "net.usage.average"
        )
    
        try {
            $VmMultiStatsTime = Measure-Command {$VmMultiStats = MultiQueryPerf $($vcenter_vms.moref) $VmMultiMetrics}
            Write-Host "$((Get-Date).ToString("o")) [INFO] All vms multi metrics collected in $($VmMultiStatsTime.TotalSeconds) sec for vCenter $vcenter_name"
        } catch {
            AltAndCatchFire "VM MultiQueryPerf failure"
        }

        $VmMultiMetricsAll = @(
            "virtualdisk.numberWriteAveraged.average",
            "virtualdisk.numberReadAveraged.average"
        )

        try {
            $VmMultiStatsTime = Measure-Command {$VmMultiStats += MultiQueryPerfAll $($vcenter_vms.moref) $VmMultiMetricsAll}
            Write-Host "$((Get-Date).ToString("o")) [INFO] All vms multi metrics instanced collected in $($VmMultiStatsTime.TotalSeconds) sec for vCenter $vcenter_name"
        } catch {
            AltAndCatchFire "VM MultiQueryPerfAll failure"
        }

    }

    if ($vcenter_clusters_h.Keys) {
        $ClusterMultiMetrics = @(
            "vmop.numSVMotion.latest",
            "vmop.numXVMotion.latest"
        )
        try {
            $ClusterMultiStatsTime = Measure-Command {$ClusterMultiStats = MultiQueryPerf300 $($vcenter_clusters_h.Values.moref) $ClusterMultiMetrics}
            Write-Host "$((Get-Date).ToString("o")) [INFO] All Clusters multi metrics collected in $($ClusterMultiStatsTime.TotalSeconds) sec for vCenter $vcenter_name"
        } catch {
            Write-Host "$((Get-Date).ToString("o")) [EROR] $($Error[0])"
            Write-Host "$((Get-Date).ToString("o")) [EROR] VM MultiQueryPerf failure"
        }
    }

    if ($ServiceInstance.Content.About.ApiVersion -ge 6.7) {
        if ($vcenter_vmhosts_NodeUuid_name_h.Count -gt 0 -and $vSanPull) {
            Write-Host "$((Get-Date).ToString("o")) [INFO] vCenter ApiVersion is 6.7+ so we can call vSAN API"
            $VsanPerformanceManager = Get-VSANView -Id VsanPerformanceManager-vsan-performance-manager -Server $Server
            $VsanClusterHealthSystem = Get-VSANView -Id VsanVcClusterHealthSystem-vsan-cluster-health-system -Server $Server
            $VsanSpaceReportSystem = Get-VSANView -Id VsanSpaceReportSystem-vsan-cluster-space-report-system -Server $Server
            $VsanObjectSystem = Get-VSANView -Id VsanObjectSystem-vsan-cluster-object-system -Server $Server
            # VsanClusterHealthSummary/VsanPhysicalDiskHealthSummary better than VsanManagedDisksInfo since we can query at the cluster level
            # if ($vcenter_clusters_vsan_efa_h.keys) {
            #     $VsanVcDiskManagementSystem = Get-VSANView -Id VimClusterVsanVcDiskManagementSystem-vsan-disk-management-system -Server $Server
            #     Write-Host "$((Get-Date).ToString("o")) [INFO] vSAN EFA clusters detected ..."
            # }
        }
    }

    foreach ($vcenter_cluster_moref in $vcenter_clusters_h.keys) {

        try {
            $vcenter_cluster = $vcenter_clusters_h[$vcenter_cluster_moref]
            $vcenter_cluster_name = nameCleaner $vcenter_cluster.Name
            $vcenter_cluster_dc_name = nameCleaner $(getRootDc $vcenter_cluster)
            Write-Host "$((Get-Date).ToString("o")) [INFO] Processing vCenter $vcenter_name cluster $vcenter_cluster_name in datacenter $vcenter_cluster_dc_name"
        } catch {
            AltAndCatchFire "cluster name cleaning issue"
        }

        $vcenter_cluster_h = @{}

        if ($vcenter_resource_pools_h[$vcenter_cluster.moref.value]) {
            try {
                $vcenter_cluster_pool_quickstats = $vcenter_resource_pools_h[$vcenter_cluster.moref.value].summary.quickStats
    
                $vcenter_cluster_h.add("vmw.$vcenter_name.$vcenter_cluster_dc_name.$vcenter_cluster_name.quickstats.mem.ballooned", $vcenter_cluster_pool_quickstats.balloonedMemory)
                $vcenter_cluster_h.add("vmw.$vcenter_name.$vcenter_cluster_dc_name.$vcenter_cluster_name.quickstats.mem.compressed", $vcenter_cluster_pool_quickstats.compressedMemory)
                $vcenter_cluster_h.add("vmw.$vcenter_name.$vcenter_cluster_dc_name.$vcenter_cluster_name.quickstats.mem.consumedOverhead", $vcenter_cluster_pool_quickstats.consumedOverheadMemory)
                $vcenter_cluster_h.add("vmw.$vcenter_name.$vcenter_cluster_dc_name.$vcenter_cluster_name.quickstats.mem.guest", $vcenter_cluster_pool_quickstats.guestMemoryUsage)
                $vcenter_cluster_h.add("vmw.$vcenter_name.$vcenter_cluster_dc_name.$vcenter_cluster_name.quickstats.mem.usage", $vcenter_cluster_pool_quickstats.hostMemoryUsage)
                $vcenter_cluster_h.add("vmw.$vcenter_name.$vcenter_cluster_dc_name.$vcenter_cluster_name.quickstats.cpu.demand", $vcenter_cluster_pool_quickstats.overallCpuDemand)
                $vcenter_cluster_h.add("vmw.$vcenter_name.$vcenter_cluster_dc_name.$vcenter_cluster_name.quickstats.cpu.usage", $vcenter_cluster_pool_quickstats.overallCpuUsage)
                $vcenter_cluster_h.add("vmw.$vcenter_name.$vcenter_cluster_dc_name.$vcenter_cluster_name.quickstats.mem.private", $vcenter_cluster_pool_quickstats.privateMemory)
                $vcenter_cluster_h.add("vmw.$vcenter_name.$vcenter_cluster_dc_name.$vcenter_cluster_name.quickstats.mem.shared", $vcenter_cluster_pool_quickstats.sharedMemory)
                $vcenter_cluster_h.add("vmw.$vcenter_name.$vcenter_cluster_dc_name.$vcenter_cluster_name.quickstats.mem.swapped", $vcenter_cluster_pool_quickstats.swappedMemory)
    
                if ($vcenter_cluster_pool_quickstats.overallCpuUsage -gt 0 -and $vcenter_cluster.summary.effectiveCpu -gt 0) {
                    $vcenter_cluster_pool_quickstats_cpu = $vcenter_cluster_pool_quickstats.overallCpuUsage * 100 / $vcenter_cluster.summary.effectiveCpu
                    $vcenter_cluster_h.add("vmw.$vcenter_name.$vcenter_cluster_dc_name.$vcenter_cluster_name.superstats.cpu.utilization", $vcenter_cluster_pool_quickstats_cpu)
                }
    
                if ($vcenter_cluster_pool_quickstats.hostMemoryUsage -gt 0 -and $vcenter_cluster.summary.effectiveMemory -gt 0) {
                    $vcenter_cluster_pool_quickstats_ram = $vcenter_cluster_pool_quickstats.hostMemoryUsage * 100 / $vcenter_cluster.summary.effectiveMemory
                    $vcenter_cluster_h.add("vmw.$vcenter_name.$vcenter_cluster_dc_name.$vcenter_cluster_name.superstats.mem.utilization", $vcenter_cluster_pool_quickstats_ram)
                }
    
            } catch {
                Write-Host "$((Get-Date).ToString("o")) [EROR] Cluster $vcenter_cluster_name quickstats collect issue"
                Write-Host "$((Get-Date).ToString("o")) [EROR] $($Error[0])"
            }
        } else {
            Write-Host "$((Get-Date).ToString("o")) [EROR] Cluster $vcenter_cluster_name root resource pool not found ?!"
        }

        if ($vcenter_cluster.summary) {
            try {
                $vcenter_cluster_h.add("vmw.$vcenter_name.$vcenter_cluster_dc_name.$vcenter_cluster_name.quickstats.mem.effective", $vcenter_cluster.summary.effectiveMemory)
                $vcenter_cluster_h.add("vmw.$vcenter_name.$vcenter_cluster_dc_name.$vcenter_cluster_name.quickstats.mem.total", $vcenter_cluster.summary.totalMemory)
                $vcenter_cluster_h.add("vmw.$vcenter_name.$vcenter_cluster_dc_name.$vcenter_cluster_name.quickstats.cpu.effective", $vcenter_cluster.summary.effectiveCpu)
                $vcenter_cluster_h.add("vmw.$vcenter_name.$vcenter_cluster_dc_name.$vcenter_cluster_name.quickstats.cpu.total", $vcenter_cluster.summary.totalCpu)
                $vcenter_cluster_h.add("vmw.$vcenter_name.$vcenter_cluster_dc_name.$vcenter_cluster_name.quickstats.numVmotions", $vcenter_cluster.summary.numVmotions)
            } catch {
                Write-Host "$((Get-Date).ToString("o")) [EROR] Cluster $vcenter_cluster_name summary collect issue"
                Write-Host "$((Get-Date).ToString("o")) [EROR] $($Error[0])"
            }
        } else {
            Write-Host "$((Get-Date).ToString("o")) [EROR] Cluster $vcenter_cluster_name summary missing "
        }

        try {
            if($ClusterMultiStats[$PerfCounterTable["vmop.numSVMotion.latest"]][$vcenter_cluster.moref.value][""]) {
                $vcenter_cluster_h.add("vmw.$vcenter_name.$vcenter_cluster_dc_name.$vcenter_cluster_name.quickstats.numSVMotions", $ClusterMultiStats[$PerfCounterTable["vmop.numSVMotion.latest"]][$vcenter_cluster.moref.value][""])
            }

            if($ClusterMultiStats[$PerfCounterTable["vmop.numXVMotion.latest"]][$vcenter_cluster.moref.value][""]) {
                $vcenter_cluster_h.add("vmw.$vcenter_name.$vcenter_cluster_dc_name.$vcenter_cluster_name.quickstats.numXVMotions", $ClusterMultiStats[$PerfCounterTable["vmop.numXVMotion.latest"]][$vcenter_cluster.moref.value][""])
            }
        } catch {
            Write-Host "$((Get-Date).ToString("o")) [EROR] Cluster $vcenter_cluster_name xyzMotion collect issue"
            Write-Host "$((Get-Date).ToString("o")) [EROR] $($Error[0])"
        }

        try {
            if ($vcenter_cluster.summary.NumVmsPerDrsScoreBucket -and $vcenter_cluster.summary.DrsScore) {
                # https://vdc-download.vmware.com/vmwb-repository/dcr-public/bf660c0a-f060-46e8-a94d-4b5e6ffc77ad/208bc706-e281-49b6-a0ce-b402ec19ef82/SDK/vsphere-ws/docs/ReferenceGuide/vim.ClusterComputeResource.Summary.html#numVmsPerDrsScoreBucket
                if ($vcenter_cluster.summary.NumVmsPerDrsScoreBucket[0]) {
                    $vcenter_cluster_h.add("vmw.$vcenter_name.$vcenter_cluster_dc_name.$vcenter_cluster_name.quickstats.drs.0_20", $vcenter_cluster.summary.NumVmsPerDrsScoreBucket[0])
                } else {
                    $vcenter_cluster_h.add("vmw.$vcenter_name.$vcenter_cluster_dc_name.$vcenter_cluster_name.quickstats.drs.0_20", 0)
                }
                if ($vcenter_cluster.summary.NumVmsPerDrsScoreBucket[1]) {
                    $vcenter_cluster_h.add("vmw.$vcenter_name.$vcenter_cluster_dc_name.$vcenter_cluster_name.quickstats.drs.21_40", $vcenter_cluster.summary.NumVmsPerDrsScoreBucket[1])
                } else {
                    $vcenter_cluster_h.add("vmw.$vcenter_name.$vcenter_cluster_dc_name.$vcenter_cluster_name.quickstats.drs.21_40", 0)
                }
                if ($vcenter_cluster.summary.NumVmsPerDrsScoreBucket[2]) {
                    $vcenter_cluster_h.add("vmw.$vcenter_name.$vcenter_cluster_dc_name.$vcenter_cluster_name.quickstats.drs.41_60", $vcenter_cluster.summary.NumVmsPerDrsScoreBucket[2])
                } else {
                    $vcenter_cluster_h.add("vmw.$vcenter_name.$vcenter_cluster_dc_name.$vcenter_cluster_name.quickstats.drs.41_60", 0)
                }
                if ($vcenter_cluster.summary.NumVmsPerDrsScoreBucket[3]) {
                    $vcenter_cluster_h.add("vmw.$vcenter_name.$vcenter_cluster_dc_name.$vcenter_cluster_name.quickstats.drs.61_80", $vcenter_cluster.summary.NumVmsPerDrsScoreBucket[3])
                } else {
                    $vcenter_cluster_h.add("vmw.$vcenter_name.$vcenter_cluster_dc_name.$vcenter_cluster_name.quickstats.drs.61_80", 0)
                }
                if ($vcenter_cluster.summary.NumVmsPerDrsScoreBucket[4]) {
                    $vcenter_cluster_h.add("vmw.$vcenter_name.$vcenter_cluster_dc_name.$vcenter_cluster_name.quickstats.drs.81_100", $vcenter_cluster.summary.NumVmsPerDrsScoreBucket[4])
                } else {
                    $vcenter_cluster_h.add("vmw.$vcenter_name.$vcenter_cluster_dc_name.$vcenter_cluster_name.quickstats.drs.81_100", 0)
                }
                
                $vcenter_cluster_h.add("vmw.$vcenter_name.$vcenter_cluster_dc_name.$vcenter_cluster_name.quickstats.drs.DrsScore", $vcenter_cluster.summary.DrsScore)
            }
        } catch {
            Write-Host "$((Get-Date).ToString("o")) [EROR] Cluster $vcenter_cluster_name DrsScore collect issue"
            Write-Host "$((Get-Date).ToString("o")) [EROR] $($Error[0])"
        }

        Write-Host "$((Get-Date).ToString("o")) [INFO] Processing vCenter $vcenter_name cluster $vcenter_cluster_name hosts in datacenter $vcenter_cluster_dc_name"

        $vcenter_cluster_hosts_pcpus = 0
        $vcenter_cluster_hosts_vms_moref = @()
        $vcenter_cluster_hosts_cpu_latency = @()
        $vcenter_cluster_hosts_net_bytesRx = 0
        $vcenter_cluster_hosts_net_bytesTx = 0
        $vcenter_cluster_hosts_hba_bytesRead = 0
        $vcenter_cluster_hosts_hba_bytesWrite = 0
        $vcenter_cluster_hosts_power_usage = 0
        $vcenter_cluster_hosts_vms_dead = 0
        $vcenter_cluster_hosts_h = @{}

        foreach ($vcenter_cluster_host in $vcenter_vmhosts_h[$vcenter_cluster.Host.value]|?{$_}) {

            $vcenter_cluster_hosts_h.add($vcenter_cluster_host.moref.value,$vcenter_cluster_host)

            $vcenter_cluster_host_name = $vcenter_cluster_host.config.network.dnsConfig.hostName.ToLower() ### to avoid esx registered by ip
            if ($vcenter_cluster_host_name -match "localhost") {
                $vcenter_cluster_host_name = NameCleaner $vcenter_cluster_host.name ### previously vmk0 ip cleaned

            }

            if ($vcenter_cluster_host.vm) {
                $vcenter_cluster_hosts_vms_moref += $vcenter_vms_h[$vcenter_cluster_host.vm.value]|?{$_}
                $vcenter_cluster_host_real_vm_count = $($vcenter_cluster_host.vm|Measure-Object).Count
                $vcenter_cluster_host_connected_vm_count = $($vcenter_vms_h[$vcenter_cluster_host.vm.value]|Measure-Object).Count
                if ($vcenter_cluster_host_real_vm_count -gt $vcenter_cluster_host_connected_vm_count) {
                    $vcenter_cluster_hosts_vms_dead += $vcenter_cluster_host_real_vm_count - $vcenter_cluster_host_connected_vm_count
                }
                ### TODO use $vcenter_resource_pools_owner_vms_h ?
            }

            if ($vcenter_cluster_host.config.product.version -and $vcenter_cluster_host.config.product.build -and $vcenter_cluster_host.summary.hardware.cpuModel -and $vcenter_cluster_host.summary.hardware.NumCpuPkgs) {
                $vcenter_cluster_host_product_version = nameCleaner $($vcenter_cluster_host.config.product.version + "_" + $vcenter_cluster_host.config.product.build)
                $vcenter_cluster_host_hw_model = nameCleaner $($vcenter_cluster_host.summary.hardware.vendor + "_" + $vcenter_cluster_host.summary.hardware.model)
                $vcenter_cluster_host_cpu_model = nameCleaner $vcenter_cluster_host.summary.hardware.cpuModel

                $vmware_version_h["vi.$vcenter_name.vi.version.esx.$vcenter_cluster_dc_name.$vcenter_cluster_name.build.$vcenter_cluster_host_product_version"] ++
                $vmware_version_h["vi.$vcenter_name.vi.version.esx.$vcenter_cluster_dc_name.$vcenter_cluster_name.hardware.$vcenter_cluster_host_hw_model"] ++
                $vmware_version_h["vi.$vcenter_name.vi.version.esx.$vcenter_cluster_dc_name.$vcenter_cluster_name.cpu.$vcenter_cluster_host_cpu_model"] += [INT32]$vcenter_cluster_host.summary.hardware.NumCpuPkgs
            }

            $vcenter_cluster_hosts_pcpus += $vcenter_cluster_host.summary.hardware.numCpuCores

            try {
                $vcenter_cluster_host_sensors = $vcenter_cluster_host.summary.runtime.healthSystemRuntime.systemHealthInfo.numericSensorInfo
                # https://vdc-download.vmware.com/vmwb-repository/dcr-public/b50dcbbf-051d-4204-a3e7-e1b618c1e384/538cf2ec-b34f-4bae-a332-3820ef9e7773/vim.host.NumericSensorInfo.html
                foreach ($vcenter_cluster_host_sensor in $vcenter_cluster_host_sensors) {
                    if ($vcenter_cluster_host_sensor.name -and $vcenter_cluster_host_sensor.sensorType -and $vcenter_cluster_host_sensor.currentReading -and $vcenter_cluster_host_sensor.unitModifier) {

                        $vcenter_cluster_host_sensor_computed_reading = $vcenter_cluster_host_sensor.currentReading * $([Math]::Pow(10, $vcenter_cluster_host_sensor.unitModifier))
                        $vcenter_cluster_host_sensor_name = NameCleaner $vcenter_cluster_host_sensor.name
                        $vcenter_cluster_host_sensor_type = $vcenter_cluster_host_sensor.sensorType

                        $vcenter_cluster_h.add("vmw.$vcenter_name.$vcenter_cluster_dc_name.$vcenter_cluster_name.esx.$vcenter_cluster_host_name.sensor.$vcenter_cluster_host_sensor_type.$vcenter_cluster_host_sensor_name", $vcenter_cluster_host_sensor_computed_reading)
                    }
                }
            } catch {
                Write-Host "$((Get-Date).ToString("o")) [EROR] ESX $vcenter_cluster_host sensors issue in cluster $vcenter_cluster_name"
                Write-Host "$((Get-Date).ToString("o")) [EROR] $($Error[0])"
            }

            try {
                foreach ($vcenter_cluster_host_vmnic in $vcenter_cluster_host.config.network.pnic) {
                    if ($vcenter_cluster_host_vmnic.linkSpeed -and $vcenter_cluster_host_vmnic.linkSpeed.speedMb -ge 100) {
                        $vcenter_cluster_host_vmnic_name = $vcenter_cluster_host_vmnic.device

                        $vcenter_cluster_host_vmnic_bytesRx = $HostMultiStats[$PerfCounterTable["net.bytesRx.average"]][$vcenter_cluster_host.moref.value][$vcenter_cluster_host_vmnic_name]
                        $vcenter_cluster_host_vmnic_bytesTx = $HostMultiStats[$PerfCounterTable["net.bytesTx.average"]][$vcenter_cluster_host.moref.value][$vcenter_cluster_host_vmnic_name]

                        if ($vcenter_cluster_host_vmnic_bytesRx -ge 0 -and $vcenter_cluster_host_vmnic_bytesTx -ge 0) {
                            $vcenter_cluster_hosts_net_bytesRx += $vcenter_cluster_host_vmnic_bytesRx
                            $vcenter_cluster_hosts_net_bytesTx += $vcenter_cluster_host_vmnic_bytesTx
                            $vcenter_cluster_h.add("vmw.$vcenter_name.$vcenter_cluster_dc_name.$vcenter_cluster_name.esx.$vcenter_cluster_host_name.net.$vcenter_cluster_host_vmnic_name.bytesRx", $vcenter_cluster_host_vmnic_bytesRx)
                            $vcenter_cluster_h.add("vmw.$vcenter_name.$vcenter_cluster_dc_name.$vcenter_cluster_name.esx.$vcenter_cluster_host_name.net.$vcenter_cluster_host_vmnic_name.bytesTx", $vcenter_cluster_host_vmnic_bytesTx)
                            # $vcenter_cluster_h.add("vmw.$vcenter_name.$vcenter_cluster_dc_name.$vcenter_cluster_name.esx.$vcenter_cluster_host_name.net.$vcenter_cluster_host_vmnic_name.linkSpeed", $vcenter_cluster_host_vmnic.linkSpeed.speedMb)
                        }

                        $vcenter_cluster_host_vmnic_droppedRx = $HostMultiStats[$PerfCounterTable["net.droppedRx.summation"]][$vcenter_cluster_host.moref.value][$vcenter_cluster_host_vmnic_name]
                        $vcenter_cluster_host_vmnic_droppedTx = $HostMultiStats[$PerfCounterTable["net.droppedTx.summation"]][$vcenter_cluster_host.moref.value][$vcenter_cluster_host_vmnic_name]
                        $vcenter_cluster_host_vmnic_errorsRx = $HostMultiStats[$PerfCounterTable["net.errorsRx.summation"]][$vcenter_cluster_host.moref.value][$vcenter_cluster_host_vmnic_name]
                        $vcenter_cluster_host_vmnic_errorsTx = $HostMultiStats[$PerfCounterTable["net.errorsTx.summation"]][$vcenter_cluster_host.moref.value][$vcenter_cluster_host_vmnic_name]

                        if ($vcenter_cluster_host_vmnic_droppedRx -gt 0) {
                            $vcenter_cluster_h.add("vmw.$vcenter_name.$vcenter_cluster_dc_name.$vcenter_cluster_name.esx.$vcenter_cluster_host_name.net.$vcenter_cluster_host_vmnic_name.droppedRx", $vcenter_cluster_host_vmnic_droppedRx)
                        }

                        if ($vcenter_cluster_host_vmnic_droppedTx -gt 0) {
                            $vcenter_cluster_h.add("vmw.$vcenter_name.$vcenter_cluster_dc_name.$vcenter_cluster_name.esx.$vcenter_cluster_host_name.net.$vcenter_cluster_host_vmnic_name.droppedTx", $vcenter_cluster_host_vmnic_droppedTx)
                        }

                        if ($vcenter_cluster_host_vmnic_errorsRx -gt 0) {
                            $vcenter_cluster_h.add("vmw.$vcenter_name.$vcenter_cluster_dc_name.$vcenter_cluster_name.esx.$vcenter_cluster_host_name.net.$vcenter_cluster_host_vmnic_name.errorsRx", $vcenter_cluster_host_vmnic_errorsRx)
                        }

                        if ($vcenter_cluster_host_vmnic_errorsTx -gt 0) {
                            $vcenter_cluster_h.add("vmw.$vcenter_name.$vcenter_cluster_dc_name.$vcenter_cluster_name.esx.$vcenter_cluster_host_name.net.$vcenter_cluster_host_vmnic_name.errorsTx", $vcenter_cluster_host_vmnic_errorsTx)
                        }

                    }
                }
            } catch {
                Write-Host "$((Get-Date).ToString("o")) [EROR] ESX $vcenter_cluster_host_name network metrics issue in cluster $vcenter_cluster_name"
                Write-Host "$((Get-Date).ToString("o")) [EROR] $($Error[0])"
            }

            try {
                foreach ($vcenter_cluster_host_vmhba in $vcenter_cluster_host.config.storageDevice.hostBusAdapter) {
                    $vcenter_cluster_host_vmhba_name = $vcenter_cluster_host_vmhba.device
                    $vcenter_cluster_host_vmhba_bytesRead = $HostMultiStats[$PerfCounterTable["storageAdapter.read.average"]][$vcenter_cluster_host.moref.value][$vcenter_cluster_host_vmhba_name]
                    $vcenter_cluster_host_vmhba_bytesWrite = $HostMultiStats[$PerfCounterTable["storageAdapter.write.average"]][$vcenter_cluster_host.moref.value][$vcenter_cluster_host_vmhba_name]
                
                    if ($vcenter_cluster_host_vmhba_bytesRead -ge 0 -and $vcenter_cluster_host_vmhba_bytesWrite -ge 0) {
                        $vcenter_cluster_hosts_hba_bytesRead += $vcenter_cluster_host_vmhba_bytesRead
                        $vcenter_cluster_hosts_hba_bytesWrite += $vcenter_cluster_host_vmhba_bytesWrite
                        $vcenter_cluster_h.add("vmw.$vcenter_name.$vcenter_cluster_dc_name.$vcenter_cluster_name.esx.$vcenter_cluster_host_name.hba.$vcenter_cluster_host_vmhba_name.bytesRead", $vcenter_cluster_host_vmhba_bytesRead)
                        $vcenter_cluster_h.add("vmw.$vcenter_name.$vcenter_cluster_dc_name.$vcenter_cluster_name.esx.$vcenter_cluster_host_name.hba.$vcenter_cluster_host_vmhba_name.bytesWrite", $vcenter_cluster_host_vmhba_bytesWrite)
                    }
                }
            } catch {
                Write-Host "$((Get-Date).ToString("o")) [EROR] ESX $vcenter_cluster_host_name hba metrics issue in cluster $vcenter_cluster_name"
                Write-Host "$((Get-Date).ToString("o")) [EROR] $($Error[0])"
            }

            try {
                foreach ($vcenter_cluster_host_path in $vcenter_cluster_host.Config.MultipathState.Path) { 
                    $vcenter_cluster_h["vmw.$vcenter_name.$vcenter_cluster_dc_name.$vcenter_cluster_name.superstats.PathState.$($vcenter_cluster_host_path.PathState)"] ++
                }
            } catch {
                Write-Host "$((Get-Date).ToString("o")) [EROR] ESX $vcenter_cluster_host_name MultipathState issue in cluster $vcenter_cluster_name"
                Write-Host "$((Get-Date).ToString("o")) [EROR] $($Error[0])"
            }

            try {
                if ($HostMultiStats[$PerfCounterTable["power.power.average"]][$vcenter_cluster_host.moref.value]) {
                    $vcenter_cluster_host_power = $HostMultiStats[$PerfCounterTable["power.power.average"]][$vcenter_cluster_host.moref.value][""]
                    if ($vcenter_cluster_host_power -ge 0) {
                        $vcenter_cluster_hosts_power_usage += $vcenter_cluster_host_power
                        $vcenter_cluster_h.add("vmw.$vcenter_name.$vcenter_cluster_dc_name.$vcenter_cluster_name.esx.$vcenter_cluster_host_name.fatstats.power", $vcenter_cluster_host_power)
                    }
                }
            } catch {
                Write-Host "$((Get-Date).ToString("o")) [EROR] ESX $vcenter_cluster_host_name fatstats power metrics issue in cluster $vcenter_cluster_name"
                Write-Host "$((Get-Date).ToString("o")) [EROR] $($Error[0])"
            }

            try {
                if ($HostMultiStats[$PerfCounterTable["cpu.totalCapacity.average"]][$vcenter_cluster_host.moref.value]) {
                    $vcenter_cluster_host_cpu_totalCapacity = $HostMultiStats[$PerfCounterTable["cpu.totalCapacity.average"]][$vcenter_cluster_host.moref.value][""]
                    if ($vcenter_cluster_host_cpu_totalCapacity -ge 0 -and $vcenter_cluster_host.summary.quickStats.overallCpuUsage -ge 0) {
                        $vcenter_cluster_h.add("vmw.$vcenter_name.$vcenter_cluster_dc_name.$vcenter_cluster_name.esx.$vcenter_cluster_host_name.fatstats.overallCpuUtilization", $($vcenter_cluster_host.summary.quickStats.overallCpuUsage * 100 / $vcenter_cluster_host_cpu_totalCapacity))
                    }
                }
            } catch {
                Write-Host "$((Get-Date).ToString("o")) [EROR] ESX $vcenter_cluster_host_name fatstats cpu.totalCapacity metrics issue in cluster $vcenter_cluster_name"
                Write-Host "$((Get-Date).ToString("o")) [EROR] $($Error[0])"
            }

            try {
                if ($HostMultiStats[$PerfCounterTable["mem.totalCapacity.average"]][$vcenter_cluster_host.moref.value]) {
                    $vcenter_cluster_host_mem_totalCapacity = $HostMultiStats[$PerfCounterTable["mem.totalCapacity.average"]][$vcenter_cluster_host.moref.value][""]
                    if ($vcenter_cluster_host_cpu_totalCapacity -ge 0 -and $vcenter_cluster_host.summary.quickStats.overallMemoryUsage -ge 0) {
                        $vcenter_cluster_h.add("vmw.$vcenter_name.$vcenter_cluster_dc_name.$vcenter_cluster_name.esx.$vcenter_cluster_host_name.fatstats.overallmemUtilization", $($vcenter_cluster_host.summary.quickStats.overallMemoryUsage * 100 / $vcenter_cluster_host_mem_totalCapacity))
                    }
                }
            } catch {
                Write-Host "$((Get-Date).ToString("o")) [EROR] ESX $vcenter_cluster_host_name fatstats mem.totalCapacity metrics issue in cluster $vcenter_cluster_name"
                Write-Host "$((Get-Date).ToString("o")) [EROR] $($Error[0])"
            }

            try {
                if ($HostMultiStats[$PerfCounterTable["cpu.latency.average"]][$vcenter_cluster_host.moref.value]) {
                    $vcenter_cluster_host_cpu_latency = $HostMultiStats[$PerfCounterTable["cpu.latency.average"]][$vcenter_cluster_host.moref.value][""]
                    if ($vcenter_cluster_host_cpu_latency -ge 0) {
                        $vcenter_cluster_hosts_cpu_latency += $vcenter_cluster_host_cpu_latency
                    }
                }
            } catch {
                Write-Host "$((Get-Date).ToString("o")) [EROR] ESX $vcenter_cluster_host_name fatstats cpu.latency metrics issue in cluster $vcenter_cluster_name"
                Write-Host "$((Get-Date).ToString("o")) [EROR] $($Error[0])"
            }

            try {
                if ($vcenter_cluster_host.overallStatus.value__) {
                    $vcenter_cluster_host_overallStatus = $vcenter_cluster_host.overallStatus.value__
                } else {
                    $vcenter_cluster_host_overallStatus = "0"
                }
                $vcenter_cluster_h.add("vmw.$vcenter_name.$vcenter_cluster_dc_name.$vcenter_cluster_name.esx.$vcenter_cluster_host_name.quickstats.overallStatus", $vcenter_cluster_host_overallStatus)
            } catch {
                Write-Host "$((Get-Date).ToString("o")) [EROR] ESX $vcenter_cluster_host_name fatstats overallStatus metrics issue in cluster $vcenter_cluster_name"
                Write-Host "$((Get-Date).ToString("o")) [EROR] $($Error[0])"
            }

            try {
                $vcenter_cluster_h.add("vmw.$vcenter_name.$vcenter_cluster_dc_name.$vcenter_cluster_name.esx.$vcenter_cluster_host_name.quickstats.distributedCpuFairness", $vcenter_cluster_host.summary.quickStats.distributedCpuFairness)
                $vcenter_cluster_h.add("vmw.$vcenter_name.$vcenter_cluster_dc_name.$vcenter_cluster_name.esx.$vcenter_cluster_host_name.quickstats.distributedMemoryFairness", $vcenter_cluster_host.summary.quickStats.distributedMemoryFairness)
            } catch {
                Write-Host "$((Get-Date).ToString("o")) [EROR] ESX $vcenter_cluster_host_name Distributed Fairness quickstats issue in cluster $vcenter_cluster_name"
                Write-Host "$((Get-Date).ToString("o")) [EROR] $($Error[0])"
            }

            try {
                $vcenter_cluster_h.add("vmw.$vcenter_name.$vcenter_cluster_dc_name.$vcenter_cluster_name.esx.$vcenter_cluster_host_name.quickstats.overallCpuUsage", $vcenter_cluster_host.summary.quickStats.overallCpuUsage)
                $vcenter_cluster_h.add("vmw.$vcenter_name.$vcenter_cluster_dc_name.$vcenter_cluster_name.esx.$vcenter_cluster_host_name.quickstats.overallMemoryUsage", $vcenter_cluster_host.summary.quickStats.overallMemoryUsage)
                $vcenter_cluster_h.add("vmw.$vcenter_name.$vcenter_cluster_dc_name.$vcenter_cluster_name.esx.$vcenter_cluster_host_name.quickstats.Uptime", $vcenter_cluster_host.summary.quickStats.uptime)

            } catch {
                Write-Host "$((Get-Date).ToString("o")) [EROR] ESX $vcenter_cluster_host_name overall quickstats issue in cluster $vcenter_cluster_name"
                Write-Host "$((Get-Date).ToString("o")) [EROR] $($Error[0])"
            }
        }

        if ($($vcenter_cluster.Host|Measure-Object).count -gt 0) {
            $vcenter_cluster_h.add("vmw.$vcenter_name.$vcenter_cluster_dc_name.$vcenter_cluster_name.superstats.esx.count", $($vcenter_cluster.Host|Measure-Object).count)
        }

        if ($vcenter_cluster_hosts_cpu_latency -gt 0) {
            $vcenter_cluster_h.add("vmw.$vcenter_name.$vcenter_cluster_dc_name.$vcenter_cluster_name.superstats.cpu.latency", $(GetMedian $vcenter_cluster_hosts_cpu_latency))
        }

        if ($vcenter_cluster_hosts_net_bytesRx -ge 0 -and $vcenter_cluster_hosts_net_bytesTx -ge 0) {
            $vcenter_cluster_h.add("vmw.$vcenter_name.$vcenter_cluster_dc_name.$vcenter_cluster_name.superstats.net.bytesRx", $vcenter_cluster_hosts_net_bytesRx)
            $vcenter_cluster_h.add("vmw.$vcenter_name.$vcenter_cluster_dc_name.$vcenter_cluster_name.superstats.net.bytesTx", $vcenter_cluster_hosts_net_bytesTx)
        }        

        if ($vcenter_cluster_hosts_hba_bytesRead -ge 0 -and $vcenter_cluster_hosts_hba_bytesWrite -ge 0) {
            $vcenter_cluster_h.add("vmw.$vcenter_name.$vcenter_cluster_dc_name.$vcenter_cluster_name.superstats.hba.bytesRead", $vcenter_cluster_hosts_hba_bytesRead)
            $vcenter_cluster_h.add("vmw.$vcenter_name.$vcenter_cluster_dc_name.$vcenter_cluster_name.superstats.hba.bytesWrite", $vcenter_cluster_hosts_hba_bytesWrite)
        } 

        if ($vcenter_cluster_hosts_power_usage -ge 0) {
            $vcenter_cluster_h.add("vmw.$vcenter_name.$vcenter_cluster_dc_name.$vcenter_cluster_name.superstats.power", $vcenter_cluster_hosts_power_usage)
        }

        Write-Host "$((Get-Date).ToString("o")) [INFO] Processing vCenter $vcenter_name cluster $vcenter_cluster_name vms in datacenter $vcenter_cluster_dc_name"

        $vcenter_cluster_vms_vcpus = 0
        $vcenter_cluster_vms_vram = 0
        $vcenter_cluster_vms_files_dedup = @{}
        $vcenter_cluster_vms_files_dedup_total = @{}
        $vcenter_cluster_vms_files_snaps = 0
        $vcenter_cluster_vms_snaps = 0
        $vcenter_cluster_vms_off = 0
        $vcenter_cluster_vms_on = 0
        $vcenter_cluster_vmdk_per_ds = @{}

        foreach ($vcenter_cluster_vm in $vcenter_cluster_hosts_vms_moref) {

            if ($vcenter_cluster_vm.config.version) {
                $vcenter_cluster_vm_vhw = NameCleaner $vcenter_cluster_vm.config.version
                $vmware_version_h["vi.$vcenter_name.vi.version.vm.$vcenter_cluster_dc_name.$vcenter_cluster_name.vhw.$vcenter_cluster_vm_vhw"] ++
            }

            if ($vcenter_cluster_vm.config.guestId) {
                $vcenter_cluster_vm_guestId = NameCleaner $vcenter_cluster_vm.config.guestId
                $vmware_version_h["vi.$vcenter_name.vi.version.vm.$vcenter_cluster_dc_name.$vcenter_cluster_name.guest.$vcenter_cluster_vm_guestId"] ++
            }

            if ($vcenter_cluster_vm.config.tools.toolsVersion) {
                $vcenter_cluster_vm_vmtools = NameCleaner $vcenter_cluster_vm.config.tools.toolsVersion
                $vmware_version_h["vi.$vcenter_name.vi.version.vm.$vcenter_cluster_dc_name.$vcenter_cluster_name.vmtools.$vcenter_cluster_vm_vmtools"] ++
            }

            $vcenter_cluster_vm_name = NameCleaner $vcenter_cluster_vm.Name

            try {
                $vcenter_cluster_vm_files = $vcenter_cluster_vm.layoutEx.file
                ### http://pubs.vmware.com/vsphere-60/topic/com.vmware.wSsdk.apiref.doc/vim.vm.FileLayoutEx.FileType.html

                $vcenter_cluster_vm_snap_size = 0

                if ($vcenter_cluster_vm.snapshot) {
                    $vcenter_cluster_vm_has_snap = 1
                    $vcenter_cluster_vms_snaps ++
                } else {
                    $vcenter_cluster_vm_has_snap = 0
                }

                $vcenter_cluster_vm_num_vdisk = $vcenter_cluster_vm.summary.config.numVirtualDisks
                $vcenter_cluster_vm_real_vdisk = 0
                $vcenter_cluster_vm_has_diskExtent = 0

                foreach ($vcenter_cluster_vm_file in $vcenter_cluster_vm_files) {
                    if ($vcenter_cluster_vm_file.type -eq "diskDescriptor") {
                        $vcenter_cluster_vm_real_vdisk ++
                        $vcenter_cluster_vm_file_ds_name = nameCleaner $([regex]::match($vcenter_cluster_vm_file.name, '^\[(.*)\]').Groups[1].value)
                        $vcenter_cluster_vmdk_per_ds[$vcenter_cluster_vm_file_ds_name] ++
                    } elseif ($vcenter_cluster_vm_file.type -eq "diskExtent") {
                        $vcenter_cluster_vm_has_diskExtent ++
                    }
                }

                if ($vcenter_cluster_vm_real_vdisk -gt $vcenter_cluster_vm_num_vdisk) {
                    $vcenter_cluster_vm_has_snap = 1
                }

                foreach ($vcenter_cluster_vm_file in $vcenter_cluster_vm_files) {
                    if(!$vcenter_cluster_vms_files_dedup[$vcenter_cluster_vm_file.name]) { ### TODO would need name & moref
                        $vcenter_cluster_vms_files_dedup[$vcenter_cluster_vm_file.name] = $vcenter_cluster_vm_file.size
                        if ($vcenter_cluster_vm_has_snap -and (($vcenter_cluster_vm_file.name -match '-[0-9]{6}-delta\.vmdk') -or ($vcenter_cluster_vm_file.name -match '-[0-9]{6}-sesparse\.vmdk'))) {
                            $vcenter_cluster_vms_files_dedup_total["snapshotExtent"] += $vcenter_cluster_vm_file.size
                            $vcenter_cluster_vm_snap_size += $vcenter_cluster_vm_file.size
                        } elseif ($vcenter_cluster_vm_has_snap -and ($vcenter_cluster_vm_file.name -match '-[0-9]{6}\.vmdk')) {
                            $vcenter_cluster_vms_files_dedup_total["snapshotDescriptor"] += $vcenter_cluster_vm_file.size
                            $vcenter_cluster_vm_snap_size += $vcenter_cluster_vm_file.size
                            $vcenter_cluster_vms_files_snaps ++
                        } elseif ($vcenter_cluster_vm_file.name -match '-rdm\.vmdk') {
                            $vcenter_cluster_vms_files_dedup_total["rdmExtent"] += $vcenter_cluster_vm_file.size
                        } elseif ($vcenter_cluster_vm_file.name -match '-rdmp\.vmdk') {
                            $vcenter_cluster_vms_files_dedup_total["rdmpExtent"] += $vcenter_cluster_vm_file.size
                        } elseif ((!$vcenter_cluster_vm_has_diskExtent) -and $vcenter_cluster_vm_file.type -eq "diskDescriptor") {
                            $vcenter_cluster_vms_files_dedup_total["virtualExtent"] += $vcenter_cluster_vm_file.size
                        } else {
                            $vcenter_cluster_vms_files_dedup_total[$vcenter_cluster_vm_file.type] += $vcenter_cluster_vm_file.size
                        }
                    }
                }

                if ($vcenter_cluster_vm_snap_size -gt 0) {
                    $vcenter_cluster_h.add("vmw.$vcenter_name.$vcenter_cluster_dc_name.$vcenter_cluster_name.vm.$vcenter_cluster_vm_name.storage.delta", $vcenter_cluster_vm_snap_size)
                }
            } catch {
                Write-Host "$((Get-Date).ToString("o")) [EROR] VM $vcenter_cluster_vm_name snapshot compute issue in cluster $vcenter_cluster_name"
                Write-Host "$((Get-Date).ToString("o")) [EROR] $($Error[0])"
            }

            try {
                $vcenter_cluster_h.add("vmw.$vcenter_name.$vcenter_cluster_dc_name.$vcenter_cluster_name.vm.$vcenter_cluster_vm_name.storage.committed", $vcenter_cluster_vm.summary.storage.committed)
                $vcenter_cluster_h.add("vmw.$vcenter_name.$vcenter_cluster_dc_name.$vcenter_cluster_name.vm.$vcenter_cluster_vm_name.storage.uncommitted", $vcenter_cluster_vm.summary.storage.uncommitted)
            } catch {
                Write-Host "$((Get-Date).ToString("o")) [EROR] VM $vcenter_cluster_vm_name storage commit metric issue in cluster $vcenter_cluster_name"
                Write-Host "$((Get-Date).ToString("o")) [EROR] $($Error[0])"
            }

            if ($vcenter_cluster_vm.summary.runtime.powerState -eq "poweredOn") {
                $vcenter_cluster_vms_on ++

                $vcenter_cluster_vms_vcpus += $vcenter_cluster_vm.config.hardware.numCPU
                $vcenter_cluster_vms_vram += $vcenter_cluster_vm.runtime.maxMemoryUsage


                if ($vcenter_cluster_vm.runtime.maxCpuUsage -gt 0 -and $vcenter_cluster_vm.summary.quickStats.overallCpuUsage) {
                    $vcenter_cluster_vm_CpuUtilization = $vcenter_cluster_vm.summary.quickStats.overallCpuUsage * 100 / $vcenter_cluster_vm.runtime.maxCpuUsage
                    $vcenter_cluster_h.add("vmw.$vcenter_name.$vcenter_cluster_dc_name.$vcenter_cluster_name.vm.$vcenter_cluster_vm_name.runtime.CpuUtilization", $vcenter_cluster_vm_CpuUtilization)
                } else {
                    $vcenter_cluster_h.add("vmw.$vcenter_name.$vcenter_cluster_dc_name.$vcenter_cluster_name.vm.$vcenter_cluster_vm_name.runtime.CpuUtilization", 0)
                }

                if ($vcenter_cluster_vm.summary.quickStats.guestMemoryUsage -gt 0 -and $vcenter_cluster_vm.runtime.maxMemoryUsage) {
                    $vcenter_cluster_vm_MemUtilization = $vcenter_cluster_vm.summary.quickStats.guestMemoryUsage * 100 / $vcenter_cluster_vm.runtime.maxMemoryUsage
                    $vcenter_cluster_h.add("vmw.$vcenter_name.$vcenter_cluster_dc_name.$vcenter_cluster_name.vm.$vcenter_cluster_vm_name.runtime.MemUtilization", $vcenter_cluster_vm_MemUtilization)
                }

                $vcenter_cluster_h.add("vmw.$vcenter_name.$vcenter_cluster_dc_name.$vcenter_cluster_name.vm.$vcenter_cluster_vm_name.quickstats.overallCpuUsage", $vcenter_cluster_vm.summary.quickStats.overallCpuUsage)
                $vcenter_cluster_h.add("vmw.$vcenter_name.$vcenter_cluster_dc_name.$vcenter_cluster_name.vm.$vcenter_cluster_vm_name.quickstats.overallCpuDemand", $vcenter_cluster_vm.summary.quickStats.overallCpuDemand)
                $vcenter_cluster_h.add("vmw.$vcenter_name.$vcenter_cluster_dc_name.$vcenter_cluster_name.vm.$vcenter_cluster_vm_name.quickstats.HostMemoryUsage", $vcenter_cluster_vm.summary.quickStats.hostMemoryUsage)
                $vcenter_cluster_h.add("vmw.$vcenter_name.$vcenter_cluster_dc_name.$vcenter_cluster_name.vm.$vcenter_cluster_vm_name.quickstats.GuestMemoryUsage", $vcenter_cluster_vm.summary.quickStats.guestMemoryUsage)

                if ($vcenter_cluster_vm.summary.quickStats.balloonedMemory -gt 0) {
                    $vcenter_cluster_h.add("vmw.$vcenter_name.$vcenter_cluster_dc_name.$vcenter_cluster_name.vm.$vcenter_cluster_vm_name.quickstats.BalloonedMemory", $vcenter_cluster_vm.summary.quickStats.balloonedMemory)
                }

                if ($vcenter_cluster_vm.summary.quickStats.compressedMemory -gt 0) {
                    $vcenter_cluster_h.add("vmw.$vcenter_name.$vcenter_cluster_dc_name.$vcenter_cluster_name.vm.$vcenter_cluster_vm_name.quickstats.CompressedMemory", $vcenter_cluster_vm.summary.quickStats.compressedMemory)
                }

                if ($vcenter_cluster_vm.summary.quickStats.swappedMemory -gt 0) {
                    $vcenter_cluster_h.add("vmw.$vcenter_name.$vcenter_cluster_dc_name.$vcenter_cluster_name.vm.$vcenter_cluster_vm_name.quickstats.SwappedMemory", $vcenter_cluster_vm.summary.quickStats.swappedMemory)
                }

                if ($VmMultiStats[$PerfCounterTable["cpu.ready.summation"]][$vcenter_cluster_vm.moref.value][""]) {
                    $vcenter_cluster_vm_ready = $VmMultiStats[$PerfCounterTable["cpu.ready.summation"]][$vcenter_cluster_vm.moref.value][""] / $vcenter_cluster_vm.config.hardware.numCPU / 20000 * 100 
                    ### https://kb.vmware.com/kb/2002181
                    $vcenter_cluster_h.add("vmw.$vcenter_name.$vcenter_cluster_dc_name.$vcenter_cluster_name.vm.$vcenter_cluster_vm_name.fatstats.cpu_ready_summation", $vcenter_cluster_vm_ready)
                }

                if ($VmMultiStats[$PerfCounterTable["cpu.wait.summation"]][$vcenter_cluster_vm.moref.value][""] -and $VmMultiStats[$PerfCounterTable["cpu.idle.summation"]][$vcenter_cluster_vm.moref.value][""]) {
                    $vcenter_cluster_vm_io_wait = ($VmMultiStats[$PerfCounterTable["cpu.wait.summation"]][$vcenter_cluster_vm.moref.value][""] - $VmMultiStats[$PerfCounterTable["cpu.idle.summation"]][$vcenter_cluster_vm.moref.value][""]) / $vcenter_cluster_vm.config.hardware.numCPU / 20000 * 100 
                    ### https://code.vmware.com/apis/358/vsphere#/doc/cpu_counters.html
                    ### "Total CPU time spent in wait state.The wait total includes time spent the CPU Idle, CPU Swap Wait, and CPU I/O Wait states."
                    # https://kb.vmware.com/s/article/85393
                    $vcenter_cluster_h.add("vmw.$vcenter_name.$vcenter_cluster_dc_name.$vcenter_cluster_name.vm.$vcenter_cluster_vm_name.fatstats.cpu_wait_no_idle", $vcenter_cluster_vm_io_wait)
                }

                if ($VmMultiStats[$PerfCounterTable["cpu.latency.average"]][$vcenter_cluster_vm.moref.value][""]) {
                    $vcenter_cluster_vm_cpu_latency = $VmMultiStats[$PerfCounterTable["cpu.latency.average"]][$vcenter_cluster_vm.moref.value][""]
                    $vcenter_cluster_h.add("vmw.$vcenter_name.$vcenter_cluster_dc_name.$vcenter_cluster_name.vm.$vcenter_cluster_vm_name.fatstats.cpu_latency_average", $vcenter_cluster_vm_cpu_latency)
                }

                if ($VmMultiStats[$PerfCounterTable["disk.maxTotalLatency.latest"]][$vcenter_cluster_vm.moref.value][""]) {
                    $vcenter_cluster_vm_disk_latency = $VmMultiStats[$PerfCounterTable["disk.maxTotalLatency.latest"]][$vcenter_cluster_vm.moref.value][""]
                    $vcenter_cluster_h.add("vmw.$vcenter_name.$vcenter_cluster_dc_name.$vcenter_cluster_name.vm.$vcenter_cluster_vm_name.fatstats.maxTotalLatency", $vcenter_cluster_vm_disk_latency)
                }

                if ($VmMultiStats[$PerfCounterTable["virtualdisk.write.average"]][$vcenter_cluster_vm.moref.value][""] -ge 0 -and $VmMultiStats[$PerfCounterTable["virtualdisk.read.average"]][$vcenter_cluster_vm.moref.value][""] -ge 0) {
                    $vcenter_cluster_vm_disk_usage = $VmMultiStats[$PerfCounterTable["virtualdisk.write.average"]][$vcenter_cluster_vm.moref.value][""] + $VmMultiStats[$PerfCounterTable["virtualdisk.read.average"]][$vcenter_cluster_vm.moref.value][""]
                    $vcenter_cluster_h.add("vmw.$vcenter_name.$vcenter_cluster_dc_name.$vcenter_cluster_name.vm.$vcenter_cluster_vm_name.fatstats.diskUsage", $vcenter_cluster_vm_disk_usage)
                } else {
                    $vcenter_cluster_h.add("vmw.$vcenter_name.$vcenter_cluster_dc_name.$vcenter_cluster_name.vm.$vcenter_cluster_vm_name.fatstats.diskUsage", 0)
                }

                if ($VmMultiStats[$PerfCounterTable["virtualdisk.numberWriteAveraged.average"]][$vcenter_cluster_vm.moref.value] -and $VmMultiStats[$PerfCounterTable["virtualdisk.numberReadAveraged.average"]][$vcenter_cluster_vm.moref.value]) {
                    $vcenter_cluster_vm_disk_iops = $($VmMultiStats[$PerfCounterTable["virtualdisk.numberWriteAveraged.average"]][$vcenter_cluster_vm.moref.value][$($VmMultiStats[$PerfCounterTable["virtualdisk.numberWriteAveraged.average"]][$vcenter_cluster_vm.moref.value]).Keys]|Measure-Object -Sum).Sum + $($VmMultiStats[$PerfCounterTable["virtualdisk.numberReadAveraged.average"]][$vcenter_cluster_vm.moref.value][$($VmMultiStats[$PerfCounterTable["virtualdisk.numberWriteAveraged.average"]][$vcenter_cluster_vm.moref.value]).Keys]|Measure-Object -Sum).Sum
                    $vcenter_cluster_h.add("vmw.$vcenter_name.$vcenter_cluster_dc_name.$vcenter_cluster_name.vm.$vcenter_cluster_vm_name.fatstats.diskIOPS", $vcenter_cluster_vm_disk_iops)
                }

                # if ($VmMultiStats[$PerfCounterTable["net.packetsTx.summation"]][$vcenter_cluster_vm.moref.value] -and $VmMultiStats[$PerfCounterTable["net.packetsRx.summation"]][$vcenter_cluster_vm.moref.value]) {
                #     $vcenter_cluster_vm_net_iops = $($($VmMultiStats[$PerfCounterTable["net.packetsTx.summation"]][$vcenter_cluster_vm.moref.value][$($VmMultiStats[$PerfCounterTable["net.packetsTx.summation"]][$vcenter_cluster_vm.moref.value]).Keys]|Measure-Object -Sum).Sum + $($VmMultiStats[$PerfCounterTable["net.packetsRx.summation"]][$vcenter_cluster_vm.moref.value][$($VmMultiStats[$PerfCounterTable["net.packetsTx.summation"]][$vcenter_cluster_vm.moref.value]).Keys]|Measure-Object -Sum).Sum) / 300
                #     $vcenter_cluster_h.add("vmw.$vcenter_name.$vcenter_cluster_dc_name.$vcenter_cluster_name.vm.$vcenter_cluster_vm_name.fatstats.netIOPS", $vcenter_cluster_vm_net_iops)
                # }

                if ($VmMultiStats[$PerfCounterTable["net.usage.average"]][$vcenter_cluster_vm.moref.value][""]) {
                    $vcenter_cluster_vm_net_usage = $VmMultiStats[$PerfCounterTable["net.usage.average"]][$vcenter_cluster_vm.moref.value][""]
                    $vcenter_cluster_h.add("vmw.$vcenter_name.$vcenter_cluster_dc_name.$vcenter_cluster_name.vm.$vcenter_cluster_vm_name.fatstats.netUsage", $vcenter_cluster_vm_net_usage)
                } else {
                    $vcenter_cluster_h.add("vmw.$vcenter_name.$vcenter_cluster_dc_name.$vcenter_cluster_name.vm.$vcenter_cluster_vm_name.fatstats.netUsage", 0)
                }

            } elseif ($vcenter_cluster_vm.summary.runtime.powerState -eq "poweredOff") {
                $vcenter_cluster_vms_off ++
            }
        }

        if ($vcenter_cluster_vms_vcpus -gt 0 -and $vcenter_cluster_hosts_pcpus -gt 0) {
            $vcenter_cluster_h.add("vmw.$vcenter_name.$vcenter_cluster_dc_name.$vcenter_cluster_name.quickstats.vCPUs", $vcenter_cluster_vms_vcpus)
            $vcenter_cluster_h.add("vmw.$vcenter_name.$vcenter_cluster_dc_name.$vcenter_cluster_name.quickstats.pCPUs", $vcenter_cluster_hosts_pcpus)
        }
        
        if ($vcenter_cluster_vms_vram -gt 0 -and $vcenter_cluster.summary.effectiveMemory -gt 0) {
            $vcenter_cluster_pool_quickstats_vram = $vcenter_cluster_vms_vram * 100 / $vcenter_cluster.summary.effectiveMemory
            $vcenter_cluster_h.add("vmw.$vcenter_name.$vcenter_cluster_dc_name.$vcenter_cluster_name.quickstats.vRAM", $vcenter_cluster_vms_vram)
            $vcenter_cluster_h.add("vmw.$vcenter_name.$vcenter_cluster_dc_name.$vcenter_cluster_name.superstats.mem.allocated", $vcenter_cluster_pool_quickstats_vram)
        }

        if ($vcenter_cluster_vms_files_dedup_total) {
            foreach ($vcenter_cluster_vms_filetype in $vcenter_cluster_vms_files_dedup_total.keys) {
                $vcenter_cluster_h.add("vmw.$vcenter_name.$vcenter_cluster_dc_name.$vcenter_cluster_name.storage.FileType.$vcenter_cluster_vms_filetype", $vcenter_cluster_vms_files_dedup_total[$vcenter_cluster_vms_filetype])
            }

            if ($vcenter_cluster_vms_files_snaps) {
                $vcenter_cluster_h.add("vmw.$vcenter_name.$vcenter_cluster_dc_name.$vcenter_cluster_name.storage.SnapshotCount", $vcenter_cluster_vms_files_snaps)
            }

            if ($vcenter_cluster_vms_snaps) {
                $vcenter_cluster_h.add("vmw.$vcenter_name.$vcenter_cluster_dc_name.$vcenter_cluster_name.storage.VmSnapshotCount", $vcenter_cluster_vms_snaps)
            }
        }

        $vcenter_cluster_h.add("vmw.$vcenter_name.$vcenter_cluster_dc_name.$vcenter_cluster_name.runtime.vm.total", ($vcenter_cluster_vms_on + $vcenter_cluster_vms_off))
        $vcenter_cluster_h.add("vmw.$vcenter_name.$vcenter_cluster_dc_name.$vcenter_cluster_name.runtime.vm.on", $vcenter_cluster_vms_on)
        $vcenter_cluster_h.add("vmw.$vcenter_name.$vcenter_cluster_dc_name.$vcenter_cluster_name.runtime.vm.dead", $vcenter_cluster_hosts_vms_dead)

        Write-Host "$((Get-Date).ToString("o")) [INFO] Processing vCenter $vcenter_name cluster $vcenter_cluster_name datastores in datacenter $vcenter_cluster_dc_name"

        $vcenter_cluster_datastores_count = 0
        $vcenter_cluster_datastores_capacity = 0
        $vcenter_cluster_datastores_freeSpace = 0
        $vcenter_cluster_datastores_uncommitted = 0
        $vcenter_cluster_datastores_latency = @()
        $vcenter_cluster_datastores_iops = 0

        foreach ($vcenter_cluster_datastore in $vcenter_datastores_h[$vcenter_cluster.Datastore.Value]|?{$_}) {
            if ($vcenter_cluster_datastore.summary.accessible -and $vcenter_cluster_datastore.summary.multipleHostAccess) {
                try {
                    $vcenter_cluster_datastore_name = NameCleaner $vcenter_cluster_datastore.summary.name

                    $vcenter_cluster_datastores_count ++

                    $vcenter_cluster_datastore_hosts = $vcenter_cluster_hosts_h[$(($vcenter_cluster_datastore.Host|?{$_.mountinfo.Accessible}).key).value].moref

                    if ($vcenter_cluster_datastore.summary.uncommitted -ge 0) {
                        $vcenter_cluster_datastore_uncommitted = $vcenter_cluster_datastore.summary.uncommitted
                    } else {
                        $vcenter_cluster_datastore_uncommitted = 0
                    }

                    $vcenter_cluster_h.add("vmw.$vcenter_name.$vcenter_cluster_dc_name.$vcenter_cluster_name.datastore.$vcenter_cluster_datastore_name.summary.capacity", $vcenter_cluster_datastore.summary.capacity)
                    $vcenter_cluster_h.add("vmw.$vcenter_name.$vcenter_cluster_dc_name.$vcenter_cluster_name.datastore.$vcenter_cluster_datastore_name.summary.freeSpace", $vcenter_cluster_datastore.summary.freeSpace)
                    $vcenter_cluster_h.add("vmw.$vcenter_name.$vcenter_cluster_dc_name.$vcenter_cluster_name.datastore.$vcenter_cluster_datastore_name.summary.uncommitted", $vcenter_cluster_datastore_uncommitted)

                    if ($vcenter_cluster_datastore.summary.capacity -gt 0 -and $vcenter_cluster_datastore.summary.capacity -gt $vcenter_cluster_datastore.summary.freeSpace) {
                        $vcenter_cluster_datastore_usagepct = ($vcenter_cluster_datastore.summary.capacity - $vcenter_cluster_datastore.summary.freeSpace) * 100 / $vcenter_cluster_datastore.summary.capacity
                        $vcenter_cluster_h.add("vmw.$vcenter_name.$vcenter_cluster_dc_name.$vcenter_cluster_name.datastore.$vcenter_cluster_datastore_name.summary.usagePct", $vcenter_cluster_datastore_usagepct)
                    }

                    if ($vcenter_cluster_vmdk_per_ds[$vcenter_cluster_datastore_name]) {
                        $vcenter_cluster_h.add("vmw.$vcenter_name.$vcenter_cluster_dc_name.$vcenter_cluster_name.datastore.$vcenter_cluster_datastore_name.summary.vmdkCount", $vcenter_cluster_vmdk_per_ds[$vcenter_cluster_datastore_name])
                    }

                    $vcenter_cluster_datastores_capacity += $vcenter_cluster_datastore.summary.capacity
                    $vcenter_cluster_datastores_freeSpace += $vcenter_cluster_datastore.summary.freeSpace
                    $vcenter_cluster_datastores_uncommitted += $vcenter_cluster_datastore_uncommitted

                } catch {
                    Write-Host "$((Get-Date).ToString("o")) [EROR] datastore processing issue in cluster $vcenter_cluster_name"
                    Write-Host "$((Get-Date).ToString("o")) [EROR] $($Error[0])"
                }

                if ($vcenter_cluster_datastore.summary.type -notmatch "vsan") {
                    try {
                        $vcenter_cluster_datastore_uuid = $vcenter_cluster_datastore.summary.url.split("/")[-2]

                        $vcenter_cluster_datastore_latency_raw = $($HostMultiStats[$PerfCounterTable["datastore.sizeNormalizedDatastoreLatency.average"]][$vcenter_cluster_datastore_hosts.value])|?{$_.count -gt 0}|%{$_[$vcenter_cluster_datastore_uuid]} #347
                        $vcenter_cluster_datastore_latency = GetMedian $vcenter_cluster_datastore_latency_raw
                        if ($vcenter_cluster_datastore_latency -eq 0) {
                            $vcenter_cluster_datastore_latency_raw = $HostMultiStats[$PerfCounterTable["datastore.totalWriteLatency.average"]][$vcenter_cluster_datastore_hosts.value]|%{$_[$vcenter_cluster_datastore_uuid]}
                            $vcenter_cluster_datastore_latency = $(GetMedian $vcenter_cluster_datastore_latency_raw) * 1000
                        }
                        $vcenter_cluster_h.add("vmw.$vcenter_name.$vcenter_cluster_dc_name.$vcenter_cluster_name.datastore.$vcenter_cluster_datastore_name.iorm.sizeNormalizedDatastoreLatency", $vcenter_cluster_datastore_latency)
                        $vcenter_cluster_datastores_latency += $vcenter_cluster_datastore_latency

                        $vcenter_cluster_datastore_iops_w = $HostMultiStats[$PerfCounterTable["datastore.numberWriteAveraged.average"]][$vcenter_cluster_datastore_hosts.value]|%{$_[$vcenter_cluster_datastore_uuid]}
                        $vcenter_cluster_datastore_iops_r = $HostMultiStats[$PerfCounterTable["datastore.numberReadAveraged.average"]][$vcenter_cluster_datastore_hosts.value]|%{$_[$vcenter_cluster_datastore_uuid]}
                        $vcenter_cluster_datastore_iops = ($vcenter_cluster_datastore_iops_w|Measure-Object -Sum).Sum + ($vcenter_cluster_datastore_iops_r|Measure-Object -Sum).Sum
                        $vcenter_cluster_h.add("vmw.$vcenter_name.$vcenter_cluster_dc_name.$vcenter_cluster_name.datastore.$vcenter_cluster_datastore_name.iorm.datastoreIops", $vcenter_cluster_datastore_iops)
                        $vcenter_cluster_datastores_iops += $vcenter_cluster_datastore_iops
                    } catch {
                        Write-Host "$((Get-Date).ToString("o")) [WARN] Unable to retreive performance metrics for datastore $vcenter_cluster_datastore_name in cluster $vcenter_cluster_name"
                        Write-Host "$((Get-Date).ToString("o")) [WARN] $($Error[0])"
                    }

                } else { # VsanPullStatistics

                    $vcenter_cluster_datastore_vsan_cluster_uuid = $vcenter_cluster_host.Config.VsanHostConfig.ClusterInfo.Uuid
                    $vcenter_cluster_datastore_vsan_uuid = $([regex]::match($vcenter_cluster_datastore.summary.url,'.*vsan:(.*)\/').Groups[1].value)

                    if ($vcenter_cluster_datastore_vsan_cluster_uuid.replace("-","") -match $vcenter_cluster_datastore_vsan_uuid.replace("-","") -and $vSanPull -and $ServiceInstance.Content.About.ApiVersion -ge 6.7) { # skip vSAN HCI Mesh
                        
                        Write-Host "$((Get-Date).ToString("o")) [INFO] Start processing VsanPerfQuery in cluster $vcenter_cluster_name (v6.7+) ..."
                        # https://vdc-download.vmware.com/vmwb-repository/dcr-public/bd51bfdb-3107-4a66-9f63-30aa3fae196e/98507723-ab67-4908-88fa-7c99e0743f0f/vim.cluster.VsanPerformanceManager.html#queryVsanPerf
                        # MethodInvocationException: Exception calling "VsanPerfQueryPerf" with "2" argument(s): "Invalid Argument. Only one wildcard query allowed in query specs." # Config.VsanHostConfig.ClusterInfo.NodeUuid
                        # $VsanPerformanceManager.VsanPerfQueryStatsObjectInformation($vcenter_cluster.moref).VsanHealth
                        $VsanHostsAndClusterPerfQuerySpec = @()
                        # cluster-domclient
                        $VsanHostsAndClusterPerfQuerySpec += New-Object VMware.Vsan.Views.VsanPerfQuerySpec -property @{entityRefId="cluster-domclient:$vcenter_cluster_datastore_vsan_cluster_uuid";labels=@("latencyAvgRead","latencyAvgWrite","iopsWrite","iopsRead");startTime=$ServiceInstanceServerClock_5;endTime=$ServiceInstanceServerClock}

                        # host-domclient host-domowner host-domcompmgr
                        foreach ($vcenter_vmhost_NodeUuid in $vcenter_vmhosts_moref_NodeUuid_h[$vcenter_cluster.Host.value]|?{$_}) {
                            $VsanHostsAndClusterPerfQuerySpec += New-Object VMware.Vsan.Views.VsanPerfQuerySpec -property @{entityRefId="host-domclient:$vcenter_vmhost_NodeUuid";labels=@("iopsRead","iopsWrite","throughputRead","throughputWrite","latencyAvgRead","latencyAvgWrite","readCongestion","writeCongestion","oio","clientCacheHitRate");startTime=$ServiceInstanceServerClock_5;endTime=$ServiceInstanceServerClock}
                            $VsanHostsAndClusterPerfQuerySpec += New-Object VMware.Vsan.Views.VsanPerfQuerySpec -property @{entityRefId="host-domowner:$vcenter_vmhost_NodeUuid";labels=@("iopsRead","iopsWrite","tputRead","tputWrite","latencyAvgRead","latencyAvgWrite","readCongestion","writeCongestion","latencyAvgRecWrite","iopsResyncRead","iopsRecWrite","tputResyncRead","oio","latencyAvgResyncRead","tputRecWrite");startTime=$ServiceInstanceServerClock_5;endTime=$ServiceInstanceServerClock}
                            $VsanHostsAndClusterPerfQuerySpec += New-Object VMware.Vsan.Views.VsanPerfQuerySpec -property @{entityRefId="dom-proxy-owner:$vcenter_vmhost_NodeUuid";labels=@("anchorRWResyncCongestion","proxyLatencyAvgRead","anchorLatencyAvgRead","proxyIopsWrite","proxyTputRWResync","anchorLatencyAvgRWResync","anchorIopsRWResync","proxyTputWrite","proxyLatencyAvgRWResync","proxyReadCongestion","anchorTputRWResync","anchorLatencyAvgWrite","proxyLatencyAvgWrite","anchorReadCongestion","proxyIopsRWResync","proxyWriteCongestion","proxyRWResyncCongestion","anchorIopsRead","proxyTputRead","anchorWriteCongestion","anchorTputRead","proxyIopsRead","anchorTputWrite","anchorIopsWrite");startTime=$ServiceInstanceServerClock_5;endTime=$ServiceInstanceServerClock}
                            $VsanHostsAndClusterPerfQuerySpec += New-Object VMware.Vsan.Views.VsanPerfQuerySpec -property @{entityRefId="host-domcompmgr:$vcenter_vmhost_NodeUuid";labels=@("iopsRead","iopsWrite","throughputRead","throughputWrite","latencyAvgRead","latencyAvgWrite","readCongestion","writeCongestion","latencyAvgRecWrite","iopsResyncRead","iopsRecWrite","tputResyncRead","resyncReadCongestion","recWriteCongestion","latAvgResyncRead","throughputRecWrite","oio");startTime=$ServiceInstanceServerClock_5;endTime=$ServiceInstanceServerClock}
                            $VsanHostsAndClusterPerfQuerySpec += New-Object VMware.Vsan.Views.VsanPerfQuerySpec -property @{entityRefId="vsan-host-net:$vcenter_vmhost_NodeUuid";labels=@("rxThroughput","txThroughput","rxPackets","txPackets","txPacketsLossRate","tcpTxRexmitRate","rxPacketsLossRate","tcpRxErrRate","portRxpkts","portTxpkts","portTxDrops","portRxDrops");startTime=$ServiceInstanceServerClock_5;endTime=$ServiceInstanceServerClock}
                        }

                        # vsan-vnic-net
                        # $VsanHostsAndClusterPerfQuerySpec += New-Object VMware.Vsan.Views.VsanPerfQuerySpec -property @{entityRefId="vsan-vnic-net:*";labels=@("rxThroughput","txThroughput","rxPackets","txPackets","tcpSackRcvBlocksRate","txPacketsLossRate","tcpSackRexmitsRate","rxPacketsLossRate","tcpHalfopenDropRate","tcpRcvoopackRate","tcpRcvduppackRate","tcpRcvdupackRate","tcpTimeoutDropRate","tcpTxRexmitRate","tcpRxErrRate","tcpSackSendBlocksRate");startTime=$ServiceInstanceServerClock_5;endTime=$ServiceInstanceServerClock} # "arpDropRate"

                        if ($vcenter_clusters_vsan_efa_h[$vcenter_cluster_moref]) { # EFA vSan cluster
                            Write-Host "$((Get-Date).ToString("o")) [INFO] Processing EFA vSAN metrics in cluster $vcenter_cluster_name (v8.0+) ..."
                            # VsanClusterHealthSummary/VsanPhysicalDiskHealthSummary better than VsanManagedDisksInfo since we can query at the cluster level
                            # $VsanHostsAndClusterStoragePoolSpec = New-Object VMware.Vsan.Views.VimVsanHostQueryVsanDisksSpec -property @{vsanDiskType="storagePool"}
                            try {
                                $ClusterHealthSummary = $VsanClusterHealthSystem.VsanQueryVcClusterHealthSummary($vcenter_cluster.moref,$null,$null,$false,"physicalDisksHealth",$true,$null,$null,$null)
                            } catch {
                                Write-Host "$((Get-Date).ToString("o")) [WARN] Unable to retreive VsanQueryVcClusterHealthSummary in cluster $vcenter_cluster_name"
                                Write-Host "$((Get-Date).ToString("o")) [WARN] $($Error[0])"
                            }

                            if ($ClusterHealthSummary.PhysicalDisksHealth) {
                                $PhysicalDisksHealthVsanUuidHosts = @{}
                                $PhysicalDisksHealthVsanUuidObj = @{}
                                foreach ($PhysicalDisksHealthHost in $ClusterHealthSummary.PhysicalDisksHealth) {
                                    foreach ($PhysicalDisksHealthHostDisk in $PhysicalDisksHealthHost.Disks) {
                                        if (!$PhysicalDisksHealthVsanUuidHosts[$PhysicalDisksHealthHostDisk.Uuid]) {
                                            $PhysicalDisksHealthVsanUuidHosts.add($PhysicalDisksHealthHostDisk.Uuid,$PhysicalDisksHealthHost.Hostname)
                                        }
                                        if (!$PhysicalDisksHealthVsanUuidObj[$PhysicalDisksHealthHostDisk.Uuid]) {
                                            $PhysicalDisksHealthVsanUuidObj.add($PhysicalDisksHealthHostDisk.Uuid,$PhysicalDisksHealthHostDisk)
                                        }
                                    }
                                }
                                foreach ($PhysicalDisksHealthVsanUuid in $PhysicalDisksHealthVsanUuidHosts.keys) {
                                    $VsanHostsAndClusterPerfQuerySpec += New-Object VMware.Vsan.Views.VsanPerfQuerySpec -property @{entityRefId="vsan-esa-disk-scsifw:$PhysicalDisksHealthVsanUuid";labels=@("latencyDevRead","latencyDevWrite");startTime=$ServiceInstanceServerClock_5;endTime=$ServiceInstanceServerClock}
                                }
                            } else {
                                Write-Host "$((Get-Date).ToString("o")) [WARN] Empty vSAN PhysicalDisksHealth in cluster $vcenter_cluster_name"
                            }
                        } else { # Non EFA vSAN cluster
                            # cache-disk disk-group
                            foreach ($vcenter_cluster_vsan_Ssd_uuid in $vcenter_clusters_vsan_Ssd_uuid_naa_h[$vcenter_cluster_moref].keys) {
                                $VsanHostsAndClusterPerfQuerySpec += New-Object VMware.Vsan.Views.VsanPerfQuerySpec -property @{entityRefId="cache-disk:$vcenter_cluster_vsan_Ssd_uuid";labels=@("latencyDevRead","latencyDevWrite","wbFreePct");startTime=$ServiceInstanceServerClock_5;endTime=$ServiceInstanceServerClock}
                            }

                            # capacity-disk
                            foreach ($vcenter_cluster_vsan_nonSsd_uuid in $vcenter_clusters_vsan_nonSsd_uuid_naa_h[$vcenter_cluster_moref].keys) {
                                $VsanHostsAndClusterPerfQuerySpec += New-Object VMware.Vsan.Views.VsanPerfQuerySpec -property @{entityRefId="capacity-disk:$vcenter_cluster_vsan_nonSsd_uuid";labels=@("latencyDevRead","latencyDevWrite","capacityUsed");startTime=$ServiceInstanceServerClock_5;endTime=$ServiceInstanceServerClock}
                            }
                        }

                        try {
                            $VsanHostsAndClusterPerfQueryTime = Measure-Command {$VsanHostsAndClusterPerfQuery = $VsanPerformanceManager.VsanPerfQueryPerf($VsanHostsAndClusterPerfQuerySpec,$vcenter_cluster.moref)}
                            Write-Host "$((Get-Date).ToString("o")) [INFO] VsanPerfQueryPerf metrics collected in $($VsanHostsAndClusterPerfQueryTime.TotalSeconds) sec for vSAN Cluster $vcenter_cluster_name in vCenter $vcenter_name"

                        } catch {
                            Write-Host "$((Get-Date).ToString("o")) [WARN] Unable to retreive VsanPerfQuery in cluster $vcenter_cluster_name"
                            Write-Host "$((Get-Date).ToString("o")) [WARN] $($Error[0])"
                        }
                            
                        if ($VsanHostsAndClusterPerfQuery) {
                            $VsanPerfEntityMetric = @{}
                            foreach ($VsanHostsAndClusterPerfEntity in $VsanHostsAndClusterPerfQuery) {
                                $VsanHostsAndClusterPerfMetrics = @{}
                                foreach ($VsanHostsAndClusterPerfEntityMetrics in $VsanHostsAndClusterPerfEntity.Value) {
                                    if (!$VsanHostsAndClusterPerfMetrics[$VsanHostsAndClusterPerfEntityMetrics.MetricId.Label]) {
                                        $VsanHostsAndClusterPerfMetrics.add($VsanHostsAndClusterPerfEntityMetrics.MetricId.Label,$VsanHostsAndClusterPerfEntityMetrics.Values.split(",")[-1])
                                    }
                                }
                                $VsanHostsAndClusterPerfEntityRef = @{}
                                if (!$VsanHostsAndClusterPerfEntityRef[$($VsanHostsAndClusterPerfEntity.EntityRefId -split "\||:")[0]]) {
                                    $VsanHostsAndClusterPerfEntityRef.add($($VsanHostsAndClusterPerfEntity.EntityRefId -split "\||:")[0],$VsanHostsAndClusterPerfMetrics)
                                }
                                if (!$VsanPerfEntityMetric[$($VsanHostsAndClusterPerfEntity.EntityRefId -split "\||:")[1]]) {
                                    $VsanPerfEntityMetric.add($($VsanHostsAndClusterPerfEntity.EntityRefId -split "\||:")[1],$VsanHostsAndClusterPerfEntityRef )
                                } else {
                                    if (!$VsanPerfEntityMetric[$($VsanHostsAndClusterPerfEntity.EntityRefId -split "\||:")[1]][$($VsanHostsAndClusterPerfEntity.EntityRefId -split "\||:")[0]]) {
                                        $VsanPerfEntityMetric[$($VsanHostsAndClusterPerfEntity.EntityRefId -split "\||:")[1]].add($($VsanHostsAndClusterPerfEntity.EntityRefId -split "\||:")[0],$VsanHostsAndClusterPerfMetrics)
                                    }
                                }
                            }

                            if ($VsanPerfEntityMetric[$vcenter_cluster_datastore_vsan_cluster_uuid]["cluster-domclient"]) {
                                $VsanClusterPerfMaxLatency = $(@($VsanPerfEntityMetric[$vcenter_cluster_datastore_vsan_cluster_uuid]["cluster-domclient"]["latencyAvgRead"],$VsanPerfEntityMetric[$vcenter_cluster_datastore_vsan_cluster_uuid]["cluster-domclient"]["latencyAvgWrite"])|Measure-Object -Maximum).Maximum
                                $vcenter_cluster_datastores_latency += $VsanClusterPerfMaxLatency
                                $VsanClusterPerfIops = $(@($VsanPerfEntityMetric[$vcenter_cluster_datastore_vsan_cluster_uuid]["cluster-domclient"]["iopsWrite"],$VsanPerfEntityMetric[$vcenter_cluster_datastore_vsan_cluster_uuid]["cluster-domclient"]["iopsRead"])|Measure-Object -Sum).Sum
                                $vcenter_cluster_datastores_iops += $VsanClusterPerfIops 

                                $vcenter_cluster_h.add("vmw.$vcenter_name.$vcenter_cluster_dc_name.$vcenter_cluster_name.datastore.$vcenter_cluster_datastore_name.iorm.datastoreIops", $VsanClusterPerfIops)
                                $vcenter_cluster_h.add("vmw.$vcenter_name.$vcenter_cluster_dc_name.$vcenter_cluster_name.datastore.$vcenter_cluster_datastore_name.iorm.sizeNormalizedDatastoreLatency", $VsanClusterPerfMaxLatency)
                            }

                            foreach ($vcenter_vmhost_NodeUuid in $vcenter_vmhosts_moref_NodeUuid_h[$vcenter_cluster.Host.value]|?{$_}) {
                                $vcenter_vmhost_NodeUuid_Name = $($vcenter_vmhosts_NodeUuid_name_h[$vcenter_vmhost_NodeUuid])
                                # oio
                                if ($VsanPerfEntityMetric[$vcenter_vmhost_NodeUuid]["host-domclient"]["oio"] -ge 0) {$vcenter_cluster_h.add("vsan.$vcenter_name.$vcenter_cluster_dc_name.$vcenter_cluster_name.esx.$vcenter_vmhost_NodeUuid_Name.vsan.domclient.oio", $VsanPerfEntityMetric[$vcenter_vmhost_NodeUuid]["host-domclient"]["oio"])}
                                if ($VsanPerfEntityMetric[$vcenter_vmhost_NodeUuid]["host-domowner"]["oio"] -ge 0) {$vcenter_cluster_h.add("vsan.$vcenter_name.$vcenter_cluster_dc_name.$vcenter_cluster_name.esx.$vcenter_vmhost_NodeUuid_Name.vsan.domowner.oio", $VsanPerfEntityMetric[$vcenter_vmhost_NodeUuid]["host-domowner"]["oio"])}
                                if ($VsanPerfEntityMetric[$vcenter_vmhost_NodeUuid]["host-domcompmgr"]["oio"] -ge 0) {$vcenter_cluster_h.add("vsan.$vcenter_name.$vcenter_cluster_dc_name.$vcenter_cluster_name.esx.$vcenter_vmhost_NodeUuid_Name.vsan.domcompmgr.oio", $VsanPerfEntityMetric[$vcenter_vmhost_NodeUuid]["host-domcompmgr"]["oio"])}
                                # iopsRead anchorIopsRead proxyIopsRead
                                if ($VsanPerfEntityMetric[$vcenter_vmhost_NodeUuid]["host-domclient"]["iopsRead"] -ge 0) {$vcenter_cluster_h.add("vsan.$vcenter_name.$vcenter_cluster_dc_name.$vcenter_cluster_name.esx.$vcenter_vmhost_NodeUuid_Name.vsan.domclient.iopsRead", $VsanPerfEntityMetric[$vcenter_vmhost_NodeUuid]["host-domclient"]["iopsRead"])}
                                if ($VsanPerfEntityMetric[$vcenter_vmhost_NodeUuid]["host-domowner"]["iopsRead"] -ge 0) {$vcenter_cluster_h.add("vsan.$vcenter_name.$vcenter_cluster_dc_name.$vcenter_cluster_name.esx.$vcenter_vmhost_NodeUuid_Name.vsan.domowner.iopsRead", $VsanPerfEntityMetric[$vcenter_vmhost_NodeUuid]["host-domowner"]["iopsRead"])}
                                if ($VsanPerfEntityMetric[$vcenter_vmhost_NodeUuid]["host-domcompmgr"]["iopsRead"] -ge 0) {$vcenter_cluster_h.add("vsan.$vcenter_name.$vcenter_cluster_dc_name.$vcenter_cluster_name.esx.$vcenter_vmhost_NodeUuid_Name.vsan.domcompmgr.iopsRead", $VsanPerfEntityMetric[$vcenter_vmhost_NodeUuid]["host-domcompmgr"]["iopsRead"])}
                                if ($VsanPerfEntityMetric[$vcenter_vmhost_NodeUuid]["dom-proxy-owner"]["anchorIopsRead"] -gt 0) {$vcenter_cluster_h.add("vsan.$vcenter_name.$vcenter_cluster_dc_name.$vcenter_cluster_name.esx.$vcenter_vmhost_NodeUuid_Name.vsan.dom-proxy-owner.anchorIopsRead", $VsanPerfEntityMetric[$vcenter_vmhost_NodeUuid]["dom-proxy-owner"]["anchorIopsRead"])}
                                if ($VsanPerfEntityMetric[$vcenter_vmhost_NodeUuid]["dom-proxy-owner"]["proxyIopsRead"] -gt 0) {$vcenter_cluster_h.add("vsan.$vcenter_name.$vcenter_cluster_dc_name.$vcenter_cluster_name.esx.$vcenter_vmhost_NodeUuid_Name.vsan.dom-proxy-owner.proxyIopsRead", $VsanPerfEntityMetric[$vcenter_vmhost_NodeUuid]["dom-proxy-owner"]["proxyIopsRead"])}
                                # iopsWrite anchorIopsWrite proxyIopsWrite
                                if ($VsanPerfEntityMetric[$vcenter_vmhost_NodeUuid]["host-domclient"]["iopsWrite"] -ge 0) {$vcenter_cluster_h.add("vsan.$vcenter_name.$vcenter_cluster_dc_name.$vcenter_cluster_name.esx.$vcenter_vmhost_NodeUuid_Name.vsan.domclient.iopsWrite", $VsanPerfEntityMetric[$vcenter_vmhost_NodeUuid]["host-domclient"]["iopsWrite"])}
                                if ($VsanPerfEntityMetric[$vcenter_vmhost_NodeUuid]["host-domowner"]["iopsWrite"] -ge 0) {$vcenter_cluster_h.add("vsan.$vcenter_name.$vcenter_cluster_dc_name.$vcenter_cluster_name.esx.$vcenter_vmhost_NodeUuid_Name.vsan.domowner.iopsWrite", $VsanPerfEntityMetric[$vcenter_vmhost_NodeUuid]["host-domowner"]["iopsWrite"])}
                                if ($VsanPerfEntityMetric[$vcenter_vmhost_NodeUuid]["host-domcompmgr"]["iopsWrite"] -ge 0) {$vcenter_cluster_h.add("vsan.$vcenter_name.$vcenter_cluster_dc_name.$vcenter_cluster_name.esx.$vcenter_vmhost_NodeUuid_Name.vsan.domcompmgr.iopsWrite", $VsanPerfEntityMetric[$vcenter_vmhost_NodeUuid]["host-domcompmgr"]["iopsWrite"])}
                                if ($VsanPerfEntityMetric[$vcenter_vmhost_NodeUuid]["dom-proxy-owner"]["anchorIopsWrite"] -gt 0) {$vcenter_cluster_h.add("vsan.$vcenter_name.$vcenter_cluster_dc_name.$vcenter_cluster_name.esx.$vcenter_vmhost_NodeUuid_Name.vsan.dom-proxy-owner.anchorIopsWrite", $VsanPerfEntityMetric[$vcenter_vmhost_NodeUuid]["dom-proxy-owner"]["anchorIopsWrite"])}
                                if ($VsanPerfEntityMetric[$vcenter_vmhost_NodeUuid]["dom-proxy-owner"]["proxyIopsWrite"] -gt 0) {$vcenter_cluster_h.add("vsan.$vcenter_name.$vcenter_cluster_dc_name.$vcenter_cluster_name.esx.$vcenter_vmhost_NodeUuid_Name.vsan.dom-proxy-owner.proxyIopsWrite", $VsanPerfEntityMetric[$vcenter_vmhost_NodeUuid]["dom-proxy-owner"]["proxyIopsWrite"])}
                                # throughputRead anchorTputRead proxyTputRead
                                if ($VsanPerfEntityMetric[$vcenter_vmhost_NodeUuid]["host-domclient"]["throughputRead"] -ge 0) {$vcenter_cluster_h.add("vsan.$vcenter_name.$vcenter_cluster_dc_name.$vcenter_cluster_name.esx.$vcenter_vmhost_NodeUuid_Name.vsan.domclient.throughputRead", $VsanPerfEntityMetric[$vcenter_vmhost_NodeUuid]["host-domclient"]["throughputRead"])}
                                if ($VsanPerfEntityMetric[$vcenter_vmhost_NodeUuid]["host-domowner"]["tputRead"] -ge 0) {$vcenter_cluster_h.add("vsan.$vcenter_name.$vcenter_cluster_dc_name.$vcenter_cluster_name.esx.$vcenter_vmhost_NodeUuid_Name.vsan.domowner.throughputRead", $VsanPerfEntityMetric[$vcenter_vmhost_NodeUuid]["host-domowner"]["tputRead"])}
                                if ($VsanPerfEntityMetric[$vcenter_vmhost_NodeUuid]["host-domcompmgr"]["throughputRead"] -ge 0) {$vcenter_cluster_h.add("vsan.$vcenter_name.$vcenter_cluster_dc_name.$vcenter_cluster_name.esx.$vcenter_vmhost_NodeUuid_Name.vsan.domcompmgr.throughputRead", $VsanPerfEntityMetric[$vcenter_vmhost_NodeUuid]["host-domcompmgr"]["throughputRead"])}
                                if ($VsanPerfEntityMetric[$vcenter_vmhost_NodeUuid]["dom-proxy-owner"]["anchorTputRead"] -gt 0) {$vcenter_cluster_h.add("vsan.$vcenter_name.$vcenter_cluster_dc_name.$vcenter_cluster_name.esx.$vcenter_vmhost_NodeUuid_Name.vsan.dom-proxy-owner.anchorTputRead", $VsanPerfEntityMetric[$vcenter_vmhost_NodeUuid]["dom-proxy-owner"]["anchorTputRead"])}
                                if ($VsanPerfEntityMetric[$vcenter_vmhost_NodeUuid]["dom-proxy-owner"]["proxyTputRead"] -gt 0) {$vcenter_cluster_h.add("vsan.$vcenter_name.$vcenter_cluster_dc_name.$vcenter_cluster_name.esx.$vcenter_vmhost_NodeUuid_Name.vsan.dom-proxy-owner.proxyTputRead", $VsanPerfEntityMetric[$vcenter_vmhost_NodeUuid]["dom-proxy-owner"]["proxyTputRead"])}
                                # throughputWrite anchorTputWrite proxyTputWrite
                                if ($VsanPerfEntityMetric[$vcenter_vmhost_NodeUuid]["host-domclient"]["throughputWrite"] -ge 0) {$vcenter_cluster_h.add("vsan.$vcenter_name.$vcenter_cluster_dc_name.$vcenter_cluster_name.esx.$vcenter_vmhost_NodeUuid_Name.vsan.domclient.throughputWrite", $VsanPerfEntityMetric[$vcenter_vmhost_NodeUuid]["host-domclient"]["throughputWrite"])}
                                if ($VsanPerfEntityMetric[$vcenter_vmhost_NodeUuid]["host-domowner"]["tputWrite"] -ge 0) {$vcenter_cluster_h.add("vsan.$vcenter_name.$vcenter_cluster_dc_name.$vcenter_cluster_name.esx.$vcenter_vmhost_NodeUuid_Name.vsan.domowner.throughputWrite", $VsanPerfEntityMetric[$vcenter_vmhost_NodeUuid]["host-domowner"]["tputWrite"])}
                                if ($VsanPerfEntityMetric[$vcenter_vmhost_NodeUuid]["host-domcompmgr"]["throughputWrite"] -ge 0) {$vcenter_cluster_h.add("vsan.$vcenter_name.$vcenter_cluster_dc_name.$vcenter_cluster_name.esx.$vcenter_vmhost_NodeUuid_Name.vsan.domcompmgr.throughputWrite", $VsanPerfEntityMetric[$vcenter_vmhost_NodeUuid]["host-domcompmgr"]["throughputWrite"])}
                                if ($VsanPerfEntityMetric[$vcenter_vmhost_NodeUuid]["dom-proxy-owner"]["anchorTputWrite"] -gt 0) {$vcenter_cluster_h.add("vsan.$vcenter_name.$vcenter_cluster_dc_name.$vcenter_cluster_name.esx.$vcenter_vmhost_NodeUuid_Name.vsan.dom-proxy-owner.anchorTputWrite", $VsanPerfEntityMetric[$vcenter_vmhost_NodeUuid]["dom-proxy-owner"]["anchorTputWrite"])}
                                if ($VsanPerfEntityMetric[$vcenter_vmhost_NodeUuid]["dom-proxy-owner"]["proxyTputWrite"] -gt 0) {$vcenter_cluster_h.add("vsan.$vcenter_name.$vcenter_cluster_dc_name.$vcenter_cluster_name.esx.$vcenter_vmhost_NodeUuid_Name.vsan.dom-proxy-owner.proxyTputWrite", $VsanPerfEntityMetric[$vcenter_vmhost_NodeUuid]["dom-proxy-owner"]["proxyTputWrite"])}
                                # latencyAvgRead anchorLatencyAvgRead proxyLatencyAvgRead
                                if ($VsanPerfEntityMetric[$vcenter_vmhost_NodeUuid]["host-domclient"]["latencyAvgRead"] -ge 0) {$vcenter_cluster_h.add("vsan.$vcenter_name.$vcenter_cluster_dc_name.$vcenter_cluster_name.esx.$vcenter_vmhost_NodeUuid_Name.vsan.domclient.latencyAvgRead", $VsanPerfEntityMetric[$vcenter_vmhost_NodeUuid]["host-domclient"]["latencyAvgRead"])}
                                if ($VsanPerfEntityMetric[$vcenter_vmhost_NodeUuid]["host-domowner"]["latencyAvgRead"] -ge 0) {$vcenter_cluster_h.add("vsan.$vcenter_name.$vcenter_cluster_dc_name.$vcenter_cluster_name.esx.$vcenter_vmhost_NodeUuid_Name.vsan.domowner.latencyAvgRead", $VsanPerfEntityMetric[$vcenter_vmhost_NodeUuid]["host-domowner"]["latencyAvgRead"])}
                                if ($VsanPerfEntityMetric[$vcenter_vmhost_NodeUuid]["host-domcompmgr"]["latencyAvgRead"] -ge 0) {$vcenter_cluster_h.add("vsan.$vcenter_name.$vcenter_cluster_dc_name.$vcenter_cluster_name.esx.$vcenter_vmhost_NodeUuid_Name.vsan.domcompmgr.latencyAvgRead", $VsanPerfEntityMetric[$vcenter_vmhost_NodeUuid]["host-domcompmgr"]["latencyAvgRead"])}
                                if ($VsanPerfEntityMetric[$vcenter_vmhost_NodeUuid]["dom-proxy-owner"]["anchorLatencyAvgRead"] -gt 0) {$vcenter_cluster_h.add("vsan.$vcenter_name.$vcenter_cluster_dc_name.$vcenter_cluster_name.esx.$vcenter_vmhost_NodeUuid_Name.vsan.dom-proxy-owner.anchorLatencyAvgRead", $VsanPerfEntityMetric[$vcenter_vmhost_NodeUuid]["dom-proxy-owner"]["anchorLatencyAvgRead"])}
                                if ($VsanPerfEntityMetric[$vcenter_vmhost_NodeUuid]["dom-proxy-owner"]["proxyLatencyAvgRead"] -gt 0) {$vcenter_cluster_h.add("vsan.$vcenter_name.$vcenter_cluster_dc_name.$vcenter_cluster_name.esx.$vcenter_vmhost_NodeUuid_Name.vsan.dom-proxy-owner.proxyLatencyAvgRead", $VsanPerfEntityMetric[$vcenter_vmhost_NodeUuid]["dom-proxy-owner"]["proxyLatencyAvgRead"])}
                                # latencyAvgWrite anchorLatencyAvgWrite proxyLatencyAvgWrite
                                if ($VsanPerfEntityMetric[$vcenter_vmhost_NodeUuid]["host-domclient"]["latencyAvgWrite"] -ge 0) {$vcenter_cluster_h.add("vsan.$vcenter_name.$vcenter_cluster_dc_name.$vcenter_cluster_name.esx.$vcenter_vmhost_NodeUuid_Name.vsan.domclient.latencyAvgWrite", $VsanPerfEntityMetric[$vcenter_vmhost_NodeUuid]["host-domclient"]["latencyAvgWrite"])}
                                if ($VsanPerfEntityMetric[$vcenter_vmhost_NodeUuid]["host-domowner"]["latencyAvgWrite"] -ge 0) {$vcenter_cluster_h.add("vsan.$vcenter_name.$vcenter_cluster_dc_name.$vcenter_cluster_name.esx.$vcenter_vmhost_NodeUuid_Name.vsan.domowner.latencyAvgWrite", $VsanPerfEntityMetric[$vcenter_vmhost_NodeUuid]["host-domowner"]["latencyAvgWrite"])}
                                if ($VsanPerfEntityMetric[$vcenter_vmhost_NodeUuid]["host-domcompmgr"]["latencyAvgWrite"] -ge 0) {$vcenter_cluster_h.add("vsan.$vcenter_name.$vcenter_cluster_dc_name.$vcenter_cluster_name.esx.$vcenter_vmhost_NodeUuid_Name.vsan.domcompmgr.latencyAvgWrite", $VsanPerfEntityMetric[$vcenter_vmhost_NodeUuid]["host-domcompmgr"]["latencyAvgWrite"])}
                                if ($VsanPerfEntityMetric[$vcenter_vmhost_NodeUuid]["dom-proxy-owner"]["anchorLatencyAvgWrite"] -gt 0) {$vcenter_cluster_h.add("vsan.$vcenter_name.$vcenter_cluster_dc_name.$vcenter_cluster_name.esx.$vcenter_vmhost_NodeUuid_Name.vsan.dom-proxy-owner.anchorLatencyAvgWrite", $VsanPerfEntityMetric[$vcenter_vmhost_NodeUuid]["dom-proxy-owner"]["anchorLatencyAvgWrite"])}
                                if ($VsanPerfEntityMetric[$vcenter_vmhost_NodeUuid]["dom-proxy-owner"]["proxyLatencyAvgWrite"] -gt 0) {$vcenter_cluster_h.add("vsan.$vcenter_name.$vcenter_cluster_dc_name.$vcenter_cluster_name.esx.$vcenter_vmhost_NodeUuid_Name.vsan.dom-proxy-owner.proxyLatencyAvgWrite", $VsanPerfEntityMetric[$vcenter_vmhost_NodeUuid]["dom-proxy-owner"]["proxyLatencyAvgWrite"])}
                                # readCongestion anchorReadCongestion proxyReadCongestion
                                if ($VsanPerfEntityMetric[$vcenter_vmhost_NodeUuid]["host-domclient"]["readCongestion"] -ge 0) {$vcenter_cluster_h.add("vsan.$vcenter_name.$vcenter_cluster_dc_name.$vcenter_cluster_name.esx.$vcenter_vmhost_NodeUuid_Name.vsan.domclient.readCongestion", $VsanPerfEntityMetric[$vcenter_vmhost_NodeUuid]["host-domclient"]["readCongestion"])}
                                if ($VsanPerfEntityMetric[$vcenter_vmhost_NodeUuid]["host-domowner"]["readCongestion"] -ge 0) {$vcenter_cluster_h.add("vsan.$vcenter_name.$vcenter_cluster_dc_name.$vcenter_cluster_name.esx.$vcenter_vmhost_NodeUuid_Name.vsan.domowner.readCongestion", $VsanPerfEntityMetric[$vcenter_vmhost_NodeUuid]["host-domowner"]["readCongestion"])}
                                if ($VsanPerfEntityMetric[$vcenter_vmhost_NodeUuid]["host-domcompmgr"]["readCongestion"] -ge 0) {$vcenter_cluster_h.add("vsan.$vcenter_name.$vcenter_cluster_dc_name.$vcenter_cluster_name.esx.$vcenter_vmhost_NodeUuid_Name.vsan.domcompmgr.readCongestion", $VsanPerfEntityMetric[$vcenter_vmhost_NodeUuid]["host-domcompmgr"]["readCongestion"])}
                                if ($VsanPerfEntityMetric[$vcenter_vmhost_NodeUuid]["dom-proxy-owner"]["anchorReadCongestion"] -gt 0) {$vcenter_cluster_h.add("vsan.$vcenter_name.$vcenter_cluster_dc_name.$vcenter_cluster_name.esx.$vcenter_vmhost_NodeUuid_Name.vsan.dom-proxy-owner.anchorReadCongestion", $VsanPerfEntityMetric[$vcenter_vmhost_NodeUuid]["dom-proxy-owner"]["anchorReadCongestion"])}
                                if ($VsanPerfEntityMetric[$vcenter_vmhost_NodeUuid]["dom-proxy-owner"]["proxyReadCongestion"] -gt 0) {$vcenter_cluster_h.add("vsan.$vcenter_name.$vcenter_cluster_dc_name.$vcenter_cluster_name.esx.$vcenter_vmhost_NodeUuid_Name.vsan.dom-proxy-owner.proxyReadCongestion", $VsanPerfEntityMetric[$vcenter_vmhost_NodeUuid]["dom-proxy-owner"]["proxyReadCongestion"])}
                                # writeCongestion anchorWriteCongestion proxyWriteCongestion
                                if ($VsanPerfEntityMetric[$vcenter_vmhost_NodeUuid]["host-domclient"]["writeCongestion"] -ge 0) {$vcenter_cluster_h.add("vsan.$vcenter_name.$vcenter_cluster_dc_name.$vcenter_cluster_name.esx.$vcenter_vmhost_NodeUuid_Name.vsan.domclient.writeCongestion", $VsanPerfEntityMetric[$vcenter_vmhost_NodeUuid]["host-domclient"]["writeCongestion"])}
                                if ($VsanPerfEntityMetric[$vcenter_vmhost_NodeUuid]["host-domowner"]["writeCongestion"] -ge 0) {$vcenter_cluster_h.add("vsan.$vcenter_name.$vcenter_cluster_dc_name.$vcenter_cluster_name.esx.$vcenter_vmhost_NodeUuid_Name.vsan.domowner.writeCongestion", $VsanPerfEntityMetric[$vcenter_vmhost_NodeUuid]["host-domowner"]["writeCongestion"])}
                                if ($VsanPerfEntityMetric[$vcenter_vmhost_NodeUuid]["host-domcompmgr"]["writeCongestion"] -ge 0) {$vcenter_cluster_h.add("vsan.$vcenter_name.$vcenter_cluster_dc_name.$vcenter_cluster_name.esx.$vcenter_vmhost_NodeUuid_Name.vsan.domcompmgr.writeCongestion", $VsanPerfEntityMetric[$vcenter_vmhost_NodeUuid]["host-domcompmgr"]["writeCongestion"])}
                                if ($VsanPerfEntityMetric[$vcenter_vmhost_NodeUuid]["dom-proxy-owner"]["anchorWriteCongestion"] -gt 0) {$vcenter_cluster_h.add("vsan.$vcenter_name.$vcenter_cluster_dc_name.$vcenter_cluster_name.esx.$vcenter_vmhost_NodeUuid_Name.vsan.dom-proxy-owner.anchorWriteCongestion", $VsanPerfEntityMetric[$vcenter_vmhost_NodeUuid]["dom-proxy-owner"]["anchorWriteCongestion"])}
                                if ($VsanPerfEntityMetric[$vcenter_vmhost_NodeUuid]["dom-proxy-owner"]["proxyWriteCongestion"] -gt 0) {$vcenter_cluster_h.add("vsan.$vcenter_name.$vcenter_cluster_dc_name.$vcenter_cluster_name.esx.$vcenter_vmhost_NodeUuid_Name.vsan.dom-proxy-owner.proxyWriteCongestion", $VsanPerfEntityMetric[$vcenter_vmhost_NodeUuid]["dom-proxy-owner"]["proxyWriteCongestion"])}
                                # latencyAvgRecWrite anchorLatencyAvgRWResync proxyLatencyAvgRWResync
                                if ($VsanPerfEntityMetric[$vcenter_vmhost_NodeUuid]["host-domowner"]["latencyAvgRecWrite"] -ge 0) {$vcenter_cluster_h.add("vsan.$vcenter_name.$vcenter_cluster_dc_name.$vcenter_cluster_name.esx.$vcenter_vmhost_NodeUuid_Name.vsan.domowner.latencyAvgRecWrite", $VsanPerfEntityMetric[$vcenter_vmhost_NodeUuid]["host-domowner"]["latencyAvgRecWrite"])}
                                if ($VsanPerfEntityMetric[$vcenter_vmhost_NodeUuid]["host-domcompmgr"]["latencyAvgRecWrite"] -ge 0) {$vcenter_cluster_h.add("vsan.$vcenter_name.$vcenter_cluster_dc_name.$vcenter_cluster_name.esx.$vcenter_vmhost_NodeUuid_Name.vsan.domcompmgr.latencyAvgRecWrite", $VsanPerfEntityMetric[$vcenter_vmhost_NodeUuid]["host-domcompmgr"]["latencyAvgRecWrite"])}
                                if ($VsanPerfEntityMetric[$vcenter_vmhost_NodeUuid]["dom-proxy-owner"]["anchorLatencyAvgRWResync"] -gt 0) {$vcenter_cluster_h.add("vsan.$vcenter_name.$vcenter_cluster_dc_name.$vcenter_cluster_name.esx.$vcenter_vmhost_NodeUuid_Name.vsan.dom-proxy-owner.anchorLatencyAvgRWResync", $VsanPerfEntityMetric[$vcenter_vmhost_NodeUuid]["dom-proxy-owner"]["anchorLatencyAvgRWResync"])}
                                if ($VsanPerfEntityMetric[$vcenter_vmhost_NodeUuid]["dom-proxy-owner"]["proxyLatencyAvgRWResync"] -gt 0) {$vcenter_cluster_h.add("vsan.$vcenter_name.$vcenter_cluster_dc_name.$vcenter_cluster_name.esx.$vcenter_vmhost_NodeUuid_Name.vsan.dom-proxy-owner.proxyLatencyAvgRWResync", $VsanPerfEntityMetric[$vcenter_vmhost_NodeUuid]["dom-proxy-owner"]["proxyLatencyAvgRWResync"])}
                                # iopsResyncRead anchorIopsRWResync proxyIopsRWResync
                                if ($VsanPerfEntityMetric[$vcenter_vmhost_NodeUuid]["host-domowner"]["iopsResyncRead"] -ge 0) {$vcenter_cluster_h.add("vsan.$vcenter_name.$vcenter_cluster_dc_name.$vcenter_cluster_name.esx.$vcenter_vmhost_NodeUuid_Name.vsan.domowner.iopsResyncRead", $VsanPerfEntityMetric[$vcenter_vmhost_NodeUuid]["host-domowner"]["iopsResyncRead"])}
                                if ($VsanPerfEntityMetric[$vcenter_vmhost_NodeUuid]["host-domcompmgr"]["iopsResyncRead"] -ge 0) {$vcenter_cluster_h.add("vsan.$vcenter_name.$vcenter_cluster_dc_name.$vcenter_cluster_name.esx.$vcenter_vmhost_NodeUuid_Name.vsan.domcompmgr.iopsResyncRead", $VsanPerfEntityMetric[$vcenter_vmhost_NodeUuid]["host-domcompmgr"]["iopsResyncRead"])}
                                if ($VsanPerfEntityMetric[$vcenter_vmhost_NodeUuid]["dom-proxy-owner"]["anchorIopsRWResync"] -gt 0) {$vcenter_cluster_h.add("vsan.$vcenter_name.$vcenter_cluster_dc_name.$vcenter_cluster_name.esx.$vcenter_vmhost_NodeUuid_Name.vsan.dom-proxy-owner.anchorIopsRWResync", $VsanPerfEntityMetric[$vcenter_vmhost_NodeUuid]["dom-proxy-owner"]["anchorIopsRWResync"])}
                                if ($VsanPerfEntityMetric[$vcenter_vmhost_NodeUuid]["dom-proxy-owner"]["proxyIopsRWResync"] -gt 0) {$vcenter_cluster_h.add("vsan.$vcenter_name.$vcenter_cluster_dc_name.$vcenter_cluster_name.esx.$vcenter_vmhost_NodeUuid_Name.vsan.dom-proxy-owner.proxyIopsRWResync", $VsanPerfEntityMetric[$vcenter_vmhost_NodeUuid]["dom-proxy-owner"]["proxyIopsRWResync"])}
                                # iopsRecWrite 
                                if ($VsanPerfEntityMetric[$vcenter_vmhost_NodeUuid]["host-domowner"]["iopsRecWrite"] -ge 0) {$vcenter_cluster_h.add("vsan.$vcenter_name.$vcenter_cluster_dc_name.$vcenter_cluster_name.esx.$vcenter_vmhost_NodeUuid_Name.vsan.domowner.iopsRecWrite", $VsanPerfEntityMetric[$vcenter_vmhost_NodeUuid]["host-domowner"]["iopsRecWrite"])}
                                if ($VsanPerfEntityMetric[$vcenter_vmhost_NodeUuid]["host-domcompmgr"]["iopsRecWrite"] -ge 0) {$vcenter_cluster_h.add("vsan.$vcenter_name.$vcenter_cluster_dc_name.$vcenter_cluster_name.esx.$vcenter_vmhost_NodeUuid_Name.vsan.domcompmgr.iopsRecWrite", $VsanPerfEntityMetric[$vcenter_vmhost_NodeUuid]["host-domcompmgr"]["iopsRecWrite"])}
                                # tputResyncRead anchorTputRWResync proxyTputRWResync
                                if ($VsanPerfEntityMetric[$vcenter_vmhost_NodeUuid]["host-domowner"]["tputResyncRead"] -ge 0) {$vcenter_cluster_h.add("vsan.$vcenter_name.$vcenter_cluster_dc_name.$vcenter_cluster_name.esx.$vcenter_vmhost_NodeUuid_Name.vsan.domowner.tputResyncRead", $VsanPerfEntityMetric[$vcenter_vmhost_NodeUuid]["host-domowner"]["tputResyncRead"])}
                                if ($VsanPerfEntityMetric[$vcenter_vmhost_NodeUuid]["host-domcompmgr"]["tputResyncRead"] -ge 0) {$vcenter_cluster_h.add("vsan.$vcenter_name.$vcenter_cluster_dc_name.$vcenter_cluster_name.esx.$vcenter_vmhost_NodeUuid_Name.vsan.domcompmgr.tputResyncRead", $VsanPerfEntityMetric[$vcenter_vmhost_NodeUuid]["host-domcompmgr"]["tputResyncRead"])}
                                if ($VsanPerfEntityMetric[$vcenter_vmhost_NodeUuid]["dom-proxy-owner"]["anchorIopsRWResync"] -gt 0) {$vcenter_cluster_h.add("vsan.$vcenter_name.$vcenter_cluster_dc_name.$vcenter_cluster_name.esx.$vcenter_vmhost_NodeUuid_Name.vsan.dom-proxy-owner.anchorTputRWResync", $VsanPerfEntityMetric[$vcenter_vmhost_NodeUuid]["dom-proxy-owner"]["anchorTputRWResync"])}
                                if ($VsanPerfEntityMetric[$vcenter_vmhost_NodeUuid]["dom-proxy-owner"]["proxyTputRWResync"] -gt 0) {$vcenter_cluster_h.add("vsan.$vcenter_name.$vcenter_cluster_dc_name.$vcenter_cluster_name.esx.$vcenter_vmhost_NodeUuid_Name.vsan.dom-proxy-owner.proxyTputRWResync", $VsanPerfEntityMetric[$vcenter_vmhost_NodeUuid]["dom-proxy-owner"]["proxyTputRWResync"])}
                                # resyncReadCongestion recWriteCongestion latAvgResyncRead throughputRecWrite clientCacheHitRate anchorRWResyncCongestion proxyRWResyncCongestion
                                if ($VsanPerfEntityMetric[$vcenter_vmhost_NodeUuid]["host-domcompmgr"]["resyncReadCongestion"] -ge 0) {$vcenter_cluster_h.add("vsan.$vcenter_name.$vcenter_cluster_dc_name.$vcenter_cluster_name.esx.$vcenter_vmhost_NodeUuid_Name.vsan.domcompmgr.resyncReadCongestion", $VsanPerfEntityMetric[$vcenter_vmhost_NodeUuid]["host-domcompmgr"]["resyncReadCongestion"])}
                                if ($VsanPerfEntityMetric[$vcenter_vmhost_NodeUuid]["host-domcompmgr"]["recWriteCongestion"] -ge 0) {$vcenter_cluster_h.add("vsan.$vcenter_name.$vcenter_cluster_dc_name.$vcenter_cluster_name.esx.$vcenter_vmhost_NodeUuid_Name.vsan.domcompmgr.recWriteCongestion", $VsanPerfEntityMetric[$vcenter_vmhost_NodeUuid]["host-domcompmgr"]["recWriteCongestion"])}
                                if ($VsanPerfEntityMetric[$vcenter_vmhost_NodeUuid]["host-domcompmgr"]["latAvgResyncRead"] -ge 0) {$vcenter_cluster_h.add("vsan.$vcenter_name.$vcenter_cluster_dc_name.$vcenter_cluster_name.esx.$vcenter_vmhost_NodeUuid_Name.vsan.domcompmgr.latAvgResyncRead", $VsanPerfEntityMetric[$vcenter_vmhost_NodeUuid]["host-domcompmgr"]["latAvgResyncRead"])}
                                if ($VsanPerfEntityMetric[$vcenter_vmhost_NodeUuid]["host-domowner"]["latencyAvgResyncRead"] -ge 0) {$vcenter_cluster_h.add("vsan.$vcenter_name.$vcenter_cluster_dc_name.$vcenter_cluster_name.esx.$vcenter_vmhost_NodeUuid_Name.vsan.host-domowner.latAvgResyncRead", $VsanPerfEntityMetric[$vcenter_vmhost_NodeUuid]["host-domowner"]["latencyAvgResyncRead"])}
                                if ($VsanPerfEntityMetric[$vcenter_vmhost_NodeUuid]["host-domcompmgr"]["throughputRecWrite"] -ge 0) {$vcenter_cluster_h.add("vsan.$vcenter_name.$vcenter_cluster_dc_name.$vcenter_cluster_name.esx.$vcenter_vmhost_NodeUuid_Name.vsan.domcompmgr.throughputRecWrite", $VsanPerfEntityMetric[$vcenter_vmhost_NodeUuid]["host-domcompmgr"]["throughputRecWrite"])}
                                if ($VsanPerfEntityMetric[$vcenter_vmhost_NodeUuid]["host-domowner"]["tputRecWrite"] -ge 0) {$vcenter_cluster_h.add("vsan.$vcenter_name.$vcenter_cluster_dc_name.$vcenter_cluster_name.esx.$vcenter_vmhost_NodeUuid_Name.vsan.host-domowner.throughputRecWrite", $VsanPerfEntityMetric[$vcenter_vmhost_NodeUuid]["host-domcompmgr"]["tputRecWrite"])}
                                if ($VsanPerfEntityMetric[$vcenter_vmhost_NodeUuid]["host-domclient"]["clientCacheHitRate"] -ge 0) {$vcenter_cluster_h.add("vsan.$vcenter_name.$vcenter_cluster_dc_name.$vcenter_cluster_name.esx.$vcenter_vmhost_NodeUuid_Name.vsan.domclient.clientCacheHitRate", $VsanPerfEntityMetric[$vcenter_vmhost_NodeUuid]["host-domclient"]["clientCacheHitRate"])}
                                if ($VsanPerfEntityMetric[$vcenter_vmhost_NodeUuid]["dom-proxy-owner"]["anchorRWResyncCongestion"] -gt 0) {$vcenter_cluster_h.add("vsan.$vcenter_name.$vcenter_cluster_dc_name.$vcenter_cluster_name.esx.$vcenter_vmhost_NodeUuid_Name.vsan.dom-proxy-owner.anchorRWResyncCongestion", $VsanPerfEntityMetric[$vcenter_vmhost_NodeUuid]["dom-proxy-owner"]["anchorRWResyncCongestion"])}
                                if ($VsanPerfEntityMetric[$vcenter_vmhost_NodeUuid]["dom-proxy-owner"]["proxyRWResyncCongestion"] -gt 0) {$vcenter_cluster_h.add("vsan.$vcenter_name.$vcenter_cluster_dc_name.$vcenter_cluster_name.esx.$vcenter_vmhost_NodeUuid_Name.vsan.dom-proxy-owner.proxyRWResyncCongestion", $VsanPerfEntityMetric[$vcenter_vmhost_NodeUuid]["dom-proxy-owner"]["proxyRWResyncCongestion"])}
                                # vsan-host-net
                                if ($VsanPerfEntityMetric[$vcenter_vmhost_NodeUuid]["vsan-host-net"]["txPackets"] -ge 0) {$vcenter_cluster_h.add("vsan.$vcenter_name.$vcenter_cluster_dc_name.$vcenter_cluster_name.esx.$vcenter_vmhost_NodeUuid_Name.vsan.net.txPackets", $VsanPerfEntityMetric[$vcenter_vmhost_NodeUuid]["vsan-host-net"]["txPackets"])}
                                if ($VsanPerfEntityMetric[$vcenter_vmhost_NodeUuid]["vsan-host-net"]["rxPackets"] -ge 0) {$vcenter_cluster_h.add("vsan.$vcenter_name.$vcenter_cluster_dc_name.$vcenter_cluster_name.esx.$vcenter_vmhost_NodeUuid_Name.vsan.net.rxPackets", $VsanPerfEntityMetric[$vcenter_vmhost_NodeUuid]["vsan-host-net"]["rxPackets"])}
                                if ($VsanPerfEntityMetric[$vcenter_vmhost_NodeUuid]["vsan-host-net"]["txThroughput"] -ge 0) {$vcenter_cluster_h.add("vsan.$vcenter_name.$vcenter_cluster_dc_name.$vcenter_cluster_name.esx.$vcenter_vmhost_NodeUuid_Name.vsan.net.txThroughput", $VsanPerfEntityMetric[$vcenter_vmhost_NodeUuid]["vsan-host-net"]["txThroughput"])}
                                if ($VsanPerfEntityMetric[$vcenter_vmhost_NodeUuid]["vsan-host-net"]["rxThroughput"] -ge 0) {$vcenter_cluster_h.add("vsan.$vcenter_name.$vcenter_cluster_dc_name.$vcenter_cluster_name.esx.$vcenter_vmhost_NodeUuid_Name.vsan.net.rxThroughput", $VsanPerfEntityMetric[$vcenter_vmhost_NodeUuid]["vsan-host-net"]["rxThroughput"])}
                                if ($VsanPerfEntityMetric[$vcenter_vmhost_NodeUuid]["vsan-host-net"]["tcpRxErrRate"] -ge 0) {$vcenter_cluster_h.add("vsan.$vcenter_name.$vcenter_cluster_dc_name.$vcenter_cluster_name.esx.$vcenter_vmhost_NodeUuid_Name.vsan.net.tcpRxErrRate", $VsanPerfEntityMetric[$vcenter_vmhost_NodeUuid]["vsan-host-net"]["tcpRxErrRate"])}
                                if ($VsanPerfEntityMetric[$vcenter_vmhost_NodeUuid]["vsan-host-net"]["rxPacketsLossRate"] -ge 0) {$vcenter_cluster_h.add("vsan.$vcenter_name.$vcenter_cluster_dc_name.$vcenter_cluster_name.esx.$vcenter_vmhost_NodeUuid_Name.vsan.net.rxPacketsLossRate", $VsanPerfEntityMetric[$vcenter_vmhost_NodeUuid]["vsan-host-net"]["rxPacketsLossRate"])}
                                if ($VsanPerfEntityMetric[$vcenter_vmhost_NodeUuid]["vsan-host-net"]["tcpTxRexmitRate"] -ge 0) {$vcenter_cluster_h.add("vsan.$vcenter_name.$vcenter_cluster_dc_name.$vcenter_cluster_name.esx.$vcenter_vmhost_NodeUuid_Name.vsan.net.tcpTxRexmitRate", $VsanPerfEntityMetric[$vcenter_vmhost_NodeUuid]["vsan-host-net"]["tcpTxRexmitRate"])}
                                if ($VsanPerfEntityMetric[$vcenter_vmhost_NodeUuid]["vsan-host-net"]["txPacketsLossRate"] -ge 0) {$vcenter_cluster_h.add("vsan.$vcenter_name.$vcenter_cluster_dc_name.$vcenter_cluster_name.esx.$vcenter_vmhost_NodeUuid_Name.vsan.net.txPacketsLossRate", $VsanPerfEntityMetric[$vcenter_vmhost_NodeUuid]["vsan-host-net"]["txPacketsLossRate"])}
                                if ($VsanPerfEntityMetric[$vcenter_vmhost_NodeUuid]["vsan-host-net"]["portTxpkts"] -gt 0) {$vcenter_cluster_h.add("vsan.$vcenter_name.$vcenter_cluster_dc_name.$vcenter_cluster_name.esx.$vcenter_vmhost_NodeUuid_Name.vsan.net.portTxDropsRate", $($VsanPerfEntityMetric[$vcenter_vmhost_NodeUuid]["vsan-host-net"]["portTxDrops"] * 100 / $VsanPerfEntityMetric[$vcenter_vmhost_NodeUuid]["vsan-host-net"]["portTxpkts"]))}
                                if ($VsanPerfEntityMetric[$vcenter_vmhost_NodeUuid]["vsan-host-net"]["portRxpkts"] -gt 0) {$vcenter_cluster_h.add("vsan.$vcenter_name.$vcenter_cluster_dc_name.$vcenter_cluster_name.esx.$vcenter_vmhost_NodeUuid_Name.vsan.net.portRxDropsRate", $($VsanPerfEntityMetric[$vcenter_vmhost_NodeUuid]["vsan-host-net"]["portRxDrops"] * 100 / $VsanPerfEntityMetric[$vcenter_vmhost_NodeUuid]["vsan-host-net"]["portRxpkts"]))}
                            }

                            if ($vcenter_clusters_vsan_efa_h[$vcenter_cluster_moref]) { # EFA vSan cluster
                                foreach ($PhysicalDisksHealthVsanUuid in $PhysicalDisksHealthVsanUuidHosts.keys) {
                                    $PhysicalDisksHealthVsanUuidName = NameCleaner $PhysicalDisksHealthVsanUuidObj[$PhysicalDisksHealthVsanUuid].Name
                                    if ($vcenter_vmhosts_short_h[$PhysicalDisksHealthVsanUuidHosts[$PhysicalDisksHealthVsanUuid]]) {
                                        $PhysicalDisksHealthVsanUuidHost = $vcenter_vmhosts_short_h[$PhysicalDisksHealthVsanUuidHosts[$PhysicalDisksHealthVsanUuid]]
                                        $vcenter_cluster_h.add("vsan.$vcenter_name.$vcenter_cluster_dc_name.$vcenter_cluster_name.esx.$PhysicalDisksHealthVsanUuidHost.vsan.disk.capacity.$PhysicalDisksHealthVsanUuidName.percentUsed", $([INT64]$PhysicalDisksHealthVsanUuidObj[$PhysicalDisksHealthVsanUuid].UsedCapacity * 100 / [INT64]$PhysicalDisksHealthVsanUuidObj[$PhysicalDisksHealthVsanUuid].Capacity))
                                        $vcenter_cluster_h.add("vsan.$vcenter_name.$vcenter_cluster_dc_name.$vcenter_cluster_name.esx.$PhysicalDisksHealthVsanUuidHost.vsan.disk.capacity.$PhysicalDisksHealthVsanUuidName.latencyDevRead", $VsanPerfEntityMetric[$PhysicalDisksHealthVsanUuid]["vsan-esa-disk-scsifw"]["latencyDevRead"])
                                        $vcenter_cluster_h.add("vsan.$vcenter_name.$vcenter_cluster_dc_name.$vcenter_cluster_name.esx.$PhysicalDisksHealthVsanUuidHost.vsan.disk.capacity.$PhysicalDisksHealthVsanUuidName.latencyDevWrite", $VsanPerfEntityMetric[$PhysicalDisksHealthVsanUuid]["vsan-esa-disk-scsifw"]["latencyDevWrite"])
                                    }

                                }
                            } else { # Non EFA vSAN cluster

                                foreach ($vcenter_cluster_vsan_Ssd_uuid in $vcenter_clusters_vsan_Ssd_uuid_naa_h[$vcenter_cluster_moref].keys) {
                                    if ($vcenter_vmhosts_short_h[$vcenter_vmhosts_h[$vcenter_vmhosts_vsan_disk_moref_h[$vcenter_cluster_vsan_Ssd_uuid]].name]) {
                                        $vcenter_cluster_vsan_Ssd_host = $vcenter_vmhosts_short_h[$vcenter_vmhosts_h[$vcenter_vmhosts_vsan_disk_moref_h[$vcenter_cluster_vsan_Ssd_uuid]].name]
                                        $vcenter_cluster_vsan_Ssd_name = $vcenter_clusters_vsan_Ssd_uuid_naa_h[$vcenter_cluster_moref][$vcenter_cluster_vsan_Ssd_uuid]
                                        $vcenter_cluster_h.add("vsan.$vcenter_name.$vcenter_cluster_dc_name.$vcenter_cluster_name.esx.$vcenter_cluster_vsan_Ssd_host.vsan.disk.cache.$vcenter_cluster_vsan_Ssd_name.latencyDevRead", $VsanPerfEntityMetric[$vcenter_cluster_vsan_Ssd_uuid]["cache-disk"]["latencyDevRead"])
                                        $vcenter_cluster_h.add("vsan.$vcenter_name.$vcenter_cluster_dc_name.$vcenter_cluster_name.esx.$vcenter_cluster_vsan_Ssd_host.vsan.disk.cache.$vcenter_cluster_vsan_Ssd_name.latencyDevWrite", $VsanPerfEntityMetric[$vcenter_cluster_vsan_Ssd_uuid]["cache-disk"]["latencyDevWrite"])
                                        $vcenter_cluster_h.add("vsan.$vcenter_name.$vcenter_cluster_dc_name.$vcenter_cluster_name.esx.$vcenter_cluster_vsan_Ssd_host.vsan.domcompmgr.cache.$vcenter_cluster_vsan_Ssd_name.wbFreePct", $VsanPerfEntityMetric[$vcenter_cluster_vsan_Ssd_uuid]["cache-disk"]["wbFreePct"])
                                    }
                                }
    
                                foreach ($vcenter_cluster_vsan_nonSsd_uuid in $vcenter_clusters_vsan_nonSsd_uuid_naa_h[$vcenter_cluster_moref].keys) {
                                    if ($vcenter_clusters_vsan_nonSsd_uuid_naa_h[$vcenter_cluster_moref][$vcenter_cluster_vsan_nonSsd_uuid]) {
                                        $vcenter_cluster_vsan_nonSsd_host = $vcenter_vmhosts_short_h[$vcenter_vmhosts_h[$vcenter_vmhosts_vsan_disk_moref_h[$vcenter_cluster_vsan_nonSsd_uuid]].name]
                                        $vcenter_cluster_vsan_nonSsd_name = $vcenter_clusters_vsan_nonSsd_uuid_naa_h[$vcenter_cluster_moref][$vcenter_cluster_vsan_nonSsd_uuid]
                                        $vcenter_cluster_h.add("vsan.$vcenter_name.$vcenter_cluster_dc_name.$vcenter_cluster_name.esx.$vcenter_cluster_vsan_nonSsd_host.vsan.disk.capacity.$vcenter_cluster_vsan_nonSsd_name.latencyDevRead", $VsanPerfEntityMetric[$vcenter_cluster_vsan_nonSsd_uuid]["capacity-disk"]["latencyDevRead"])
                                        $vcenter_cluster_h.add("vsan.$vcenter_name.$vcenter_cluster_dc_name.$vcenter_cluster_name.esx.$vcenter_cluster_vsan_nonSsd_host.vsan.disk.capacity.$vcenter_cluster_vsan_nonSsd_name.latencyDevWrite", $VsanPerfEntityMetric[$vcenter_cluster_vsan_nonSsd_uuid]["capacity-disk"]["latencyDevWrite"])
                                        # $vcenter_cluster_h.add("vsan.$vcenter_name.$vcenter_cluster_dc_name.$vcenter_cluster_name.esx.$vcenter_cluster_vsan_nonSsd_host.vsan.disk.capacity.$vcenter_cluster_vsan_nonSsd_name.capacityUsed", $VsanPerfEntityMetric[$vcenter_cluster_vsan_nonSsd_uuid]["capacity-disk"]["capacityUsed"])
                                        $vcenter_cluster_h.add("vsan.$vcenter_name.$vcenter_cluster_dc_name.$vcenter_cluster_name.esx.$vcenter_cluster_vsan_nonSsd_host.vsan.disk.capacity.$vcenter_cluster_vsan_nonSsd_name.percentUsed", $([INT64]$VsanPerfEntityMetric[$vcenter_cluster_vsan_nonSsd_uuid]["capacity-disk"]["capacityUsed"] * 100 / [INT64]$vcenter_vmhosts_vsan_disk_capa_h[$vcenter_cluster_vsan_nonSsd_uuid]))
                                    }
                                }
                            }

                        } else {
                            Write-Host "$((Get-Date).ToString("o")) [WARN] Empty VsanPerfQuery in cluster $vcenter_cluster_name"
                        }

                        try {
                            Write-Host "$((Get-Date).ToString("o")) [INFO] Start processing SmartStatsSummary in cluster $vcenter_cluster_name (v6.7+) ..."
                            # https://www.virtuallyghetto.com/2017/04/getting-started-wthe-new-powercli-6-5-1-get-vsanview-cmdlet.html
                            # https://github.com/lamw/vghetto-scripts/blob/master/powershell/VSANSmartsData.ps1
                            $VcClusterSmartStatsSummary = $VsanClusterHealthSystem.VsanQueryVcClusterSmartStatsSummary($vcenter_cluster.moref)
                            if ($VcClusterSmartStatsSummary.SmartStats) {
                                foreach ($SmartStatsEsx in $VcClusterSmartStatsSummary) {
                                    $SmartStatsEsxName = $vcenter_vmhosts_short_h[$SmartStatsEsx.Hostname]
                                    foreach ($SmartStatsEsxDisk in $SmartStatsEsx.SmartStats) {
                                        $SmartStatsEsxDiskName = NameCleaner $SmartStatsEsxDisk.Disk
                                        foreach ($SmartStatsEsxDiskStats in $SmartStatsEsxDisk.Stats|?{$_.Value -ne $null}) {
                                            if ($SmartStatsEsxDiskStats.Parameter -and !$vcenter_cluster_h["vsan.$vcenter_name.$vcenter_cluster_dc_name.$vcenter_cluster_name.esx.$SmartStatsEsxName.vsan.disk.smart.$SmartStatsEsxDiskName.$($SmartStatsEsxDiskStats.Parameter)"]) {
                                                $vcenter_cluster_h.add("vsan.$vcenter_name.$vcenter_cluster_dc_name.$vcenter_cluster_name.esx.$SmartStatsEsxName.vsan.disk.smart.$SmartStatsEsxDiskName.$($SmartStatsEsxDiskStats.Parameter)", $($SmartStatsEsxDiskStats.Value))
                                            }
                                        }
                                    }
                                }
                            }
                        } catch {
                            Write-Host "$((Get-Date).ToString("o")) [WARN] Unable to retreive VcClusterSmartStatsSummary in cluster $vcenter_cluster_name"
                            Write-Host "$((Get-Date).ToString("o")) [WARN] $($Error[0])"
                        }

                        try {
                            Write-Host "$((Get-Date).ToString("o")) [INFO] Processing spaceUsageByObjectType in vSAN cluster $vcenter_cluster_name (v6.2+) ..."
    
                            $ClusterVsanSpaceUsageReport = $VsanSpaceReportSystem.VsanQuerySpaceUsage($vcenter_cluster.Moref)
                            $ClusterVsanSpaceUsageReportObjList = $ClusterVsanSpaceUsageReport.spaceDetail.spaceUsageByObjectType
                            $vcenter_cluster_h.add("vsan.$vcenter_name.$vcenter_cluster_dc_name.$vcenter_cluster_name.vsan.spaceDetail.TotalCapacityB", $ClusterVsanSpaceUsageReport.TotalCapacityB)
                            $vcenter_cluster_h.add("vsan.$vcenter_name.$vcenter_cluster_dc_name.$vcenter_cluster_name.vsan.spaceDetail.FreeCapacityB", $ClusterVsanSpaceUsageReport.FreeCapacityB)
                            foreach ($vsanObjType in $ClusterVsanSpaceUsageReportObjList) {
                                $ClusterVsanSpaceUsageReportObjType = $vsanObjType.objType
                                $vcenter_cluster_h.add("vsan.$vcenter_name.$vcenter_cluster_dc_name.$vcenter_cluster_name.vsan.spaceDetail.spaceUsageByObjectType.$ClusterVsanSpaceUsageReportObjType.overheadB", $vsanObjType.overheadB)
                                $vcenter_cluster_h.add("vsan.$vcenter_name.$vcenter_cluster_dc_name.$vcenter_cluster_name.vsan.spaceDetail.spaceUsageByObjectType.$ClusterVsanSpaceUsageReportObjType.physicalUsedB", $vsanObjType.physicalUsedB)
                                $vcenter_cluster_h.add("vsan.$vcenter_name.$vcenter_cluster_dc_name.$vcenter_cluster_name.vsan.spaceDetail.spaceUsageByObjectType.$ClusterVsanSpaceUsageReportObjType.overReservedB", $vsanObjType.overReservedB)
                                $vcenter_cluster_h.add("vsan.$vcenter_name.$vcenter_cluster_dc_name.$vcenter_cluster_name.vsan.spaceDetail.spaceUsageByObjectType.$ClusterVsanSpaceUsageReportObjType.usedB", $vsanObjType.usedB)
                                $vcenter_cluster_h.add("vsan.$vcenter_name.$vcenter_cluster_dc_name.$vcenter_cluster_name.vsan.spaceDetail.spaceUsageByObjectType.$ClusterVsanSpaceUsageReportObjType.temporaryOverheadB", $vsanObjType.temporaryOverheadB)
                                $vcenter_cluster_h.add("vsan.$vcenter_name.$vcenter_cluster_dc_name.$vcenter_cluster_name.vsan.spaceDetail.spaceUsageByObjectType.$ClusterVsanSpaceUsageReportObjType.primaryCapacityB", $vsanObjType.primaryCapacityB)
                                $vcenter_cluster_h.add("vsan.$vcenter_name.$vcenter_cluster_dc_name.$vcenter_cluster_name.vsan.spaceDetail.spaceUsageByObjectType.$ClusterVsanSpaceUsageReportObjType.reservedCapacityB", $vsanObjType.reservedCapacityB)
                            }
                            # if ($ClusterVsanSpaceUsageReport.EfficientCapacity) {
                            #     $vcenter_cluster_h.add("vsan.$vcenter_name.$vcenter_cluster_dc_name.$vcenter_cluster_name.vsan.EfficientCapacity.LogicalCapacity", $ClusterVsanSpaceUsageReport.EfficientCapacity.LogicalCapacity)
                            #     $vcenter_cluster_h.add("vsan.$vcenter_name.$vcenter_cluster_dc_name.$vcenter_cluster_name.vsan.EfficientCapacity.LogicalCapacityUsed", $ClusterVsanSpaceUsageReport.EfficientCapacity.LogicalCapacityUsed)
                            #     $vcenter_cluster_h.add("vsan.$vcenter_name.$vcenter_cluster_dc_name.$vcenter_cluster_name.vsan.EfficientCapacity.PhysicalCapacity", $ClusterVsanSpaceUsageReport.EfficientCapacity.PhysicalCapacity)
                            #     $vcenter_cluster_h.add("vsan.$vcenter_name.$vcenter_cluster_dc_name.$vcenter_cluster_name.vsan.EfficientCapacity.PhysicalCapacityUsed", $ClusterVsanSpaceUsageReport.EfficientCapacity.PhysicalCapacityUsed)
                            #     if ($ClusterVsanSpaceUsageReport.EfficientCapacity.SpaceEfficiencyMetadataSize) {
                            #         $vcenter_cluster_h.add("vsan.$vcenter_name.$vcenter_cluster_dc_name.$vcenter_cluster_name.vsan.SpaceEfficiencyMetadataSize.CompressionMetadataSize", $ClusterVsanSpaceUsageReport.EfficientCapacity.SpaceEfficiencyMetadataSize.CompressionMetadataSize)
                            #         $vcenter_cluster_h.add("vsan.$vcenter_name.$vcenter_cluster_dc_name.$vcenter_cluster_name.vsan.SpaceEfficiencyMetadataSize.DedupMetadataSize", $ClusterVsanSpaceUsageReport.EfficientCapacity.SpaceEfficiencyMetadataSize.DedupMetadataSize)
                            #     } elseif ($ClusterVsanSpaceUsageReport.EfficientCapacity.DedupMetadataSize) {
                            #         $vcenter_cluster_h.add("vsan.$vcenter_name.$vcenter_cluster_dc_name.$vcenter_cluster_name.vsan.SpaceEfficiencyMetadataSize.DedupMetadataSize", $ClusterVsanSpaceUsageReport.EfficientCapacity.DedupMetadataSize)
                            #     }
                            # }        
                        } catch {
                            Write-Host "$((Get-Date).ToString("o")) [WARN] Unable to retreive VsanQuerySpaceUsage for cluster $vcenter_cluster_name"
                            Write-Host "$((Get-Date).ToString("o")) [WARN] $($Error[0])"
                        }

                        try {
                            Write-Host "$((Get-Date).ToString("o")) [INFO] Start processing SyncingVsanObjectsSummary in cluster $vcenter_cluster_name (v6.7+) ..."
                            # https://vdc-download.vmware.com/vmwb-repository/dcr-public/b21ba11d-4748-4796-97e2-7000e2543ee1/b4a40704-fbca-4222-902c-2500f5a90f3f/vim.cluster.VsanObjectSystem.html#querySyncingVsanObjectsSummary
                            # https://vdc-download.vmware.com/vmwb-repository/dcr-public/9ab58fbf-b389-4e15-bfd4-a915910be724/7872dcb2-3287-40e1-ba00-71071d0e19ff/vim.vsan.VsanSyncReason.html
                            $QuerySyncingVsanObjectsSummary = $VsanObjectSystem.QuerySyncingVsanObjectsSummary($vcenter_cluster.Moref,$(New-Object VMware.Vsan.Views.VsanSyncingObjectFilter -property @{NumberOfObjects="200"}))
                            if ($QuerySyncingVsanObjectsSummary.TotalObjectsToSync -gt 0) {
                                if ($QuerySyncingVsanObjectsSummary.Objects) {
                                    $ReasonsToSync = @{}
                                    foreach ($SyncingComponent in $QuerySyncingVsanObjectsSummary.Objects.Components) {
                                        $SyncingComponentJoinReason = $SyncingComponent.Reasons -join "-"
                                        $ReasonsToSync.$SyncingComponentJoinReason += $SyncingComponent.BytesToSync
                                    }

                                    foreach ($ReasonToSync in $ReasonsToSync.keys) {
                                        $vcenter_cluster_h.add("vsan.$vcenter_name.$vcenter_cluster_dc_name.$vcenter_cluster_name.vsan.SyncingVsanObjects.bytesToSync.$ReasonToSync",$ReasonsToSync.$ReasonToSync)
                                    }        
                                }
    
                                $vcenter_cluster_h.add("vsan.$vcenter_name.$vcenter_cluster_dc_name.$vcenter_cluster_name.vsan.SyncingVsanObjects.totalRecoveryETA",$QuerySyncingVsanObjectsSummary.TotalRecoveryETA)
                                $vcenter_cluster_h.add("vsan.$vcenter_name.$vcenter_cluster_dc_name.$vcenter_cluster_name.vsan.SyncingVsanObjects.totalBytesToSync",$QuerySyncingVsanObjectsSummary.TotalBytesToSync)
                                $vcenter_cluster_h.add("vsan.$vcenter_name.$vcenter_cluster_dc_name.$vcenter_cluster_name.vsan.SyncingVsanObjects.totalObjectsToSync",$QuerySyncingVsanObjectsSummary.TotalObjectsToSync)
                                $vcenter_cluster_h.add("vsan.$vcenter_name.$vcenter_cluster_dc_name.$vcenter_cluster_name.vsan.SyncingVsanObjects.totalComponentsToSync",($QuerySyncingVsanObjectsSummary.Objects.Components|Measure-Object -sum).count)

                            }
                        } catch {
                            Write-Host "$((Get-Date).ToString("o")) [WARN] Unable to retreive SyncingVsanObjectsSummary in cluster $vcenter_cluster_name"
                            Write-Host "$((Get-Date).ToString("o")) [WARN] $($Error[0])"
                        }

                        try {
                            Write-Host "$((Get-Date).ToString("o")) [INFO] Start processing VsanObjectIdentityAndHealth in cluster $vcenter_cluster_name ..."
                            $vcenter_cluster_ObjectIdentities = $VsanObjectSystem.VsanQueryObjectIdentities($vcenter_cluster.moref,$null,$null,$true,$false,$false) ### TODO optimize
                            if ($vcenter_cluster_ObjectIdentities.Health.ObjectHealthDetail) {
                                foreach ($ObjectHealth in $vcenter_cluster_ObjectIdentities.Health.ObjectHealthDetail) {
                                    if ($ObjectHealth.NumObjects -gt 0) {
                                        $vcenter_cluster_h.add("vsan.$vcenter_name.$vcenter_cluster_dc_name.$vcenter_cluster_name.vsan.ObjectHealthDetail.$($ObjectHealth.Health)", $($ObjectHealth.NumObjects))
                                    }
                                }        
                            }
                        } catch {
                            Write-Host "$((Get-Date).ToString("o")) [WARN] Unable to retreive VsanObjectIdentityAndHealth from cluster $vcenter_cluster_name"
                            Write-Host "$((Get-Date).ToString("o")) [WARN] $($Error[0])"
                        }
                    }
                }
            }
        }

        if ($vcenter_cluster_datastores_count -gt 0) {
            $vcenter_cluster_datastores_utilization = ($vcenter_cluster_datastores_capacity - $vcenter_cluster_datastores_freeSpace) * 100 / $vcenter_cluster_datastores_capacity
            $vcenter_cluster_h.add("vmw.$vcenter_name.$vcenter_cluster_dc_name.$vcenter_cluster_name.superstats.datastore.count", $vcenter_cluster_datastores_count)
            $vcenter_cluster_h.add("vmw.$vcenter_name.$vcenter_cluster_dc_name.$vcenter_cluster_name.superstats.datastore.capacity", $vcenter_cluster_datastores_capacity)
            $vcenter_cluster_h.add("vmw.$vcenter_name.$vcenter_cluster_dc_name.$vcenter_cluster_name.superstats.datastore.freeSpace", $vcenter_cluster_datastores_freeSpace)
            $vcenter_cluster_h.add("vmw.$vcenter_name.$vcenter_cluster_dc_name.$vcenter_cluster_name.superstats.datastore.utilization", $vcenter_cluster_datastores_utilization)
            $vcenter_cluster_h.add("vmw.$vcenter_name.$vcenter_cluster_dc_name.$vcenter_cluster_name.superstats.datastore.uncommitted", $vcenter_cluster_datastores_uncommitted)
            $vcenter_cluster_h.add("vmw.$vcenter_name.$vcenter_cluster_dc_name.$vcenter_cluster_name.superstats.datastore.max_latency", $($vcenter_cluster_datastores_latency|Measure-Object -Maximum).Maximum)
            $vcenter_cluster_h.add("vmw.$vcenter_name.$vcenter_cluster_dc_name.$vcenter_cluster_name.superstats.datastore.mid_latency", $(GetMedian $vcenter_cluster_datastores_latency))
            $vcenter_cluster_h.add("vmw.$vcenter_name.$vcenter_cluster_dc_name.$vcenter_cluster_name.superstats.datastore.iops", $vcenter_cluster_datastores_iops)
        }

        Write-Host "$((Get-Date).ToString("o")) [INFO] Sending cluster, hosts, vms and datastores metrics to Graphite for cluster $vcenter_cluster_name ..."
        Send-BulkGraphiteMetrics -CarbonServer 127.0.0.1 -CarbonServerPort 2003 -Metrics $vcenter_cluster_h -DateTime $ExecStart
    }

    foreach ($vcenter_pod_moref in $vcenter_pods_h.keys) {
        $vcenter_pod = $vcenter_pods_h[$vcenter_pod_moref]
        if ($vcenter_pod.childEntity) {
            try {
                $vcenter_pod_name = NameCleaner $vcenter_pod.Name
                $vcenter_pod_dc_name = nameCleaner $(getRootDc $vcenter_pod)
                Write-Host "$((Get-Date).ToString("o")) [INFO] Processing vCenter $vcenter_name pod $vcenter_pod_name in datacenter $vcenter_pod_dc_name"
            } catch {
                AltAndCatchFire "pod name cleaning issue"
            }

            $vcenter_pod_datastores = $vcenter_datastores_h[$vcenter_pod.childEntity.value]
            $vcenter_pod_uncommitted = $($vcenter_pod_datastores.summary.uncommitted|Measure-Object -Sum).Sum
            $vcenter_pod_vmdk = $($vcenter_cluster_vmdk_per_ds[$vcenter_pod_datastores.name]|Measure-Object -Sum).Sum

            $vcenter_pod_h = @{}
            $vcenter_pod_h.add("pod.$vcenter_name.$vcenter_pod_dc_name.$vcenter_pod_name.summary.capacity", $vcenter_pod.Summary.Capacity)
            $vcenter_pod_h.add("pod.$vcenter_name.$vcenter_pod_dc_name.$vcenter_pod_name.summary.freeSpace", $vcenter_pod.Summary.FreeSpace)
            $vcenter_pod_h.add("pod.$vcenter_name.$vcenter_pod_dc_name.$vcenter_pod_name.summary.uncommitted", $vcenter_pod_uncommitted)
            $vcenter_pod_h.add("pod.$vcenter_name.$vcenter_pod_dc_name.$vcenter_pod_name.summary.vmdkCount", $vcenter_pod_vmdk)

            Send-BulkGraphiteMetrics -CarbonServer 127.0.0.1 -CarbonServerPort 2003 -Metrics $vcenter_pod_h -DateTime $ExecStart
        }
    }

    foreach ($vcenter_standalone_host_moref in $vcenter_compute_h.keys) {

        if ($vcenter_compute_h[$vcenter_standalone_host_moref] -and $vcenter_vmhosts_h[$vcenter_compute_h[$vcenter_standalone_host_moref].host.value] -and $vcenter_resource_pools_h[$vcenter_standalone_host_moref]) {

            $vcenter_standalone_host_h = @{}

            try {
                $vcenter_standalone_pool = $vcenter_compute_h[$vcenter_standalone_host_moref]
                # $vcenter_standalone_rpool = $vcenter_resource_pools_h[$vcenter_standalone_host_moref]
                $vcenter_standalone_host = $vcenter_vmhosts_h[$vcenter_compute_h[$vcenter_standalone_host_moref].host.value]
                $vcenter_standalone_host_name = $vcenter_standalone_host.config.network.dnsConfig.hostName.ToLower() ### why not $vcenter_standalone_host.name.split(".")[0].ToLower() ? because could be ip !!!
                if ($vcenter_standalone_host_name -match "localhost") {
                    $vcenter_standalone_host_name = NameCleaner $vcenter_standalone_host.name ### previously vmk0 ip cleaned

                }
                $vcenter_standalone_host_dc_name = nameCleaner $(getRootDc $vcenter_standalone_pool)
                Write-Host "$((Get-Date).ToString("o")) [INFO] Processing vCenter $vcenter_name standalone host $vcenter_standalone_host_name in datacenter $vcenter_standalone_host_dc_name"
            } catch {
                AltAndCatchFire "standalone_host name cleaning issue"
            }

            if ($vcenter_standalone_host.config.product.version -and $vcenter_standalone_host.config.product.build -and $vcenter_standalone_host.summary.hardware.cpuModel) {
                $vcenter_standalone_host_product_version = nameCleaner $($vcenter_standalone_host.config.product.version + "_" + $vcenter_standalone_host.config.product.build)
                $vcenter_standalone_host_hw_model = nameCleaner $($vcenter_standalone_host.summary.hardware.vendor + "_" + $vcenter_standalone_host.summary.hardware.model)
                $vcenter_standalone_host_cpu_model = nameCleaner $vcenter_standalone_host.summary.hardware.cpuModel

                $vmware_version_h["vi.$vcenter_name.vi.version.esx.$vcenter_standalone_host_dc_name.$vcenter_standalone_host_name.build.$vcenter_standalone_host_product_version"] ++
                $vmware_version_h["vi.$vcenter_name.vi.version.esx.$vcenter_standalone_host_dc_name.$vcenter_standalone_host_name.hardware.$vcenter_standalone_host_hw_model"] ++
                $vmware_version_h["vi.$vcenter_name.vi.version.esx.$vcenter_standalone_host_dc_name.$vcenter_standalone_host_name.cpu.$vcenter_standalone_host_cpu_model"] ++
            }

            try {
                $vcenter_standalone_host_sensors = $vcenter_standalone_host.summary.runtime.healthSystemRuntime.systemHealthInfo.numericSensorInfo
                # https://vdc-download.vmware.com/vmwb-repository/dcr-public/b50dcbbf-051d-4204-a3e7-e1b618c1e384/538cf2ec-b34f-4bae-a332-3820ef9e7773/vim.host.NumericSensorInfo.html
                foreach ($vcenter_standalone_host_sensor in $vcenter_standalone_host_sensors) {
                    if ($vcenter_standalone_host_sensor.name -and $vcenter_standalone_host_sensor.sensorType -and $vcenter_standalone_host_sensor.currentReading -and $vcenter_standalone_host_sensor.unitModifier) {

                        $vcenter_standalone_host_sensor_computed_reading = $vcenter_standalone_host_sensor.currentReading * $([Math]::Pow(10, $vcenter_standalone_host_sensor.unitModifier))
                        $vcenter_standalone_host_sensor_name = NameCleaner $vcenter_standalone_host_sensor.name
                        $vcenter_standalone_host_sensor_type = $vcenter_standalone_host_sensor.sensorType

                        $vcenter_standalone_host_h.add("esx.$vcenter_name.$vcenter_standalone_host_dc_name.$vcenter_standalone_host_name.sensor.$vcenter_standalone_host_sensor_type.$vcenter_standalone_host_sensor_name", $vcenter_standalone_host_sensor_computed_reading)
                    }
                }
            } catch {
                Write-Host "$((Get-Date).ToString("o")) [EROR] ESX $vcenter_standalone_host sensors issue in datacenter $vcenter_standalone_host_dc_name"
                Write-Host "$((Get-Date).ToString("o")) [EROR] $($Error[0])"
            }

            if ($vcenter_standalone_host.overallStatus) {
                $vcenter_standalone_host_overallStatus = $vcenter_standalone_host.overallStatus.value__
            } else {
                $vcenter_standalone_host_overallStatus = "0"
            }

            try {
                $vcenter_standalone_host_h.add("esx.$vcenter_name.$vcenter_standalone_host_dc_name.$vcenter_standalone_host_name.quickstats.mem.usage", $vcenter_standalone_host.Summary.QuickStats.OverallMemoryUsage)
                # $vcenter_standalone_host_h.add("esx.$vcenter_name.$vcenter_standalone_host_dc_name.$vcenter_standalone_host_name.quickstats.cpu.demand", $vcenter_standalone_rpool.summary.quickStats.overallCpuDemand)
                $vcenter_standalone_host_h.add("esx.$vcenter_name.$vcenter_standalone_host_dc_name.$vcenter_standalone_host_name.quickstats.cpu.usage", $vcenter_standalone_host.Summary.QuickStats.overallCpuUsage)
                $vcenter_standalone_host_h.add("esx.$vcenter_name.$vcenter_standalone_host_dc_name.$vcenter_standalone_host_name.quickstats.mem.effective", $vcenter_standalone_pool.summary.effectiveMemory)
                $vcenter_standalone_host_h.add("esx.$vcenter_name.$vcenter_standalone_host_dc_name.$vcenter_standalone_host_name.quickstats.mem.total", $vcenter_standalone_pool.summary.totalMemory)
                $vcenter_standalone_host_h.add("esx.$vcenter_name.$vcenter_standalone_host_dc_name.$vcenter_standalone_host_name.quickstats.cpu.effective", $vcenter_standalone_pool.summary.effectiveCpu)
                $vcenter_standalone_host_h.add("esx.$vcenter_name.$vcenter_standalone_host_dc_name.$vcenter_standalone_host_name.quickstats.cpu.total", $vcenter_standalone_pool.summary.totalCpu)
                $vcenter_standalone_host_h.add("esx.$vcenter_name.$vcenter_standalone_host_dc_name.$vcenter_standalone_host_name.quickstats.overallStatus", $vcenter_standalone_host_overallStatus)
            } catch {
                Write-Host "$((Get-Date).ToString("o")) [EROR] ESX $vcenter_standalone_host_name quickstats issue in datacenter $vcenter_standalone_host_dc_name"
                Write-Host "$((Get-Date).ToString("o")) [EROR] $($Error[0])"
            }

            Write-Host "$((Get-Date).ToString("o")) [INFO] Processing vCenter $vcenter_name standalone host $vcenter_standalone_host_name datastores in datacenter $vcenter_standalone_host_dc_name"

            foreach ($vcenter_standalone_host_datastore in $vcenter_datastores_h[$vcenter_standalone_pool.Datastore.value]|?{$_}) {
                if ($vcenter_standalone_host_datastore.summary.accessible) {
                    try {
                        $vcenter_standalone_host_datastore_name = NameCleaner $vcenter_standalone_host_datastore.summary.name

                        if($vcenter_standalone_host_datastore.summary.uncommitted -ge 0) {
                            $vcenter_standalone_host_datastore_uncommitted = $vcenter_standalone_host_datastore.summary.uncommitted
                        } else {
                            $vcenter_standalone_host_datastore_uncommitted = 0
                        }

                        $vcenter_standalone_host_h.add("esx.$vcenter_name.$vcenter_standalone_host_dc_name.$vcenter_standalone_host_name.datastore.$vcenter_standalone_host_datastore_name.summary.capacity", $vcenter_standalone_host_datastore.summary.capacity)
                        $vcenter_standalone_host_h.add("esx.$vcenter_name.$vcenter_standalone_host_dc_name.$vcenter_standalone_host_name.datastore.$vcenter_standalone_host_datastore_name.summary.freeSpace", $vcenter_standalone_host_datastore.summary.freeSpace)
                        $vcenter_standalone_host_h.add("esx.$vcenter_name.$vcenter_standalone_host_dc_name.$vcenter_standalone_host_name.datastore.$vcenter_standalone_host_datastore_name.summary.uncommitted", $vcenter_standalone_host_datastore_uncommitted)

                        if ($vcenter_standalone_host_datastore.summary.type -notmatch "vsan") {
                            $vcenter_standalone_host_datastore_uuid = $vcenter_standalone_host_datastore.summary.url.split("/")[-2]

                            $vcenter_standalone_host_datastore_latency = $HostMultiStats[$PerfCounterTable["datastore.sizeNormalizedDatastoreLatency.latest"]][$vcenter_standalone_host.moref.value][$vcenter_standalone_host_datastore_uuid]
                            $vcenter_standalone_host_h.add("esx.$vcenter_name.$vcenter_standalone_host_dc_name.$vcenter_standalone_host_name.datastore.$vcenter_standalone_host_datastore_name.iorm.sizeNormalizedDatastoreLatency", $vcenter_standalone_host_datastore_latency)

                            $vcenter_standalone_host_datastore_iops_w = $HostMultiStats[$PerfCounterTable["datastore.numberWriteAveraged.average"]][$vcenter_standalone_host.moref.value][$vcenter_standalone_host_datastore_uuid]
                            $vcenter_standalone_host_datastore_iops_r = $HostMultiStats[$PerfCounterTable["datastore.numberReadAveraged.average"]][$vcenter_standalone_host.moref.value][$vcenter_standalone_host_datastore_uuid]
                            $vcenter_standalone_host_datastore_iops = $vcenter_standalone_host_datastore_iops_w + $vcenter_standalone_host_datastore_iops_r.Sum
                            $vcenter_standalone_host_h.add("esx.$vcenter_name.$vcenter_standalone_host_dc_name.$vcenter_standalone_host_name.datastore.$vcenter_standalone_host_datastore_name.iorm.datastoreIops", $vcenter_standalone_host_datastore_iops)
                        }
                    } catch {
                        Write-Host "$((Get-Date).ToString("o")) [EROR] datastore processing issue on ESX $vcenter_standalone_host_name in datacenter $vcenter_standalone_host_dc_name"
                        Write-Host "$((Get-Date).ToString("o")) [EROR] $($Error[0])"
                    }
                }
            }
            
            try {
                foreach ($vcenter_standalone_host_vmnic in $vcenter_standalone_host.config.network.pnic) {
                    if ($vcenter_standalone_host_vmnic.linkSpeed -and $vcenter_standalone_host_vmnic.linkSpeed.speedMb -ge 100) {
                        $vcenter_standalone_host_vmnic_name = $vcenter_standalone_host_vmnic.device

                        $vcenter_standalone_host_vmnic_bytesRx = $HostMultiStats[$PerfCounterTable["net.bytesRx.average"]][$vcenter_standalone_host.moref.value][$vcenter_standalone_host_vmnic_name]
                        $vcenter_standalone_host_vmnic_bytesTx = $HostMultiStats[$PerfCounterTable["net.bytesTx.average"]][$vcenter_standalone_host.moref.value][$vcenter_standalone_host_vmnic_name]

                        if ($vcenter_standalone_host_vmnic_bytesRx -ge 0 -and $vcenter_standalone_host_vmnic_bytesTx -ge 0) {
                            $vcenter_standalone_host_h.add("esx.$vcenter_name.$vcenter_standalone_host_dc_name.$vcenter_standalone_host_name.net.$vcenter_standalone_host_vmnic_name.bytesRx", $vcenter_standalone_host_vmnic_bytesRx)
                            $vcenter_standalone_host_h.add("esx.$vcenter_name.$vcenter_standalone_host_dc_name.$vcenter_standalone_host_name.net.$vcenter_standalone_host_vmnic_name.bytesTx", $vcenter_standalone_host_vmnic_bytesTx)
                        }
                    }
                }
            } catch {
                Write-Host "$((Get-Date).ToString("o")) [EROR] ESX $vcenter_standalone_host_name network metrics issue in datacenter $vcenter_standalone_host_dc_name"
                Write-Host "$((Get-Date).ToString("o")) [EROR] $($Error[0])"
            }

            try {
                foreach ($vcenter_standalone_host_vmhba in $vcenter_standalone_host.config.storageDevice.hostBusAdapter) {
                    $vcenter_standalone_host_vmhba_name = $vcenter_standalone_host_vmhba.device
                    $vcenter_standalone_host_vmhba_bytesRead = $HostMultiStats[$PerfCounterTable["storageAdapter.read.average"]][$vcenter_standalone_host.moref.value][$vcenter_standalone_host_vmhba_name]
                    $vcenter_standalone_host_vmhba_bytesWrite = $HostMultiStats[$PerfCounterTable["storageAdapter.write.average"]][$vcenter_standalone_host.moref.value][$vcenter_standalone_host_vmhba_name]
                
                    if ($vcenter_standalone_host_vmhba_bytesRead -ge 0 -and $vcenter_standalone_host_vmhba_bytesWrite -ge 0) {

                        $vcenter_standalone_host_h.add("esx.$vcenter_name.$vcenter_standalone_host_dc_name.$vcenter_standalone_host_name.hba.$vcenter_standalone_host_vmhba_name.bytesRead", $vcenter_standalone_host_vmhba_bytesRead)
                        $vcenter_standalone_host_h.add("esx.$vcenter_name.$vcenter_standalone_host_dc_name.$vcenter_standalone_host_name.hba.$vcenter_standalone_host_vmhba_name.bytesWrite", $vcenter_standalone_host_vmhba_bytesWrite)
                    }
                }
            } catch {
                Write-Host "$((Get-Date).ToString("o")) [EROR] ESX $vcenter_standalone_host_name hba metrics issue in datacenter $vcenter_standalone_host_dc_name"
                Write-Host "$((Get-Date).ToString("o")) [EROR] $($Error[0])"
            }

            try {
                foreach ($vcenter_standalone_host_path in $vcenter_standalone_host.Config.MultipathState.Path) { 
                    $vcenter_standalone_host_h["esx.$vcenter_name.$vcenter_standalone_host_dc_name.$vcenter_standalone_host_name.superstats.PathState.$($vcenter_standalone_host_path.PathState)"] ++
                }
            } catch {
                Write-Host "$((Get-Date).ToString("o")) [EROR] ESX $vcenter_standalone_host_name MultipathState issue in cluster $vcenter_cluster_name"
                Write-Host "$((Get-Date).ToString("o")) [EROR] $($Error[0])"
            }

            Write-Host "$((Get-Date).ToString("o")) [INFO] Processing vCenter $vcenter_name standalone host $vcenter_standalone_host_name vms in datacenter $vcenter_standalone_host_dc_name"

            $StandaloneResourcePoolPrivateMemory = 0
            $StandaloneResourcePoolSharedMemory = 0
            $StandaloneResourcePoolBalloonedMemory = 0
            $StandaloneResourcePoolCompressedMemory = 0
            $StandaloneResourcePoolSwappedMemory = 0
            $StandaloneResourcePoolGuestMemoryUsage = 0
            $StandaloneResourcePoolConsumedOverheadMemory = 0

            $vcenter_standalone_host_vms_vcpus = 0
            $vcenter_standalone_host_vms_vram = 0
            $vcenter_standalone_host_vms_files_dedup = @{}
            $vcenter_standalone_host_vms_files_dedup_total = @{}
            $vcenter_standalone_host_vms_files_snaps = 0
            $vcenter_standalone_host_vms_snaps = 0
            $vcenter_standalone_host_vms_off = 0
            $vcenter_standalone_host_vms_on = 0
            $vcenter_standalone_host_vmdk_per_ds = @{}

            foreach ($vcenter_standalone_host_vm in $vcenter_vms_h[$vcenter_standalone_host.vm.value]|?{$_}) {

                if ($vcenter_standalone_host_vm.config.version) {
                    $vcenter_standalone_host_vm_vhw = NameCleaner $vcenter_standalone_host_vm.config.version
                    $vmware_version_h["vi.$vcenter_name.vi.version.vm.$vcenter_standalone_host_dc_name.$vcenter_standalone_host_name.vhw.$vcenter_standalone_host_vm_vhw"] ++
                }

                if ($vcenter_standalone_host_vm.config.guestId) {
                    $vcenter_standalone_host_vm_guestId = NameCleaner $vcenter_standalone_host_vm.config.guestId
                    $vmware_version_h["vi.$vcenter_name.vi.version.vm.$vcenter_standalone_host_dc_name.$vcenter_standalone_host_name.guest.$vcenter_standalone_host_vm_guestId"] ++
                }

                if ($vcenter_standalone_host_vm.config.tools.toolsVersion) {
                    $vcenter_standalone_host_vm_vmtools = NameCleaner $vcenter_standalone_host_vm.config.tools.toolsVersion
                    $vmware_version_h["vi.$vcenter_name.vi.version.vm.$vcenter_standalone_host_dc_name.$vcenter_standalone_host_name.vmtools.$vcenter_standalone_host_vm_vmtools"] ++
                }

                $vcenter_standalone_host_vm_name = NameCleaner $vcenter_standalone_host_vm.Name

                try {
                    $vcenter_standalone_host_vm_files = $vcenter_standalone_host_vm.layoutEx.file
                    ### http://pubs.vmware.com/vsphere-60/topic/com.vmware.wSsdk.apiref.doc/vim.vm.FileLayoutEx.FileType.html

                    $vcenter_standalone_host_vm_snap_size = 0

                    if ($vcenter_standalone_host_vm.snapshot) {
                        $vcenter_standalone_host_vm_has_snap = 1
                        $vcenter_standalone_host_vms_snaps ++
                    } else {
                        $vcenter_standalone_host_vm_has_snap = 0
                    }

                    $vcenter_standalone_host_vm_num_vdisk = $vcenter_standalone_host_vm.summary.config.numVirtualDisks
                    $vcenter_standalone_host_vm_real_vdisk = 0
                    $vcenter_standalone_host_vm_has_diskExtent = 0

                    foreach ($vcenter_standalone_host_vm_file in $vcenter_standalone_host_vm_files) {
                        if ($vcenter_standalone_host_vm_file.type -eq "diskDescriptor") {
                            $vcenter_standalone_host_vm_real_vdisk ++
                            $vcenter_standalone_host_vm_file_ds_name = nameCleaner $([regex]::match($vcenter_standalone_host_vm_file.name, '^\[(.*)\]').Groups[1].value)
                            $vcenter_standalone_host_vmdk_per_ds[$vcenter_standalone_host_vm_file_ds_name] ++
                        } elseif ($vcenter_standalone_host_vm_file.type -eq "diskExtent") {
                            $vcenter_standalone_host_vm_has_diskExtent ++
                        }
                    }

                    if ($vcenter_standalone_host_vm_real_vdisk -gt $vcenter_standalone_host_vm_num_vdisk) {
                        $vcenter_standalone_host_vm_has_snap = 1
                    }

                    foreach ($vcenter_standalone_host_vm_file in $vcenter_standalone_host_vm_files) {
                        if(!$vcenter_standalone_host_vms_files_dedup[$vcenter_standalone_host_vm_file.name]) { ### TODO would need name & moref
                            $vcenter_standalone_host_vms_files_dedup[$vcenter_standalone_host_vm_file.name] = $vcenter_standalone_host_vm_file.size
                            if ($vcenter_standalone_host_vm_has_snap -and (($vcenter_standalone_host_vm_file.name -match '-[0-9]{6}-delta\.vmdk') -or ($vcenter_standalone_host_vm_file.name -match '-[0-9]{6}-sesparse\.vmdk'))) {
                                $vcenter_standalone_host_vms_files_dedup_total["snapshotExtent"] += $vcenter_standalone_host_vm_file.size
                                $vcenter_standalone_host_vm_snap_size += $vcenter_standalone_host_vm_file.size
                            } elseif ($vcenter_standalone_host_vm_has_snap -and ($vcenter_standalone_host_vm_file.name -match '-[0-9]{6}\.vmdk')) {
                                $vcenter_standalone_host_vms_files_dedup_total["snapshotDescriptor"] += $vcenter_standalone_host_vm_file.size
                                $vcenter_standalone_host_vm_snap_size += $vcenter_standalone_host_vm_file.size
                                $vcenter_standalone_host_vms_files_snaps ++
                            } elseif ($vcenter_standalone_host_vm_file.name -match '-rdm\.vmdk') {
                                $vcenter_standalone_host_vms_files_dedup_total["rdmExtent"] += $vcenter_standalone_host_vm_file.size
                            } elseif ($vcenter_standalone_host_vm_file.name -match '-rdmp\.vmdk') {
                                $vcenter_standalone_host_vms_files_dedup_total["rdmpExtent"] += $vcenter_standalone_host_vm_file.size
                            } elseif ((!$vcenter_standalone_host_vm_has_diskExtent) -and $vcenter_standalone_host_vm_file.type -eq "diskDescriptor") {
                                $vcenter_standalone_host_vms_files_dedup_total["virtualExtent"] += $vcenter_standalone_host_vm_file.size
                            } else {
                                $vcenter_standalone_host_vms_files_dedup_total[$vcenter_standalone_host_vm_file.type] += $vcenter_standalone_host_vm_file.size
                            }
                        }
                    }

                    if ($vcenter_standalone_host_vm_snap_size -gt 0) {
                        $vcenter_standalone_host_h.add("esx.$vcenter_name.$vcenter_standalone_host_dc_name.$vcenter_standalone_host_name.vm.$vcenter_standalone_host_vm_name.storage.delta", $vcenter_standalone_host_vm_snap_size)
                    }
                } catch {
                    Write-Host "$((Get-Date).ToString("o")) [EROR] VM $vcenter_standalone_host_vm_name snapshot compute issue standalone host $vcenter_standalone_host_name"
                    Write-Host "$((Get-Date).ToString("o")) [EROR] $($Error[0])"
                }

                try {
                    $vcenter_standalone_host_h.add("esx.$vcenter_name.$vcenter_standalone_host_dc_name.$vcenter_standalone_host_name.vm.$vcenter_standalone_host_vm_name.storage.committed", $vcenter_standalone_host_vm.summary.storage.committed)
                    $vcenter_standalone_host_h.add("esx.$vcenter_name.$vcenter_standalone_host_dc_name.$vcenter_standalone_host_name.vm.$vcenter_standalone_host_vm_name.storage.uncommitted", $vcenter_standalone_host_vm.summary.storage.uncommitted)
                } catch {
                    Write-Host "$((Get-Date).ToString("o")) [EROR] VM $vcenter_standalone_host_vm_name storage commit metric issue standalone host $vcenter_standalone_host_name"
                    Write-Host "$((Get-Date).ToString("o")) [EROR] $($Error[0])"
                }

                if ($vcenter_standalone_host_vm.summary.runtime.powerState -eq "poweredOn") {
                    $vcenter_standalone_host_vms_on ++

                    $vcenter_standalone_host_vms_vcpus += $vcenter_standalone_host_vm.config.hardware.numCPU
                    $vcenter_standalone_host_vms_vram += $vcenter_standalone_host_vm.runtime.maxMemoryUsage


                    if ($vcenter_standalone_host_vm.runtime.maxCpuUsage -gt 0 -and $vcenter_standalone_host_vm.summary.quickStats.overallCpuUsage) {
                        $vcenter_standalone_host_vm_CpuUtilization = $vcenter_standalone_host_vm.summary.quickStats.overallCpuUsage * 100 / $vcenter_standalone_host_vm.runtime.maxCpuUsage
                        $vcenter_standalone_host_h.add("esx.$vcenter_name.$vcenter_standalone_host_dc_name.$vcenter_standalone_host_name.vm.$vcenter_standalone_host_vm_name.runtime.CpuUtilization", $vcenter_standalone_host_vm_CpuUtilization)
                    }

                    if ($vcenter_standalone_host_vm.summary.quickStats.guestMemoryUsage -gt 0 -and $vcenter_standalone_host_vm.runtime.maxMemoryUsage) {
                        $vcenter_standalone_host_vm_MemUtilization = $vcenter_standalone_host_vm.summary.quickStats.guestMemoryUsage * 100 / $vcenter_standalone_host_vm.runtime.maxMemoryUsage
                        $vcenter_standalone_host_h.add("esx.$vcenter_name.$vcenter_standalone_host_dc_name.$vcenter_standalone_host_name.vm.$vcenter_standalone_host_vm_name.runtime.MemUtilization", $vcenter_standalone_host_vm_MemUtilization)
                    }

                    $vcenter_standalone_host_h.add("esx.$vcenter_name.$vcenter_standalone_host_dc_name.$vcenter_standalone_host_name.vm.$vcenter_standalone_host_vm_name.quickstats.overallCpuUsage", $vcenter_standalone_host_vm.summary.quickStats.overallCpuUsage)
                    $vcenter_standalone_host_h.add("esx.$vcenter_name.$vcenter_standalone_host_dc_name.$vcenter_standalone_host_name.vm.$vcenter_standalone_host_vm_name.quickstats.overallCpuDemand", $vcenter_standalone_host_vm.summary.quickStats.overallCpuDemand)
                    $vcenter_standalone_host_h.add("esx.$vcenter_name.$vcenter_standalone_host_dc_name.$vcenter_standalone_host_name.vm.$vcenter_standalone_host_vm_name.quickstats.HostMemoryUsage", $vcenter_standalone_host_vm.summary.quickStats.hostMemoryUsage)
                    $vcenter_standalone_host_h.add("esx.$vcenter_name.$vcenter_standalone_host_dc_name.$vcenter_standalone_host_name.vm.$vcenter_standalone_host_vm_name.quickstats.GuestMemoryUsage", $vcenter_standalone_host_vm.summary.quickStats.guestMemoryUsage)

                    if ($vcenter_standalone_host_vm.summary.quickStats.balloonedMemory -gt 0) {
                        $vcenter_standalone_host_h.add("esx.$vcenter_name.$vcenter_standalone_host_dc_name.$vcenter_standalone_host_name.vm.$vcenter_standalone_host_vm_name.quickstats.BalloonedMemory", $vcenter_standalone_host_vm.summary.quickStats.balloonedMemory)
                        $StandaloneResourcePoolBalloonedMemory += $vcenter_standalone_host_vm.summary.quickStats.balloonedMemory
                    }

                    if ($vcenter_standalone_host_vm.summary.quickStats.compressedMemory -gt 0) {
                        $vcenter_standalone_host_h.add("esx.$vcenter_name.$vcenter_standalone_host_dc_name.$vcenter_standalone_host_name.vm.$vcenter_standalone_host_vm_name.quickstats.CompressedMemory", $vcenter_standalone_host_vm.summary.quickStats.compressedMemory)
                        $StandaloneResourcePoolCompressedMemory += $vcenter_standalone_host_vm.summary.quickStats.compressedMemory
                    }

                    if ($vcenter_standalone_host_vm.summary.quickStats.swappedMemory -gt 0) {
                        $vcenter_standalone_host_h.add("esx.$vcenter_name.$vcenter_standalone_host_dc_name.$vcenter_standalone_host_name.vm.$vcenter_standalone_host_vm_name.quickstats.SwappedMemory", $vcenter_standalone_host_vm.summary.quickStats.swappedMemory)
                        $StandaloneResourcePoolSwappedMemory += $vcenter_standalone_host_vm.summary.quickStats.swappedMemory
                    }

                    if ($VmMultiStats[$PerfCounterTable["cpu.ready.summation"]][$vcenter_standalone_host_vm.moref.value][""]) {
                        $vcenter_standalone_host_vm_ready = $VmMultiStats[$PerfCounterTable["cpu.ready.summation"]][$vcenter_standalone_host_vm.moref.value][""] / $vcenter_standalone_host_vm.config.hardware.numCPU / 20000 * 100 
                        ### https://kb.vmware.com/kb/2002181
                        $vcenter_standalone_host_h.add("esx.$vcenter_name.$vcenter_standalone_host_dc_name.$vcenter_standalone_host_name.vm.$vcenter_standalone_host_vm_name.fatstats.cpu_ready_summation", $vcenter_standalone_host_vm_ready)
                    }

                    if ($VmMultiStats[$PerfCounterTable["cpu.wait.summation"]][$vcenter_standalone_host_vm.moref.value][""] -and $VmMultiStats[$PerfCounterTable["cpu.idle.summation"]][$vcenter_standalone_host_vm.moref.value][""]) {
                        $vcenter_standalone_host_vm_io_wait = ($VmMultiStats[$PerfCounterTable["cpu.wait.summation"]][$vcenter_standalone_host_vm.moref.value][""] - $VmMultiStats[$PerfCounterTable["cpu.idle.summation"]][$vcenter_standalone_host_vm.moref.value][""]) / $vcenter_standalone_host_vm.config.hardware.numCPU / 20000 * 100 
                        ### https://code.vmware.com/apis/358/vsphere#/doc/cpu_counters.html
                        ### "Total CPU time spent in wait state.The wait total includes time spent the CPU Idle, CPU Swap Wait, and CPU I/O Wait states."
                        # https://kb.vmware.com/s/article/85393
                        $vcenter_standalone_host_h.add("esx.$vcenter_name.$vcenter_standalone_host_dc_name.$vcenter_standalone_host_name.vm.$vcenter_standalone_host_vm_name.fatstats.cpu_wait_no_idle", $vcenter_standalone_host_vm_io_wait)
                    }

                    if ($VmMultiStats[$PerfCounterTable["cpu.latency.average"]][$vcenter_standalone_host_vm.moref.value][""]) {
                        $vcenter_standalone_host_vm_cpu_latency = $VmMultiStats[$PerfCounterTable["cpu.latency.average"]][$vcenter_standalone_host_vm.moref.value][""]
                        $vcenter_standalone_host_h.add("esx.$vcenter_name.$vcenter_standalone_host_dc_name.$vcenter_standalone_host_name.vm.$vcenter_standalone_host_vm_name.fatstats.cpu_latency_average", $vcenter_standalone_host_vm_cpu_latency)
                    }

                    if ($VmMultiStats[$PerfCounterTable["disk.maxTotalLatency.latest"]][$vcenter_standalone_host_vm.moref.value][""]) {
                        $vcenter_standalone_host_vm_disk_latency = $VmMultiStats[$PerfCounterTable["disk.maxTotalLatency.latest"]][$vcenter_standalone_host_vm.moref.value][""]
                        $vcenter_standalone_host_h.add("esx.$vcenter_name.$vcenter_standalone_host_dc_name.$vcenter_standalone_host_name.vm.$vcenter_standalone_host_vm_name.fatstats.maxTotalLatency", $vcenter_standalone_host_vm_disk_latency)
                    }

                    if ($VmMultiStats[$PerfCounterTable["virtualdisk.write.average"]][$vcenter_standalone_host_vm.moref.value][""] -ge 0 -and $VmMultiStats[$PerfCounterTable["virtualdisk.read.average"]][$vcenter_standalone_host_vm.moref.value][""] -ge 0) {
                        $vcenter_standalone_host_vm_disk_usage = $VmMultiStats[$PerfCounterTable["virtualdisk.write.average"]][$vcenter_standalone_host_vm.moref.value][""] + $VmMultiStats[$PerfCounterTable["virtualdisk.read.average"]][$vcenter_standalone_host_vm.moref.value][""]
                        $vcenter_standalone_host_h.add("esx.$vcenter_name.$vcenter_standalone_host_dc_name.$vcenter_standalone_host_name.vm.$vcenter_standalone_host_vm_name.fatstats.diskUsage", $vcenter_standalone_host_vm_disk_usage)
                    } else {
                        vcenter_standalone_host_h.add("esx.$vcenter_name.$vcenter_standalone_host_dc_name.$vcenter_standalone_host_name.vm.$vcenter_standalone_host_vm_name.fatstats.diskUsage", 0)
                    }

                    if ($VmMultiStats[$PerfCounterTable["virtualdisk.numberWriteAveraged.average"]][$vcenter_standalone_host_vm.moref.value] -and $VmMultiStats[$PerfCounterTable["virtualdisk.numberReadAveraged.average"]][$vcenter_standalone_host_vm.moref.value]) {
                        $vcenter_standalone_host_vm_disk_iops = $($VmMultiStats[$PerfCounterTable["virtualdisk.numberWriteAveraged.average"]][$vcenter_standalone_host_vm.moref.value][$($VmMultiStats[$PerfCounterTable["virtualdisk.numberWriteAveraged.average"]][$vcenter_standalone_host_vm.moref.value]).Keys]|Measure-Object -Sum).Sum + $($VmMultiStats[$PerfCounterTable["virtualdisk.numberReadAveraged.average"]][$vcenter_standalone_host_vm.moref.value][$($VmMultiStats[$PerfCounterTable["virtualdisk.numberWriteAveraged.average"]][$vcenter_standalone_host_vm.moref.value]).Keys]|Measure-Object -Sum).Sum
                        $vcenter_standalone_host_h.add("esx.$vcenter_name.$vcenter_standalone_host_dc_name.$vcenter_standalone_host_name.vm.$vcenter_standalone_host_vm_name.fatstats.diskIOPS", $vcenter_standalone_host_vm_disk_iops)
                    }

                    # if ($VmMultiStats[$PerfCounterTable["net.packetsTx.summation"]][$vcenter_standalone_host_vm.moref.value] -and $VmMultiStats[$PerfCounterTable["net.packetsRx.summation"]][$vcenter_standalone_host_vm.moref.value]) {
                    #     $vcenter_standalone_host_vm_net_iops = $($($VmMultiStats[$PerfCounterTable["net.packetsTx.summation"]][$vcenter_standalone_host_vm.moref.value][$($VmMultiStats[$PerfCounterTable["net.packetsTx.summation"]][$vcenter_standalone_host_vm.moref.value]).Keys]|Measure-Object -Sum).Sum + $($VmMultiStats[$PerfCounterTable["net.packetsRx.summation"]][$vcenter_standalone_host_vm.moref.value][$($VmMultiStats[$PerfCounterTable["net.packetsTx.summation"]][$vcenter_standalone_host_vm.moref.value]).Keys]|Measure-Object -Sum).Sum) / 300
                    #     $unmanaged_host_h.add("esx.$vcenter_name.$unmanaged_host_dc_name.$unmanaged_host_name.vm.$vcenter_standalone_host_vm_name.fatstats.netIOPS", $vcenter_standalone_host_vm_net_iops)
                    # }

                    if ($VmMultiStats[$PerfCounterTable["net.usage.average"]][$vcenter_standalone_host_vm.moref.value][""]) {
                        $vcenter_standalone_host_vm_net_usage = $VmMultiStats[$PerfCounterTable["net.usage.average"]][$vcenter_standalone_host_vm.moref.value][""]
                        $vcenter_standalone_host_h.add("esx.$vcenter_name.$vcenter_standalone_host_dc_name.$vcenter_standalone_host_name.vm.$vcenter_standalone_host_vm_name.fatstats.netUsage", $vcenter_standalone_host_vm_net_usage)
                    } else {
                        $vcenter_standalone_host_h.add("esx.$vcenter_name.$vcenter_standalone_host_dc_name.$vcenter_standalone_host_name.vm.$vcenter_standalone_host_vm_name.fatstats.netUsage", 0)
                    }

                    if ($vcenter_standalone_host_vm.summary.quickStats.privateMemory -gt 0) {$StandaloneResourcePoolPrivateMemory += $vcenter_standalone_host_vm.summary.quickStats.privateMemory}
                    if ($vcenter_standalone_host_vm.summary.quickStats.GuestMemoryUsage -gt 0) {$StandaloneResourcePoolGuestMemoryUsage += $vcenter_standalone_host_vm.summary.quickStats.GuestMemoryUsage}
                    if ($vcenter_standalone_host_vm.summary.quickStats.SharedMemory -gt 0) {$StandaloneResourcePoolSharedMemory += $vcenter_standalone_host_vm.summary.quickStats.SharedMemory}
                    if ($vcenter_standalone_host_vm.summary.quickStats.ConsumedOverheadMemory -gt 0) {$StandaloneResourcePoolConsumedOverheadMemory += $vcenter_standalone_host_vm.summary.quickStats.ConsumedOverheadMemory}

                } elseif ($vcenter_standalone_host_vm.summary.runtime.powerState -eq "poweredOff") {
                    $vcenter_standalone_host_vms_off ++
                }
            }
            
            if ($vcenter_standalone_host_vms_vcpus -gt 0 -and $vcenter_standalone_host_hosts_pcpus -gt 0) {
                $vcenter_standalone_host_h.add("esx.$vcenter_name.$vcenter_standalone_host_dc_name.$vcenter_standalone_host_name.quickstats.vCPUs", $vcenter_standalone_host_vms_vcpus)
                $vcenter_standalone_host_h.add("esx.$vcenter_name.$vcenter_standalone_host_dc_name.$vcenter_standalone_host_name.quickstats.pCPUs", $vcenter_standalone_host_hosts_pcpus)
            }
            
            if ($vcenter_standalone_host_vms_vram -gt 0 -and $vcenter_standalone_host.summary.effectiveMemory -gt 0) {
                $vcenter_standalone_host_pool_quickstats_vram = $vcenter_standalone_host_vms_vram * 100 / $vcenter_standalone_host.summary.effectiveMemory
                $vcenter_standalone_host_h.add("esx.$vcenter_name.$vcenter_standalone_host_dc_name.$vcenter_standalone_host_name.quickstats.vRAM", $vcenter_standalone_host_vms_vram)
                $vcenter_standalone_host_h.add("esx.$vcenter_name.$vcenter_standalone_host_dc_name.$vcenter_standalone_host_name.superstats.mem.allocated", $vcenter_standalone_host_pool_quickstats_vram)
            }

            if ($vcenter_standalone_host_vms_files_dedup_total) {
                foreach ($vcenter_standalone_host_vms_filetype in $vcenter_standalone_host_vms_files_dedup_total.keys) {
                    $vcenter_standalone_host_h.add("esx.$vcenter_name.$vcenter_standalone_host_dc_name.$vcenter_standalone_host_name.storage.FileType.$vcenter_standalone_host_vms_filetype", $vcenter_standalone_host_vms_files_dedup_total[$vcenter_standalone_host_vms_filetype])
                }

                if ($vcenter_standalone_host_vms_files_snaps) {
                    $vcenter_standalone_host_h.add("esx.$vcenter_name.$vcenter_standalone_host_dc_name.$vcenter_standalone_host_name.storage.SnapshotCount", $vcenter_standalone_host_vms_files_snaps)
                }

                if ($vcenter_standalone_host_vms_snaps) {
                    $vcenter_standalone_host_h.add("esx.$vcenter_name.$vcenter_standalone_host_dc_name.$vcenter_standalone_host_name.storage.VmSnapshotCount", $vcenter_standalone_host_vms_snaps)
                }
            }

            $vcenter_standalone_host_h.add("esx.$vcenter_name.$vcenter_standalone_host_dc_name.$vcenter_standalone_host_name.runtime.vm.total", ($vcenter_standalone_host_vms_on + $vcenter_standalone_host_vms_off))
            $vcenter_standalone_host_h.add("esx.$vcenter_name.$vcenter_standalone_host_dc_name.$vcenter_standalone_host_name.runtime.vm.on", $vcenter_standalone_host_vms_on)
            $vcenter_standalone_host_h.add("esx.$vcenter_name.$vcenter_standalone_host_dc_name.$vcenter_standalone_host_name.runtime.vm.dead", $vcenter_standalone_host_hosts_vms_dead)

            $vcenter_standalone_host_h.add("esx.$vcenter_name.$vcenter_standalone_host_dc_name.$vcenter_standalone_host_name.quickstats.mem.ballooned", $StandaloneResourcePoolBalloonedMemory)
            $vcenter_standalone_host_h.add("esx.$vcenter_name.$vcenter_standalone_host_dc_name.$vcenter_standalone_host_name.quickstats.mem.compressed", $StandaloneResourcePoolCompressedMemory)
            $vcenter_standalone_host_h.add("esx.$vcenter_name.$vcenter_standalone_host_dc_name.$vcenter_standalone_host_name.quickstats.mem.consumedOverhead", $StandaloneResourcePoolConsumedOverheadMemory)
            $vcenter_standalone_host_h.add("esx.$vcenter_name.$vcenter_standalone_host_dc_name.$vcenter_standalone_host_name.quickstats.mem.guest", $StandaloneResourcePoolGuestMemoryUsage)
            $vcenter_standalone_host_h.add("esx.$vcenter_name.$vcenter_standalone_host_dc_name.$vcenter_standalone_host_name.quickstats.mem.private", $StandaloneResourcePoolPrivateMemory)
            $vcenter_standalone_host_h.add("esx.$vcenter_name.$vcenter_standalone_host_dc_name.$vcenter_standalone_host_name.quickstats.mem.shared", $StandaloneResourcePoolSharedMemory)
            $vcenter_standalone_host_h.add("esx.$vcenter_name.$vcenter_standalone_host_dc_name.$vcenter_standalone_host_name.quickstats.mem.swapped", $StandaloneResourcePoolSwappedMemory)

            Send-BulkGraphiteMetrics -CarbonServer 127.0.0.1 -CarbonServerPort 2003 -Metrics $vcenter_standalone_host_h -DateTime $ExecStart
        }
    }

    if ($SessionManager) {
        Write-Host "$((Get-Date).ToString("o")) [INFO] Processing vCenter $vcenter_name SessionList"
        $vcenter_session_list_h = @{}
        $SessionList = $SessionManager.sessionList
        if ($SessionList) {
            foreach ($vcenter_session in $SessionList) {
                $vcenter_session_list_h["vi.$vcenter_name.vi.exec.sessionList.$(NameCleaner $vcenter_session.UserName)"] ++
            }
            $vcenter_session_list_h["vi.$vcenter_name.vi.exec.sessionCount"] = $($SessionList|Measure-Object).Count
    
            Send-BulkGraphiteMetrics -CarbonServer 127.0.0.1 -CarbonServerPort 2003 -Metrics $vcenter_session_list_h -DateTime $ExecStart
        }
    }

    Write-Host "$((Get-Date).ToString("o")) [INFO] Processing vCenter $vcenter_name events"

    $vcenter_events_h = @{}
    $vCenterFilteredEventTypeId = [System.Collections.ArrayList]@()
    $vCenterFilteredEventTypeIdCat = [System.Collections.ArrayList]@()

    if ($EventManager.LatestEvent.Key -gt 0) {
        # https://github.com/lamw/vghetto-scripts/blob/master/perl/provisionedVMReport.pl

        foreach ($vCenterEventInfo in $EventManager.Description.EventInfo) {
            try {
                if ($vCenterEventInfo.Key -match "EventEx|ExtendedEvent" -and $vCenterEventInfo.fullFormat.split("|")[0] -notmatch "nonviworkload|io\.latency|^esx\.audit\.net\.firewall\.config\.changed") {
                    if ($vCenterEventInfo.fullFormat.split("|")[0] -match "^esx\.|^com\.vmware\.vc\.ha\.|^com\.vmware\.vc\.HA\.|^vprob\.|^com\.vmware\.vsan\.|^com\.vmware\.vc\.vsan\.|^vob\.hbr\.|^com\.vmware\.vcHms\.|^com\.vmware\.vc\.HardwareSensorEvent") {
                        $null = $vCenterFilteredEventTypeId.add($vCenterEventInfo.fullFormat.split("|")[0])
                    } elseif ($vCenterEventInfo.fullFormat.split("|")[0] -match "^com\.vmware\.vc\." -and $vCenterEventInfo.category -match "warning|error") {
                        $null = $vCenterFilteredEventTypeIdCat.add($vCenterEventInfo.fullFormat.split("|")[0])
                    }
                } elseif ($vCenterEventInfo.category -match "warning|error" -and $vCenterEventInfo.longDescription -match "vim\.event\.") {
                    $null = $vCenterFilteredEventTypeIdCat.add($vCenterEventInfo.key)
                }
            } catch {
                Write-Host "$((Get-Date).ToString("o")) [EROR] vCenter $vcenter_name EventInfo collect issue"
                Write-Host "$((Get-Date).ToString("o")) [EROR] $($Error[0])"
            }
        }

        if ($vCenterFilteredEventTypeId -or $vCenterFilteredEventTypeIdCat) {

            try {
                $vCenterEventFilterSpecByTime =  New-Object VMware.Vim.EventFilterSpecByTime -property @{BeginTime=$ServiceInstanceServerClock_5;EndTime=$ServiceInstanceServerClock}
                $vCenterEventFilterSpec =  New-Object VMware.Vim.EventFilterSpec -property @{Time=$vCenterEventFilterSpecByTime;EventTypeId=$vCenterFilteredEventTypeId}
                $vCenterEventFilterSpecCat =  New-Object VMware.Vim.EventFilterSpec -property @{Time=$vCenterEventFilterSpecByTime;EventTypeId=$vCenterFilteredEventTypeIdCat;category=@("warning","error")}
    
                $vCenterEventsHistoryCollector = $EventManager.QueryEvents($vCenterEventFilterSpec)
                $vCenterEventsHistoryCollectorCat = $EventManager.QueryEvents($vCenterEventFilterSpecCat)
            } catch {
                Write-Host "$((Get-Date).ToString("o")) [EROR] vCenter $vcenter_name EventManager QueryEvents issue"
                Write-Host "$((Get-Date).ToString("o")) [EROR] $($Error[0])"
            }

            if ($vCenterEventsHistoryCollector -or $vCenterEventsHistoryCollectorCat) {
                foreach ($vCenterEventHistoryCollectorEx in $($vCenterEventsHistoryCollector + $vCenterEventsHistoryCollectorCat)) {
                    if ($vCenterEventHistoryCollectorEx.EventTypeId -and $vCenterEventHistoryCollectorEx.Datacenter -and $vCenterEventHistoryCollectorEx.ComputeResource) {
                        $vCenterEventHistoryCollectorExDc = $(NameCleaner $vCenterEventHistoryCollectorEx.Datacenter.Name)
                        $vCenterEventHistoryCollectorExComp = $(NameCleaner $vCenterEventHistoryCollectorEx.ComputeResource.Name)
                        $vCenterEventHistoryCollectorExType = $vCenterEventHistoryCollectorEx.EventTypeId.Replace(".","_")
                        $vcenter_events_h["vi.$vcenter_name.vi.exec.ExEvent.$vCenterEventHistoryCollectorExDc.$vCenterEventHistoryCollectorExComp.$vCenterEventHistoryCollectorExType"] ++
                    } elseif ($vCenterEventHistoryCollectorEx.MessageInfo -and $vCenterEventHistoryCollectorEx.Datacenter -and $vCenterEventHistoryCollectorEx.ComputeResource) {
                        $vCenterEventHistoryCollectorExDc = $(NameCleaner $vCenterEventHistoryCollectorEx.Datacenter.Name)
                        $vCenterEventHistoryCollectorExComp = $(NameCleaner $vCenterEventHistoryCollectorEx.ComputeResource.Name)
                        $vCenterEventHistoryCollectorExType = $vCenterEventHistoryCollectorEx.MessageInfo[-1].id.Replace(".","_").ToLower()
                        $vcenter_events_h["vi.$vcenter_name.vi.exec.ExEvent.$vCenterEventHistoryCollectorExDc.$vCenterEventHistoryCollectorExComp.$vCenterEventHistoryCollectorExType"] ++
                    } elseif ($vCenterEventHistoryCollectorEx.Datacenter -and $vCenterEventHistoryCollectorEx.ComputeResource) {
                        $vCenterEventHistoryCollectorExDc = $(NameCleaner $vCenterEventHistoryCollectorEx.Datacenter.Name)
                        $vCenterEventHistoryCollectorExComp = $(NameCleaner $vCenterEventHistoryCollectorEx.ComputeResource.Name)
                        $vCenterEventHistoryCollectorExType = $vCenterEventHistoryCollectorEx.pstypenames[0].split(".")[-1]
                        $vcenter_events_h["vi.$vcenter_name.vi.exec.ExEvent.$vCenterEventHistoryCollectorExDc.$vCenterEventHistoryCollectorExComp.$vCenterEventHistoryCollectorExType"] ++
                    } elseif ($vCenterEventHistoryCollectorEx -is [VMware.Vim.DvsHostWentOutOfSyncEvent]) {
                        $vCenterEventHistoryCollectorExDc = $(NameCleaner $vCenterEventHistoryCollectorEx.Datacenter.Name)
                        $vCenterEventHistoryCollectorExComp = $(NameCleaner $vCenterEventHistoryCollectorEx.Dvs.Name)
                        $vCenterEventHistoryCollectorExType = $vCenterEventHistoryCollectorEx.pstypenames[0].split(".")[-1]
                        $vcenter_events_h["vi.$vcenter_name.vi.exec.ExEvent.$vCenterEventHistoryCollectorExDc.$vCenterEventHistoryCollectorExComp.$vCenterEventHistoryCollectorExType"] ++
                    }
                }

                if ($vcenter_events_h) {
                    Send-BulkGraphiteMetrics -CarbonServer 127.0.0.1 -CarbonServerPort 2003 -Metrics $vcenter_events_h -DateTime $ExecStart
                }
            } else {
                Write-Host "$((Get-Date).ToString("o")) [INFO] vCenter $vcenter_name no new event collected"
            }
        } else {
            Write-Host "$((Get-Date).ToString("o")) [EROR] No EventInfo to process in vCenter $vcenter_name"
        }
    }

    $vmware_version_h["vi.$vcenter_name.vi.exec.duration"] = $($(Get-Date).ToUniversalTime() - $ExecStart).TotalSeconds

    Send-BulkGraphiteMetrics -CarbonServer 127.0.0.1 -CarbonServerPort 2003 -Metrics $vmware_version_h -DateTime $ExecStart

    Write-Host "$((Get-Date).ToString("o")) [INFO] End processing vCenter $vcenter_name"
    
} elseif ($ServiceInstance.Content.About.ApiType -match "HostAgent") {

    Write-Host "$((Get-Date).ToString("o")) [INFO] HostAgent detected, collecting unmanaged objects ..."

    $vcenter_name = "_unmanaged_"
    $unmanaged_host_dc_name = "_unmanaged_"
    $esx_name = $($Server.ToLower()) -replace "[. ]","_"
    $unmanaged_host_h = @{}
    $vmware_version_h = @{}

    try {
        $vcenter_resource_pools = Get-View -ViewType ResourcePool -Property Vm, Parent, Owner, summary.quickStats -Server $Server
        $vcenter_clusters = Get-View -ViewType ComputeResource -Property name, parent, summary, resourcePool, host, datastore -Server $Server
        $vcenter_vmhosts = Get-View -ViewType HostSystem -Property config.network.pnic, config.network.vnic, config.network.dnsConfig.hostName, runtime.connectionState, summary.hardware.numCpuCores, summary.quickStats.distributedCpuFairness, summary.quickStats.distributedMemoryFairness, summary.quickStats.overallCpuUsage, summary.quickStats.overallMemoryUsage, summary.quickStats.uptime, overallStatus, config.storageDevice.hostBusAdapter, vm, name, summary.runtime.healthSystemRuntime.systemHealthInfo.numericSensorInfo, config.product.version, config.product.build, summary.hardware.vendor, summary.hardware.model, summary.hardware.cpuModel, Config.VsanHostConfig.ClusterInfo -filter @{"Runtime.ConnectionState" = "^connected$"} -Server $Server
        $vcenter_datastores = Get-View -ViewType Datastore -Property summary, iormConfiguration.enabled, iormConfiguration.statsCollectionEnabled, host -filter @{"summary.accessible" = "true"} -Server $Server
        $vcenter_vms = Get-View -ViewType VirtualMachine -Property name, runtime.maxCpuUsage, runtime.maxMemoryUsage, summary.quickStats.overallCpuUsage, summary.quickStats.overallCpuDemand, summary.quickStats.hostMemoryUsage, summary.quickStats.guestMemoryUsage, summary.quickStats.balloonedMemory, summary.quickStats.compressedMemory, summary.quickStats.swappedMemory, summary.storage.committed, summary.storage.uncommitted, config.hardware.numCPU, layoutEx.file, snapshot, runtime.host, summary.runtime.connectionState, summary.runtime.powerState, summary.config.numVirtualDisks, summary.quickStats.privateMemory, summary.quickStats.consumedOverheadMemory, summary.quickStats.sharedMemory, config.version, config.guestId, config.tools.toolsVersion -filter @{"Summary.Runtime.ConnectionState" = "^connected$"} -Server $Server       
    } catch {
        AltAndCatchFire "Get-View failure"
    }

    Write-Host "$((Get-Date).ToString("o")) [INFO] Performance metrics collection ..."

    $HostMultiMetrics = @(
        "net.bytesRx.average",
        "net.bytesTx.average",
        "storageAdapter.read.average",
        "storageAdapter.write.average"
        # "power.power.average",
        # "datastore.sizeNormalizedDatastoreLatency.latest",
        # "datastore.numberWriteAveraged.average",
        # "datastore.numberReadAveraged.average"
    )

    try {
        $HostMultiStatsTime = Measure-Command {$HostMultiStats = MultiQueryPerfAll $($vcenter_vmhosts.moref) $HostMultiMetrics}
        Write-Host "$((Get-Date).ToString("o")) [INFO] All hosts multi metrics collected in $($HostMultiStatsTime.TotalSeconds) sec for Unmanaged ESX $esx_name"
    } catch {
        AltAndCatchFire "ESX MultiQueryPerfAll failure"
    }

    $VmMultiMetrics = @(
        "cpu.ready.summation",
		"cpu.wait.summation",
		"cpu.idle.summation",
		"cpu.latency.average",
		"disk.maxTotalLatency.latest",
		"virtualdisk.write.average",
		"virtualdisk.read.average",
        "net.usage.average"
    )

    $VmMultiMetricsAll = @(
        "virtualdisk.numberWriteAveraged.average",
        "virtualdisk.numberReadAveraged.average"
    )

    if ($vcenter_vms) {
        try {
            $VmMultiStatsTime = Measure-Command {$VmMultiStats = MultiQueryPerf $($vcenter_vms.moref) $VmMultiMetrics}
            Write-Host "$((Get-Date).ToString("o")) [INFO] All vms multi metrics collected in $($VmMultiStatsTime.TotalSeconds) sec for Unmanaged ESX $esx_name"
        } catch {
            AltAndCatchFire "VM MultiQueryPerf failure"
        }

        try {
            $VmMultiStatsTime = Measure-Command {$VmMultiStats += MultiQueryPerfAll $($vcenter_vms.moref) $VmMultiMetricsAll}
            Write-Host "$((Get-Date).ToString("o")) [INFO] All vms multi metrics instanced collected in $($VmMultiStatsTime.TotalSeconds) sec for vCenter $vcenter_name"
        } catch {
            AltAndCatchFire "VM MultiQueryPerfAll failure"
        }
    }

    try {
        $unmanaged_host = $vcenter_vmhosts
        $unmanaged_compute_resource = $vcenter_clusters
        # $unmanaged_pool = $vcenter_resource_pools|?{$_.moref.value -match "ha-root-pool"}
        $unmanaged_host_name = $unmanaged_host.config.network.dnsConfig.hostName.ToLower() ### why not $unmanaged_host.name.split(".")[0].ToLower() ? because could be ip !!!
        if ($unmanaged_host_name -match "localhost") {
            $unmanaged_host_name = NameCleaner $unmanaged_host.name ### previously vmk0 ip cleaned

        }
        Write-Host "$((Get-Date).ToString("o")) [INFO] Processing Unmanaged ESX $esx_name"
    } catch {
        AltAndCatchFire "Unmanaged ESX name cleaning issue"
    }

    if ($unmanaged_host.config.product.version -and $unmanaged_host.config.product.build -and $unmanaged_host.summary.hardware.cpuModel) {
        $unmanaged_host_product_version = nameCleaner $($unmanaged_host.config.product.version + "_" + $unmanaged_host.config.product.build)
        $unmanaged_host_hw_model = nameCleaner $($unmanaged_host.summary.hardware.vendor + "_" + $unmanaged_host.summary.hardware.model)
        $unmanaged_host_cpu_model = nameCleaner $unmanaged_host.summary.hardware.cpuModel

        $vmware_version_h["vi.$esx_name.vi.version.esx.$unmanaged_host_dc_name.$unmanaged_host_name.build.$unmanaged_host_product_version"] ++
        $vmware_version_h["vi.$esx_name.vi.version.esx.$unmanaged_host_dc_name.$unmanaged_host_name.hardware.$unmanaged_host_hw_model"] ++
        $vmware_version_h["vi.$esx_name.vi.version.esx.$unmanaged_host_dc_name.$unmanaged_host_name.cpu.$unmanaged_host_cpu_model"] ++
    }

    try {
        $unmanaged_host_sensors = $unmanaged_host.summary.runtime.healthSystemRuntime.systemHealthInfo.numericSensorInfo
        # https://vdc-download.vmware.com/vmwb-repository/dcr-public/b50dcbbf-051d-4204-a3e7-e1b618c1e384/538cf2ec-b34f-4bae-a332-3820ef9e7773/vim.host.NumericSensorInfo.html
        foreach ($unmanaged_host_sensor in $unmanaged_host_sensors) {
            if ($unmanaged_host_sensor.name -and $unmanaged_host_sensor.sensorType -and $unmanaged_host_sensor.currentReading -and $unmanaged_host_sensor.unitModifier) {

                $unmanaged_host_sensor_computed_reading = $unmanaged_host_sensor.currentReading * $([Math]::Pow(10, $unmanaged_host_sensor.unitModifier))
                $unmanaged_host_sensor_name = NameCleaner $unmanaged_host_sensor.name
                $unmanaged_host_sensor_type = $unmanaged_host_sensor.sensorType

                $unmanaged_host_h.add("esx.$vcenter_name.$unmanaged_host_dc_name.$unmanaged_host_name.sensor.$unmanaged_host_sensor_type.$unmanaged_host_sensor_name", $unmanaged_host_sensor_computed_reading)
            }
        }
    } catch {
        Write-Host "$((Get-Date).ToString("o")) [EROR] Unmanaged ESX $esx_name sensors issue"
        Write-Host "$((Get-Date).ToString("o")) [EROR] $($Error[0])"
    }

    if ($unmanaged_host.overallStatus.value__) {
        $unmanaged_host_overallStatus = $unmanaged_host.overallStatus.value__
    } else {
        $unmanaged_host_overallStatus = "0"
    }

    try {
        $unmanaged_host_h.add("esx.$vcenter_name.$unmanaged_host_dc_name.$unmanaged_host_name.quickstats.mem.usage", $unmanaged_host.summary.quickStats.OverallMemoryUsage)
        # $unmanaged_host_h.add("esx.$vcenter_name.$unmanaged_host_dc_name.$unmanaged_host_name.quickstats.cpu.demand", $unmanaged_pool.summary.quickStats.overallCpuDemand)
        $unmanaged_host_h.add("esx.$vcenter_name.$unmanaged_host_dc_name.$unmanaged_host_name.quickstats.cpu.usage", $unmanaged_host.summary.quickStats.overallCpuUsage)
        $unmanaged_host_h.add("esx.$vcenter_name.$unmanaged_host_dc_name.$unmanaged_host_name.quickstats.mem.effective", $unmanaged_compute_resource.summary.effectiveMemory/1MB) # in bytes for unmanaged but in MB for managed
        $unmanaged_host_h.add("esx.$vcenter_name.$unmanaged_host_dc_name.$unmanaged_host_name.quickstats.mem.total", $unmanaged_compute_resource.summary.totalMemory)
        $unmanaged_host_h.add("esx.$vcenter_name.$unmanaged_host_dc_name.$unmanaged_host_name.quickstats.cpu.effective", $unmanaged_compute_resource.summary.effectiveCpu)
        $unmanaged_host_h.add("esx.$vcenter_name.$unmanaged_host_dc_name.$unmanaged_host_name.quickstats.cpu.total", $unmanaged_compute_resource.summary.totalCpu)
        $unmanaged_host_h.add("esx.$vcenter_name.$unmanaged_host_dc_name.$unmanaged_host_name.quickstats.overallStatus", $unmanaged_host_overallStatus)
    } catch {
        Write-Host "$((Get-Date).ToString("o")) [EROR] Unmanaged ESX $esx_name quickstats issue"
        Write-Host "$((Get-Date).ToString("o")) [EROR] $($Error[0])"
    }

    Write-Host "$((Get-Date).ToString("o")) [INFO] Processing Unmanaged ESX $esx_name datastores"

    foreach ($unmanaged_host_datastore in $vcenter_datastores) {
        if ($unmanaged_host_datastore.summary.accessible) {
            try {
                $unmanaged_host_datastore_name = NameCleaner $unmanaged_host_datastore.summary.name

                if($unmanaged_host_datastore.summary.uncommitted -ge 0) {
                    $unmanaged_host_datastore_uncommitted = $unmanaged_host_datastore.summary.uncommitted
                } else {
                    $unmanaged_host_datastore_uncommitted = 0
                }

                $unmanaged_host_h.add("esx.$vcenter_name.$unmanaged_host_dc_name.$unmanaged_host_name.datastore.$unmanaged_host_datastore_name.summary.capacity", $unmanaged_host_datastore.summary.capacity)
                $unmanaged_host_h.add("esx.$vcenter_name.$unmanaged_host_dc_name.$unmanaged_host_name.datastore.$unmanaged_host_datastore_name.summary.freeSpace", $unmanaged_host_datastore.summary.freeSpace)
                $unmanaged_host_h.add("esx.$vcenter_name.$unmanaged_host_dc_name.$unmanaged_host_name.datastore.$unmanaged_host_datastore_name.summary.uncommitted", $unmanaged_host_datastore_uncommitted)

                # if ($unmanaged_host_datastore.summary.type -notmatch "vsan") {
                #     $unmanaged_host_datastore_uuid = $unmanaged_host_datastore.summary.url.split("/")[-2]

                #     $unmanaged_host_datastore_latency = $HostMultiStats[$PerfCounterTable["datastore.maxTotalLatency.latest"]][$unmanaged_host.moref.value][$unmanaged_host_datastore_uuid]
                #     $unmanaged_host_h.add("esx.$vcenter_name.$unmanaged_host_dc_name.$unmanaged_host_name.datastore.$unmanaged_host_datastore_name.iorm.sizeNormalizedDatastoreLatency", $unmanaged_host_datastore_latency)

                #     $unmanaged_host_datastore_iops_w = $HostMultiStats[$PerfCounterTable["datastore.numberWriteAveraged.average"]][$unmanaged_host.moref.value][$unmanaged_host_datastore_uuid]
                #     $unmanaged_host_datastore_iops_r = $HostMultiStats[$PerfCounterTable["datastore.numberReadAveraged.average"]][$unmanaged_host.moref.value][$unmanaged_host_datastore_uuid]
                #     $unmanaged_host_datastore_iops = $unmanaged_host_datastore_iops_w + $unmanaged_host_datastore_iops_r.Sum
                #     $unmanaged_host_h.add("esx.$vcenter_name.$unmanaged_host_dc_name.$unmanaged_host_name.datastore.$unmanaged_host_datastore_name.iorm.datastoreIops", $unmanaged_host_datastore_iops)
                # }
            } catch {
                Write-Host "$((Get-Date).ToString("o")) [EROR] datastore processing issue on Unmanaged ESX $esx_name"
                Write-Host "$((Get-Date).ToString("o")) [EROR] $($Error[0])"
            }
        }
    }

    try {
        foreach ($unmanaged_host_vmnic in $unmanaged_host.config.network.pnic) {
            if ($unmanaged_host_vmnic.linkSpeed -and $unmanaged_host_vmnic.linkSpeed.speedMb -ge 100) {
                $unmanaged_host_vmnic_name = $unmanaged_host_vmnic.device

                $unmanaged_host_vmnic_bytesRx = $HostMultiStats[$PerfCounterTable["net.bytesRx.average"]][$unmanaged_host.moref.value][$unmanaged_host_vmnic_name]
                $unmanaged_host_vmnic_bytesTx = $HostMultiStats[$PerfCounterTable["net.bytesTx.average"]][$unmanaged_host.moref.value][$unmanaged_host_vmnic_name]

                if ($unmanaged_host_vmnic_bytesRx -ge 0 -and $unmanaged_host_vmnic_bytesTx -ge 0) {
                    $unmanaged_host_h.add("esx.$vcenter_name.$unmanaged_host_dc_name.$unmanaged_host_name.net.$unmanaged_host_vmnic_name.bytesRx", $unmanaged_host_vmnic_bytesRx)
                    $unmanaged_host_h.add("esx.$vcenter_name.$unmanaged_host_dc_name.$unmanaged_host_name.net.$unmanaged_host_vmnic_name.bytesTx", $unmanaged_host_vmnic_bytesTx)
                }
            }
        }
    } catch {
        Write-Host "$((Get-Date).ToString("o")) [EROR] Unmanaged ESX $esx_name network metrics issue"
        Write-Host "$((Get-Date).ToString("o")) [EROR] $($Error[0])"
    }

    try {
        foreach ($unmanaged_host_vmhba in $unmanaged_host.config.storageDevice.hostBusAdapter) {
            $unmanaged_host_vmhba_name = $unmanaged_host_vmhba.device
            $unmanaged_host_vmhba_bytesRead = $HostMultiStats[$PerfCounterTable["storageAdapter.read.average"]][$unmanaged_host.moref.value][$unmanaged_host_vmhba_name]
            $unmanaged_host_vmhba_bytesWrite = $HostMultiStats[$PerfCounterTable["storageAdapter.write.average"]][$unmanaged_host.moref.value][$unmanaged_host_vmhba_name]
        
            if ($unmanaged_host_vmhba_bytesRead -ge 0 -and $unmanaged_host_vmhba_bytesWrite -ge 0) {

                $unmanaged_host_h.add("esx.$vcenter_name.$unmanaged_host_dc_name.$unmanaged_host_name.hba.$unmanaged_host_vmhba_name.bytesRead", $unmanaged_host_vmhba_bytesRead)
                $unmanaged_host_h.add("esx.$vcenter_name.$unmanaged_host_dc_name.$unmanaged_host_name.hba.$unmanaged_host_vmhba_name.bytesWrite", $unmanaged_host_vmhba_bytesWrite)
            }
        }
    } catch {
        Write-Host "$((Get-Date).ToString("o")) [EROR] Unmanaged ESX $esx_name hba metrics issue"
        Write-Host "$((Get-Date).ToString("o")) [EROR] $($Error[0])"
    }

    $UnamagedResourcePoolPrivateMemory = 0
    $UnamagedResourcePoolSharedMemory = 0
    $UnamagedResourcePoolBalloonedMemory = 0
    $UnamagedResourcePoolCompressedMemory = 0
    $UnamagedResourcePoolSwappedMemory = 0
    $UnamagedResourcePoolGuestMemoryUsage = 0
    $UnamagedResourcePoolConsumedOverheadMemory = 0

    $unmanaged_host_vms_vcpus = 0
    $unmanaged_host_vms_vram = 0
    $unmanaged_host_vms_files_dedup = @{}
    $unmanaged_host_vms_files_dedup_total = @{}
    $unmanaged_host_vms_files_snaps = 0
    $unmanaged_host_vms_snaps = 0
    $unmanaged_host_vms_off = 0
    $unmanaged_host_vms_on = 0
    $unmanaged_host_vms_dead = 0
    $unmanaged_host_vmdk_per_ds = @{}

    if ($unmanaged_host.vm) {

        $unmanaged_host_real_vms_count = $($unmanaged_host.vm|Measure-Object).Count
        $unmanaged_host_connected_vms_count = $($vcenter_vms|Measure-Object).Count
        if ($unmanaged_host_real_vms_count -gt $unmanaged_host_connected_vms_count) {
            $unmanaged_host_vms_dead += $unmanaged_host_real_vms_count - $unmanaged_host_connected_vms_count
        }

        foreach ($unmanaged_host_vm in $vcenter_vms) {

            if ($unmanaged_host_vm.config.version) {
                $unmanaged_host_vm_vhw = NameCleaner $unmanaged_host_vm.config.version
                $vmware_version_h["vi.$vcenter_name.vi.version.vm.$unmanaged_host_dc_name.$unmanaged_host_name.vhw.$unmanaged_host_vm_vhw"] ++
            }

            if ($unmanaged_host_vm.config.guestId) {
                $unmanaged_host_vm_guestId = NameCleaner $unmanaged_host_vm.config.guestId
                $vmware_version_h["vi.$vcenter_name.vi.version.vm.$unmanaged_host_dc_name.$unmanaged_host_name.guest.$unmanaged_host_vm_guestId"] ++
            }

            if ($unmanaged_host_vm.config.tools.toolsVersion) {
                $unmanaged_host_vm_vmtools = NameCleaner $unmanaged_host_vm.config.tools.toolsVersion
                $vmware_version_h["vi.$vcenter_name.vi.version.vm.$unmanaged_host_dc_name.$unmanaged_host_name.vmtools.$unmanaged_host_vm_vmtools"] ++
            }

            $unmanaged_host_vm_name = NameCleaner $unmanaged_host_vm.Name

            try {
                $unmanaged_host_vm_files = $unmanaged_host_vm.layoutEx.file
                ### http://pubs.vmware.com/vsphere-60/topic/com.vmware.wSsdk.apiref.doc/vim.vm.FileLayoutEx.FileType.html

                $unmanaged_host_vm_snap_size = 0

                if ($unmanaged_host_vm.snapshot) {
                    $unmanaged_host_vm_has_snap = 1
                    $unmanaged_host_vms_snaps ++
                } else {
                    $unmanaged_host_vm_has_snap = 0
                }

                $unmanaged_host_vm_num_vdisk = $unmanaged_host_vm.summary.config.numVirtualDisks
                $unmanaged_host_vm_real_vdisk = 0
                $unmanaged_host_vm_has_diskExtent = 0

                foreach ($unmanaged_host_vm_file in $unmanaged_host_vm_files) {
                    if ($unmanaged_host_vm_file.type -eq "diskDescriptor") {
                        $unmanaged_host_vm_real_vdisk ++
                        $unmanaged_host_vm_file_ds_name = nameCleaner $([regex]::match($unmanaged_host_vm_file.name, '^\[(.*)\]').Groups[1].value)
                        $unmanaged_host_vmdk_per_ds[$unmanaged_host_vm_file_ds_name] ++
                    } elseif ($unmanaged_host_vm_file.type -eq "diskExtent") {
                        $unmanaged_host_vm_has_diskExtent ++
                    }
                }

                if ($unmanaged_host_vm_real_vdisk -gt $unmanaged_host_vm_num_vdisk) {
                    $unmanaged_host_vm_has_snap = 1
                }

                foreach ($unmanaged_host_vm_file in $unmanaged_host_vm_files) {
                    if(!$unmanaged_host_vms_files_dedup[$unmanaged_host_vm_file.name]) { ### TODO would need name & moref
                        $unmanaged_host_vms_files_dedup[$unmanaged_host_vm_file.name] = $unmanaged_host_vm_file.size
                        if ($unmanaged_host_vm_has_snap -and (($unmanaged_host_vm_file.name -match '-[0-9]{6}-delta\.vmdk') -or ($unmanaged_host_vm_file.name -match '-[0-9]{6}-sesparse\.vmdk'))) {
                            $unmanaged_host_vms_files_dedup_total["snapshotExtent"] += $unmanaged_host_vm_file.size
                            $unmanaged_host_vm_snap_size += $unmanaged_host_vm_file.size
                        } elseif ($unmanaged_host_vm_has_snap -and ($unmanaged_host_vm_file.name -match '-[0-9]{6}\.vmdk')) {
                            $unmanaged_host_vms_files_dedup_total["snapshotDescriptor"] += $unmanaged_host_vm_file.size
                            $unmanaged_host_vm_snap_size += $unmanaged_host_vm_file.size
                            $unmanaged_host_vms_files_snaps ++
                        } elseif ($unmanaged_host_vm_file.name -match '-rdm\.vmdk') {
                            $unmanaged_host_vms_files_dedup_total["rdmExtent"] += $unmanaged_host_vm_file.size
                        } elseif ($unmanaged_host_vm_file.name -match '-rdmp\.vmdk') {
                            $unmanaged_host_vms_files_dedup_total["rdmpExtent"] += $unmanaged_host_vm_file.size
                        } elseif ((!$unmanaged_host_vm_has_diskExtent) -and $unmanaged_host_vm_file.type -eq "diskDescriptor") {
                            $unmanaged_host_vms_files_dedup_total["virtualExtent"] += $unmanaged_host_vm_file.size
                        } else {
                            $unmanaged_host_vms_files_dedup_total[$unmanaged_host_vm_file.type] += $unmanaged_host_vm_file.size
                        }
                    }
                }

                if ($unmanaged_host_vm_snap_size -gt 0) {
                    $unmanaged_host_h.add("esx.$vcenter_name.$unmanaged_host_dc_name.$unmanaged_host_name.vm.$unmanaged_host_vm_name.storage.delta", $unmanaged_host_vm_snap_size)
                }
            } catch {
                Write-Host "$((Get-Date).ToString("o")) [EROR] VM $unmanaged_host_vm_name snapshot compute issue standalone host $unmanaged_host_name"
                Write-Host "$((Get-Date).ToString("o")) [EROR] $($Error[0])"
            }

            try {
                $unmanaged_host_h.add("esx.$vcenter_name.$unmanaged_host_dc_name.$unmanaged_host_name.vm.$unmanaged_host_vm_name.storage.committed", $unmanaged_host_vm.summary.storage.committed)
                $unmanaged_host_h.add("esx.$vcenter_name.$unmanaged_host_dc_name.$unmanaged_host_name.vm.$unmanaged_host_vm_name.storage.uncommitted", $unmanaged_host_vm.summary.storage.uncommitted)
            } catch {
                Write-Host "$((Get-Date).ToString("o")) [EROR] VM $unmanaged_host_vm_name storage commit metric issue standalone host $unmanaged_host_name"
                Write-Host "$((Get-Date).ToString("o")) [EROR] $($Error[0])"
            }

            if ($unmanaged_host_vm.summary.runtime.powerState -eq "poweredOn") {
                try {
                    $unmanaged_host_vms_on ++

                    $unmanaged_host_vms_vcpus += $unmanaged_host_vm.config.hardware.numCPU
                    $unmanaged_host_vms_vram += $unmanaged_host_vm.runtime.maxMemoryUsage


                    if ($unmanaged_host_vm.runtime.maxCpuUsage -gt 0 -and $unmanaged_host_vm.summary.quickStats.overallCpuUsage) {
                        $unmanaged_host_vm_CpuUtilization = $unmanaged_host_vm.summary.quickStats.overallCpuUsage * 100 / $unmanaged_host_vm.runtime.maxCpuUsage
                        $unmanaged_host_h.add("esx.$vcenter_name.$unmanaged_host_dc_name.$unmanaged_host_name.vm.$unmanaged_host_vm_name.runtime.CpuUtilization", $unmanaged_host_vm_CpuUtilization)
                    }

                    if ($unmanaged_host_vm.summary.quickStats.guestMemoryUsage -gt 0 -and $unmanaged_host_vm.runtime.maxMemoryUsage) {
                        $unmanaged_host_vm_MemUtilization = $unmanaged_host_vm.summary.quickStats.guestMemoryUsage * 100 / $unmanaged_host_vm.runtime.maxMemoryUsage
                        $unmanaged_host_h.add("esx.$vcenter_name.$unmanaged_host_dc_name.$unmanaged_host_name.vm.$unmanaged_host_vm_name.runtime.MemUtilization", $unmanaged_host_vm_MemUtilization)
                    }

                    $unmanaged_host_h.add("esx.$vcenter_name.$unmanaged_host_dc_name.$unmanaged_host_name.vm.$unmanaged_host_vm_name.quickstats.overallCpuUsage", $unmanaged_host_vm.summary.quickStats.overallCpuUsage)
                    $unmanaged_host_h.add("esx.$vcenter_name.$unmanaged_host_dc_name.$unmanaged_host_name.vm.$unmanaged_host_vm_name.quickstats.overallCpuDemand", $unmanaged_host_vm.summary.quickStats.overallCpuDemand)
                    $unmanaged_host_h.add("esx.$vcenter_name.$unmanaged_host_dc_name.$unmanaged_host_name.vm.$unmanaged_host_vm_name.quickstats.HostMemoryUsage", $unmanaged_host_vm.summary.quickStats.hostMemoryUsage)
                    $unmanaged_host_h.add("esx.$vcenter_name.$unmanaged_host_dc_name.$unmanaged_host_name.vm.$unmanaged_host_vm_name.quickstats.GuestMemoryUsage", $unmanaged_host_vm.summary.quickStats.guestMemoryUsage)

                    if ($unmanaged_host_vm.summary.quickStats.balloonedMemory -gt 0) {
                        $unmanaged_host_h.add("esx.$vcenter_name.$unmanaged_host_dc_name.$unmanaged_host_name.vm.$unmanaged_host_vm_name.quickstats.BalloonedMemory", $unmanaged_host_vm.summary.quickStats.balloonedMemory)
                        $UnamagedResourcePoolBalloonedMemory += $unmanaged_host_vm.summary.quickStats.balloonedMemory
                    }

                    if ($unmanaged_host_vm.summary.quickStats.compressedMemory -gt 0) {
                        $unmanaged_host_h.add("esx.$vcenter_name.$unmanaged_host_dc_name.$unmanaged_host_name.vm.$unmanaged_host_vm_name.quickstats.CompressedMemory", $unmanaged_host_vm.summary.quickStats.compressedMemory)
                        $UnamagedResourcePoolCompressedMemory += $unmanaged_host_vm.summary.quickStats.compressedMemory
                    }

                    if ($unmanaged_host_vm.summary.quickStats.swappedMemory -gt 0) {
                        $unmanaged_host_h.add("esx.$vcenter_name.$unmanaged_host_dc_name.$unmanaged_host_name.vm.$unmanaged_host_vm_name.quickstats.SwappedMemory", $unmanaged_host_vm.summary.quickStats.swappedMemory)
                        $UnamagedResourcePoolSwappedMemory += $unmanaged_host_vm.summary.quickStats.swappedMemory
                    }

                    if ($VmMultiStats[$PerfCounterTable["cpu.ready.summation"]][$unmanaged_host_vm.moref.value][""]) {
                        $unmanaged_host_vm_ready = $VmMultiStats[$PerfCounterTable["cpu.ready.summation"]][$unmanaged_host_vm.moref.value][""] / $unmanaged_host_vm.config.hardware.numCPU / 20000 * 100 
                        ### https://kb.vmware.com/kb/2002181
                        $unmanaged_host_h.add("esx.$vcenter_name.$unmanaged_host_dc_name.$unmanaged_host_name.vm.$unmanaged_host_vm_name.fatstats.cpu_ready_summation", $unmanaged_host_vm_ready)
                    }

                    if ($VmMultiStats[$PerfCounterTable["cpu.wait.summation"]][$unmanaged_host_vm.moref.value][""] -and $VmMultiStats[$PerfCounterTable["cpu.idle.summation"]][$unmanaged_host_vm.moref.value][""]) {
                        $unmanaged_host_vm_io_wait = ($VmMultiStats[$PerfCounterTable["cpu.wait.summation"]][$unmanaged_host_vm.moref.value][""] - $VmMultiStats[$PerfCounterTable["cpu.idle.summation"]][$unmanaged_host_vm.moref.value][""]) / $unmanaged_host_vm.config.hardware.numCPU / 20000 * 100 
                        ### https://code.vmware.com/apis/358/vsphere#/doc/cpu_counters.html
                        ### "Total CPU time spent in wait state.The wait total includes time spent the CPU Idle, CPU Swap Wait, and CPU I/O Wait states."
                        # https://kb.vmware.com/s/article/85393
                        $unmanaged_host_h.add("esx.$vcenter_name.$unmanaged_host_dc_name.$unmanaged_host_name.vm.$unmanaged_host_vm_name.fatstats.cpu_wait_no_idle", $unmanaged_host_vm_io_wait)
                    }

                    if ($VmMultiStats[$PerfCounterTable["cpu.latency.average"]][$unmanaged_host_vm.moref.value][""]) {
                        $unmanaged_host_vm_cpu_latency = $VmMultiStats[$PerfCounterTable["cpu.latency.average"]][$unmanaged_host_vm.moref.value][""]
                        $unmanaged_host_h.add("esx.$vcenter_name.$unmanaged_host_dc_name.$unmanaged_host_name.vm.$unmanaged_host_vm_name.fatstats.cpu_latency_average", $unmanaged_host_vm_cpu_latency)
                    }

                    if ($VmMultiStats[$PerfCounterTable["disk.maxTotalLatency.latest"]][$unmanaged_host_vm.moref.value][""]) {
                        $unmanaged_host_vm_disk_latency = $VmMultiStats[$PerfCounterTable["disk.maxTotalLatency.latest"]][$unmanaged_host_vm.moref.value][""]
                        $unmanaged_host_h.add("esx.$vcenter_name.$unmanaged_host_dc_name.$unmanaged_host_name.vm.$unmanaged_host_vm_name.fatstats.maxTotalLatency", $unmanaged_host_vm_disk_latency)
                    }

                    if ($VmMultiStats[$PerfCounterTable["virtualdisk.write.average"]][$unmanaged_host_vm.moref.value][""] -ge 0 -and $VmMultiStats[$PerfCounterTable["virtualdisk.read.average"]][$unmanaged_host_vm.moref.value][""] -ge 0) {
                        $unmanaged_host_vm_disk_usage = $VmMultiStats[$PerfCounterTable["virtualdisk.write.average"]][$unmanaged_host_vm.moref.value][""] + $VmMultiStats[$PerfCounterTable["virtualdisk.read.average"]][$unmanaged_host_vm.moref.value][""]
                        $unmanaged_host_h.add("esx.$vcenter_name.$unmanaged_host_dc_name.$unmanaged_host_name.vm.$unmanaged_host_vm_name.fatstats.diskUsage", $unmanaged_host_vm_disk_usage)
                    } else {
                        $unmanaged_host_h.add("esx.$vcenter_name.$unmanaged_host_dc_name.$unmanaged_host_name.vm.$unmanaged_host_vm_name.fatstats.diskUsage", 0)
                    }

                    if ($VmMultiStats[$PerfCounterTable["virtualdisk.numberWriteAveraged.average"]][$unmanaged_host_vm.moref.value] -and $VmMultiStats[$PerfCounterTable["virtualdisk.numberReadAveraged.average"]][$unmanaged_host_vm.moref.value]) {
                        $unmanaged_host_vm_disk_iops = $($VmMultiStats[$PerfCounterTable["virtualdisk.numberWriteAveraged.average"]][$unmanaged_host_vm.moref.value][$($VmMultiStats[$PerfCounterTable["virtualdisk.numberWriteAveraged.average"]][$unmanaged_host_vm.moref.value]).Keys]|Measure-Object -Sum).Sum + $($VmMultiStats[$PerfCounterTable["virtualdisk.numberReadAveraged.average"]][$unmanaged_host_vm.moref.value][$($VmMultiStats[$PerfCounterTable["virtualdisk.numberWriteAveraged.average"]][$unmanaged_host_vm.moref.value]).Keys]|Measure-Object -Sum).Sum
                        $unmanaged_host_h.add("esx.$vcenter_name.$unmanaged_host_dc_name.$unmanaged_host_name.vm.$unmanaged_host_vm_name.fatstats.diskIOPS", $unmanaged_host_vm_disk_iops)
                    }

                    # if ($VmMultiStats[$PerfCounterTable["net.packetsTx.summation"]][$unmanaged_host_vm.moref.value] -and $VmMultiStats[$PerfCounterTable["net.packetsRx.summation"]][$unmanaged_host_vm.moref.value]) {
                    #     $unmanaged_host_vm_net_iops = $($($VmMultiStats[$PerfCounterTable["net.packetsTx.summation"]][$unmanaged_host_vm.moref.value][$($VmMultiStats[$PerfCounterTable["net.packetsTx.summation"]][$unmanaged_host_vm.moref.value]).Keys]|Measure-Object -Sum).Sum + $($VmMultiStats[$PerfCounterTable["net.packetsRx.summation"]][$unmanaged_host_vm.moref.value][$($VmMultiStats[$PerfCounterTable["net.packetsTx.summation"]][$unmanaged_host_vm.moref.value]).Keys]|Measure-Object -Sum).Sum) / 300
                    #     $unmanaged_host_h.add("esx.$vcenter_name.$unmanaged_host_dc_name.$unmanaged_host_name.vm.$unmanaged_host_vm_name.fatstats.netIOPS", $unmanaged_host_vm_net_iops)
                    # }

                    if ($VmMultiStats[$PerfCounterTable["net.usage.average"]][$unmanaged_host_vm.moref.value][""]) {
                        $unmanaged_host_vm_net_usage = $VmMultiStats[$PerfCounterTable["net.usage.average"]][$unmanaged_host_vm.moref.value][""]
                        $unmanaged_host_h.add("esx.$vcenter_name.$unmanaged_host_dc_name.$unmanaged_host_name.vm.$unmanaged_host_vm_name.fatstats.netUsage", $unmanaged_host_vm_net_usage)
                    } else {
                        $unmanaged_host_h.add("esx.$vcenter_name.$unmanaged_host_dc_name.$unmanaged_host_name.vm.$unmanaged_host_vm_name.fatstats.netUsage", 0)
                    }
                    
                    if ($unmanaged_host_vm.summary.quickStats.privateMemory -gt 0) {$UnamagedResourcePoolPrivateMemory += $unmanaged_host_vm.summary.quickStats.privateMemory}
                    if ($unmanaged_host_vm.summary.quickStats.GuestMemoryUsage -gt 0) {$UnamagedResourcePoolGuestMemoryUsage += $unmanaged_host_vm.summary.quickStats.GuestMemoryUsage}
                    if ($unmanaged_host_vm.summary.quickStats.SharedMemory -gt 0) {$UnamagedResourcePoolSharedMemory += $unmanaged_host_vm.summary.quickStats.SharedMemory}
                    if ($unmanaged_host_vm.summary.quickStats.ConsumedOverheadMemory -gt 0) {$UnamagedResourcePoolConsumedOverheadMemory += $unmanaged_host_vm.summary.quickStats.ConsumedOverheadMemory}
                
                } catch {
                    Write-Host "$((Get-Date).ToString("o")) [EROR] VM $unmanaged_host_vm_name metric issue on unmanaged host $unmanaged_host_name"
                    Write-Host "$((Get-Date).ToString("o")) [EROR] $($Error[0])"  
                }

            } elseif ($unmanaged_host_vm.summary.runtime.powerState -eq "poweredOff") {
                $unmanaged_host_vms_off ++
            }
        }
    }

    try {
        $unmanaged_host_h.add("esx.$vcenter_name.$unmanaged_host_dc_name.$unmanaged_host_name.quickstats.mem.ballooned", $UnamagedResourcePoolBalloonedMemory)
        $unmanaged_host_h.add("esx.$vcenter_name.$unmanaged_host_dc_name.$unmanaged_host_name.quickstats.mem.compressed", $UnamagedResourcePoolCompressedMemory)
        $unmanaged_host_h.add("esx.$vcenter_name.$unmanaged_host_dc_name.$unmanaged_host_name.quickstats.mem.consumedOverhead", $UnamagedResourcePoolConsumedOverheadMemory)
        $unmanaged_host_h.add("esx.$vcenter_name.$unmanaged_host_dc_name.$unmanaged_host_name.quickstats.mem.guest", $UnamagedResourcePoolGuestMemoryUsage)
        $unmanaged_host_h.add("esx.$vcenter_name.$unmanaged_host_dc_name.$unmanaged_host_name.quickstats.mem.private", $UnamagedResourcePoolPrivateMemory)
        $unmanaged_host_h.add("esx.$vcenter_name.$unmanaged_host_dc_name.$unmanaged_host_name.quickstats.mem.shared", $UnamagedResourcePoolSharedMemory)
        $unmanaged_host_h.add("esx.$vcenter_name.$unmanaged_host_dc_name.$unmanaged_host_name.quickstats.mem.swapped", $UnamagedResourcePoolSwappedMemory)
        $unmanaged_host_h.add("esx.$vcenter_name.$unmanaged_host_dc_name.$unmanaged_host_name.runtime.vm.total", $($unmanaged_host_vms_on + $unmanaged_host_vms_off))
        $unmanaged_host_h.add("esx.$vcenter_name.$unmanaged_host_dc_name.$unmanaged_host_name.runtime.vm.on", $unmanaged_host_vms_on)
        $unmanaged_host_h.add("esx.$vcenter_name.$unmanaged_host_dc_name.$unmanaged_host_name.runtime.vm.dead", $unmanaged_host_vms_dead)

    } catch {
        Write-Host "$((Get-Date).ToString("o")) [EROR] Unmanaged ESX $esx_name quickstats issue"
        Write-Host "$((Get-Date).ToString("o")) [EROR] $($Error[0])"
    }

    Send-BulkGraphiteMetrics -CarbonServer 127.0.0.1 -CarbonServerPort 2003 -Metrics $unmanaged_host_h -DateTime $ExecStart

    Write-Host "$((Get-Date).ToString("o")) [INFO] Processing Unmanaged ESX $esx_name events"

    $vcenter_events_h = @{}
    $vCenterFilteredEventTypeId = @()
    $vCenterFilteredEventTypeIdCat = [System.Collections.ArrayList]@()

    if ($EventManager.LatestEvent.Key -gt 0) {

        $vCenterFilteredEventTypeId = Get-Content /opt/sexigraf/vsp801.evt

        foreach ($vCenterEventInfo in $EventManager.Description.EventInfo) {
            try {
                if ($vCenterEventInfo.category -match "warning|error" -and $vCenterEventInfo.longDescription -match "vim\.event\.") {
                    $null = $vCenterFilteredEventTypeIdCat.add($vCenterEventInfo.key)
                }
            } catch {
                Write-Host "$((Get-Date).ToString("o")) [EROR] Unmanaged ESX $esx_name EventInfo collect issue"
                Write-Host "$((Get-Date).ToString("o")) [EROR] $($Error[0])"
            }
        }

        if ($vCenterFilteredEventTypeId -or $vCenterFilteredEventTypeIdCat) {

            try {
                $vCenterEventFilterSpecByTime =  New-Object VMware.Vim.EventFilterSpecByTime -property @{BeginTime=$ServiceInstanceServerClock_5;EndTime=$ServiceInstanceServerClock}
                $vCenterEventFilterSpec =  New-Object VMware.Vim.EventFilterSpec -property @{Time=$vCenterEventFilterSpecByTime;EventTypeId=$vCenterFilteredEventTypeId}
                $vCenterEventFilterSpecCat =  New-Object VMware.Vim.EventFilterSpec -property @{Time=$vCenterEventFilterSpecByTime;EventTypeId=$vCenterFilteredEventTypeIdCat;category=@("warning","error")}
    
                # $vCenterEventsHistoryCollector = $EventManager.QueryEvents($vCenterEventFilterSpec)
                # $vCenterEventsHistoryCollectorCat = $EventManager.QueryEvents($vCenterEventFilterSpecCat)

                $vCenterEventsHistoryCollectorObj = Get-View $EventManager.CreateCollectorForEvents($vCenterEventFilterSpec) -Server $Server
                $vCenterEventsHistoryCollectorCatObj = Get-View $EventManager.CreateCollectorForEvents($vCenterEventFilterSpecCat) -Server $Server

                $vCenterEventsHistoryCollector = $vCenterEventsHistoryCollectorObj.ReadNextEvents("999")
                $vCenterEventsHistoryCollectorCat = $vCenterEventsHistoryCollectorCatObj.ReadNextEvents("999")

            } catch {
                Write-Host "$((Get-Date).ToString("o")) [EROR] Unmanaged ESX $esx_name EventManager QueryEvents issue"
                Write-Host "$((Get-Date).ToString("o")) [EROR] $($Error[0])"
            }

            if ($vCenterEventsHistoryCollector -or $vCenterEventsHistoryCollectorCat) {
                foreach ($vCenterEventHistoryCollectorEx in $($vCenterEventsHistoryCollector + $vCenterEventsHistoryCollectorCat)) {
                    if ($vCenterEventHistoryCollectorEx.EventTypeId -and $vCenterEventHistoryCollectorEx.ComputeResource) {
                        $vCenterEventHistoryCollectorExDc = $unmanaged_host_dc_name
                        $vCenterEventHistoryCollectorExComp = $(NameCleaner $vCenterEventHistoryCollectorEx.ComputeResource.Name)
                        $vCenterEventHistoryCollectorExType = $vCenterEventHistoryCollectorEx.EventTypeId.Replace(".","_")
                        $vcenter_events_h["vi.$vcenter_name.vi.exec.ExEvent.$vCenterEventHistoryCollectorExDc.$vCenterEventHistoryCollectorExComp.$vCenterEventHistoryCollectorExType"] ++
                    } elseif ($vCenterEventHistoryCollectorEx.MessageInfo -and $vCenterEventHistoryCollectorEx.ComputeResource) {
                        $vCenterEventHistoryCollectorExDc = $unmanaged_host_dc_name
                        $vCenterEventHistoryCollectorExComp = $(NameCleaner $vCenterEventHistoryCollectorEx.ComputeResource.Name)
                        $vCenterEventHistoryCollectorExType = $vCenterEventHistoryCollectorEx.MessageInfo[-1].id.Replace(".","_").ToLower()
                        $vcenter_events_h["vi.$vcenter_name.vi.exec.ExEvent.$vCenterEventHistoryCollectorExDc.$vCenterEventHistoryCollectorExComp.$vCenterEventHistoryCollectorExType"] ++
                    } elseif ($vCenterEventHistoryCollectorEx.ComputeResource) {
                        $vCenterEventHistoryCollectorExDc = $unmanaged_host_dc_name
                        $vCenterEventHistoryCollectorExComp = $(NameCleaner $vCenterEventHistoryCollectorEx.ComputeResource.Name)
                        $vCenterEventHistoryCollectorExType = $vCenterEventHistoryCollectorEx.pstypenames[0].split(".")[-1]
                        $vcenter_events_h["vi.$vcenter_name.vi.exec.ExEvent.$vCenterEventHistoryCollectorExDc.$vCenterEventHistoryCollectorExComp.$vCenterEventHistoryCollectorExType"] ++
                    }
                }

                if ($vcenter_events_h) {
                    Send-BulkGraphiteMetrics -CarbonServer 127.0.0.1 -CarbonServerPort 2003 -Metrics $vcenter_events_h -DateTime $ExecStart
                }
            } else {
                Write-Host "$((Get-Date).ToString("o")) [INFO] Unmanaged ESX $esx_name no new event collected"
            }
        } else {
            Write-Host "$((Get-Date).ToString("o")) [EROR] No EventInfo to process in Unmanaged ESX $esx_name"
        }
    }

    $vmware_version_h["vi.$esx_name.vi.exec.duration"] = $($(Get-Date).ToUniversalTime() - $ExecStart).TotalSeconds

    Send-BulkGraphiteMetrics -CarbonServer 127.0.0.1 -CarbonServerPort 2003 -Metrics $vmware_version_h -DateTime $ExecStart

    Write-Host "$((Get-Date).ToString("o")) [INFO] End processing Unmanaged ESX $esx_name"

} else {
    AltAndCatchFire "$Server is not a vCenter/ESXi!"
}