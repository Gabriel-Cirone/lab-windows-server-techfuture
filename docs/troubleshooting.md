# Troubleshooting log

Real problems found while building the lab, in the order they appeared. Each entry has the symptom, the cause and the fix.

## Domain controller

**`Install-ADDSForest` refused to promote the server.**
The built-in local Administrator had a blank password. On promotion that account becomes the domain Administrator, so it must have a strong password first. Fix: set one (`lusrmgr.msc` or Ctrl+Alt+Del → Change a password), then promote.

## Sophos Firewall

**Console at `https://172.16.16.16:4444` timed out.**
The Sophos VM had been powered off since installation. Fix: power it on and wait 3–5 minutes for the console prompt.

**Setup wizard showed `undefined` in its fields.**
Stale browser cache from a previous attempt. Fix: reload from the root URL `https://172.16.16.16:4444`.

**Zone list only offered the defaults (LAN, WAN, DMZ, VPN, WiFi).**
The project zones had never been created. Fix: create `ADMINISTRATIVO`, `PROFESSORES` and `ALUNOS` in *Network → Zones* first, then assign them on each interface. The zone screen has no field for ports.

## DHCP and DHCP Relay

**Test client stuck on `169.254.x.x`; `ipconfig /renew` said it could not contact the DHCP server.**
Three causes stacked up:
1. Port3, Port4 and Port5 on Sophos were *Unbound / Not configured*, with no IP and no zone, so the gateway `10.10.30.1` did not exist.
2. The user zones did not exist (see above).
3. The relay entries pointed to `10.10.10.2`, `10.10.20.2` and `10.10.30.2`, addresses inside the user networks, instead of SRV.

Fix: create the zones, bind and address the ports, point all three relay entries to `10.10.40.2`.

**After a static-IP test, `ipconfig /renew` failed with "no adapter is in the state permissible".**
Setting a static IP had disabled DHCP on the adapter. Fix: remove the static address and route, run `Set-NetIPInterface -Dhcp Enabled`, reset DNS and restart the adapter.

**DHCP reservation rejected as "already exists".**
A placeholder MAC had been typed instead of the real one. Fix: `Remove-DhcpServerv4Reservation`, then recreate it with the MAC from `Get-NetAdapter`.

**Ubuntu (Wazuh) ignored its DHCP reservation.**
Ubuntu identifies itself to DHCP by DUID, not by MAC. Fix: `dhcp-identifier: mac` in netplan (see `scripts/15-wazuh-server.sh`).

## Domain join and remote administration

**`Add-Computer` on the client: "The specified domain either does not exist or could not be contacted".**
The client had a valid IP, but Sophos had no rule allowing user networks to reach the servers, so DNS, LDAP and Kerberos were dropped. Fix: the *Usuarios para servidores* rule.

**`Invoke-Command` from SRV worked for FILESERVER but timed out for PCCLIENTE.**
FILESERVER is on the server network, so its traffic never crosses the firewall. PCCLIENTE is behind Sophos, which blocks new connections in any direction unless a rule allows them. Only users → servers existed. `Test-NetConnection PCCLIENTE -Port 5985` showed a silent drop (timeout), the signature of a firewall. Fix: a *Servidores para Usuarios* rule (LAN → user zones).

**A command ran on the wrong machine.**
`Add-DnsServerResourceRecordA` was run on FILESERVER (DNS cmdlets only exist on SRV), and the Robocopy task was registered on SRV instead of FILESERVER. Fix: run DNS commands on SRV or through `Invoke-Command -ComputerName SRV`, unregister the misplaced task and recreate it on FILESERVER. Every script block now starts with a `# Run on:` comment for this reason.

## File server

**NFS refused to remove the `All Machines` entry.**
That built-in entry cannot be revoked, only configured. Fix: `Grant-NfsSharePermission -ClientName "All Machines" -Permission no-access`, then grant read-only to the Wazuh host only.

**Robocopy backup failed with access errors.**
`/COPY:DATS` tried to copy the NTFS ACLs, which then locked the `FILESERVER$` computer account out of the destination. Fix: `/COPY:DAT` (data, attributes, timestamps).

## Wazuh

**Agent install failed with `Invalid URI: The hostname could not be parsed`.**
The `$msi` variable held the whole install command copied from the dashboard instead of only the `.msi` URL. Fix: store only the URL.

**Sophos syslog did not produce anything in Wazuh.**
Three causes, found one at a time:
1. In Sophos *Log settings*, the syslog server existed but no log type was ticked in its column, so nothing was sent. `tcpdump` on the Wazuh host showed no packets.
2. After fixing that, packets arrived but nothing listened on UDP 514 (`ss -ulpn | grep 514` was empty). The manager had no syslog `<remote>` block.
3. `wazuh-logtest` answered `No decoder matched`. Wazuh ships Sophos decoders, but none match this firmware's `device_name=... log_component=...` format.

Fix: tick the log types, add the `<remote>` block, and write a custom decoder and rule (see [`../wazuh/`](../wazuh/)). Verified end to end: alerts for rule `100100` appear in `alerts.json`.
