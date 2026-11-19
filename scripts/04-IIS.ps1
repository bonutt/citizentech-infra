# ETAPA 2 - Hospedar a aplicacao CitizenTech (Gota Inteligente) no IIS
# Caminho A: aplicacao estatica (HTML, CSS, JavaScript)
# Inclui: IIS, pool, site, firewall, permissoes NTFS e File Server (compartilhamento SMB)

. "$PSScriptRoot\_comum.ps1"
Testar-Admin
Titulo 'ETAPA 2 - IIS + NTFS + File Server'
$ip = IP-Servidor

Passo 'Instalando o IIS'
Evidencia '03-iis' '01-install-iis' { Install-WindowsFeature -Name Web-Server -IncludeManagementTools }
Import-Module WebAdministration
Evidencia '03-iis' '02-get-windowsfeature-web' { Get-WindowsFeature -Name Web-* | Where-Object Installed | Format-Table Name, DisplayName, InstallState -AutoSize }
Print 'Tire print do Get-WindowsFeature acima (evidencias/03-iis/01-features.png)'

Passo 'Publicando os arquivos do site'
$origem = Join-Path $RepoRoot 'site'
New-Item -Path 'C:\Temp\citizentech' -ItemType Directory -Force | Out-Null
Copy-Item -Path "$origem\*" -Destination 'C:\Temp\citizentech' -Recurse -Force
New-Item -Path $CT.PastaSite -ItemType Directory -Force | Out-Null
Copy-Item -Path 'C:\Temp\citizentech\*' -Destination $CT.PastaSite -Recurse -Force
Evidencia '03-iis' '03-arquivos-site' { Get-ChildItem 'C:\inetpub\citizentech' -Recurse | Format-Table FullName, Length -AutoSize }

Passo 'Liberando a porta 80 (removendo o Default Web Site)'
if (Get-Website | Where-Object Name -eq 'Default Web Site') {
    Remove-Website -Name 'Default Web Site'
    Ok 'Default Web Site removido (ele tambem usava a porta 80).'
}

Passo 'Criando o pool de aplicativos e o site'
if (-not (Test-Path "IIS:\AppPools\$($CT.Pool)")) { New-WebAppPool -Name $CT.Pool | Out-Null }
# managedRuntimeVersion vazio = "Sem codigo gerenciado". Obrigatorio para site estatico (evita erro 500.19).
Set-ItemProperty -Path "IIS:\AppPools\$($CT.Pool)" -Name managedRuntimeVersion -Value ''
if (-not (Get-Website | Where-Object Name -eq $CT.Site)) {
    New-Website -Name $CT.Site -Port 80 -PhysicalPath $CT.PastaSite -ApplicationPool $CT.Pool | Out-Null
}
Start-Website -Name $CT.Site -ErrorAction SilentlyContinue

if (-not (Get-NetFirewallRule -DisplayName 'HTTP CitizenTech' -ErrorAction SilentlyContinue)) {
    New-NetFirewallRule -DisplayName 'HTTP CitizenTech' -Direction Inbound -Protocol TCP -LocalPort 80 -Action Allow | Out-Null
}
Ok 'Firewall liberado na porta 80.'

Evidencia '03-iis' '04-get-website' { Get-Website -Name 'CitizenTech' | Format-List Name, State, PhysicalPath, ApplicationPool, Bindings }
Evidencia '03-iis' '05-apppool' { Get-ItemProperty 'IIS:\AppPools\CitizenTechPool' | Format-List Name, State, managedRuntimeVersion, managedPipelineMode }
Evidencia '03-iis' '06-get-webapppoolstate' { Get-WebAppPoolState -Name 'CitizenTechPool' }
Evidencia '03-iis' '07-invoke-webrequest' { Invoke-WebRequest -Uri 'http://localhost' -UseBasicParsing | Select-Object StatusCode, StatusDescription }
Print 'Tire print do Get-Website, Get-WebAppPoolState e Invoke-WebRequest (evidencias/03-iis/)'
Print "No SEU PC (fora da VM), abra o navegador em http://$ip e tire print do site carregado (evidencias/03-iis/05-navegador.png)"
Pausa 'Depois dos prints, pressione ENTER para configurar as permissoes NTFS'

Passo 'Permissoes NTFS da pasta do site'
$iisUsrs = New-Object Security.Principal.SecurityIdentifier('S-1-5-32-568')   # IIS_IUSRS
$acl = Get-Acl $CT.PastaSite
$rule = New-Object System.Security.AccessControl.FileSystemAccessRule($iisUsrs, 'ReadAndExecute', 'ContainerInherit,ObjectInherit', 'None', 'Allow')
$acl.SetAccessRule($rule)
Set-Acl -Path $CT.PastaSite -AclObject $acl
Evidencia '04-ntfs-gpo' '01-get-acl' { Get-Acl 'C:\inetpub\citizentech' | Format-List Path, Owner, AccessToString }
Print 'Tire print do Get-Acl (IIS_IUSRS com ReadAndExecute Allow) e da aba Seguranca da pasta C:\inetpub\citizentech (botao direito > Propriedades > Seguranca)'
Pausa 'Depois dos prints, pressione ENTER para configurar o File Server'

Passo 'File Server e compartilhamento'
Evidencia '04-ntfs-gpo' '02-install-fileserver' { Install-WindowsFeature -Name FS-FileServer -IncludeManagementTools }
New-Item -Path $CT.Share -ItemType Directory -Force | Out-Null
$csv = @"
data_hora,talhao,umidade_solo,chuva_prevista_24h,recomendacao
2026-11-19 06:00,Talhao 1,34,10,Irrigar 20 min
2026-11-19 06:00,Talhao 2,58,75,Aguardar chuva
2026-11-19 06:00,Talhao 3,71,20,Nao irrigar
"@
Set-Content -Path (Join-Path $CT.Share 'leituras-umidade.csv') -Value $csv -Encoding UTF8
Set-Content -Path (Join-Path $CT.Share 'LEIA-ME.txt') -Value 'Pasta compartilhada da equipe CitizenTech - relatorios do Gota Inteligente.'

$domUsers = Nome-Por-SID ((Get-ADDomain).DomainSID.Value + '-513')   # Domain Users / Usuarios do Dominio
if (-not (Get-SmbShare -Name 'CitizenTech' -ErrorAction SilentlyContinue)) {
    New-SmbShare -Name 'CitizenTech' -Path $CT.Share -FullAccess "$($CT.NetBIOS)\GG_CitizenTech_Admins" | Out-Null
}
Grant-SmbShareAccess -Name 'CitizenTech' -AccountName $domUsers -AccessRight Read -Force | Out-Null
Evidencia '04-ntfs-gpo' '03-get-smbshare' { Get-SmbShare -Name 'CitizenTech' | Format-List Name, Path, ScopeName, Description }
Evidencia '04-ntfs-gpo' '04-get-smbshareaccess' { Get-SmbShareAccess -Name 'CitizenTech' | Format-Table AccountName, AccessControlType, AccessRight -AutoSize }
Print "Tire print do Get-SmbShare e abra \\SRV-CITIZENTECH\CitizenTech (Win+R) mostrando os arquivos"
Write-Host "   Dica: do SEU PC, Win+R > \\$ip\CitizenTech e entre com CITIZENTECH\ana.souza / $($CT.SenhaTeste)" -ForegroundColor DarkGray
Proximo 'rode .\05-Infra.ps1'
