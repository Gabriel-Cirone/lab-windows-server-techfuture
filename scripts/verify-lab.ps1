# Final check - the whole lab from SRV
# This file CAN be run as a whole, once all phases are done.
# It only reads state; it changes nothing.
# Run on: SRV (PowerShell as Administrator)

function Write-Section($text) { Write-Host "`n== $text ==" -ForegroundColor Cyan }

Write-Section "Domain and DNS"
Get-ADDomain | Select-Object DNSRoot, NetBIOSName | Format-Table -AutoSize
"fileserver.techfuture.local", "intranet.techfuture.local" | ForEach-Object {
    Resolve-DnsName $_ -Type A | Select-Object Name, IPAddress
} | Format-Table -AutoSize

Write-Section "DHCP: scopes and reservations"
Get-DhcpServerv4Scope | Select-Object Name, ScopeId, State | Format-Table -AutoSize
Get-DhcpServerv4Reservation -ScopeId 10.10.40.0 | Select-Object Name, IPAddress | Format-Table -AutoSize

Write-Section "Policies"
Get-GPO -All | Select-Object DisplayName | Sort-Object DisplayName | Format-Table -AutoSize
Get-ADUserResultantPasswordPolicy aluno.teste | Select-Object Name, MinPasswordLength, LockoutThreshold | Format-Table -AutoSize

Write-Section "LAPS (update times only, no passwords)"
"FILESERVER", "PCCLIENTE", "SRV" | ForEach-Object {
    Get-LapsADPassword -Identity $_ | Select-Object ComputerName, Account, PasswordUpdateTime
} | Format-Table -AutoSize

Write-Section "Hardening and services per machine"
Invoke-Command -ComputerName SRV, FILESERVER, PCCLIENTE -ScriptBlock {
    [PSCustomObject]@{
        Machine    = $env:COMPUTERNAME
        SMB1       = (Get-SmbServerConfiguration).EnableSMB1Protocol
        Spooler    = (Get-Service Spooler).StartType
        WazuhAgent = (Get-Service WazuhSvc -ErrorAction SilentlyContinue).Status
        Sysmon     = (Get-Service Sysmon64 -ErrorAction SilentlyContinue).Status
        SSH        = (Get-Service sshd -ErrorAction SilentlyContinue).Status
    }
} | Select-Object Machine, SMB1, Spooler, WazuhAgent, Sysmon, SSH | Format-Table -AutoSize

Write-Section "File Server"
Invoke-Command -ComputerName FILESERVER -ScriptBlock {
    Get-SmbShare | Where-Object Path -like "D:*" | Select-Object Name, Path | Format-Table -AutoSize | Out-String
    Get-DedupStatus -Volume "E:" | Select-Object Volume, SavedSpace | Format-Table -AutoSize | Out-String
    Get-BitLockerVolume | Select-Object MountPoint, VolumeStatus, ProtectionStatus | Format-Table -AutoSize | Out-String
    Get-ScheduledTask -TaskName "Backup Robocopy", "Copias de Sombra D" | Select-Object TaskName, State | Format-Table -AutoSize | Out-String
}

Write-Section "iSCSI disk on SRV"
Get-Disk | Where-Object BusType -eq "iSCSI" | Select-Object Number, FriendlyName, @{ n = "GB"; e = { $_.Size / 1GB } } | Format-Table -AutoSize

Write-Section "Intranet (HTTP status with domain login)"
(Invoke-WebRequest "http://intranet.techfuture.local" -UseBasicParsing -UseDefaultCredentials).StatusCode
