#!/usr/bin/pwsh -Command
#
param([Parameter (Mandatory=$true)] [string] $Server, [Parameter (Mandatory=$true)] [string] $SessionFile, [Parameter (Mandatory=$false)] [string] $CredStore)

$ScriptVersion = "0.9.39"

$ExecStart = $(Get-Date).ToUniversalTime()
# $stopwatch =  [system.diagnostics.stopwatch]::StartNew()

$ErrorActionPreference = "SilentlyContinue"
$WarningPreference = "SilentlyContinue"
(Get-Process -Id $pid).PriorityClass = 'Idle'
$SexiVbrMutex = New-Object System.Threading.Mutex($false, "SexiVbrMutex")
# https://learn-powershell.net/2014/09/30/using-mutexes-to-write-data-to-the-same-logfile-across-processes-with-powershell/
# https://github.com/ryan-leap/GreenMeansGoMutexDemo

function SexiLogger {
    param($Text2Log)
    Write-Host "$((Get-Date).ToString("o")) $Text2Log"
    $null = $SexiVbrMutex.WaitOne(500)
    Add-Content -Path "/var/log/sexigraf/VbrPullStatistics.log" -Value "$((Get-Date).ToString("o")) $($Server) $Text2Log"
    $SexiVbrMutex.ReleaseMutex()
}

