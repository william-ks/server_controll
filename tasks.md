# CONJUNTO CONSOLIDADO DE TASKS — Aplicativo de Controle de Servidor Minecraft Local

> Escopo consolidado a partir da documentação existente, do estado já implementado informado por você e das decisões fechadas na conversa.
>
> Observações de escopo:
> - As antigas tasks de **backup em nuvem**, **edição genérica de configs de mods**, **telas específicas para mods** e **gerador dinâmico de formulários** foram removidas.
> - O escopo final foi reorganizado em **15 tasks consolidadas**.
> - Sempre que o servidor enviar mensagens no chat para players, usar o padrão:
>   **`[SERVER 🤖]`**
> - O sistema continua compatível com **Windows** e **Linux**, mantendo providers/comandos específicos por plataforma.
> - Futuro suporte a macOS não entra neste escopo.

---

## TASK 1 — Categorização de Tempo de Jogo dos Players

### Objetivo
Implementar um sistema confiável de rastreamento de tempo de jogo por jogador, com histórico de sessões, métricas agregadas e maior resiliência a inconsistências causadas por fechamento abrupto do app, kicks e reinícios do servidor.

### Regras de negócio
- A base principal do cálculo será:
  - evento de entrada do player no servidor
  - evento de saída do player do servidor
- O sistema deve complementar isso com um **tick global do app/servidor**, executado periodicamente, para:
  - consultar players online
  - reconciliar sessões abertas
  - detectar inconsistências entre log e estado real
  - atualizar presença online no app
  - apoiar melhor cenários de kick, restart e stop
- Sessões interrompidas por fechamento inesperado do app não devem ser descartadas:
  - devem ser marcadas como **sessão incompleta**
  - com registro do último estado conhecido
- O sistema deve considerar também:
  - saída normal
  - kick
  - restart do servidor
  - stop do servidor
- Antes de restart/stop com players online:
  - o sistema deve alertar o operador
  - e garantir persistência do estado das sessões
- Períodos de agregação:
  - diário por calendário local
  - semanal por calendário local
  - total acumulado
- Deve existir:
  - estatística por player
  - ranking geral
  - histórico completo de sessões

### Estrutura esperada
- Tabela de players
- Tabela de sessões de jogo
- Tabela/visão de agregados
- Flags de consistência:
  - sessão aberta
  - sessão incompleta
  - última presença conhecida

### Requisitos técnicos
- Implementar um **tick global configurável**
- Valor inicial sugerido:
  - 5 segundos
- Esse tick deve ser desenhado para futura expansão
- A frequência de execução deve ser facilmente configurável por código e, futuramente, por tela de configuração
- O sistema deve evitar sobrecarga desnecessária do dispositivo e do servidor

### Output esperado
- Histórico completo de sessões por player
- Tempo diário, semanal e total
- Ranking de players por tempo
- Estado online/offline mais consistente
- Tratamento de sessões incompletas

---

## TASK 2 — Modo de Manutenção do Servidor

### Objetivo
Criar um modo de manutenção controlado pelo app, com suporte a personalização visual, timer opcional, mensagens automáticas e regras diferentes de acesso.

### Modos suportados
- **Modo manutenção total**
  - ninguém entra
  - players online podem ser removidos após contagem regressiva
- **Modo manutenção apenas admins**
  - somente **admins do app** podem entrar
  - OP isoladamente não define esse acesso; a regra usa admin do app

### Regras de negócio
- Implementação via app, sem dependência de plugin/mod de autenticação
- O controle será feito por:
  - lógica do app
  - hooks/eventos do servidor
  - comandos de kick quando necessário
- Deve haver tela/modal de ativação com:
  - escolha do modo
  - ativação imediata ou com atraso
  - configuração de timer
- Durante a contagem regressiva:
  - enviar mensagens automáticas no chat
  - usar marcos padrão:
    - 60s
    - 30s
    - 10s
- Ao ativar manutenção:
  - alterar MOTD
  - alterar imagem/fav icon do servidor conforme configuração
  - atualizar status visual do app
- Ao desativar manutenção:
  - restaurar automaticamente:
    - MOTD anterior
    - imagem/fav icon anterior
    - estado visual anterior salvo

### Configurações necessárias
Criar uma área de configuração do modo manutenção contendo:
- imagem do servidor para manutenção
- descrição/MOTD para manutenção total
- descrição/MOTD para manutenção apenas admins
- parâmetros de timer padrão, se aplicável

