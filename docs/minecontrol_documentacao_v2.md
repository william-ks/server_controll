# MineControl - Documentação do Projeto

## 1. Visão geral

**MineControl** é uma aplicação desktop desenvolvida em **Flutter** para gerenciamento local de servidores Minecraft, com foco inicial em **Windows** e suporte planejado para **Linux**.

O sistema foi projetado para centralizar a administração de um servidor **Fabric** em uma interface moderna, limpa e orientada a produtividade, evitando a necessidade de operar diretamente pelo terminal do sistema.

O objetivo principal do aplicativo é permitir que o usuário:

- inicie, pare, desligue e reinicie o servidor;
- acompanhe o console em tempo real;
- envie comandos ao servidor;
- gerencie configurações persistentes;
- edite propriedades importantes do `server.properties`;
- controle backups;
- gerencie whitelist e permissões administrativas;
- execute agendamentos automáticos;
- opere geração de chunks com fluxo automatizado e segmentado.

---

## 2. Stack e tecnologias

### Base técnica

- **Flutter** (desktop)
- **Riverpod 3** para gerenciamento de estado
- **SQLite** para persistência local
- Integração com execução de processos do sistema operacional
- Leitura e escrita de arquivos locais do servidor Minecraft

### Escopo atual

- Plataforma inicialmente considerada: **Windows**
- Suporte futuro: **Linux**

---

## 3. Objetivo funcional

O MineControl funciona como um painel de administração local do servidor Minecraft, permitindo operar o servidor e seus recursos sem depender de terminal externo.

A aplicação centraliza:

- ciclo de vida do processo Java do servidor;
- leitura e escrita de configurações;
- gerenciamento de backups;
- administração de whitelist e OP;
- automações por agendamento;
- pré-geração de chunks com Chunky.

### Status implementado nesta fase

- Módulo `Config` com aba `Arquivos` funcional:
  - formulário completo com seções `Arquivos`, `Comportamento` e `Ações`;
  - validação de path e arquivo `jar` com badges de status;
  - memória `xms/xmx` em GB com validação de limites;
  - persistência/recuperação de configurações no SQLite (`app_settings`);
  - estado de edição (`dirty state`) para habilitação de `Salvar` e exibição de `Cancelar`.
- Design System refinado:
  - inputs/selects com estado visual ativo consistente quando focado, em hover ou preenchido;
  - placeholders com token dedicado no `ThemeExtension` para melhor distinção de campos vazios;
  - novos tokens de texto auxiliar e sidebar no `ThemeExtension` para melhor legibilidade no tema claro.
- Whitelist revisada:
  - cards padronizados por subcomponente único com avatar maior, UUID em estilo muted e badges consistentes;
  - pendência normalizada com base no estado persistido no banco local.
- Configurações > Arquivos:
  - agrupamento por seções `Core` e `Memoria RAM`;
  - switch de comportamento padronizado por componente global de card (`AppSwitchCard`);
  - ações finais sem seção explícita e alinhadas à direita.

---

## 4. Layout geral da aplicação

## 4.1 Header

O topo da aplicação possui um header fixo com três áreas principais:

### Esquerda
- Ícone de **arrow right** para abrir a sidebar.
- Esse ícone só aparece quando a sidebar está fechada.

### Centro
- Título da aplicação: **MineControl**.

### Direita
- Botão de alternância de tema.
- Ícone de **lua/sol** para alternar entre tema dark e light.
- O tema padrão da aplicação é **dark**.

## 4.2 Sidebar

A sidebar:

- vem **aberta por padrão**;
- sobrepõe visualmente o header quando aberta;
- possui botão próprio de fechar;
- concentra a navegação lateral da aplicação;
- pode exibir a entrada da tela de Chunk apenas quando habilitada nas configurações.

## 4.3 Diretriz visual

A interface segue uma proposta de UX/UI:

- moderna;
- limpa;
- com foco em clareza operacional;
- adequada para administração contínua de servidor.

---

## 5. Navegação e rotas

O projeto possui um arquivo de rotas responsável por organizar a navegação entre as telas.

Telas principais mencionadas:

- Home
- Console
- Configurações
- Whitelist
- Chunk

