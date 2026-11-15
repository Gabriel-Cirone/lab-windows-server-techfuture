# Sophos Firewall configuration

Sophos Firewall (Home Edition) is configured in its web console, not with PowerShell. This page lists what was set, in the order it has to be done. The order matters: the zones must exist before the ports can use them, and the ports must exist before the DHCP Relay and the rules can use them.

## VM network adapters

The Sophos VM has five network adapters, one per VMware network:

| Adapter | VMware network | Sophos port | Purpose |
| --- | --- | --- | --- |
| 1 | vmnet5 | Port1 | Servers (LAN) |
| 2 | vmnet8 (NAT) | Port2 | WAN / internet |
| 3 | vmnet2 | Port3 | Administrative |
| 4 | vmnet3 | Port4 | Teachers |
| 5 | vmnet4 | Port5 | Students / labs |

The VM uses legacy BIOS firmware.

## 1. First access

Sophos ships with Port1 on `172.16.16.16`, and the console only answers from that range. Give SRV a temporary second address in the same range (`scripts/04-sophos-first-access.ps1`), then open `https://172.16.16.16:4444`.

> Turn the Sophos VM on first and wait 3–5 minutes until its console shows the login prompt. A powered-off firewall looks exactly like a network problem.

In the setup wizard, set:
- the admin password, hostname and time zone (`America/Sao_Paulo`)
- **LAN** on `10.10.40.1/27`, with the built-in DHCP server **disabled** (DHCP lives on SRV)

From then on the console is at `https://10.10.40.1:4444`, and the temporary address on SRV can be removed.

## 2. Zones — Network → Zones

Create three zones, all of type **LAN**, with only **Ping/Ping6** allowed under *Device access*:

- `ADMINISTRATIVO`
- `PROFESSORES`
- `ALUNOS`

The zone screen has no field for ports or IPs. Ports are assigned to zones from the interface screen, and the zone's *Members* column fills in by itself.

## 3. Interfaces — Network → Interfaces

| Port | Network zone | IPv4 / mask |
| --- | --- | --- |
| Port1 | LAN | 10.10.40.1 /27 |
| Port2 | WAN | DHCP from VMware NAT |
| Port3 | ADMINISTRATIVO | 10.10.10.1 /24 |
| Port4 | PROFESSORES | 10.10.20.1 /24 |
| Port5 | ALUNOS | 10.10.30.1 /24 |

## 4. Firewall rules — Rules and policies → Firewall rules

| # | Name | Source zones | Destination zones | Services | Action | Notes |
| --- | --- | --- | --- | --- | --- | --- |
| 1 | Usuarios para servidores | ADMINISTRATIVO, PROFESSORES, ALUNOS | LAN | Any | Accept | Domain logon, DNS, file shares |
| 2 | Usuarios para internet | ADMINISTRATIVO, PROFESSORES, ALUNOS | WAN | Any | Accept | Linked NAT rule, source translation **MASQ** |
| 3 | Servidores para Usuarios | LAN | ADMINISTRATIVO, PROFESSORES, ALUNOS | Any | Accept | Remote administration from SRV (WinRM) |

**Log firewall traffic** is enabled on all three. Below them stays the default **Drop all**.

There is no rule between user zones, so a student cannot reach the administrative network. That is the isolation the project is built on. Rule 3 does not break it: it only allows connections that start on the server network.

## 5. DHCP Relay — Network → DHCP → Relay

| Interface | DHCP server IP |
| --- | --- |
| Port3 | 10.10.40.2 |
| Port4 | 10.10.40.2 |
| Port5 | 10.10.40.2 |

DHCP broadcasts do not cross a router. The relay catches them on each user network and forwards them to the DHCP server on SRV. Every entry must point to SRV, not to an address inside the user network.

## 6. Syslog to Wazuh — System services → Log settings

1. Under **Syslog servers**, click **Add**: name `wazuh`, IP `10.10.40.4`, port `514`, facility `DAEMON`, severity `Information`, format **Standard syslog protocol**.
2. Under **Log settings**, tick the log types you want **in the `wazuh` column**, at least **Firewall rules** and **Invalid traffic**, then click **Apply**.

Adding the server alone sends nothing. Each log type has to be ticked in that server's column. On the Wazuh side, see [`../wazuh/README.md`](../wazuh/README.md).
