# Teste-Falha.ps1 - derruba o IIS de proposito e mostra a recuperacao automatica
# Uso: powershell -ExecutionPolicy Bypass -File C:\Scripts\Teste-Falha.ps1
#
# Parte 1 (servico): simula um TRAVAMENTO do W3SVC (o processo e encerrado a forca).
#   O Windows detecta a falha e o proprio Gerenciador de Servicos reinicia o W3SVC,
#   conforme a recuperacao configurada com: sc.exe failure W3SVC ... restart/5000
#   Obs.: um Stop-Service "educado" nao dispara a recuperacao do Windows (ele entende
#   que foi parada de proposito). Por isso o crash e simulado encerrando o processo.
#   Se o servico nao voltar, a tarefa CitizenTech_Recuperacao (Recupera-Site.ps1) assume.
#
# Parte 2 (pool): para o pool CitizenTechPool, mostra o site fora do ar (HTTP 503) e a
#   tarefa agendada CitizenTech_Recuperacao recupera o pool e grava no recuperacao.log.

Import-Module WebAdministration -ErrorAction SilentlyContinue

function Status-Site {
    try { (Invoke-WebRequest -Uri 'http://localhost' -UseBasicParsing -TimeoutSec 5).StatusCode }
    catch { "Site indisponivel, como esperado: $($_.Exception.Message)" }
}

Write-Host '=== TESTE DE FALHA - CITIZENTECH ===' -ForegroundColor Cyan

Write-Host '[1] Estado antes:' -ForegroundColor Yellow
Get-Service W3SVC | Select-Object Name, Status | Format-Table -AutoSize
Write-Host "HTTP: $(Status-Site)"

Write-Host '[2] Derrubando o servico W3SVC (simulando travamento)...' -ForegroundColor Yellow
$procId = (Get-CimInstance Win32_Service -Filter "Name='W3SVC'").ProcessId
Write-Host "Encerrando o processo do W3SVC (PID $procId)" -ForegroundColor Red
Stop-Process -Id $procId -Force
Start-Sleep -Milliseconds 800
Get-Service W3SVC | Select-Object Name, Status | Format-Table -AutoSize

Write-Host '[3] Tentando acessar o site durante a falha...' -ForegroundColor Yellow
try {
    Invoke-WebRequest -Uri 'http://localhost' -UseBasicParsing -TimeoutSec 3 | Select-Object StatusCode
} catch {
    Write-Host "Site indisponivel, como esperado: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host '[4] Aguardando recuperacao automatica (ate 60s)...' -ForegroundColor Yellow
$ok = $false
for ($i = 1; $i -le 12; $i++) {
    Start-Sleep -Seconds 5
    $st = (Get-Service W3SVC).Status
    Write-Host "   +$($i*5)s  W3SVC = $st"
    if ($st -eq 'Running') {
        try { if ((Invoke-WebRequest -Uri 'http://localhost' -UseBasicParsing -TimeoutSec 5).StatusCode -eq 200) { $ok = $true; break } } catch {}
    }
}

Write-Host '[5] Estado depois:' -ForegroundColor Yellow
Get-Service W3SVC | Select-Object Name, Status | Format-Table -AutoSize
if ($ok) {
    Write-Host 'HTTP: 200 - recuperado automaticamente pelo Windows (recuperacao do servico W3SVC)' -ForegroundColor Green
} else {
    Write-Host 'Ainda indisponivel. Acionando a tarefa de recuperacao CitizenTech_Recuperacao...' -ForegroundColor Red
    Start-ScheduledTask -TaskName 'CitizenTech_Recuperacao'
    Start-Sleep -Seconds 15
    Write-Host "HTTP: $(Status-Site)"
}

Write-Host ''
Write-Host '=== PARTE 2 - FALHA DO POOL DE APLICATIVOS ===' -ForegroundColor Cyan
Write-Host '[6] Parando o pool CitizenTechPool...' -ForegroundColor Yellow
Stop-WebAppPool -Name 'CitizenTechPool'
Start-Sleep -Seconds 2
Write-Host "Pool: $((Get-WebAppPoolState -Name 'CitizenTechPool').Value)"
Write-Host "HTTP: $(Status-Site)"

Write-Host '[7] Disparando a tarefa agendada CitizenTech_Recuperacao (roda sozinha a cada 2 min)...' -ForegroundColor Yellow
Start-ScheduledTask -TaskName 'CitizenTech_Recuperacao'
Start-Sleep -Seconds 12
Write-Host "Pool: $((Get-WebAppPoolState -Name 'CitizenTechPool').Value)"
Write-Host "HTTP: $(Status-Site)" -ForegroundColor Green

Write-Host '[8] Ultimas linhas do recuperacao.log:' -ForegroundColor Yellow
Get-Content 'C:\Scripts\logs\recuperacao.log' -Tail 8 -ErrorAction SilentlyContinue
