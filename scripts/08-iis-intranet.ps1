# Phase 8 - IIS and the intranet
# Run block by block, not as a whole file. See scripts/README.md.

# --- 8.1 Install IIS with Windows authentication ---
# Run on: FILESERVER
Install-WindowsFeature Web-Server, Web-Windows-Auth -IncludeManagementTools

# --- 8.2 Announcements page (content in Portuguese, as served to the college) ---
# Run on: FILESERVER
New-Item -Path "D:\Sites\Intranet" -ItemType Directory -Force

$html = @'
<!DOCTYPE html>
<html lang="pt-BR">
<head><meta charset="utf-8"><title>Intranet TechFuture</title></head>
<body style="font-family: Arial; max-width: 720px; margin: 40px auto;">
<h1>Intranet - Faculdade TechFuture</h1>
<h2>Avisos</h2>
<ul>
<li>Feriado: nao havera aula na proxima segunda-feira.</li>
<li>Provas do segundo bimestre na semana 12.</li>
<li>Laboratorios 1 a 4 em manutencao na sexta, das 8h as 12h.</li>
</ul>
</body>
</html>
'@
Set-Content -Path "D:\Sites\Intranet\index.html" -Value $html -Encoding UTF8

# --- 8.3 Create the site ---
# Run on: FILESERVER
Import-Module WebAdministration
Stop-Website -Name "Default Web Site"
New-WebAppPool -Name "IntranetAppPool"
New-Website -Name "IntranetTechFuture" -Port 80 -HostHeader "intranet.techfuture.local" `
    -PhysicalPath "D:\Sites\Intranet" -ApplicationPool "IntranetAppPool"

# --- 8.4 Require domain login ---
# Run on: FILESERVER
$auth = "/system.webServer/security/authentication"
Set-WebConfigurationProperty -Filter "$auth/anonymousAuthentication" -Name enabled -Value $false -PSPath IIS:\ -Location "IntranetTechFuture"
Set-WebConfigurationProperty -Filter "$auth/windowsAuthentication" -Name enabled -Value $true -PSPath IIS:\ -Location "IntranetTechFuture"

# --- 8.5 DNS record (DNS cmdlets only exist on SRV) ---
# Run on: SRV
Add-DnsServerResourceRecordA -ZoneName "techfuture.local" -Name "intranet" -IPv4Address 10.10.40.3

# --- 8.6 Test: anonymous is refused (401), domain login gets 200 ---
# Run on: SRV
try { Invoke-WebRequest "http://intranet.techfuture.local" -UseBasicParsing } catch { $_.Exception.Message }
(Invoke-WebRequest "http://intranet.techfuture.local" -UseBasicParsing -UseDefaultCredentials).StatusCode
