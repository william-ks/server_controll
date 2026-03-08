# TASK 02 - Modo de Manutencao do Servidor

## Contexto atual no projeto
- O app ja possui controle de lifecycle (start/stop/restart) em [lib/modules/server/providers/server_runtime_provider.dart](C:/Users/Usuario/Desktop/projeto/server_controll/lib/modules/server/providers/server_runtime_provider.dart).
- O sistema de comandos Minecraft existe em [lib/modules/server/services/minecraft_command_provider.dart](C:/Users/Usuario/Desktop/projeto/server_controll/lib/modules/server/services/minecraft_command_provider.dart), incluindo `kick` e `say`.
- Existe edicao de MOTD e imagem do servidor via `server.properties` e manipulacao de `server-icon` em [lib/modules/config/subcomponents/properties_settings_tab.dart](C:/Users/Usuario/Desktop/projeto/server_controll/lib/modules/config/subcomponents/properties_settings_tab.dart).
- Ainda nao existe modo manutencao, controle por admins do app, nem restauracao automatica de estado visual apos manutencao.

## Como implementar
- Dados:
  - Criar tabela `maintenance_state` com `is_active`, `mode`, `starts_at`, `ends_at`, `countdown_seconds`, `motd_before`, `motd_during`, `icon_before_path`, `icon_during_path`.
  - Persistir configuracoes padrao em `app_settings`: `maintenance_default_mode`, `maintenance_countdown_default`, `maintenance_motd_total`, `maintenance_motd_admin`.
- Servico de manutencao:
  - Criar `maintenance_service` com API para `schedule`, `activate`, `deactivate`, `enforceAccess`.
  - Modos:
    - `total`: bloquear todos.
    - `admins_only`: permitir somente admins do app.
  - Reaproveitar parser de join para detectar entrada e aplicar kick imediato quando nao autorizado.
- Contagem regressiva:
  - Criar timer interno com marcos 60s, 30s, 10s.
  - Mensagens no chat devem usar prefixo fixo `[SERVER 🤖]`.
  - Integrar com a Home para ativacao imediata ou agendada.
- Alteracao visual:
  - Ao ativar: trocar MOTD e icon conforme modo.
  - Ao desativar: restaurar MOTD/icon anteriores gravados no estado.
  - Implementar fallback seguro caso arquivo de icon nao exista.
- Controle de acesso:
  - Integrar com dominio de permissao de admin do app (Task 07/08).
  - Enquanto a base de admins nao estiver pronta, deixar adaptador unico para troca futura.
- UI:
  - Adicionar modal/tela de manutencao com:
    - seletor de modo;
    - ativar agora ou com atraso;
    - timer;
    - preview de MOTD/icon.

## Como verificar
- [ ] Ativar manutencao total imediata e confirmar que novos joins sao removidos.
- [ ] Ativar manutencao admins_only e validar entrada apenas de admins do app.
- [ ] Validar mensagens de contagem regressiva em 60/30/10 segundos com prefixo `[SERVER 🤖]`.
- [ ] Confirmar troca de MOTD e icon durante manutencao e restauracao ao desativar.
- [ ] Reiniciar app no meio da manutencao e confirmar estado persistido e reidratado.
- [ ] Validar comportamento em Windows e Linux sem mudancas de comando por SO.

## Dependencias e ordem sugerida
- Base de dados de estado de manutencao primeiro.
- Servico de manutencao e timer depois.
- Integracao com runtime/log parser para enforcement.
- UI por ultimo.
- Esta task deve anteceder Task 03 (protecao durante Chunky).

## Definicao de concluido
- O app ativa/desativa manutencao com modos total e admins_only.
- O acesso de players e controlado em runtime conforme modo.
- MOTD e icon sao alterados e restaurados automaticamente.
- Contagem regressiva e mensagens de chat funcionam com o prefixo global correto.