> Observação: a estrutura final de rotas e nomes técnicos das pages pode ser refinada posteriormente na documentação de arquitetura.

---

## 6. Estados do servidor

A aplicação trabalha com estados operacionais explícitos do servidor:

- **offline**
- **iniciando**
- **online**
- **desligando**
- **reiniciando**

Esses estados controlam:

- exibição de status visual;
- disponibilidade de ações na interface;
- habilitação e desabilitação de botões;
- execução de rotinas dependentes do estado do servidor.

---


### 6.1 Detecção de “servidor pronto”

Para considerar o servidor **online/pronto para players**, a aplicação deve observar o **stdout** do processo Java (console embutido) e identificar a linha padrão do servidor Minecraft indicando finalização do boot.

Padrão mais comum:

- `Done (<tempo>s)! For help, type "help"`

Variações observadas:

- `Done (<tempo>s)! For help, type "help" or "?"`

A aplicação deve:
1. manter o estado como **iniciando** até detectar essa linha;
2. ao detectar, marcar como **online** e liberar as ações dependentes (ex.: whitelist/op);
3. considerar que o prefixo do log pode variar (ex.: `[Server thread/INFO]:`), então a detecção deve focar no trecho `Done (` + `For help, type`.

> Observação: durante o boot é comum aparecer `Preparing spawn area: <n>%` e outras mensagens, mas o ponto de transição para “pronto” é a linha do `Done (...)`.

## 7. Tela Home

A tela Home concentra as ações principais de operação do servidor.

### Ações disponíveis

- **Iniciar servidor**
- **Parar servidor**
- **Desligar servidor**
- **Reiniciar servidor**
- **Fazer backup**

### Regras gerais

- Os botões possuem regras condicionais de exibição e/ou habilitação de acordo com o estado atual do servidor.
- As ações executam operações diretamente sobre o processo do servidor e sobre os arquivos locais quando necessário.

### Backup manual

O backup manual consiste em:

- gerar um arquivo `.zip` da pasta inteira do servidor;
- salvar esse arquivo em uma pasta previamente definida pelo usuário.

### Gerenciamento de jogadores

A Home também oferece ações de desconexão de jogadores:

- desconectar **todos** os jogadores;
- desconectar **um** jogador específico;
- desconectar **vários** jogadores selecionados;
- definir uma **mensagem personalizada de desconexão**.

---

## 8. Tela Console

A tela de Console existe para eliminar a dependência de um terminal separado da aplicação.

### Objetivos da tela

- exibir a saída do servidor Java em tempo real;
- permitir observação contínua do log;
- permitir envio de comandos ao servidor;
- permitir copiar conteúdo do console;
- manter toda a operação dentro da própria aplicação.

### Requisito funcional

Ao iniciar o processo Java, o console deve ser incorporado ao fluxo da interface do MineControl, sem abrir um console externo separado.

---

## 9. Tela de Configurações

A tela de configurações é dividida em abas horizontais.

### Abas existentes

- Servidor
- Propriedades
- Backups
- Admin
- Agendamentos
- Chunk

> Breakpoints foram removidos do escopo atual.

---

## 10. Aba Servidor

Responsável pelas configurações principais de execução do servidor.

### Campos/configurações

- **Memória RAM mínima**
- **Memória RAM máxima**
- **Path da pasta do servidor**
- **Nome do arquivo do servidor**
- **Comando Java**
- **JVM Args**
- **Auto restart em caso de crash**
- **Tempo de espera para restart automático**

### Regras

#### Path do servidor
- Deve permitir seleção/definição da pasta do servidor.
- O sistema deve verificar se a pasta existe.

#### Nome do arquivo do servidor
- Identifica o arquivo executável do servidor dentro da pasta configurada.

#### Comando Java
- Define o comando usado para iniciar o Java no terminal.
- Exemplos:
  - `java`
  - `/usr/bin/java`

#### JVM Args
- Permite definir argumentos adicionais da JVM antes da execução do servidor.

#### Auto restart
- Quando ativado, reinicia o servidor automaticamente após crash.
- O restart respeita um tempo de espera configurável.

---

## 11. Aba Propriedades

