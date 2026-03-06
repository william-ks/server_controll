<div align="center">

# ⛏️ MineControl

**Painel de administração local para servidores Minecraft**

[![Version](https://img.shields.io/badge/versão-0.1.0--alpha-orange?style=flat-square)](https://github.com/william-ks/server_controll/releases)
[![License: GPL v3](https://img.shields.io/badge/Licença-GPLv3-blue?style=flat-square)](https://www.gnu.org/licenses/gpl-3.0)
[![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?style=flat-square&logo=flutter)](https://flutter.dev)
[![Platform](https://img.shields.io/badge/Plataforma-Windows%20%7C%20Linux-lightgrey?style=flat-square)](https://github.com/william-ks/server_controll)
[![Status](https://img.shields.io/badge/status-alpha-yellow?style=flat-square)](https://github.com/william-ks/server_controll)

> ⚠️ **Projeto em fase Alpha** — funcionalidades em desenvolvimento ativo. Pode haver instabilidades.

</div>

---

## 📖 Sobre o Projeto

O **MineControl** é uma aplicação desktop desenvolvida em **Flutter** para gerenciamento local de servidores Minecraft. Ele centraliza a administração do servidor em uma interface moderna e limpa, eliminando a necessidade de operar diretamente pelo terminal.

Inspirado no projeto Python `zController`, o MineControl traz as mesmas capacidades funcionais com uma arquitetura mais modular, UI aprimorada e fluxo operacional mais robusto.

### 🎯 Objetivo

Permitir que o administrador do servidor:
- Inicie, pare e reinicie o servidor com um clique
- Acompanhe o console em tempo real sem abrir um terminal separado
- Envie comandos diretamente ao servidor
- Gerencie configurações de forma persistente
- Controle backups automatizados e manuais
- Gerencie whitelist e permissões de OP
- Agende automações baseadas em cron

---

## ✨ Funcionalidades

### 🖥️ Home
- Controle completo do ciclo de vida do servidor (iniciar, parar, reiniciar)
- Indicador visual de estado do servidor (offline, iniciando, online, desligando)
- Backup manual com modal de progresso
- Controle de PVP em tempo real
- Desconexão de jogadores (individual, múltiplos ou todos)

### 📟 Console
- Exibição do stdout do servidor Java em tempo real
- Envio de comandos ao servidor
- Cópia de conteúdo do console

### ⚙️ Configurações
| Aba | Descrição |
|-----|-----------|
| **Servidor** | Path do servidor, arquivo JAR, configurações de Java e RAM, auto-restart em crash |
| **Propriedades** | Edição do `server.properties` (nome, MOTD, gamemode, max-players, PVP, whitelist) |
| **Backups** | Configuração de pasta, retenção máxima e agendamento |
| **Admin** | Gerenciamento de OP (dar/remover permissões de operador) |
| **Agendamentos** | Automações via cron (iniciar, desligar, reiniciar + backup opcional) |
| **Avançado** | Limpeza de dados locais com dupla confirmação |

### 📋 Whitelist
- Sincronização com o arquivo físico `whitelist.json`
- Adição e remoção de jogadores
- Validação de configurações essenciais

### 📦 Backups
- Backup manual e agendado
- Retenção automática (remove os mais antigos ao atingir o limite)
- Histórico com nome, tipo, data e tamanho
- Tipos: `Manual`, `Agendamento`, `Chunk`

### ⏰ Agendamentos
- Expressões cron personalizadas
- Avisos automáticos aos jogadores (15, 10, 5 e 1 minuto antes)
- Integração com sistema de backup

---

## 🗂️ Estrutura do Projeto

```
lib/
├── main.dart                 # Entrypoint
├── app.dart                  # Configuração da aplicação
├── layout/                   # Layout padrão e design system
├── components/               # Componentes reutilizáveis globais
├── models/                   # Modelos de dados
├── database/                 # Configuração e acesso SQLite
├── config/                   # Configurações globais da aplicação
└── modules/
    ├── home/                 # Tela principal e controle do servidor
    ├── console/              # Console em tempo real
    ├── config/               # Módulo de configurações
    ├── whitelist/            # Gerenciamento de whitelist
    ├── server/               # Serviços do processo Java
    └── backup/               # Sistema de backup
docs/
├── minecontrol_documentacao_v2.md  # Documentação completa do sistema
├── info_zcontroller.md             # Referência do projeto base Python
├── compatibilidade_so_levantamento.md  # Análise de compatibilidade SO
└── minecraft_commands.md           # Referência de comandos Minecraft
```

---

## 🛠️ Tecnologias

| Tecnologia | Descrição |
|------------|-----------|
| [Flutter](https://flutter.dev) | Framework UI multiplataforma |
| [Riverpod 3](https://riverpod.dev) | Gerenciamento de estado reativo |
| [SQLite (sqflite_ffi)](https://pub.dev/packages/sqflite_common_ffi) | Persistência local |
| [file_picker](https://pub.dev/packages/file_picker) | Seleção de arquivos/pastas |
| [archive](https://pub.dev/packages/archive) | Criação de arquivos ZIP (backup) |

---

## 📋 Pré-requisitos

Antes de executar o projeto, certifique-se de ter instalado:

- **[Flutter SDK](https://docs.flutter.dev/get-started/install)** — versão `^3.10.7` ou superior
- **[Dart SDK](https://dart.dev/get-dart)** — incluído com o Flutter
- **Git**

Para verificar a instalação:
```bash
flutter --version
flutter doctor
```

---

## 🚀 Como Executar

### 1. Clone o repositório

```bash
git clone https://github.com/william-ks/server_controll.git
cd server_controll
```

### 2. Instale as dependências

```bash
flutter pub get
```

### 3. Execute em modo desenvolvimento

**Windows:**
```bash
flutter run -d windows
```

**Linux:**
```bash
flutter run -d linux
```

> 💡 Para listar os dispositivos disponíveis: `flutter devices`

---

## 📦 Como Compilar (Build)

### Windows

```bash
flutter build windows --release
```

O executável será gerado em:
```
build/windows/x64/runner/Release/
```

### Linux

```bash
flutter build linux --release
```

O executável será gerado em:
```
build/linux/x64/release/bundle/
```

---

## 🖼️ Ícones do Launcher

Para regenerar os ícones da aplicação após alterar a imagem em `lib/assets/minecraft.png`:

```bash
dart run flutter_launcher_icons
```

---

## 🗄️ Banco de Dados

O MineControl utiliza **SQLite** para persistência local de:
- Configurações do servidor (`app_settings`)
- Dados da whitelist
- Registros de backup
- Agendamentos
- Estado do PVP e propriedades do servidor

O banco é criado automaticamente na primeira execução.

---

## 📊 Estado Atual (Alpha)

| Módulo | Status |
|--------|--------|
| Home (controle do servidor) | ✅ Funcional |
| Console em tempo real | ✅ Funcional |
| Config > Servidor | ✅ Funcional |
| Config > Propriedades | ✅ Funcional |
| Config > Backups | ✅ Funcional |
| Config > Admin (OP) | ✅ Funcional |
| Config > Agendamentos | ✅ Funcional |
| Config > Avançado | ✅ Funcional |
| Whitelist | ✅ Funcional |
| Tela de Backups | ✅ Funcional |
| Geração de Chunks | 🚧 Em desenvolvimento |
| Suporte Linux completo | 🚧 Em desenvolvimento |

---

## 🤝 Contribuindo

Contribuições são bem-vindas! Por favor, leia as orientações antes de abrir issues ou pull requests.

### Como contribuir

1. **Fork** o projeto
2. Crie uma branch para sua feature ou correção:
   ```bash
   git checkout -b feat/minha-feature
   ```
3. Faça suas alterações e commit:
   ```bash
   git commit -m "feat: adiciona minha feature"
   ```
4. Envie para o repositório remoto:
   ```bash
   git push origin feat/minha-feature
   ```
5. Abra um **Pull Request**

### Padrão de commits

Use o padrão [Conventional Commits](https://www.conventionalcommits.org/):

| Prefixo | Uso |
|---------|-----|
| `feat:` | Nova funcionalidade |
| `fix:` | Correção de bug |
| `docs:` | Documentação |
| `refactor:` | Refatoração sem mudança funcional |
| `chore:` | Tarefas de manutenção |

### Reportando problemas

Use os templates de issue disponíveis ao abrir uma nova issue. Veja a pasta [`.github/ISSUE_TEMPLATE`](.github/ISSUE_TEMPLATE/).

---

## 📄 Licença

Este projeto é licenciado sob a **GNU General Public License v3.0** — veja o arquivo [LICENSE](LICENSE) para detalhes.

```
MineControl - Painel de administração local para servidores Minecraft
Copyright (C) 2024  william-ks

Este programa é software livre: você pode redistribuí-lo e/ou modificá-lo
sob os termos da Licença Pública Geral GNU conforme publicada pela
Free Software Foundation, na versão 3 da Licença, ou (a seu critério)
qualquer versão posterior.
```

---

## 📚 Documentação

Para documentação técnica completa do sistema, consulte a pasta [`docs/`](docs/):

- [`minecontrol_documentacao_v2.md`](docs/minecontrol_documentacao_v2.md) — Documentação completa do sistema
- [`info_zcontroller.md`](docs/info_zcontroller.md) — Referência do projeto base Python
- [`compatibilidade_so_levantamento.md`](docs/compatibilidade_so_levantamento.md) — Análise de compatibilidade por SO
- [`minecraft_commands.md`](docs/minecraft_commands.md) — Referência rápida de comandos Minecraft

---

<div align="center">

Feito com ❤️ por [william-ks](https://github.com/william-ks)

</div>
