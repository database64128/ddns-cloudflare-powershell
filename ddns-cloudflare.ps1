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
    # If $Settings.IPv6.Enable was $True but no IPv6 address was detected, $IPv6.Length would be zero and the AAAA record wouldn't be updated.
    # This is to make sure when there is a problem with IPv6 but IPv4 still works, the script can still update the A record.
    try {
        if ($Settings.IPv4.Enable) {
            # Get current public IPv4 address via AddressAPI
            $IPv4 = Invoke-WebRequest -NoProxy -TimeoutSec 15 $Settings.IPv4.AddressAPI | Select-Object -ExpandProperty Content
            $IPv4 = $IPv4.Trim()
            if ($IPv4.Length -le 0) {
                throw "Failed to get current public IPv4 address: " + $Settings.IPv4.AddressAPI + " is probably down.";
            }
            # Compare the results.
            if ($Settings.EnableCompare) {
                # Resolve the A record
                if ($IsWindows) {
                    $IPv4Resolved = Resolve-DnsName -Name $Settings.IPv4.Hostname -DnsOnly -QuickTimeout -Type A | Select-Object -First 1 -ExpandProperty IPAddress
                }
                if ($IsLinux) {
                    $Temp = ('s/' + $Settings.IPv4.Hostname + ' has address //p')
                    $IPv4Resolved = /usr/bin/host -t A $Settings.IPv4.Hostname | sed -n $Temp
                }
                if ($IPv4Resolved.Length -le 0) {
                    throw "Failed to resolve the A record. Operation aborted.";
                }
                if ($IPv4 -eq $IPv4Resolved) {
                    # Write-Log -Content "Same IPv4 record:",$IPv4
                    Return
                }
            }
            # Send request to update the record.
            $parms = @{
                NoProxy = !$Settings.UseProxy
                TimeoutSec = 15
                Uri = $Settings.IPv4.CloudflareUri
                Body = ('{"type":"A","name":"' + $Settings.IPv4.Hostname + '","content":"' + $IPv4 + '","ttl":120,"proxied":'+ $Settings.IPv4.Proxied + '}') 
            }
            $Result = Invoke-WebRequest @parms -Method PUT -Authentication OAuth -Token (ConvertTo-SecureString $Settings.OAuthToken -AsPlainText -Force) -Headers @{"Content-Type" = "application/json" } | Select-Object -ExpandProperty Content
            Write-Log -Content $Result
        }        
        if ($Settings.IPv6.Enable) {
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
            # Compare the results.
            if ($Settings.EnableCompare) {
                # Resolve the AAAA record
                if ($IsWindows) {
                    $IPv6Resolved = Resolve-DnsName -Name $Settings.IPv6.Hostname -DnsOnly -QuickTimeout -Type AAAA | Select-Object -First 1 -ExpandProperty IPAddress
                }
                if ($IsLinux) {
                    $Temp = ('s/' + $Settings.IPv6.Hostname + ' has IPv6 address //p')
                    $IPv6Resolved = /usr/bin/host -t AAAA $Settings.IPv6.Hostname | sed -n $Temp
                }
                if ($IPv6Resolved.Length -le 0) {
                    throw "Failed to resolve the AAAA record. Operation aborted.";
                }
                if ($IPv6 -eq $IPv6Resolved) {
                    # Write-Log -Content "Same IPv6 record:",$IPv6
                    Return
                }
            }
            # Send request to update the record.
            $parms = @{
                NoProxy = !$Settings.UseProxy
                TimeoutSec = 15
                Uri = $Settings.IPv6.CloudflareUri
                Body = ('{"type":"AAAA","name":"' + $Settings.IPv6.Hostname + '","content":"' + $IPv6 + '","ttl":120,"proxied":'+ $Settings.IPv6.Proxied + '}') 
            }
            $Result = Invoke-WebRequest @parms -Method PUT -Authentication OAuth -Token (ConvertTo-SecureString $Settings.OAuthToken -AsPlainText -Force) -Headers @{"Content-Type" = "application/json" } | Select-Object -ExpandProperty Content
            Write-Log -Content $Result
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
        Start-Sleep -Seconds $Settings.Interval
    }
}
else {
    Write-Log -Content "Started one-shot DDNS updater."
    Invoke-DDNSUpdate
}
