# ETAPA 4 - Monitoramento com alertas de CPU, memoria e disco
# Cria no Monitor de Desempenho:
#   - CitizenTech_Monitor : coletor de dados (grava os 3 contadores a cada 15 s)
#   - CitizenTech_Alertas : alerta de contador (CPU > 80%, RAM < 500 MB, disco < 15% livre)
# E agenda o script Monitor-Recursos.ps1 a cada 5 minutos.

. "$PSScriptRoot\_comum.ps1"
Testar-Admin
Titulo 'ETAPA 4 - Monitoramento com alertas'

Passo 'Copiando scripts para C:\Scripts'
New-Item -Path "$($CT.Scripts)\logs" -ItemType Directory -Force | Out-Null
foreach ($s in 'Monitor-Recursos.ps1', 'Teste-Falha.ps1', 'Recupera-Site.ps1') {
    Copy-Item (Join-Path $PSScriptRoot $s) $CT.Scripts -Force
}
Get-ChildItem $CT.Scripts -Filter *.ps1 | Unblock-File
Ok 'Scripts em C:\Scripts'

New-EventLog -LogName Application -Source 'CitizenTechMonitor' -ErrorAction SilentlyContinue

$contadores = @('\Processor(_Total)\% Processor Time', '\Memory\Available MBytes', '\LogicalDisk(C:)\% Free Space')

Passo 'Data Collector Set: CitizenTech_Monitor'
$path = 'C:\PerfLogs\CitizenTech'
New-Item -Path $path -ItemType Directory -Force | Out-Null
logman stop CitizenTech_Monitor 2>&1 | Out-Null
logman delete CitizenTech_Monitor 2>&1 | Out-Null
logman create counter CitizenTech_Monitor -c $contadores -si 00:00:15 -f csv -o "$path\Recursos" -v mmddhhmm 2>&1 | Write-Host
logman start CitizenTech_Monitor 2>&1 | Write-Host

Passo 'Alerta de desempenho: CitizenTech_Alertas'
logman stop CitizenTech_Alertas 2>&1 | Out-Null
logman delete CitizenTech_Alertas 2>&1 | Out-Null
logman create alert CitizenTech_Alertas -th '\Processor(_Total)\% Processor Time>80' '\Memory\Available MBytes<500' '\LogicalDisk(C:)\% Free Space<15' -si 00:00:15 -el 2>&1 | Write-Host
logman start CitizenTech_Alertas 2>&1 | Write-Host

Start-Sleep -Seconds 20
Evidencia '05-monitoramento' '01-logman-query' { logman query }
Evidencia '05-monitoramento' '02-logman-monitor' { logman query CitizenTech_Monitor }
Evidencia '05-monitoramento' '03-logman-alertas' { logman query CitizenTech_Alertas }
Evidencia '05-monitoramento' '04-perflogs' { Get-ChildItem 'C:\PerfLogs\CitizenTech' -Recurse | Format-Table FullName, Length -AutoSize }
Evidencia '05-monitoramento' '05-get-counter' {
    try { Get-Counter '\Processor(_Total)\% Processor Time' -SampleInterval 2 -MaxSamples 3 -ErrorAction Stop }
    catch { 1..3 | ForEach-Object { "CPU: $((Get-CimInstance Win32_Processor | Measure-Object LoadPercentage -Average).Average)%"; Start-Sleep 2 } }
}
Print 'Abra o Monitor de Desempenho (Win+R > perfmon) > Conjuntos de Coletores de Dados > Definido pelo Usuario.'
Write-Host '   Mostre CitizenTech_Monitor e CitizenTech_Alertas em execucao (seta verde).' -ForegroundColor DarkGray
Write-Host '   Depois va em Ferramentas de Monitoramento > Monitor de Desempenho, clique no + verde e adicione:' -ForegroundColor DarkGray
Write-Host '   Processador > % Tempo de Processador (_Total) | Memoria > MBytes Disponiveis | Disco Logico > % Espaco Livre (C:)' -ForegroundColor DarkGray
Write-Host '   Tire print do grafico com os tres contadores.' -ForegroundColor DarkGray
Pausa 'Depois dos prints, pressione ENTER para testar o script de alerta'

Passo 'Testando o script de alerta'
Write-Host ''
Write-Host 'PS C:\> C:\Scripts\Monitor-Recursos.ps1' -ForegroundColor White
& 'C:\Scripts\Monitor-Recursos.ps1'
Write-Host ''
Write-Host 'PS C:\> C:\Scripts\Monitor-Recursos.ps1 -Simular   (limites rebaixados para forcar o alerta)' -ForegroundColor White
& 'C:\Scripts\Monitor-Recursos.ps1' -Simular
Print 'Tire print das duas execucoes acima (verde = normal, amarelo = alerta)'

Passo 'Agendando a verificacao a cada 5 minutos'
$acao = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument '-NoProfile -ExecutionPolicy Bypass -File C:\Scripts\Monitor-Recursos.ps1'
$gatilho = New-ScheduledTaskTrigger -Once -At (Get-Date).AddMinutes(1) -RepetitionInterval (New-TimeSpan -Minutes 5) -RepetitionDuration (New-TimeSpan -Days 365)
Register-ScheduledTask -TaskName 'CitizenTech_Monitor_Alertas' -Action $acao -Trigger $gatilho -User 'SYSTEM' -RunLevel Highest -Force | Out-Null
# Liga o historico do Agendador de Tarefas (para aparecer a aba Historico)
wevtutil set-log Microsoft-Windows-TaskScheduler/Operational /enabled:true
Start-ScheduledTask -TaskName 'CitizenTech_Monitor_Alertas'
Start-Sleep -Seconds 5
Evidencia '05-monitoramento' '08-scheduledtask' { Get-ScheduledTask -TaskName 'CitizenTech_Monitor_Alertas' | Format-Table TaskName, State -AutoSize; Get-ScheduledTaskInfo -TaskName 'CitizenTech_Monitor_Alertas' | Format-List LastRunTime, LastTaskResult, NextRunTime }
Evidencia '05-monitoramento' '09-alertas-log' { Get-Content 'C:\Scripts\logs\alertas.log' }
Print 'Abra o Agendador de Tarefas (taskschd.msc) > Biblioteca, selecione CitizenTech_Monitor_Alertas e tire print (inclua a aba Historico)'
Proximo 'rode .\07-Tolerancia-Falhas.ps1'
