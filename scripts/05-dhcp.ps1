# Phase 5 - DHCP
# Run block by block, not as a whole file. See scripts/README.md.
#
# One DHCP server on SRV serves all four networks. The user networks reach it
# through the DHCP Relay on Sophos (docs/sophos-firewall.md, step 5).

# --- 5.1 Install and authorize in AD ---
# Run on: SRV
Install-WindowsFeature DHCP -IncludeManagementTools
Add-DhcpServerInDC -DnsName "srv.techfuture.local" -IPAddress 10.10.40.2
netsh dhcp add securitygroups
Restart-Service dhcpserver

# --- 5.2 Options for every network ---
# Run on: SRV
Set-DhcpServerv4OptionValue -DnsServer 10.10.40.2 -DnsDomain "techfuture.local"

# --- 5.3 Four scopes ---
# Run on: SRV
# .1 is the gateway (Sophos) and .1-.9 are excluded for fixed equipment.
$networks = @(
    @{ Name = "Servidores";     Network = "10.10.40.0"; Mask = "255.255.255.224"; Last = 30 },
    @{ Name = "Administrativo"; Network = "10.10.10.0"; Mask = "255.255.255.0";   Last = 254 },
    @{ Name = "Professores";    Network = "10.10.20.0"; Mask = "255.255.255.0";   Last = 254 },
    @{ Name = "Alunos";         Network = "10.10.30.0"; Mask = "255.255.255.0";   Last = 254 }
)

foreach ($n in $networks) {
    $prefix = $n.Network.Substring(0, $n.Network.LastIndexOf("."))   # e.g. 10.10.40

    Add-DhcpServerv4Scope -Name $n.Name -StartRange "$prefix.1" -EndRange "$prefix.$($n.Last)" `
        -SubnetMask $n.Mask -State Active
    Add-DhcpServerv4ExclusionRange -ScopeId $n.Network -StartRange "$prefix.1" -EndRange "$prefix.9"
    Set-DhcpServerv4OptionValue -ScopeId $n.Network -Router "$prefix.1"
}

# --- 5.4 Check ---
# Run on: SRV
Get-DhcpServerInDC
Get-DhcpServerv4Scope | Select-Object Name, ScopeId, StartRange, EndRange, State
Get-DhcpServerv4ExclusionRange
Get-DhcpServerv4OptionValue -ScopeId 10.10.30.0
