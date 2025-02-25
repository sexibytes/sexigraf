#!/usr/bin/pwsh -Command
#

param([Parameter (Mandatory=$true)] [string] $CredStore)

$ScriptVersion = "0.9.93"

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

# https://communities.vmware.com/t5/VMware-PowerCLI-Discussions/Listing-all-snapshots-per-vm-using-get-view/td-p/1835866
function Get-SnapChild {
    param([VMware.Vim.VirtualMachineSnapshotTree]$Snapshot)
    process {
        $snapshot
        if($Snapshot.ChildSnapshotList.Count -gt 0) {
            $Snapshot.ChildSnapshotList | %{
                Get-SnapChild -Snapshot $_
            }
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
    $VmsWithSnapsInfos = @()
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
            $Vms = Get-View -ViewType virtualmachine -Property name, Parent, Guest.IpAddress, Network, Summary.Storage, Guest.Net, Runtime.Host, Config.Hardware.NumCPU, Config.Hardware.MemoryMB, Config.GuestId, Guest.GuestId, summary.config.vmPathName, Config.Hardware.Device, Runtime.PowerState, Runtime.bootTime, snapshot, LayoutEx.File, Guest.HostName -Server $ViServer
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

                if ($vm.Guest.HostName) {
                    $VmGuestHostName = $vm.Guest.HostName
                } else {
                    $VmGuestHostName = ""
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
                } elseif ($Vm.Config.GuestId.Length  -gt 0) {
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
                
                $ViVmInfo = "" | Select-Object vCenter, VM, ESX, Cluster, IP, PortGroup, Committed_GB, Allocated_GB, MAC, GuestId, vCPU, vRAM_GB, PowerState, vmxPath, Folder, bootTime, GuestHostname
                
                $ViVmInfo.vCenter = $ServerConnection.name
                $ViVmInfo.VM = $Vm.name
                $ViVmInfo.ESX = $VmHost
                $ViVmInfo.Cluster = $VmCluster
                $ViVmInfo.IP = $VmIpAddress -join " ; "
                $ViVmInfo.PortGroup = $VmNet -join " ; "
                $ViVmInfo.Committed_GB = [math]::round($Vm.Summary.Storage.committed/1GB,0)
                $ViVmInfo.Allocated_GB = [math]::round(($Vm.Summary.Storage.Committed + $Vm.Summary.Storage.Uncommitted)/1GB,0)
                $ViVmInfo.MAC = ($Vm.Config.Hardware.Device|?{$_.MacAddress}).MacAddress -join " ; "
                $ViVmInfo.GuestId = $VmGuestId
                $ViVmInfo.vCPU = $Vm.Config.Hardware.NumCPU
                $ViVmInfo.vRAM_GB = [math]::round($Vm.Config.Hardware.MemoryMB/1KB,0)
                $ViVmInfo.PowerState =  $Vm.Runtime.PowerState
                $ViVmInfo.vmxPath = $Vm.summary.config.vmPathName
                $ViVmInfo.Folder = $VmPath
                $ViVmInfo.bootTime = $VmBootTime
                $ViVmInfo.GuestHostname = $VmGuestHostName
                
                $ViVmsInfos += $ViVmInfo

                try {
                    if ($Vm.Snapshot.CurrentSnapshot) {
                        $VmWithSnapsChildren = $Vm.Snapshot.RootSnapshotList|%{Get-SnapChild -Snapshot $_}
                        $VmWithSnapsOld = @($VmWithSnapsChildren)
                        $VmWithSnapsSizeGB = [math]::Round(($Vm.LayoutEx.File|?{$_.name -match "-[0-9]{6}-"}|Measure-Object -Property Size -Sum).Sum/1GB,2)

                        $VmWithSnapsInfo = "" | Select-Object vCenter, VM, Cluster, Allocated_GB, SnapChild, SnapSizeGB, NewestSnapTime, OldestSnapTime
                        $VmWithSnapsInfo.vCenter = $ViVmInfo.vCenter
                        $VmWithSnapsInfo.VM = $($Vm.name)
                        $VmWithSnapsInfo.Cluster = $ViVmInfo.Cluster
                        $VmWithSnapsInfo.Allocated_GB = $ViVmInfo.Committed_GB
                        $VmWithSnapsInfo.SnapChild = $($VmWithSnapsChildren|Measure-Object).Count
                        $VmWithSnapsInfo.SnapSizeGB = $VmWithSnapsSizeGB
                        $VmWithSnapsInfo.NewestSnapTime = $($($VmWithSnapsOld|Sort-Object CreateTime)[0]).CreateTime
                        $VmWithSnapsInfo.OldestSnapTime = $($($VmWithSnapsOld|Sort-Object CreateTime)[-1]).CreateTime

                        $VmsWithSnapsInfos += $VmWithSnapsInfo
                    }
                } catch {
                    Write-Host -ForegroundColor Red "$((Get-Date).ToString("o")) [EROR] SnapChild issue on VM $($Vm.name)"
                }
                
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
                $ViEsxInfo.RAM_GB = [math]::round($Esx.Summary.Hardware.MemorySize/1GB,0)
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
                $ViDatastoreInfo.Capacity_GB = $([math]::round($Datastore.Summary.Capacity/1GB,0))
                $ViDatastoreInfo.FreeSpace_GB = $([math]::round($Datastore.Summary.FreeSpace/1GB,0))
                $ViDatastoreInfo."Usage_%" = $([math]::round(($Datastore.Summary.Capacity - $Datastore.Summary.FreeSpace) * 100 / $Datastore.Summary.Capacity,0))
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

        $ViVmInventories = Get-ChildItem "/mnt/wfs/inventory/ViVmInventory.*.csv"

        if ($ViVmInventories) {
            Write-Host "$((Get-Date).ToString("o")) [INFO] Rotating ViVmInventory.*.csv files ..."
            $ExtraCsvFiles = Compare-Object  $ViVmInventories  $($ViVmInventories|Sort-Object LastWriteTime | Select-Object -Last 10) -property FullName | ?{$_.SideIndicator -eq "<="}
            If ($ExtraCsvFiles) {
                try {
                    Get-ChildItem $ExtraCsvFiles.FullName | Remove-Item -Force -Confirm:$false
                } catch {
                    AltAndCatchFire "Cannot remove extra csv files"
                }
            }
        }

        try {
            Write-Host "$((Get-Date).ToString("o")) [INFO] Building Vm Inventory CSV ..."
            $ViVmsInfosCsv = $ViVmsInfos|ConvertTo-Csv -NoTypeInformation -ErrorAction Stop
            # Write-Host "$((Get-Date).ToString("o")) [INFO] Looking for vCenter,Cluster,VM differences with previous inventory file ..."
            # if (Test-Path -Path /mnt/wfs/inventory/ViVmInventory.csv) {
            #     $ViVmsInfosCsvBak = Import-Csv -Path /mnt/wfs/inventory/ViVmInventory.csv -ErrorAction Stop
            #     if ($ViVmsInfosCsvBak) {
            #         if (Compare-Object $ViVmsInfosCsvBak $ViVmsInfos -Property vCenter,Cluster,VM) {
            #             Write-Host "$((Get-Date).ToString("o")) [INFO] Differences detected with previous inventory file ..."
            #             $VmMigratedScan = $true
            #         } else {
            #             $VmMigratedScan = $false
            #             Write-Host "$((Get-Date).ToString("o")) [INFO] No differences detected with previous inventory file ..."
            #         }
            #     } else {
            #         Write-Host "$((Get-Date).ToString("o")) [EROR] Empty Vm Inventory file"
            #         $VmMigratedScan = $true
            #     }
            # } else {
            #     Write-Host "$((Get-Date).ToString("o")) [EROR] No existing Vm Inventory file"
            #     $VmMigratedScan = $true
            # }
            Write-Host "$((Get-Date).ToString("o")) [INFO] Writing Vm Inventory file ..."
            $ViVmsInfosCsv|Out-File -Path /mnt/wfs/inventory/ViVmInventory.csv -Force -ErrorAction Stop
            if ($ExecStart.DayOfWeek -match "Monday" -and !$($ViVmInventories|?{$_.LastWriteTime -gt $ExecStart.AddDays(-1)})) {
                $ViVmsInfosCsv|Out-File -Path /mnt/wfs/inventory/ViVmInventory.$((Get-Date).ToString("yyyy.MM.dd_hh.mm.ss")).csv -Force -ErrorAction Stop
            }
        } catch {
            Write-Host "$((Get-Date).ToString("o")) [EROR] VM Inventory issue"
            Write-Host "$((Get-Date).ToString("o")) [EROR] $($Error[0])"
        }
    }

    if ($VmsWithSnapsInfos) {

        $ViSnapInventories = Get-ChildItem "/mnt/wfs/inventory/ViSnapInventory.*.csv"

        if ($ViSnapInventories) {
            Write-Host "$((Get-Date).ToString("o")) [INFO] Rotating ViSnapInventory.*.csv files ..."
            $ExtraCsvFiles = Compare-Object  $ViSnapInventories  $($ViSnapInventories|Sort-Object LastWriteTime | Select-Object -Last 10) -property FullName | ?{$_.SideIndicator -eq "<="}
            If ($ExtraCsvFiles) {
                try {
                    Get-ChildItem $ExtraCsvFiles.FullName | Remove-Item -Force -Confirm:$false
                } catch {
                    AltAndCatchFire "Cannot remove extra csv files"
                }
            }
        }

        try {
            Write-Host "$((Get-Date).ToString("o")) [INFO] Building Vm Snapshot Inventory CSV ..."
            $ViSnapInfosCsv = $VmsWithSnapsInfos|Sort-Object SnapSizeGB -Descending|ConvertTo-Csv -NoTypeInformation -ErrorAction Stop
            Write-Host "$((Get-Date).ToString("o")) [INFO] Writing Vm Snapshot Inventory file ..."
            $ViSnapInfosCsv|Out-File -Path /mnt/wfs/inventory/ViSnapInventory.csv -Force -ErrorAction Stop
            if ($ExecStart.DayOfWeek -match "Monday" -and !$($ViSnapInventories|?{$_.LastWriteTime -gt $ExecStart.AddDays(-1)})) {
                $ViSnapInfosCsv|Out-File -Path /mnt/wfs/inventory/ViSnapInventory.$((Get-Date).ToString("yyyy.MM.dd_hh.mm.ss")).csv -Force -ErrorAction Stop
            }
        } catch {
            Write-Host "$((Get-Date).ToString("o")) [EROR] VM Snapshot Inventory issue"
            Write-Host "$((Get-Date).ToString("o")) [EROR] $($Error[0])"
        }
    }

    if ($ViEsxsInfos) {

        $ViEsxInventories = Get-ChildItem "/mnt/wfs/inventory/ViEsxInventory.*.csv"

        if ($ViEsxInventories) {
            Write-Host "$((Get-Date).ToString("o")) [INFO] Rotating ViEsxInventory.*.csv files ..."
            $ExtraCsvFiles = Compare-Object  $ViEsxInventories  $($ViEsxInventories|Sort-Object LastWriteTime | Select-Object -Last 10) -property FullName | ?{$_.SideIndicator -eq "<="}
            If ($ExtraCsvFiles) {
                try {
                    Get-ChildItem $ExtraCsvFiles.FullName | Remove-Item -Force -Confirm:$false
                } catch {
                    AltAndCatchFire "Cannot remove extra csv files"
                }
            }
        }

        try {
            Write-Host "$((Get-Date).ToString("o")) [INFO] Building ESX Inventory CSV ..."
            $ViEsxsInfosCsv = $ViEsxsInfos|ConvertTo-Csv -NoTypeInformation -ErrorAction Stop
            # Write-Host "$((Get-Date).ToString("o")) [INFO] Looking for vCenter,Cluster,ESX differences with previous inventory file ..."
            # if (Test-Path -Path /mnt/wfs/inventory/ViEsxInventory.csv) {
            #     $ViEsxsInfosCsvBak = Import-Csv -Path /mnt/wfs/inventory/ViEsxInventory.csv -ErrorAction Stop
            #     if ($ViEsxsInfosCsvBak) {
            #         if (Compare-Object $ViEsxsInfosCsvBak $ViEsxsInfos -Property vCenter,Cluster,ESX) {
            #             Write-Host "$((Get-Date).ToString("o")) [INFO] Differences detected with previous inventory file ..."
            #             $EsxMigratedScan = $true
            #         } else {
            #             $EsxMigratedScan = $false
            #             Write-Host "$((Get-Date).ToString("o")) [INFO] No differences detected with previous inventory file ..."
            #         }
            #     } else {
            #         Write-Host "$((Get-Date).ToString("o")) [EROR] Empty ESX Inventory file"
            #         $EsxMigratedScan = $true
            #     }
            # } else {
            #     Write-Host "$((Get-Date).ToString("o")) [EROR] No existing ESX Inventory file"
            #     $EsxMigratedScan = $true
            # }
            Write-Host "$((Get-Date).ToString("o")) [INFO] Writing ESX Inventory file ..."
            $ViEsxsInfosCsv|Out-File -Path /mnt/wfs/inventory/ViEsxInventory.csv -Force -ErrorAction Stop
            if ($ExecStart.DayOfWeek -match "Monday" -and !$($ViEsxInventories|?{$_.LastWriteTime -gt $ExecStart.AddDays(-1)})) {
                $ViEsxsInfosCsv|Out-File -Path /mnt/wfs/inventory/ViEsxInventory.$((Get-Date).ToString("yyyy.MM.dd_hh.mm.ss")).csv -Force -ErrorAction Stop
            }
        } catch {
            Write-Host "$((Get-Date).ToString("o")) [EROR] ESX Inventory issue"
            Write-Host "$((Get-Date).ToString("o")) [EROR] $($Error[0])"
        }
    }

    if ($ViDatastoresInfos) {

        $ViDsInventories = Get-ChildItem "/mnt/wfs/inventory/ViDsInventory.*.csv"

        if ($ViDsInventories) {
            Write-Host "$((Get-Date).ToString("o")) [INFO] Rotating ViDsInventory.*.csv files ..."
            $ExtraCsvFiles = Compare-Object  $ViDsInventories  $($ViDsInventories|Sort-Object LastWriteTime | Select-Object -Last 10) -property FullName | ?{$_.SideIndicator -eq "<="}
            If ($ExtraCsvFiles) {
                try {
                    Get-ChildItem $ExtraCsvFiles.FullName | Remove-Item -Force -Confirm:$false
                } catch {
                    AltAndCatchFire "Cannot remove extra csv files"
                }
            }
        }

        try {
            Write-Host "$((Get-Date).ToString("o")) [INFO] Writing Datastore Inventory files ..."
            $ViDatastoresInfos|Export-Csv -NoTypeInformation -Path /mnt/wfs/inventory/ViDsInventory.csv -Force -ErrorAction Stop
            if ($ExecStart.DayOfWeek -match "Monday" -and !$($ViDsInventories|?{$_.LastWriteTime -gt $ExecStart.AddDays(-1)})) {
                $ViDatastoresInfos|Out-File -Path /mnt/wfs/inventory/ViDsInventory.$((Get-Date).ToString("yyyy.MM.dd_hh.mm.ss")).csv -Force -ErrorAction Stop
            }
        } catch {
            Write-Host "$((Get-Date).ToString("o")) [EROR] Datastore Export-Csv issue"
            Write-Host "$((Get-Date).ToString("o")) [EROR] $($Error[0])"
        }
    }

    Write-Host "$((Get-Date).ToString("o")) [INFO] SexiGraf ViOfflineInventory has left the building ..."

} else {
    AltAndCatchFire "No VI server to process"
}