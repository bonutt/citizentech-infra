# ETAPA 1 (parte 2) - Instalar o Active Directory e promover o dominio citizentech.local

. "$PSScriptRoot\_comum.ps1"
Testar-Admin
Titulo 'ETAPA 1 - Active Directory + DNS (dominio citizentech.local)'

if ($env:COMPUTERNAME -ne $CT.Servidor) {
    Aviso "O servidor ainda se chama $env:COMPUTERNAME. Rode o .\01-Rede.ps1 primeiro."
    exit 1
}
if (E-Controlador-Dominio) {
    Ok 'Este servidor ja e controlador de dominio.'
    Proximo 'rode .\03-AD-Usuarios.ps1'
    exit 0
}

Evidencia '01-rede' '05-ipconfig-apos-reinicio' { ipconfig /all }
Print 'Tire print do ipconfig /all acima: hostname SRV-CITIZENTECH, IP, mascara, gateway e DNS (evidencias/01-rede/02-ipconfig.png)'
Pausa 'Depois do print, pressione ENTER para continuar'

Passo 'Senha do Administrator'
Write-Host '   A conta Administrator vira o administrador do dominio.'
Write-Host '   Use uma senha forte: maiuscula + minuscula + numero + simbolo (ex.: Citizen@2026).'
Write-Host '   ANOTE ESSA SENHA. Voce vai entrar com CITIZENTECH\Administrator depois.' -ForegroundColor Green
$adm = Get-LocalUser | Where-Object { $_.SID.Value -like '*-500' }
do {
    if ($AUTO) { $senhaAdm = ConvertTo-SecureString $CT.SenhaAdmin -AsPlainText -Force }
    else { $senhaAdm = Read-Host -AsSecureString 'Senha do Administrator' }
    try {
        $adm | Set-LocalUser -Password $senhaAdm -PasswordNeverExpires $true -ErrorAction Stop
        $okSenha = $true
    } catch {
        Aviso 'Senha recusada (precisa de maiuscula, minuscula, numero e simbolo, 8+ caracteres). Tente de novo.'
        $okSenha = $false
    }
} until ($okSenha)
$adm | Enable-LocalUser
Ok "Senha definida para $($adm.Name)."

Passo 'Instalando a funcao AD DS'
Evidencia '02-ad-dns' '01-install-adds' { Install-WindowsFeature -Name AD-Domain-Services -IncludeManagementTools }

Passo 'Promovendo a controlador de dominio'
Write-Host '   Agora defina a senha DSRM (modo de restauracao). Pode ser a mesma do Administrator. ANOTE.' -ForegroundColor Green
if ($AUTO) { $dsrm = ConvertTo-SecureString $CT.SenhaAdmin -AsPlainText -Force }
else { $dsrm = Read-Host -AsSecureString 'Senha DSRM' }

Import-Module ADDSDeployment
$res = Install-ADDSForest -DomainName $CT.Dominio -DomainNetbiosName $CT.NetBIOS -InstallDns `
        -SafeModeAdministratorPassword $dsrm -NoRebootOnCompletion -Force -WarningAction SilentlyContinue
$res | Out-String | Write-Host
Evidencia '02-ad-dns' '02-install-addsforest' { $res | Format-List Status, Message, RebootRequired }

Write-Host ''
Write-Host '   Quando reiniciar, entre com:  CITIZENTECH\Administrator  (senha que voce definiu)' -ForegroundColor Green
Write-Host '   No VirtualBox, para mandar Ctrl+Alt+Del use: Entrada > Teclado > Inserir Ctrl-Alt-Del (ou Host+Del).'
Proximo 'depois de reiniciar (demora uns 5 min), rode .\03-AD-Usuarios.ps1'
Pausa 'Pressione ENTER para reiniciar'
Restart-Computer -Force
