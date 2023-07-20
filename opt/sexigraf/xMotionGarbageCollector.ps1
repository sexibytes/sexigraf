#!/usr/bin/pwsh -Command
#

$ScriptVersion = "0.9.1"

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

try {
    Start-Transcript -Path "/var/log/sexigraf/xMotionGarbageCollector.log" -Append -Confirm:$false -Force -UseMinimalHeader
    Write-Host "$((Get-Date).ToString("o")) [INFO] xMotionGarbageCollector v$ScriptVersion"
} catch {
    Write-Host "$((Get-Date).ToString("o")) [EROR] xMotionGarbageCollector logging failure"
    Write-Host "$((Get-Date).ToString("o")) [EROR] Exit"
    exit
}

try {
    Write-Host "$((Get-Date).ToString("o")) [INFO] Looking for another xMotionGarbageCollector ..."
    $DupViVmInventoryProcess = Get-PSHostProcessInfo|%{$(Get-Content -LiteralPath "/proc/$($_.ProcessId)/cmdline") -replace "`0", ' '}|?{$_ -match "xMotionGarbageCollector"}
    # https://github.com/PowerShell/PowerShell/issues/13944
    if (($DupViVmInventoryProcess|Measure-Object).Count -gt 1) {
        $DupViVmInventoryProcessId = (Get-PSHostProcessInfo|?{$(Get-Content -LiteralPath "/proc/$($_.ProcessId)/cmdline") -replace "`0", ' '|?{$_ -match "xMotionGarbageCollector"}}).ProcessId[0]
        $DupViVmInventoryProcessTime = [INT32](ps -p $DupViVmInventoryProcessId -o etimes).split()[-1]
        if ($DupViVmInventoryProcessTime -gt 21600) {
            Write-Host "$((Get-Date).ToString("o")) [WARN] xMotionGarbageCollector is already running for more than 6 hours!"
            Write-Host "$((Get-Date).ToString("o")) [WARN] Killing stunned xMotionGarbageCollector"
            Stop-Process -Id $DupViVmInventoryProcessId -Force
        } else {
            AltAndCatchFire "xMotionGarbageCollector is already running!"
        }
    }
} catch {
    AltAndCatchFire "xMotionGarbageCollector process lookup failure"
}

Write-Host "$((Get-Date).ToString("o")) [INFO] Collecting VM folders ..."

