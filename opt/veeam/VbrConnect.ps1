#!/usr/bin/pwsh -NonInteractive -NoProfile -Command
#
param([Parameter (Mandatory=$true)] [string] $server, [Parameter (Mandatory=$true)] [string] $username, [Parameter (Mandatory=$true)] [string] $password)

# https://communities.vmware.com/t5/VMware-PowerCLI-Discussions/PowerCLI-on-Debian-Stretch-The-type-initializer-for-VMware/m-p/451739#M10646
Set-Content -Path Env:HOME -Value '/tmp'

if (!$(Test-Connection -TargetName $server -TcpPort 9419 -TimeoutSeconds 2)) {
    Write-Host "$server is not answering at TCP:9419 check if VeeamBackupRESTSvc is running"
    exit 1
}

try {
    $VbrHeaders = @{"accept" = "application/json";"x-api-version" = "1.0-rev1"}
    $VbrBody = @{grant_type = "password";username = $username;password = $password;refresh_token = "";code = "";use_short_term_refresh = ""}
    $VbrConnect = Invoke-RestMethod -SkipHttpErrorCheck -SkipCertificateCheck -Method POST -Uri $("https://" + $server + ":9419/api/oauth2/token") -Headers $VbrHeaders -ContentType "application/x-www-form-urlencoded" -Body $VbrBody
    if ($VbrConnect.access_token) {
        $SessionSecretName = "vbr_" + $server.Replace(".","_") + ".key"
        $SessionRefresh = "vbr_" + $server.Replace(".","_") + ".dat"
        $VbrConnect.access_token | Out-File -FilePath /tmp/$SessionSecretName
        $VbrConnect.refresh_token | Out-File -FilePath /tmp/$SessionRefresh
        Write-Host "Connected to $server"
    } else {
        Write-Host "Connection to $server failed!"
        exit 1
    }
} catch {
    # Invoke-RestMethod: Unable to read data from the transport connection: Connection reset by peer.
    # https://helpcenter.veeam.com/docs/backup/vbr_rest/tls_certificate.html
    Write-Host "$($Error[0])"
    exit 1
}