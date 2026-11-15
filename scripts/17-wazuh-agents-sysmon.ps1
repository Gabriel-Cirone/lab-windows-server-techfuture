# Phase 17 - Wazuh agents, Sysmon, file integrity monitoring and test cases
# Run block by block, not as a whole file. See scripts/README.md.
# Sophos syslog and the custom decoder are in 17-wazuh-syslog.sh.

# --- 17.1 Install the agent on the three Windows machines ---
# Run on: SRV
# $msi must hold ONLY the .msi URL, not the install command the dashboard shows.
# Match the agent version to the manager (4.14.9 in this lab).
$msi = "https://packages.wazuh.com/4.x/windows/wazuh-agent-4.14.9-1.msi"

Invoke-Command -ComputerName SRV, FILESERVER, PCCLIENTE -ArgumentList $msi -ScriptBlock {
    param($msi)
    $installer = "$env:TEMP\wazuh-agent.msi"
    Invoke-WebRequest -Uri $msi -OutFile $installer -UseBasicParsing
    Start-Process msiexec.exe -ArgumentList "/i `"$installer`" /q WAZUH_MANAGER=10.10.40.4 WAZUH_AGENT_GROUP=default" -Wait
    Start-Service WazuhSvc
    Get-Service WazuhSvc | Select-Object @{ n = "Machine"; e = { $env:COMPUTERNAME } }, Status
}
# Check: Dashboard -> Agents management -> Summary shows three Active agents.

# --- 17.2 Sysmon on the servers, and real-time FIM on the shares ---
# Run on: SRV
Invoke-Command -ComputerName SRV, FILESERVER -ScriptBlock {
    # Sysmon with the SwiftOnSecurity community configuration
    $folder = "C:\Tools\Sysmon"
    New-Item -Path $folder -ItemType Directory -Force | Out-Null
    Invoke-WebRequest -UseBasicParsing -Uri "https://download.sysinternals.com/files/Sysmon.zip" -OutFile "$folder\Sysmon.zip"
    Expand-Archive -Path "$folder\Sysmon.zip" -DestinationPath $folder -Force
    Invoke-WebRequest -UseBasicParsing -Uri "https://raw.githubusercontent.com/SwiftOnSecurity/sysmon-config/master/sysmonconfig-export.xml" -OutFile "$folder\sysmonconfig-export.xml"
    & "$folder\Sysmon64.exe" -accepteula -i "$folder\sysmonconfig-export.xml"

    # Wazuh agent: read the Sysmon event channel
    $conf = "C:\Program Files (x86)\ossec-agent\ossec.conf"
    Add-Content -Path $conf -Value @'

<ossec_config>
  <localfile>
    <location>Microsoft-Windows-Sysmon/Operational</location>
    <log_format>eventchannel</log_format>
  </localfile>
</ossec_config>
'@

    # File Server only: watch the shared folders in real time
    if ($env:COMPUTERNAME -eq "FILESERVER") {
        Add-Content -Path $conf -Value @'

<ossec_config>
  <syscheck>
    <directories realtime="yes" check_all="yes" report_changes="yes">D:\Compartilhamentos</directories>
  </syscheck>
</ossec_config>
'@
    }

    Restart-Service WazuhSvc
    Get-Service Sysmon64, WazuhSvc | Select-Object @{ n = "Machine"; e = { $env:COMPUTERNAME } }, Name, Status
}

# Run on: SRV - Sysmon is writing events
Invoke-Command -ComputerName SRV, FILESERVER -ScriptBlock {
    Get-WinEvent -LogName "Microsoft-Windows-Sysmon/Operational" -MaxEvents 3 |
        Select-Object @{ n = "Machine"; e = { $env:COMPUTERNAME } }, TimeCreated, Id
}

# --- 17.4 Test case 1: file integrity ---
# On PCCLIENTE, as aluno.teste, in \\fileserver\Alunos: create a file, edit and
# save it, then delete it. Dashboard -> File Integrity Monitoring -> agent
# FILESERVER -> Events shows the three events with time and path.

# --- 17.5 Test case 2: failed logons ---
# On PCCLIENTE, lock the screen and mistype aluno.teste's password five times
# (stop before ten, which locks the account). Each failure is event 4625; in the
# dashboard they appear as alerts (rule.id: 60122).
# Run on: SRV
Invoke-Command -ComputerName PCCLIENTE -ScriptBlock {
    Get-WinEvent -FilterHashtable @{ LogName = "Security"; Id = 4625 } -MaxEvents 5 |
        Select-Object TimeCreated, Id, @{ n = "Message"; e = { ($_.Message -split "`n")[0] } }
}

# If the account got locked:
Unlock-ADAccount -Identity aluno.teste

# Bonus: Dashboard -> Vulnerability Detection lists known CVEs in the software
# installed on each agent, with no extra configuration.