### Output esperado
- Servidor entra e sai de manutenção pelo app
- Bloqueio de entrada conforme modo selecionado
- Kick automático quando aplicável
- Mensagens de contagem regressiva no chat
- Personalização visual restaurável

---

## TASK 3 — Proteção Durante Geração de Chunks

### Objetivo
Reaproveitar a infraestrutura do modo de manutenção para proteger o servidor durante processos pesados de geração de chunks, especialmente no fluxo do Chunky.

### Regras de negócio
- A proteção é **opcional**, escolhida no momento em que a geração do Chunky for iniciada
- Opções de proteção:
  - bloquear todos
  - permitir apenas admins do app
- A proteção deve usar a mesma base lógica do modo manutenção
- Durante todo o processo de geração:
  - a proteção escolhida deve permanecer ativa
- Se houver restart entre execuções do fluxo de chunk:
  - a proteção deve continuar ativa
  - sem depender de nova ação manual

### Requisitos de interface
Ao iniciar uma geração de chunks, o app deve perguntar:
- se deseja ativar proteção
- qual tipo de proteção deseja aplicar

### Output esperado
- Geração de chunks com controle de entrada de players
- Proteção persistente entre etapas do fluxo
- Reuso da mesma infraestrutura de manutenção

---

## TASK 4 — Política de Backup do Servidor (Retenção, Tipos e Alertas)

### Objetivo
Evoluir o sistema de backup do servidor para suportar tipos distintos de backup, retenção por espaço em disco e alertas de capacidade.

### Tipos de backup do servidor
- **Backup completo**
  - compacta toda a raiz do servidor
- **Backup de mundo**
  - usa o valor de `level-name` do `server.properties`
  - localiza a pasta correspondente na raiz do servidor
  - faz backup dessa pasta do mundo
- **Backup seletivo**
  - definido em task própria

### Formato
- Padrão único:
  - **ZIP**
- Deve ser cross-platform
- Mesmo no Linux, manter ZIP como padrão atual

### Política de retenção
- Não usar limite por quantidade
- Usar limite por **espaço ocupado**
- `0 GB` = ilimitado
- A limpeza deve considerar a **data embutida na nomenclatura**
- A nomenclatura dos backups deve carregar tags úteis, por exemplo:
  - manual
  - agendado
  - chunk
  - full
  - world
  - selective

### Limpeza automática
- Deve existir opção de:
  - limpeza automática ativada
  - limpeza automática desativada
- Se a limpeza automática estiver desativada e houver limite configurado:
  - o sistema não apaga nada
  - apenas gera alertas

### Sistema de alertas/notificações
Criar uma área de alertas/notificações para avisar quando:
- o uso estiver próximo do limite
- o limite tiver sido atingido
- o limite tiver sido ultrapassado

### Output esperado
- Backups classificados por tipo e origem
- Retenção por espaço
- Limpeza automática opcional
- Alertas visuais de capacidade

---

## TASK 5 — Backup Manual Seletivo

### Objetivo
Permitir backup manual apenas de arquivos e pastas escolhidos na raiz do servidor, com interface adequada para seleção múltipla.

### Regras de seleção
- A seleção ocorre a partir da **raiz do servidor**
- O usuário pode selecionar:
  - pastas da raiz
  - arquivos soltos da raiz
- Ao selecionar uma pasta:
  - incluir automaticamente todo o conteúdo interno
- Deve ser possível marcar ao mesmo tempo:
  - uma ou mais pastas
  - um ou mais arquivos da raiz
- Não será permitido:
  - entrar em subníveis para escolher arquivo isolado dentro de pasta
  - exemplo: pode selecionar `config/`, mas não um arquivo específico dentro de `config/`

### Interface
- Implementar visualização em **árvore**
- Permitir múltipla seleção
- Exibir de forma clara o que está sendo incluído

### Histórico
- O histórico deve registrar:
  - que foi feito um backup seletivo
  - data e hora
  - descrição textual resumida com os diretórios/arquivos raiz selecionados
- Não precisa listar cada arquivo interno contido nas pastas

### Output esperado
- Backup ZIP contendo apenas os itens escolhidos da raiz
- Histórico com descrição resumida do backup seletivo

---

## TASK 6 — Sistema de Restauração de Backup do Servidor

### Objetivo
Permitir restauração segura de backups de mundo ou do servidor completo, sempre preservando o estado atual antes da sobrescrita.

### Regras de negócio
- A restauração só pode ocorrer com o servidor parado
- Antes de qualquer restauração:
  - gerar obrigatoriamente um backup completo de segurança do estado atual
