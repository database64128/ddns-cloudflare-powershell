#!/bin/pwsh
# DDNS update script for Cloudflare DNS.
# This script first retrieves existing DNS records that match the configured hostnames from Cloudflare API.
# Each time it checks the current IP against the DNS record to decide whether to create or update a DNS record.
# This script supports both Linux and Windows.

# No macOS support.
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

function Get-DNSRecord {
    param (
        [string]$Hostname,
        [string]$Type
    )

    $Body = @{
        name = $Hostname
        type = $Type
    }

    return Invoke-RestMethod $DNSRecordsUri -Authentication OAuth -Token $OAuthToken -Body $Body -ContentType "application/json" -TimeoutSec 15 -NoProxy:$Settings.NoProxy
}

function New-DNSRecord {
    param (
        [string]$Type,
        [string]$Hostname,
        [string]$IP,
        [int]$TTL = 60,
        [bool]$Proxied = $false
    )

    $Data = @{
        type    = $Type
        name    = $Hostname
        content = $IP
        ttl     = $TTL
        proxied = $Proxied
    }

    $Body = ConvertTo-Json $Data

    return Invoke-RestMethod $DNSRecordsUri -Method Post -Authentication OAuth -Token $OAuthToken -Body $Body -ContentType "application/json" -TimeoutSec 15 -NoProxy:$Settings.NoProxy
}

function Update-DNSRecordIP {
    param (
        [string]$RecordID,
        [string]$IP
    )

    $Data = @{
        content = $IP
    }

    $Body = ConvertTo-Json $Data

    return Invoke-RestMethod "$DNSRecordsUri/$RecordID" -Method Patch -Authentication OAuth -Token $OAuthToken -Body $Body -ContentType "application/json" -TimeoutSec 15 -NoProxy:$Settings.NoProxy
}

function Update-IPv4DNSRecord {
    # Get current public IPv4 address via AddressAPI
    $IPv4 = Invoke-RestMethod -NoProxy -TimeoutSec 15 $Settings.IPv4.AddressAPI
    if ($IPv4.Length -le 0) {
        throw ("Failed to get current public IPv4 address: " + $Settings.IPv4.AddressAPI + " is probably down.");
    }

    if ($null -eq $DNSRecordA) {
        # No existing A record. Create a new one.
        $Result = New-DNSRecord -Type "A" -Hostname $Settings.IPv4.Hostname -IP $IPv4 -TTL 60 -Proxied $Settings.IPv4.Proxied
        if ($Result.success) {
            $Script:DNSRecordA = $Result.result
            Write-Log -Content ("Successfully created a new A record for " + $Settings.IPv4.Hostname + " with IP ${IPv4}: $Result")
        }
        else {
            Write-Log -Content ("Failed to create a new A record for " + $Settings.IPv4.Hostname + " with IP ${IPv4}: $Result")
        }
    }
    else {
        # Compare current IPv4 with A record.
        if ($IPv4 -ne $DNSRecordA.content) {
            $Result = Update-DNSRecordIP -RecordID $DNSRecordA.id -IP $IPv4
            if ($Result.success) {
                $Script:DNSRecordA = $Result.result
                Write-Log -Content ("Successfully updated A record for " + $Settings.IPv4.Hostname + " with IP ${IPv4}: $Result")
            }
            else {
                Write-Log -Content ("Failed to update A record for " + $Settings.IPv4.Hostname + " with IP ${IPv4}: $Result")
            }
        }
    }
}

