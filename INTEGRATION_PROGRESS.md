# EeveeSpotify — integração inicial do painel

Esta cópia de trabalho preserva os arquivos originais e contém a primeira etapa da integração.

## O que foi adicionado

- `Sources/EeveeSpotify/TriggerConfiguration.swift`: configuração central da faixa gatilho.
- `Sources/EeveeSpotify/TriggerTrackDetector.swift`: leitura periódica de `currentTrack()` e comparação pelo identificador da faixa.
- `Sources/EeveeSpotify/TriggerPanelHost.swift`: host SwiftUI apresentado dentro do processo do Spotify.
- `Sources/EeveeSpotify/PanelAppState.swift`: estado separado do ciclo de vida `@main` do aplicativo 3105.
- Fontes Swift do painel copiadas para `Sources/EeveeSpotify/Panel`, sem o `App.swift` original.
- Hooks de `NowPlaying` atualizados para conectar o detector ao player interno.

## Configuração

Edite `TriggerConfiguration.swift`:

```swift
static let trackIdentifier = "spotify:track:SEU_ID"
```

O identificador deve ser o URI da faixa no Spotify. O valor vazio mantém o gatilho desativado.

## Limitações desta etapa

O ambiente atual não possui Xcode, SDK iOS, Swift compiler ou Theos. Portanto, não foi possível executar um build real do tweak neste ambiente.

O painel original contém código C/Objective-C e componentes de baixo nível relacionados a exploit/sandbox. Esses componentes ainda não foram ligados ao target Theos nesta etapa e não são ativados automaticamente pelo host. Eles precisam ser auditados e adaptados separadamente antes de declarar o projeto compilável.

A cópia é uma etapa de integração em andamento, não uma release final.