Responsável por editar o arquivo `server.properties` localizado na pasta do servidor.

### Propriedades citadas como prioritárias

- `level-name`
- `motd`
- `max-players`
- `pvp`
- `whitelist`

### Objetivo

Permitir edição dos parâmetros mais importantes do servidor sem abrir manualmente o arquivo físico.

### Regras de persistência

- A edição deve refletir no arquivo físico `server.properties`.
- O sistema pode espelhar essas informações no banco local, mas o **arquivo físico é a fonte prioritária**.

---

## 12. Aba Backups

Responsável pelas configurações permanentes do sistema de backup.

### Campos/configurações

- **Switch para habilitar/desabilitar backup**
- **Pasta de backups**
- **Máximo de backups armazenados**

### Regras

#### Pasta de backups
- Deve validar se a pasta existe.

#### Máximo de backups
- O sistema mantém apenas a quantidade máxima configurada.
- Ao criar um novo backup acima do limite, o backup mais antigo deve ser removido.

### Exemplo

Se o limite for `5`:

- backups 1, 2, 3, 4 e 5 existem;
- ao gerar o backup 6;
- o backup mais antigo é deletado;
- permanecem apenas os 5 mais recentes.

---

## 13. Aba Admin

Responsável por gerenciar permissões administrativas (OP) dos jogadores.

### Origem dos dados

A tela utiliza jogadores:

- presentes na whitelist;
- e também registrados no banco de dados local.

### Ações disponíveis

- dar **OP** a um jogador;
- remover **OP** de um jogador.

### Regra crítica

Essas operações só podem ser executadas quando o servidor estiver **online**.

### Persistência

Quase tudo no sistema pode existir:

- no banco de dados local;
- e também nos arquivos físicos do servidor.

Contudo, a regra principal é:

> **Os arquivos físicos têm prioridade sobre o banco e podem sobrescrever/reconstruir os dados persistidos no SQLite.**

---

## 14. Aba Agendamentos

Responsável por automações baseadas em cron.

### Finalidade

Permitir criar eventos programados para:

- iniciar o servidor;
- desligar o servidor;
- reiniciar o servidor;
- executar backup em conjunto com a operação.

### Motor de execução

- utiliza uma função baseada em **cron** para verificar e disparar eventos agendados.

### Regras de execução com backup

#### Quando a ação for reiniciar
Fluxo:
1. desliga o servidor;
2. executa backup;
3. inicia o servidor novamente.

#### Quando a ação for desligar
Fluxo:
1. desliga o servidor;
2. executa backup.

#### Quando a ação for iniciar
Fluxo:
1. executa backup antes;
2. inicia o servidor.

---

## 15. Aba Chunk (Configurações)

Responsável pelas configurações do recurso de pré-geração de chunks.

### Campos/configurações

- **Switch para habilitar a tela Chunk na sidebar**
- **Path relativo do Chunky**
- **Máximo de chunks gerados por vez**
- **Botão para apagar a pasta `tasks`**

### Valores padrão

- Path relativo padrão: `config/chunky`
- Máximo de geração por vez: `1000`

### Regra de remoção de tasks

Ao apagar as tasks, o sistema deve:

1. pegar o `serverPath`;
2. concatenar com o path relativo configurado do Chunky;
3. adicionar `/tasks`;
4. apagar essa pasta.

---

## 16. Tela Whitelist

Responsável pelo gerenciamento visual da whitelist de jogadores.

### Dados por jogador

- foto/avatar
- nickname
- ID/UUID

### Observações sobre os dados

- O **nickname** é obrigatório.
- O **ID/UUID** é opcional no cadastro inicial.

### Fluxo de cadastro

Quando um jogador é adicionado:

- ele fica marcado como **pendente**.

Quando o servidor inicia:

- o sistema executa uma rotina que tenta rodar o comando:

```text
whitelist add <nickname>
```

- essa rotina deve tratar falhas e registrar o resultado.

### Botão de refresh

A tela possui um botão de **refresh** para:

- reprocessar jogadores pendentes;
- tentar novamente a inclusão dos que ainda não foram efetivamente aplicados ao servidor.

### Regra funcional importante

