# Phase 3 - OUs, security groups and test users
# Run block by block, not as a whole file. See scripts/README.md.
#
# Object names are in Portuguese, as in the lab:
#   Administrativo = Administrative staff, Professores = Teachers, Alunos = Students,
#   Servidores-Membro = Member servers, Estacoes = Workstations.
#
# OUs organize users and computers and receive GPOs.
# Groups are lists of accounts and receive permissions.

# --- 3.1 Create the OUs ---
# Run on: SRV
$domain = "DC=techfuture,DC=local"

"Administrativo", "Professores", "Alunos", "Servidores-Membro", "Estacoes" | ForEach-Object {
    New-ADOrganizationalUnit -Name $_ -Path $domain
}

# --- 3.2 Create the security groups ---
# Run on: SRV
$domain = "DC=techfuture,DC=local"

"Administrativo", "Professores", "Alunos" | ForEach-Object {
    New-ADGroup -Name "GG-$_" -GroupScope Global -GroupCategory Security -Path "OU=$_,$domain"
}
New-ADGroup -Name "GG-TI" -GroupScope Global -GroupCategory Security -Path "CN=Users,$domain"

# --- 3.3 Create one test user per profile ---
# Run on: SRV
$domain = "DC=techfuture,DC=local"
$password = Read-Host "Password for the test users" -AsSecureString

$users = @(
    @{ Login = "adm.teste";   Name = "Adm Teste";   OU = "Administrativo" },
    @{ Login = "prof.teste";  Name = "Prof Teste";  OU = "Professores" },
    @{ Login = "aluno.teste"; Name = "Aluno Teste"; OU = "Alunos" }
)

foreach ($u in $users) {
    New-ADUser -Name $u.Name -SamAccountName $u.Login `
        -UserPrincipalName "$($u.Login)@techfuture.local" `
        -Path "OU=$($u.OU),$domain" -AccountPassword $password -Enabled $true
    Add-ADGroupMember -Identity "GG-$($u.OU)" -Members $u.Login
}

Add-ADGroupMember -Identity "GG-TI" -Members "Administrator"

# --- 3.4 Check ---
# Run on: SRV
Get-ADOrganizationalUnit -Filter * | Select-Object Name
Get-ADGroupMember "GG-Alunos" | Select-Object Name
Get-ADUser -Filter * -SearchBase "DC=techfuture,DC=local" | Where-Object Name -like "*Teste" | Select-Object Name, DistinguishedName
