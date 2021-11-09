#!/usr/bin/pwsh -NonInteractive -NoProfile -Command
#

param([Parameter (Mandatory=$true)] [string] $CredStore)

$ScriptVersion = "0.9.49"

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
			$VmPathTree = "/"
			$Parent_folder = $child_object.Parent.value
			while ($BlueFolders_type_table[$BlueFolders_Parent_table[$Parent_folder]]) {
				if ($BlueFolders_type_table[$Parent_folder] -eq "Folder") {
					$VmPathTree = "/" + $BlueFolders_name_table[$Parent_folder] + $VmPathTree
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
    Start-Transcript -Path "/var/log/sexigraf/ViVmInventory.log" -Append -Confirm:$false -Force
    Write-Host "$((Get-Date).ToString("o")) [DEBUG] ViVmInventory v$ScriptVersion"
} catch {
    Write-Host "$((Get-Date).ToString("o")) [ERROR] ViVmInventory logging failure"
    Write-Host "$((Get-Date).ToString("o")) [ERROR] Exit"
    exit
}

try {
    Write-Host "$((Get-Date).ToString("o")) [DEBUG] Importing PowerCli module ..."
    Import-Module VMware.VimAutomation.Common, VMware.VimAutomation.Core, VMware.VimAutomation.Sdk, VMware.VimAutomation.Storage
    $PowerCliConfig = Set-PowerCLIConfiguration -ProxyPolicy NoProxy -DefaultVIServerMode Single -InvalidCertificateAction Ignore -ParticipateInCeip:$false -DisplayDeprecationWarnings:$false -Confirm:$false -Scope Session
} catch {
    AltAndCatchFire "Powershell modules import failure"
}

try {
    Write-Host "$((Get-Date).ToString("o")) [INFO] Looking for another ViVmInventory ..."
    $DupViVmInventoryProcess = Get-PSHostProcessInfo|%{$(Get-Content -LiteralPath "/proc/$($_.ProcessId)/cmdline") -replace "`0", ' '}|?{$_ -match "ViVmInventory"}
    # https://github.com/PowerShell/PowerShell/issues/13944
    if (($DupViVmInventoryProcess|Measure-Object).Count -gt 1) {
        $DupViVmInventoryProcessId = (Get-PSHostProcessInfo|?{$(Get-Content -LiteralPath "/proc/$($_.ProcessId)/cmdline") -replace "`0", ' '|?{$_ -match "ViVmInventory"}}).ProcessId[0]
        $DupViVmInventoryProcessTime = [INT32](ps -p $DupViVmInventoryProcessId -o etimes).split()[-1]
        if ($DupViVmInventoryProcessTime -gt 21600) {
            Write-Host "$((Get-Date).ToString("o")) [WARNING] ViVmInventory is already running for more than 6 hours!"
            Write-Host "$((Get-Date).ToString("o")) [WARNING] Killing stunned ViVmInventory"
            Stop-Process -Id $DupViVmInventoryProcessId -Force
        } else {
            AltAndCatchFire "ViVmInventory is already running!"
        }
    }
} catch {
    AltAndCatchFire "ViVmInventory process lookup failure"
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
    foreach ($ViServer in $ViServersList) {
        $ViServerCleanName = $ViServer.Replace(".","_")
        $SessionFile = "/tmp/vmw_" + $ViServerCleanName + ".key"

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
            Write-Host "$((Get-Date).ToString("o")) [WARNING] SessionToken not found, invalid or connection failure"
            Write-Host "$((Get-Date).ToString("o")) [WARNING] Attempting explicit connection ..."
        }

        if (!$($global:DefaultVIServer)) {
            try {
                # $createstorexml = New-Object -TypeName XML
                # $createstorexml.Load($credstore)
                $XPath = '//passwordEntry[server="' + $ViServer + '"]'
                if ($(Select-XML -Xml $createstorexml -XPath $XPath)){
                    $item = Select-XML -Xml $createstorexml -XPath $XPath
                    $CredStoreLogin = $item.Node.username
                    $CredStorePassword = [System.Text.Encoding]::Unicode.GetString([System.Convert]::FromBase64String($item.Node.password))
                } else {
                    Write-Host "$((Get-Date).ToString("o")) [WARNING] No $ViServer entry in CredStore"
                    continue
                }
                $ServerConnection = Connect-VIServer -Server $ViServer -User $CredStoreLogin -Password $CredStorePassword -Force -ErrorAction Stop
                if ($ServerConnection.IsConnected) {
                    # $PwCliContext = Get-PowerCLIContext
                    Write-Host "$((Get-Date).ToString("o")) [INFO] Connected to vCenter $($ServerConnection.Name) version $($ServerConnection.Version) build $($ServerConnection.Build)"
                    $SessionSecretName = "vmw_" + $ViServer.Replace(".","_") + ".key"
                    $ServerConnection.SessionSecret | Out-File -FilePath /tmp/$SessionSecretName -Force
                }
            } catch {
                Write-Host "$((Get-Date).ToString("o")) [WARNING] Explicit connection failed, check the stored credentials for $ViServer !"
                continue
            }
        }

        try {
            if ($($global:DefaultVIServer)) {
                Write-Host "$((Get-Date).ToString("o")) [INFO] Start processing vCenter/ESX $ViServer ..."
                $ServiceInstance = Get-View ServiceInstance -Server $ViServer
            } else {
                Write-Host "$((Get-Date).ToString("o")) [WARNING] global:DefaultVIServer variable check failure for $ViServer"
                continue
            }
        } catch {
            Write-Host "$((Get-Date).ToString("o")) [WARNING] Unable to verify vCenter connection for $ViServer"
            continue
        }

        if ($ServiceInstance) {

            Write-Host "$((Get-Date).ToString("o")) [INFO] Collecting objects in $ViServer ..."

            $DvPgs = Get-View -ViewType DistributedVirtualPortgroup -Property name -Server $ViServer
            $vPgs = Get-View -ViewType Network -Property name -Server $ViServer
            $Vms = Get-View -ViewType virtualmachine -Property name, Parent, Guest.IpAddress, Network, Summary.Storage, Config.Hardware.Device, Runtime.Host, Config.Hardware.NumCPU, Config.Hardware.MemoryMB, Guest.GuestId, summary.config.vmPathName -Server $ViServer
            $esxs = Get-View -ViewType hostsystem -Property name, Parent -Server $ViServer
            $clusters = Get-View -ViewType clustercomputeresource -Property name -Server $ViServer

            $BlueFolders = Get-View -ViewType folder -Property Parent, Name, ChildType -Server $ViServer

            $BlueFolders_name_table = @{}
            $BlueFolders_Parent_table = @{}
            $BlueFolders_type_table = @{}
            
            foreach ($BlueFolder in [array]$BlueFolders) {
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
            
                if ($Vm.Guest.IpAddress) {
                    $VmIpAddress = $Vm.Guest.IpAddress
                } else {
                    $VmIpAddress = "N/A"
                }
                
                if ($vm.network) {
                    $VmNet = $DvPgs_h[$vm.network]
                } else {
                    $VmNet = "N/A"
                }
                
                if ($esxs_h[$vm.Runtime.Host]) {
                    $VmHost = $($esxs_h[$vm.Runtime.Host]).name
                } else {
                    $VmHost = "N/A"
                }
                
                if ($clusters_h[$esxs_h[$vm.Runtime.Host].Parent]) {
                    $VmCluster = $clusters_h[$esxs_h[$vm.Runtime.Host].Parent]
                } else {
                    $VmCluster = "N/A"
                }
                
                if ($Vm.Guest.GuestId) {
                    $VmGuestId = $Vm.Guest.GuestId
                } else {
                    $VmGuestId = "N/A"
                }
                
                try {
                    $VmPath = "N/A"
                    $VmPath = GetBlueFolderFullPath $Vm
                } catch {
                    Write-Host "$((Get-Date).ToString("o")) [WARNING] Unable to get blue folder path for $($Vm.name)"
                }
                
                $ViVmsInfo = "" | Select-Object vCenter, VM, ESX, Cluster, IP, PortGroup, CommittedGB, MAC, GuestId, vCPU, vRAM, vmxPath, Folder
                
                $ViVmsInfo.vCenter = $ViServer
                $ViVmsInfo.VM = $Vm.name
                $ViVmsInfo.ESX = $VmHost
                $ViVmsInfo.Cluster = $VmCluster
                $ViVmsInfo.IP = $VmIpAddress
                $ViVmsInfo.PortGroup = $VmNet -join " ; "
                $ViVmsInfo.CommittedGB = [math]::round($Vm.Summary.Storage.committed/1GB,1)
                $ViVmsInfo.MAC = ($Vm.Config.Hardware.Device|?{$_.MacAddress}).MacAddress -join " ; "
                $ViVmsInfo.GuestId = $VmGuestId
                $ViVmsInfo.vCPU = $Vm.Config.Hardware.NumCPU
                $ViVmsInfo.vRAM = [math]::round($Vm.Config.Hardware.MemoryMB/1KB,1)
                $ViVmsInfo.vmxPath = $Vm.summary.config.vmPathName
                $ViVmsInfo.Folder = $VmPath
                
                # $ViVmsInfo
                $ViVmsInfos += $ViVmsInfo
            }
    
        }
        
        Write-Host "$((Get-Date).ToString("o")) [INFO] Disconnecting from $ViServer ..."
        
        if ($global:DefaultVIServers) {Disconnect-VIServer * -Force -Confirm:0}
    }

    if ($ViVmsInfos) {
        try {
            Write-Host "$((Get-Date).ToString("o")) [INFO] Writing ViVmInventory.csv ..."
            $ViVmsInfos|Export-Csv -NoTypeInformation -Path /mnt/wfs/inventory/ViVmInventory.csv -Force
        } catch {
            AltAndCatchFire "Export-Csv issue"
        }
    }
} else {
    AltAndCatchFire "No VI server to process"
}