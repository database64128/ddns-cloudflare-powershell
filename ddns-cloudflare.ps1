# DDNS update script for Cloudflare DNS for pwsh on Windows and Linux
# This script checks if DNS records need updating by making DNS queries and comparing the results with current IP addresses.
# When both IPv4 and IPv6 are enabled, the script will fail if no IPv4 connectivity is available. It will work even if you only have IPv4.

# macOS
if ($IsMacOS) {
    Write-Host -Object "macOS is not supported."
    Return
}

function Write-Log {
    param (
        $Content
    )
    $Content = "$(Get-Date -Format s) ${Content}"
    if ($Settings.LogFilePath.Length -gt 0) {
        Out-File -InputObject $Content -FilePath $Settings.LogFilePath -Append
    }
    else {
        Write-Host -Object $Content
    }
}

function Invoke-DDNSUpdate {
    # If $Settings.EnableIPv6 was $True but no IPv6 address was detected, $IPv6.Length would be zero and the AAAA record wouldn't be updated.
    # This is to make sure when there is a problem with IPv6 but IPv4 still works, the script can still update the A record.
    try {
        if ($Settings.EnableIPv4) {
            # Get current public IPv4 address via api.ipify.org
            $IPv4 = Invoke-WebRequest -NoProxy -TimeoutSec 15 https://api.ipify.org/ | Select-Object -ExpandProperty Content
            if ($IPv4.Length -le 0) {
                throw "Failed to get current public IPv4 address: api.ipify.org is probably down.";
            }
            # Resolve the A record
            if ($IsWindows) {
                $IPv4Resolved = Resolve-DnsName -Name $Settings.Hostname -DnsOnly -QuickTimeout -Type A | Select-Object -First 1 -ExpandProperty IPAddress
            }
            if ($IsLinux) {
                $Temp = ('s/' + $Settings.Hostname + ' has address //p')
                $IPv4Resolved = /usr/bin/host -t A $Settings.Hostname | sed -n $Temp
            }
            if ($IPv4Resolved.Length -le 0) {
                throw "Failed to resolve the A record. Operation aborted.";
            }
            # Compare the results and update the record if necessary.
            if ($IPv4 -ne $IPv4Resolved) {
                $Result = Invoke-WebRequest -TimeoutSec 15 -Uri $Settings.CloudflareUriIPv4 -Method PUT -Authentication OAuth -Token (ConvertTo-SecureString $Settings.OAuthToken -AsPlainText -Force) -Headers @{"Content-Type" = "application/json" } -Body ('{"type":"A","name":"' + $Settings.Hostname + '","content":"' + $IPv4 + '","ttl":120,"proxied":false}') | Select-Object -ExpandProperty Content
                Write-Log -Content $Result
            }
        }
        if ($Settings.EnableIPv6) {
            # Get current IPv6 address using OS-specific utilities
            # $IPv6 = Invoke-WebRequest -NoProxy -TimeoutSec 15 https://api6.ipify.org/ | Select-Object -ExpandProperty Content
            if ($IsWindows) {
                $IPv6 = Get-NetIPAddress -AddressFamily IPv6 -PrefixOrigin RouterAdvertisement -SuffixOrigin Link | Select-Object -First 1 -ExpandProperty IPAddress
            }
            if ($IsLinux) {
                # mngtmpaddr may not exist in non-SLAAC configurations
                # filter temporary IPv6 addresses (privacy extension)
                $IPv6 = ip -6 addr list scope global noprefixroute | grep -v -e " fd" -e "temporary" | sed -n 's/.*inet6 \([0-9a-f:]\+\).*/\1/p' | head -n 1
            }
            if ($IPv6.Length -le 0) {
                throw "Failed to get current IPv6 address, skipping IPv6..."
            }
            # Resolve the AAAA record
            if ($IsWindows) {
                $IPv6Resolved = Resolve-DnsName -Name $Settings.Hostname -DnsOnly -QuickTimeout -Type AAAA | Select-Object -First 1 -ExpandProperty IPAddress
            }
            if ($IsLinux) {
                $Temp = ('s/' + $Settings.Hostname + ' has IPv6 address //p')
                $IPv6Resolved = /usr/bin/host -t AAAA $Settings.Hostname | sed -n $Temp
            }
            if ($IPv6Resolved.Length -le 0) {
                throw "Failed to resolve the AAAA record. Operation aborted.";
            }
            # Compare the results and update the record if necessary.
            if ($IPv6 -ne $IPv6Resolved) {
                $Result = Invoke-WebRequest -TimeoutSec 15 -Uri $Settings.CloudflareUriIPv6 -Method PUT -Authentication OAuth -Token (ConvertTo-SecureString $Settings.OAuthToken -AsPlainText -Force) -Headers @{"Content-Type" = "application/json" } -Body ('{"type":"AAAA","name":"' + $Settings.Hostname + '","content":"' + $IPv6 + '","ttl":120,"proxied":false}') | Select-Object -ExpandProperty Content
                Write-Log -Content $Result
            }
        }
        # Debug
        # Write-Host ("IPv6: " + $IPv6 + "`nIPv4: " + $IPv4 + "`nIPv6 resolved: " + $IPv6Resolved + "`nIPv4 resolved: " + $IPv4Resolved)
    }
    catch {
        Write-Log -Content "Exception thrown: $($_.Exception.Message)"
        Return
    }
}

$ErrorActionPreference = "Stop"

# Load config
$Settings = Get-Content -Path settings.jsonc | ConvertFrom-Json

if ($Settings.Interval -gt 0) {
    Write-Log -Content "Started periodic DDNS updater at intervals of $($Settings.Interval) seconds."
    while ($True) {
        Invoke-DDNSUpdate
        Start-Sleep -Seconds 300
    }
}
else {
    Write-Log -Content "Started one-shot DDNS updater."
    Invoke-DDNSUpdate
}
