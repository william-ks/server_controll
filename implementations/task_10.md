# TASK 10 - Expansao da Tela de server.properties

## Contexto atual no projeto
- A edicao atual de `server.properties` cobre um subconjunto de campos (10 chaves) via [lib/modules/config/services/server_properties_service.dart](C:/Users/Usuario/Desktop/projeto/server_controll/lib/modules/config/services/server_properties_service.dart).
- A UI atual da aba Propriedades esta em [lib/modules/config/subcomponents/properties_settings_tab.dart](C:/Users/Usuario/Desktop/projeto/server_controll/lib/modules/config/subcomponents/properties_settings_tab.dart) com validacoes basicas.
- Ja existe regra de precedencia do arquivo fisico sobre banco.
- Ainda nao ha estrutura expansivel por metadados de campo (tipo, faixa, descricao, impacto).

## Como implementar
- Modelo de metadados:
  - Criar catalogo de campos gerenciados (ex.: `server_properties_field_catalog.dart`) com:
    - chave tecnica;
    - label amigavel;
    - tipo (`bool`, `int`, `string`, `enum`);
    - faixa valida (quando aplicavel);
    - descricao de impacto.
- Servico:
  - Evoluir `ServerPropertiesService` para leitura/escrita dinamica com base no catalogo.
  - Preservar chaves nao gerenciadas sem alteracao.
  - Implementar validacao por tipo/faixa antes de salvar.
- UI:
  - Reorganizar aba em grupos tematicos (rede, gameplay, mundo, performance, seguranca).
  - Inputs adequados por tipo e mensagens de erro claras por campo.
  - Mostrar hint/impacto sob cada campo quando relevante.
  - Preparar area de acao fixa (sinergia com Task 15).
- Persistencia:
  - Continuar espelhando no SQLite para cache e inicializacao rapida.
  - Manter arquivo fisico como fonte principal.
- Compatibilidade:
  - Evitar quebrar campos antigos ja suportados.
  - Garantir que escrita funcione em Windows e Linux.

## Como verificar
- [ ] Carregar `server.properties` real e validar preenchimento dos campos ampliados.
- [ ] Alterar campos de tipos diferentes (bool/int/string/enum) e salvar com sucesso.
- [ ] Validar erros de faixa/tipo quando valores invalidos forem informados.
- [ ] Confirmar persistencia no arquivo fisico e no espelho local.
- [ ] Garantir que chaves nao gerenciadas continuam intactas apos salvamento.
- [ ] Revisar usabilidade da tela em diferentes tamanhos de janela.

## Dependencias e ordem sugerida
- Implementar catalogo de campos primeiro.
- Evoluir servico de leitura/escrita em seguida.
- Reestruturar UI por ultimo.
- Recomendada antes de Task 02 e Task 04 (dependem de propriedades mais ricas como MOTD/estado visual).

## Definicao de concluido
- A tela de `server.properties` cobre quase todos os campos relevantes.
- Cada campo tem input adequado, validacao e explicacao de impacto.
- O app reduz a necessidade de edicao manual de arquivo texto.

