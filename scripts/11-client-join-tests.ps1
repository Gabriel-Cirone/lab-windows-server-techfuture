# Phase 11 - Test client: network, domain and per-profile tests
# Run block by block, not as a whole file. See scripts/README.md.
#
# PCCLIENTE starts on vmnet4 (Students). To act as another profile, change its
# network adapter in VMware (vmnet3 = Teachers, vmnet2 = Administrative) and reboot.

# --- 11.1 First test: the DHCP Relay ---
# Run on: PCCLIENTE
# Expected: IP 10.10.30.x, gateway 10.10.30.1, DNS 10.10.40.2, File Server at
# 10.10.40.3 and TcpTestSucceeded: True. A 169.254.x.x address means the relay failed.
# Requires the Sophos rule "Usuarios para servidores" (docs/sophos-firewall.md).
Get-NetIPConfiguration | Select-Object IPv4Address, IPv4DefaultGateway, DNSServer
Resolve-DnsName fileserver.techfuture.local
Test-NetConnection fileserver.techfuture.local -Port 445

# Confirm the lease on the DHCP server: IP and MAC must match the client.
# Run on: SRV
Get-DhcpServerv4Lease -ScopeId 10.10.30.0 | Select-Object IPAddress, ClientId, HostName, LeaseExpiryTime

# --- 11.2 Join the domain (reboots) ---
# Run on: PCCLIENTE
Add-Computer -DomainName "techfuture.local" -NewName "PCCLIENTE" `
    -Credential TECHFUTURE\Administrator -Restart

# --- 11.3 Enable remote administration ---
# Run on: PCCLIENTE (logged on as TECHFUTURE\Administrator)
Enable-PSRemoting -Force

# --- 11.4 Move to the workstations OU and test remote access ---
# Run on: SRV
# Requires the Sophos rule "Servidores para Usuarios": without it, WinRM (5985)
# from SRV to the client times out, because the firewall drops new connections
# in any direction unless a rule allows them.
Get-ADComputer PCCLIENTE | Move-ADObject -TargetPath "OU=Estacoes,DC=techfuture,DC=local"
Invoke-Command -ComputerName PCCLIENTE -ScriptBlock { hostname }

# --- 11.5 Student profile ---
# Run on: PCCLIENTE (logged on as aluno.teste, normal PowerShell, one line at a time)
# The GPO that blocks PowerShell for students only arrives in phase 12.
whoami /groups | Select-String "GG-"                          # shows GG-Alunos
New-Item "\\fileserver\Alunos\do-aluno.txt" -ItemType File   # works
Get-ChildItem "\\fileserver\Professores"                     # Access denied
Get-ChildItem "\\techfuture.local\Arquivos"                  # the four folders via DFS
New-Item "\\fileserver\Transfer\do-aluno.txt" -ItemType File  # works
Test-NetConnection 10.10.10.50 -Port 445                     # fails: no rule between user networks

# --- 11.6 Teacher profile ---
# Switch the adapter to vmnet3, reboot, log on as prof.teste.
# Run on: PCCLIENTE
Get-NetIPConfiguration | Select-Object IPv4Address, IPv4DefaultGateway   # 10.10.20.x
Get-ChildItem "\\fileserver\Professores"                                 # works
Get-ChildItem "\\fileserver\Alunos"                                      # Access denied
Remove-Item "\\fileserver\Transfer\do-aluno.txt"                         # Access denied: not the creator

# --- 11.7 Administrative profile ---
# Switch to vmnet2, reboot, log on as adm.teste: the IP becomes 10.10.10.x and
# only \\fileserver\Administrativo opens. Afterwards, put the adapter back on
# vmnet4 and reboot (the default position for phase 12).
