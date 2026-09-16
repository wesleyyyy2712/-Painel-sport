import SwiftUI
import UIKit

/// Raiz do painel convertido de aplicativo independente para módulo hospedado.
struct TriggerPanelHost: View {
    @StateObject private var appState = AppState()
    @StateObject private var patchDraftCoordinator = PatchDraftCoordinator()
    @StateObject private var fileOperationCoordinator = FileOperationCoordinator()
    @StateObject private var patchStore = PatchProjectStore()
    @StateObject private var repositoryStore = PackageRepositoryStore()

    var body: some View {
        ContentView()
            .environmentObject(appState)
            .environmentObject(patchDraftCoordinator)
            .environmentObject(fileOperationCoordinator)
            .environmentObject(patchStore)
            .environmentObject(repositoryStore)
            .environment(\.appLanguage, .portuguese)
            .environment(\.locale, AppLanguage.portuguese.locale)
    }
}

final class TriggerPresentationCoordinator {
    static let shared = TriggerPresentationCoordinator()

    private weak var presentedController: UIViewController?
    private var isPresenting = false

    private init() {}

    func presentPanelIfNeeded() {
        guard !isPresenting else { return }
        DispatchQueue.main.async { [weak self] in
            guard let self, !self.isPresenting else { return }
            guard let presenter = self.topViewController() else { return }

            let controller = UIHostingController(rootView: TriggerPanelHost())
            controller.modalPresentationStyle = .pageSheet
            controller.title = "3105"
            if let sheet = controller.sheetPresentationController {
                sheet.detents = [.large()]
                sheet.prefersGrabberVisible = true
            }

            self.isPresenting = true
            self.presentedController = controller
            presenter.present(controller, animated: true)
        }
    }

    func dismissPanelIfPresented() {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.presentedController?.dismiss(animated: true)
            self.presentedController = nil
            self.isPresenting = false
        }
    }

    private func topViewController() -> UIViewController? {
        let keyWindow = UIApplication.shared.windows.first(where: { $0.isKeyWindow })
        let root = keyWindow?.rootViewController ?? UIApplication.shared.windows.first?.rootViewController
        var current = root
        while let presented = current?.presentedViewController {
            current = presented
        }
        return current
    }
}
