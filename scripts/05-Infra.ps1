# ETAPA 3 - Infraestrutura de suporte: GPO, acesso remoto (RDP), DFS e auditoria

. "$PSScriptRoot\_comum.ps1"
Testar-Admin
Titulo 'ETAPA 3 - GPO + RDP + DFS + Auditoria'
Import-Module GroupPolicy
Import-Module WebAdministration
$ip = IP-Servidor

# ---------------- GPO ----------------
Passo 'GPO: bloquear o Painel de Controle para os usuarios da OU CitizenTech'
$gpo = 'GPO_CitizenTech_Usuarios'
if (-not (Get-GPO -Name $gpo -ErrorAction SilentlyContinue)) { New-GPO -Name $gpo -Comment 'Bloqueia Painel de Controle e Configuracoes para usuarios da OU CitizenTech' | Out-Null }
try { New-GPLink -Name $gpo -Target $CT.OU -ErrorAction Stop | Out-Null } catch { Ok 'GPO ja vinculada a OU.' }
Set-GPRegistryValue -Name $gpo -Key 'HKCU\Software\Microsoft\Windows\CurrentVersion\Policies\Explorer' -ValueName 'NoControlPanel' -Type DWord -Value 1 | Out-Null
New-Item -Path 'C:\Temp' -ItemType Directory -Force | Out-Null
Get-GPOReport -Name $gpo -ReportType Html -Path 'C:\Temp\GPO_Report.html'
Copy-Item 'C:\Temp\GPO_Report.html' (Join-Path $CT.Evid '04-ntfs-gpo\GPO_Report.html') -Force
gpupdate /force | Out-Null
Evidencia '04-ntfs-gpo' '05-get-gpo-all' { Get-GPO -All | Format-Table DisplayName, GpoStatus, CreationTime -AutoSize }
Evidencia '04-ntfs-gpo' '06-gplink' { (Get-GPInheritance -Target 'OU=CitizenTech,DC=citizentech,DC=local').GpoLinks | Format-Table DisplayName, Enabled, Enforced, Target -AutoSize }
Print 'Tire print do Get-GPO -All'
Write-Host "   Para o print do usuario bloqueado: faca logoff, entre com CITIZENTECH\carlos.lima / $($CT.SenhaTeste)," -ForegroundColor DarkGray
Write-Host '   tente abrir o Painel de Controle (Win+R > control) e tire print da mensagem de restricao.' -ForegroundColor DarkGray

# ---------------- RDP ----------------
Passo 'Acesso remoto (RDP)'
Set-ItemProperty -Path 'HKLM:\System\CurrentControlSet\Control\Terminal Server' -Name 'fDenyTSConnections' -Value 0
# Grupo de regras "Remote Desktop" / "Area de Trabalho Remota" (referencia que funciona em qualquer idioma)
Enable-NetFirewallRule -Group '@FirewallAPI.dll,-28752'
Evidencia '04-ntfs-gpo' '07-rdp' { Get-ItemProperty 'HKLM:\System\CurrentControlSet\Control\Terminal Server' -Name fDenyTSConnections | Format-List fDenyTSConnections; Get-NetFirewallRule -Group '@FirewallAPI.dll,-28752' | Format-Table DisplayName, Enabled, Direction -AutoSize }
Print "No SEU PC: Win+R > mstsc > $ip > usuario CITIZENTECH\Administrator. Dentro da sessao abra o PowerShell, digite hostname e tire print."