O sistema aceita cadastro de jogadores mesmo offline, mas a aplicação real no servidor acontece quando o servidor estiver apto a processar o comando.

---

## 17. Tela Chunk

A tela Chunk implementa o fluxo de pré-geração de mundo usando o **Chunky**.

Esse é um dos módulos mais complexos do sistema.

### 17.1 Objetivo

Permitir configurar e executar a geração massiva de chunks do mapa, com controle de progresso, segmentação automática por limite e recuperação operacional.

### 17.2 Dados configuráveis pelo usuário

- coordenada **X** do centro
- coordenada **Z** do centro
- **raio**
- **pattern**
- **shape**

### 17.3 Fluxo base de execução

Antes da geração:

1. alterar o `server.properties` para definir `max-players = 0`;
   - antes de sobrescrever, ler o valor atual de `max-players` e persistir no **SQLite** (ex.: `chunk_previous_max_players`) para restauração ao final;
2. reiniciar o servidor;
3. executar `chunky center <x> <z>`;
4. executar `chunky radius <valor>`;
5. executar `chunky pattern <pattern>`;
6. executar `chunky shape <shape>`;
7. executar `chunky start`.

### 17.4 Segmentação por limite

O sistema não deve necessariamente gerar todo o raio em uma única etapa.

Ele compara:

- o **raio solicitado pelo usuário**;
- com o **máximo de chunks gerados por vez** configurado no sistema.

Se o valor solicitado for maior que o limite, a tarefa deve ser quebrada em etapas.

### Exemplo

Se:

- raio solicitado = `10000`
- limite por execução = `1000`

Então o sistema deve executar em lotes:

- 1000
- 2000
- 3000
- 4000
- 5000
- 6000
- 7000
- 8000
- 9000
- 10000

A cada etapa:

1. inicia a geração até o limite atual;
2. acompanha o progresso até 100%;
3. salva o mundo;
4. reinicia o servidor;
5. inicia a próxima etapa.

Ao concluir **todas** as etapas (100% do alvo):

1. restaurar `max-players` para o valor original salvo no SQLite;
2. reiniciar o servidor (para aplicar o `server.properties` restaurado);
3. liberar o estado de UI (voltar botões e telas ao modo normal).

### Exemplo com resto

Se:

- raio solicitado = `10500`
- limite = `1000`

O sistema executa:

- de 1000 em 1000 até 10000;
- e finaliza com uma etapa adicional de `500`.

### 17.5 Ações operacionais

A tela deve permitir:

- **atualizar** status da task;
- **cancelar** task;
- **continuar** task;
- **pausar** task.


#### Leitura de progresso

Quando o Chunky está rodando, o progresso pode ser obtido de duas formas:

1. **Parse do console**: o plugin imprime atualizações de progresso no stdout durante a execução.
2. **Comando `chunky progress`**: a UI deve ter um botão de **Atualizar**, que envia `chunky progress` ao servidor e atualiza o card/estado local com o resultado.

A tela Chunk deve preferir o comando `chunky progress` para o botão de atualização (fonte explícita), usando o parse do console como complemento para feedback em tempo real.

### 17.6 Integração com Chunky

#### Patterns conhecidos

Com base na documentação oficial do Chunky, os patterns disponíveis incluem:

- `region`
- `concentric`
- `loop`
- `spiral`
- `csv`
- `world`

#### Shapes conhecidos

Com base na documentação oficial do Chunky, os shapes disponíveis incluem:

- `square`
- `circle`
- `triangle`
- `diamond`
- `pentagon`
- `hexagon`
- `star`
- `rectangle`
- `ellipse`

**Nota sobre `chunky radius`:** o comando aceita **um ou dois valores**. O segundo valor é usado principalmente para `rectangle` e `ellipse` (ex.: raios diferentes em X/Z).

#### Observação importante sobre radius

O comando `chunky radius` aceita:

- um raio único, para formatos comuns;
- ou dois raios, quando a shape for `rectangle` ou `ellipse`.

---

## 18. Persistência e sincronização de dados

O sistema trabalha com duas camadas principais de persistência:

### Banco local
- SQLite

