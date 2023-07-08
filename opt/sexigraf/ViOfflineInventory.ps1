#!/usr/bin/pwsh -Command
#

param([Parameter (Mandatory=$true)] [string] $CredStore)

$ScriptVersion = "0.9.74"

$ErrorActionPreference = "SilentlyContinue"
$WarningPreference = "SilentlyContinue"
(Get-Process -Id $pid).PriorityClass = 'BelowNormal'

function AltAndCatchFire {
    Param($ExitReason)
    Write-Host "$((Get-Date).ToString("o")) [EROR] $ExitReason"
    Write-Host "$((Get-Date).ToString("o")) [EROR] $($Error[0])"
    Write-Host "$((Get-Date).ToString("o")) [EROR] Exit"
    Stop-Transcript
    exit
}

function NameCleaner {
    Param($NameToClean)
    $NameToClean = $NameToClean -replace "[ .]","_"
    [System.Text.NormalizationForm]$NormalizationForm = "FormD"
    $NameToClean = $NameToClean.Normalize($NormalizationForm)
    $NameToClean = $NameToClean -replace "[^[:ascii:]]","" -replace "[^A-Za-z0-9-_]","_"
    return $NameToClean.ToLower()
}

function GetBlueFolderFullPath {
	Param($child_object)
	if ($child_object.Parent) {
		if ($BlueFolders_name_table[$child_object.Parent.value]) {
			$VmPathTree = ""
			$Parent_folder = $child_object.Parent.value
			while ($BlueFolders_type_table[$BlueFolders_Parent_table[$Parent_folder]]) {
				if ($BlueFolders_type_table[$Parent_folder] -eq "Folder" -and $BlueFolders_type_table[$BlueFolders_Parent_table[$Parent_folder]] -ne "Datacenter") {
					$VmPathTree = "/" + $BlueFolders_name_table[$Parent_folder] + $VmPathTree
				}
                if ($BlueFolders_type_table[$BlueFolders_Parent_table[$Parent_folder]] -eq "Datacenter") {
					$VmPathTree = "/" + $BlueFolders_name_table[$BlueFolders_Parent_table[$Parent_folder]] + $VmPathTree
				}
				if ($BlueFolders_type_table[$BlueFolders_Parent_table[$Parent_folder]]) {
					$Parent_folder = $BlueFolders_Parent_table[$Parent_folder]
				}	
			}
			return $VmPathTree = $VmPathTree
		}
	}
}

try {
    Start-Transcript -Path "/var/log/sexigraf/ViOfflineInventory.log" -Append -Confirm:$false -Force -UseMinimalHeader
    Write-Host "$((Get-Date).ToString("o")) [INFO] ViOfflineInventory v$ScriptVersion"
} catch {
    Write-Host "$((Get-Date).ToString("o")) [EROR] ViOfflineInventory logging failure"
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
    Write-Host "$((Get-Date).ToString("o")) [INFO] Looking for another ViOfflineInventory ..."
    $DupViVmInventoryProcess = Get-PSHostProcessInfo|%{$(Get-Content -LiteralPath "/proc/$($_.ProcessId)/cmdline") -replace "`0", ' '}|?{$_ -match "ViOfflineInventory"}
    # https://github.com/PowerShell/PowerShell/issues/13944
    if (($DupViVmInventoryProcess|Measure-Object).Count -gt 1) {
        $DupViVmInventoryProcessId = (Get-PSHostProcessInfo|?{$(Get-Content -LiteralPath "/proc/$($_.ProcessId)/cmdline") -replace "`0", ' '|?{$_ -match "ViOfflineInventory"}}).ProcessId[0]
        $DupViVmInventoryProcessTime = [INT32](ps -p $DupViVmInventoryProcessId -o etimes).split()[-1]
        if ($DupViVmInventoryProcessTime -gt 21600) {
            Write-Host "$((Get-Date).ToString("o")) [WARN] ViOfflineInventory is already running for more than 6 hours!"
            Write-Host "$((Get-Date).ToString("o")) [WARN] Killing stunned ViOfflineInventory"
            Stop-Process -Id $DupViVmInventoryProcessId -Force
        } else {
            AltAndCatchFire "ViOfflineInventory is already running!"
        }
    }
} catch {
    AltAndCatchFire "ViOfflineInventory process lookup failure"
}

