# TASK 04 - Politica de Backup do Servidor (Retencao, Tipos e Alertas)

## Contexto atual no projeto
- O backup atual gera ZIP da pasta inteira do servidor em [lib/modules/backup/services/backup_service.dart](C:/Users/Usuario/Desktop/projeto/server_controll/lib/modules/backup/services/backup_service.dart).
- Os tipos atuais sao inferidos por prefixo de nome (`Manual`, `Agendamento`, `Chunk`).
- Retencao atual e por quantidade maxima (`backup_max_count`), nao por espaco em disco.
- Ainda nao existe sistema de alertas de capacidade, limpeza opcional, nem diferenciacao funcional entre backup full/world/selective.

## Como implementar
- Modelo de configuracao:
  - Evoluir `BackupConfigSettings` para incluir:
    - `retentionMaxGb` (0 = ilimitado)
    - `autoCleanupEnabled`
    - `capacityWarnThresholdPercent` (ex.: 80)
  - Persistir novas chaves em `app_settings`.
- Tipos de backup:
  - `full`: zip de toda raiz do servidor.
  - `world`: ler `level-name` em `server.properties` e zipar apenas a pasta do mundo.
  - `selective`: implementar em Task 05 e registrar como tipo oficial aqui.
- Nomenclatura padrao:
  - Adotar formato que carregue tags de origem e tipo, exemplo:
    - `20260308_211530__manual__full.zip`
    - `20260308_211530__schedule__world.zip`
  - Manter parser de nome para classificar `trigger` e `kind`.
- Retencao por espaco:
  - Calcular ocupacao total da pasta de backup.
  - Quando exceder limite e `autoCleanupEnabled = true`, remover do mais antigo para o mais novo ate voltar ao limite.
  - Ordenacao deve priorizar timestamp embutido no nome; fallback para `modifiedAt`.
- Alertas:
  - Criar estado de alertas no provider de backup com niveis `warning`, `reached`, `exceeded`.
  - Exibir alertas em Config > Backup e na tela Backups.
  - Se limpeza automatica estiver desativada, apenas alertar (nao apagar).
- Compatibilidade:
  - Continuar usando ZIP em Windows e Linux.

## Como verificar
- [ ] Gerar backup full, world e selective e validar classificacao correta no historico.
- [ ] Configurar limite em GB e confirmar limpeza automatica por antiguidade quando ativada.
- [ ] Desativar limpeza automatica e confirmar que nada e apagado ao exceder limite.
- [ ] Confirmar exibicao de alertas de proximidade, limite atingido e limite excedido.
- [ ] Validar comportamento com `retentionMaxGb = 0` (sem limpeza por limite).
- [ ] Testar no Windows e Linux com mesmo formato ZIP.

## Dependencias e ordem sugerida
- Evoluir modelo/config de backup primeiro.
- Implementar servico de retencao por espaco depois.
- Integrar alertas na UI por ultimo.
- Esta task deve preceder Task 05 e Task 12.

## Definicao de concluido
- O sistema suporta tipos full/world/selective com nomenclatura padronizada.
- A retencao passa a ser por espaco em GB, com opcao de limpeza automatica.
- Alertas de capacidade estao visiveis e coerentes com o uso real de disco.

