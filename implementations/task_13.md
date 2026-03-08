# TASK 13 - Hook de Chat para Comandos do Servidor

## Contexto atual no projeto
- O app ja recebe stdout do servidor e ja possui parser para alguns eventos operacionais.
- Nao existe parser/dispatcher de comandos administrativos via chat.
- Nao existe conceito operacional de admin do app aplicado a comandos de chat.
- O console do app ja e um bom ponto para refletir retorno de execucao.

## Como implementar
- Parser de hook:
  - Criar parser de chat que detecta mensagens iniciadas com prefixo literal `<server>`.
  - Parsing case-insensitive para comando/argumentos.
  - Estrutura de resultado: `raw`, `command`, `args`, `player`.
- Registry de comandos:
  - Criar `chat_command_registry` com contrato:
    - nome;
    - descricao;
    - politica de permissao;
    - handler.
  - Comandos iniciais:
    - `help`
    - `status`
    - `restart`
- Permissao:
  - Integrar com status de admin do app (Task 07/08).
  - Nao usar OP como criterio de autorizacao do hook.
- Resposta:
  - Retornar para chat e console do app quando aplicavel.
  - Padronizar mensagens para players com prefixo `[SERVER 🤖]`.
  - `help` deve listar apenas comandos permitidos ao executor.
- Historico especifico:
  - Criar tabela `chat_hook_history` com:
    - player, comando bruto, comando interpretado, args, permissao aplicada, resultado, horario.

## Como verificar
- [ ] Enviar `<server> help` com player comum e validar lista restrita.
- [ ] Enviar `<server> help` com admin e validar lista completa permitida.
- [ ] Enviar `<server> status` e `<server> restart` e validar execucao/autorizacao.
- [ ] Testar case-insensitive (`<server> ReStArT`) e validar parser.
- [ ] Confirmar registro completo no historico do hook.
- [ ] Validar mensagens de retorno no chat e no console do app.

## Dependencias e ordem sugerida
- Depende de Task 07/08 para permissao de admin do app.
- Implementar primeiro parser + registry.
- Integrar permissao e handlers em seguida.
- Finalizar com historico e UI de consulta (pode integrar com Task 14).

## Definicao de concluido
- Comandos via `<server>` sao parseados e executados com controle de permissao por comando.
- `help` respeita visibilidade por executor.
- Toda execucao do hook fica registrada com resultado e contexto.

