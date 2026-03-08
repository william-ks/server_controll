# TASK 01 - Categorizacao de Tempo de Jogo dos Players

## Contexto atual no projeto
- O runtime do servidor ja rastreia estado online/offline e lista de players em memoria via [lib/modules/server/providers/server_runtime_provider.dart](C:/Users/Usuario/Desktop/projeto/server_controll/lib/modules/server/providers/server_runtime_provider.dart).
- O parser de logs ja detecta `joined the game`, `left the game` e saida do comando `list` em [lib/modules/server/services/server_log_parser.dart](C:/Users/Usuario/Desktop/projeto/server_controll/lib/modules/server/services/server_log_parser.dart).
- Nao existe persistencia de sessoes de jogo, ranking, agregados diarios/semanais ou historico por player no schema atual de [lib/database/app_database.dart](C:/Users/Usuario/Desktop/projeto/server_controll/lib/database/app_database.dart).
- O projeto ainda nao possui um modulo de dominio de players unificado; hoje existe apenas whitelist em [lib/modules/whitelist/](C:/Users/Usuario/Desktop/projeto/server_controll/lib/modules/whitelist).

## Como implementar
- Dados:
  - Adicionar tabelas `players`, `player_sessions` e `player_playtime_aggregates` (diario, semanal, total).
  - Incluir colunas de consistencia em `player_sessions`: `is_open`, `is_incomplete`, `start_at`, `end_at`, `last_seen_at`, `close_reason`.
  - Criar indice por `player_id + start_at` e por sessoes abertas (`is_open = 1`).
- Servico de sessao:
  - Criar `player_playtime_service` responsavel por abrir sessao no join, fechar no leave, e consolidar agregados.
  - Usar `nickname` como chave inicial e permitir associacao posterior por UUID quando disponivel.
- Tick global:
  - Criar `player_presence_tick_service` com `Timer.periodic` configuravel (default 5s).
  - No tick: solicitar `list`, reconciliar players online, atualizar `last_seen_at`, detectar sessoes abertas sem presenca real.
  - Persistir configuracao em `app_settings` (ex.: `playtime_tick_seconds`).
- Resiliencia:
  - No startup do app, marcar sessoes abertas antigas como incompletas com `close_reason = app_shutdown_unexpected`.
  - Antes de restart/stop, salvar snapshot de presenca e fechar sessoes com `close_reason` adequado.
  - Em kick detectado por evento/log, fechar sessao como `kick`.
- UI:
  - Criar secao em Players com:
    - historico por player;
    - cards de tempo diario, semanal e total;
    - ranking geral ordenado por total.
  - Exibir flag visual de sessao incompleta no historico.
- Integracao cross-platform:
  - Reaproveitar runtime e parser existentes; nao introduzir comando especifico de SO.

## Como verificar
- [ ] Iniciar servidor, entrar com 1 player, sair normalmente e validar sessao completa no banco.
- [ ] Simular fechamento abrupto do app com player online e validar sessao marcada como incompleta no proximo startup.
- [ ] Executar restart/stop com player online e validar fechamento com `close_reason` correto.
- [ ] Confirmar atualizacao de agregados diario, semanal e total apos multiplas sessoes.
- [ ] Confirmar ranking ordenado por tempo total e consistencia com soma das sessoes.
- [ ] Validar que tick de 5s nao degrada uso de CPU de forma perceptivel no app.

## Dependencias e ordem sugerida
- Implementar primeiro o schema novo no banco.
- Depois implementar servico de sessao e tick global.
- Integrar com eventos do runtime/server.
- Por fim entregar UI de historico e ranking.
- Recomendada antes de Task 08 (refatoracao do dominio de players).

## Definicao de concluido
- Existe historico persistido de sessoes por player com suporte a sessoes incompletas.
- Agregados diario/semanal/total e ranking estao disponiveis e coerentes.
- Cenarios de join/leave/kick/restart/stop/app shutdown estao cobertos sem perda de rastreabilidade.
- Tick global esta configuravel e ativo por padrao com 5 segundos.

