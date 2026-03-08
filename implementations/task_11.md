# TASK 11 - Backup dos Dados do Aplicativo

## Contexto atual no projeto
- O backup atual cobre arquivos do servidor Minecraft, nao os dados internos do app.
- O banco local principal e `minecontrol.db` criado por [lib/database/app_database.dart](C:/Users/Usuario/Desktop/projeto/server_controll/lib/database/app_database.dart).
- Existem dados internos adicionais, como icones de whitelist em diretorio de suporte do app.
- Nao existe fluxo de exportacao/importacao/restauracao do estado administrativo do aplicativo.

## Como implementar
- Escopo do backup do app:
  - Incluir obrigatoriamente:
    - arquivo de banco (`minecontrol.db`);
    - assets internos persistidos (ex.: `whitelist_icons/`);
    - metadata de versao do app/schema.
- Servico dedicado:
  - Criar `app_backup_service` separado do `backup_service` de servidor.
  - Operacoes:
    - `createAppBackup(manual|auto)`
    - `exportAppBackup(filePath)`
    - `importAppBackup(filePath)`
    - `restoreAppBackup(backupFile)`
- Armazenamento/config:
  - Configuracao propria de pasta e agenda de backup do app.
  - Nao compartilhar limite de retencao por GB dos backups do servidor.
- Fluxo de restauracao:
  - Exigir confirmacao forte por ser sobrescrita de estado administrativo.
  - Fechar conexoes ativas de banco antes de restaurar arquivo.
  - Reabrir banco e recarregar providers apos restore.
- UI:
  - Nova secao "Backup do App" em Config/Backups ou modulo dedicado.
  - Lista de backups do app e acoes de exportar/importar/restaurar.

## Como verificar
- [ ] Gerar backup manual do app e validar presenca de DB + assets internos.
- [ ] Exportar backup do app para caminho externo e reimportar com sucesso.
- [ ] Restaurar backup do app e confirmar reidratacao de configuracoes/players/permissoes.
- [ ] Validar separacao total entre backup do app e backup do servidor.
- [ ] Confirmar que falhas de import/export exibem erro claro sem corromper estado atual.

## Dependencias e ordem sugerida
- Implementar servico separado primeiro.
- Depois configurar persistencia e UI.
- Integrar com agendamentos na Task 12.

## Definicao de concluido
- O app possui backup proprio, independente do backup do servidor.
- Exportacao, importacao e restauracao funcionam com seguranca.
- Estado administrativo completo pode ser recuperado apos restauracao.

