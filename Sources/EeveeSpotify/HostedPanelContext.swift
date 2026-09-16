import Foundation

/// Contexto do painel quando ele é executado dentro do processo do Spotify.
enum HostedPanelContext {
    static var hostBundleIdentifier: String? {
        Bundle.main.bundleIdentifier
    }

    static var isHostedInSpotify: Bool {
        hostBundleIdentifier == "com.spotify.client"
    }

    /// Identificador usado ao criar novos projetos no painel hospedado.
    static var defaultPatchBundleIdentifier: String {
        hostBundleIdentifier ?? "com.spotify.client"
    }
}