### Arquivos físicos
- `server.properties`
- arquivos do servidor Minecraft
- estrutura do Chunky
- demais arquivos locais relevantes

### Regra principal de precedência

Os **arquivos físicos do servidor** têm prioridade sobre o banco de dados.

Isso significa que:

- o banco pode servir como cache, espelho ou apoio operacional;
- mas o conteúdo real do servidor pode sobrescrever e reconstruir o estado persistido localmente.

---

## 19. Regras de negócio já definidas

### Servidor
- o servidor deve operar com estados explícitos;
- ações visuais dependem do estado atual.

### Backups
- backups são arquivos `.zip` da pasta inteira do servidor;
- existe retenção máxima configurável.

### Admin
- dar/remover OP exige servidor online.

### Whitelist
- jogadores podem ser cadastrados offline;
- a aplicação efetiva no servidor pode ocorrer posteriormente;
- jogadores recém-criados ficam em estado pendente.

### Chunk
- a tela do Chunk só aparece se estiver habilitada nas configurações;
- a geração pode ser quebrada em etapas com base no limite configurado;
- a pasta `tasks` pode ser apagada manualmente.

### Agendamentos
- podem acionar iniciar, desligar, reiniciar e backup em fluxos combinados.

---

## 20. Estrutura funcional resumida

### Núcleos do sistema


### Estrutura de pastas (Flutter)

Dentro de `lib/`, a organização segue estes grupos:

- `components/`  
  Componentes globais reutilizáveis (ex.: botões, inputs, cards, modal, etc.).

- `config/`  
  Configurações base do app.
  - `config/routes/`
    - `routes.dart` (definição de rotas; pode ser copiado/adaptado de outro projeto)
    - `routes_provider.dart` (Riverpod que expõe rota atual e permite navegação/atualização)

- `layouts/`  
  Layouts compartilhados (ex.: `DefaultLayout` com Header + Sidebar).

- `modules/`  
  Módulos funcionais (feature-first). Cada módulo pode ter 1+ páginas e seus próprios artefatos.
  Exemplo: `modules/home/`
  - `pages/` (telas do módulo)
  - `home_service.dart` (se necessário)
  - `home_provider.dart` (se necessário)
  - outros arquivos específicos do domínio do módulo (models, widgets locais, etc.)

Regra: o que for **global** vai para `components/`, e o que for **do domínio de uma feature** fica dentro do módulo correspondente em `modules/`.



1. **Gerenciamento do processo do servidor**
2. **Console incorporado**
3. **Gerenciamento de configurações**
4. **Manipulação de arquivos do servidor**
5. **Persistência local com SQLite**
6. **Whitelist e administração**
7. **Backups**
8. **Agendamentos**
9. **Pré-geração de chunks**

---

## 21. Pendências e pontos a confirmar

Os itens abaixo não estão indefinidos, mas ainda podem ser refinados na próxima etapa da documentação:

- nome técnico das rotas e pages;
- estrutura de pastas do projeto Flutter;
- entidades do banco SQLite;
- formato exato de armazenamento dos logs do console;
- estratégia de detecção de servidor "pronto para jogadores";
- estratégia de leitura do progresso do Chunky;
- política de restauração do `max-players` após terminar a geração de chunks;
- comportamento detalhado ao detectar crash durante geração por lotes.

---

## 22. Próximo passo recomendado

Na próxima etapa, esta documentação pode ser expandida para incluir:

1. modelagem do banco de dados;
2. providers Riverpod;
3. services e repositories;
4. fluxo completo de inicialização do servidor;
5. fluxos detalhados de whitelist e chunk;
6. checklist de implementação por feature.

---

## 23. Status de implementação (atualização em 04/03/2026)

### 23.1 Fundação concluída

Foi implementada a base técnica do app com:

- Riverpod sem codegen;
- SQLite desktop via `sqflite_common_ffi`;
- migrations versionadas;
- tema centralizado (`AppColors`, `AppTypography`, `AppThemeExtension`, `AppStyles`, `AppTheme`);
- rotas centralizadas (`lib/routes/routes_config.dart` e `lib/routes/app_router.dart`).

### 23.2 Banco e migrations implementados

- Migration v1:
  - `app_settings`
  - `schema_migrations`
