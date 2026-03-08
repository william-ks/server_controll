# TASK 14 - Auditoria e Historico do Sistema

## Contexto atual no projeto
- O app possui logs locais pontuais (ex.: `chunky_logs`) e historicos isolados, mas nao um modulo central de auditoria.
- Eventos administrativos relevantes (backup, restore, permissao, hook, lifecycle) ainda nao estao unificados em uma trilha unica.
- A arquitetura atual com providers/services facilita instrumentacao transversal sem quebrar UI existente.

## Como implementar
- Modelo central:
  - Criar tabela `audit_events` com:
    - `event_type`
    - `entity_type` / `entity_id`
    - `actor_type` / `actor_id`
    - `payload_json`
    - `result_status`
    - `created_at`
  - Nao aplicar politica de limpeza nesta fase (guardar tudo).
- Catalogo de eventos:
  - Cobrir no minimo:
    - acoes administrativas;
    - backup sucesso/falha;
    - restauracao;
    - mudancas de configuracao;
    - whitelist/admin/op;
    - ban/unban;
    - comandos do hook;
    - updates do app;
    - start/stop/restart.
- API de auditoria:
  - Criar `audit_service.logEvent(...)` com contrato padrao.
  - Integrar chamadas em pontos criticos dos modulos existentes.
- UI:
  - Nova tela/lista de auditoria com filtros por:
    - tipo;
    - data;
    - player;
    - acao.
  - Exibir detalhes do payload quando selecionado.
- Observabilidade:
  - Garantir escrita de evento mesmo em falha operacional (com `result_status = error`).

## Como verificar
- [ ] Executar start/stop/restart e validar eventos registrados.
- [ ] Criar backup e forcar falha de backup para validar sucesso/falha no historico.
- [ ] Alterar configuracoes e confirmar rastreabilidade com actor/horario.
- [ ] Executar acoes de whitelist/admin/op/ban e validar registros.
- [ ] Executar comando do hook e confirmar entrada correspondente.
- [ ] Validar filtros por tipo/data/player/acao na UI de historico.

## Dependencias e ordem sugerida
- Pode iniciar em paralelo com outras tasks, mas ganha valor apos Task 07-13.
- Implementar primeiro schema + service central.
- Depois instrumentar modulos principais.
- Por fim criar UI de consulta com filtros.

## Definicao de concluido
- Existe trilha central unificada de auditoria para eventos criticos do sistema.
- A tela de historico permite filtragem operacional util para suporte e troubleshooting.
- Eventos de sucesso e falha estao igualmente rastreaveis.

