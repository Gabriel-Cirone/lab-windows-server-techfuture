# Phase 12 - Policies: password, GPOs and auditing
# Run block by block, not as a whole file. See scripts/README.md.

# --- 12.1 Password and lockout: fine-grained password policy (PSO) ---
# Run on: SRV
# Applied to the groups, so it overrides the domain default for these users.
New-ADFineGrainedPasswordPolicy -Name "TF-Senha-Usuarios" -Precedence 10 `
    -MinPasswordLength 14 -ComplexityEnabled $true -PasswordHistoryCount 24 `
    -MinPasswordAge "1.00:00:00" -MaxPasswordAge "90.00:00:00" `
    -LockoutThreshold 10 -LockoutDuration "00:15:00" -LockoutObservationWindow "00:15:00" `
    -ReversibleEncryptionEnabled $false

Add-ADFineGrainedPasswordPolicySubject -Identity "TF-Senha-Usuarios" `
    -Subjects "GG-Administrativo", "GG-Professores", "GG-Alunos", "GG-TI"

Get-ADUserResultantPasswordPolicy -Identity aluno.teste

# --- 12.2 Domain baseline GPO ---
# Run on: SRV
$gpo = "TF-Baseline-Seguranca"
New-GPO -Name $gpo | New-GPLink -Target "DC=techfuture,DC=local"

# SMB signing required, as client and as server
Set-GPRegistryValue -Name $gpo -Key "HKLM\System\CurrentControlSet\Services\LanmanWorkstation\Parameters" -ValueName "RequireSecuritySignature" -Type DWord -Value 1
Set-GPRegistryValue -Name $gpo -Key "HKLM\System\CurrentControlSet\Services\LanmanServer\Parameters" -ValueName "RequireSecuritySignature" -Type DWord -Value 1

# Advanced audit policy (12.3) takes precedence over legacy audit settings
Set-GPRegistryValue -Name $gpo -Key "HKLM\System\CurrentControlSet\Control\Lsa" -ValueName "SCENoApplyLegacyAuditPolicy" -Type DWord -Value 1

# Users cannot install software
Set-GPRegistryValue -Name $gpo -Key "HKLM\Software\Policies\Microsoft\Windows\Installer" -ValueName "DisableUserInstalls" -Type DWord -Value 1

# Optional: treat the intranet as a Local Intranet site (automatic logon)
Set-GPRegistryValue -Name $gpo -Key "HKCU\Software\Policies\Microsoft\Windows\CurrentVersion\Internet Settings" -ValueName "ListBox_Support_ZoneMapKey" -Type DWord -Value 1
Set-GPRegistryValue -Name $gpo -Key "HKCU\Software\Policies\Microsoft\Windows\CurrentVersion\Internet Settings\ZoneMapKey" -ValueName "intranet.techfuture.local" -Type String -Value "1"

# --- 12.3 Logon auditing ---
# Run on: SRV
# Subcategories by GUID, so they work regardless of the OS language:
#   {0CCE9215-...} = Logon, {0CCE923F-...} = Special Logon
# Applied per machine with auditpol (a limitation: new machines do not inherit it).
Invoke-Command -ComputerName SRV, FILESERVER, PCCLIENTE -ScriptBlock {
    auditpol /set /subcategory:"{0CCE9215-69AE-11D9-BED3-505054503030}" /success:enable /failure:enable
    auditpol /set /subcategory:"{0CCE923F-69AE-11D9-BED3-505054503030}" /success:enable /failure:enable
    auditpol /get /subcategory:"{0CCE9215-69AE-11D9-BED3-505054503030}"
}

# --- 12.4 Per-profile GPOs (least privilege: restriction follows risk) ---
# Run on: SRV (keep this window open for the next three blocks)
$domain = "DC=techfuture,DC=local"
$desktop = "HKCU\Software\Policies\Microsoft\Windows\Control Panel\Desktop"
$explorer = "HKCU\Software\Microsoft\Windows\CurrentVersion\Policies\Explorer"
$system = "HKCU\Software\Policies\Microsoft\Windows\System"
$usb = "HKCU\Software\Policies\Microsoft\Windows\RemovableStorageDevices"

# Password-protected screen saver; timeout in seconds
function Set-ScreenLock($gpo, $seconds) {
    Set-GPRegistryValue -Name $gpo -Key $desktop -ValueName "ScreenSaveActive" -Type String -Value "1"
    Set-GPRegistryValue -Name $gpo -Key $desktop -ValueName "SCRNSAVE.EXE" -Type String -Value "scrnsave.scr"
    Set-GPRegistryValue -Name $gpo -Key $desktop -ValueName "ScreenSaverIsSecure" -Type String -Value "1"
    Set-GPRegistryValue -Name $gpo -Key $desktop -ValueName "ScreenSaveTimeOut" -Type String -Value "$seconds"
}

# Blocked programs: PowerShell, and Windows Terminal, which opens PowerShell inside it
$blocked = "powershell.exe", "powershell_ise.exe", "pwsh.exe", "wt.exe", "WindowsTerminal.exe"

# Run on: SRV (same window) - Students: the most exposed profile, the most restricted
$gpo = "TF-Alunos"
New-GPO -Name $gpo | New-GPLink -Target "OU=Alunos,$domain"

Set-ScreenLock $gpo 300                                                                          # lock after 5 min
Set-GPRegistryValue -Name $gpo -Key $explorer -ValueName "NoControlPanel" -Type DWord -Value 1   # no Control Panel
Set-GPRegistryValue -Name $gpo -Key $system -ValueName "DisableCMD" -Type DWord -Value 2         # no Command Prompt
Set-GPRegistryValue -Name $gpo -Key $explorer -ValueName "DisallowRun" -Type DWord -Value 1      # enable the block list
for ($i = 0; $i -lt $blocked.Count; $i++) {
    Set-GPRegistryValue -Name $gpo -Key "$explorer\DisallowRun" -ValueName "$($i + 1)" -Type String -Value $blocked[$i]
}
Set-GPRegistryValue -Name $gpo -Key $usb -ValueName "Deny_All" -Type DWord -Value 1             # no USB storage

# Run on: SRV (same window) - Teachers: more autonomy
$gpo = "TF-Professores"
New-GPO -Name $gpo | New-GPLink -Target "OU=Professores,$domain"

Set-ScreenLock $gpo 600
Set-GPRegistryValue -Name $gpo -Key $explorer -ValueName "DisallowCpl" -Type DWord -Value 1     # hide some Control Panel items
Set-GPRegistryValue -Name $gpo -Key "$explorer\DisallowCpl" -ValueName "1" -Type String -Value "Microsoft.NetworkAndSharingCenter"
Set-GPRegistryValue -Name $gpo -Key "$explorer\DisallowCpl" -ValueName "2" -Type String -Value "Microsoft.UserAccounts"
Set-GPRegistryValue -Name $gpo -Key $system -ValueName "DisableCMD" -Type DWord -Value 2
Set-GPRegistryValue -Name $gpo -Key $explorer -ValueName "DisallowRun" -Type DWord -Value 1
for ($i = 0; $i -lt $blocked.Count; $i++) {
    Set-GPRegistryValue -Name $gpo -Key "$explorer\DisallowRun" -ValueName "$($i + 1)" -Type String -Value $blocked[$i]
}
# USB: read allowed, write denied (removable disks class GUID)
Set-GPRegistryValue -Name $gpo -Key "$usb\{53f5630d-b6bf-11d0-94f2-00a0c91efb8b}" -ValueName "Deny_Write" -Type DWord -Value 1

# Run on: SRV (same window) - Administrative staff: screen lock only
$gpo = "TF-Administrativo"
New-GPO -Name $gpo | New-GPLink -Target "OU=Administrativo,$domain"
Set-ScreenLock $gpo 900

# --- 12.5 Check and apply ---
# Run on: SRV
Get-GPInheritance -Target "OU=Alunos,DC=techfuture,DC=local" | Select-Object -ExpandProperty InheritedGpoLinks | Select-Object DisplayName, Target
Invoke-Command -ComputerName PCCLIENTE -ScriptBlock { gpupdate /force }
# Then log on to PCCLIENTE as aluno.teste: Prompt, PowerShell and Control Panel must be blocked.
