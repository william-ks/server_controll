# TASK 05 - Backup Manual Seletivo

## Contexto atual no projeto
- O backup manual hoje e somente completo, disparado na Home e executado pelo `BackupService`.
- A tela de backups lista e exclui arquivos ZIP, mas nao existe fluxo de selecao de itens da raiz.
- Nao existe historico textual de itens selecionados em backup seletivo.

## Como implementar
- Servico:
  - Adicionar metodo `createSelectiveBackup` no `BackupService` recebendo lista de entradas da raiz (`files` e `dirs`).
  - Validar que cada item selecionado pertence ao primeiro nivel da raiz do servidor.
  - Para diretorios, incluir conteudo completo recursivo no ZIP.
- Modelo de historico:
  - Registrar no historico do backup:
    - `type = selective`
    - data/hora
    - resumo textual dos itens raiz selecionados (sem detalhar subarquivos).
  - Persistir resumo em metadata de banco/local para exibicao na UI.
- UI:
  - Criar modal em Home ou Backups para "Backup seletivo".
  - Listar arvore de primeiro nivel da raiz com selecao multipla por checkbox.
  - Exibir painel "Itens incluidos" com resumo antes de confirmar.
  - Bloquear confirmacao se nenhuma entrada estiver selecionada.
- Regras:
  - Nao permitir navegacao para selecionar arquivo interno de subpasta.
  - Permitir selecao mista: arquivos soltos + pastas.
- Integracao:
  - Reusar configuracao de pasta de backup e regras de validacao ja existentes.
  - Integrar com nomenclatura/tags definidas na Task 04.

## Como verificar
- [ ] Selecionar apenas arquivos da raiz e validar conteudo do ZIP.
- [ ] Selecionar apenas pasta(s) e validar inclusao recursiva interna.
- [ ] Selecionar combinacao de arquivo + pasta e validar ZIP final.
- [ ] Confirmar que selecao de subarquivo interno nao esta disponivel.
- [ ] Validar registro de historico com resumo textual da selecao.
- [ ] Confirmar bloqueio quando nenhuma entrada e selecionada.

## Dependencias e ordem sugerida
- Depende das definicoes de tipo/nome de backup da Task 04.
- Implementar primeiro metodo de servico e validacao de paths.
- Depois construir modal de selecao em arvore simplificada.
- Finalizar com exibicao de historico resumido na UI.

## Definicao de concluido
- O usuario cria backup ZIP seletivo com base em itens da raiz do servidor.
- O historico identifica claramente que foi backup seletivo e quais entradas raiz entraram.
- As restricoes de selecao (sem subnivel manual) estao respeitadas.

