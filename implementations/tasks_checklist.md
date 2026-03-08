# CHECKLIST CENTRAL DE TASKS

## Lista de tarefas
- [x] [Task 01 - Categorizacao de Tempo de Jogo dos Players](C:/Users/Usuario/Desktop/projeto/server_controll/implementations/task_01.md)
- [x] [Task 02 - Modo de Manutencao do Servidor](C:/Users/Usuario/Desktop/projeto/server_controll/implementations/task_02.md)
- [x] [Task 03 - Protecao Durante Geracao de Chunks](C:/Users/Usuario/Desktop/projeto/server_controll/implementations/task_03.md)
- [x] [Task 04 - Politica de Backup do Servidor](C:/Users/Usuario/Desktop/projeto/server_controll/implementations/task_04.md)
- [x] [Task 05 - Backup Manual Seletivo](C:/Users/Usuario/Desktop/projeto/server_controll/implementations/task_05.md)
- [x] [Task 06 - Sistema de Restauracao de Backup do Servidor](C:/Users/Usuario/Desktop/projeto/server_controll/implementations/task_06.md)
- [x] [Task 07 - Gerenciamento de Permissoes](C:/Users/Usuario/Desktop/projeto/server_controll/implementations/task_07.md)
- [x] [Task 08 - Refatoracao de Players/Whitelist/Historia](C:/Users/Usuario/Desktop/projeto/server_controll/implementations/task_08.md)
- [x] [Task 09 - Sistema de Banimento de Jogadores](C:/Users/Usuario/Desktop/projeto/server_controll/implementations/task_09.md)
- [x] [Task 10 - Expansao da Tela de server.properties](C:/Users/Usuario/Desktop/projeto/server_controll/implementations/task_10.md)
- [x] [Task 11 - Backup dos Dados do Aplicativo](C:/Users/Usuario/Desktop/projeto/server_controll/implementations/task_11.md)
- [x] [Task 12 - Fluxo de Backup Automatico](C:/Users/Usuario/Desktop/projeto/server_controll/implementations/task_12.md)
- [x] [Task 13 - Hook de Chat para Comandos do Servidor](C:/Users/Usuario/Desktop/projeto/server_controll/implementations/task_13.md)
- [x] [Task 14 - Auditoria e Historico do Sistema](C:/Users/Usuario/Desktop/projeto/server_controll/implementations/task_14.md)
- [ ] [Task 15 - Ajustes de UI e UX Estruturais](C:/Users/Usuario/Desktop/projeto/server_controll/implementations/task_15.md)

## Tutorial - como resolver 1 task
1. Abra a task correspondente (`task_XX.md`) e leia as 5 secoes obrigatorias.
2. Implemente o que esta em `Como implementar`, seguindo a ordem sugerida.
3. Execute todos os itens de `Como verificar` e ajuste o que falhar.
4. Confirme os criterios de `Definicao de concluido`.
5. Marque esta checklist trocando `[ ]` por `[x]` na task finalizada.
6. Registre o resultado com 1 commit exclusivo daquela task.

## Regra de commit por task (uso futuro)
- Esta etapa atual e somente de planejamento/documentacao: nao criar commit agora.
- Quando uma task for realmente implementada e validada, gerar exatamente 1 commit exclusivo para ela.
- Nao agrupar multiplas tasks no mesmo commit.
- Mensagem recomendada de commit por task concluida:
  - `feat(task_XX): concluir implementacao da task_XX`
  - Exemplo: `feat(task_03): concluir implementacao da task_03`

## Observacoes operacionais
- A ordem recomendada de execucao segue dependencias descritas em cada `task_XX.md`.
- Sempre respeitar regras globais do `tasks.md`, incluindo prefixo de chat `[SERVER 🤖]` e compatibilidade Windows/Linux.
