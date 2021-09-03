#!/usr/bin/pwsh -NonInteractive -NoProfile -Command
#
param([Parameter (Mandatory=$true)] [string] $Server, [Parameter (Mandatory=$true)] [string] $SessionFile, [Parameter (Mandatory=$false)] [string] $CredStore)

$ScriptVersion = "0.9.922"

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
# $AltAndCatchFire = $function:AltAndCatchFire.ToString()

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
# $GetRootDc = $function:GetRootDc.ToString()

function NameCleaner {
    Param($NameToClean)
    $NameToClean = $NameToClean -replace "[ .]","_"
    [System.Text.NormalizationForm]$NormalizationForm = "FormD"
    $NameToClean = $NameToClean.Normalize($NormalizationForm)
    $NameToClean = $NameToClean -replace "[^[:ascii:]]","" -replace "[^A-Za-z0-9-_]","_"
    return $NameToClean.ToLower()
}
# $NameCleaner = $function:NameCleaner.ToString()

function GetParent {
    param ($parent)
    if ($parent.Parent) {
        GetParent $parent.Parent
    } else {
        return $parent
    }
}
# $GetParent = $function:GetParent.ToString()

function GetMedian {
    param($numberSeries)
    if ($($numberSeries|Measure-Object).count -gt 1) {
        $sortedNumbers = @($numberSeries | Sort-Object)
        if ($numberSeries.Count % 2) {
            $sortedNumbers[($sortedNumbers.Count / 2) - 1]
        } else {
            ($sortedNumbers[($sortedNumbers.Count / 2)] + $sortedNumbers[($sortedNumbers.Count / 2) - 1]) / 2
        }
    }                      
}
# https://www.powershellgallery.com/packages/Formulaic/0.2.1.0/Content/Get-Median.ps1

