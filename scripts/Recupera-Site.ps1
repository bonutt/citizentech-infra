# Recupera-Site.ps1 - verifica servico, pool e site do IIS e recupera o que estiver parado
# Instalado em C:\Scripts e executado a cada 2 minutos pela tarefa CitizenTech_Recuperacao.

Import-Module WebAdministration -ErrorAction SilentlyContinue
$site = 'CitizenTech'
$pool = 'CitizenTechPool'
$log  = 'C:\Scripts\logs\recuperacao.log'
New-Item -Path (Split-Path $log) -ItemType Directory -Force | Out-Null

function Registrar($texto) {
    $linha = "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') | $texto"
    Add-Content -Path $log -Value $linha
    Write-Host $linha -ForegroundColor Cyan
}

# 1) Servicos do IIS (WAS e W3SVC)
foreach ($nome in 'WAS', 'W3SVC') {
    $svc = Get-Service $nome
    if ($svc.Status -ne 'Running') {
        Registrar "Servico $nome estava $($svc.Status). Iniciando."
        Start-Service $nome
        Start-Sleep -Seconds 5
    }
}

# 2) Pool de aplicativos
try {
    $estadoPool = (Get-WebAppPoolState -Name $pool).Value
    if ($estadoPool -ne 'Started') {
        Registrar "Pool $pool estava $estadoPool. Reiniciando."
        Start-WebAppPool -Name $pool
        Start-Sleep -Seconds 2
    }
} catch { Registrar "Nao foi possivel ler o pool: $($_.Exception.Message)" }

# 3) Site
try {
    $estadoSite = (Get-Website -Name $site).State
    if ($estadoSite -ne 'Started') {
        Registrar "Site $site estava $estadoSite. Iniciando."
        Start-Website -Name $site
    }
} catch { Registrar "Nao foi possivel ler o site: $($_.Exception.Message)" }

# 4) Teste HTTP final
try {
    $r = Invoke-WebRequest -Uri 'http://localhost' -UseBasicParsing -TimeoutSec 10
    Registrar "Site respondendo com HTTP $($r.StatusCode)."
} catch {
    Registrar 'Site nao responde. Executando iisreset.'
    iisreset /restart | Out-Null
    Start-Sleep -Seconds 10
    try {
        $r = Invoke-WebRequest -Uri 'http://localhost' -UseBasicParsing -TimeoutSec 10
        Registrar "Recuperado apos iisreset. HTTP $($r.StatusCode)."
    } catch {
        Registrar 'Falha persistente. Verificar logs do IIS.'
    }
}
