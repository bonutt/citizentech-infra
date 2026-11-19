# ETAPA 1 (parte 1) - IP fixo e nome do servidor
# Uso: .\01-Rede.ps1            (mantem o IP que a VM recebeu e o deixa fixo)
#      .\01-Rede.ps1 -IP 192.168.1.10   (forca um IP especifico)
param([string]$IP)

. "$PSScriptRoot\_comum.ps1"
Testar-Admin
Titulo 'ETAPA 1 - Rede: IP fixo e nome do servidor'

Evidencia '01-rede' '00-versao-windows' { Get-CimInstance Win32_OperatingSystem | Format-List Caption, Version, BuildNumber, OSArchitecture }
Print 'Abra o winver (Win+R > winver) e tire print da tela com a versao (evidencias/01-rede/01-winver.png)'

Passo 'Identificando a placa de rede'
Evidencia '01-rede' '01-get-netadapter' { Get-NetAdapter | Format-Table Name, InterfaceDescription, Status, ifIndex -AutoSize }

$cfg = Get-NetIPConfiguration | Where-Object { $_.IPv4DefaultGateway -and $_.NetAdapter.Status -eq 'Up' } | Select-Object -First 1
if (-not $cfg) {
    Aviso 'Nenhuma placa de rede conectada com gateway. No VirtualBox, confira se a rede da VM esta em "Placa em modo Bridge".'
    exit 1
}
$idx      = $cfg.InterfaceIndex
$ipAtual = ($cfg.IPv4Address | Select-Object -First 1).IPAddress
$prefixo = ($cfg.IPv4Address | Select-Object -First 1).PrefixLength
$gw      = ($cfg.IPv4DefaultGateway | Select-Object -First 1).NextHop
if (-not $IP) { $IP = $ipAtual }

Write-Host "   Interface: $idx | IP: $IP/$prefixo | Gateway: $gw"

Passo 'Aplicando IP fixo'
$dhcp = (Get-NetIPInterface -InterfaceIndex $idx -AddressFamily IPv4).Dhcp
if ($dhcp -eq 'Enabled' -or $IP -ne $ipAtual) {
    Set-NetIPInterface -InterfaceIndex $idx -Dhcp Disabled
    Get-NetIPAddress -InterfaceIndex $idx -AddressFamily IPv4 -ErrorAction SilentlyContinue | Remove-NetIPAddress -Confirm:$false -ErrorAction SilentlyContinue
    Get-NetRoute -InterfaceIndex $idx -DestinationPrefix '0.0.0.0/0' -ErrorAction SilentlyContinue | Remove-NetRoute -Confirm:$false -ErrorAction SilentlyContinue
    $cmdIP = "New-NetIPAddress -InterfaceIndex $idx -IPAddress $IP -PrefixLength $prefixo -DefaultGateway $gw"
    Evidencia '01-rede' '02-new-netipaddress' ([scriptblock]::Create($cmdIP))
} else {
    Ok "IP $IP ja estava fixo."
}

# O servidor aponta para ele mesmo como DNS (vira o DNS do dominio na etapa 2).
# O 8.8.8.8 fica como secundario so ate o AD ser instalado; o script 03 remove.
Set-DnsClientServerAddress -InterfaceIndex $idx -ServerAddresses $IP, '8.8.8.8'
Ok "DNS da placa: $IP (secundario temporario 8.8.8.8)"

New-Item -Path 'C:\CitizenTech' -ItemType Directory -Force | Out-Null
@{ IP = $IP; Prefixo = $prefixo; Gateway = $gw; Interface = $idx } | ConvertTo-Json | Set-Content 'C:\CitizenTech\rede.json'

Start-Sleep -Seconds 3
Evidencia '01-rede' '03-ipconfig-all' { ipconfig /all }

Passo 'Renomeando o servidor'
if ($env:COMPUTERNAME -ne $CT.Servidor) {
    Evidencia '01-rede' '04-rename-computer' ([scriptblock]::Create("Rename-Computer -NewName '$($CT.Servidor)' -Force"))
    Write-Host ''
    Write-Host "   ANOTE: IP do servidor = $IP | Gateway = $gw" -ForegroundColor Green
    Proximo 'depois de reiniciar, rode .\02-AD.ps1'
    Pausa 'Pressione ENTER para reiniciar agora'
    Restart-Computer -Force
} else {
    Ok "O servidor ja se chama $($CT.Servidor)."
    Print 'Tire print do ipconfig /all acima (evidencias/01-rede/02-ipconfig.png)'
    Proximo 'rode .\02-AD.ps1'
}