try {
    Write-Host "$((Get-Date).ToString("o")) [INFO] VI servers listing ..."
    $createstorexml = New-Object -TypeName XML
    $createstorexml.Load($CredStore)
    $ViServersList = $createstorexml.viCredentials.passwordEntry.server|?{$_ -notmatch "__localhost__"}
} catch {
    AltAndCatchFire "VI servers listing failed"
}


    
if ($ViServersList.count -gt 0) {
    $ViVmsInfos = @()
    $ViEsxsInfos = @()
    $ViDatastoresInfos = @()
    foreach ($ViServer in $ViServersList) {
        $ViServerCleanName = $ViServer.Replace(".","_")
        $SessionFile = "/tmp/vmw_" + $ViServerCleanName + ".key"

        $ExecStart = $(Get-Date).ToUniversalTime()

        try {
            $SessionToken = Get-Content -Path $SessionFile -ErrorAction Stop
            Write-Host "$((Get-Date).ToString("o")) [INFO] SessionToken found in SessionFile, attempting connection to $ViServer ..."
            # https://zhengwu.org/validating-connection-result-of-connect-viserver/
            $ServerConnection = Connect-VIServer -Server $ViServer -Session $SessionToken -Force -ErrorAction Stop
            if ($ServerConnection.IsConnected) {
                # $PwCliContext = Get-PowerCLIContext
                Write-Host "$((Get-Date).ToString("o")) [INFO] Connected to vCenter $($ServerConnection.Name) version $($ServerConnection.Version) build $($ServerConnection.Build)"
            }
        } catch {
            Write-Host "$((Get-Date).ToString("o")) [WARN] SessionToken not found, invalid or connection failure"
            Write-Host "$((Get-Date).ToString("o")) [WARN] Attempting explicit connection ..."
        }

        if (!$($global:DefaultVIServers|?{$_.Name -eq $ViServer})) {
            try {
                # $createstorexml = New-Object -TypeName XML
                # $createstorexml.Load($credstore)
                $XPath = '//passwordEntry[server="' + $ViServer + '"]'
                if ($(Select-XML -Xml $createstorexml -XPath $XPath)){
                    $item = Select-XML -Xml $createstorexml -XPath $XPath
                    $CredStoreLogin = $item.Node.username
                    $CredStorePassword = [System.Text.Encoding]::Unicode.GetString([System.Convert]::FromBase64String($item.Node.password))
                } else {
                    Write-Host "$((Get-Date).ToString("o")) [WARN] No $ViServer entry in CredStore"
                    continue
                }
                $ServerConnection = Connect-VIServer -Server $ViServer -User $CredStoreLogin -Password $CredStorePassword -Force -ErrorAction Stop
                if ($ServerConnection.IsConnected) {
                    # $PwCliContext = Get-PowerCLIContext
                    Write-Host "$((Get-Date).ToString("o")) [INFO] Connected to vCenter $($ServerConnection.Name) version $($ServerConnection.Version) build $($ServerConnection.Build)"
                    $SessionSecretName = "vmw_" + $ViServer.Replace(".","_") + ".key"
                    # $ServerConnection.SessionSecret | Out-File -FilePath /tmp/$SessionSecretName -Force # PS>TerminatingError(Out-File): "Access to the path '/tmp/vmw_xxx.key' is denied."
                }
            } catch {
                Write-Host "$((Get-Date).ToString("o")) [WARN] Explicit connection failed, check the stored credentials for $ViServer !"
                continue
            }
        }

        try {
            if ($($global:DefaultVIServer|?{$_.Name -eq $ViServer})) {
                Write-Host "$((Get-Date).ToString("o")) [INFO] Start processing vCenter/ESX $ViServer ..."
                $ServiceInstance = Get-View ServiceInstance -Server $ViServer -Property ServerClock
            } else {
                Write-Host "$((Get-Date).ToString("o")) [WARN] global:DefaultVIServer variable check failure for $ViServer"
                continue
            }
        } catch {
            Write-Host "$((Get-Date).ToString("o")) [WARN] Unable to verify vCenter connection for $ViServer"
            continue
        }

        if ($ServiceInstance) {

            Write-Host "$((Get-Date).ToString("o")) [INFO] Collecting objects in $ViServer ..."

            $DvPgs = Get-View -ViewType DistributedVirtualPortgroup -Property name -Server $ViServer
            $vPgs = Get-View -ViewType Network -Property name -Server $ViServer
            $Vms = Get-View -ViewType virtualmachine -Property name, Parent, Guest.IpAddress, Network, Summary.Storage, Guest.Net, Runtime.Host, Config.Hardware.NumCPU, Config.Hardware.MemoryMB, Guest.GuestId, summary.config.vmPathName, Config.Hardware.Device, Runtime.PowerState, Runtime.bootTime -Server $ViServer
            $esxs = Get-View -ViewType hostsystem -Property name, Config.Product.Version, Config.Product.Build, Summary.Hardware.Model, Summary.Hardware.MemorySize, Summary.Hardware.CpuModel, Summary.Hardware.NumCpuCores, Summary.Hardware.OtherIdentifyingInfo, Parent, runtime.ConnectionState, runtime.InMaintenanceMode, config.network.dnsConfig.hostName, Config.Network.Vnic, Hardware.SystemInfo.SerialNumber -Server $ViServer
            $clusters = Get-View -ViewType clustercomputeresource -Property name -Server $ViServer
            $datastores = Get-View -ViewType datastore -Property name, Summary.Type, Summary.Capacity, Summary.FreeSpace, Summary.Url -Server $ViServer

            $Datacenters = Get-View -ViewType datacenter -Property Parent, Name -Server $ViServer
            $BlueFolders = Get-View -ViewType folder -Property Parent, Name, ChildType -Server $ViServer

            $BlueFolders_name_table = @{}
            $BlueFolders_Parent_table = @{}
            $BlueFolders_type_table = @{}
            
            foreach ($BlueFolder in [array]$BlueFolders + [array]$Datacenters) {
                if ($BlueFolder.Parent.value) {
                    if (!$BlueFolders_name_table[$BlueFolder.moref.value]) {$BlueFolders_name_table.add($BlueFolder.moref.value,$BlueFolder.name)}
                    if (!$BlueFolders_Parent_table[$BlueFolder.moref.value]) {$BlueFolders_Parent_table.add($BlueFolder.moref.value,$BlueFolder.Parent.value)}
                    if (!$BlueFolders_type_table[$BlueFolder.moref.value]) {$BlueFolders_type_table.add($BlueFolder.moref.value,$BlueFolder.moref.type)}
                }
            }

            Write-Host "$((Get-Date).ToString("o")) [INFO] Building hashtables ..."
            
            $DvPgs_h = @{}
            foreach ($DvPg in $DvPgs) {
                if (!$DvPgs_h[$DvPg.moref]) {
                    $DvPgs_h.add($DvPg.moref,$DvPg.name)
                }
            }
            foreach ($vPg in $vPgs) {
                if (!$DvPgs_h[$vPg.moref]) {
                    $DvPgs_h.add($vPg.moref,$vPg.name)
                }
            }
            
            $esxs_h = @{}
            foreach ($esx in $esxs) {
                if (!$esxs_h[$esx.moref]) {
                    $esxs_h.add($esx.moref,$esx)
                }
            }
            
            $clusters_h = @{}
            foreach ($cluster in $clusters) {
                if (!$clusters_h[$cluster.moref]) {
                    $clusters_h.add($cluster.moref,$cluster.name)
                }
            }
    
            foreach ($Vm in $Vms) {
            
                if ($Vm.Guest.Net) {
                    $VmIpAddress = $Vm.Guest.Net.IpAddress|?{$_}
                } else {
                    $VmIpAddress = ""
                }
                
                if ($vm.network) {
                    $VmNet = $DvPgs_h[$vm.network]
                } else {
                    $VmNet = ""
                }

                if ($vm.Runtime.bootTime) {
                    $VmBootTime = $vm.Runtime.bootTime.ToString("yyyy-MM-ddTHH:mm:ss.fffZ")
                } else {
                    $VmBootTime = ""
                }
                
                if ($esxs_h[$vm.Runtime.Host]) {
                    if ($($esxs_h[$vm.Runtime.Host]).config.network.dnsConfig.hostName -notmatch "localhost") {
                        $VmHost = $($esxs_h[$vm.Runtime.Host]).config.network.dnsConfig.hostName
                    } else {
                        $VmHost = $($esxs_h[$vm.Runtime.Host]).name
                    }
                } else {
                    $VmHost = ""
                }
                
                if ($clusters_h[$esxs_h[$vm.Runtime.Host].Parent]) {
                    $VmCluster = $clusters_h[$esxs_h[$vm.Runtime.Host].Parent]
                } else {
                    $VmCluster = ""
                }
                
                if ($Vm.Guest.GuestId.Length -gt 0) {
                    $VmGuestId = $Vm.Guest.GuestId.replace('Guest','')
                } elseif ($Vm.Config.GuestId  -gt 0) {
                    $VmGuestId = $Vm.Config.GuestId.replace('Guest','')
                } else {
                    $VmGuestId = ""
                }
                
                try {
                    $VmPath = ""
                    $VmPath = GetBlueFolderFullPath $Vm
                } catch {
                    Write-Host "$((Get-Date).ToString("o")) [WARN] Unable to get blue folder path for $($Vm.name)"
                }
                
                $ViVmInfo = "" | Select-Object vCenter, VM, ESX, Cluster, IP, PortGroup, Committed_GB, Allocated_GB, MAC, GuestId, vCPU, vRAM_GB, PowerState, vmxPath, Folder, bootTime
                
                $ViVmInfo.vCenter = $ServerConnection.name
                $ViVmInfo.VM = $Vm.name
                $ViVmInfo.ESX = $VmHost
                $ViVmInfo.Cluster = $VmCluster
                $ViVmInfo.IP = $VmIpAddress -join " ; "
                $ViVmInfo.PortGroup = $VmNet -join " ; "
                $ViVmInfo.Committed_GB = [math]::round($Vm.Summary.Storage.committed/1GB,1)
                $ViVmInfo.Allocated_GB = [math]::round(($Vm.Summary.Storage.Committed + $Vm.Summary.Storage.Uncommitted)/1GB,1)
                $ViVmInfo.MAC = ($Vm.Config.Hardware.Device|?{$_.MacAddress}).MacAddress -join " ; "
                $ViVmInfo.GuestId = $VmGuestId
                $ViVmInfo.vCPU = $Vm.Config.Hardware.NumCPU
                $ViVmInfo.vRAM_GB = [math]::round($Vm.Config.Hardware.MemoryMB/1KB,1)
                $ViVmInfo.PowerState =  $Vm.Runtime.PowerState
                $ViVmInfo.vmxPath = $Vm.summary.config.vmPathName
                $ViVmInfo.Folder = $VmPath
                $ViVmInfo.bootTime = $VmBootTime
                
                $ViVmsInfos += $ViVmInfo
            }

            foreach ($Esx in $esxs) {
            
                if ($clusters_h[$Esx.Parent]) {
                    $EsxCluster = $clusters_h[$Esx.Parent]
                } else {
                    $EsxCluster = ""
                }

                if ($Esx.Config.Product.Version -and $Esx.Config.Product.Build) {
                    $EsxVersion = $Esx.Config.Product.Version + "." + $Esx.Config.Product.Build
                } else {
                    $EsxVersion = ""
                }

                if ($Esx.runtime.ConnectionState -eq "connected" -and $Esx.runtime.InMaintenanceMode) {
                    $EsxState = "MaintenanceMode"
                } else {
                    $EsxState = $Esx.runtime.ConnectionState
                }

                if ($Esx.Hardware.SystemInfo.SerialNumber) {
                    $EsxServiceTag = $Esx.Hardware.SystemInfo.SerialNumber
                } elseif ($Esx.Summary.Hardware.OtherIdentifyingInfo[3].IdentifierValue) {
                    $EsxServiceTag = $Esx.Summary.Hardware.OtherIdentifyingInfo[3].IdentifierValue
                } else {
                    $EsxServiceTag = ""
                }
                
                $ViEsxInfo = "" | Select-Object vCenter, ESX, Cluster, Version, Model, SerialNumber, State, RAM_GB, CPU, Cores, vmk0Ip, vmk0Mac
                
                $ViEsxInfo.vCenter = $ViServer
                $ViEsxInfo.ESX = $($Esx.name)
                $ViEsxInfo.Cluster = $EsxCluster
                $ViEsxInfo.Version = $EsxVersion
                $ViEsxInfo.Model = $Esx.Summary.Hardware.Model
                $ViEsxInfo.SerialNumber = $EsxServiceTag
                $ViEsxInfo.State = $EsxState
                $ViEsxInfo.RAM_GB = [math]::round($Esx.Summary.Hardware.MemorySize/1GB,1)
                $ViEsxInfo.CPU = $Esx.Summary.Hardware.CpuModel
                $ViEsxInfo.Cores = $Esx.Summary.Hardware.NumCpuCores
                $ViEsxInfo.vmk0Ip = ($Esx.Config.Network.Vnic|?{$_.Device -eq "vmk0"}).Spec.Ip.IpAddress
                $ViEsxInfo.vmk0Mac = ($Esx.Config.Network.Vnic|?{$_.Device -eq "vmk0"}).Spec.Mac
                
                $ViEsxsInfos += $ViEsxInfo
            }

            foreach ($Datastore in $datastores) {
                
                $ViDatastoreInfo = "" | Select-Object vCenter, Datastore, Type, Capacity_GB, FreeSpace_GB, "Usage_%", Url
                
                $ViDatastoreInfo.vCenter = $ViServer
                $ViDatastoreInfo.Datastore = $($Datastore.name)
                $ViDatastoreInfo.Type = $($Datastore.Summary.Type)
                $ViDatastoreInfo.Capacity_GB = $([math]::round($Datastore.Summary.Capacity/1GB,1))
                $ViDatastoreInfo.FreeSpace_GB = $([math]::round($Datastore.Summary.FreeSpace/1GB,1))
                $ViDatastoreInfo."Usage_%" = $([math]::round(($Datastore.Summary.Capacity - $Datastore.Summary.FreeSpace) * 100 / $Datastore.Summary.Capacity,1))
                $ViDatastoreInfo.Url = $($Datastore.Summary.Url)
                
                $ViDatastoresInfos += $ViDatastoreInfo
            }
    
        }
        
        $ExecDuration = $($(Get-Date) - $ExecStart).TotalSeconds.ToString().Split(".")[0]
        $ExecStartEpoc = $(New-TimeSpan -Start (Get-Date -Date "01/01/1970") -End $ExecStart).TotalSeconds.ToString().Split(".")[0]
    
        Send-GraphiteMetric -CarbonServer 127.0.0.1 -CarbonServerPort 2003 -MetricPath "vi.$ViServerCleanName.vm.exec.duration" -MetricValue $ExecDuration -UnixTime $ExecStartEpoc

        # Write-Host "$((Get-Date).ToString("o")) [INFO] Disconnecting from $ViServer ..."
        
        # if ($global:DefaultVIServers) {Disconnect-VIServer * -Force -Confirm:0}
    }

    if ($ViVmsInfos) {
        try {
            Write-Host "$((Get-Date).ToString("o")) [INFO] Building Vm Inventory CSV ..."
            $ViVmsInfosCsv = $ViVmsInfos|Export-Csv -NoTypeInformation -ErrorAction Stop
            Write-Host "$((Get-Date).ToString("o")) [INFO] Looking for vCenter,Cluster,VM differences with previous inventory file ..."
            if (Test-Path /mnt/wfs/inventory/ViVmInventory.csv) {
                if ($ViVmsInfosCsvDiff = Compare-Object $(Import-Csv -Path /mnt/wfs/inventory/ViVmInventory.csv -ErrorAction Stop) $ViVmsInfosCsv -Property vCenter,Cluster,VM) {
                    Write-Host "$((Get-Date).ToString("o")) [INFO] Differences detected with previous inventory file ..."
                    $VmMigratedScan = $true
                } else {
                    $VmMigratedScan = $false
                    Write-Host "$((Get-Date).ToString("o")) [INFO] No differences detected with previous inventory file ..."
                }
            } else {
                Write-Host "$((Get-Date).ToString("o")) [EROR] No existing Vm Inventory file"
                $VmMigratedScan = $true
            }
            Write-Host "$((Get-Date).ToString("o")) [INFO] Writing Vm Inventory file ..."
            $ViVmsInfosCsv|Out-File -Path /mnt/wfs/inventory/ViVmInventory.csv -Force -ErrorAction Stop
        } catch {
            Write-Host "$((Get-Date).ToString("o")) [EROR] VM Export-Csv issue"
            Write-Host "$((Get-Date).ToString("o")) [EROR] $($Error[0])"
        }
    }

    if ($ViEsxsInfos) {
        try {
            Write-Host "$((Get-Date).ToString("o")) [INFO] Writing Esx Inventory files ..."
            $ViEsxsInfos|Export-Csv -NoTypeInformation -Path /mnt/wfs/inventory/ViEsxInventory.csv -Force -ErrorAction Stop
        } catch {
            Write-Host "$((Get-Date).ToString("o")) [EROR] ESX Export-Csv issue"
            Write-Host "$((Get-Date).ToString("o")) [EROR] $($Error[0])"
        }
    }

    if ($ViDatastoresInfos) {
        try {
            Write-Host "$((Get-Date).ToString("o")) [INFO] Writing Datastore Inventory files ..."
            $ViDatastoresInfos|Export-Csv -NoTypeInformation -Path /mnt/wfs/inventory/ViDsInventory.csv -Force -ErrorAction Stop
        } catch {
            Write-Host "$((Get-Date).ToString("o")) [EROR] Datastore Export-Csv issue"
            Write-Host "$((Get-Date).ToString("o")) [EROR] $($Error[0])"
        }
    }

    if ($VmMigratedScan -eq $true) {
        Write-Host "$((Get-Date).ToString("o")) [INFO] VM Inventory differences detected, scanning vm folders ..."

        $VmFolders = Get-ChildItem -Directory /mnt/wfs/whisper/vmw/*/*/*/vm/*|Select-Object BaseName, FullName, CreationTimeUtc, LastWriteTimeUtc, LastAccessTimeUtc|Sort-Object LastAccessTimeUtc -Descending

        Write-Host "$((Get-Date).ToString("o")) [INFO] Looking for xvmotioned vms aka DstVmMigratedEvent ..."

        $VmFolders_h = @{}
        $VmFoldersDup_h = @{}
        foreach ($VmFolder in $VmFolders) {
            if (!$VmFolders_h[$VmFolder.basename]) {
                $VmFolders_h.add($VmFolder.basename,@($VmFolder))
            } else {
                $VmFolders_h[$VmFolder.basename] += $VmFolder
                if (!$VmFoldersDup_h[$VmFolder.basename]) {
                    $VmFoldersDup_h.add($VmFolder.basename,"1")
                }
            }
        }
        
        if ($VmFoldersDup_h) {
            Write-Host "$((Get-Date).ToString("o")) [INFO] Duplicated vm folders found across clusters, evaluating mobility ..."
            foreach ($VmDup in $($VmFoldersDup_h.keys|Select-Object -first 500)) {

                if ($VmFolders_h[$VmDup].count -lt 2) {
                    Write-Host "$((Get-Date).ToString("o")) [EROR] VM $VmDup has less than 2 copies, skipping ..."
                    continue
                } elseif ($VmFolders_h[$VmDup].count -gt 2) {
                    Write-Host "$((Get-Date).ToString("o")) [INFO] VM $VmDup has more than 2 copies ..."
                }

                $VmDupFolders = $VmFolders_h[$VmDup]
                $VmDupSrcDir = $($VmDupFolders|Sort-Object CreationTimeUtc -Descending)[1]
                $VmDupDstDir = $($VmDupFolders|Sort-Object CreationTimeUtc -Descending)[0]

                try {
                    $VmDupSrcWsp = Get-Item $($VmDupSrcDir.FullName + "/storage/committed.wsp")|Select-Object BaseName, FullName, CreationTimeUtc, LastWriteTimeUtc, LastAccessTimeUtc
                    $VmDupDstWsp = Get-Item $($VmDupDstDir.FullName + "/storage/committed.wsp")|Select-Object BaseName, FullName, CreationTimeUtc, LastWriteTimeUtc, LastAccessTimeUtc
                } catch {
                    Write-Host "$((Get-Date).ToString("o")) [EROR] Missing committed.wsp for vm $VmDup ..."
                    continue
                }

                if (($VmDupDstDir.CreationTimeUtc -gt $VmDupSrcDir.CreationTimeUtc) -and ($VmDupDstWsp.LastWriteTimeUtc - $VmDupSrcWsp.LastWriteTimeUtc).TotalMinutes -gt 90) {

                    $VmDupDstVc = $VmDupDstDir.FullName.split("/")[5]
                    $VmDupDstDc = $VmDupDstDir.FullName.split("/")[6]
                    $VmDupDstClu = $VmDupDstDir.FullName.split("/")[7]
                    $VmDupSrcClu = $VmDupSrcDir.FullName.split("/")[7]
                    Write-Host "$((Get-Date).ToString("o")) [INFO] VM $VmDup has been moved from cluster $VmDupSrcClu to cluster $VmDupDstClu a while ago, merging metrics to the new destination if possible ..."
                    $VmDupWsps2Mv = Get-ChildItem -Recurse $VmDupSrcDir.FullName -Filter *.wsp
                    foreach ($VmDupWsp2Mv in $VmDupWsps2Mv) {
                        $WspRelativePath = $($VmDupWsp2Mv.FullName -split "/vm/")[1]
                        $DstWspFullPath = $("/mnt/wfs/whisper/vmw/" + $VmDupDstVc + "/" + $VmDupDstDc + "/" + $VmDupDstClu + "/vm/" + $WspRelativePath)
                        if (Test-Path $DstWspFullPath) {
                            try {
                                Write-Host "$((Get-Date).ToString("o")) [INFO] Merging $($VmDupWsp2Mv.FullName) to $DstWspFullPath"
                                $VmDupWspSrcResiz = Invoke-Expression "/usr/local/bin/whisper-resize.py $DstWspFullPath 5m:24h 10m:48h 60m:7d 240m:30d 720m:90d 2880m:1y 5760m:2y 17280m:5y --nobackup --force"
                                $VmDupWsp2MvResiz = Invoke-Expression "/usr/local/bin/whisper-resize.py $($VmDupWsp2Mv.FullName) 5m:24h 10m:48h 60m:7d 240m:30d 720m:90d 2880m:1y 5760m:2y 17280m:5y --nobackup --force"
                                $VmDupWsp2MvMerg = Invoke-Expression "/usr/local/bin/whisper-merge.py $($VmDupWsp2Mv.FullName) $DstWspFullPath"
                                
                            } catch {
                                Write-Host "$((Get-Date).ToString("o")) [EROR] $($VmDupWsp2Mv.FullName) moving issue ..."
                                continue
                            }
                        } else {
                            try {
                                Write-Host "$((Get-Date).ToString("o")) [INFO] Creating $DstWspFullPath and moving $($VmDupWsp2Mv.FullName)"
                                $VmDupWspMkDir = New-Item $DstWspFullPath -Force -ErrorAction Stop
                                $VmDupWspMv = Move-Item $VmDupWsp2Mv.FullName $DstWspFullPath -Force -ErrorAction Stop
                            } catch {
                                Write-Host "$((Get-Date).ToString("o")) [EROR] $($VmDupWsp2Mv.FullName) moving issue ..."
                                continue
                            }
                        }
                    }
                    Write-Host "$((Get-Date).ToString("o")) [INFO] Removing $($VmDupSrcDir.FullName)"
                    try {
                        Remove-Item -Recurse $($VmDupSrcDir.FullName) -Force -ErrorAction Stop
                    } catch {
                        Write-Host "$((Get-Date).ToString("o")) [EROR] Removing $($VmDupSrcDir.FullName) issue ..."
                    }
                } else {
                    Write-Host "$((Get-Date).ToString("o")) [INFO] VM $VmDup move is too recent, has clones or has come back to its original location ..."
                }
            }
        } else {
            Write-Host "$((Get-Date).ToString("o")) [INFO] No duplicated vm folders found"
        }
    }

    Write-Host "$((Get-Date).ToString("o")) [INFO] Scanning Esx folders ..."

    $EsxFolders = Get-ChildItem -Directory /mnt/wfs/whisper/vmw/*/*/*/esx/*|Select-Object BaseName, FullName, CreationTimeUtc, LastWriteTimeUtc, LastAccessTimeUtc|Sort-Object LastAccessTimeUtc -Descending
    
    Write-Host "$((Get-Date).ToString("o")) [INFO] Looking for xEsxotioned Esxs aka DstEsxMigratedEvent ..."
    
    $EsxFolders_h = @{}
    $EsxFoldersDup_h = @{}
    foreach ($EsxFolder in $EsxFolders) {
        if (!$EsxFolders_h[$EsxFolder.basename]) {
            $EsxFolders_h.add($EsxFolder.basename,@($EsxFolder))
        } else {
            $EsxFolders_h[$EsxFolder.basename] += $EsxFolder
            if (!$EsxFoldersDup_h[$EsxFolder.basename]) {
                $EsxFoldersDup_h.add($EsxFolder.basename,"1")
            }
        }
    }
    
    if ($EsxFoldersDup_h) {
        Write-Host "$((Get-Date).ToString("o")) [INFO] Duplicated Esx folders found across clusters, evaluating mobility ..."
        foreach ($EsxDup in $($EsxFoldersDup_h.keys|Select-Object -first 50)) {
    
            if ($EsxFolders_h[$EsxDup].count -lt 2) {
                Write-Host "$((Get-Date).ToString("o")) [EROR] Esx $EsxDup has less than 2 copies, skipping ..."
                continue
            } elseif ($EsxFolders_h[$EsxDup].count -gt 2) {
                Write-Host "$((Get-Date).ToString("o")) [INFO] Esx $EsxDup has more than 2 copies ..."
            }
    
            $EsxDupFolders = $EsxFolders_h[$EsxDup]
            $EsxDupSrcDir = $($EsxDupFolders|Sort-Object CreationTimeUtc -Descending)[1]
            $EsxDupDstDir = $($EsxDupFolders|Sort-Object CreationTimeUtc -Descending)[0]
    
            try {
                $EsxDupSrcWsp = Get-Item $($EsxDupSrcDir.FullName + "/quickstats/Uptime.wsp")|Select-Object BaseName, FullName, CreationTimeUtc, LastWriteTimeUtc, LastAccessTimeUtc
                $EsxDupDstWsp = Get-Item $($EsxDupDstDir.FullName + "/quickstats/Uptime.wsp")|Select-Object BaseName, FullName, CreationTimeUtc, LastWriteTimeUtc, LastAccessTimeUtc
            } catch {
                Write-Host "$((Get-Date).ToString("o")) [EROR] Missing committed.wsp for Esx $EsxDup ..."
                continue
            }
    
            if (($EsxDupDstDir.CreationTimeUtc -gt $EsxDupSrcDir.CreationTimeUtc) -and ($EsxDupDstWsp.LastWriteTimeUtc - $EsxDupSrcWsp.LastWriteTimeUtc).TotalMinutes -gt 90) {
    
                $EsxDupDstVc = $EsxDupDstDir.FullName.split("/")[5]
                $EsxDupDstDc = $EsxDupDstDir.FullName.split("/")[6]
                $EsxDupDstClu = $EsxDupDstDir.FullName.split("/")[7]
                $EsxDupSrcClu = $EsxDupSrcDir.FullName.split("/")[7]
                Write-Host "$((Get-Date).ToString("o")) [INFO] Esx $EsxDup has been moved from cluster $EsxDupSrcClu to cluster $EsxDupDstClu a while ago, merging metrics to the new destination if possible ..."
                $EsxDupWsps2Mv = Get-ChildItem -Recurse $EsxDupSrcDir.FullName -Filter *.wsp
                foreach ($EsxDupWsp2Mv in $EsxDupWsps2Mv) {
                    $WspRelativePath = $($EsxDupWsp2Mv.FullName -split "/Esx/")[1]
                    $DstWspFullPath = $("/mnt/wfs/whisper/vmw/" + $EsxDupDstVc + "/" + $EsxDupDstDc + "/" + $EsxDupDstClu + "/esx/" + $WspRelativePath)
                    if (Test-Path $DstWspFullPath) {
                        try {
                            Write-Host "$((Get-Date).ToString("o")) [INFO] Merging $($EsxDupWsp2Mv.FullName) to $DstWspFullPath"
                            $EsxDupWspSrcResiz = Invoke-Expression "/usr/local/bin/whisper-resize.py $DstWspFullPath 5m:24h 10m:48h 60m:7d 240m:30d 720m:90d 2880m:1y 5760m:2y 17280m:5y --nobackup --force"
                            $EsxDupWsp2MvResiz = Invoke-Expression "/usr/local/bin/whisper-resize.py $($EsxDupWsp2Mv.FullName) 5m:24h 10m:48h 60m:7d 240m:30d 720m:90d 2880m:1y 5760m:2y 17280m:5y --nobackup --force"
                            $EsxDupWsp2MEsxerg = Invoke-Expression "/usr/local/bin/whisper-merge.py $($EsxDupWsp2Mv.FullName) $DstWspFullPath"
                            
                        } catch {
                            Write-Host "$((Get-Date).ToString("o")) [EROR] $($EsxDupWsp2Mv.FullName) moving issue ..."
                            continue
                        }
                    } else {
                        try {
                            Write-Host "$((Get-Date).ToString("o")) [INFO] Creating $DstWspFullPath and moving $($EsxDupWsp2Mv.FullName)"
                            $EsxDupWspMkDir = New-Item $DstWspFullPath -Force -ErrorAction Stop
                            $EsxDupWspMv = Move-Item $EsxDupWsp2Mv.FullName $DstWspFullPath -Force -ErrorAction Stop
                        } catch {
                            Write-Host "$((Get-Date).ToString("o")) [EROR] $($EsxDupWsp2Mv.FullName) moving issue ..."
                            continue
                        }
                    }
                }
                Write-Host "$((Get-Date).ToString("o")) [INFO] Removing $($EsxDupSrcDir.FullName)"
                try {
                    Remove-Item -Recurse $($EsxDupSrcDir.FullName) -Force -ErrorAction Stop
                } catch {
                    Write-Host "$((Get-Date).ToString("o")) [EROR] Removing $($EsxDupSrcDir.FullName) issue ..."
                }
            } else {
                Write-Host "$((Get-Date).ToString("o")) [INFO] Esx $EsxDup move is too recent, has clones or has come back to its original location ..."
            }
        }
    } else {
        Write-Host "$((Get-Date).ToString("o")) [INFO] No duplicated Esx folders found"
    }

    Write-Host "$((Get-Date).ToString("o")) [INFO] SexiGraf has left the building ..."

} else {
    AltAndCatchFire "No VI server to process"
}