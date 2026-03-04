# Documentação principal

Este arquivo é a ponte oficial de contexto do projeto.

A fonte principal funcional/técnica é:
- `docs/minecontrol_documentacao_v2.md`

Status da base implementada:
- arquitetura modular em `lib/` com `components`, `layout`, `modules`, `database`, `config` e `models`;
- configurações globais centralizadas em `lib/config/`:
  - `config/routes/`
  - `config/theme/`
  - `config/providers/`
- app bootstrap com `lib/main.dart` + `lib/app.dart`;
- módulo de servidor em `lib/modules/server/` (providers + services);
- módulo de whitelist com `providers/repositories/services/subcomponents` dentro do próprio módulo;
- SQLite desktop via `sqflite_common_ffi` + `sqlite3_flutter_libs` para runtime nativo no Windows/Linux.
- aba `Config > Arquivos` implementada com formulário real:
  - persistência em `app_settings` para `server_dir`, `jar_file`, `java_command`, `jvm_args`, `xms`, `xmx`, `auto_restart_on_crash`, `restart_wait_seconds`;
  - validações de existência de path/arquivo com badges;
  - validações de RAM (`min <= max`) e tempo de restart;
  - `Salvar` habilitado apenas com alterações válidas (dirty state) e `Cancelar` exibido apenas quando houver edição.
- padronização global de input/select:
  - background ativo unificado para `focus/hover/preenchido` via tokens no tema (`inputFillNormal`/`inputFillActive`);
  - aplicado em campos padrão e selects para consistência visual em páginas e modais.
- whitelist refinada:
  - card único padronizado com avatar maior, UID em texto muted, badges consistentes e ações centralizadas;
  - regra de pendência normalizada a partir dos dados persistidos (UUID/estado adicionado) durante carregamento.

Regra:
- qualquer mudança relevante de arquitetura, fluxo ou comportamento deve manter este arquivo e `docs/minecontrol_documentacao_v2.md` sincronizados.
