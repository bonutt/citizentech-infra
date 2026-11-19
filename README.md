# CitizenTech · Infraestrutura Windows Server para o Gota Inteligente

Global Solution 2026 · FIAP · 3ES · Disciplina **Operating Systems**

Este repositório tem a infraestrutura Windows Server que hospeda a aplicação web da solução CitizenTech da equipe, o **Gota Inteligente**. Estão aqui os scripts PowerShell de cada etapa, o site publicado no IIS, a documentação e as evidências (prints) de cada critério de avaliação.

## Equipe

| Integrante | RM |
|---|---|
| Henrique Maciel Rodrigues | |
| Igor Pereira Nociti | |
| João Pedro Vieira de Moais | |
| Luigi Pereira Bonuccelli | 560950 |
| Pedro Paulo Sabino Botelho | |

## Ficha da CitizenTech

| Campo | Valor |
|---|---|
| **Nome da solução** | Gota Inteligente |
| **Problema que resolve** | O agricultor familiar irriga "no olho": desperdiça água e energia e muitas vezes rega um dia antes de chover. O Gota Inteligente é um assistente de irrigação de baixo custo. Ele cruza a umidade do solo, medida por um sensor com ESP32, com a previsão do tempo e recomenda irrigar ou aguardar. |
| **Público** | Agricultores familiares, Sindicato Rural e Prefeitura |
| **Tecnologias da solução** | ESP32 + sensor de umidade (Wokwi), modelo de Machine Learning em Python, app React Native, painel C# Windows Forms, backend Python (FastAPI) |
| **Tecnologias desta infraestrutura** | Windows Server 2022 Standard Evaluation (Desktop Experience), Active Directory, DNS, IIS 10, File Server (SMB), DFS Namespace, GPO, RDP, Monitor de Desempenho (Data Collector Set + Alerta), Agendador de Tarefas, auditoria (auditpol), PowerShell 5.1 |
| **Hipervisor** | Oracle VirtualBox · VM com 4 GB de RAM, 2 vCPUs, disco de 60 GB, rede em modo Bridge |
| **Hospedagem escolhida** | **Caminho A: aplicação estática** (HTML, CSS e JavaScript). O pool `CitizenTechPool` roda com `managedRuntimeVersion` vazio ("Sem código gerenciado"). |
| **Hostname** | `SRV-CITIZENTECH` |
| **IP do servidor** | `192.168.10.206` (máscara 255.255.255.0, gateway 192.168.10.1) |
| **Domínio** | `citizentech.local` (NetBIOS `CITIZENTECH`) |
| **Endereço do site** | `http://<IP do servidor>` ou `http://citizentech.citizentech.local` |
| **Pasta do site** | `C:\inetpub\citizentech` |
| **Compartilhamento** | `\\SRV-CITIZENTECH\CitizenTech` · DFS: `\\citizentech.local\CitizenTechDFS\Arquivos` |
| **Credenciais de teste** | `CITIZENTECH\ana.souza` (grupo `GG_CitizenTech_Admins`) e `CITIZENTECH\carlos.lima` (usuário comum, `GG_CitizenTech_Usuarios`). As senhas de laboratório estão em `scripts/_comum.ps1`. Elas valem só para esta VM de testes e não são senhas reais. |

## Estrutura do repositório

```
citizentech-infra/
    README.md
    docs/
        roteiro-configuracao.md   roteiro de configuração do ambiente
        ficha-citizentech.md      ficha da solução e desenho do ambiente
    scripts/
        _comum.ps1                valores e funções compartilhadas
        01-Rede.ps1               IP fixo + hostname
        02-AD.ps1                 AD DS + DNS + promoção do domínio
        03-AD-Usuarios.ps1        validação do domínio, OU, grupos e usuários
        04-IIS.ps1                IIS, pool, site, NTFS e File Server
        05-Infra.ps1              GPO, RDP, DFS e auditoria
        06-Monitoramento.ps1      Data Collector Set, alerta e tarefa agendada
        07-Tolerancia-Falhas.ps1  recuperação do pool e do W3SVC + teste de falha
        08-Validacao-Final.ps1    ficha final da infraestrutura
        Monitor-Recursos.ps1      alerta por limiar (CPU, memória, disco)
        Teste-Falha.ps1           derruba o IIS e prova a recuperação automática
        Recupera-Site.ps1         recupera serviço, pool e site
    site/                         aplicação web Gota Inteligente (publicada no IIS)
    evidencias/
        01-rede/  02-ad-dns/  03-iis/  04-ntfs-gpo/
        05-monitoramento/  06-teste-falha/  07-logs/  08-validacao-final/
```

## Como executar

No PowerShell do servidor, como Administrador, a partir da pasta `scripts`:

