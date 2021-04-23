#!/usr/bin/pwsh -Command
#
param([Parameter (Mandatory=$true)] [string] $server, [Parameter (Mandatory=$true)] [string] $username, [Parameter (Mandatory=$true)] [string] $password)

# https://communities.vmware.com/t5/VMware-PowerCLI-Discussions/PowerCLI-on-Debian-Stretch-The-type-initializer-for-VMware/m-p/451739#M10646
Set-Content -Path Env:HOME -Value '/tmp'

if (!$(Test-Connection -TargetName $server -TcpPort 443 -TimeoutSeconds 2)) {
    Write-Host "$server is not answering at TCP:443"
    exit 1
}

try {
    Import-Module VMware.Vim, VMware.VimAutomation.Cis.Core, VMware.VimAutomation.Common, VMware.VimAutomation.Core, VMware.VimAutomation.Sdk
    # $PowerCliConfig = Set-PowerCLIConfiguration -ProxyPolicy NoProxy -DefaultVIServerMode Single -InvalidCertificateAction Ignore -ParticipateInCeip:$false -DisplayDeprecationWarnings:$false -Confirm:$false -Scope Session
    $ViConnect = Connect-VIServer -Force -Server $server -User $username -Password $password -ErrorAction Stop|Out-Null
    $SessionSecretName = "vmw_" + $server.Replace(".","_") + ".key"
    $ViConnect.SessionSecret | Out-File -FilePath /tmp/$SessionSecretName
    Write-Host "Connected to $server"
} catch {
    Write-Host "$($Error[0])"
    exit 1
}