# ---------------- DFS ----------------
Passo 'DFS Namespace (opcional, mas valorizado)'
try {
    Install-WindowsFeature -Name FS-DFS-Namespace, FS-DFS-Replication -IncludeManagementTools | Out-Null
    Import-Module DFSN
    $raiz = 'C:\DFSRoots\CitizenTechDFS'
    New-Item -Path $raiz -ItemType Directory -Force | Out-Null
    $todos = Nome-Por-SID 'S-1-1-0'
    if (-not (Get-SmbShare -Name 'CitizenTechDFS' -ErrorAction SilentlyContinue)) {
        New-SmbShare -Name 'CitizenTechDFS' -Path $raiz -ReadAccess $todos -FullAccess "$($CT.NetBIOS)\GG_CitizenTech_Admins" | Out-Null
    }
    $ns = "\\$($CT.Dominio)\CitizenTechDFS"
    if (-not (Get-DfsnRoot -Path $ns -ErrorAction SilentlyContinue)) {
        New-DfsnRoot -Path $ns -TargetPath "\\$($CT.Servidor)\CitizenTechDFS" -Type DomainV2 | Out-Null
    }
    if (-not (Get-DfsnFolder -Path "$ns\Arquivos" -ErrorAction SilentlyContinue)) {
        New-DfsnFolder -Path "$ns\Arquivos" -TargetPath "\\$($CT.Servidor)\CitizenTech" | Out-Null
    }
    Evidencia '04-ntfs-gpo' '08-get-dfsnroot' { Get-DfsnRoot | Format-Table Path, Type, State -AutoSize; Get-DfsnFolder -Path '\\citizentech.local\CitizenTechDFS\*' | Format-Table Path, State -AutoSize }
    Print 'Tire print do Get-DfsnRoot. Bonus: Win+R > \\citizentech.local\CitizenTechDFS\Arquivos'
} catch {
    Aviso "DFS nao configurado: $($_.Exception.Message) (e opcional, pode seguir)"
}

# ---------------- AUDITORIA ----------------
Passo 'Auditoria de logon e de acesso a arquivos'
# GUIDs das subcategorias (funcionam em Windows ingles ou portugues)
auditpol /set /subcategory:"{0CCE9215-69AE-11D9-BED3-505054503030}" /success:enable /failure:enable | Out-Null   # Logon
auditpol /set /subcategory:"{0CCE921D-69AE-11D9-BED3-505054503030}" /success:enable /failure:enable | Out-Null   # File System
Evidencia '07-logs' '01-auditpol' { auditpol /get /category:* }

$todosSid = New-Object Security.Principal.SecurityIdentifier('S-1-1-0')   # Everyone / Todos
$acl = Get-Acl $CT.PastaSite -Audit
$auditRule = New-Object System.Security.AccessControl.FileSystemAuditRule($todosSid, 'ReadData,WriteData', 'ContainerInherit,ObjectInherit', 'None', 'Success,Failure')
$acl.AddAuditRule($auditRule)
Set-Acl -Path $CT.PastaSite -AclObject $acl
Evidencia '07-logs' '02-regra-auditoria-pasta' { (Get-Acl 'C:\inetpub\citizentech' -Audit).Audit | Format-Table IdentityReference, FileSystemRights, AuditFlags -AutoSize }

Passo 'Gerando atividade para aparecer nos logs'
1..5 | ForEach-Object { try { Invoke-WebRequest -Uri 'http://localhost' -UseBasicParsing | Out-Null } catch {} }
Get-Content (Join-Path $CT.PastaSite 'index.html') | Out-Null
netsh http flush logbuffer | Out-Null
Start-Sleep -Seconds 3

Evidencia '07-logs' '03-security-log' { Get-WinEvent -LogName Security -MaxEvents 20 | Format-Table TimeCreated, Id, @{n='Mensagem';e={($_.Message -split "`n")[0]}} -AutoSize -Wrap }
Evidencia '07-logs' '04-iis-logs' { Get-ChildItem 'C:\inetpub\logs\LogFiles' -Recurse | Format-Table FullName, Length, LastWriteTime -AutoSize }
Print 'Tire print do auditpol /get (Logon e File System com Success and Failure)'
Print 'Abra o Visualizador de Eventos (eventvwr) > Logs do Windows > Seguranca e tire print'
Print 'Abra a pasta C:\inetpub\logs\LogFiles\W3SVC2 (ou similar) no Explorer e tire print'
Proximo 'rode .\06-Monitoramento.ps1'