```powershell
Set-ExecutionPolicy Bypass -Scope Process -Force
.\01-Rede.ps1            # IP fixo e hostname (reinicia)
.\02-AD.ps1              # AD DS + DNS + domínio citizentech.local (reinicia)
.\03-AD-Usuarios.ps1     # OU, grupos e usuários
.\04-IIS.ps1             # IIS, site, pool, NTFS e File Server
.\05-Infra.ps1           # GPO, RDP, DFS e auditoria
.\06-Monitoramento.ps1   # Data Collector Set, alertas e tarefa agendada
.\07-Tolerancia-Falhas.ps1  # recuperação automática + teste de falha
.\08-Validacao-Final.ps1 # ficha da infraestrutura
```

Cada script mostra o comando executado e a sua saída, e também grava essa saída em `C:\CitizenTech\evidencias` no servidor. O passo a passo detalhado está em [docs/roteiro-configuracao.md](docs/roteiro-configuracao.md).

## Decisões técnicas

- **Rede:** o script 01 pega o IP que a VM recebeu do roteador (DHCP) e o deixa fixo, com o mesmo gateway. Assim o IP sempre combina com a rede real. O DNS da placa aponta para o próprio servidor.
- **Porta 80:** o `Default Web Site` é removido, porque ele também usa a porta 80 e impediria o site `CitizenTech` de iniciar.
- **Nomes independentes de idioma:** grupos internos (`IIS_IUSRS`, `Everyone`, `Domain Users`), regras de firewall do RDP e subcategorias do `auditpol` são referenciados por SID ou GUID. Os scripts funcionam em Windows Server em inglês ou em português.
- **GPO testável:** num controlador de domínio, usuário comum não pode fazer logon local. O `carlos.lima` foi colocado no grupo interno *Print Operators*, que tem esse direito e poucos privilégios, para demonstrar o bloqueio do Painel de Controle na tela.
- **DFS:** a raiz de domínio usa o formato correto `\\citizentech.local\CitizenTechDFS` (com destino em um compartilhamento UNC). O compartilhamento `CitizenTech` fica publicado como a pasta `Arquivos` dentro dela.
- **Monitoramento duplo:** no Monitor de Desempenho há o coletor `CitizenTech_Monitor` (grava CPU, memória e disco a cada 15 s em CSV) e o alerta `CitizenTech_Alertas` (CPU > 80 %, memória < 500 MB, disco < 15 % livre, registrando no log de eventos). O `Monitor-Recursos.ps1` roda a cada 5 minutos pelo Agendador de Tarefas e grava em `C:\Scripts\logs\alertas.log` e no log *Application* (evento 9001).
- **Teste de falha realista:** um `Stop-Service` comum não dispara a recuperação do Windows, porque o Windows entende que a parada foi proposital. Por isso o `Teste-Falha.ps1` simula um **travamento** encerrando o processo do W3SVC. Assim o próprio Gerenciador de Serviços o reinicia em 5 s (`sc.exe failure`). Na segunda parte do teste, o pool é parado e a tarefa `CitizenTech_Recuperacao` (a cada 2 min) o recupera, registrando tudo em `recuperacao.log`.

## Rastreabilidade: critério → evidência

Todos os prints foram tirados do ambiente real (SRV-CITIZENTECH, 192.168.10.206). As saídas em texto de cada comando também ficam no servidor, em `C:\CitizenTech\evidencias`.

