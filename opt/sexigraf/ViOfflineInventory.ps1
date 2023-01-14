#!/usr/bin/pwsh -Command
#

param([Parameter (Mandatory=$true)] [string] $CredStore)

$ScriptVersion = "0.9.72"

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
                
                if ($Vm.Guest.GuestId) {
                    $VmGuestId = $Vm.Guest.GuestId.replace('Guest','')
                } elseif ($Vm.Config.GuestId) {
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
            Write-Host "$((Get-Date).ToString("o")) [INFO] Writing Vm Inventory files ..."
            $ViVmsInfos|Export-Csv -NoTypeInformation -Path /mnt/wfs/inventory/ViVmInventory.csv -Force -ErrorAction Stop
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

    Write-Host "$((Get-Date).ToString("o")) [INFO] Scanning vm folders ..."

    $vmfolders = Get-ChildItem -Directory /mnt/wfs/whisper/vmw/*/*/*/vm/*|Select-Object BaseName, FullName, CreationTimeUtc, LastWriteTimeUtc, LastAccessTimeUtc|Sort-Object LastAccessTimeUtc -Descending

    Write-Host "$((Get-Date).ToString("o")) [INFO] Looking for xvmotioned vms aka DstVmMigratedEvent ..."

    $vmfolders_h = @{}
    $vmfoldersdup_h = @{}
    foreach ($vmfolder in $vmfolders) {
        if (!$vmfolders_h[$vmfolder.basename]) {
            $vmfolders_h.add($vmfolder.basename,@($vmfolder))
        } else {
            $vmfolders_h[$vmfolder.basename] += $vmfolder
            if (!$vmfoldersdup_h[$vmfolder.basename]) {
                $vmfoldersdup_h.add($vmfolder.basename,"1")
            }
        }
    }
    
    if ($vmfoldersdup_h) {
        Write-Host "$((Get-Date).ToString("o")) [INFO] Duplicated vm folders found across clusters, evaluating mobility ..."
        foreach ($vmdup in $($vmfoldersdup_h.keys|Select-Object -first 500)) {

            if ($vmfolders_h[$vmdup].count -lt 2) {
                Write-Host "$((Get-Date).ToString("o")) [EROR] VM $vmdup has less than 2 copies, skipping ..."
                continue
            } elseif ($vmfolders_h[$vmdup].count -gt 2) {
                Write-Host "$((Get-Date).ToString("o")) [INFO] VM $vmdup has more than 2 copies ..."
            }

            $vmdupfolders = $vmfolders_h[$vmdup]
            $vmdupsrcdir = $($vmdupfolders|Sort-Object CreationTimeUtc -Descending)[1]
            $vmdupdstdir = $($vmdupfolders|Sort-Object CreationTimeUtc -Descending)[0]

            try {
                $vmdupsrcwsp = Get-Item $($vmdupsrcdir.FullName + "/storage/committed.wsp")|Select-Object BaseName, FullName, CreationTimeUtc, LastWriteTimeUtc, LastAccessTimeUtc
                $vmdupdstwsp = Get-Item $($vmdupdstdir.FullName + "/storage/committed.wsp")|Select-Object BaseName, FullName, CreationTimeUtc, LastWriteTimeUtc, LastAccessTimeUtc
            } catch {
                Write-Host "$((Get-Date).ToString("o")) [EROR] Missing committed.wsp for vm $vmdup ..."
                continue
            }

            if (($vmdupdstdir.CreationTimeUtc -gt $vmdupsrcdir.CreationTimeUtc) -and ($vmdupdstwsp.LastWriteTimeUtc - $vmdupsrcwsp.LastWriteTimeUtc).TotalMinutes -gt 90) {
                $vmdupsrcclu = $vmdupsrcdir.FullName.split("/")[-3]
                $vmdupdstclu = $vmdupdstdir.FullName.split("/")[-3]
                Write-Host "$((Get-Date).ToString("o")) [INFO] VM $vmdup has been moved from cluster $vmdupsrcclu to cluster $vmdupdstclu a while ago, merging metrics to the new destination if possible ..."
                $vmdupwsps2mv = Get-ChildItem -Recurse $vmdupsrcdir.FullName -Filter *.wsp
                foreach ($vmdupwsp2mv in $vmdupwsps2mv) {
                    if (Test-Path $($vmdupdstdir.FullName + "/" + $vmdupwsp2mv.FullName.split("/")[-2] + "/" + $vmdupwsp2mv.FullName.split("/")[-1])) {
                        try {
                            Write-Host "$((Get-Date).ToString("o")) [INFO] Merging $($vmdupwsp2mv.FullName) to $($vmdupdstdir.FullName + "/" + $($vmdupwsp2mv.FullName.split("/")[-2]) + "/" + $($vmdupwsp2mv.FullName.split("/")[-1]))"
                            $vmdupwspsrcresiz = Invoke-Expression "/usr/local/bin/whisper-resize.py $($vmdupdstdir.FullName + "/" + $($vmdupwsp2mv.FullName.split("/")[-2]) + "/" + $($vmdupwsp2mv.FullName.split("/")[-1])) 5m:24h 10m:48h 60m:7d 240m:30d 720m:90d 2880m:1y 5760m:2y 17280m:5y --nobackup --force"
                            $vmdupwsp2mvresiz = Invoke-Expression "/usr/local/bin/whisper-resize.py $($vmdupwsp2mv.FullName) 5m:24h 10m:48h 60m:7d 240m:30d 720m:90d 2880m:1y 5760m:2y 17280m:5y --nobackup --force"
                            $vmdupwsp2mvmerg = Invoke-Expression "/usr/local/bin/whisper-merge.py $($vmdupwsp2mv.FullName) $($vmdupdstdir.FullName + "/" + $($vmdupwsp2mv.FullName.split("/")[-2]) + "/" + $($vmdupwsp2mv.FullName.split("/")[-1]))"
                            
                        } catch {
                            Write-Host "$((Get-Date).ToString("o")) [EROR] $($vmdupwsp2mv.FullName) moving issue ..."
                            continue
                        }
                    } else {
                        if (Test-Path $($vmdupdstdir.FullName + "/" + $vmdupwsp2mv.FullName.split("/")[-2] + "/")) {
                            try {
                                Write-Host "$((Get-Date).ToString("o")) [INFO] Moving $($vmdupwsp2mv.FullName) to $($vmdupdstdir.FullName + "/" + $($vmdupwsp2mv.FullName.split("/")[-2]) + "/")"
                                $vmdupwspmv = Move-Item $vmdupwsp2mv.FullName $($vmdupdstdir.FullName + "/" + $vmdupwsp2mv.FullName.split("/")[-2] + "/" + $vmdupwsp2mv.FullName.split("/")[-1]) -Force -ErrorAction Stop
                            } catch {
                                Write-Host "$((Get-Date).ToString("o")) [EROR] $($vmdupwsp2mv.FullName) moving issue ..."
                                continue
                            }
                        } else {
                            try {
                                Write-Host "$((Get-Date).ToString("o")) [INFO] Creating $($vmdupdstdir.FullName + "/" + $($vmdupwsp2mv.FullName.split("/")[-2]) + "/") and moving $($vmdupwsp2mv.FullName)"
                                $vmdupwspmkdir = New-Item $($vmdupdstdir.FullName + "/" + $vmdupwsp2mv.FullName.split("/")[-2] + "/") -Force -ErrorAction Stop
                                $vmdupwspmv = Move-Item $vmdupwsp2mv.FullName $($vmdupdstdir.FullName + "/" + $vmdupwsp2mv.FullName.split("/")[-2] + "/" + $vmdupwsp2mv.FullName.split("/")[-1]) -Force -ErrorAction Stop
                            } catch {
                                Write-Host "$((Get-Date).ToString("o")) [EROR] $($vmdupwsp2mv.FullName) moving issue ..."
                                continue
                            }
                        }
                    }
                }
                Write-Host "$((Get-Date).ToString("o")) [INFO] Removing $($vmdupsrcdir.FullName)"
                try {
                    Remove-Item -Recurse $($vmdupsrcdir.FullName) -Force -ErrorAction Stop
                } catch {
                    Write-Host "$((Get-Date).ToString("o")) [EROR] Removing $($vmdupsrcdir.FullName) issue ..."
                }
            } else {
                Write-Host "$((Get-Date).ToString("o")) [INFO] VM $vmdup move is too recent or has clone ..."
            }
        }
    } else {
        Write-Host "$((Get-Date).ToString("o")) [INFO] No duplicated vm folders found"
    }

    Write-Host "$((Get-Date).ToString("o")) [INFO] Scanning esx folders ..."

    $esxfolders = Get-ChildItem -Directory /mnt/wfs/whisper/vmw/*/*/*/esx/*|Select-Object BaseName, FullName, CreationTimeUtc, LastWriteTimeUtc, LastAccessTimeUtc

    Write-Host "$((Get-Date).ToString("o")) [INFO] Looking for esx move across clusters ..."

    $esxfolders_h = @{}
    $esxfoldersdup_h = @{}
    foreach ($esxfolder in $esxfolders) {
        if (!$esxfolders_h[$esxfolder.basename]) {
            $esxfolders_h.add($esxfolder.basename,@($esxfolder))
        } else {
            $esxfolders_h[$esxfolder.basename] += $esxfolder
            if (!$esxfoldersdup_h[$esxfolder.basename]) {
                $esxfoldersdup_h.add($esxfolder.basename,"1")
            }
        }
    }
    
    if ($esxfoldersdup_h) {
        Write-Host "$((Get-Date).ToString("o")) [INFO] Duplicated esx folders found across clusters, evaluating mobility ..."
        foreach ($esxdup in $esxfoldersdup_h.keys|Select-Object -first 100) {
            if ($esxfolders_h[$esxdup].count -eq 2) {

                $esxdupfolders = $esxfolders_h[$esxdup]
                $esxdupsrcdir = $esxdupfolders|Sort-Object CreationTimeUtc -Descending|Select-Object -Last 1
                $esxdupdstdir = $esxdupfolders|Sort-Object CreationTimeUtc -Descending|Select-Object -First 1

                try {
                    $esxdupsrcwsp = Get-Item $($esxdupsrcdir.FullName + "/quickstats/Uptime.wsp")|Select-Object BaseName, FullName, CreationTimeUtc, LastWriteTimeUtc, LastAccessTimeUtc
                    $esxdupdstwsp = Get-Item $($esxdupdstdir.FullName + "/quickstats/Uptime.wsp")|Select-Object BaseName, FullName, CreationTimeUtc, LastWriteTimeUtc, LastAccessTimeUtc
                } catch {
                    Write-Host "$((Get-Date).ToString("o")) [EROR] Missing committed.wsp for esx $esxdup ..."
                    continue
                }

                if (($esxdupdstdir.CreationTimeUtc -gt $esxdupsrcdir.CreationTimeUtc) -and (($esxdupdstwsp.LastWriteTimeUtc - $esxdupsrcwsp.LastWriteTimeUtc).TotalMinutes -gt 60)) {
                # if (($esxdupdstdir.CreationTimeUtc -gt $esxdupsrcdir.CreationTimeUtc) -and (($esxdupdstwsp.LastWriteTimeUtc - $esxdupsrcwsp.LastWriteTimeUtc).TotalMinutes -gt 15) -and (($esxdupdstwsp.LastWriteTimeUtc - $esxdupsrcwsp.LastWriteTimeUtc).TotalMinutes -le 90)) {
                    $esxdupsrcclu = $esxdupsrcdir.FullName.split("/")[-3]
                    $esxdupdstclu = $esxdupdstdir.FullName.split("/")[-3]
                    Write-Host "$((Get-Date).ToString("o")) [INFO] esx $esxdup has recently been moved from cluster $esxdupsrcclu to cluster $esxdupdstclu, moving metrics to the new destination ..."
                    try {
                        # Move-Item $esxdupsrcdir.FullName $esxdupdstdir.FullName -Force
                    } catch {
                        Write-Host "$((Get-Date).ToString("o")) [EROR] moving issue for esx $esxdup ..."
                        continue
                    }
                }

            } else {
                Write-Host "$((Get-Date).ToString("o")) [INFO] Too many folders for esx $esxdup ..."
            }
        }
    } else {
        Write-Host "$((Get-Date).ToString("o")) [INFO] No duplicated esx folders found"
    }

    Write-Host "$((Get-Date).ToString("o")) [INFO] SexiGraf has left the building ..."

} else {
    AltAndCatchFire "No VI server to process"
}