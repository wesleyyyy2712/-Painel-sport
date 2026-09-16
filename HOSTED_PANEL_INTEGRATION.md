# Integração do painel 3105 no host Spotify

Esta cópia usa a `ContentView` real do projeto 3105 dentro de `TriggerPanelHost`, aberta pelo detector da faixa configurada em `TriggerConfiguration.swift`.

## Fluxo

A faixa é monitorada pelo `TriggerTrackDetector`. Quando o identificador atual coincide com `0wwPcA6wtMf6HUMpIRdeP7`, o `TriggerPresentationCoordinator` apresenta o `TriggerPanelHost` dentro do Spotify. Quando a faixa muda, a apresentação é fechada porque `dismissPanelWhenTrackChanges` está habilitado.

## Alteração aplicada

`PanelAppState.detectSupport()` agora detecta o contexto hospedado e não inicia automaticamente o caminho de acesso de dispositivo/exploit usado pelo app 3105 independente. Nesse modo, o painel informa que o acesso do aplicativo independente está indisponível.

Também foi incluído o asset `HomeBackground.jpg` no bundle de recursos do tweak para evitar que a tela inicial perca o fundo visual.

## Limites da validação

O sandbox não possui Xcode, SDK iOS, Theos ou compilador Swift para iPhoneOS. Portanto, a cópia foi validada por inspeção estática e comparação de arquivos, mas não foi possível produzir um `.deb`/`.ipa` nem confirmar o comportamento em um iPhone.

Os componentes de exploit, sandbox escape e acesso a containers permanecem fora do caminho automático do painel hospedado e não foram desenvolvidos ou ampliados nesta integração.
