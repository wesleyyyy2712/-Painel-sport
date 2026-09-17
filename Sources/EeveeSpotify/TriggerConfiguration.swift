import Foundation

/// Configuração única da faixa que abre o painel integrado.
/// Preferencialmente use o identificador Spotify da faixa, não apenas o título.
enum TriggerConfiguration {
    /// Faixa configurada pelo usuário:
    /// https://open.spotify.com/track/0wwPcA6wtMf6HUMpIRdeP7
    static let trackIdentifier = "0wwPcA6wtMf6HUMpIRdeP7"
    static let trackTitle = "Hotline Bling"
    static let trackArtist = "Drake"

    /// Política aplicada quando a reprodução deixa de ser a faixa gatilho.
    static let dismissPanelWhenTrackChanges = true

    static var isEnabled: Bool {
        !trackIdentifier.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    static func normalizedTrackIdentifier(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        if trimmed == trackIdentifier { return trimmed }

        let withoutQuery = trimmed.split(separator: "?", maxSplits: 1).first.map(String.init) ?? trimmed
        let components = withoutQuery.split(whereSeparator: { $0 == ":" || $0 == "/" })
        return components.last.map(String.init)
    }

    static func matches(_ value: String?) -> Bool {
        normalizedTrackIdentifier(value) == trackIdentifier
    }

    static func matches(title: String?, artist: String?) -> Bool {
        guard let title, let artist else { return false }
        let options: String.CompareOptions = [.caseInsensitive, .diacriticInsensitive]
        return title.compare(trackTitle, options: options) == .orderedSame
            && artist.range(of: trackArtist, options: options) != nil
    }
}
