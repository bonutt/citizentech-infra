# Ficha da CitizenTech

## Solução

**Gota Inteligente** é um assistente de irrigação de baixo custo para o agricultor familiar.

- **Problema:** sem medir o solo, o pequeno produtor irriga por intuição. Desperdiça água e energia da bomba e muitas vezes irriga pouco antes de uma chuva.
- **Como resolve:** um sensor de umidade com ESP32 mede o solo do talhão. O sistema cruza essa leitura com a previsão de chuva para as próximas 24 h e recomenda **irrigar** (e por quanto tempo) ou **aguardar**.
- **Quem usa:** o agricultor recebe a recomendação no app (React Native). O Sindicato Rural e a Prefeitura acompanham os talhões pelo painel desktop (C# Windows Forms).
- **Componentes:** ESP32 + sensor (Physical Computing, Wokwi) · modelo de ML em Python · backend FastAPI · app React Native · painel WinForms · **página web hospedada nesta infraestrutura Windows Server**.

## Desenho do ambiente

| Item | Valor |
|---|---|
| Hipervisor | Oracle VirtualBox |
| Sistema | Windows Server 2022 Standard Evaluation (Desktop Experience) |
| Hardware da VM | 4 GB RAM · 2 vCPUs · disco de 60 GB (dinâmico) |
| Rede | Placa em modo Bridge, IP fixo na rede local |
| Hostname | SRV-CITIZENTECH |
| IP | `192.168.10.206` · gateway 192.168.10.1 |
| Domínio / NetBIOS | citizentech.local / CITIZENTECH |
| DNS | Integrado ao AD · zona `citizentech.local` (Primary) · registro `citizentech` → IP do servidor · encaminhadores 8.8.8.8 e 1.1.1.1 |
| OU | `OU=CitizenTech,DC=citizentech,DC=local` |
| Grupos | GG_CitizenTech_Admins · GG_CitizenTech_Usuarios |
| Usuários de teste | ana.souza (admin) · carlos.lima (comum) |
| Site IIS | CitizenTech · porta 80 · `C:\inetpub\citizentech` · pool CitizenTechPool (sem código gerenciado) |
| Compartilhamento | `\\SRV-CITIZENTECH\CitizenTech` → `C:\Shares\CitizenTech` |
| DFS | `\\citizentech.local\CitizenTechDFS\Arquivos` |
| GPO | GPO_CitizenTech_Usuarios (NoControlPanel) vinculada à OU CitizenTech |
| Monitoramento | CitizenTech_Monitor (coletor) · CitizenTech_Alertas (alerta) · tarefa CitizenTech_Monitor_Alertas (5 min) |
| Recuperação | sc failure W3SVC/WAS (5 s / 10 s / 30 s) · pool sem Rapid-Fail · tarefa CitizenTech_Recuperacao (2 min) |
| Logs | Auditoria de Logon e File System (sucesso e falha) · `C:\inetpub\logs\LogFiles` · `C:\Scripts\logs\alertas.log` e `recuperacao.log` |

## Diagrama

```
                 Rede local (roteador / gateway)
                               │
        ┌──────────────────────┴──────────────────────┐
        │                                             │
  PC do usuário (cliente)                  VM SRV-CITIZENTECH (Bridge, IP fixo)
  - navegador → http://IP                  ┌──────────────────────────────────────┐
  - mstsc (RDP)                            │ AD DS + DNS   citizentech.local      │
  - \\SRV-CITIZENTECH\CitizenTech          │ IIS 10        site CitizenTech :80   │
                                           │ File Server   \\...\CitizenTech      │
                                           │ DFS           \\citizentech.local\…  │
                                           │ GPO           OU CitizenTech         │
                                           │ PerfMon + Agendador (alertas)        │
                                           │ Recuperação automática do IIS        │
                                           │ Auditoria + Event Log + logs do IIS  │
                                           └──────────────────────────────────────┘
```
