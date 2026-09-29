import Foundation
import UIKit

/// Integração mínima com o Spotify: o Spotify só dispara a abertura do 3105.
/// A interface, o estado e a aplicação permanecem no app 3105 standalone.
final class TriggerPresentationCoordinator {
    static let shared = TriggerPresentationCoordinator()

    private var isOpening = false

    private init() {}

    func presentPanelIfNeeded() {
        guard !isOpening else { return }
        guard let url = URL(string: "threeoneosfive://trigger") else { return }

        isOpening = true
        DispatchQueue.main.async { [weak self] in
            UIApplication.shared.open(url, options: [:]) { _ in
                DispatchQueue.main.async {
                    self?.isOpening = false
                }
            }
        }
    }

    /// O 3105 é um app independente; trocar de música não deve fechar sua interface.
    func dismissPanelIfPresented() {}
}