try {
    $VmFolders = Get-ChildItem -Directory /mnt/wfs/whisper/vmw/*/*/*/vm/*|Select-Object BaseName, FullName, CreationTimeUtc, LastWriteTimeUtc, LastAccessTimeUtc|Sort-Object LastAccessTimeUtc -Descending
} catch {
    Write-Host "$((Get-Date).ToString("o")) [EROR] Collecting VM folders issue ..."
}

if ($VmFolders) {
    Write-Host "$((Get-Date).ToString("o")) [INFO] Looking for xvmotioned vms aka DstVmMigratedEvent ..."

    $VmFolders_h = @{}
    $VmFoldersDup_h = @{}
    foreach ($VmFolder in $VmFolders) {
        if (!$VmFolders_h[$VmFolder.basename]) {
            $VmFolders_h.add($VmFolder.basename,@($VmFolder))
        } else {
            $VmFolders_h[$VmFolder.basename] += $VmFolder
            if (!$VmFoldersDup_h[$VmFolder.basename]) {
                $VmFoldersDup_h.add($VmFolder.basename,"1")
            }
        }
    }
    
    if ($VmFoldersDup_h.Count -gt 0) {
        Write-Host "$((Get-Date).ToString("o")) [INFO] $($VmFoldersDup_h.Count) Duplicate vm folders found across clusters, evaluating mobility ..."
        foreach ($VmDup in $($VmFoldersDup_h.keys|Select-Object -first 100)) {
    
            if ($VmFolders_h[$VmDup].count -lt 2) {
                Write-Host "$((Get-Date).ToString("o")) [EROR] VM $VmDup has less than 2 copies, skipping ..."
                continue
            } elseif ($VmFolders_h[$VmDup].count -gt 2) {
                Write-Host "$((Get-Date).ToString("o")) [INFO] VM $VmDup has more than 2 copies ..."
            }
    
            $VmDupFolders = $VmFolders_h[$VmDup]
            $VmDupSrcDir = $($VmDupFolders|Sort-Object CreationTimeUtc -Descending)[1]
            $VmDupDstDir = $($VmDupFolders|Sort-Object CreationTimeUtc -Descending)[0]
    
            try {
                $VmDupSrcWsp = Get-Item $($VmDupSrcDir.FullName + "/storage/committed.wsp")|Select-Object BaseName, FullName, CreationTimeUtc, LastWriteTimeUtc, LastAccessTimeUtc
                $VmDupDstWsp = Get-Item $($VmDupDstDir.FullName + "/storage/committed.wsp")|Select-Object BaseName, FullName, CreationTimeUtc, LastWriteTimeUtc, LastAccessTimeUtc
            } catch {
                Write-Host "$((Get-Date).ToString("o")) [EROR] Missing committed.wsp for vm $VmDup ..."
                continue
            }
    
            if (($VmDupDstDir.CreationTimeUtc -gt $VmDupSrcDir.CreationTimeUtc) -and ($VmDupDstWsp.LastWriteTimeUtc - $VmDupSrcWsp.LastWriteTimeUtc).TotalMinutes -gt 90) {
    
                $VmDupDstVc = $VmDupDstDir.FullName.split("/")[5]
                $VmDupDstDc = $VmDupDstDir.FullName.split("/")[6]
                $VmDupDstClu = $VmDupDstDir.FullName.split("/")[7]
                $VmDupSrcClu = $VmDupSrcDir.FullName.split("/")[7]
                Write-Host "$((Get-Date).ToString("o")) [INFO] VM $VmDup has been moved from cluster $VmDupSrcClu to cluster $VmDupDstClu a while ago, merging metrics to the new destination if possible ..."
                $VmDupWsps2Mv = Get-ChildItem -Recurse $VmDupSrcDir.FullName -Filter *.wsp
                foreach ($VmDupWsp2Mv in $VmDupWsps2Mv) {
                    $WspRelativePath = $($VmDupWsp2Mv.FullName -split "/vm/")[1]
                    $DstWspFullPath = $("/mnt/wfs/whisper/vmw/" + $VmDupDstVc + "/" + $VmDupDstDc + "/" + $VmDupDstClu + "/vm/" + $WspRelativePath)
                    if (Test-Path $DstWspFullPath) {
                        try {
                            Write-Host "$((Get-Date).ToString("o")) [INFO] Checking $DstWspFullPath whisper-info"
                            $VmDupWspSrcInfo = Invoke-Expression "/usr/local/bin/whisper-info.py $DstWspFullPath"
                            Write-Host "$((Get-Date).ToString("o")) [INFO] Checking $($VmDupWsp2Mv.FullName) whisper-info"
                            $VmDupWsp2MvInfo = Invoke-Expression "/usr/local/bin/whisper-info.py $($VmDupWsp2Mv.FullName)"
    
                            if (Compare-Object $VmDupWspSrcInfo $VmDupWsp2MvInfo) {
                                Write-Host "$((Get-Date).ToString("o")) [INFO] Resizing $($VmDupWsp2Mv.FullName) and $DstWspFullPath"
                                $VmDupWspSrcResiz = Invoke-Expression "/usr/local/bin/whisper-resize.py $DstWspFullPath 5m:24h 10m:48h 60m:7d 240m:30d 720m:90d 2880m:1y 5760m:2y 17280m:5y --nobackup --force"
                                $VmDupWsp2MvResiz = Invoke-Expression "/usr/local/bin/whisper-resize.py $($VmDupWsp2Mv.FullName) 5m:24h 10m:48h 60m:7d 240m:30d 720m:90d 2880m:1y 5760m:2y 17280m:5y --nobackup --force"
                            }
    
                            Write-Host "$((Get-Date).ToString("o")) [INFO] Merging $($VmDupWsp2Mv.FullName) to $DstWspFullPath"
                            $VmDupWsp2MvMerg = Invoke-Expression "/usr/local/bin/whisper-merge.py $($VmDupWsp2Mv.FullName) $DstWspFullPath"
                        } catch {
                            Write-Host "$((Get-Date).ToString("o")) [EROR] $($VmDupWsp2Mv.FullName) moving issue ..."
                            continue
                        }
                    } else {
                        try {
                            Write-Host "$((Get-Date).ToString("o")) [INFO] Creating $DstWspFullPath and moving $($VmDupWsp2Mv.FullName)"
                            $VmDupWspMkDir = New-Item $DstWspFullPath -Force -ErrorAction Stop
                            $VmDupWspMv = Move-Item $VmDupWsp2Mv.FullName $DstWspFullPath -Force -ErrorAction Stop
                        } catch {
                            Write-Host "$((Get-Date).ToString("o")) [EROR] $($VmDupWsp2Mv.FullName) moving issue ..."
                            continue
                        }
                    }
                }
                Write-Host "$((Get-Date).ToString("o")) [INFO] Removing $($VmDupSrcDir.FullName)"
                try {
                    Remove-Item -Recurse $($VmDupSrcDir.FullName) -Force -ErrorAction Stop
                } catch {
                    Write-Host "$((Get-Date).ToString("o")) [EROR] Removing $($VmDupSrcDir.FullName) issue ..."
                }
            } else {
                Write-Host "$((Get-Date).ToString("o")) [INFO] VM $VmDup move is too recent, has clones or has come back to its original location ..."
                # TODO deal with infinite clones
            }
        }
    } else {
        Write-Host "$((Get-Date).ToString("o")) [INFO] No duplicated vm folders found"
    }
}

Write-Host "$((Get-Date).ToString("o")) [INFO] Collecting ESX folders ..."

try {
    $EsxFolders = Get-ChildItem -Directory /mnt/wfs/whisper/vmw/*/*/*/esx/*|Select-Object BaseName, FullName, CreationTimeUtc, LastWriteTimeUtc, LastAccessTimeUtc|Sort-Object LastAccessTimeUtc -Descending
} catch {
    Write-Host "$((Get-Date).ToString("o")) [EROR] Collecting ESX folders issue ..."
}

if ($EsxFolders) {
    Write-Host "$((Get-Date).ToString("o")) [INFO] Looking for *xvmotioned* ESXs aka DstEsxMigratedEvent ..."

    $EsxFolders_h = @{}
    $EsxFoldersDup_h = @{}
    foreach ($EsxFolder in $EsxFolders) {
        if (!$EsxFolders_h[$EsxFolder.basename]) {
            $EsxFolders_h.add($EsxFolder.basename,@($EsxFolder))
        } else {
            $EsxFolders_h[$EsxFolder.basename] += $EsxFolder
            if (!$EsxFoldersDup_h[$EsxFolder.basename]) {
                $EsxFoldersDup_h.add($EsxFolder.basename,"1")
            }
        }
    }
    
    if ($EsxFoldersDup_h.Count -gt 0) {
        Write-Host "$((Get-Date).ToString("o")) [INFO] $($EsxFoldersDup_h.Count) Duplicate Esx folders found across clusters, evaluating mobility ..."
        foreach ($EsxDup in $($EsxFoldersDup_h.keys|Select-Object -first 10)) {
    
            if ($EsxFolders_h[$EsxDup].count -lt 2) {
                Write-Host "$((Get-Date).ToString("o")) [EROR] Esx $EsxDup has less than 2 copies, skipping ..."
                continue
            } elseif ($EsxFolders_h[$EsxDup].count -gt 2) {
                Write-Host "$((Get-Date).ToString("o")) [INFO] Esx $EsxDup has more than 2 copies ..."
            }
    
            $EsxDupFolders = $EsxFolders_h[$EsxDup]
            $EsxDupSrcDir = $($EsxDupFolders|Sort-Object CreationTimeUtc -Descending)[1]
            $EsxDupDstDir = $($EsxDupFolders|Sort-Object CreationTimeUtc -Descending)[0]
    
            try {
                $EsxDupSrcWsp = Get-Item $($EsxDupSrcDir.FullName + "/quickstats/Uptime.wsp")|Select-Object BaseName, FullName, CreationTimeUtc, LastWriteTimeUtc, LastAccessTimeUtc
                $EsxDupDstWsp = Get-Item $($EsxDupDstDir.FullName + "/quickstats/Uptime.wsp")|Select-Object BaseName, FullName, CreationTimeUtc, LastWriteTimeUtc, LastAccessTimeUtc
            } catch {
                Write-Host "$((Get-Date).ToString("o")) [EROR] Missing committed.wsp for Esx $EsxDup ..."
                continue
            }
    
            if (($EsxDupDstDir.CreationTimeUtc -gt $EsxDupSrcDir.CreationTimeUtc) -and ($EsxDupDstWsp.LastWriteTimeUtc - $EsxDupSrcWsp.LastWriteTimeUtc).TotalMinutes -gt 90) {
    
                $EsxDupDstVc = $EsxDupDstDir.FullName.split("/")[5]
                $EsxDupDstDc = $EsxDupDstDir.FullName.split("/")[6]
                $EsxDupDstClu = $EsxDupDstDir.FullName.split("/")[7]
                $EsxDupSrcClu = $EsxDupSrcDir.FullName.split("/")[7]
                Write-Host "$((Get-Date).ToString("o")) [INFO] Esx $EsxDup has been moved from cluster $EsxDupSrcClu to cluster $EsxDupDstClu a while ago, merging metrics to the new destination if possible ..."
                $EsxDupWsps2Mv = Get-ChildItem -Recurse $EsxDupSrcDir.FullName -Filter *.wsp
                foreach ($EsxDupWsp2Mv in $EsxDupWsps2Mv) {
                    $WspRelativePath = $($EsxDupWsp2Mv.FullName -split "/Esx/")[1]
                    $DstWspFullPath = $("/mnt/wfs/whisper/vmw/" + $EsxDupDstVc + "/" + $EsxDupDstDc + "/" + $EsxDupDstClu + "/esx/" + $WspRelativePath)
                    if (Test-Path $DstWspFullPath) {
                        try {
                            Write-Host "$((Get-Date).ToString("o")) [INFO] Checking $DstWspFullPath whisper-info"
                            $VmDupWspSrcInfo = Invoke-Expression "/usr/local/bin/whisper-info.py $DstWspFullPath"
                            Write-Host "$((Get-Date).ToString("o")) [INFO] Checking $($EsxDupWsp2Mv.FullName) whisper-info"
                            $EsxDupWsp2MvInfo = Invoke-Expression "/usr/local/bin/whisper-info.py $($EsxDupWsp2Mv.FullName)"
    
                            if (Compare-Object $VmDupWspSrcInfo $EsxDupWsp2MvInfo) {
                                Write-Host "$((Get-Date).ToString("o")) [INFO] Resizing $($EsxDupWsp2Mv.FullName) and $DstWspFullPath"
                                $EsxDupWspSrcResiz = Invoke-Expression "/usr/local/bin/whisper-resize.py $DstWspFullPath 5m:24h 10m:48h 60m:7d 240m:30d 720m:90d 2880m:1y 5760m:2y 17280m:5y --nobackup --force"
                                $EsxDupWsp2MvResiz = Invoke-Expression "/usr/local/bin/whisper-resize.py $($EsxDupWsp2Mv.FullName) 5m:24h 10m:48h 60m:7d 240m:30d 720m:90d 2880m:1y 5760m:2y 17280m:5y --nobackup --force"
                            }
    
                            Write-Host "$((Get-Date).ToString("o")) [INFO] Merging $($EsxDupWsp2Mv.FullName) to $DstWspFullPath"
                            $EsxDupWsp2MEsxerg = Invoke-Expression "/usr/local/bin/whisper-merge.py $($EsxDupWsp2Mv.FullName) $DstWspFullPath"
                        } catch {
                            Write-Host "$((Get-Date).ToString("o")) [EROR] $($EsxDupWsp2Mv.FullName) moving issue ..."
                            continue
                        }
                    } else {
                        try {
                            Write-Host "$((Get-Date).ToString("o")) [INFO] Creating $DstWspFullPath and moving $($EsxDupWsp2Mv.FullName)"
                            $EsxDupWspMkDir = New-Item $DstWspFullPath -Force -ErrorAction Stop
                            $EsxDupWspMv = Move-Item $EsxDupWsp2Mv.FullName $DstWspFullPath -Force -ErrorAction Stop
                        } catch {
                            Write-Host "$((Get-Date).ToString("o")) [EROR] $($EsxDupWsp2Mv.FullName) moving issue ..."
                            continue
                        }
                    }
                }
                Write-Host "$((Get-Date).ToString("o")) [INFO] Removing $($EsxDupSrcDir.FullName)"
                try {
                    Remove-Item -Recurse $($EsxDupSrcDir.FullName) -Force -ErrorAction Stop
                } catch {
                    Write-Host "$((Get-Date).ToString("o")) [EROR] Removing $($EsxDupSrcDir.FullName) issue ..."
                }
            } else {
                Write-Host "$((Get-Date).ToString("o")) [INFO] Esx $EsxDup move is too recent, has clones or has come back to its original location ..."
            }
        }
    } else {
        Write-Host "$((Get-Date).ToString("o")) [INFO] No duplicated Esx folders found"
    }
}

Write-Host "$((Get-Date).ToString("o")) [INFO] SexiGraf xMotionGarbageCollector has left the building ..."