function Update-IPv6DNSRecord {
    # $IPv6 = Invoke-RestMethod -NoProxy -TimeoutSec 15 https://api6.ipify.org/
    # Get current IPv6 address using OS-specific utilities
    if ($IsWindows) {
        $IPv6 = Get-NetIPAddress -AddressFamily IPv6 -PrefixOrigin RouterAdvertisement -SuffixOrigin Link | Select-Object -First 1 -ExpandProperty IPAddress
    }
    if ($IsLinux) {
        # mngtmpaddr may not exist in non-SLAAC configurations
        # filter temporary IPv6 addresses (privacy extension)
        # TODO: Consider replacing this piece of magic with `ip -j` JSON output parsing.
        $IPv6 = ip -6 addr list scope global noprefixroute | grep -v -e " fd" -e "temporary" | sed -n 's/.*inet6 \([0-9a-f:]\+\).*/\1/p' | head -n 1
    }
    if ($IPv6.Length -le 0) {
        throw "Failed to get current IPv6 address, skipping IPv6..."
    }

    if ($null -eq $DNSRecordAAAA) {
        # No existing AAAA record. Create a new one.
        $Result = New-DNSRecord -Type "AAAA" -Hostname $Settings.IPv6.Hostname -IP $IPv6 -TTL 60 -Proxied $Settings.IPv6.Proxied
        if ($Result.success) {
            $Script:DNSRecordAAAA = $Result.result
            Write-Log -Content ("Successfully created a new AAAA record for " + $Settings.IPv6.Hostname + " with IP ${IPv6}: $Result")
        }
        else {
            Write-Log -Content ("Failed to create a new AAAA record for " + $Settings.IPv6.Hostname + " with IP ${IPv6}: $Result")
        }
    }
    else {
        # Compare current IPv6 with AAAA record.
        if ($IPv6 -ne $DNSRecordAAAA.content) {
            $Result = Update-DNSRecordIP -RecordID $DNSRecordAAAA.id -IP $IPv6
            if ($Result.success) {
                $Script:DNSRecordAAAA = $Result.result
                Write-Log -Content ("Successfully updated AAAA record for " + $Settings.IPv6.Hostname + " with IP ${IPv6}: $Result")
            }
            else {
                Write-Log -Content ("Failed to update AAAA record for " + $Settings.IPv6.Hostname + " with IP ${IPv6}: $Result")
            }
        }
    }
}

function Initialize-DNSRecords {
    if ($Settings.IPv4.Enabled) {
        $Result = Get-DNSRecord -Hostname $Settings.IPv4.Hostname -Type "A"
        if ($Result.result.Length -gt 0) {
            $Script:DNSRecordA = $Result.result[0]
            Write-Log -Content "Got initial A record: $DNSRecordA"
        }
        else {
            Write-Log -Content ("Found no existing A record for " + $Settings.IPv4.Hostname)
        }
    }
    if ($Settings.IPv6.Enabled) {
        $Result = Get-DNSRecord -Hostname $Settings.IPv6.Hostname -Type "AAAA"
        if ($Result.result.Length -gt 0) {
            $Script:DNSRecordAAAA = $Result.result[0]
            Write-Log -Content "Got initial AAAA record: $DNSRecordAAAA"
        }
        else {
            Write-Log -Content ("Found no existing AAAA record for " + $Settings.IPv6.Hostname)
        }
    }
}

function Update-DNSRecords {
    try {
        if ($Settings.IPv4.Enabled) {
            Update-IPv4DNSRecord
        }
        if ($Settings.IPv6.Enabled) {
            Update-IPv6DNSRecord
        }
    }
    catch {
        Write-Log -Content "Exception thrown: $($_.Exception.Message)"
    }
}

$ErrorActionPreference = "Stop"

# Load config
$Settings = Get-Content -Path settings.jsonc | ConvertFrom-Json
$OAuthToken = ConvertTo-SecureString $Settings.OAuthToken -AsPlainText -Force
$DNSRecordsUri = "https://api.cloudflare.com/client/v4/zones/" + $Settings.ZoneID + "/dns_records"

# Load existing records
Initialize-DNSRecords

# Start update loop
if ($Settings.Interval -gt 0) {
    Write-Log -Content "Started periodic DDNS updater at intervals of $($Settings.Interval) seconds."
    while ($True) {
        Update-DNSRecords
        Start-Sleep -Seconds $Settings.Interval
    }
}
else {
    Write-Log -Content "Started one-shot DDNS updater."
    Update-DNSRecords
}