| Critério | Pontos | Evidências (prints) |
|---|---|---|
| Infraestrutura de rede e identidade (IP fixo, hostname, DNS e domínio no AD) | 2,0 | [00-versao-windows](evidencias/01-rede/00-versao-windows.png) · [00-winver](evidencias/01-rede/00-winver.png) · [01-get-netadapter](evidencias/01-rede/01-get-netadapter.png) · [02-new-netipaddress](evidencias/01-rede/02-new-netipaddress.png) · [03-ipconfig-all](evidencias/01-rede/03-ipconfig-all.png) · [04-rename-computer](evidencias/01-rede/04-rename-computer.png) · [05-ipconfig-apos-reinicio](evidencias/01-rede/05-ipconfig-apos-reinicio.png) · [01-install-adds](evidencias/02-ad-dns/01-install-adds.png) · [02-install-addsforest](evidencias/02-ad-dns/02-install-addsforest.png) · [03-get-addomain](evidencias/02-ad-dns/03-get-addomain.png) · [04-nslookup](evidencias/02-ad-dns/04-nslookup.png) · [05-get-dnsserverzone](evidencias/02-ad-dns/05-get-dnsserverzone.png) · [06-get-aduser](evidencias/02-ad-dns/06-get-aduser.png) · [07-get-adgroupmember](evidencias/02-ad-dns/07-get-adgroupmember.png) |
| Aplicação hospedada no IIS (site, pool, dependências, pasta e permissões NTFS) | 2,0 | [01-install-iis](evidencias/03-iis/01-install-iis.png) · [02-get-windowsfeature-web](evidencias/03-iis/02-get-windowsfeature-web.png) · [03-arquivos-site](evidencias/03-iis/03-arquivos-site.png) · [04-get-website](evidencias/03-iis/04-get-website.png) · [05-apppool](evidencias/03-iis/05-apppool.png) · [06-get-webapppoolstate](evidencias/03-iis/06-get-webapppoolstate.png) · [07-invoke-webrequest](evidencias/03-iis/07-invoke-webrequest.png) · [08-navegador-1](evidencias/03-iis/08-navegador-1.png) · [08-navegador-2](evidencias/03-iis/08-navegador-2.png) · [01-get-acl](evidencias/04-ntfs-gpo/01-get-acl.png) · [02-install-fileserver](evidencias/04-ntfs-gpo/02-install-fileserver.png) · [03-get-smbshare](evidencias/04-ntfs-gpo/03-get-smbshare.png) · [04-get-smbshareaccess](evidencias/04-ntfs-gpo/04-get-smbshareaccess.png) · [09-aba-seguranca](evidencias/04-ntfs-gpo/09-aba-seguranca.png) · [10-acesso-share](evidencias/04-ntfs-gpo/10-acesso-share.png) |
| Monitoramento com alertas de CPU, disco e memória | 2,0 | [01-logman-query](evidencias/05-monitoramento/01-logman-query.png) · [02-logman-monitor](evidencias/05-monitoramento/02-logman-monitor.png) · [03-logman-alertas](evidencias/05-monitoramento/03-logman-alertas.png) · [04-perflogs](evidencias/05-monitoramento/04-perflogs.png) · [05-get-counter](evidencias/05-monitoramento/05-get-counter.png) · [08-scheduledtask](evidencias/05-monitoramento/08-scheduledtask.png) · [09-alertas-log](evidencias/05-monitoramento/09-alertas-log.png) · [10-perfmon-conjuntos](evidencias/05-monitoramento/10-perfmon-conjuntos.png) · [11-perfmon-grafico](evidencias/05-monitoramento/11-perfmon-grafico.png) · [12-agendador](evidencias/05-monitoramento/12-agendador.png) |
| Serviços tolerantes a falhas e teste de falha | 1,0 | [01-pool-config](evidencias/06-teste-falha/01-pool-config.png) · [02-sc-qfailure](evidencias/06-teste-falha/02-sc-qfailure.png) · [03-scheduledtask](evidencias/06-teste-falha/03-scheduledtask.png) · [04-teste-falha-1](evidencias/06-teste-falha/04-teste-falha-1.png) · [04-teste-falha-2](evidencias/06-teste-falha/04-teste-falha-2.png) · [05-recuperacao-log](evidencias/06-teste-falha/05-recuperacao-log.png) · [06-aba-recuperacao](evidencias/06-teste-falha/06-aba-recuperacao.png) |
| Logs de auditoria e acompanhamento | 1,0 | [01-auditpol](evidencias/07-logs/01-auditpol.png) · [02-regra-auditoria-pasta](evidencias/07-logs/02-regra-auditoria-pasta.png) · [03-security-log](evidencias/07-logs/03-security-log.png) · [04-iis-logs](evidencias/07-logs/04-iis-logs.png) · [05-eventvwr-security](evidencias/07-logs/05-eventvwr-security.png) · [06-pasta-logs-iis](evidencias/07-logs/06-pasta-logs-iis.png) |
| Funcionamento completo da proposta | 2,0 | [01-ficha-parte1](evidencias/08-validacao-final/01-ficha-parte1.png) · [02-ficha-parte2](evidencias/08-validacao-final/02-ficha-parte2.png) · [03-ficha-parte3](evidencias/08-validacao-final/03-ficha-parte3.png) |
| *Infraestrutura de suporte: GPO, RDP e DFS* |  | [05-get-gpo-all](evidencias/04-ntfs-gpo/05-get-gpo-all.png) · [06-gplink](evidencias/04-ntfs-gpo/06-gplink.png) · [07-rdp](evidencias/04-ntfs-gpo/07-rdp.png) · [08-get-dfsnroot](evidencias/04-ntfs-gpo/08-get-dfsnroot.png) · [11-rdp-porta-3389](evidencias/04-ntfs-gpo/11-rdp-porta-3389.png) · [12-rdp-hostname](evidencias/04-ntfs-gpo/12-rdp-hostname.png) |
| **Vídeo** (até 7 min) | | `<colar link do vídeo aqui>` |

## Vídeo

Link: `<colar link do YouTube (não listado) ou do Drive aqui>`