- Tipos de restauração:
  - **Restauração de mundo**
    - sobrescreve apenas a pasta do mundo
    - preserva o restante do servidor
  - **Restauração completa**
    - sobrescreve toda a estrutura do servidor

### Segurança e UX
- Deve haver alertas explícitos sobre:
  - o que será sobrescrito
  - o impacto da operação
- O botão pode ficar desabilitado quando não for permitido restaurar
- Mesmo assim, manter validações defensivas na execução
- Se houver players ativos:
  - impedir restauração
  - exigir parada correta do servidor primeiro

### Pós-restauração
- Ao final, perguntar ao usuário:
  - se deseja iniciar o servidor
  - ou manter desligado

### Validações
- Não é necessário implementar validação avançada de compatibilidade do backup neste escopo

### Output esperado
- Restauração segura
- Backup de segurança obrigatório
- Confirmações claras de sobrescrita
- Possibilidade de iniciar ou não o servidor ao final

---

## TASK 7 — Gerenciamento de Permissões: Player, Admin do App e OP

### Objetivo
Separar corretamente os conceitos de player, admin do app e OP do Minecraft, permitindo combinações válidas e regras claras entre eles.

### Modelo final
O player pode ser:
- apenas player
- player + whitelist
- player + admin do app
- player + OP
- player + banido
- ou combinações válidas

### Regra obrigatória
- **Todo OP precisa ser admin do app**
- **Nem todo admin do app precisa ser OP**

### Conceitos
- **Admin do app**
  - controla ações administrativas do sistema
  - pode usar hook de chat administrativo
  - pode operar funcionalidades do app
- **OP**
  - privilégio nativo do Minecraft
  - representa poder dentro do servidor/jogo
- **Whitelist**
  - depende da configuração do servidor
  - mesmo quando desativada no servidor, a sincronização pode continuar existindo
- **Ban**
  - status separado

### Requisitos técnicos
- Persistir estados no banco
- Sincronizar também com os mecanismos/arquivos do servidor quando aplicável
- Suportar adição de admin offline como pendente
- Suportar OP offline respeitando a regra:
  - só pode virar OP se já for admin do app

### Output esperado
- Separação consistente entre admin do app e OP
- Regras de integridade preservadas
- Base pronta para permissões futuras

---

## TASK 8 — Refatoração do Sistema de Players, Whitelist e Histórico

### Objetivo
Reestruturar o domínio de players para preservar histórico e evitar perda de dados ao mudar whitelist, UUID, permissões ou status.

### Regras de negócio
- Nunca excluir o registro principal do player apenas por mudança de whitelist
- Ao remover da whitelist:
  - o player continua existindo no banco
  - o histórico é preservado
- Um player pode existir sem UUID
- Quando o UUID for descoberto depois:
  - o sistema deve tentar associar corretamente
- Em caso de conflito de identificação:
  - exigir validação manual
  - o operador escolhe qual registro manter
  - não permitir duplicidade inválida com o mesmo UUID

### Estrutura de domínio recomendada
Separar conceitualmente:
- player base
- status de whitelist
- status de admin do app
- status de OP
- status de banimento
- histórico de sessões
- histórico administrativo

### Interface
Criar uma **tela única de Players** com navegação horizontal interna, contendo abas/subseções como:
- todos
- whitelist
- admins
- OPs
- banidos
- histórico

### Output esperado
- Histórico preservado
- Menos risco de perda de dados
- Tela centralizada de gestão de players
- Conciliação futura de UUID mais robusta

---

## TASK 9 — Sistema de Banimento de Jogadores

### Objetivo
Implementar banimento permanente e temporário usando os mecanismos oficiais do servidor, com integração ao banco local e interface administrativa.

### Regras de negócio
- O banimento será aplicado pelo mecanismo oficial do servidor
- Suportar:
  - ban permanente
  - ban temporário
- O fluxo será centrado em **jogador**
  - usando nickname/UUID associados internamente
- Expiração de ban temporário:
  - remoção automática quando expirar
  - podendo haver estado pendente até sincronização/execução, se necessário

### Interface
- Criar seção de banidos dentro da área de players
- Ao banir:
  - abrir modal
  - permitir selecionar player
  - permitir informar motivo
  - permitir duração opcional
- Exibir player com identificação visual amigável, como:
  - avatar/foto
  - nickname
  - demais dados relevantes

