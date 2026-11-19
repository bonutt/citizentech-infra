# ETAPA 1 (parte 3) - Validar DNS e dominio, criar OU, grupos e usuarios

. "$PSScriptRoot\_comum.ps1"
Testar-Admin
Titulo 'ETAPA 1 - Validacao do dominio + usuarios e grupos'

if (-not (E-Controlador-Dominio)) {
    Aviso 'Este servidor ainda nao e controlador de dominio. Rode o .\02-AD.ps1 primeiro.'
    exit 1
}
Import-Module ActiveDirectory
Import-Module DnsServer
$ip = IP-Servidor

Passo 'Ajustando o DNS'
$idx = (Get-NetIPConfiguration | Where-Object { $_.IPv4DefaultGateway } | Select-Object -First 1).InterfaceIndex
Set-DnsClientServerAddress -InterfaceIndex $idx -ServerAddresses $ip
try { Set-DnsServerForwarder -IPAddress '8.8.8.8', '1.1.1.1' -ErrorAction Stop; Ok 'Encaminhadores DNS: 8.8.8.8 e 1.1.1.1 (acesso a internet)' } catch { Aviso $_.Exception.Message }
if (-not (Get-DnsServerResourceRecord -ZoneName $CT.Dominio -Name 'citizentech' -ErrorAction SilentlyContinue)) {
    Add-DnsServerResourceRecordA -ZoneName $CT.Dominio -Name 'citizentech' -IPv4Address $ip
}
Ok "Registro DNS citizentech.citizentech.local -> $ip (endereco amigavel do site)"
ipconfig /flushdns | Out-Null

Passo 'Validando dominio e DNS'
Evidencia '02-ad-dns' '03-get-addomain' { Get-ADDomain | Format-List Name, DNSRoot, NetBIOSName, DomainMode, PDCEmulator }
Evidencia '02-ad-dns' '04-nslookup' { nslookup srv-citizentech.citizentech.local }
Evidencia '02-ad-dns' '05-get-dnsserverzone' { Get-DnsServerZone | Format-Table ZoneName, ZoneType, IsAutoCreated, IsDsIntegrated -AutoSize }
Print 'Tire print da saida do Get-ADDomain, do nslookup e do Get-DnsServerZone (evidencias/02-ad-dns/)'
Pausa 'Depois dos prints, pressione ENTER para criar usuarios e grupos'

Passo 'Criando OU, grupos e usuarios'
if (-not (Get-ADOrganizationalUnit -Filter "Name -eq 'CitizenTech'" -SearchBase $CT.DN -ErrorAction SilentlyContinue)) {
    New-ADOrganizationalUnit -Name 'CitizenTech' -Path $CT.DN -ProtectedFromAccidentalDeletion $false
}
foreach ($g in 'GG_CitizenTech_Admins', 'GG_CitizenTech_Usuarios') {
    if (-not (Get-ADGroup -Filter "Name -eq '$g'" -ErrorAction SilentlyContinue)) {
        New-ADGroup -Name $g -GroupScope Global -GroupCategory Security -Path $CT.OU
    }
}

$senha = ConvertTo-SecureString $CT.SenhaTeste -AsPlainText -Force
$usuarios = @(
    @{ Nome = 'Ana Souza';   Login = 'ana.souza';   Grupo = 'GG_CitizenTech_Admins';   Cargo = 'Administradora da plataforma' },
    @{ Nome = 'Carlos Lima'; Login = 'carlos.lima'; Grupo = 'GG_CitizenTech_Usuarios'; Cargo = 'Tecnico do Sindicato Rural (usuario comum)' }
)
foreach ($u in $usuarios) {
    if (-not (Get-ADUser -Filter "SamAccountName -eq '$($u.Login)'" -ErrorAction SilentlyContinue)) {
        New-ADUser -Name $u.Nome -SamAccountName $u.Login -UserPrincipalName "$($u.Login)@$($CT.Dominio)" `
            -Path $CT.OU -AccountPassword $senha -Enabled $true -PasswordNeverExpires $true -Title $u.Cargo
    }
    Add-ADGroupMember -Identity $u.Grupo -Members $u.Login -ErrorAction SilentlyContinue
}

# Em um controlador de dominio, usuario comum nao pode fazer logon local.
# Para demonstrar a GPO na tela do carlos.lima, ele entra no grupo interno "Print Operators"
# (S-1-5-32-550), que tem permissao de logon local no DC e poucos privilegios.
$printOps = Get-ADGroup -Identity 'S-1-5-32-550'
Add-ADGroupMember -Identity $printOps -Members 'carlos.lima' -ErrorAction SilentlyContinue
Ok "carlos.lima pode fazer logon local no servidor (grupo $($printOps.Name))"

Evidencia '02-ad-dns' '06-get-aduser' { Get-ADUser -Filter * -SearchBase $CT.OU -Properties Title | Format-Table Name, SamAccountName, Enabled, Title -AutoSize }
Evidencia '02-ad-dns' '07-get-adgroupmember' { foreach ($g in 'GG_CitizenTech_Admins','GG_CitizenTech_Usuarios') { "Grupo: $g"; Get-ADGroupMember -Identity $g | Format-Table Name, SamAccountName, objectClass -AutoSize } }
Print 'Tire print das duas saidas acima: usuarios e membros dos grupos (evidencias/02-ad-dns/)'
Write-Host "   Senha de laboratorio dos usuarios de teste: $($CT.SenhaTeste)" -ForegroundColor Green
Proximo 'rode .\04-IIS.ps1'
