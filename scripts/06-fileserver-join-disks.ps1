# Phase 6 - File Server: DHCP reservation, domain join and disks
# Run block by block, not as a whole file. See scripts/README.md.

# --- 6.1 Find the MAC address ---
# Run on: FILESERVER
Get-NetAdapter | Where-Object Status -eq "Up" | Select-Object Name, MacAddress
ipconfig

# --- 6.2 Reserve 10.10.40.3 for the File Server ---
# Run on: SRV
# Use the real MAC from 6.1 (format 00-0C-29-XX-XX-XX).
Add-DhcpServerv4Reservation -ScopeId 10.10.40.0 -IPAddress 10.10.40.3 `
    -ClientId "<FILESERVER-MAC>" -Name "FILESERVER" -Description "File Server"

# --- 6.3 Pick up the reserved IP ---
# Run on: FILESERVER
ipconfig /release
ipconfig /renew
Get-NetIPConfiguration | Select-Object IPv4Address, IPv4DefaultGateway, DNSServer

# --- 6.4 Rename and join the domain (reboots) ---
# Run on: FILESERVER
Add-Computer -DomainName "techfuture.local" -NewName "FILESERVER" `
    -Credential TECHFUTURE\Administrator -Restart

# --- 6.5 Move to the member servers OU ---
# Run on: SRV
Get-ADComputer FILESERVER | Move-ADObject -TargetPath "OU=Servidores-Membro,DC=techfuture,DC=local"

# --- 6.6 Prepare the three data disks ---
# Run on: FILESERVER
# Move the DVD drive away from D: so the data disk can use it.
Get-CimInstance Win32_Volume -Filter "DriveType=5 AND DriveLetter='D:'" |
    Set-CimInstance -Property @{ DriveLetter = "Z:" }

# Run on: FILESERVER
# One disk per function, so they do not compete for I/O.
# Disks are matched largest first, so create them with these sizes in VMware.
$roles = @(
    @{ Letter = "D"; Label = "Dados" },   # 15 GB: file shares
    @{ Letter = "E"; Label = "Dedup" },   #  8 GB: deduplication
    @{ Letter = "F"; Label = "iSCSI" }    #  6 GB: iSCSI virtual disk
)

$disks = Get-Disk | Where-Object PartitionStyle -eq "RAW" | Sort-Object Size -Descending

for ($i = 0; $i -lt $disks.Count; $i++) {
    $n = $disks[$i].Number
    Initialize-Disk -Number $n -PartitionStyle GPT
    New-Partition -DiskNumber $n -UseMaximumSize -DriveLetter $roles[$i].Letter |
        Format-Volume -FileSystem NTFS -NewFileSystemLabel $roles[$i].Label -Confirm:$false
}

# --- 6.7 Check ---
# Run on: FILESERVER
Get-Volume | Where-Object DriveLetter | Sort-Object DriveLetter |
    Select-Object DriveLetter, FileSystemLabel, FileSystem, @{ n = "GB"; e = { [math]::Round($_.Size / 1GB, 1) } }
