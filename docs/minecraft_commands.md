# Comandos Rápidos do Minecraft 1.21.1

Referência rápida dos comandos essenciais para console de servidor.

---

## Comandos Essenciais

### 1. Modo de Jogo
**Comando:** `gamemode <survival|creative|adventure|spectator> [player]`

Troca o modo de jogo do jogador.

---

### 2. Localizar Estrutura/Bioma
**Comando:** `locate <structure|biome> <target>`

Encontra estrutura ou bioma mais próximo.

---

### 3. Matar Entidades
**Comando:** `kill @e[type=<mob>]`

Remove entidades por tipo (usar com cuidado).

---

### 4. Listar Jogadores Online
**Comando:** `list`

Lista todos os jogadores conectados ao servidor.

---

## Configurações do Servidor

### 5. Máximo de Jogadores
**Config:** `max-players=<número>` (server.properties)

Define o limite máximo de conexões simultâneas.

---

### 6. Percentual de Jogadores Dormindo
**Comando:** `gamerule playersSleepingPercentage <0-100>`

Define quantos % de jogadores precisam estar na cama para pular a noite (0 = apenas 1 jogador, 100 = todos).

---

### 7. Velocidade de Tick Aleatório
**Comando:** `gamerule randomTickSpeed <número>`

Controla velocidade de crescimento de plantas, propagação de fogo e outros processos aleatórios (padrão: 3).

---

### 8. Controle de Animais
**Comando:** `gamerule spawn_mobs <true|false>`

Habilita ou desabilita spawning natural de mobs/animais.

---

## Seletores de Alvo
- `@s` — executor do comando
- `@a` — todos os jogadores
- `@e` — todas as entidades
- `@p` — jogador mais próximo
- `@r` — jogador aleatório

## Notas
- Muitos comandos requerem nível de operador (OP)
- Use `/help <comando>` para sintaxe detalhada em-jogo
- Para `max-players`, edite o arquivo `server.properties` ou use a interface do app se disponível
