# TASK 07 - Gerenciamento de Permissoes: Player, Admin do App e OP

## Contexto atual no projeto
- O projeto hoje tem whitelist local e sincronizacao com `whitelist.json`, mas nao possui conceito formal de admin do app.
- Nao existe dominio separado para OP no banco atual, nem regra de integridade OP -> admin do app.
- O `MinecraftCommandProvider` ainda nao expoe comandos `op/deop`.
- A arquitetura atual ja usa providers/services e permite ampliar o dominio sem quebrar runtime/backup/chunky.

## Como implementar
- Modelo de permissao:
  - Criar estrutura de dados com papeis independentes:
    - `is_player`, `is_whitelisted`, `is_app_admin`, `is_op`, `is_banned`.
  - Regra de integridade obrigatoria: `is_op = true` somente se `is_app_admin = true`.
- Banco:
  - Introduzir tabela de status por player (ou colunas em tabela central de players, definida junto da Task 08).
  - Adicionar tabela de pendencias offline para operacoes administrativas.
- Sincronizacao servidor:
  - Ampliar provider de comandos para `op <player>` e `deop <player>`.
  - Sincronizar alteracoes de whitelist/op quando servidor estiver online.
  - Quando offline, registrar pendencia e aplicar no proximo ciclo online.
- Fluxo offline:
  - Permitir adicionar admin do app offline (status local imediato).
  - Permitir marcar OP offline apenas se ja for admin do app; aplicar comando depois.
- UI:
  - Atualizar area de Players com badges claros para cada status.
  - Bloquear acao de OP quando regra de integridade nao for atendida.
- Rastreabilidade:
  - Registrar quem alterou permissao, quando e resultado da sincronizacao.

## Como verificar
- [ ] Criar admin do app offline e confirmar persistencia.
- [ ] Tentar promover OP sem admin do app e validar bloqueio.
- [ ] Promover admin + OP e validar aplicacao no servidor quando online.
- [ ] Remover admin de player OP e confirmar despromocao OP obrigatoria.
- [ ] Validar comportamento de pendencias em reinicio de app/servidor.
- [ ] Confirmar exibicao correta de combinacoes de status na UI.

## Dependencias e ordem sugerida
- Depende da modelagem de players da Task 08 (ou deve ser implementada em paralelo no mesmo dominio).
- Implementar primeiro regra de integridade e persistencia local.
- Depois sincronizacao com comandos do servidor.
- Finalizar com UI e logs administrativos.

## Definicao de concluido
- O sistema separa claramente player, admin do app e OP.
- A regra "todo OP precisa ser admin do app" e aplicada em todas as camadas.
- Operacoes offline funcionam com pendencia e sincronizacao posterior consistente.

