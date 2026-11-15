# Phase 16 - SSH with an RSA 4096 key pair (Windows side)
# Run block by block, not as a whole file. See scripts/README.md.
#
# SRV is the administrator's workstation: the private key stays only there,
# the public key goes to the servers. Password login is then disabled.
# The Linux side is in 16-ssh-hardening-wazuh.sh.

# --- 16.1 Generate the key pair ---
# Run on: SRV (normal PowerShell, not as Administrator)
# Set a passphrase when prompted. Never commit or share id_rsa (the private key).
ssh-keygen -t rsa -b 4096 -C "admin@techfuture"

# --- 16.2 Send the public key to Wazuh ---
# Run on: SRV
Get-Content "$env:USERPROFILE\.ssh\id_rsa.pub" | ssh admintf@10.10.40.4 "mkdir -p ~/.ssh && chmod 700 ~/.ssh && cat >> ~/.ssh/authorized_keys && chmod 600 ~/.ssh/authorized_keys"

# Now run 16-ssh-hardening-wazuh.sh on the Wazuh server.

# --- 16.4 Enable the SSH server on SRV and the File Server ---
# Run on: SRV
$publicKey = Get-Content "$env:USERPROFILE\.ssh\id_rsa.pub"

Invoke-Command -ComputerName SRV, FILESERVER -ArgumentList $publicKey -ScriptBlock {
    param($publicKey)

    # Enable the SSH service (on Windows Server 2025 it is installed but disabled)
    Add-WindowsCapability -Online -Name OpenSSH.Server~~~~0.0.1.0 | Out-Null
    Start-Service sshd
    Set-Service -Name sshd -StartupType Automatic

    # Firewall: SSH only from the server network
    Set-NetFirewallRule -Name "OpenSSH-Server-In-TCP" -RemoteAddress 10.10.40.0/27

    # SSH sessions open straight into PowerShell
    New-ItemProperty -Path "HKLM:\SOFTWARE\OpenSSH" -Name DefaultShell `
        -Value "C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe" -PropertyType String -Force | Out-Null

    # Administrators' keys file, readable only by SYSTEM and Administrators
    $keysFile = "C:\ProgramData\ssh\administrators_authorized_keys"
    Set-Content -Path $keysFile -Value $publicKey
    icacls.exe $keysFile /inheritance:r /grant "*S-1-5-32-544:F" /grant "*S-1-5-18:F" | Out-Null

    # Disable password login and restrict ciphers to AES-GCM/CTR
    # (mitigates CVE-2023-48795, "Terrapin"). Global options go at the top of the file.
    $cfg = "C:\ProgramData\ssh\sshd_config"
    $lines = (Get-Content $cfg) -replace '^#?PasswordAuthentication.*', 'PasswordAuthentication no'
    Set-Content -Path $cfg -Value (@("Ciphers aes256-gcm@openssh.com,aes128-gcm@openssh.com,aes256-ctr,aes192-ctr,aes128-ctr") + $lines)

    Restart-Service sshd
    Get-Service sshd | Select-Object @{ n = "Machine"; e = { $env:COMPUTERNAME } }, Status, StartType
}

# --- 16.5 Test: the key works, a password is refused ---
# Run on: SRV
ssh admintf@10.10.40.4 "hostname"
ssh -o PubkeyAuthentication=no admintf@10.10.40.4                        # Permission denied (publickey)

ssh -l administrator@techfuture.local fileserver "hostname"
ssh -o PubkeyAuthentication=no -l administrator@techfuture.local fileserver   # refused

ssh -l administrator@techfuture.local localhost "hostname"
