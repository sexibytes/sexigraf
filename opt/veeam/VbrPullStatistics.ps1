#!/usr/bin/pwsh -Command
#
param([Parameter (Mandatory=$true)] [string] $Server, [Parameter (Mandatory=$true)] [string] $SessionFile, [Parameter (Mandatory=$false)] [string] $CredStore)

$ScriptVersion = "0.9.11"

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
    Start-Transcript -Path "/var/log/sexigraf/VbrPullStatistics.log" -Append -Confirm:$false -Force -UseMinimalHeader
    Write-Host "$((Get-Date).ToString("o")) [INFO] VbrPullStatistics v$ScriptVersion"
} catch {
    Write-Host "$((Get-Date).ToString("o")) [EROR] VbrPullStatistics logging failure"
    Write-Host "$((Get-Date).ToString("o")) [EROR] Exit"
    exit
}

try {
    Write-Host "$((Get-Date).ToString("o")) [INFO] Importing Graphite PowerShell module ..."
    Import-Module -Name /usr/local/share/powershell/Modules/Graphite-PowerShell-Functions/Graphite-Powershell.psm1 -Global -Force -SkipEditionCheck
} catch {
    AltAndCatchFire "Powershell modules import failure"
}

try {
    Write-Host "$((Get-Date).ToString("o")) [INFO] Looking for another VbrPullStatistics for $Server ..."
    $DupVbrPullStatisticsProcess = Get-PSHostProcessInfo|%{$(Get-Content -LiteralPath "/proc/$($_.ProcessId)/cmdline") -replace "`0", ' '}|?{$_ -match "VbrPullStatistics" -and $_ -match "$Server"}
    # https://github.com/PowerShell/PowerShell/issues/13944
    if (($DupVbrPullStatisticsProcess|Measure-Object).Count -gt 1) {
        $DupVbrPullStatisticsProcessId = (Get-PSHostProcessInfo|?{$(Get-Content -LiteralPath "/proc/$($_.ProcessId)/cmdline") -replace "`0", ' '|?{$_ -match "$Server"}}).ProcessId[0]
        $DupVbrPullStatisticsProcessTime = [INT32](ps -p $DupVbrPullStatisticsProcessId -o etimes).split()[-1]
        if ($DupVbrPullStatisticsProcessTime -gt 300) {
            Write-Host "$((Get-Date).ToString("o")) [WARN] VbrPullStatistics for $Server is already running for more than 5 minutes!"
            Write-Host "$((Get-Date).ToString("o")) [WARN] Killing stunned VbrPullStatistics for $Server"
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
        $SessionToken = Get-Content -Path $SessionFile -ErrorAction Stop
        Write-Host "$((Get-Date).ToString("o")) [INFO] SessionToken found in SessionFile, attempting connection to $Server ..."
        $VbrAuthHeaders = @{"accept" = "application/json";"x-api-version" = "1.0-rev1"; "Authorization" = "Bearer $SessionToken"}
        $VbrJobsStates = Invoke-RestMethod -SkipHttpErrorCheck -SkipCertificateCheck -Method GET -Uri $("https://" + $server + ":9419/api/v1/jobs/states?limit=1") -Headers $VbrAuthHeaders
        if ($($VbrJobsStates.data)) {
            Write-Host "$((Get-Date).ToString("o")) [INFO] Connected to VBR REST API Server $Server"
        } else {
            Write-Host "$((Get-Date).ToString("o")) [WARN] Connection failure or no job state"
        }
    } catch {
        Write-Host "$((Get-Date).ToString("o")) [WARN] SessionToken not found, invalid or connection failure"
    }
    
    if (!$($VbrJobsStates.data)) {
        Write-Host "$((Get-Date).ToString("o")) [WARN] Attempting explicit connection ..."
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
                $VbrJobsStates = Invoke-RestMethod -SkipHttpErrorCheck -SkipCertificateCheck -Method GET -Uri $("https://" + $server + ":9419/api/v1/jobs/states?limit=1") -Headers $VbrAuthHeaders
                if ($($VbrJobsStates.data)) {
                    Write-Host "$((Get-Date).ToString("o")) [INFO] Connected to VBR REST API Server $Server"
                    $SessionSecretName = "vbr_" + $server.Replace(".","_") + ".key"
                    $VbrConnect.access_token | Out-File -FilePath /tmp/$SessionSecretName
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
    Write-Host "$((Get-Date).ToString("o")) [INFO] Start processing VBR Server $Server ..."

    try {
        Write-Host "$((Get-Date).ToString("o")) [INFO] VBR sessions collect ..."
        $VbrRunningSessions = Invoke-RestMethod -SkipHttpErrorCheck -SkipCertificateCheck -Method GET -Uri $("https://" + $server + ":9419/api/v1/sessions?stateFilter=working") -Headers $VbrAuthHeaders
    } catch {
        Write-Host "$((Get-Date).ToString("o")) [EROR] Sessions collect failure"
        Write-Host "$((Get-Date).ToString("o")) [EROR] $($Error[0])"
    }

    Write-Host "$((Get-Date).ToString("o")) [INFO] Building VBR sessions table ..."
    $VbrRunningSessionsIdTable = @{}
    foreach ($VbrSession in $VbrRunningSessions.data) {
        try {
            $VbrRunningSessionsIdTable.add($VbrSession.id,$VbrSession)
        } catch {}
    }

    try {
        Write-Host "$((Get-Date).ToString("o")) [INFO] VBR 5min old objectRestorePoints collect ..."
        # $VbrSessions5 = Invoke-RestMethod -SkipHttpErrorCheck -SkipCertificateCheck -Method GET -Uri $("https://" + $server + ":9419/api/v1/sessions?createdAfterFilter=" + $(($ExecStart.AddMinutes(-5)).ToString("o"))) -Headers $VbrAuthHeaders
        $VbrObjectRestorePoints5 = Invoke-RestMethod -SkipHttpErrorCheck -SkipCertificateCheck -Method GET -Uri $("https://" + $server + ":9419/api/v1/objectRestorePoints?platformNameFilter=VmWare&createdAfterFilter=" + $(($ExecStart.AddMinutes(-5)).ToString("o"))) -Headers $VbrAuthHeaders
    } catch {
        Write-Host "$((Get-Date).ToString("o")) [EROR] objectRestorePoints collect failure"
        Write-Host "$((Get-Date).ToString("o")) [EROR] $($Error[0])"
    }

    if ($VbrObjectRestorePoints5.data.count -gt 0) {
        # Write-Host "$((Get-Date).ToString("o")) [INFO] VBR backupObjects collect ..."
        # $VbrBackupObjects5 = @{}
        # foreach ($VbrObjectRestorePoint5 in $VbrObjectRestorePoints5.data) {
        #     try {
        #         $VbrBackupObjects = Invoke-RestMethod -SkipHttpErrorCheck -SkipCertificateCheck -Method GET -Uri $("https://" + $server + ":9419/api/v1/backupObjects?platformNameFilter=VmWare&nameFilter=" + $($VbrObjectRestorePoint5.name)) -Headers $VbrAuthHeaders
        #         if ($VbrBackupObjects.data[0].type -eq "VM" -and !$VbrBackupObjects5[$VbrBackupObjects.data[0].name]) {
        #             $VbrBackupObjects5.Add($VbrBackupObjects.data[0].name,$VbrBackupObjects[0].data)
        #         }
        #     } catch {
        #         Write-Host "$((Get-Date).ToString("o")) [EROR] backupObjects collect failure"
        #         Write-Host "$((Get-Date).ToString("o")) [EROR] $($Error[0])"
        #     }
        # }

        try {
            Write-Host "$((Get-Date).ToString("o")) [INFO] VBR backupObjects collect ..."
            $VbrBackupObjects = Invoke-RestMethod -SkipHttpErrorCheck -SkipCertificateCheck -Method GET -Uri $("https://" + $server + ":9419/api/v1/backupObjects?platformNameFilter=VmWare&limit=9999") -Headers $VbrAuthHeaders
            if ($VbrBackupObjects.data) {
                Write-Host "$((Get-Date).ToString("o")) [INFO] Building VBR backupObjects table ..."
                $VbrBackupObjectsTable = @{}
                foreach ($VbrBackupObject in $VbrBackupObjects.data) {
                    try {
                        $VbrBackupObjectsTable.add($VbrBackupObject.name,$VbrBackupObject)
                    } catch {}
                }
            }
        } catch {
            Write-Host "$((Get-Date).ToString("o")) [EROR] backupObjects collect failure"
            Write-Host "$((Get-Date).ToString("o")) [EROR] $($Error[0])"
        }

        $VbrObjectRestorePoints5SessionsId = $VbrObjectRestorePoints5.data.backupId|Select-Object -Unique

        Write-Host "$((Get-Date).ToString("o")) [INFO] VBR Sessions collect ..."
        $VbrSessions5 = @{}
        foreach ($VbrObjectRestorePoints5SessionId in $VbrObjectRestorePoints5SessionsId) {
            try {
                $VbrObjectRestorePoints5Session = Invoke-RestMethod -SkipHttpErrorCheck -SkipCertificateCheck -Method GET -Uri $("https://" + $server + ":9419/api/v1/backups/" + $VbrObjectRestorePoints5SessionId) -Headers $VbrAuthHeaders
                if ($VbrObjectRestorePoints5Session) {
                    $VbrSessions5.Add($VbrObjectRestorePoints5SessionId,$VbrObjectRestorePoints5Session)
                }
            } catch {
                Write-Host "$((Get-Date).ToString("o")) [EROR] backupObjects collect failure"
                Write-Host "$((Get-Date).ToString("o")) [EROR] $($Error[0])"
            }
        }

        $VbrObjectRestorePointTable = @{}
        
        $vbrserver_name = NameCleaner $Server

        foreach ($VbrObjectRestorePoint in $VbrObjectRestorePoints5.data) {
            $vcenter_name = NameCleaner $VbrBackupObjectsTable[$VbrObjectRestorePoint.name].path.split("\")[0]
            $vm_name = NameCleaner $VbrBackupObjectsTable[$VbrObjectRestorePoint.name].name
            $job_name = NameCleaner $VbrSessions5[$VbrObjectRestorePoint.backupId].name
            $VbrObjectRestorePointTable["veeam.vi.$vcenter_name.vm.$vm_name"] ++
            $VbrObjectRestorePointTable["veeam.vbr.$vbrserver_name.job.$job_name"] ++
        }

        
        $VbrObjectRestorePointTable["vi.$vbrserver_name.vi.exec.duration"] = $($(Get-Date).ToUniversalTime() - $ExecStart).TotalSeconds
        Write-Host "$((Get-Date).ToString("o")) [INFO] Sending veeam data to Graphite for VBR server $Server ..."
        Send-BulkGraphiteMetrics -CarbonServer 127.0.0.1 -CarbonServerPort 2003 -Metrics $VbrObjectRestorePointTable -DateTime $ExecStart

    }

    Write-Host "$((Get-Date).ToString("o")) [INFO] End of VBR server $server processing ..."

} else {
    Write-Host "$((Get-Date).ToString("o")) [INFO] No Running Jobs on VBR server $server ..."
    Write-Host "$((Get-Date).ToString("o")) [INFO] Exit"
    Stop-Transcript
    exit
}