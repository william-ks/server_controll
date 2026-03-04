# Documentação principal

Este arquivo é a ponte oficial de contexto do projeto.

A fonte principal funcional/técnica é:
- `docs/minecontrol_documentacao_v2.md`

Status da base implementada (Tasks 00-06):
- arquitetura modular em `lib/` com `components`, `layout`, `modules`, `database`, `routes`, `theme`, `providers`, `services` e `models`;
- design system inicial (cores, tipografia, tema, extension e styles);
- Riverpod sem codegen;
- SQLite desktop via `sqflite_common_ffi` com migrations (v1 base + v2 whitelist);
- `DefaultLayout` com Header + Sidebar;
- módulos funcionais iniciais: Home, Console e Whitelist;
- camada de processo do servidor com detecção de pronto por log `Done (...) For help, type`;
- console em tempo real com envio de comando por Enter e botão;
- whitelist com CRUD local, upload opcional de ícone e sincronização com `whitelist.json`.

Regra:
- qualquer mudança relevante de arquitetura, fluxo ou comportamento deve manter este arquivo e `docs/minecontrol_documentacao_v2.md` sincronizados.
