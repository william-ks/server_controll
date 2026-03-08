# TASK 03 - Protecao Durante Geracao de Chunks

## Contexto atual no projeto
- O fluxo de execucao de Chunky ja existe e e robusto em [lib/modules/chunky/providers/chunky_execution_provider.dart](C:/Users/Usuario/Desktop/projeto/server_controll/lib/modules/chunky/providers/chunky_execution_provider.dart).
- Ja ha checkpoint e retomada de execucao, inclusive apos reinicios parciais de fluxo.
- Nao existe ainda uma camada de protecao de acesso dedicada para execucao de chunk.
- A infraestrutura base de manutencao sera introduzida na Task 02 e deve ser reutilizada aqui.

## Como implementar
- Reuso de infraestrutura:
  - Integrar `chunky_execution_provider` com `maintenance_service`.
  - Ao iniciar geracao, perguntar se ativa protecao e qual modo: `total` ou `admins_only`.
  - Mapear protecao de chunk para o mesmo mecanismo da manutencao, sem duplicar regras.
- Persistencia:
  - Salvar em `app_settings` ou tabela dedicada:
    - `chunk_protection_enabled`
    - `chunk_protection_mode`
    - `chunk_protection_owner_execution_id`
  - Em caso de restart entre runs, restaurar protecao automaticamente.
- Fluxo operacional:
  - Na tela de execucao/task do Chunky, exibir modal pre-start com escolhas de protecao.
  - Enquanto status for `running`/`paused`, manter enforcement ativo.
  - Ao concluir/cancelar com seguranca, remover protecao automaticamente se ela foi criada por essa execucao.
- Mensagens:
  - Avisos e feedback de protecao no chat devem usar `[SERVER 🤖]`.
- Confiabilidade:
  - Em erro fatal do fluxo, manter protecao ativa ate decisao explicita do operador.
  - Garantir idempotencia para nao desativar manutencao manual preexistente.

## Como verificar
- [ ] Iniciar chunk com protecao total e confirmar bloqueio de entrada durante toda a execucao.
- [ ] Iniciar chunk com protecao admins_only e validar acesso restrito.
- [ ] Simular restart entre runs e confirmar que protecao persiste sem nova acao manual.
- [ ] Finalizar execucao e validar desativacao automatica quando apropriado.
- [ ] Validar que manutencao manual existente nao e sobrescrita indevidamente.

## Dependencias e ordem sugerida
- Depende diretamente da Task 02 (modo manutencao pronto).
- Implementar primeiro integracao de estado/persistencia.
- Depois modal de escolha no fluxo de inicio do Chunky.
- Por ultimo regras de encerramento e idempotencia.

## Definicao de concluido
- O usuario consegue ativar protecao opcional ao iniciar geracao de chunks.
- A protecao permanece ativa durante todo o processo e sobrevive a reinicios entre etapas.
- O mecanismo e 100% reutilizado da manutencao, sem logica duplicada.

