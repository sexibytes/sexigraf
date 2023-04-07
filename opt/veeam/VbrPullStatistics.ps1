#!/usr/bin/pwsh -Command
#
param([Parameter (Mandatory=$true)] [string] $Server, [Parameter (Mandatory=$true)] [string] $SessionFile, [Parameter (Mandatory=$false)] [string] $CredStore)

$ScriptVersion = "0.9.1"

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
        $VbrServices = Invoke-RestMethod -SkipHttpErrorCheck -SkipCertificateCheck -Method GET -Uri $("https://" + $server + ":9419/api/v1/services") -Headers $VbrAuthHeaders
        if ($($VbrServices.data.name)) {
            Write-Host "$((Get-Date).ToString("o")) [INFO] Connected to VBR REST API Server $Server"
        }
    } catch {
        Write-Host "$((Get-Date).ToString("o")) [WARN] SessionToken not found, invalid or connection failure"
        Write-Host "$((Get-Date).ToString("o")) [WARN] Attempting explicit connection ..."
    }
    
    if (!$($VbrServices.data.name)) {
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
            if ($($VbrServices.data.name)) {
                Write-Host "$((Get-Date).ToString("o")) [INFO] Connected to VBR REST API Server $Server"
                $SessionSecretName = "vbr_" + $server.Replace(".","_") + ".key"
                $VbrConnect.access_token | Out-File -FilePath /tmp/$SessionSecretName
            }
        } catch {
            AltAndCatchFire "Explicit connection failed, check the stored credentials!"
        }
    }
} else {
    AltAndCatchFire "No SessionFile somehow ..."
}

if ($($VbrServices.data.name) -match "Backup") {
    $VbrAuthHeaders = @{"accept" = "application/json";"x-api-version" = "1.0-rev1"; "Authorization" = "Bearer $($VbrConnect.access_token)";"limit" = "9999"}
    Write-Host "$((Get-Date).ToString("o")) [INFO] Start processing VBR Server $Server ..."

    try {
        Write-Host "$((Get-Date).ToString("o")) [INFO] VBR jobs states collect ..."
        $VbrJobsStates = Invoke-RestMethod -SkipHttpErrorCheck -SkipCertificateCheck -Method GET -Uri $("https://" + $server + ":9419/api/v1/jobs/states") -Headers $VbrAuthHeaders
    } catch {
        Write-Host "$((Get-Date).ToString("o")) [EROR] VbrJobsStates collect failure"
        Write-Host "$((Get-Date).ToString("o")) [EROR] $($Error[0])"
    }

    try {
        Write-Host "$((Get-Date).ToString("o")) [INFO] VBR backupObjects collect ..."
        $VbrBackupObjects = Invoke-RestMethod -SkipHttpErrorCheck -SkipCertificateCheck -Method GET -Uri $("https://" + $server + ":9419/api/v1/backupObjects") -Headers $VbrAuthHeaders
    } catch {
        Write-Host "$((Get-Date).ToString("o")) [EROR] backupObjects collect failure"
        Write-Host "$((Get-Date).ToString("o")) [EROR] $($Error[0])"
    }

    try {
        Write-Host "$((Get-Date).ToString("o")) [INFO] VBR 5min old objectRestorePoints collect ..."
        $VbrObjectRestorePoints5 = Invoke-RestMethod -SkipHttpErrorCheck -SkipCertificateCheck -Method GET -Uri $("https://" + $server + ":9419/api/v1/objectRestorePoints?createdAfterFilter=" + $(($ExecStart.AddMinutes(-5)).ToString("o"))) -Headers $VbrAuthHeaders
    } catch {
        Write-Host "$((Get-Date).ToString("o")) [EROR] objectRestorePoints collect failure"
        Write-Host "$((Get-Date).ToString("o")) [EROR] $($Error[0])"
    }

} else {
    AltAndCatchFire "VbrServices variable check failure"
}

