#!/usr/bin/pwsh
#
param([Parameter (Mandatory=$true)] [string] $Server, [Parameter (Mandatory=$true)] [string] $SessionFile, [Parameter (Mandatory=$false)] [string] $CredStore)

$ExecStart = Get-Date
$ScriptVersion = "0.9.1"

function AltAndCatchFire {
    Param([string] $ExitReason)
    Write-Host "$((Get-Date).ToString("o")) [ERROR] $ExitReason"
    Write-Host "$((Get-Date).ToString("o")) [ERROR] Exit"
    Stop-Transcript
    exit
}

try {
    Start-Transcript -Path "/var/log/sexigraf/VsanDisksPullStatistics.$($server).log" -Append -Confirm:$false -Force
    Write-Host "$((Get-Date).ToString("o")) [DEBUG] VsanDisksPullStatistics v$ScriptVersion"
} catch {
    Write-Host "$((Get-Date).ToString("o")) [ERROR] VsanDisksPullStatistics logging failure"
    Write-Host "$((Get-Date).ToString("o")) [ERROR] Exit"
    exit
}

try {
    Write-Host "$((Get-Date).ToString("o")) [INFO] Looking for another VsanPullStatistics for $Server"
    $DupVsanPullStatisticsProcess = Get-PSHostProcessInfo|%{$(Get-Content -LiteralPath "/proc/$($_.ProcessId)/cmdline") -replace "`0", ' '}|?{$_ -match "VsanPullStatistics" -and $_ -match "$Server"}
    if ($DupVsanPullStatisticsProcess) {
        AltAndCatchFire "VsanPullStatistics for $server is already running!"
    }
} catch {
    # Write-Host "$((Get-Date).ToString("o")) [ERROR] VsanDisksPullStatistics process lookup failure"
    # Write-Host "$((Get-Date).ToString("o")) [ERROR] Exit"
    # Stop-Transcript
    # exit
    AltAndCatchFire "VsanDisksPullStatistics process lookup failure"
}

if ($SessionFile) {
    try {
        $SessionToken = (Get-Content -Path $SessionFile -Force -Delimiter '\"')[1]
        Write-Host "$((Get-Date).ToString("o")) [INFO] SessionToken found in SessionFile, attempting connection to $Server"
        $PowerCliConfig = Set-PowerCLIConfiguration -ProxyPolicy NoProxy -DefaultVIServerMode Single -InvalidCertificateAction Ignore -ParticipateInCeip:$false -DisplayDeprecationWarnings:$false -Confirm:$false -Scope Session
        $ServerConnection = Connect-VIServer -Server $Server -Session $SessionToken -Force
        if ($ServerConnection.IsConnected) {
            Write-Host "$((Get-Date).ToString("o")) [INFO] Connected to vCenter $($ServerConnection.Name) version $($ServerConnection.Version) build $($ServerConnection.Build)"
        }
    } catch {
        # Write-Host "$((Get-Date).ToString("o")) [ERROR] SessionToken not found, invalid or connection failure"
        # Write-Host "$((Get-Date).ToString("o")) [ERROR] Exit"
        # Stop-Transcript
        # exit
        AltAndCatchFire "SessionToken not found, invalid or connection failure"
    }
}