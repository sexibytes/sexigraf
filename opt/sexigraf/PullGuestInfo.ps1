#!/usr/bin/pwsh -Command
#
$ScriptVersion = "0.9.1"

$ErrorActionPreference = "SilentlyContinue"
$WarningPreference = "SilentlyContinue"
(Get-Process -Id $pid).PriorityClass = 'BelowNormal'

try {
    Start-Transcript -Path "/var/log/sexigraf/PullGuestInfo.log" -Append -Confirm:$false -Force -UseMinimalHeader
    Write-Host "$((Get-Date).ToString("o")) [INFO] PullGuestInfo v$ScriptVersion"
} catch {
    Write-Host "$((Get-Date).ToString("o")) [EROR] PullGuestInfo logging failure"
    Write-Host "$((Get-Date).ToString("o")) [EROR] Exit"
    exit
}

try {
    # https://kb.vmware.com/s/article/1014038
    $VmwCmdTimeSymc = Invoke-Expression "/bin/vmware-toolbox-cmd timesync status"
} catch {
    Write-Host "$((Get-Date).ToString("o")) [WARN] timesync status invoke failure"
}

if ($VmwCmdTimeSymc -match "Disabled") {
    Write-Host "$((Get-Date).ToString("o")) [INFO] fixing VMtools timesync status ..."
    try {
        $VmwCmdTimeSymc = Invoke-Expression "/bin/vmware-toolbox-cmd timesync enable"
        Write-Host "$((Get-Date).ToString("o")) [INFO] VMtools timesync status is $VmwCmdTimeSymc"
        if ($VmwCmdTimeSymc -match "Disabled") {
            Write-Host "$((Get-Date).ToString("o")) [WARN] timesync status invoke failure"
        }
    } catch {
        Write-Host "$((Get-Date).ToString("o")) [WARN] timesync status invoke failure"
    }
} elseif ($VmwCmdTimeSymc -match "Enabled") {
    Write-Host "$((Get-Date).ToString("o")) [INFO] VMtools timesync status is already $VmwCmdTimeSymc"
} else {
    Write-Host "$((Get-Date).ToString("o")) [WARN] timesync status invoke failure"
}

