#!/usr/bin/pwsh -Command
#
param([Parameter (Mandatory=$true)] [string] $DaysOld)

$ScriptVersion = "0.9.3"

$ErrorActionPreference = "SilentlyContinue"
$WarningPreference = "SilentlyContinue"

try {
    Start-Transcript -Path "/var/log/sexigraf/WhisperAutoPurge.log" -Append -Confirm:$false -Force
    Write-Host "$((Get-Date).ToString("o")) [INFO] WhisperAutoPurge v$ScriptVersion"
} catch {
    Write-Host "$((Get-Date).ToString("o")) [ERROR] WhisperAutoPurge logging failure"
    Write-Host "$((Get-Date).ToString("o")) [ERROR] Exit"
    exit
}

Write-Host "$((Get-Date).ToString("o")) [INFO] looking for $DaysOld days old files ..."

# Get-ChildItem -File -Recurse -Path /mnt/wfs/whisper/ |Group-Object -Property Directory|?{$_.group.LastWriteTime|Sort-Object -Descending|Select-Object -First 1|?{$_ -lt (Get-Date).AddDays(-1)}}|%{Remove-Item -Recurse -Path $_.name -force -confirm:$false}
$OldFoldersGroups = Get-ChildItem -File -Recurse -Path /mnt/wfs/whisper/ |Group-Object -Property Directory|?{$_.group.LastWriteTime|Sort-Object -Descending|Select-Object -First 1|?{$_ -lt (Get-Date).AddDays(-$DaysOld)}}
foreach ($OldFolder in $OldFoldersGroups) {
    try {
        Write-Host "$((Get-Date).ToString("o")) [INFO] Removing $($OldFolder.name)"
        Remove-Item -Recurse -Path $OldFolder.name -force -confirm:$false
    } catch {
        Write-Host "$((Get-Date).ToString("o")) [WARN] Cannot remove $($OldFolder.name)"
        Write-Host "$((Get-Date).ToString("o")) [WARN] $($Error[0])"
    }
}

Write-Host "$((Get-Date).ToString("o")) [INFO] looking for empty folders ..."

# While((Get-ChildItem -Directory -Recurse -Path /mnt/wfs/whisper/|?{$_.GetFiles().Count -eq 0 -and $_.GetDirectories().Count -eq 0}).count -gt 0) {Get-ChildItem -Directory -Recurse -Path /mnt/wfs/whisper/|?{$_.GetFiles().Count -eq 0 -and $_.GetDirectories().Count -eq 0}|Remove-Item -force -confirm:$false}
While(($OldEmptyFolders = Get-ChildItem -Directory -Recurse -Path /mnt/wfs/whisper/|?{$_.GetFiles().Count -eq 0 -and $_.GetDirectories().Count -eq 0}).count -gt 0) {
    foreach ($OldEmptyFolder in $OldEmptyFolders) {
        try {
            Write-Host "$((Get-Date).ToString("o")) [INFO] Removing $($OldEmptyFolder.FullName)"
            $OldEmptyFolder|Remove-Item -force -confirm:$false
        } catch {
            Write-Host "$((Get-Date).ToString("o")) [WARN] Cannot remove $($OldEmptyFolder.FullName)"
            Write-Host "$((Get-Date).ToString("o")) [WARN] $($Error[0])"
        }
    }
}