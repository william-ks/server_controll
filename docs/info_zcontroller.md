# Info zController (base de referência)

## Visão geral
O projeto `zController` (Python) é o baseline funcional para gerenciamento local de servidor Minecraft.
A versão Flutter (`server_controll`) deve manter as mesmas capacidades principais, com arquitetura mais modular, UI melhor e fluxo mais robusto.

## Estrutura observada
- `classes/`
  - `server_manager.py`: ciclo de vida do processo Java (start/stop/restart), envio de comandos, leitura de stdout, monitoramento de crash, auto-restart e detecção de jogadores.
  - `config_manager.py`: leitura/escrita de `config.json`, defaults, resolução de caminhos (server dir, jar, whitelist, logs, properties) e validação.
  - `whitelist_manager.py`: CRUD direto no `whitelist.json`.
  - `cron_manager.py`, `resource_monitor.py`, `admin_manager.py`, `breakpoint_manager.py`: automações e monitoramento.
- `functions/`
  - utilitários de validação e detecção de sistema operacional.
- `cli/` e `gui/`
  - duas interfaces sobre os mesmos managers.
- `main.py`
  - bootstrap, checagem de dependências, inicialização dos managers e escolha de interface.

## Como o zController manipula o servidor
### Processo
- Usa `subprocess.Popen` com:
  - `stdin` para comandos
  - `stdout`/`stderr` (stderr redirecionado para stdout)
  - `cwd` no diretório do servidor
- No Windows usa `CREATE_NO_WINDOW`.

### Threads e monitoramento
- Thread de leitura contínua do output (`_read_output`).
- Thread de monitoramento do processo (`_monitor_process`) para detectar encerramento inesperado.
- Em crash:
  - marca status
  - loga saída
  - se `auto_restart_on_crash` estiver ativo, aguarda delay e reinicia.

### Comandos
- `send_command()` escreve no `stdin`.
- `stop()` envia `stop` e aguarda encerramento gracioso, com fallback para terminate/kill.

### Parsing de eventos
- Detecta:
  - `joined the game`
  - `left the game`
- Mantém set de jogadores online.

## Configuração e persistência no zController
- Fonte principal: `config.json`.
- Chaves principais:
  - `server_dir`, `jar_file`, `java_path`
  - `min_ram_gb`, `max_ram_gb`
  - `java_args_extra`, `additional_args`
  - `auto_restart_on_crash`, `restart_delay_seconds`
  - `whitelist_path`, `log_file`, `server_properties_path`
- Resolve caminhos absolutos a partir de `server_dir`.

## Whitelist no zController
- Gerencia arquivo `whitelist.json` diretamente.
- Operações:
  - listar
  - adicionar (com validação)
  - remover
  - verificar expiração (quando aplicável)

## Mapeamento recomendado para o server_controll (Flutter)
### Equivalências
- `ServerManager` (Python) -> `modules/server/services/server_process_service.dart` + providers Riverpod.
- `ConfigManager` -> `modules/config/providers/config_files_provider.dart` + SQLite (`app_settings`).
- `WhitelistManager` -> `modules/whitelist/services/whitelist_sync_service.dart` + repository SQLite.

### Regras arquiteturais mantidas
- UI não chama processo diretamente.
- Toda operação de processo passa por service/provider.
- Estado reativo via Riverpod.
- Persistência local em SQLite.

## Diferenças desejadas no Flutter (melhoria em relação ao Python)
- Layout padrão único (`DefaultLayout`) com design system consistente.
- Componentes reutilizáveis (buttons, inputs, select, modal, switch card).
- Estados visuais e validações mais claras na UI.
- Separação modular por domínio (`home`, `console`, `whitelist`, `config`, `server`).

## Checklist de referência funcional
- Start/stop/restart de servidor local.
- Envio de comandos em tempo real.
- Console com logs contínuos.
- Detecção de online players.
- Auto-restart opcional em crash.
- Configuração persistente (path/java/jar/ram/args).
- Whitelist sincronizada com `whitelist.json`.

## Observação
Este arquivo é um resumo técnico de referência do projeto Python para orientar a evolução do app Flutter.
