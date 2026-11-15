# Phase 13 - Windows LAPS
# Run block by block, not as a whole file. See scripts/README.md.
#
# Without LAPS, every machine shares the same local Administrator password,
# so one stolen password opens all of them (pass-the-hash, lateral movement).
# Windows LAPS gives each machine a unique, rotating password stored in AD.

# --- 13.1 Prepare AD and permissions ---
# Run on: SRV
Update-LapsADSchema

$ous = "OU=Servidores-Membro,DC=techfuture,DC=local", "OU=Estacoes,DC=techfuture,DC=local"
foreach ($ou in $ous) {
    Set-LapsADComputerSelfPermission -Identity $ou
    Set-LapsADReadPasswordPermission -Identity $ou -AllowedPrincipals "TECHFUTURE\GG-TI"
}

# --- 13.2 LAPS GPO for the File Server and the client ---
# Run on: SRV
$gpo = "TF-LAPS"
$laps = "HKLM\Software\Microsoft\Windows\CurrentVersion\Policies\LAPS"

New-GPO -Name $gpo | New-GPLink -Target "OU=Servidores-Membro,DC=techfuture,DC=local"
New-GPLink -Name $gpo -Target "OU=Estacoes,DC=techfuture,DC=local"

Set-GPRegistryValue -Name $gpo -Key $laps -ValueName "BackupDirectory" -Type DWord -Value 2              # 2 = Active Directory
Set-GPRegistryValue -Name $gpo -Key $laps -ValueName "PasswordComplexity" -Type DWord -Value 4           # upper, lower, digits and symbols
Set-GPRegistryValue -Name $gpo -Key $laps -ValueName "PasswordLength" -Type DWord -Value 14
Set-GPRegistryValue -Name $gpo -Key $laps -ValueName "PasswordAgeDays" -Type DWord -Value 30
Set-GPRegistryValue -Name $gpo -Key $laps -ValueName "ADPasswordEncryptionEnabled" -Type DWord -Value 1   # encrypted in AD
Set-GPRegistryValue -Name $gpo -Key $laps -ValueName "ADPasswordEncryptionPrincipal" -Type String -Value "TECHFUTURE\GG-TI"  # only GG-TI can decrypt

# --- 13.3 LAPS GPO for the domain controller: the DSRM password ---
# Run on: SRV
$gpo = "TF-LAPS-DC"
$laps = "HKLM\Software\Microsoft\Windows\CurrentVersion\Policies\LAPS"

New-GPO -Name $gpo | New-GPLink -Target "OU=Domain Controllers,DC=techfuture,DC=local"

Set-GPRegistryValue -Name $gpo -Key $laps -ValueName "BackupDirectory" -Type DWord -Value 2
Set-GPRegistryValue -Name $gpo -Key $laps -ValueName "PasswordComplexity" -Type DWord -Value 4
Set-GPRegistryValue -Name $gpo -Key $laps -ValueName "PasswordLength" -Type DWord -Value 14
Set-GPRegistryValue -Name $gpo -Key $laps -ValueName "PasswordAgeDays" -Type DWord -Value 30
Set-GPRegistryValue -Name $gpo -Key $laps -ValueName "ADPasswordEncryptionEnabled" -Type DWord -Value 1
Set-GPRegistryValue -Name $gpo -Key $laps -ValueName "ADBackupDSRMPassword" -Type DWord -Value 1         # back up the DSRM password

# --- 13.4 Apply on the three machines ---
# Run on: SRV
Invoke-Command -ComputerName SRV, FILESERVER, PCCLIENTE -ScriptBlock {
    gpupdate /force
    Invoke-LapsPolicyProcessing
}

# --- 13.5 Read and rotate ---
# Run on: SRV
# -AsPlainText prints the passwords: do not screenshot or share this output.
"FILESERVER", "PCCLIENTE", "SRV" | ForEach-Object {
    Get-LapsADPassword -Identity $_ -AsPlainText | Select-Object ComputerName, Account, Password, PasswordUpdateTime, ExpirationTimestamp
}

Invoke-Command -ComputerName FILESERVER -ScriptBlock { Reset-LapsPassword }
Get-LapsADPassword -Identity FILESERVER -AsPlainText | Select-Object Password, PasswordUpdateTime
