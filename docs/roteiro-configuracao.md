# Roteiro de configuração · SRV-CITIZENTECH

Este roteiro descreve como o ambiente Windows Server da solução Gota Inteligente foi montado e configurado. Todas as etapas foram executadas no PowerShell, como Administrador, com os scripts da pasta `scripts/`.

## 1. Ambiente

| Item | Valor |
|---|---|
| Hipervisor | Oracle VirtualBox |
| Sistema | Windows Server 2022 Standard Evaluation (Desktop Experience) |
| VM | 4 GB RAM · 2 vCPUs · disco de 60 GB |
| Rede | Placa em modo Bridge |
| Hostname | SRV-CITIZENTECH |
| IP | 192.168.10.206/24 · gateway 192.168.10.1 · DNS 192.168.10.206 |
| Domínio | citizentech.local (NetBIOS CITIZENTECH) |

## 2. Rede e identidade (`01-Rede.ps1`, `02-AD.ps1`, `03-AD-Usuarios.ps1`)

1. O IP recebido pela VM é fixado com `New-NetIPAddress`, mantendo o gateway da rede. O DNS da placa passa a apontar para o próprio servidor.
2. O servidor é renomeado para `SRV-CITIZENTECH` com `Rename-Computer` e reiniciado.
3. A função AD DS é instalada (`Install-WindowsFeature AD-Domain-Services`) e o servidor é promovido a controlador do domínio `citizentech.local` com DNS integrado (`Install-ADDSForest -InstallDns`).
4. Depois do reinício, são configurados os encaminhadores DNS e o registro `citizentech.citizentech.local`. O domínio é validado com `Get-ADDomain`, `nslookup` e `Get-DnsServerZone`.
5. São criados a OU `CitizenTech`, os grupos `GG_CitizenTech_Admins` e `GG_CitizenTech_Usuarios` e os usuários `ana.souza` (admin) e `carlos.lima` (usuário comum).

## 3. Aplicação no IIS (`04-IIS.ps1`) · Caminho A, site estático

1. O IIS é instalado com `Install-WindowsFeature Web-Server -IncludeManagementTools`.
2. Os arquivos de `site/` são publicados em `C:\inetpub\citizentech`.
3. O `Default Web Site` é removido para liberar a porta 80.
4. É criado o pool `CitizenTechPool`, com `managedRuntimeVersion` vazio ("Sem código gerenciado", o que evita o erro 500.19), e o site `CitizenTech` na porta 80.
5. A porta 80 é liberada no firewall.
6. A pasta recebe permissão NTFS `ReadAndExecute` para `IIS_IUSRS`.
7. O File Server é instalado. O compartilhamento `\\SRV-CITIZENTECH\CitizenTech` dá Full Control a `GG_CitizenTech_Admins` e leitura a `Domain Users`.

## 4. Infraestrutura de suporte (`05-Infra.ps1`)

- **GPO:** a `GPO_CitizenTech_Usuarios` foi vinculada à OU CitizenTech e aplica `NoControlPanel = 1`, que bloqueia o Painel de Controle.
- **Acesso remoto:** o RDP foi habilitado (`fDenyTSConnections = 0`) e as regras de firewall de Área de Trabalho Remota foram liberadas.
- **DFS:** foi criada a raiz de domínio `\\citizentech.local\CitizenTechDFS`, com a pasta `Arquivos` apontando para o compartilhamento CitizenTech.
- **Auditoria:** as subcategorias *Logon* e *File System* foram habilitadas com sucesso e falha (`auditpol`), e a pasta do site recebeu uma regra de auditoria (SACL) para `Everyone`.

## 5. Monitoramento (`06-Monitoramento.ps1`)

1. O Data Collector Set **CitizenTech_Monitor** grava `\Processor(_Total)\% Processor Time`, `\Memory\Available MBytes` e `\LogicalDisk(C:)\% Free Space` a cada 15 s em `C:\PerfLogs\CitizenTech`.
2. O alerta de desempenho **CitizenTech_Alertas** dispara com CPU > 80 %, memória < 500 MB ou disco < 15 % livre, e registra no log de eventos.
3. O script `Monitor-Recursos.ps1` roda a cada 5 minutos pela tarefa agendada `CitizenTech_Monitor_Alertas` (conta SYSTEM). Ele grava em `C:\Scripts\logs\alertas.log` e no log *Application*, com o evento 9001.

## 6. Tolerância a falhas (`07-Tolerancia-Falhas.ps1`)

1. No pool, a *Rapid-Fail Protection* foi desativada e configurados `autoStart = True` e `startMode = AlwaysRunning`.
2. Os serviços W3SVC e WAS foram configurados para reiniciar sozinhos depois de 5 s, 10 s e 30 s (`sc.exe failure`).
3. A tarefa agendada `CitizenTech_Recuperacao` roda o `Recupera-Site.ps1` a cada 2 minutos.
4. O `Teste-Falha.ps1` simula um travamento do W3SVC encerrando o processo do serviço: o site fica indisponível e o Windows o recupera sozinho. Depois o script para o pool (HTTP 503) e a tarefa de recuperação o religa. Tudo fica registrado em `C:\Scripts\logs\recuperacao.log`.

## 7. Validação final (`08-Validacao-Final.ps1`)

O script executa o bloco de validação da atividade: `hostname`, `ipconfig /all`, `nslookup`, `Test-NetConnection` na porta 80, domínio, recursos instalados, site, pool, serviços, compartilhamentos e GPOs.
