# TASK 09 - Sistema de Banimento de Jogadores

## Contexto atual no projeto
- Nao existe modulo de banimento no app atual.
- O runtime ja permite enviar comandos ao servidor e reagir a eventos de log.
- O dominio de players/permissoes ainda precisa ser consolidado (Task 08).
- A UI atual nao possui secao de banidos nem historico de ban/unban.

## Como implementar
- Modelo de dados:
  - Criar tabela `player_bans` com campos:
    - `player_id`, `reason`, `starts_at`, `expires_at`, `is_active`, `created_by`, `removed_by`, `removed_at`.
  - Registrar historico de alteracoes em tabela administrativa/auditoria.
- Integracao com servidor:
  - Ampliar `MinecraftCommandProvider` para comandos:
    - `ban <player> [reason]`
    - `pardon <player>`
  - Ban temporario:
    - aplicar `ban` normal;
    - manter expiracao no banco;
    - ao expirar, executar `pardon` automatico.
- Scheduler de expiracao:
  - Reusar loop periodico (ou novo timer dedicado) para detectar bans expirados.
  - Se servidor offline, manter estado pendente para aplicar `pardon` no proximo online.
- UI:
  - Em Players, criar secao de banidos com lista e filtros.
  - Modal de ban com selecao de player, motivo e duracao opcional.
  - Exibir identificacao amigavel (nickname/avatar/UUID quando disponivel).
- Historico:
  - Registrar ban/unban com quem executou, quando, motivo e resultado.

## Como verificar
- [ ] Aplicar ban permanente e confirmar bloqueio de entrada no servidor.
- [ ] Aplicar ban temporario e validar expiracao automatica com unban.
- [ ] Validar estado pendente de expiracao quando servidor estiver offline.
- [ ] Executar desbanimento manual e confirmar sincronizacao local + servidor.
- [ ] Confirmar exibicao de lista de banidos e historico completo na UI.
- [ ] Garantir que banimentos invalidos sem player resolvido sejam bloqueados.

## Dependencias e ordem sugerida
- Depende da consolidacao do dominio de players (Task 08).
- Implementar primeiro camada de dados e comandos.
- Depois scheduler de expiracao.
- Por ultimo UI e historico operacional.

## Definicao de concluido
- O app suporta ban permanente e temporario com sincronizacao ao servidor.
- Expiracoes sao tratadas automaticamente com rastreabilidade.
- Existe gestao administrativa de banidos integrada a area de Players.