try {
    [xml]$VmwCmdOvfEnv = Invoke-Expression '/usr/bin/vmtoolsd --cmd "info-get guestinfo.ovfEnv"'

    if ($VmwCmdOvfEnv -and $VmwCmdOvfEnv.Environment.PropertySection.Property -and $VmwCmdOvfEnv.Environment.PlatformSection.Kind -match "VMware ESXi") {

        $VmwCmdOvfEnvGuest = @{}
        foreach ($VmwCmdOvfEnvProperty in $VmwCmdOvfEnv.Environment.PropertySection.Property) {
            if (!$VmwCmdOvfEnvGuest[$VmwCmdOvfEnvProperty.key]) {
                $VmwCmdOvfEnvGuest.add($VmwCmdOvfEnvProperty.key, $VmwCmdOvfEnvProperty.value)
            }
        }

        if (([regex]::match($($VmwCmdOvfEnvGuest['guestinfo.ipaddress']), '^([0-9]{1,3})\.([0-9]{1,3})\.([0-9]{1,3})\.([0-9]{1,3})$')).Success -and ([regex]::match($($VmwCmdOvfEnvGuest['guestinfo.netmask']), '^([0-9]{1,3})\.([0-9]{1,3})\.([0-9]{1,3})\.([0-9]{1,3})$')).Success -and ([regex]::match($($VmwCmdOvfEnvGuest['guestinfo.gateway']), '^([0-9]{1,3})\.([0-9]{1,3})\.([0-9]{1,3})\.([0-9]{1,3})$')).Success) {
            $EtcNetworkInterfaces = @()
            $EtcNetworkInterfaces += "auto lo"
            $EtcNetworkInterfaces += "iface lo inet loopback"
            $EtcNetworkInterfaces += "allow-hotplug eth0"
            $EtcNetworkInterfaces += "iface eth0 inet static"
            $EtcNetworkInterfaces += " address $($VmwCmdOvfEnvGuest['guestinfo.ipaddress'])"
            $EtcNetworkInterfaces += " netmask $($VmwCmdOvfEnvGuest['guestinfo.netmask'])"
            $EtcNetworkInterfaces += " gateway $($VmwCmdOvfEnvGuest['guestinfo.gateway'])"

            if ($VmwCmdOvfEnvGuest["guestinfo.dns"] -and ([regex]::match($($VmwCmdOvfEnvGuest['guestinfo.dns']), '^([0-9]{1,3})\.([0-9]{1,3})\.([0-9]{1,3})\.([0-9]{1,3})$')).Success) {
                $EtcNetworkInterfaces += " dns-nameservers $($VmwCmdOvfEnvGuest['guestinfo.dns'])"
            }
    
            if ($VmwCmdOvfEnvGuest["guestinfo.domain"] -and ([regex]::match($($VmwCmdOvfEnvGuest['guestinfo.domain']), '([a-zA-Z]+)')).Success) {
                $EtcNetworkInterfaces += " dns-search $($VmwCmdOvfEnvGuest['guestinfo.domain'])"
            }
        } else {
            Write-Host "$((Get-Date).ToString("o")) [INFO] DHCP detected or bad guestinfo syntax ..."
        }

    }

    $EtcNetworkInterfacesLocal = Get-Content /etc/network/interfaces
    $NetworkToReload = $false

    if ($EtcNetworkInterfaces -and $EtcNetworkInterfacesLocal) {
        if (Compare-Object $EtcNetworkInterfaces $EtcNetworkInterfacesLocal) {
            Write-Host "$((Get-Date).ToString("o")) [INFO] fixing network info ..."
            $EtcNetworkInterfaces|Set-Content -Path /etc/network/interfaces -Force
            $NetworkToReload = $true
        } else {
            Write-Host "$((Get-Date).ToString("o")) [INFO] no network info changes ..."
        }

        $EtcHostsLocal = Get-Content /etc/hosts
        $EtcHostnameLocal = Get-Content /etc/hostname

        if ($($VmwCmdOvfEnvGuest['guestinfo.hostname'])) {
            $GuestinfoHostname = $($VmwCmdOvfEnvGuest['guestinfo.hostname'])
            $EtcHosts = @()
            $EtcHosts += "127.0.0.1   localhost"
            $EtcHosts += "$($VmwCmdOvfEnvGuest['guestinfo.ipaddress'])   $GuestinfoHostname"
            
            if (Compare-Object $EtcHosts $EtcHostsLocal) {
                Write-Host "$((Get-Date).ToString("o")) [INFO] fixing hosts info ..."
                $EtcHosts|Set-Content -Path /etc/hosts -Force
                $NetworkToReload = $true
            } else {
                Write-Host "$((Get-Date).ToString("o")) [INFO] no hosts info changes ..."
            }

            if (Compare-Object $GuestinfoHostname $EtcHostnameLocal) {
                Write-Host "$((Get-Date).ToString("o")) [INFO] fixing hostname ..."
                $GuestinfoHostname|Set-Content -Path /etc/hostname -Force
                $NetworkToReload = $true
                Invoke-Expression "/bin/hostname $GuestinfoHostname"
            } else {
                Write-Host "$((Get-Date).ToString("o")) [INFO] no hostname changes ..."
            }

        } else {
            $EtcHosts = @()
            $EtcHosts += "127.0.0.1   localhost"
            $EtcHosts += "$($VmwCmdOvfEnvGuest['guestinfo.ipaddress'])   $EtcHostnameLocal"
            
            if (Compare-Object $EtcHosts $EtcHostsLocal) {
                Write-Host "$((Get-Date).ToString("o")) [INFO] fixing hosts info with stock hostname ..."
                $EtcHosts|Set-Content -Path /etc/hosts -Force
                $NetworkToReload = $true
            }
        }
    }

    if ($NetworkToReload -eq $true) {
        Write-Host "$((Get-Date).ToString("o")) [INFO] restarting network ..."
        try {
            Invoke-Expression "systemctl restart networking"
            Invoke-Expression "systemctl restart resolvconf"
            Invoke-Expression "ifdown eth0 --force && ifup eth0 --force"
        } catch {
            Write-Host "$((Get-Date).ToString("o")) [WARN] network restart failure"
        }
    } else {
        Write-Host "$((Get-Date).ToString("o")) [INFO] no network changes ..."
    }
    
} catch {
    Write-Host "$((Get-Date).ToString("o")) [WARN] guestinfo.ovfEnv invoke failure"
}