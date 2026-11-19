# Monitor-Recursos.ps1 - alerta por limiar de CPU, memoria e disco
# Instalado em C:\Scripts\Monitor-Recursos.ps1 e executado a cada 5 minutos pelo Agendador de Tarefas.
# Uso manual:  powershell -ExecutionPolicy Bypass -File C:\Scripts\Monitor-Recursos.ps1
#              powershell -ExecutionPolicy Bypass -File C:\Scripts\Monitor-Recursos.ps1 -Simular
#              (-Simular baixa os limites para forcar um alerta na demonstracao)
param([switch]$Simular)

$limiteCPU   = 80     # % de uso da CPU acima disso gera alerta
$limiteDisco = 15     # GB livres no C: abaixo disso gera alerta
$limiteRAM   = 500    # MB de memoria livre abaixo disso gera alerta
if ($Simular) { $limiteCPU = 0; $limiteDisco = 10000; $limiteRAM = 100000 }

$logPath = 'C:\Scripts\logs\alertas.log'
New-Item -Path (Split-Path $logPath) -ItemType Directory -Force | Out-Null

# Leitura via contadores de desempenho; se o Windows estiver em outro idioma, usa CIM (mesmos valores).
try {
    $cpu = (Get-Counter '\Processor(_Total)\% Processor Time' -ErrorAction Stop).CounterSamples.CookedValue
    $ram = (Get-Counter '\Memory\Available MBytes' -ErrorAction Stop).CounterSamples.CookedValue
} catch {
    $cpu = (Get-CimInstance Win32_Processor | Measure-Object -Property LoadPercentage -Average).Average
    $ram = (Get-CimInstance Win32_OperatingSystem).FreePhysicalMemory / 1KB
}
$disco = (Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='C:'").FreeSpace / 1GB

$alertas = @()
if ($cpu -gt $limiteCPU)     { $alertas += "CPU alta: $([math]::Round($cpu,2))%" }
if ($ram -lt $limiteRAM)     { $alertas += "Memoria baixa: $([math]::Round($ram,0)) MB livres" }
if ($disco -lt $limiteDisco) { $alertas += "Disco baixo: $([math]::Round($disco,2)) GB livres" }

if ($alertas.Count -gt 0) {
    $msg = "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') | ALERTA | " + ($alertas -join ' | ')
    if ($Simular) { $msg += ' | (simulacao)' }
    Add-Content -Path $logPath -Value $msg
    Write-EventLog -LogName Application -Source 'CitizenTechMonitor' -EventId 9001 -EntryType Warning -Message $msg -ErrorAction SilentlyContinue
    Write-Host $msg -ForegroundColor Yellow
} else {
    $msg = "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') | OK | CPU: $([math]::Round($cpu,1))% | RAM livre: $([math]::Round($ram,0)) MB | Disco livre: $([math]::Round($disco,1)) GB"
    Add-Content -Path $logPath -Value $msg
    Write-Host $msg -ForegroundColor Green
}
