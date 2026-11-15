# Phase 7 - Folders, shares and permissions
# Run block by block, not as a whole file. See scripts/README.md.
#
# Model: open share permissions, restrictive NTFS. Share permissions only apply
# over the network, NTFS applies always, and the most restrictive of the two wins.

# --- 7.1 Create the folders ---
# Run on: FILESERVER
$base = "D:\Compartilhamentos"
"Administrativo", "Professores", "Alunos", "Transfer" | ForEach-Object {
    New-Item -Path "$base\$_" -ItemType Directory -Force
}

# --- 7.2 NTFS on the profile folders ---
# Run on: FILESERVER
# Inheritance is cut. Only SYSTEM (S-1-5-18), Administrators (S-1-5-32-544)
# and the owning group have access. Well-known SIDs avoid language-specific names.
$base = "D:\Compartilhamentos"

"Administrativo", "Professores", "Alunos" | ForEach-Object {
    icacls "$base\$_" /inheritance:r
    icacls "$base\$_" /grant "*S-1-5-18:(OI)(CI)F" "*S-1-5-32-544:(OI)(CI)F" "TECHFUTURE\GG-$($_):(OI)(CI)M"
}

# --- 7.3 The Transfer exchange folder ---
# Run on: FILESERVER
# Everyone reads and creates. CREATOR OWNER (S-1-3-0) gives Modify only on what
# each user created, so nobody can change or delete someone else's file.
$transfer = "D:\Compartilhamentos\Transfer"
$groups = "GG-Administrativo", "GG-Professores", "GG-Alunos"

icacls $transfer /inheritance:r
icacls $transfer /grant "*S-1-5-18:(OI)(CI)F" "*S-1-5-32-544:(OI)(CI)F" "*S-1-3-0:(OI)(CI)(IO)M"

foreach ($g in $groups) {
    icacls $transfer /grant "TECHFUTURE\$($g):(OI)(CI)RX"   # read everything
    icacls $transfer /grant "TECHFUTURE\$($g):(WD,AD)"      # create files and folders
}

# --- 7.4 Share ---
# Run on: FILESERVER
# Authenticated Users (S-1-5-11) gets full access at share level; NTFS does the filtering.
# Access-based enumeration hides what a user cannot open.
$base = "D:\Compartilhamentos"
$authUsers = ([System.Security.Principal.SecurityIdentifier]"S-1-5-11").Translate([System.Security.Principal.NTAccount]).Value

"Administrativo", "Professores", "Alunos" | ForEach-Object {
    New-SmbShare -Name $_ -Path "$base\$_" -FullAccess $authUsers
}
New-SmbShare -Name "Transfer" -Path "$base\Transfer" -FullAccess $authUsers -FolderEnumerationMode AccessBased

# --- 7.5 Check ---
# Run on: FILESERVER
Get-SmbShare | Where-Object Path -like "D:*" | Select-Object Name, Path, FolderEnumerationMode
icacls "D:\Compartilhamentos\Alunos"