function AltAndCatchFire {
    Param($ExitReason)
    SexiLogger "[EROR] $ExitReason"
    SexiLogger "[EROR] $($Error[0])"
    SexiLogger "[EROR] Exit"
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


try {
    Start-Transcript -Path "/var/log/sexigraf/VbrPullStatistics.$($Server).log" -Append -Confirm:$false -Force -UseMinimalHeader
    SexiLogger "[INFO] VbrPullStatistics v$ScriptVersion"
} catch {
    SexiLogger "[EROR] VbrPullStatistics logging failure"
    SexiLogger "[EROR] Exit"
    exit
}

try {
    SexiLogger "[INFO] Importing Graphite PowerShell module ..."
    Import-Module -Name /usr/local/share/powershell/Modules/Graphite-PowerShell-Functions/Graphite-Powershell.psm1 -Global -Force -SkipEditionCheck
} catch {
    AltAndCatchFire "Powershell modules import failure"
}

try {
    SexiLogger "[INFO] Looking for another VbrPullStatistics for $Server ..."
    $DupVbrPullStatisticsProcess = Get-PSHostProcessInfo|%{$(Get-Content -LiteralPath "/proc/$($_.ProcessId)/cmdline") -replace "`0", ' '}|?{$_ -match "VbrPullStatistics" -and $_ -match "$Server"}
    # https://github.com/PowerShell/PowerShell/issues/13944
    if (($DupVbrPullStatisticsProcess|Measure-Object).Count -gt 1) {
        $DupVbrPullStatisticsProcessId = (Get-PSHostProcessInfo|?{$(Get-Content -LiteralPath "/proc/$($_.ProcessId)/cmdline") -replace "`0", ' '|?{$_ -match "$Server"}}).ProcessId[0]
        $DupVbrPullStatisticsProcessTime = [INT32](ps -p $DupVbrPullStatisticsProcessId -o etimes).split()[-1]
        if ($DupVbrPullStatisticsProcessTime -gt 300) {
            SexiLogger "[WARN] VbrPullStatistics for $Server is already running for more than 5 minutes!"
            SexiLogger "[WARN] Killing stunned VbrPullStatistics for $Server"
            Stop-Process -Id $DupVbrPullStatisticsProcessId -Force
        } else {
            AltAndCatchFire "VbrPullStatistics for $Server is already running!"
        }
    }
} catch {
    AltAndCatchFire "VbrPullStatistics process lookup failure"
}

if ($SessionFile) {
    try {
        $SessionSecretExpiration = "vbr_" + $server.Replace(".","_") + ".exp"
        if ([DateTime]$(Get-Content -Path /tmp/$SessionSecretExpiration) -gt $ExecStart.AddMinutes(5)) {
            $SessionToken = Get-Content -Path $SessionFile -ErrorAction Stop
            SexiLogger "[INFO] SessionToken found in SessionFile, attempting connection to $Server ..."
            $VbrAuthHeaders = @{"accept" = "application/json";"x-api-version" = "1.0-rev1"; "Authorization" = "Bearer $SessionToken"}
            $VbrJobsStates = Invoke-RestMethod -SkipHttpErrorCheck -SkipCertificateCheck -Method GET -Uri $("https://" + $server + ":9419/api/v1/jobs/states") -Headers $VbrAuthHeaders
            if ($($VbrJobsStates.data)) {
                SexiLogger "[INFO] Connected to VBR REST API Server $Server"
            } else {
                SexiLogger "[WARN] Connection failure or no job state"
            }
        } else {
            SexiLogger "[WARN] Token has expired or is about to ..."
        }
    } catch {
        SexiLogger "[WARN] SessionToken or SessionSecretExpiration not found, invalid or connection failure"
    }

    if (!$($VbrJobsStates.data)) {
        SexiLogger "[WARN] Attempting token refresh ..."
        try {
            $SessionRefreshPath = "vbr_" + $server.Replace(".","_") + ".dat"
            $SessionRefresh = Get-Content -Path /tmp/$SessionRefreshPath -ErrorAction Stop
            $VbrHeaders = @{"accept" = "application/json";"x-api-version" = "1.0-rev1"}
            $VbrBody = @{grant_type = "refresh_token";username = "";password = "";refresh_token = $SessionRefresh;code = "";use_short_term_refresh = ""}
            $VbrConnect = Invoke-RestMethod -SkipHttpErrorCheck -SkipCertificateCheck -Method POST -Uri $("https://" + $server + ":9419/api/oauth2/token") -Headers $VbrHeaders -ContentType "application/x-www-form-urlencoded" -Body $VbrBody
            if ($VbrConnect.access_token) {
                $SessionSecretName = "vbr_" + $server.Replace(".","_") + ".key"
                $SessionSecretExpiration = "vbr_" + $server.Replace(".","_") + ".exp"
                $VbrConnect.access_token | Out-File -FilePath /tmp/$SessionSecretName
                $VbrConnect.refresh_token | Out-File -FilePath /tmp/$SessionRefreshPath
                $VbrConnect.".expires".ToUniversalTime().tostring() | Out-File -FilePath /tmp/$SessionSecretExpiration
                $SessionToken = $VbrConnect.access_token
                $VbrAuthHeaders = @{"accept" = "application/json";"x-api-version" = "1.0-rev1"; "Authorization" = "Bearer $($VbrConnect.access_token)"}
                $VbrJobsStates = Invoke-RestMethod -SkipHttpErrorCheck -SkipCertificateCheck -Method GET -Uri $("https://" + $server + ":9419/api/v1/jobs/states") -Headers $VbrAuthHeaders
                if (!$($VbrJobsStates.data)) {
                    SexiLogger "[WARN] Token refresh failed!"
                    SexiLogger "[WARN] Known issue on v11!"
                    # https://forums.veeam.com/restful-api-f30/how-to-handle-the-refresh-token-t74916.html
                }
            } else {
                SexiLogger "[WARN] Token refresh failed!"
            }
        } catch {
            SexiLogger "[WARN] Token refresh issue!"
        }
    }
    
    if (!$($VbrJobsStates.data)) {
        SexiLogger "[WARN] Attempting explicit connection ..."
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
            $VbrHeaders = @{"accept" = "application/json";"x-api-version" = "1.0-rev1"}
            $VbrBody = @{grant_type = "password";username = $CredStoreLogin;password = $CredStorePassword;refresh_token = "";code = "";use_short_term_refresh = ""}
            $VbrConnect = Invoke-RestMethod -SkipHttpErrorCheck -SkipCertificateCheck -Method POST -Uri $("https://" + $server + ":9419/api/oauth2/token") -Headers $VbrHeaders -ContentType "application/x-www-form-urlencoded" -Body $VbrBody
            if ($VbrConnect.access_token) {
                $VbrAuthHeaders = @{"accept" = "application/json";"x-api-version" = "1.0-rev1"; "Authorization" = "Bearer $($VbrConnect.access_token)"}
                $VbrJobsStates = Invoke-RestMethod -SkipHttpErrorCheck -SkipCertificateCheck -Method GET -Uri $("https://" + $server + ":9419/api/v1/jobs/states") -Headers $VbrAuthHeaders
                if ($($VbrJobsStates.data)) {
                    SexiLogger "[INFO] Connected to VBR REST API Server $Server"
                    $SessionSecretName = "vbr_" + $server.Replace(".","_") + ".key"
                    $SessionRefreshPath = "vbr_" + $server.Replace(".","_") + ".dat"
                    $SessionSecretExpiration = "vbr_" + $server.Replace(".","_") + ".exp"
                    $VbrConnect.access_token | Out-File -FilePath /tmp/$SessionSecretName
                    $VbrConnect.refresh_token | Out-File -FilePath /tmp/$SessionRefreshPath
                    $VbrConnect.".expires".ToUniversalTime().tostring() | Out-File -FilePath /tmp/$SessionSecretExpiration
                    $SessionToken = $VbrConnect.access_token
                } else {
                    AltAndCatchFire "Jobs States check failed, no job state or check the user permissions!"
                }
            } else {
                AltAndCatchFire "Explicit connection failed, check the stored credentials!"
            }
        } catch {
            AltAndCatchFire "Explicit connection failed, check the stored credentials!"
        }
    }
} else {
    AltAndCatchFire "No SessionFile somehow ..."
}

