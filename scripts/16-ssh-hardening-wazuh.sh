#!/usr/bin/env bash
# Phase 16.3 - Key-only SSH on the Wazuh server (Ubuntu)
# Run after 16.2 in 16-ssh-keys.ps1 has copied the public key.
# Keep your current session open until a new key-based login works.

# Run on: WAZUH
sudo tee /etc/ssh/sshd_config.d/00-hardening.conf > /dev/null <<'EOF'
PasswordAuthentication no
KbdInteractiveAuthentication no
PermitRootLogin no
PubkeyAuthentication yes
Ciphers aes256-gcm@openssh.com,aes128-gcm@openssh.com,aes256-ctr,aes192-ctr,aes128-ctr
EOF

# Validate the config before restarting, so a typo cannot lock you out
sudo sshd -t && sudo systemctl restart ssh
