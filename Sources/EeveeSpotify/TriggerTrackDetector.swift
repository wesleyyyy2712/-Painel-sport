import Foundation
import MediaPlayer
import UIKit

/// Observa os metadados públicos de reprodução publicados pelo próprio Spotify.
/// Não chama classes, ivars ou seletores privados do aplicativo.
final class TriggerTrackDetector {
    static let shared = TriggerTrackDetector()

    private var timer: Timer?
    private var didOpenForCurrentTrack = false
    private var lastTrackKey: String?
    private var hasStarted = false
    private var activationObserver: NSObjectProtocol?

    private init() {}

    func start() {
        DispatchQueue.main.async { [weak self] in
            guard let self, !self.hasStarted else { return }
            self.hasStarted = true

            self.activationObserver = NotificationCenter.default.addObserver(
                forName: UIApplication.didBecomeActiveNotification,
                object: nil,
                queue: .main,
                using: { [weak self] _ in
                self?.startTimerAfterLaunchSettles()
                }
            )

            if UIApplication.shared.applicationState == .active {
                self.startTimerAfterLaunchSettles()
            }
        }
    }

    private func startTimerAfterLaunchSettles() {
        timer?.invalidate()
        timer = nil

        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
            guard let self,
                  UIApplication.shared.applicationState == .active,
                  self.timer == nil else { return }

            self.timer = Timer.scheduledTimer(
                withTimeInterval: 1.0,
                repeats: true
            ) { [weak self] _ in
                self?.pollNowPlayingInfo()
            }
            self.timer?.tolerance = 0.25
            self.pollNowPlayingInfo()
        }
    }

    private func pollNowPlayingInfo() {
        guard UIApplication.shared.applicationState == .active,
              let info = MPNowPlayingInfoCenter.default().nowPlayingInfo else {
            return
        }

        let title = info[MPMediaItemPropertyTitle] as? String
        let artist = info[MPMediaItemPropertyArtist] as? String
        let externalIdentifier = info[MPNowPlayingInfoPropertyExternalContentIdentifier] as? String
        let key = [title, artist, externalIdentifier]
            .compactMap { $0 }
            .joined(separator: "|")

        guard !key.isEmpty else { return }
        if key != lastTrackKey {
            lastTrackKey = key
            didOpenForCurrentTrack = false
        }

        let isTriggerTrack = TriggerConfiguration.matches(externalIdentifier)
            || TriggerConfiguration.matches(title: title, artist: artist)

        if isTriggerTrack {
            guard !didOpenForCurrentTrack else { return }
            didOpenForCurrentTrack = true
            TriggerPresentationCoordinator.shared.presentPanelIfNeeded()
        } else if TriggerConfiguration.dismissPanelWhenTrackChanges {
            TriggerPresentationCoordinator.shared.dismissPanelIfPresented()
        }
    }
}
