#!/usr/bin/env bash
# Phase 17.3 - Sophos Firewall logs into Wazuh via syslog, with a custom decoder
# Run block by block, not as a whole file. See scripts/README.md and wazuh/README.md.
#
# Sophos side first (web console): System services -> Log settings, add the syslog
# server 10.10.40.4:514 and tick the log types IN ITS COLUMN, then Apply.
# Details in docs/sophos-firewall.md, step 6.

# --- 1. Confirm packets arrive ---
# Run on: WAZUH
# Generate traffic on PCCLIENTE meanwhile, e.g. Test-NetConnection 10.10.40.2 -Port 53.
# Nothing here means the log types are not ticked for the syslog server in Sophos.
sudo apt install -y tcpdump
sudo tcpdump -i any -nn -l --immediate-mode -A -s0 udp port 514

# --- 2. Make the manager listen for syslog ---
# Run on: WAZUH
sudo grep -n "syslog" /var/ossec/etc/ossec.conf   # if a <remote> syslog block exists, do not add another

sudo cp /var/ossec/etc/ossec.conf /var/ossec/etc/ossec.conf.bak
sudo tee -a /var/ossec/etc/ossec.conf > /dev/null <<'EOF'

<ossec_config>
  <remote>
    <connection>syslog</connection>
    <port>514</port>
    <protocol>udp</protocol>
    <allowed-ips>10.10.40.1</allowed-ips>
  </remote>
</ossec_config>
EOF
sudo systemctl restart wazuh-manager
sudo ss -ulpn | grep 514   # wazuh-remoted must be listening

# --- 3. Install the custom decoder and rules (from this repo's wazuh/ folder) ---
# Run on: WAZUH, from a copy of the repository
sudo cp wazuh/decoders/sophos_sfos_decoder.xml /var/ossec/etc/decoders/
sudo cp wazuh/rules/sophos_sfos_rules.xml /var/ossec/etc/rules/
sudo chown wazuh:wazuh /var/ossec/etc/decoders/sophos_sfos_decoder.xml /var/ossec/etc/rules/sophos_sfos_rules.xml
sudo chmod 660 /var/ossec/etc/decoders/sophos_sfos_decoder.xml /var/ossec/etc/rules/sophos_sfos_rules.xml

# --- 4. Test, then restart ---
# Run on: WAZUH
# Paste a log line starting at device_name= (or the sample in wazuh/samples/).
# Expected: decoder sophos-sfos in Phase 2, rule 100100 and "Alert to be generated" in Phase 3.
sudo /var/ossec/bin/wazuh-logtest

sudo systemctl restart wazuh-manager

# --- 5. Verify alerts end to end ---
# Run on: WAZUH
sudo tail -f /var/ossec/logs/alerts/alerts.json | grep --line-buffered 100100
