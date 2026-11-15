# Build scripts

The lab was built in 17 phases. Each file here is one phase, in order.

**These are not run-once installers.** Blocks run on different machines, some need a reboot in between, and a few steps happen in the VMware or Sophos interfaces. Run them **block by block**, reading the comment above each one.

## Conventions

- Every block starts with `# Run on: <MACHINE>` — SRV, FILESERVER, PCCLIENTE or WAZUH. Running a block on the wrong machine was a real mistake during the build (see [`../docs/troubleshooting.md`](../docs/troubleshooting.md)).
- Windows blocks run in **PowerShell as Administrator**. Bash blocks (`*.sh`) run on the Wazuh server, over SSH from SRV.
- Passwords are never written in the scripts. They are read with `Read-Host -AsSecureString` or typed when prompted.
- Values in angle brackets, such as `<FILESERVER-MAC>`, are placeholders to replace before running.
- Variables are lost when the PowerShell window closes. If you reopen it, rerun the lines that define them.
- Take a VM snapshot before each phase.

## Phases

| File | Phase | Main machine |
| --- | --- | --- |
| `01-srv-base.ps1` | Name, static IP, time zone | SRV |
| `02-domain.ps1` | AD DS, promotion to domain controller, DNS forwarders | SRV |
| `03-ous-groups-users.ps1` | OUs, security groups, test users | SRV |
| `04-sophos-first-access.ps1` | Temporary IP to reach the Sophos console (rest in [`../docs/sophos-firewall.md`](../docs/sophos-firewall.md)) | SRV |
| `05-dhcp.ps1` | DHCP server, four scopes | SRV |
| `06-fileserver-join-disks.ps1` | Reservation, domain join, data disks | FILESERVER |
| `07-shares-ntfs.ps1` | Folders, NTFS permissions, Transfer folder, shares | FILESERVER |
| `08-iis-intranet.ps1` | Intranet on IIS with Windows authentication | FILESERVER |
| `09-dfs-nfs-iscsi-dedup.ps1` | DFS namespace, NFS, iSCSI target, deduplication | FILESERVER |
| `10-shadowcopies-robocopy-bitlocker.ps1` | Shadow copies, scheduled backup, BitLocker | FILESERVER |
| `11-client-join-tests.ps1` | Client domain join and per-profile tests | PCCLIENTE |
| `12-policies-pso-gpo-audit.ps1` | Password policy, GPOs, logon auditing | SRV |
| `13-windows-laps.ps1` | Windows LAPS and DSRM backup | SRV |
| `14-best-practices.ps1` | SMBv1, Print Spooler, local Administrator rename | SRV |
| `15-wazuh-server.sh` | Ubuntu prep and Wazuh install | WAZUH |
| `16-ssh-keys.ps1` | RSA 4096 keys, key-only SSH on Windows | SRV |
| `16-ssh-hardening-wazuh.sh` | Key-only SSH on Ubuntu | WAZUH |
| `17-wazuh-agents-sysmon.ps1` | Agents, Sysmon, FIM, test cases | SRV |
| `17-wazuh-syslog.sh` | Syslog from Sophos, custom decoder | WAZUH |
| `verify-lab.ps1` | Final check of the whole lab | SRV |

Phase 0 (creating the VMs and installing the operating systems) is done in the VMware interface.
