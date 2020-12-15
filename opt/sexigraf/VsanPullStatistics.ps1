#!/usr/bin/pwsh
#
param([Parameter (Mandatory=$true)] [string] $Server, [Parameter (Mandatory=$true)] [string] $SessionFile, [Parameter (Mandatory=$false)] [string] $CredStore)

$ScriptVersion = "0.9.1"

$ExecStart = Get-Date

$ErrorActionPreference = "SilentlyContinue"
$WarningPreference = "SilentlyContinue"

function AltAndCatchFire {
    Param([string] $ExitReason)
    Write-Host "$((Get-Date).ToString("o")) [ERROR] $ExitReason"
    Write-Host "$((Get-Date).ToString("o")) [ERROR] $($Error[0])"
    Write-Host "$((Get-Date).ToString("o")) [ERROR] Exit"
    Stop-Transcript
    exit
}

try {
    Start-Transcript -Path "/var/log/sexigraf/VsanDisksPullStatistics.$($Server).log" -Append -Confirm:$false -Force
    Write-Host "$((Get-Date).ToString("o")) [DEBUG] VsanDisksPullStatistics v$ScriptVersion"
} catch {
    Write-Host "$((Get-Date).ToString("o")) [ERROR] VsanDisksPullStatistics logging failure"
    Write-Host "$((Get-Date).ToString("o")) [ERROR] Exit"
    exit
}

try {
    Write-Host "$((Get-Date).ToString("o")) [INFO] Looking for another VsanPullStatistics for $Server"
    $DupVsanPullStatisticsProcess = Get-PSHostProcessInfo|%{$(Get-Content -LiteralPath "/proc/$($_.ProcessId)/cmdline") -replace "`0", ' '}|?{$_ -match "VsanPullStatistics" -and $_ -match "$Server"}
    # https://github.com/PowerShell/PowerShell/issues/13944
    if (($DupVsanPullStatisticsProcess|Measure-Object).Count -gt 1) {
        AltAndCatchFire "VsanPullStatistics for $Server is already running!"
    }
} catch {
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
        AltAndCatchFire "SessionToken not found, invalid or connection failure"
    }
} elseif ($CredStore) {

}

try {
    if ($($global:DefaultVIServer)) {
        Write-Host "$((Get-Date).ToString("o")) [INFO] Start processing vCenter $Server"
        $ServiceInstance = Get-View ServiceInstance
    } else {
        AltAndCatchFire "global:DefaultVIServer variable check failure"
    }
} catch {
    AltAndCatchFire "Unable to verify vCenter connection"
}

if ($ServiceInstance.Content.About.ApiType -match "VirtualCenter") {

    $VcenterName = $($Server.ToLower()) -replace "[. ]","_"
    
    try {
        if ($ServiceInstance.Content.About.ApiVersion.Split(".")[0] -ge 6) {
            Write-Host "$((Get-Date).ToString("o")) [INFO] vCenter ApiVersion is =>6 so we can call vSAN API"
            $VsanSpaceReportSystem = Get-VSANView -Id "VsanSpaceReportSystem-vsan-cluster-space-report-system"
        } else {
            Write-Host "$((Get-Date).ToString("o")) [INFO] vCenter ApiVersion is not =>6 so we cannot call vSAN API"
        }
    } catch {
        AltAndCatchFire "Unable to read ServiceInstance.Content.About.ApiVersion"
    }

    Write-Host -ForegroundColor White "$((Get-Date).ToString("o")) [INFO] vCenter objects collect ..."

	$all_vCenter_folders = Get-View -ViewType folder -Property Parent, Name -Server $vCenter
	$all_vCenter_datacenters = Get-View -ViewType datacenter -Property Name, Parent -Server $vCenter
	$all_vCenter_clusters = Get-View -ViewType clustercomputeresource -Property Name, Parent,ConfigurationEx, Summary, CustomValue -Server $vCenter
	# $all_vCenter_vmhosts = Get-View -ViewType hostsystem -Property Name, Parent -Server $vCenter
	$all_vCenter_resource_pools = Get-View -ViewType ResourcePool -Property Parent, Name, Owner, Config -Server $vCenter
	$all_vCenter_compute_pools = Get-View -ViewType ComputeResource -Property Name, Parent -Server $vCenter
	
	$xfolders_vCenter_name_table = @{}
	$xfolders_vCenter_Parent_table = @{}
	$xfolders_vCenter_type_table = @{}

	Write-Host -ForegroundColor White "$((Get-Date).ToString("o")) [INFO] vCenter objects relationship discover ..."
	
	foreach ($all_vCenter_xfolder in [array]$all_vCenter_datacenters+[array]$all_vCenter_folders+[array]$all_vCenter_clusters+[array]$all_vCenter_compute_pools+[array]$all_vCenter_resource_pools) {
		if (!$xfolders_vCenter_name_table[$all_vCenter_xfolder.moref.value]) {$xfolders_vCenter_name_table.add($all_vCenter_xfolder.moref.value,$all_vCenter_xfolder.name)}
		if (!$xfolders_vCenter_Parent_table[$all_vCenter_xfolder.moref.value]) {$xfolders_vCenter_Parent_table.add($all_vCenter_xfolder.moref.value,$all_vCenter_xfolder.Parent.value)}
		if (!$xfolders_vCenter_type_table[$all_vCenter_xfolder.moref.value]) {$xfolders_vCenter_type_table.add($all_vCenter_xfolder.moref.value,$all_vCenter_xfolder.moref.type)}
	}


} else {
    AltAndCatchFire "$Server is not a vcenter!"
}

# https://www.virtuallyghetto.com/2017/04/getting-started-wthe-new-powercli-6-5-1-get-vsanview-cmdlet.html
# https://github.com/lamw/vghetto-scripts/blob/master/powershell/VSANSmartsData.ps1