function MultiQueryPerfAll {
    param($query_entity_views, $query_perfCntrs)
    foreach ($query_perfCntr in $query_perfCntrs) {
        [ARRAY]$PerfMetrics += New-Object VMware.Vim.PerfMetricId -Property @{counterId=$PerfCounterTable[$query_perfCntr];instance=''}
    }
    foreach ($query_entity_view in $query_entity_views) {
        [ARRAY]$PerfQuerySpecs += New-Object VMware.Vim.PerfQuerySpec -Property @{entity=$query_entity_view;maxSample="15";intervalId="20";metricId=$PerfMetrics}
    }
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
    foreach ($query_perfCntr in $query_perfCntrs) {
        [ARRAY]$PerfMetrics += New-Object VMware.Vim.PerfMetricId -Property @{counterId=$PerfCounterTable[$query_perfCntr];instance=''}
    }
    foreach ($query_entity_view in $query_entity_views) {
        [ARRAY]$PerfQuerySpecs += New-Object VMware.Vim.PerfQuerySpec -Property @{entity=$query_entity_view;maxSample="15";intervalId="20";metricId=$PerfMetrics}
    }
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
    foreach ($query_perfCntr in $query_perfCntrs) {
        [ARRAY]$PerfMetrics += New-Object VMware.Vim.PerfMetricId -Property @{counterId=$PerfCounterTable[$query_perfCntr];instance=''}
    }
    foreach ($query_entity_view in $query_entity_views) {
        [ARRAY]$PerfQuerySpecs += New-Object VMware.Vim.PerfQuerySpec -Property @{entity=$query_entity_view;startTime=$ServiceInstanceServerClock_5;intervalId="300";metricId=$PerfMetrics}
    }
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
    Start-Transcript -Path "/var/log/sexigraf/ViPullStatistics.$($Server).log" -Append -Confirm:$false -Force
    Start-Transcript -Path "/var/log/sexigraf/ViPullStatistics.log" -Append -Confirm:$false -Force
    Write-Host "$((Get-Date).ToString("o")) [DEBUG] ViPullStatistics v$ScriptVersion"
} catch {
    Write-Host "$((Get-Date).ToString("o")) [ERROR] ViPullStatistics logging failure"
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
    Write-Host "$((Get-Date).ToString("o")) [INFO] Looking for another ViPullStatistics for $Server ..."
    $DupViPullStatisticsProcess = Get-PSHostProcessInfo|%{$(Get-Content -LiteralPath "/proc/$($_.ProcessId)/cmdline") -replace "`0", ' '}|?{$_ -match "ViPullStatistics" -and $_ -match "$Server"}
    # https://github.com/PowerShell/PowerShell/issues/13944
    if (($DupViPullStatisticsProcess|Measure-Object).Count -gt 1) {
        $DupViPullStatisticsProcessId = (Get-PSHostProcessInfo|?{$(Get-Content -LiteralPath "/proc/$($_.ProcessId)/cmdline") -replace "`0", ' '|?{$_ -match "$Server"}}).ProcessId[0]
        $DupViPullStatisticsProcessTime = [INT32](ps -p $DupViPullStatisticsProcessId -o etimes).split()[-1]
        if ($DupViPullStatisticsProcessTime -gt 300) {
            Write-Host "$((Get-Date).ToString("o")) [WARNING] ViPullStatistics for $Server is already running for more than 5 minutes!"
            Write-Host "$((Get-Date).ToString("o")) [WARNING] Killing stunned ViPullStatistics for $Server"
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
                $ServerConnection.SessionSecret | Out-File -FilePath /tmp/$SessionSecretName
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
        $vcenter_clusters = Get-View -ViewType ComputeResource -Property name, parent, summary, resourcePool, host, datastore -Server $Server
        $vcenter_vmhosts = Get-View -ViewType HostSystem -Property config.network.pnic, config.network.vnic, config.network.dnsConfig.hostName, runtime.connectionState, summary.hardware.numCpuCores, summary.quickStats.distributedCpuFairness, summary.quickStats.distributedMemoryFairness, summary.quickStats.overallCpuUsage, summary.quickStats.overallMemoryUsage, summary.quickStats.uptime, overallStatus, config.storageDevice.hostBusAdapter, vm, name, summary.runtime.healthSystemRuntime.systemHealthInfo.numericSensorInfo, config.product.version, config.product.build, summary.hardware.vendor, summary.hardware.model, summary.hardware.cpuModel -filter @{"Runtime.ConnectionState" = "^connected$"} -Server $Server
        $vcenter_datastores = Get-View -ViewType Datastore -Property summary, iormConfiguration.enabled, iormConfiguration.statsCollectionEnabled, host -filter @{"summary.accessible" = "true"} -Server $Server
        $vcenter_pods = Get-View -ViewType StoragePod -Property name, summary, parent, childEntity -Server $Server
        $vcenter_vms = Get-View -ViewType VirtualMachine -Property name, runtime.maxCpuUsage, runtime.maxMemoryUsage, summary.quickStats.overallCpuUsage, summary.quickStats.overallCpuDemand, summary.quickStats.hostMemoryUsage, summary.quickStats.guestMemoryUsage, summary.quickStats.balloonedMemory, summary.quickStats.compressedMemory, summary.quickStats.swappedMemory, summary.storage.committed, summary.storage.uncommitted, config.hardware.numCPU, layoutEx.file, snapshot, runtime.host, summary.runtime.connectionState, summary.runtime.powerState, summary.config.numVirtualDisks, config.version, config.guestId, config.tools.toolsVersion -filter @{"Summary.Runtime.ConnectionState" = "^connected$"} -Server $Server       
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
    foreach ($vcenter_cluster in $vcenter_clusters) {
        if ($vcenter_cluster.MoRef.Type -eq "ClusterComputeResource") {
            try {
                $vcenter_clusters_h.add($vcenter_cluster.MoRef.Value, $vcenter_cluster)
            } catch {}
        } elseif ($vcenter_cluster.MoRef.Type -eq "ComputeResource"){
            try {
                $vcenter_compute_h.add($vcenter_cluster.MoRef.Value, $vcenter_cluster)
            } catch {}
        }
    }

    $vcenter_vmhosts_h = @{}
    foreach ($vcenter_vmhost in $vcenter_vmhosts) {
        try {
            $vcenter_vmhosts_h.add($vcenter_vmhost.MoRef.Value, $vcenter_vmhost)
        } catch {}
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
        "datastore.datastoreIops.average",
        "datastore.totalWriteLatency.average",
        "datastore.totalReadLatency.average",
        "datastore.numberWriteAveraged.average",
        "datastore.numberReadAveraged.average",
        "cpu.latency.average",
        "cpu.totalCapacity.average",
        "mem.totalCapacity.average"
    )

    try {
        $HostMultiStatsTime = Measure-Command {$HostMultiStats = MultiQueryPerfAll $($vcenter_vmhosts.moref) $HostMultiMetrics}
        Write-Host "$((Get-Date).ToString("o")) [DEBUG] All hosts multi metrics collected in $($HostMultiStatsTime.TotalSeconds) sec for vCenter $vcenter_name"
    } catch {
        AltAndCatchFire "ESX MultiQueryPerfAll failure"
    }

    $VmMultiMetrics = @(
        "cpu.ready.summation",
		"cpu.wait.summation",
		"cpu.idle.summation",
		"cpu.latency.average",
		"disk.maxTotalLatency.latest",
		"disk.usage.average",
		# "disk.commandsAveraged.average",
		"net.usage.average",
		"cpu.totalCapacity.average",
		"mem.totalCapacity.average"
    )

    try {
        $VmMultiStatsTime = Measure-Command {$VmMultiStats = MultiQueryPerf $($vcenter_vms.moref) $VmMultiMetrics}
        Write-Host "$((Get-Date).ToString("o")) [DEBUG] All vms multi metrics collected in $($VmMultiStatsTime.TotalSeconds) sec for vCenter $vcenter_name"
    } catch {
        AltAndCatchFire "VM MultiQueryPerf failure"
    }

    if ($vcenter_clusters_h.Keys) {
        $ClusterMultiMetrics = @(
            "vmop.numSVMotion.latest"
        )
        try {
            $ClusterMultiStatsTime = Measure-Command {$ClusterMultiStats = MultiQueryPerf300 $($vcenter_clusters_h.Values.moref) $ClusterMultiMetrics}
            Write-Host "$((Get-Date).ToString("o")) [DEBUG] All Clusters multi metrics collected in $($ClusterMultiStatsTime.TotalSeconds) sec for vCenter $vcenter_name"
        } catch {
            AltAndCatchFire "VM MultiQueryPerf failure"
        }
    }

    foreach ($vcenter_cluster_moref in $vcenter_clusters_h.keys) {

        try {
            $vcenter_cluster = $vcenter_clusters_h[$vcenter_cluster_moref]
            $vcenter_cluster_name = nameCleaner $vcenter_cluster.Name
            $vcenter_cluster_dc_name = nameCleaner $(getRootDc $vcenter_cluster)
            Write-Host "$((Get-Date).ToString("o")) [INFO] Processing vCenter $vcenter_name cluster $vcenter_cluster_name hosts in datacenter $vcenter_cluster_dc_name"
        } catch {
            AltAndCatchFire "cluster name cleaning issue"
        }

        $vcenter_cluster_h = @{}

        try {
            $vcenter_cluster_pool_quickstats = $vcenter_resource_pools_h[$vcenter_cluster.moref.value].summary.quickStats

			$vcenter_cluster_h.add("vi.$vcenter_name.$vcenter_cluster_dc_name.$vcenter_cluster_name.quickstats.mem.ballooned", $vcenter_cluster_pool_quickstats.balloonedMemory)
			$vcenter_cluster_h.add("vi.$vcenter_name.$vcenter_cluster_dc_name.$vcenter_cluster_name.quickstats.mem.compressed", $vcenter_cluster_pool_quickstats.compressedMemory)
			$vcenter_cluster_h.add("vi.$vcenter_name.$vcenter_cluster_dc_name.$vcenter_cluster_name.quickstats.mem.consumedOverhead", $vcenter_cluster_pool_quickstats.consumedOverheadMemory)
			$vcenter_cluster_h.add("vi.$vcenter_name.$vcenter_cluster_dc_name.$vcenter_cluster_name.quickstats.mem.guest", $vcenter_cluster_pool_quickstats.guestMemoryUsage)
			$vcenter_cluster_h.add("vi.$vcenter_name.$vcenter_cluster_dc_name.$vcenter_cluster_name.quickstats.mem.usage", $vcenter_cluster_pool_quickstats.hostMemoryUsage)
			$vcenter_cluster_h.add("vi.$vcenter_name.$vcenter_cluster_dc_name.$vcenter_cluster_name.quickstats.cpu.demand", $vcenter_cluster_pool_quickstats.overallCpuDemand)
			$vcenter_cluster_h.add("vi.$vcenter_name.$vcenter_cluster_dc_name.$vcenter_cluster_name.quickstats.cpu.usage", $vcenter_cluster_pool_quickstats.overallCpuUsage)
			$vcenter_cluster_h.add("vi.$vcenter_name.$vcenter_cluster_dc_name.$vcenter_cluster_name.quickstats.mem.private", $vcenter_cluster_pool_quickstats.privateMemory)
			$vcenter_cluster_h.add("vi.$vcenter_name.$vcenter_cluster_dc_name.$vcenter_cluster_name.quickstats.mem.shared", $vcenter_cluster_pool_quickstats.sharedMemory)
			$vcenter_cluster_h.add("vi.$vcenter_name.$vcenter_cluster_dc_name.$vcenter_cluster_name.quickstats.mem.swapped", $vcenter_cluster_pool_quickstats.swappedMemory)
			$vcenter_cluster_h.add("vi.$vcenter_name.$vcenter_cluster_dc_name.$vcenter_cluster_name.quickstats.mem.effective", $vcenter_cluster.summary.effectiveMemory)
			$vcenter_cluster_h.add("vi.$vcenter_name.$vcenter_cluster_dc_name.$vcenter_cluster_name.quickstats.mem.total", $vcenter_cluster.summary.totalMemory)
			$vcenter_cluster_h.add("vi.$vcenter_name.$vcenter_cluster_dc_name.$vcenter_cluster_name.quickstats.cpu.effective", $vcenter_cluster.summary.effectiveCpu)
			$vcenter_cluster_h.add("vi.$vcenter_name.$vcenter_cluster_dc_name.$vcenter_cluster_name.quickstats.cpu.total", $vcenter_cluster.summary.totalCpu)
			$vcenter_cluster_h.add("vi.$vcenter_name.$vcenter_cluster_dc_name.$vcenter_cluster_name.quickstats.numVmotions", $vcenter_cluster.summary.numVmotions)

            if($ClusterMultiStats[$PerfCounterTable["vmop.numSVMotion.latest"]][$vcenter_cluster.moref.value][""]) {
                $vcenter_cluster_h.add("vi.$vcenter_name.$vcenter_cluster_dc_name.$vcenter_cluster_name.quickstats.numSVMotions", $ClusterMultiStats[$PerfCounterTable["vmop.numSVMotion.latest"]][$vcenter_cluster.moref.value][""])
            }

            if ($vcenter_cluster_pool_quickstats.overallCpuUsage -gt 0 -and $vcenter_cluster.summary.effectiveCpu -gt 0) {
                $vcenter_cluster_pool_quickstats_cpu = $vcenter_cluster_pool_quickstats.overallCpuUsage * 100 / $vcenter_cluster.summary.effectiveCpu
                $vcenter_cluster_h.add("vi.$vcenter_name.$vcenter_cluster_dc_name.$vcenter_cluster_name.superstats.cpu.utilization", $vcenter_cluster_pool_quickstats_cpu)
            }

            if ($vcenter_cluster_pool_quickstats.hostMemoryUsage -gt 0 -and $vcenter_cluster.summary.effectiveMemory -gt 0) {
                $vcenter_cluster_pool_quickstats_ram = $vcenter_cluster_pool_quickstats.hostMemoryUsage * 100 / $vcenter_cluster.summary.effectiveMemory
                $vcenter_cluster_h.add("vi.$vcenter_name.$vcenter_cluster_dc_name.$vcenter_cluster_name.superstats.mem.utilization", $vcenter_cluster_pool_quickstats_ram)
            }	

        } catch {
            Write-Host "$((Get-Date).ToString("o")) [ERROR] Cluster $vcenter_cluster_name root resource pool not found ?!"
            Write-Host "$((Get-Date).ToString("o")) [ERROR] $($Error[0])"
        }

        $vcenter_cluster_hosts_pcpus = 0
        $vcenter_cluster_hosts_vms_moref = @()
        $vcenter_cluster_hosts_cpu_latency = 0
        $vcenter_cluster_hosts_net_bytesRx = 0
        $vcenter_cluster_hosts_net_bytesTx = 0
        $vcenter_cluster_hosts_hba_bytesRead = 0
        $vcenter_cluster_hosts_hba_bytesWrite = 0
        $vcenter_cluster_hosts_power_usage = 0
        # $vcenter_cluster_hosts_dead_vms = 0


        foreach ($vcenter_cluster_host in $vcenter_vmhosts_h[$vcenter_clusters_h["domain-c8"].Host.value]) {

            $vcenter_cluster_host_name = $vcenter_cluster_host.config.network.dnsConfig.hostName.ToLower() ### XXX why not $vcenter_cluster_host.name.split(".")[0].ToLower() ?
            if ($vcenter_cluster_host_name -match "localhost") {
                $vcenter_cluster_host_name = NameCleaner $vcenter_cluster_host.name.split(".")[0] ### previously vmk0 ip cleaned

            }

            if ($vcenter_cluster_host.vm) {
                $vcenter_cluster_hosts_vms_moref += $vcenter_vms_h[$vcenter_cluster_host.vm.value]
                # $vcenter_cluster_host_real_vm_count = $($vcenter_cluster_host.vm|Measure-Object).Count
                # $vcenter_cluster_host_connected_vm_count = $($vcenter_vms_h[$vcenter_cluster_host.vm.value]|Measure-Object).Count
                # if ($vcenter_cluster_host_real_vm_count -gt $vcenter_cluster_host_connected_vm_count) {
                #     $vcenter_cluster_hosts_dead_vms += $vcenter_cluster_host_real_vm_count - $vcenter_cluster_host_connected_vm_count
                # }
            }

            if ($vcenter_cluster_host.config.product.version -and $vcenter_cluster_host.config.product.build -and $vcenter_cluster_host.summary.hardware.cpuModel) {
                $vcenter_cluster_host_product_version = nameCleaner $($vcenter_cluster_host.config.product.version + "_" + $vcenter_cluster_host.config.product.build)
                $vcenter_cluster_host_hw_model = nameCleaner $($vcenter_cluster_host.summary.hardware.vendor + "_" + $vcenter_cluster_host.summary.hardware.model)
                $vcenter_cluster_host_cpu_model = nameCleaner $vcenter_cluster_host.summary.hardware.cpuModel

                $vmware_version_h["vi.$vcenter_name.vi.version.esx.$vcenter_cluster_dc_name.$vcenter_cluster_name.build.$vcenter_cluster_host_product_version"] ++
                $vmware_version_h["vi.$vcenter_name.vi.version.esx.$vcenter_cluster_dc_name.$vcenter_cluster_name.hardware.$vcenter_cluster_host_hw_model"] ++
                $vmware_version_h["vi.$vcenter_name.vi.version.esx.$vcenter_cluster_dc_name.$vcenter_cluster_name.cpu.$vcenter_cluster_host_cpu_model"] ++
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

                        $vcenter_cluster_h.add("vi.$vcenter_name.$vcenter_cluster_dc_name.$vcenter_cluster_name.esx.$vcenter_cluster_host_name.sensor.$vcenter_cluster_host_sensor_type.$vcenter_cluster_host_sensor_name", $vcenter_cluster_host_sensor_computed_reading)
                    }
                }
            } catch {
                Write-Host "$((Get-Date).ToString("o")) [ERROR] ESX $vcenter_cluster_host sensors issue in cluster $vcenter_cluster_name"
                Write-Host "$((Get-Date).ToString("o")) [ERROR] $($Error[0])"
            }

            foreach ($vcenter_cluster_host_vmnic in $vcenter_cluster_host.config.network.pnic) {
                if ($vcenter_cluster_host_vmnic.linkSpeed -and $vcenter_cluster_host_vmnic.linkSpeed.speedMb -ge 100) {
                    $vcenter_cluster_host_vmnic_name = $vcenter_cluster_host_vmnic.device

                    $vcenter_cluster_host_vmnic_bytesRx = $HostMultiStats[$PerfCounterTable["net.bytesRx.average"]][$vcenter_cluster_host.moref.value][$vcenter_cluster_host_vmnic_name]
                    $vcenter_cluster_host_vmnic_bytesTx = $HostMultiStats[$PerfCounterTable["net.bytesTx.average"]][$vcenter_cluster_host.moref.value][$vcenter_cluster_host_vmnic_name]

                    if ($vcenter_cluster_host_vmnic_bytesRx -ge 0 -and $vcenter_cluster_host_vmnic_bytesTx -ge 0) {
                        $vcenter_cluster_hosts_net_bytesRx += $vcenter_cluster_host_vmnic_bytesRx
                        $vcenter_cluster_hosts_net_bytesTx += $vcenter_cluster_host_vmnic_bytesTx
                        $vcenter_cluster_h.add("vi.$vcenter_name.$vcenter_cluster_dc_name.$vcenter_cluster_name.esx.$vcenter_cluster_host_name.net.$vcenter_cluster_host_vmnic_name.bytesRx", $vcenter_cluster_host_vmnic_bytesRx)
                        $vcenter_cluster_h.add("vi.$vcenter_name.$vcenter_cluster_dc_name.$vcenter_cluster_name.esx.$vcenter_cluster_host_name.net.$vcenter_cluster_host_vmnic_name.bytesTx", $vcenter_cluster_host_vmnic_bytesTx)
                        $vcenter_cluster_h.add("vi.$vcenter_name.$vcenter_cluster_dc_name.$vcenter_cluster_name.esx.$vcenter_cluster_host_name.net.$vcenter_cluster_host_vmnic_name.linkSpeed", $vcenter_cluster_host_vmnic.linkSpeed.speedMb) ### XXX Still usefull? 
                    }

                    $vcenter_cluster_host_vmnic_droppedRx = $HostMultiStats[$PerfCounterTable["net.droppedRx.summation"]][$vcenter_cluster_host.moref.value][$vcenter_cluster_host_vmnic_name]
                    $vcenter_cluster_host_vmnic_droppedTx = $HostMultiStats[$PerfCounterTable["net.droppedTx.summation"]][$vcenter_cluster_host.moref.value][$vcenter_cluster_host_vmnic_name]
                    $vcenter_cluster_host_vmnic_errorsRx = $HostMultiStats[$PerfCounterTable["net.errorsRx.summation"]][$vcenter_cluster_host.moref.value][$vcenter_cluster_host_vmnic_name]
                    $vcenter_cluster_host_vmnic_errorsTx = $HostMultiStats[$PerfCounterTable["net.errorsTx.summation"]][$vcenter_cluster_host.moref.value][$vcenter_cluster_host_vmnic_name]

                    if ($vcenter_cluster_host_vmnic_droppedRx -gt 0) {
                        $vcenter_cluster_h.add("vi.$vcenter_name.$vcenter_cluster_dc_name.$vcenter_cluster_name.esx.$vcenter_cluster_host_name.net.$vcenter_cluster_host_vmnic_name.droppedRx", $vcenter_cluster_host_vmnic_droppedRx)
                    }

                    if ($vcenter_cluster_host_vmnic_droppedTx -gt 0) {
                        $vcenter_cluster_h.add("vi.$vcenter_name.$vcenter_cluster_dc_name.$vcenter_cluster_name.esx.$vcenter_cluster_host_name.net.$vcenter_cluster_host_vmnic_name.droppedTx", $vcenter_cluster_host_vmnic_droppedTx)
                    }

                    if ($vcenter_cluster_host_vmnic_errorsRx -gt 0) {
                        $vcenter_cluster_h.add("vi.$vcenter_name.$vcenter_cluster_dc_name.$vcenter_cluster_name.esx.$vcenter_cluster_host_name.net.$vcenter_cluster_host_vmnic_name.errorsRx", $vcenter_cluster_host_vmnic_errorsRx)
                    }

                    if ($vcenter_cluster_host_vmnic_errorsTx -gt 0) {
                        $vcenter_cluster_h.add("vi.$vcenter_name.$vcenter_cluster_dc_name.$vcenter_cluster_name.esx.$vcenter_cluster_host_name.net.$vcenter_cluster_host_vmnic_name.errorsTx", $vcenter_cluster_host_vmnic_errorsTx)
                    }

                }
            }

            foreach ($vcenter_cluster_host_vmhba in $vcenter_cluster_host.config.storageDevice.hostBusAdapter) { ### XXX dead paths from config.storageDevice.HostBusAdapter to add
                $vcenter_cluster_host_vmhba_name = $vcenter_cluster_host_vmhba.device
                $vcenter_cluster_host_vmhba_bytesRead = $HostMultiStats[$PerfCounterTable["storageAdapter.read.average"]][$vcenter_cluster_host.moref.value][$vcenter_cluster_host_vmhba_name]
                $vcenter_cluster_host_vmhba_bytesWrite = $HostMultiStats[$PerfCounterTable["storageAdapter.write.average"]][$vcenter_cluster_host.moref.value][$vcenter_cluster_host_vmhba_name]
            
                if ($vcenter_cluster_host_vmhba_bytesRead -ge 0 -and $vcenter_cluster_host_vmhba_bytesWrite -ge 0) {
                    $vcenter_cluster_hosts_hba_bytesRead += $vcenter_cluster_host_vmhba_bytesRead
                    $vcenter_cluster_hosts_hba_bytesWrite += $vcenter_cluster_host_vmhba_bytesWrite
                    $vcenter_cluster_h.add("vi.$vcenter_name.$vcenter_cluster_dc_name.$vcenter_cluster_name.esx.$vcenter_cluster_host_name.hba.$vcenter_cluster_host_vmhba_name.bytesRead", $vcenter_cluster_host_vmhba_bytesRead)
                    $vcenter_cluster_h.add("vi.$vcenter_name.$vcenter_cluster_dc_name.$vcenter_cluster_name.esx.$vcenter_cluster_host_name.hba.$vcenter_cluster_host_vmhba_name.bytesWrite", $vcenter_cluster_host_vmhba_bytesWrite)
                }
            }

            "power.power.average"
        }
    }

} elseif ($ServiceInstance.Content.About.ApiType -match "HostAgent") {

} else {
    AltAndCatchFire "$Server is not a vCenter/ESX!"
}