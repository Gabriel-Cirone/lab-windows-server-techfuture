# Sophos Firewall → Wazuh: custom decoder and rules

Wazuh ships decoders for Sophos (`0300-sophos_decoders.xml`, `0510-sophos_fw_decoders.xml`), but in this lab none of them matched the logs sent by Sophos Firewall Home Edition. `wazuh-logtest` answered `No decoder matched` for every line. This folder holds the decoder and rules written to parse them.

Tested with **Wazuh 4.14.9** and **Sophos Firewall Home Edition** (`device_model="SFVH"`), syslog format *Standard syslog protocol*.

## What it extracts

| Field | Source key | Example |
| --- | --- | --- |
| `action` | `log_subtype` | `Allowed` |
| `fw_rule_name` | `fw_rule_name` | `Usuarios para servidores` |
| `srcip` | `src_ip` | `10.10.30.10` |
| `dstip` | `dst_ip` | `10.10.40.2` |
| `dstport` | `dst_port` | `53` |
| `src_zone` | `src_zone` | `ALUNOS` |
| `dst_zone` | `dst_zone` | `LAN` |

| Rule | Level | Fires on |
| --- | --- | --- |
| 100100 | 3 | Every connection Sophos logs |
| 100101 | 7 | Connections with `log_subtype="Denied"` |

Rule 100100 was verified end to end in the lab: alerts appeared in `alerts.json` with all fields above. Rule 100101 follows the same pattern but was not exercised, because no denied connection was logged during the test.

## Install

**1. Sophos** — *System services → Log settings*: add the Wazuh server as a syslog server (UDP 514), then tick at least **Firewall rules** in that server's column and click **Apply**. Adding the server alone sends nothing. Details in [`../docs/sophos-firewall.md`](../docs/sophos-firewall.md).

**2. Wazuh manager — listen for syslog.** Check first whether a syslog block already exists:

```bash
sudo grep -n "syslog" /var/ossec/etc/ossec.conf
```

If there is none, append one (replace the IP with your firewall's):

```bash
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
```

**3. Copy the decoder and rules:**

```bash
sudo cp decoders/sophos_sfos_decoder.xml /var/ossec/etc/decoders/
sudo cp rules/sophos_sfos_rules.xml /var/ossec/etc/rules/
sudo chown wazuh:wazuh /var/ossec/etc/decoders/sophos_sfos_decoder.xml /var/ossec/etc/rules/sophos_sfos_rules.xml
sudo chmod 660 /var/ossec/etc/decoders/sophos_sfos_decoder.xml /var/ossec/etc/rules/sophos_sfos_rules.xml
```

If your firewall's hostname is not `Sophos`, edit `device_name="Sophos"` in the decoder's `<prematch>`.

**4. Test before restarting:**

```bash
sudo /var/ossec/bin/wazuh-logtest
```

Paste the line from [`samples/sophos-firewall-allowed.log`](samples/sophos-firewall-allowed.log). Expected: *Phase 2* shows decoder `sophos-sfos` with the fields above, and *Phase 3* shows rule `100100` and `Alert to be generated`.

**5. Restart and verify:**

```bash
sudo systemctl restart wazuh-manager
sudo ss -ulpn | grep 514                       # wazuh-remoted should be listening
sudo tail -f /var/ossec/logs/alerts/alerts.json | grep --line-buffered 100100
```

Generate traffic through the firewall and alerts should start appearing. In the dashboard, search for `rule.id:100100`.

## Troubleshooting

| Symptom | Check |
| --- | --- |
| `tcpdump -i any udp port 514` shows nothing | Log types not ticked for the syslog server in Sophos |
| Packets arrive but no alerts | `ss -ulpn \| grep 514` is empty, so the `<remote>` block is missing |
| `wazuh-logtest`: `No decoder matched` | Hostname in `<prematch>` differs, or the decoder file is not in `/var/ossec/etc/decoders/` |

Rule 100100 fires on every logged connection, which is noisy outside a lab. In production, raise the level only for the rules and zones you care about.
