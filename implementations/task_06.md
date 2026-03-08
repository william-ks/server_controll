# TASK 06 - Sistema de Restauracao de Backup do Servidor

## Contexto atual no projeto
- O app possui fluxo de criacao e listagem de backups, mas nao possui restauracao.
- O runtime ja controla estado online/offline e pode parar/iniciar servidor.
- Ja existe leitura de `server.properties`, incluindo `level-name`, via [lib/modules/config/services/server_properties_service.dart](C:/Users/Usuario/Desktop/projeto/server_controll/lib/modules/config/services/server_properties_service.dart).
- Nao ha etapa obrigatoria de backup de seguranca antes de sobrescrita.

## Como implementar
- Servico de restauracao:
  - Criar `backup_restore_service` com operacoes:
    - `restoreWorld(backupZipPath)`
    - `restoreFull(backupZipPath)`
  - Antes de qualquer restore: executar backup full de seguranca obrigatorio.
- Regras de seguranca:
  - Restauracao so permitida com servidor offline.
  - Se houver players ativos ou lifecycle nao offline, bloquear acao.
  - Usar validacoes defensivas no servico, mesmo que botao esteja desabilitado.
- Escopo de restore:
  - Mundo: substituir somente pasta `level-name`.
  - Completo: sobrescrever toda estrutura da raiz do servidor.
  - Usar pasta temporaria para extracao e validacao minima antes da copia final.
- UX:
  - Na tela Backups, adicionar acao "Restaurar".
  - Modal de confirmacao explicando impacto (sobrescrita).
  - Ao final perguntar: iniciar servidor agora ou manter desligado.
- Auditoria:
  - Registrar tentativa, sucesso e falha de restauracao (task 14 integrara modulo central).
- Compatibilidade:
  - Fluxo de descompactacao/copia deve funcionar em Windows e Linux.

## Como verificar
- [ ] Tentar restaurar com servidor online e confirmar bloqueio.
- [ ] Restaurar mundo com servidor offline e validar que apenas pasta do mundo foi alterada.
- [ ] Restaurar completo e validar sobrescrita total da raiz.
- [ ] Confirmar criacao obrigatoria de backup de seguranca antes de restaurar.
- [ ] Simular falha de restore e validar rollback seguro/erro claro ao operador.
- [ ] Validar prompt final para iniciar servidor ou manter offline.

## Dependencias e ordem sugerida
- Depende da base de backup madura (Task 04/05).
- Implementar primeiro servico com backup de seguranca obrigatorio.
- Depois integrar UI de confirmacao e escolha pos-restore.
- Registrar eventos para trilha de auditoria.

## Definicao de concluido
- Restauracao de mundo e completa funcionam com servidor parado.
- Sempre existe backup de seguranca antes da sobrescrita.
- Usuario recebe confirmacoes claras e escolha final de iniciar ou nao o servidor.

