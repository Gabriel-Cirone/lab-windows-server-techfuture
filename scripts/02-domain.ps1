# Phase 2 - Domain: AD DS, DNS and forwarders
# Run block by block, not as a whole file. See scripts/README.md.

# Before promoting: the built-in local Administrator must have a strong password.
# It becomes the domain Administrator, and promotion fails if it is blank.

# --- 2.1 Install the AD DS role ---
# Run on: SRV
Install-WindowsFeature AD-Domain-Services -IncludeManagementTools

# --- 2.2 Promote to domain controller (reboots) ---
# Run on: SRV
# The DSRM password is the recovery password for Directory Services Restore Mode.
# Phase 13 later backs it up to AD with Windows LAPS.
$dsrm = Read-Host "DSRM password" -AsSecureString

Install-ADDSForest `
    -DomainName "techfuture.local" `
    -DomainNetbiosName "TECHFUTURE" `
    -InstallDns `
    -SafeModeAdministratorPassword $dsrm `
    -Force

# --- 2.3 Check the domain ---
# Run on: SRV
Get-ADDomain | Select-Object DNSRoot, NetBIOSName, DomainMode
Resolve-DnsName techfuture.local
dcdiag /q

# --- 2.4 DNS forwarders for external names ---
# Run on: SRV
# They start working once Sophos provides the internet path (phase 4).
Set-DnsServerForwarder -IPAddress 1.1.1.1, 8.8.8.8
Get-DnsServerForwarder