- Migration v2:
  - `whitelist_players`

Tabela `whitelist_players`:

- `id`
- `nickname`
- `uuid`
- `icon_path`
- `is_pending`
- `is_added`
- `created_at`
- `updated_at`

### 23.3 Layout e navegação

- Implementado `DefaultLayout` com:
  - `AppHeader`
  - `AppSidebar`
- Páginas principais usando o layout:
  - Home
  - Console
  - Whitelist

### 23.4 Home (ciclo de vida do servidor)

- Estados implementados:
  - `offline`
  - `starting`
  - `online`
  - `stopping`
  - `restarting`
  - `error`
- Uptime inicia apenas após detectar a linha de pronto no stdout:
  - `Done (...) For help, type ...`
- Cards implementados:
  - Status
  - Uptime
  - Jogadores ativos
- Ações implementadas:
  - Iniciar
  - Desligar
  - Reiniciar
  - Backup (placeholder visual)

### 23.5 Console em tempo real

- Saída de logs em tempo real (server/system);
- envio de comando por Enter e botão de envio;
- comandos do usuário renderizados com origem visual distinta;
- modal de comandos rápidos com estrutura pronta;
- suporte a auto-scroll alternável.

### 23.6 Whitelist

- CRUD local completo de jogadores;
- upload opcional de ícone com cópia para diretório interno do app;
- normalização de nome de arquivo pelo nickname;
- fluxo de pendência:
  - com UUID: `is_added = true`, `is_pending = false`
  - sem UUID: `is_pending = true`
- sincronização com `whitelist.json`;
- tentativa de `whitelist add <nickname>` para pendentes quando servidor fica online;
- refresh manual e sincronização automática ao transicionar para online.

### 23.7 Observações de escopo atual

- Backup permanece como placeholder na Home;
- comandos rápidos no Console estão estruturados, com lista inicial simples;
- foco desta fase: base arquitetural e módulos Home/Console/Whitelist.

## 24. Ajustes de UI/UX (04/03/2026 - rodada 2)

- Persistência de tema corrigida:
  - tema inicial agora é carregado antes do `runApp`;
  - alternância funciona com um clique sem race condition.
- Sidebar:
  - animação de abertura/fechamento mais suave;
  - item ativo com mesmo destaque de hover primary + indicador lateral.
- Console:
  - fundo quase preto;
  - auto-scroll inteligente por posição do usuário (sem botão manual).
- Componentes base:
  - `AppModal` criado (Header/Body/Actions com ícone + título + fechar);
  - `AppButton` com estados visuais refinados e suporte a `text`, `icon` e `textIcon`.
- Home:
  - cards de Status/Uptime/Jogadores com ícones primary e menor excesso de cor.
- Whitelist:
  - box central com barra de pesquisa local;
  - filtro em tempo real por nickname/UUID.
- Config:
  - navegação por abas adicionada (`Arquivos`, `Backup`, `Propriedades`) com estilo pill e estado ativo.

## 25. Home Dashboard + Kick Players + refinamentos de Whitelist/Config/Console (04/03/2026)

- Home:
  - remoção dos textos introdutórios;
  - cards de status com ícone + título bold + valor;
  - status padronizado em maiúsculo;
  - backup habilitado apenas offline;
  - botão de desconectar jogadores com modal de kick (todos / um / vários) e mensagem padrão.
- Servidor:
  - estado inclui `onlinePlayers`;
  - provider `onlinePlayersProvider` para consumo em UI;
  - parsing de `/list` e eventos de join/leave para atualizar jogadores online.
- Whitelist:
  - formulário do modal refatorado para componente dedicado;
  - seletor de ícone com visual de input e posicionado acima de nickname;
  - confirmação de deleção via `AppModal`;
  - cards com avatar circular padrão, ações coloridas, destaque quando ID vazio e badge ONLINE/OFFLINE.
- Config:
  - navegação por abas centralizada no topo.
- Sidebar:
  - ordenação ajustada: Chunky antes de Config (Config como último item).
- Console:
  - modal de comandos rápidos em cards com título/descrição;
  - ações por card: copiar e inserir no input (sem executar automaticamente).
