import Foundation
import UIKit

/// Observa a faixa atual do Spotify sem interferir no fluxo normal de reprodução.
final class TriggerTrackDetector {
    static let shared = TriggerTrackDetector()

    private weak var player: StatefulPlayerImplementation?
    private var timer: Timer?
    private var lastIdentifier: String?
    private var didOpenForIdentifier: String?

    private init() {}

    func attach(to player: StatefulPlayerImplementation) {
        self.player = player
        guard timer == nil else { return }

        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.timer = Timer.scheduledTimer(
                withTimeInterval: 0.75,
                repeats: true
            ) { [weak self] _ in
                self?.poll()
            }
            self.timer?.tolerance = 0.25
            self.poll()
        }
    }

    private func poll() {
        guard let player else { return }
        let identifier = player.currentTrack()?.URI().spt_trackIdentifier()
        guard identifier != lastIdentifier else { return }
        lastIdentifier = identifier

        guard TriggerConfiguration.isEnabled else { return }

        if identifier == TriggerConfiguration.trackIdentifier {
            guard didOpenForIdentifier != identifier else { return }
            didOpenForIdentifier = identifier
            TriggerPresentationCoordinator.shared.presentPanelIfNeeded()
        } else {
            didOpenForIdentifier = nil
            if TriggerConfiguration.dismissPanelWhenTrackChanges {
                TriggerPresentationCoordinator.shared.dismissPanelIfPresented()
            }
        }
    }
}
