import Foundation

/// Configuração única da faixa que abre o painel integrado.
/// Preferencialmente use o identificador Spotify da faixa, não apenas o título.
enum TriggerConfiguration {
    /// Faixa configurada pelo usuário:
    /// https://open.spotify.com/track/0wwPcA6wtMf6HUMpIRdeP7
    static let trackIdentifier = "0wwPcA6wtMf6HUMpIRdeP7"

    /// Política aplicada quando a reprodução deixa de ser a faixa gatilho.
    static let dismissPanelWhenTrackChanges = true

    static var isEnabled: Bool {
        !trackIdentifier.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}
