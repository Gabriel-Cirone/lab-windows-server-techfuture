# Phase 1 - SRV: name, static IP and time zone
# Run block by block, not as a whole file. See scripts/README.md.

# --- 1.1 Rename the server (reboots) ---
# Run on: SRV
Rename-Computer -NewName "SRV" -Restart

# --- 1.2 Static IP on the server network ---
# Run on: SRV
# The gateway 10.10.40.1 is the Sophos firewall (configured in phase 4).
# DNS points to itself, because SRV becomes the DNS server in phase 2.
$nic = Get-NetAdapter | Where-Object Status -eq "Up" | Select-Object -First 1

Set-NetIPInterface -InterfaceIndex $nic.ifIndex -Dhcp Disabled
New-NetIPAddress -InterfaceIndex $nic.ifIndex -IPAddress 10.10.40.2 -PrefixLength 27 -DefaultGateway 10.10.40.1
Set-DnsClientServerAddress -InterfaceIndex $nic.ifIndex -ServerAddresses 127.0.0.1

# --- 1.3 Time zone (Kerberos needs consistent clocks) ---
# Run on: SRV
Set-TimeZone -Id "E. South America Standard Time"

# --- 1.4 Check ---
# Run on: SRV
hostname
Get-NetIPConfiguration | Select-Object InterfaceAlias, IPv4Address, IPv4DefaultGateway, DNSServer
Get-TimeZone
