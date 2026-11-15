# Phase 14 - Best practices: turn off what is not used
# Run block by block, not as a whole file. See scripts/README.md.

# --- 14.1 Confirm SMBv1 is off (WannaCry, 2017, spread over SMBv1) ---
# Run on: SRV
Invoke-Command -ComputerName SRV, FILESERVER, PCCLIENTE -ScriptBlock {
    $smb1 = (Get-SmbServerConfiguration).EnableSMB1Protocol
    if ($smb1) { Set-SmbServerConfiguration -EnableSMB1Protocol $false -Force }
    [PSCustomObject]@{ Machine = $env:COMPUTERNAME; SMB1Enabled = (Get-SmbServerConfiguration).EnableSMB1Protocol }
}

# --- 14.2 Disable the Print Spooler on servers (PrintNightmare, CVE-2021-34527) ---
# Run on: SRV
Invoke-Command -ComputerName SRV, FILESERVER -ScriptBlock {
    Stop-Service -Name Spooler -Force
    Set-Service -Name Spooler -StartupType Disabled
    Get-Service Spooler | Select-Object @{ n = "Machine"; e = { $env:COMPUTERNAME } }, Status, StartType
}

# --- 14.3 Rename the built-in local Administrator (RID 500) ---
# Run on: SRV
# Done per machine with PowerShell, not by GPO (a limitation: new machines do not inherit it).
Invoke-Command -ComputerName FILESERVER, PCCLIENTE -ScriptBlock {
    Get-LocalUser | Where-Object { $_.SID -like "*-500" } | Rename-LocalUser -NewName "tf-localadm"
    Get-LocalUser | Where-Object { $_.SID -like "*-500" } | Select-Object @{ n = "Machine"; e = { $env:COMPUTERNAME } }, Name, SID
}

# Run on: SRV
# LAPS follows the account by RID, so it keeps managing it after the rename.
Invoke-Command -ComputerName FILESERVER -ScriptBlock { Invoke-LapsPolicyProcessing }
Get-LapsADPassword -Identity FILESERVER -AsPlainText | Select-Object Account, PasswordUpdateTime