if ($($VbrJobsStates.data)) {
    $VbrAuthHeaders = @{"accept" = "application/json";"x-api-version" = "1.0-rev1"; "Authorization" = "Bearer $SessionToken"}
    $VbrDataTable = @{}
    $vbrserver_name = NameCleaner $Server
    SexiLogger "[INFO] Start processing VBR Server $Server ..."

    $VbrJobsStatesTable = @{}
    foreach ($VbrJobState in $VbrJobsStates.data) {
        try {
            $VbrJobsStatesTable.add($VbrJobState.id,$VbrJobState)
        } catch {}
        $job_name = NameCleaner $VbrJobState.name
        if ($VbrJobState.status -eq "running") {
            $VbrJobStateStatus = 0
        } elseif ($VbrJobState.status -eq "inactive") {
            $VbrJobStateStatus = 1
        } elseif ($VbrJobState.status -eq "disabled") {
            $VbrJobStateStatus = 2
        } else {
            $VbrJobStateStatus = 3
        }
        $VbrDataTable["veeam.vbr.$vbrserver_name.job.$job_name.status"] = $VbrJobStateStatus
    }

    try {
        SexiLogger "[INFO] VBR repositories states collect ..."
        $VbrRepositoriesStates = Invoke-RestMethod -SkipHttpErrorCheck -SkipCertificateCheck -Method GET -Uri $("https://" + $server + ":9419/api/v1/backupInfrastructure/repositories/states") -Headers $VbrAuthHeaders
    } catch {
        SexiLogger "[EROR] repositories states collect failure"
        SexiLogger "[EROR] $($Error[0])"
    } 

    if ($VbrRepositoriesStates.data) {
        SexiLogger "[INFO] VBR repositories processing ..."
        $VbrRepositoryTable = @{}
        foreach ($VbrRepository in $VbrRepositoriesStates.data) {
            $VbrRepositoryName = NameCleaner $VbrRepository.name

            $VbrDataTable["veeam.vbr.$vbrserver_name.repo.$VbrRepositoryName.capacityGB"] = $VbrRepository.capacityGB
            $VbrDataTable["veeam.vbr.$vbrserver_name.repo.$VbrRepositoryName.freeGB"] = $VbrRepository.freeGB
            $VbrDataTable["veeam.vbr.$vbrserver_name.repo.$VbrRepositoryName.usedSpaceGB"] = $VbrRepository.usedSpaceGB
            $VbrDataTable["veeam.vbr.$vbrserver_name.repo.$VbrRepositoryName.RealUsedPct"] = $($VbrRepository.usedSpaceGB * 100 / $($VbrRepository.usedSpaceGB + $VbrRepository.freeGB ))

            try {
                $VbrRepositoryTable.add($VbrRepository.id,$VbrRepository)
            } catch {}
        }
    } else {
        SexiLogger "[WARN] No repositories ?!"
    }

    try {
        SexiLogger "[INFO] VBR ScaleOutRepositories collect ..."
        $VbrScaleOutRepositories = Invoke-RestMethod -SkipHttpErrorCheck -SkipCertificateCheck -Method GET -Uri $("https://" + $server + ":9419/api/v1/backupInfrastructure/scaleOutRepositories") -Headers $VbrAuthHeaders
    } catch {
        SexiLogger "[EROR] ScaleOutRepositories collect failure"
        SexiLogger "[EROR] $($Error[0])"
    }

    if ($VbrScaleOutRepositories.data) {
        SexiLogger "[INFO] SOBR performanceTier processing ..."
        foreach ($VbrScaleOutRepository in $VbrScaleOutRepositories.data) {
            try {
                $VbrScaleOutRepositoryName = NameCleaner $VbrScaleOutRepository.name

                $VbrSobrNotNormal = $VbrScaleOutRepository.performanceTier.performanceExtents|?{$_.status -ne "Normal"}

                if ($VbrSobrNotNormal.id) {
                    $VbrSobrNotNormalRepos = $VbrRepositoryTable[$VbrSobrNotNormal.id]
                    $VbrDataTable["veeam.vbr.$vbrserver_name.sobr.$VbrScaleOutRepositoryName.capacityGB"] += $($VbrSobrNotNormalRepos|Measure-Object -Sum -Property capacityGB).Sum
                    $VbrDataTable["veeam.vbr.$vbrserver_name.sobr.$VbrScaleOutRepositoryName.usedSpaceGB"] += $($VbrSobrNotNormalRepos|Measure-Object -Sum -Property usedSpaceGB).Sum
                }

                $VbrSobrNormal = $VbrScaleOutRepository.performanceTier.performanceExtents|?{$_.status -eq "Normal"}
                if ($VbrSobrNormal.id) {
                    $VbrSobrNormalRepos = $VbrRepositoryTable[$VbrSobrNormal.id]
                    $VbrDataTable["veeam.vbr.$vbrserver_name.sobr.$VbrScaleOutRepositoryName.capacityGB"] += $($VbrSobrNormalRepos|Measure-Object -Sum -Property capacityGB).Sum
                    $VbrDataTable["veeam.vbr.$vbrserver_name.sobr.$VbrScaleOutRepositoryName.usedSpaceGB"] += $($VbrSobrNormalRepos|Measure-Object -Sum -Property usedSpaceGB).Sum
                    $VbrDataTable["veeam.vbr.$vbrserver_name.sobr.$VbrScaleOutRepositoryName.freeGB"] = $($VbrSobrNormalRepos|Measure-Object -Sum -Property freeGB).Sum
                    $VbrDataTable["veeam.vbr.$vbrserver_name.sobr.$VbrScaleOutRepositoryName.RealUsedPct"] = $($VbrDataTable["veeam.vbr.$vbrserver_name.sobr.$VbrScaleOutRepositoryName.usedSpaceGB"] * 100 / $($VbrDataTable["veeam.vbr.$vbrserver_name.sobr.$VbrScaleOutRepositoryName.usedSpaceGB"] + $VbrDataTable["veeam.vbr.$vbrserver_name.sobr.$VbrScaleOutRepositoryName.freeGB"]))
                } else {
                    $VbrDataTable["veeam.vbr.$vbrserver_name.sobr.$VbrScaleOutRepositoryName.freeGB"] = 0
                    $VbrDataTable["veeam.vbr.$vbrserver_name.sobr.$VbrScaleOutRepositoryName.RealUsedPct"] = 100
                }
            } catch {
                SexiLogger "[EROR] Issue processing SOBR $($VbrScaleOutRepository.name)"
                SexiLogger "[EROR] $($Error[0])"
            }
        }
    } else {
        SexiLogger "[INFO] No SOBR"
    }

    try {
        SexiLogger "[INFO] VBR 5min old objectRestorePoints collect ..."
        # $VbrSessions5 = Invoke-RestMethod -SkipHttpErrorCheck -SkipCertificateCheck -Method GET -Uri $("https://" + $server + ":9419/api/v1/sessions?createdAfterFilter=" + $(($ExecStart.AddMinutes(-5)).ToString("o"))) -Headers $VbrAuthHeaders
        $VbrObjectRestorePoints5 = Invoke-RestMethod -SkipHttpErrorCheck -SkipCertificateCheck -Method GET -Uri $("https://" + $server + ":9419/api/v1/objectRestorePoints?platformNameFilter=VmWare&limit=999&createdAfterFilter=" + $(($ExecStart.AddMinutes(-5)).ToString("o"))) -Headers $VbrAuthHeaders
    } catch {
        SexiLogger "[EROR] objectRestorePoints collect failure"
        SexiLogger "[EROR] $($Error[0])"
    }

    # $VbrVmwareServers = Invoke-RestMethod -SkipHttpErrorCheck -SkipCertificateCheck -Method GET -Uri $("https://" + $server + ":9419/api/v1/inventory/vmware/hosts") -Headers $VbrAuthHeaders
    

    if ($VbrObjectRestorePoints5.data) {
        # SexiLogger "[INFO] VBR backupObjects collect ..."
        # $VbrBackupObjects5 = @{}
        # foreach ($VbrObjectRestorePoint5 in $VbrObjectRestorePoints5.data) {
        #     try {
        #         $VbrBackupObjects = Invoke-RestMethod -SkipHttpErrorCheck -SkipCertificateCheck -Method GET -Uri $("https://" + $server + ":9419/api/v1/backupObjects?platformNameFilter=VmWare&nameFilter=" + $($VbrObjectRestorePoint5.name)) -Headers $VbrAuthHeaders
        #         if ($VbrBackupObjects.data[0].type -eq "VM" -and !$VbrBackupObjects5[$VbrBackupObjects.data[0].name]) {
        #             $VbrBackupObjects5.Add($VbrBackupObjects.data[0].name,$VbrBackupObjects[0].data)
        #         }
        #     } catch {
        #         SexiLogger "[EROR] backupObjects collect failure"
        #         SexiLogger "[EROR] $($Error[0])"
        #     }
        # } # Too Slow !!!

        try {
            SexiLogger "[INFO] VBR backupObjects collect ..."
            $VbrBackupObjects = Invoke-RestMethod -SkipHttpErrorCheck -SkipCertificateCheck -Method GET -Uri $("https://" + $server + ":9419/api/v1/backupObjects?platformNameFilter=VmWare&limit=9999") -Headers $VbrAuthHeaders # TODO limit=9999+ ?
            if ($VbrBackupObjects.data) {
                SexiLogger "[INFO] Building VBR backupObjects table ..."
                $VbrBackupObjectsTable = @{}
                foreach ($VbrBackupObject in $VbrBackupObjects.data) {
                    try {
                        $VbrBackupObjectsTable.add($VbrBackupObject.name,$VbrBackupObject)
                    } catch {}
                }
            }
        } catch {
            SexiLogger "[EROR] backupObjects collect failure"
            SexiLogger "[EROR] $($Error[0])"
        }

        $VbrObjectRestorePoints5SessionsId = $VbrObjectRestorePoints5.data.backupId|Select-Object -Unique

        SexiLogger "[INFO] VBR Sessions collect ..."
        $VbrSessions5 = @{}
        foreach ($VbrObjectRestorePoints5SessionId in $VbrObjectRestorePoints5SessionsId) {
            try {
                $VbrObjectRestorePoints5Session = Invoke-RestMethod -SkipHttpErrorCheck -SkipCertificateCheck -Method GET -Uri $("https://" + $server + ":9419/api/v1/backups/" + $VbrObjectRestorePoints5SessionId) -Headers $VbrAuthHeaders
                if ($VbrObjectRestorePoints5Session|?{$_.jobId -ne  "00000000-0000-0000-0000-000000000000"}) {
                    $VbrSessions5.Add($VbrObjectRestorePoints5SessionId,$VbrObjectRestorePoints5Session)
                }
            } catch {
                SexiLogger "[EROR] backupObjects collect failure"
                SexiLogger "[EROR] $($Error[0])"
            }
        }

        if (Test-Path /mnt/wfs/inventory/ViVmInventory.csv) {
            SexiLogger "[INFO] Importing VM inventory ..."
            try {
                $ViVmInventory = $(Import-Csv -Path /mnt/wfs/inventory/ViVmInventory.csv -ErrorAction Stop)
            } catch {
                SexiLogger "[EROR] ViVmInventory import issue"
                SexiLogger "[EROR] $($Error[0])"
            }

            if ($ViVmInventory) {
                $ViVmInventoryTable = @{}
                foreach ($ViVm in $ViVmInventory) {
                    try {
                        $ViVmInventoryTable.Add($ViVm.vm,$ViVm)
                    } catch {}
                }

                if (Test-Path /mnt/wfs/inventory/VbrInv_$($Server).csv) {
                    SexiLogger "[INFO] Importing $($Server) VBR inventory ..."
                    try {
                        $VbrVmInventory = $(Import-Csv -Path /mnt/wfs/inventory/VbrInv_$($Server).csv -ErrorAction Stop)
                    } catch {
                        SexiLogger "[EROR] VbrVmInventory import issue"
                        SexiLogger "[EROR] $($Error[0])"
                    }
                    if ($ViVmInventory) {
                        $VbrVmInventoryTable = @{}
                        foreach ($VbrVm in $VbrVmInventory) {
                            try {
                                if ($ViVmInventoryTable[$VbrVm.vm]) {
                                    $VbrVmInventoryTable.Add($VbrVm.vm,$VbrVm)
                                }
                            } catch {}
                        }
                    }
                } else {
                    $VbrVmInventoryTable = @{}
                }

                SexiLogger "[INFO] Building $($Server) VBR DataTable and inventory ..."
                foreach ($VbrObjectRestorePoint in $VbrObjectRestorePoints5.data) {
                    if ($VbrJobsStatesTable[$VbrSessions5[$VbrObjectRestorePoint.backupId].jobId]) {
                        $job_name = NameCleaner $VbrSessions5[$VbrObjectRestorePoint.backupId].name
                        $VbrDataTable["veeam.vbr.$vbrserver_name.job.$job_name.objectRestorePoints"] ++
                        $vm_name = NameCleaner $VbrBackupObjectsTable[$VbrObjectRestorePoint.name].name
                        if ($ViVmInventoryTable[$vm_name]) {
                            $vcenter_name = NameCleaner $ViVmInventoryTable[$vm_name].vCenter
                            if ($ViVmInventoryTable[$vm_name].Cluster) {
                                $cluster_name = NameCleaner $ViVmInventoryTable[$vm_name].Cluster
                            } else {
                                $cluster_name = NameCleaner $ViVmInventoryTable[$vm_name].ESX
                            }
                            $VbrDataTable["veeam.vi.$vcenter_name.$cluster_name.objectRestorePoints"] ++
                            $VbrDataTable["veeam.vi.$vcenter_name.$cluster_name.vm.$vm_name.restorePointsCount"] = $VbrBackupObjectsTable[$VbrObjectRestorePoint.name].restorePointsCount

                            $VbrObjectInventoryInfo  = "" | Select-Object VbrServer, JobName, vCenter, Cluster, VM, RestorePointsCount, LastRestorePoint
                            $VbrObjectInventoryInfo.VbrServer = $vbrserver_name
                            $VbrObjectInventoryInfo.JobName = $job_name
                            $VbrObjectInventoryInfo.vCenter = $vcenter_name
                            $VbrObjectInventoryInfo.Cluster = $cluster_name
                            $VbrObjectInventoryInfo.VM = $vm_name
                            $VbrObjectInventoryInfo.RestorePointsCount = $VbrBackupObjectsTable[$VbrObjectRestorePoint.name].restorePointsCount
                            $VbrObjectInventoryInfo.LastRestorePoint = $VbrObjectRestorePoint.creationTime
                            if ($VbrVmInventoryTable[$vm_name]) {
                                $VbrVmInventoryTable[$vm_name] = $VbrObjectInventoryInfo
                            } else {
                                $VbrVmInventoryTable.add($vm_name,$VbrObjectInventoryInfo)
                            }
                        }
                    }
                }

                if ($VbrVmInventoryTable.Values) {
                    SexiLogger "[INFO] Exporting $($Server) VBR inventory ..."
                    try {
                        $VbrVmInventoryTable.Values|Sort-Object VM|Export-Csv /mnt/wfs/inventory/VbrInv_$($Server).csv -ErrorAction Stop -Force
                    } catch {
                        SexiLogger "[EROR] VbrVmInventory import issue"
                        SexiLogger "[EROR] $($Error[0])"
                    }

                    if ($(Get-ChildItem "/mnt/wfs/inventory/VbrVmInventory.*.csv")) {
                        SexiLogger "[INFO] Rotating VbrVmInventory.*.csv files ..."
                        $ExtraCsvFiles = Compare-Object  $(Get-ChildItem "/mnt/wfs/inventory/VbrVmInventory.*.csv")  $(Get-ChildItem "/mnt/wfs/inventory/VbrVmInventory.*.csv"|Sort-Object LastWriteTime | Select-Object -Last 10) -property Name | ?{$_.SideIndicator -eq "<="}
                        If ($ExtraCsvFiles) {
                            try {
                                Get-ChildItem $ExtraCsvFiles.name | Remove-Item -Force -Confirm:$false
                            } catch {
                                AltAndCatchFire "Cannot remove extra csv files"
                            }
                        }
                    }

                    SexiLogger "[INFO] Import/Export VBR inventories ..."
                    try {
                        $VbrVmInventoryCsv = Import-Csv $(Get-ChildItem /mnt/wfs/inventory/VbrInv_*.csv).fullname | Sort-Object LastRestorePoint -Descending
                        $VbrVmInventoryCsv | Export-Csv /mnt/wfs/inventory/VbrVmInventory.csv -ErrorAction Stop -Force
                        if ($ExecStart.DayOfWeek -match "Monday" -and $ExecStart.Hour -match "1") {
                            $VbrVmInventoryCsv | Export-Csv /mnt/wfs/inventory/VbrVmInventory.$((Get-Date).ToString("yyyy.MM.dd_hh.mm.ss")).csv -ErrorAction Stop -Force
                        }
                    } catch {
                        SexiLogger "[EROR] Import/Export VBR inventories issue"
                        SexiLogger "[EROR] $($Error[0])"
                    }
                } else {
                    SexiLogger "[EROR] No VbrVmInventoryTable values ?!"
                }
            } else {
                SexiLogger "[EROR] ViVmInventory import issue"
            }
        } else {
            SexiLogger "[EROR] No ViVmInventory"
        }
    }

    try {
        SexiLogger "[INFO] VBR ended sessions collect ..."
        $VbrEndedSessions = Invoke-RestMethod -SkipHttpErrorCheck -SkipCertificateCheck -Method GET -Uri $("https://" + $server + ":9419/api/v1/sessions?endedAfterFilter=" + $(($ExecStart.AddMinutes(-5)).ToString("o"))) -Headers $VbrAuthHeaders
    } catch {
        SexiLogger "[EROR] Sessions collect failure"
        SexiLogger "[EROR] $($Error[0])"
    }

    if ($VbrEndedSessions.data) {
        SexiLogger "[INFO] Processing VBR ended sessions ..."
        foreach ($VbrEndedSession in $VbrEndedSessions.data) {
            $job_name = NameCleaner $VbrEndedSession.name
            if ($VbrEndedSession.result.result -eq "Success") {
                $VbrEndedSessionResult = 0
            } elseif ($VbrEndedSession.result.result -eq "Warning") {
                $VbrEndedSessionResult = 1
            } elseif ($VbrEndedSession.result.result -eq "Failed") {
                $VbrEndedSessionResult = 2
            } else {
                $VbrEndedSessionResult = 3
            }
            $VbrDataTable["veeam.vbr.$vbrserver_name.job.$job_name.result"] = $VbrEndedSessionResult
        }
    }

    $VbrDataTable["veeam.vbr.$vbrserver_name.exec.duration"] = $($(Get-Date).ToUniversalTime() - $ExecStart).TotalSeconds
    SexiLogger "[INFO] Sending veeam data to Graphite for VBR server $Server ..."
    Send-BulkGraphiteMetrics -CarbonServer 127.0.0.1 -CarbonServerPort 2003 -Metrics $VbrDataTable -DateTime $ExecStart

    SexiLogger "[INFO] End of VBR server $server processing ..."

} else {
    SexiLogger "[INFO] No Running Jobs on VBR server $server ..."
    SexiLogger "[INFO] Exit"
    Stop-Transcript
    exit
}