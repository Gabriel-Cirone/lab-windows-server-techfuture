# Phase 10 - Shadow copies, Robocopy backup and BitLocker
# Run block by block, not as a whole file. See scripts/README.md.

# --- 10.1 Shadow copies on D:, twice a day on weekdays ---
# Run on: FILESERVER
vssadmin add shadowstorage /for=D: /on=D: /maxsize=1500MB
vssadmin create shadow /for=D:

$weekdays = "Monday", "Tuesday", "Wednesday", "Thursday", "Friday"
$action = New-ScheduledTaskAction -Execute "vssadmin.exe" -Argument "create shadow /for=D:"
$triggers = @(
    New-ScheduledTaskTrigger -Weekly -DaysOfWeek $weekdays -At 7am
    New-ScheduledTaskTrigger -Weekly -DaysOfWeek $weekdays -At 12pm
)
Register-ScheduledTask -TaskName "Copias de Sombra D" -Action $action -Trigger $triggers -User "SYSTEM" -RunLevel Highest

vssadmin list shadows /for=D:

# Run on: FILESERVER
# Restore test: write version 1, snapshot, overwrite with version 2,
# then restore version 1 from the file's Properties -> Previous Versions.
$file = "D:\Compartilhamentos\Transfer\teste.txt"
Set-Content -Path $file -Value "version 1"
vssadmin create shadow /for=D:
Set-Content -Path $file -Value "version 2"

# --- 10.2 Weekly Robocopy backup to SRV ---
# Run on: SRV
# Hidden share on SRV, writable by the File Server computer account.
$domainAdmins = ([System.Security.Principal.SecurityIdentifier]"$((Get-ADDomain).DomainSID.Value)-512").Translate([System.Security.Principal.NTAccount]).Value

New-Item -Path "C:\Backup\FileServer" -ItemType Directory -Force
New-SmbShare -Name 'Backup$' -Path "C:\Backup" -FullAccess 'TECHFUTURE\FILESERVER$', $domainAdmins
icacls "C:\Backup" /grant 'TECHFUTURE\FILESERVER$:(OI)(CI)M'

# Run on: FILESERVER (not SRV: the task runs as SYSTEM on the File Server)
# /COPY:DAT copies data, attributes and timestamps but not ACLs. Copying ACLs
# (/COPY:DATS) locked the FILESERVER$ account out of the destination.
New-Item -Path "C:\Logs" -ItemType Directory -Force
$action = New-ScheduledTaskAction -Execute "robocopy.exe" `
    -Argument 'D:\Compartilhamentos \\SRV\Backup$\FileServer /MIR /COPY:DAT /R:2 /W:5 /LOG:C:\Logs\robocopy.log'
$trigger = New-ScheduledTaskTrigger -Weekly -DaysOfWeek Sunday -At 2am
Register-ScheduledTask -TaskName "Backup Robocopy" -Action $action -Trigger $trigger -User "SYSTEM" -RunLevel Highest

# Test now instead of waiting for Sunday
Start-ScheduledTask -TaskName "Backup Robocopy"
Start-Sleep -Seconds 15
Get-Content "C:\Logs\robocopy.log" -Tail 15

# --- 10.3 BitLocker on C: and D: ---
# Take a VM snapshot first. The VM needs a virtual TPM.
# Run on: FILESERVER
Install-WindowsFeature BitLocker -IncludeAllSubFeature -IncludeManagementTools -Restart

# Run on: FILESERVER
Get-Tpm | Select-Object TpmPresent, TpmReady   # both must be True

Add-BitLockerKeyProtector -MountPoint "C:" -RecoveryPasswordProtector
Enable-BitLocker -MountPoint "C:" -TpmProtector -UsedSpaceOnly -EncryptionMethod XtsAes256 -SkipHardwareTest

while ((Get-BitLockerVolume -MountPoint "C:").VolumeStatus -ne "FullyEncrypted") { Start-Sleep -Seconds 10 }

Enable-BitLocker -MountPoint "D:" -RecoveryPasswordProtector -UsedSpaceOnly -EncryptionMethod XtsAes256
Enable-BitLockerAutoUnlock -MountPoint "D:"

# Run on: FILESERVER
# Shows the recovery passwords: copy them somewhere safe, outside the VM,
# and never commit them or show them in screenshots.
Get-BitLockerVolume -MountPoint "C:", "D:" | ForEach-Object {
    $_.MountPoint
    $_.KeyProtector | Where-Object KeyProtectorType -eq "RecoveryPassword" | Select-Object -ExpandProperty RecoveryPassword
}
Get-BitLockerVolume | Select-Object MountPoint, VolumeStatus, ProtectionStatus
