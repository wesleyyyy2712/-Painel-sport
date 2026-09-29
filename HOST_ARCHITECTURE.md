# Arquitetura final: 3105 como host principal

## Papéis

```text
Spotify                 = somente fonte do gatilho musical
Spotify3105Trigger      = tweak mínimo instalado no Spotify
3105                    = aplicativo principal e host da interface
Bundle ID selecionado   = alvo real da aplicação
Container resolvido     = container correspondente ao alvo
```

## Fluxo

```text
Spotify publica metadados públicos de reprodução
→ Spotify3105Trigger detecta a faixa configurada
→ Spotify3105Trigger abre threeoneosfive://trigger
→ iOS inicia ou traz o app 3105 standalone
→ 3105 mantém sua própria interface, estado, projetos e regras
→ usuário seleciona o aplicativo-alvo
→ o Bundle ID real do alvo é preservado
→ DevicePatchService resolve e valida o container do alvo
→ PatchTransaction aplica as regras existentes
→ o Spotify nunca é usado como destino
```

## Artefatos de build

### 1. Aplicativo 3105

Projeto existente:

```text
Sources/EeveeSpotify/Panel/extracted/panel/3105-2.0/ThreeOneOSFive.xcodeproj
```

O target `3105` já é um aplicativo iOS (`com.apple.product-type.application`) com:

- `@main` em `ThreeOneOSFive/App.swift`;
- `CFBundleIdentifier` standalone original;
- `CFBundleURLSchemes = threeoneosfive`;
- `mcm_bridge.m`;
- `DevicePatchService.swift`;
- `PatchTransaction.swift`;
- lógica original de seleção, projetos e regras.

O tratamento de `threeoneosfive://trigger` foi adicionado ao `App.swift` apenas para não interpretar o URL de gatilho como um arquivo de patch. A interface principal continua sendo `ContentView` do app standalone.

### 2. Gatilho Spotify

Target Theos:

```text
Makefile.panel
```

Target produzido:

```text
Spotify3105Trigger
```

Ele inclui somente:

- `TriggerConfiguration.swift`;
- `TriggerTrackDetector.swift`;
- `TriggerPanelHost.swift`, agora reduzido ao launcher de URL;
- `PanelHostBootstrap.m`.

Ele não inclui mais:

- a interface SwiftUI do 3105;
- `AppState` do painel;
- `DevicePatchService`;
- `mcm_bridge`;
- `kexploit`;
- recursos do Spotify além da leitura pública do gatilho.

O `Makefile` principal do EeveeSpotify exclui explicitamente as três fontes do
gatilho (`TriggerConfiguration.swift`, `TriggerPanelHost.swift` e
`TriggerTrackDetector.swift`). Assim, ao instalar os dois pacotes, existe uma
única instância do detector: a do target `Spotify3105Trigger`.

Ele também exclui `Sources/EeveeSpotify/Panel/**/*.swift`,
`HostedPanelContext.swift`, `PanelAppState.swift` e todo o diretório
`Sources/EeveeSpotifyC/panel-native`. O target principal usa somente
`Sources/EeveeSpotifyC/Tweak.m` como fonte nativa; portanto não incorpora a
interface, o AppState ou o mecanismo privilegiado do 3105.

O tweak principal continua compilando os recursos próprios do Spotify, como
hooks de premium, letras, configurações e demais extensões existentes. Esses
recursos não são responsáveis por renderizar login, conta ou a navegação
principal do Spotify; essas telas continuam pertencendo ao aplicativo original.

## Segurança de identidade

O launcher abre somente:

```text
threeoneosfive://trigger
```

O Bundle ID do host Spotify nunca é usado como Bundle ID do alvo. A resolução ocorre somente depois que o app 3105 standalone está em execução e recebe o alvo escolhido pelo usuário.

## Limitação de validação nesta sandbox

A sandbox atual não possui Xcode/iOS SDK nem um dispositivo iOS para executar o app ou testar o Mobile Container Manager. Foram feitas validações estáticas de:

- target application existente;
- bundle identity;
- inclusão das fontes de aplicação;
- target do gatilho;
- referências de símbolos;
- preservação do Bundle ID do alvo;
- integridade do ZIP original.