### Histórico
Registrar:
- quem foi banido
- quando
- por quem
- motivo
- duração
- data de expiração, quando houver
- ação de desbanimento, quando houver

### Output esperado
- Banimento funcional e sincronizado
- Suporte a temporário e permanente
- Tela/lista de banidos com histórico

---

## TASK 10 — Expansão da Tela de `server.properties`

### Objetivo
Ampliar significativamente a edição de `server.properties` no app, tornando-a mais completa, amigável e explicativa.

### Escopo
- Expor **quase todos os campos relevantes** do `server.properties`
- Organizar em interface adequada
- Cada campo deve ter:
  - nome amigável
  - hint/descrição
  - explicação do impacto no jogo/servidor quando necessário

### Regras de UX
- A tela precisa ser confortável para edição
- Os agrupamentos devem facilitar entendimento
- Campos booleanos, numéricos e textuais devem usar inputs apropriados
- Onde fizer sentido, validar tipo e faixa de valor
- Deve ficar claro o que é alterado no comportamento do servidor

### Requisitos técnicos
- Continuar usando o arquivo real como fonte
- Manter compatibilidade com a lógica atual do sistema
- Preparar a estrutura para expansão futura

### Output esperado
- Tela robusta de edição de `server.properties`
- Melhor legibilidade
- Menos edição manual em arquivo texto

---

## TASK 11 — Backup dos Dados do Aplicativo

### Objetivo
Criar um sistema separado de backup do próprio aplicativo, cobrindo o banco de dados e demais dados internos do sistema.

### Escopo do backup do app
- arquivo de database
- histórico interno
- players
- permissões
- configs do app
- estado interno geral necessário para restauração

### Regras de negócio
- Este backup é **separado** do backup do servidor/jogo
- Não entra na regra de limite por GB dos backups do servidor
- Deve suportar:
  - backup manual
  - backup automático
  - exportação
  - importação
  - restauração

### Observações
- Exportação pode ser do conjunto completo
- O foco aqui é preservar o estado do app e não os arquivos do servidor Minecraft

### Output esperado
- Backups independentes do app
- Restauração do ambiente administrativo do sistema
- Fluxo de export/import funcional

---

## TASK 12 — Fluxo de Backup Automático

### Objetivo
Expandir o backup automático já existente para cobrir mais cenários, mais tipos de backup, retries e melhor integração com o ciclo de vida do servidor.

### Base existente
- Já há agendamento com cron
- Já há fluxo automático funcionando para backup completo

### Escopo novo
Passar a suportar automaticamente:
- backup completo
- backup de mundo
- backup seletivo
- backup do app

### Regras operacionais
- Sempre que a operação envolver backup com fluxo de servidor:
  - usar `save-all`
  - depois parar/iniciar conforme o caso
- Fluxos:
  - **Iniciar servidor**
    - fazer backup antes de iniciar
  - **Desligar servidor**
    - desligar
    - fazer backup
  - **Reiniciar servidor**
    - desligar
    - fazer backup
    - iniciar novamente
- Quando houver players online e a ação exigir parada:
  - usar o fluxo de aviso já existente
  - manter mensagens periódicas no chat
  - reiniciar/parar apenas ao fim da contagem

### Retry
- Em falha de backup automático:
  - registrar no histórico/log
  - notificar visualmente no app
  - tentar novamente
- Limite:
  - até 3 tentativas

### Output esperado
- Backup automático mais completo
- Integração segura com lifecycle do servidor
- Reaproveitamento do agendamento já existente

---

## TASK 13 — Hook de Chat para Comandos do Servidor

### Objetivo
Criar uma infraestrutura extensível de comandos administrativos disparados pelo chat do Minecraft.

### Sintaxe
O hook deve ser ativado quando a mensagem começar com:
- **`<server>`**

Exemplos:
- `<server> help`
- `<server> restart`
- `<server> status`
- comandos futuros com argumentos

### Regras de parsing
- O prefixo deve ser literal
- O parser deve ser **case-insensitive**
- Deve suportar argumentos no futuro
  - exemplo: `<server> backup full`

### Permissões
- O hook usa **admin do app**, não OP
- Cada comando deve definir sua própria permissão
- Pode haver:
  - comandos para qualquer player
  - comandos apenas para admins do app

### Estrutura esperada
Criar uma base extensível com:
- parser
- registry de comandos
- contexto do player
- retorno padronizado
- controle de permissão por comando
- suporte futuro a argumentos
- facilidade para adicionar/remover comandos

