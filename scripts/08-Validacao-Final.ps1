# ETAPA 6 - Ficha da infraestrutura (bloco de validacao final do roteiro)
# Rode, maximize a janela do PowerShell e tire o print da saida completa (pode ser em 2 ou 3 partes).

. "$PSScriptRoot\_comum.ps1"
Testar-Admin
Import-Module WebAdministration

$arq = Join-Path $CT.Evid '08-validacao-final.txt'
New-Item -Path $CT.Evid -ItemType Directory -Force | Out-Null
Start-Transcript -Path $arq -Force | Out-Null

Write-Host '=== FICHA DA INFRAESTRUTURA ===' -ForegroundColor Cyan
hostname
ipconfig /all
nslookup srv-citizentech.citizentech.local
Test-NetConnection -ComputerName srv-citizentech.citizentech.local -Port 80
Get-ADDomain | Select-Object Name, DNSRoot
Get-WindowsFeature -Name Web-Server, AD-Domain-Services, DNS, FS-FileServer | Select-Object Name, InstallState
Get-Website | Select-Object Name, State, PhysicalPath
Get-WebAppPoolState -Name 'CitizenTechPool'
Get-Service W3SVC, DNS | Select-Object Name, Status
Get-SmbShare | Select-Object Name, Path
Get-GPO -All | Select-Object DisplayName, GpoStatus

Stop-Transcript | Out-Null

# Junta todas as evidencias em texto num zip (opcional: subir no repositorio em evidencias/)
Copy-Item 'C:\Scripts\logs\*' (New-Item (Join-Path $CT.Evid '07-logs\scripts') -ItemType Directory -Force) -Force -ErrorAction SilentlyContinue
$zip = 'C:\CitizenTech\evidencias-texto.zip'
Compress-Archive -Path "$($CT.Evid)\*" -DestinationPath $zip -Force
Write-Host ''
Write-Host "   Evidencias em texto salvas em $($CT.Evid) e em $zip" -ForegroundColor Green
Write-Host '   [PRINT] Tire print da saida completa deste bloco (evidencias/08-validacao-final/)' -ForegroundColor Magenta
