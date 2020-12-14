#!/usr/bin/pwsh
#
param([Parameter (Mandatory=$true)] [string] $server, [Parameter (Mandatory=$true)] [string] $sessionfile, [Parameter (Mandatory=$false)] [string] $credstore)

$exec_start = Get-Date
$script_version = "0.9.1"

try {
    Start-Transcript -Path "/var/log/sexigraf/ViPullStatistics.$($server).log" -Append -Confirm:$false -Force
    Write-Host "$((Get-Date).ToString("o")) [DEBUG] VsanDisksPullStatistics v$script_version"
} catch {
    Write-Host "$((Get-Date).ToString("o")) [ERROR] VsanDisksPullStatistics logging failure"
    exit
}