# ETAPA 5 - Tolerancia a falhas e recuperacao automatica

. "$PSScriptRoot\_comum.ps1"
Testar-Admin
Titulo 'ETAPA 5 - Tolerancia a falhas'
Import-Module WebAdministration

Passo 'Recuperacao automatica do pool do IIS'
Set-ItemProperty -Path "IIS:\AppPools\$($CT.Pool)" -Name failure.rapidFailProtection -Value $false
Set-ItemProperty -Path "IIS:\AppPools\$($CT.Pool)" -Name autoStart -Value $true
Set-ItemProperty -Path "IIS:\AppPools\$($CT.Pool)" -Name startMode -Value 'AlwaysRunning'
Evidencia '06-teste-falha' '01-pool-config' { Get-ItemProperty 'IIS:\AppPools\CitizenTechPool' | Format-List Name, State, autoStart, startMode, @{n='rapidFailProtection';e={$_.failure.rapidFailProtection}} }

Passo 'Recuperacao do servico W3SVC (e do WAS, do qual ele depende)'
sc.exe failure W3SVC reset= 86400 actions= restart/5000/restart/10000/restart/30000 | Out-Null
sc.exe failure WAS   reset= 86400 actions= restart/5000/restart/10000/restart/30000 | Out-Null
Evidencia '06-teste-falha' '02-sc-qfailure' { sc.exe qfailure W3SVC }
Print 'Tire print do sc.exe qfailure W3SVC e da aba Recuperacao do servico (services.msc > Servico de Publicacao na World Wide Web / World Wide Web Publishing Service)'

Passo 'Tarefa de recuperacao automatica (a cada 2 minutos)'
$acao = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument '-NoProfile -ExecutionPolicy Bypass -File C:\Scripts\Recupera-Site.ps1'
$gatilho = New-ScheduledTaskTrigger -Once -At (Get-Date).AddMinutes(1) -RepetitionInterval (New-TimeSpan -Minutes 2) -RepetitionDuration (New-TimeSpan -Days 365)
Register-ScheduledTask -TaskName 'CitizenTech_Recuperacao' -Action $acao -Trigger $gatilho -User 'SYSTEM' -RunLevel Highest -Force | Out-Null
Evidencia '06-teste-falha' '03-scheduledtask' { Get-ScheduledTask -TaskName 'CitizenTech_*' | Format-Table TaskName, State -AutoSize }

Write-Host ''
Write-Host '   Tudo pronto para o teste de falha. Abra o site no navegador do SEU PC antes de rodar.' -ForegroundColor Green
Pausa 'Pressione ENTER para executar o Teste-Falha.ps1 agora'
Start-Transcript -Path (Join-Path $CT.Evid '06-teste-falha\04-teste-falha.txt') -Force | Out-Null
& 'C:\Scripts\Teste-Falha.ps1'
Stop-Transcript | Out-Null
Evidencia '06-teste-falha' '05-recuperacao-log' { Get-Content 'C:\Scripts\logs\recuperacao.log' }
Print 'Tire print das etapas [1] a [5] do teste, da parte 2, do recuperacao.log e do navegador voltando a carregar o site'
Write-Host '   Para repetir o teste no video: powershell -ExecutionPolicy Bypass -File C:\Scripts\Teste-Falha.ps1' -ForegroundColor DarkGray
Proximo 'rode .\08-Validacao-Final.ps1'