### Comandos iniciais
Não é obrigatório entregar todos agora, mas a estrutura deve suportar já de forma clara:
- `help`
- `restart`
- `status`
- outros futuros

### Help
- O comando `help` deve retornar apenas os comandos visíveis/permitidos para o player que executou

### Resposta
As respostas devem ser enviadas em:
- chat do Minecraft
- console do app
- ambos, quando aplicável

### Histórico específico do hook
Registrar:
- player
- comando bruto
- comando interpretado
- resultado
- horário
- permissão usada

### Output esperado
- Infraestrutura de comandos via chat
- Permissões separadas de OP
- Base pronta para expansão futura

---

## TASK 14 — Auditoria e Histórico do Sistema

### Objetivo
Criar um módulo central de auditoria/histórico para rastrear ações do sistema, operadores, comandos, alterações e eventos relevantes.

### Eventos que devem ser registrados
- ações administrativas
- execução de backup
- falha de backup
- restauração
- mudanças de configuração
- alterações em whitelist
- alterações em admin do app
- alterações em OP
- banimentos e desbanimentos
- comandos do hook
- updates do aplicativo
- início, parada e restart do servidor
- eventos relevantes do sistema

### Requisitos
- Deve haver filtros, quando possível, por:
  - tipo
  - data
  - player
  - ação
- A retenção, neste escopo, será:
  - **guardar tudo**
- O histórico deve servir tanto para auditoria quanto para depuração operacional

### Output esperado
- Tela/lista de histórico centralizado
- Melhor rastreabilidade do sistema
- Base para suporte e troubleshooting

---

## TASK 15 — Ajustes de UI e UX Estruturais

### Objetivo
Corrigir problemas de usabilidade já identificados e padronizar comportamentos importantes da interface.

### 15.1 Botões fixos de Salvar/Cancelar nas telas de configuração
#### Objetivo
Evitar que o usuário precise rolar até o fim da página para salvar alterações.

#### Regras
- Em todas as telas de configuração:
  - abaixo da navegação horizontal superior
  - exibir uma área fixa/flutuante com:
    - Salvar
    - Cancelar
- Essa área deve acompanhar o scroll
- Isso deve virar padrão para telas atuais e futuras de configuração

### 15.2 Correção de scroll/layout na tela de whitelist
#### Objetivo
Corrigir o comportamento de scroll, especialmente no Linux, onde cards estão vazando da box/container.

#### Regras
- Revisar:
  - overflow
  - altura dos containers
  - hierarquia do container rolável
  - comportamento de cards internos
- Verificar se o problema também afeta outras telas e/ou Windows

### 15.3 Padronização visual e operacional
#### Objetivo
Aproveitar as revisões para manter consistência entre telas com:
- sidebar principal
- menu horizontal interno
- cards agrupadores
- áreas de ação fixas quando necessário

### Output esperado
- Melhor experiência de edição
- Scroll corrigido
- Menos risco de ações escondidas
- Estrutura visual mais consistente

---

# REGRAS GLOBAIS DE IMPLEMENTAÇÃO

## 1. Mensagens no chat do servidor
Sempre que o app enviar mensagem para players no chat, usar:
- **`[SERVER 🤖]`**

## 2. Compatibilidade
- Manter compatibilidade com:
  - Windows
  - Linux
- Respeitar providers/comandos específicos por plataforma já existentes

## 3. Filosofia de sincronização
Sempre que possível:
- preservar histórico
- evitar exclusão destrutiva
- sincronizar com o servidor e também refletir no banco local
- usar estados pendentes quando necessário para operações offline

## 4. Integridade de dados
- Não permitir duplicidade inválida de UUID
- Tratar conflitos com validação manual
- Preservar rastreabilidade administrativa

## 5. Expansibilidade
As estruturas criadas agora devem facilitar adição futura de:
- novos comandos de hook
- novos eventos de auditoria
- novos tipos de backup
- novos campos/configurações
- novas regras de permissão

---

# RESUMO FINAL DE ESCOPO

## Módulos principais contemplados
- Players e tempo de jogo
- Manutenção e proteção operacional
- Backup/restauração do servidor
- Backup do aplicativo
- Permissões separadas entre admin do app e OP
- Banimento
- Expansão do `server.properties`
- Hook de chat administrativo
- Auditoria e histórico
- Ajustes estruturais de UI

## Módulos removidos deste ciclo
- Backup em nuvem
- Editor genérico de configs de mods
- Telas específicas de mods
- Gerador dinâmico de formulários para configs
