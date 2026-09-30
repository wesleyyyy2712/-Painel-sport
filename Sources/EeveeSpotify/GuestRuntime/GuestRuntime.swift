import Foundation

protocol GuestRuntimeLogging: Sendable {
    func record(_ event: GuestRuntimeLogEvent)
}

struct GuestRuntimeLogger: GuestRuntimeLogging {
    func record(_ event: GuestRuntimeLogEvent) {
        print("[GuestRuntime] [\(event.phase)] \(event.message)")
    }
}

final class GuestRuntime {
    private(set) var state: GuestRuntimeState = .idle
    private(set) var descriptor: GuestRuntimeDescriptor?
    private(set) var layout: GuestPathLayout?

    private let configurationStore: GuestConfigurationStore
    private let logger: GuestRuntimeLogging
    private let fileManager: FileManager

    init(
        configurationStore: GuestConfigurationStore = JSONGuestConfigurationStore(),
        logger: GuestRuntimeLogging = GuestRuntimeLogger(),
        fileManager: FileManager = .default
    ) {
        self.configurationStore = configurationStore
        self.logger = logger
        self.fileManager = fileManager
    }

    func prepare(
        descriptor: GuestRuntimeDescriptor,
        layout: GuestPathLayout
    ) throws {
        guard descriptor.host.bundleIdentifier != descriptor.guest.bundleIdentifier else {
            throw GuestRuntimeError.hostGuestIdentityConflict
        }
        if let target = descriptor.target,
           target.bundleIdentifier == descriptor.host.bundleIdentifier {
            throw GuestRuntimeError.targetGuestIdentityConflict
        }
        guard state == .idle || state == .stopped else {
            throw GuestRuntimeError.invalidState(current: state, requested: .preparing)
        }

        transition(to: .preparing, message: "preparing isolated guest environment")
        do {
            try layout.prepare(using: fileManager)
            try configurationStore.save(descriptor, layout: layout)
            self.descriptor = descriptor
            self.layout = layout
            transition(to: .prepared, message: "guest paths and configuration prepared")
        } catch {
            state = .failed
            logger.record(GuestRuntimeLogEvent(phase: "prepare", message: error.localizedDescription))
            throw error
        }
    }

    /// Fase 1 deliberadamente não executa o Spotify. O carregador Mach-O,
    /// processo guest, assinatura e ciclo de vida serão implementados em fases
    /// posteriores e só poderão ser marcados como funcionais após teste real.
    func start() throws {
        guard state == .prepared else {
            throw GuestRuntimeError.invalidState(current: state, requested: .running)
        }
        state = .loadingUnavailable
        logger.record(GuestRuntimeLogEvent(
            phase: "load",
            message: "guest execution unavailable: Mach-O loader and guest process are not implemented"
        ))
        throw GuestRuntimeError.guestExecutionUnavailable
    }

    func stop() {
        guard state == .running || state == .loadingUnavailable || state == .failed else { return }
        transition(to: .stopping, message: "stopping guest runtime")
        transition(to: .stopped, message: "guest runtime stopped")
    }

    func reloadConfiguration() throws -> GuestRuntimeDescriptor? {
        guard let layout else { return nil }
        return try configurationStore.load(layout: layout)
    }

    private func transition(to newState: GuestRuntimeState, message: String) {
        state = newState
        logger.record(GuestRuntimeLogEvent(phase: newState.rawValue, message: message))
    }
}
