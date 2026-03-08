# TASK 12 - Fluxo de Backup Automatico

## Contexto atual no projeto
- Ja existe agendador cron funcional em [lib/modules/schedules/services/schedules_runner_service.dart](C:/Users/Usuario/Desktop/projeto/server_controll/lib/modules/schedules/services/schedules_runner_service.dart).
- O fluxo atual usa backup completo em cenarios de schedule e sem retry estruturado.
- Avisos de contagem regressiva ja existem, mas usam prefixo `[Server]` e precisam padronizar para `[SERVER 🤖]`.
- Ainda nao ha suporte automatico completo para backup world/selective/app no runner.

## Como implementar
- Ampliar tipos automaticos:
  - Permitir selecionar tipo de backup por agendamento/acao:
    - full, world, selective, app.
  - Reusar servicos definidos nas Tasks 04, 05 e 11.
- Fluxos lifecycle:
  - `start`: backup antes de iniciar.
  - `stop`: parar servidor, depois backup.
  - `restart`: parar, backup, iniciar.
  - Sempre executar `save-all` quando houver interacao com estado de mundo.
- Contagem com players online:
  - Reusar aviso periodico antes de parada/reinicio.
  - Padronizar mensagens para `[SERVER 🤖]`.
- Retry:
  - Implementar politica de ate 3 tentativas por execucao automatica.
  - Entre tentativas, aguardar intervalo curto configuravel (ex.: 10s).
  - Registrar falhas parciais e falha final.
- Notificacao:
  - Exibir erro visual no app quando backup automatico falhar.
  - Registrar historico para troubleshooting (integracao Task 14).
- Robustez:
  - Evitar concorrencia de backups automaticos em paralelo.
  - Bloquear disparo se ja houver execucao em progresso.

## Como verificar
- [ ] Criar agendamentos para start/stop/restart e validar ordem correta com backup.
- [ ] Confirmar `save-all` antes de backup nos fluxos aplicaveis.
- [ ] Simular falha no backup e validar retries ate 3 tentativas.
- [ ] Confirmar notificacao visual e registro de falha apos esgotar tentativas.
- [ ] Validar mensagens de aviso com prefixo `[SERVER 🤖]`.
- [ ] Testar backup automatico dos quatro tipos previstos.

## Dependencias e ordem sugerida
- Depende de Task 04, Task 05 e Task 11.
- Implementar primeiro suporte a tipos de backup no runner.
- Depois adicionar retries e notificacoes.
- Finalizar com padronizacao de mensagens e bloqueio de concorrencia.

## Definicao de concluido
- O backup automatico cobre full/world/selective/app.
- Fluxos de lifecycle executam ordem operacional correta com retry.
- Falhas ficam rastreaveis e visiveis para o operador.

