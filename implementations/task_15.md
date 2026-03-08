# TASK 15 - Ajustes de UI e UX Estruturais

## Contexto atual no projeto
- As telas de configuracao (`Files`, `Backup`, `Propriedades`) usam `SingleChildScrollView` e botoes de acao no fim do conteudo.
- Em cenarios de muito scroll, salvar/cancelar podem ficar fora de visao.
- Existe relato de problemas de overflow/scroll na whitelist, especialmente no Linux.
- O app ja possui padrao visual base com `DefaultLayout`, sidebar e tabs horizontais.

## Como implementar
- Barra fixa de acoes:
  - Criar componente reutilizavel `sticky_form_actions_bar` com botoes Salvar/Cancelar.
  - Posicionar abaixo do menu horizontal da pagina de configuracao, fixo durante scroll.
  - Aplicar em todas as telas de configuracao atuais e deixar padrao para futuras.
- Correcao de scroll na whitelist:
  - Revisar hierarquia de containers da [lib/modules/whitelist/pages/whitelist_page.dart](C:/Users/Usuario/Desktop/projeto/server_controll/lib/modules/whitelist/pages/whitelist_page.dart).
  - Ajustar `Expanded`, `ListView`, `clipBehavior`, `constraints` e `overflow` para evitar vazamento de cards.
  - Validar comportamento em Linux e Windows.
- Padronizacao estrutural:
  - Uniformizar espacamentos e comportamento de cards entre Home, Config, Whitelist e outras paginas.
  - Padronizar uso de areas de acao fixa quando ha formularios longos.
- Qualidade de experiencia:
  - Manter foco em navegacao continua sem esconder acoes principais.
  - Evitar regressao visual no design system existente.

## Como verificar
- [ ] Em cada aba de configuracao, rolar ate o fim e confirmar botoes sempre visiveis.
- [ ] Validar que Salvar/Cancelar continuam respeitando estado `dirty` e validacoes.
- [ ] Testar whitelist com muitos registros e confirmar ausencia de overflow/vazamento.
- [ ] Validar layout no Linux e no Windows com diferentes tamanhos de janela.
- [ ] Confirmar consistencia visual da estrutura (sidebar, tabs, cards, acoes).

## Dependencias e ordem sugerida
- Pode ser executada em paralelo com tasks funcionais.
- Implementar primeiro componente global de acoes fixas.
- Depois aplicar nas abas de configuracao.
- Finalizar com ajuste de scroll da whitelist e revisao visual transversal.

## Definicao de concluido
- Acoes Salvar/Cancelar ficam acessiveis sem exigir scroll ate o fim.
- Problemas de scroll da whitelist foram corrigidos de forma cross-platform.
- A interface fica mais consistente e previsivel para operacao diaria.

