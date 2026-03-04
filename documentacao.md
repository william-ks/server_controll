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

Regra:
- qualquer mudança relevante de arquitetura, fluxo ou comportamento deve manter este arquivo e `docs/minecontrol_documentacao_v2.md` sincronizados.
