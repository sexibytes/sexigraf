#!/usr/bin/pwsh -Command
#
$ScriptVersion = "0.9.2"

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

try {
    Start-Transcript -Path "/var/log/sexigraf/VbrVmInventory.log" -Append -Confirm:$false -Force -UseMinimalHeader
    Write-Host "$((Get-Date).ToString("o")) [INFO] VbrVmInventory v$ScriptVersion"
} catch {
    Write-Host "$((Get-Date).ToString("o")) [EROR] VbrVmInventory logging failure"
    Write-Host "$((Get-Date).ToString("o")) [EROR] Exit"
    exit
}

try {
    Write-Host "$((Get-Date).ToString("o")) [INFO] Looking for another VbrVmInventory ..."
    $DupVbrVmInventoryProcess = Get-PSHostProcessInfo|%{$(Get-Content -LiteralPath "/proc/$($_.ProcessId)/cmdline") -replace "`0", ' '}|?{$_ -match "VbrVmInventory"}
    # https://github.com/PowerShell/PowerShell/issues/13944
    if (($DupVbrVmInventoryProcess|Measure-Object).Count -gt 1) {
        $DupVbrVmInventoryProcessId = (Get-PSHostProcessInfo|?{$(Get-Content -LiteralPath "/proc/$($_.ProcessId)/cmdline") -replace "`0", ' '}).ProcessId[0]
        $DupVbrVmInventoryProcessTime = [INT32](ps -p $DupVbrVmInventoryProcessId -o etimes).split()[-1]
        if ($DupVbrVmInventoryProcessTime -gt 300) {
            Write-Host "$((Get-Date).ToString("o")) [WARN] VbrVmInventory is already running for more than 5 minutes!"
            Write-Host "$((Get-Date).ToString("o")) [WARN] Killing stunned VbrVmInventory"
            Stop-Process -Id $DupVbrVmInventoryProcessId -Force
        } else {
            AltAndCatchFire "VbrVmInventory is already running!"
        }
    }
} catch {
    AltAndCatchFire "VbrVmInventory process lookup failure"
}

try {
    Write-Host "$((Get-Date).ToString("o")) [INFO] Looking for VBR inventories ..."
    $VbrVmInventories = Test-Path /mnt/wfs/inventory/VbrInv_*.csv
} catch {
    Write-Host "$((Get-Date).ToString("o")) [EROR] No VBR VM Inventories ?!"
    Write-Host "$((Get-Date).ToString("o")) [EROR] Exit"
    exit
}

if ($VbrVmInventories) {
    Write-Host "$((Get-Date).ToString("o")) [INFO] Import/Export VBR inventories ..."
    try {
        Import-Csv $(Get-ChildItem /mnt/wfs/inventory/VbrInv_*.csv).fullname | Export-Csv /mnt/wfs/inventory/VbrVmInventory.csv -ErrorAction Stop -Force #TODO sort LastRestorePoint
    } catch {
        AltAndCatchFire "Import/Export VBR inventories issue"
    }
}

Write-Host "$((Get-Date).ToString("o")) [INFO] End of VBR inventories processing ..."