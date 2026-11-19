# Funcoes e valores compartilhados pelos scripts de configuracao.
# Os scripts de etapa fazem: . "$PSScriptRoot\_comum.ps1"

$Global:CT = @{
    Servidor  = 'SRV-CITIZENTECH'
    Dominio   = 'citizentech.local'
    NetBIOS   = 'CITIZENTECH'
    DN        = 'DC=citizentech,DC=local'
    OU        = 'OU=CitizenTech,DC=citizentech,DC=local'
    Site      = 'CitizenTech'
    Pool      = 'CitizenTechPool'
    PastaSite = 'C:\inetpub\citizentech'
    Share     = 'C:\Shares\CitizenTech'
    Scripts   = 'C:\Scripts'
    Evid      = 'C:\CitizenTech\evidencias'
    # Senha de LABORATORIO para os usuarios de teste do AD (nao e senha real).
    SenhaTeste = 'Gota@2026!'
    # Senha de LABORATORIO do Administrator (nao e senha real).
    SenhaAdmin = 'Citizen@2026'
}
# Modo sem pausas: ativado quando existe C:\CitizenTech\auto.flag
$Global:AUTO = Test-Path 'C:\CitizenTech\auto.flag'
function Pausa([string]$t) { if (-not $AUTO) { Read-Host $t | Out-Null } }
$Global:RepoRoot = Split-Path $PSScriptRoot -Parent

function Titulo([string]$t) {
    Write-Host ''
    Write-Host ('=' * 72) -ForegroundColor Cyan
    Write-Host " $t" -ForegroundColor Cyan
    Write-Host ('=' * 72) -ForegroundColor Cyan
}

function Passo([string]$t) { Write-Host "`n>> $t" -ForegroundColor Yellow }
function Ok([string]$t)    { Write-Host "   OK: $t" -ForegroundColor Green }
function Aviso([string]$t) { Write-Host "   ATENCAO: $t" -ForegroundColor Red }

function Print([string]$t) {
    Write-Host ''
    Write-Host "   [PRINT] $t" -ForegroundColor Magenta
}

# Executa um bloco, mostra a saida na tela e salva em C:\CitizenTech\evidencias\<pasta>\<nome>.txt
function Evidencia {
    param([string]$Pasta, [string]$Nome, [scriptblock]$Bloco)
    $dir = Join-Path $CT.Evid $Pasta
    New-Item -Path $dir -ItemType Directory -Force | Out-Null
    $arq = Join-Path $dir "$Nome.txt"
    $cmd = $Bloco.ToString().Trim()
    Write-Host ''
    Write-Host "PS C:\> $cmd" -ForegroundColor White
    $saida = & $Bloco 2>&1 | Out-String -Width 220
    Write-Host $saida.TrimEnd()
    $cab = "# $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') | $env:COMPUTERNAME"
    Add-Content -Path $arq -Value "$cab`r`nPS C:\> $cmd`r`n$saida" -Encoding UTF8
}

function Testar-Admin {
    $p = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
    if (-not $p.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        Aviso 'Abra o PowerShell como Administrador (botao direito > Executar como administrador).'
        exit 1
    }
}

# Converte um SID conhecido no nome do grupo (funciona com Windows em ingles ou portugues)
function Nome-Por-SID([string]$sid) {
    (New-Object Security.Principal.SecurityIdentifier($sid)).Translate([Security.Principal.NTAccount]).Value
}

function IP-Servidor {
    $cfg = Get-NetIPConfiguration | Where-Object { $_.IPv4DefaultGateway -and $_.NetAdapter.Status -eq 'Up' } | Select-Object -First 1
    if ($cfg) { return ($cfg.IPv4Address | Select-Object -First 1).IPAddress }
    return $null
}

function E-Controlador-Dominio {
    return ((Get-CimInstance Win32_ComputerSystem).DomainRole -ge 4)
}

function Proximo([string]$t) {
    Write-Host ''
    Write-Host ('-' * 72) -ForegroundColor Cyan
    Write-Host " PROXIMO PASSO: $t" -ForegroundColor Cyan
    Write-Host ('-' * 72) -ForegroundColor Cyan
}
