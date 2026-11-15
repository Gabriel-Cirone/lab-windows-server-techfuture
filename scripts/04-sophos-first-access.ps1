# Phase 4 - Sophos Firewall
# Sophos is configured in its web console. The full steps (zones, interfaces,
# rules, DHCP Relay, syslog) are in docs/sophos-firewall.md.
# These blocks only support that configuration from SRV.
# Run block by block, not as a whole file. See scripts/README.md.

# --- 4.1 Temporary IP to reach the console ---
# Run on: SRV
# Power on the Sophos VM first and wait 3-5 minutes for its console prompt.
# Sophos ships on 172.16.16.16 and its console only answers from that range,
# so SRV gets a second, temporary address. 10.10.40.2 stays in place.
$nic = Get-NetAdapter | Where-Object Status -eq "Up" | Select-Object -First 1
New-NetIPAddress -InterfaceIndex $nic.ifIndex -IPAddress 172.16.16.20 -PrefixLength 24

# Now open https://172.16.16.16:4444 and run the setup wizard
# (LAN on 10.10.40.1/27, built-in DHCP server disabled).

# --- 4.2 Remove the temporary IP ---
# Run on: SRV
# After the wizard moves LAN to 10.10.40.1, the console is at https://10.10.40.1:4444.
Remove-NetIPAddress -IPAddress 172.16.16.20 -Confirm:$false

# --- 4.3 Check: gateway, internet and external DNS ---
# Run on: SRV
Test-Connection 10.10.40.1 -Count 2
Test-Connection 8.8.8.8 -Count 2
Resolve-DnsName google.com
