# Phase 9 - DFS, NFS, iSCSI and deduplication
# Run block by block, not as a whole file. See scripts/README.md.

# --- 9.1 DFS namespace: one path for all shares ---
# Run on: FILESERVER
Install-WindowsFeature FS-DFS-Namespace -IncludeManagementTools

$authUsers = ([System.Security.Principal.SecurityIdentifier]"S-1-5-11").Translate([System.Security.Principal.NTAccount]).Value
New-Item -Path "D:\DFSRoots\Arquivos" -ItemType Directory -Force
New-SmbShare -Name "Arquivos" -Path "D:\DFSRoots\Arquivos" -ReadAccess $authUsers

New-DfsnRoot -Path "\\techfuture.local\Arquivos" -TargetPath "\\FILESERVER\Arquivos" -Type DomainV2

"Administrativo", "Professores", "Alunos", "Transfer" | ForEach-Object {
    New-DfsnFolder -Path "\\techfuture.local\Arquivos\$_" -TargetPath "\\FILESERVER\$_"
}

Get-DfsnFolder -Path "\\techfuture.local\Arquivos\*" | Select-Object Path

# --- 9.2 NFS: read-only export for the Wazuh host only ---
# Run on: FILESERVER
Install-WindowsFeature FS-NFS-Service -IncludeManagementTools

New-Item -Path "D:\NFS\Publico" -ItemType Directory -Force
icacls "D:\NFS\Publico" /grant "*S-1-1-0:(OI)(CI)RX"
New-NfsShare -Name "Publico" -Path "D:\NFS\Publico" -EnableUnmappedAccess $true

# "All Machines" cannot be removed, only configured, so it is set to no-access.
Grant-NfsSharePermission -Name "Publico" -ClientName "All Machines" -ClientType builtin -Permission no-access
Grant-NfsSharePermission -Name "Publico" -ClientName "10.10.40.4" -ClientType host -Permission readonly

Set-Content -Path "D:\NFS\Publico\leia-me.txt" -Value "File served over NFS by the File Server"
Get-NfsSharePermission -Name "Publico"

# --- 9.3 iSCSI: a 5 GB block disk lent to SRV ---
# Run on: SRV
# 1. Start the iSCSI initiator on SRV and read its identifier (IQN)
Set-Service MSiSCSI -StartupType Automatic
Start-Service MSiSCSI
$iqn = (Get-InitiatorPort).NodeAddress

# 2. On the File Server: install the role, create the virtual disk, allow only SRV
Invoke-Command -ComputerName FILESERVER -ScriptBlock {
    Install-WindowsFeature FS-iSCSITarget-Server -IncludeManagementTools
    New-Item -Path "F:\iSCSIVirtualDisks" -ItemType Directory -Force
    New-IscsiVirtualDisk -Path "F:\iSCSIVirtualDisks\LUN01.vhdx" -SizeBytes 5GB
    New-IscsiServerTarget -TargetName "srv-backup" -InitiatorIds "IQN:$using:iqn"
    Add-IscsiVirtualDiskTargetMapping -TargetName "srv-backup" -Path "F:\iSCSIVirtualDisks\LUN01.vhdx"
}

# 3. SRV connects to the target
New-IscsiTargetPortal -TargetPortalAddress 10.10.40.3
Get-IscsiTarget | Connect-IscsiTarget -IsPersistent $true

# Run on: SRV
# Format the new disk as I:
$lun = Get-Disk | Where-Object { $_.BusType -eq "iSCSI" -and $_.PartitionStyle -eq "RAW" }
Initialize-Disk -Number $lun.Number -PartitionStyle GPT
New-Partition -DiskNumber $lun.Number -UseMaximumSize -DriveLetter I |
    Format-Volume -FileSystem NTFS -NewFileSystemLabel "LUN-iSCSI" -Confirm:$false

# --- 9.4 Deduplication on E: ---
# Run on: FILESERVER
Install-WindowsFeature FS-Data-Deduplication
Enable-DedupVolume -Volume "E:" -UsageType Default
Set-DedupVolume -Volume "E:" -MinimumFileAgeDays 0

# Demo data: three copies of the same folder, then an optimization job.
1..3 | ForEach-Object { Copy-Item -Path "C:\Windows\Fonts" -Destination "E:\Copy$_" -Recurse -ErrorAction SilentlyContinue }
Start-DedupJob -Volume "E:" -Type Optimization -Wait
Get-DedupStatus -Volume "E:" | Select-Object Volume, SavedSpace, OptimizedFilesCount
