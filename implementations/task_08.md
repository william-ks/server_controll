# TASK 08 - Refatoracao do Sistema de Players, Whitelist e Historico

## Contexto atual no projeto
- A whitelist atual vive em tabela dedicada (`whitelist_players`) e em modulo proprio [lib/modules/whitelist/](C:/Users/Usuario/Desktop/projeto/server_controll/lib/modules/whitelist).
- O modelo atual mistura cadastro base e status de whitelist, sem dominio unico para admin/op/ban/sessoes.
- Existe risco de acoplamento entre identificacao por nickname e UUID quando houver reconciliacao futura.
- Ainda nao existe tela unica de Players com abas para todos, whitelist, admins, OPs, banidos e historico.

## Como implementar
- Novo dominio de players:
  - Criar tabela `players` como entidade principal imutavel por historico.
  - Criar tabela `player_identities` para nickname/uuid com controle de conflitos.
  - Criar tabela `player_status_history` para trilha temporal de whitelist/admin/op/ban.
  - Migrar dados de `whitelist_players` para `players` sem perda de historico.
- Regras de integridade:
  - Nao excluir registro principal do player em remocao de whitelist.
  - Impedir duplicidade invalida de UUID.
  - Em conflito de UUID/nickname, registrar estado `conflict_pending_manual_review`.
- Fluxo de conciliacao UUID:
  - Permitir player sem UUID.
  - Quando UUID surgir, tentar vinculacao automatica por nickname.
  - Se houver ambiguidade, abrir fluxo de validacao manual.
- UI unificada:
  - Criar nova pagina `Players` com abas horizontais:
    - todos, whitelist, admins, ops, banidos, historico.
  - Reaproveitar componentes visuais da whitelist atual quando possivel.
- Compatibilidade gradual:
  - Manter adaptador temporario da whitelist antiga ate migracao completa.
  - Evitar ruptura imediata das rotas existentes.

## Como verificar
- [ ] Migrar base existente e confirmar que nenhum player foi perdido.
- [ ] Remover player da whitelist e validar preservacao do registro principal/historico.
- [ ] Cadastrar player sem UUID e associar UUID depois com sucesso.
- [ ] Simular conflito de UUID e validar bloqueio de duplicidade + fluxo manual.
- [ ] Validar abas da nova tela de Players com filtros coerentes.
- [ ] Confirmar que sincronizacao com arquivo do servidor segue funcional.

## Dependencias e ordem sugerida
- Implementar schema e migracao primeiro.
- Depois criar repositories/services novos e adaptadores.
- Em seguida construir tela unica de Players.
- Finalizar removendo uso direto da estrutura antiga da whitelist.
- Base recomendada antes de Task 09, Task 13 e Task 14.

## Definicao de concluido
- O dominio de players preserva historico e evita perda de dados por mudanca de status.
- UUID duplicado invalido e impossivel no estado final.
- Existe tela unica de Players cobrindo os recortes operacionais principais.

