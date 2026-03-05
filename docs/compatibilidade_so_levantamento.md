# Levantamento de Compatibilidade de SO

Data: 2026-03-05
Escopo: codigo em `lib/`

## Pontos que funcionam apenas no Windows hoje

1. `lib/modules/server/services/server_process_service.dart`
- Uso direto de `taskkill` para encerramento de processo.
- Uso de scripts `powershell` para:
  - verificar se PID existe;
  - obter memoria de processo;
  - localizar instancias Java com `Get-CimInstance Win32_Process`.

## Pontos que variam por SO, mas ja tem caminho Unix/Linux

1. `lib/modules/server/services/server_process_service.dart`
- Para nao-Windows, ja existe caminho usando `kill` e `ps`.
- Risco atual: comandos por SO estao acoplados dentro da mesma classe, sem provider dedicado por plataforma.

## Pontos nao bloqueantes, mas com viés Windows

1. `lib/modules/config/subcomponents/files_settings_tab.dart`
- Hint de path mostra exemplo Windows (`C:\minecraft\...`).

2. `lib/modules/whitelist/subcomponents/whitelist_add_player_form.dart`
- Hint de imagem mostra exemplo Windows (`C:\imagens\...`).

## Conclusao

- O funcionamento cross-platform do ciclo de vida do servidor depende de extrair os comandos por SO para um provider.
- O projeto nao possui ainda etapa explicita de bootstrap que detecta o SO e registra/valida comandos ao iniciar.
