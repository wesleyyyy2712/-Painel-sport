import Foundation

/// Identidade do aplicativo que controla o runtime.
struct GuestHostIdentity: Codable, Equatable, Sendable {
    let bundleIdentifier: String
    let executableName: String

    init(bundleIdentifier: String, executableName: String) {
        self.bundleIdentifier = bundleIdentifier
        self.executableName = executableName
    }
}

/// Identidade lógica do aplicativo carregado pelo runtime.
struct GuestIdentity: Codable, Equatable, Sendable {
    let bundleIdentifier: String
    let displayName: String
    let executableName: String

    init(bundleIdentifier: String, displayName: String, executableName: String) {
        self.bundleIdentifier = bundleIdentifier
        self.displayName = displayName
        self.executableName = executableName
    }
}

/// Alvo selecionado para operações do 3105. Não é automaticamente o guest.
struct GuestTargetIdentity: Codable, Equatable, Sendable {
    let bundleIdentifier: String

    init(bundleIdentifier: String) {
        self.bundleIdentifier = bundleIdentifier
    }
}

struct GuestRuntimeDescriptor: Codable, Equatable, Sendable {
    let host: GuestHostIdentity
    let guest: GuestIdentity
    let target: GuestTargetIdentity?
    let containerIdentifier: String

    init(
        host: GuestHostIdentity,
        guest: GuestIdentity,
        target: GuestTargetIdentity? = nil,
        containerIdentifier: String
    ) {
        self.host = host
        self.guest = guest
        self.target = target
        self.containerIdentifier = containerIdentifier
    }
}

enum GuestRuntimeState: String, Codable, Equatable, Sendable {
    case idle
    case preparing
    case prepared
    case loadingUnavailable
    case running
    case stopping
    case stopped
    case failed
}

enum GuestRuntimeError: Error, LocalizedError, Equatable, Sendable {
    case invalidIdentifier(String)
    case invalidPath(String)
    case hostGuestIdentityConflict
    case targetGuestIdentityConflict
    case configurationPersistenceFailed(String)
    case guestExecutionUnavailable
    case invalidState(current: GuestRuntimeState, requested: GuestRuntimeState)

    var errorDescription: String? {
        switch self {
        case .invalidIdentifier(let value):
            return "Invalid bundle/container identifier: \(value)"
        case .invalidPath(let value):
            return "Invalid guest path: \(value)"
        case .hostGuestIdentityConflict:
            return "HOST and GUEST identities must remain separate"
        case .targetGuestIdentityConflict:
            return "TARGET must be selected explicitly and cannot replace HOST identity"
        case .configurationPersistenceFailed(let detail):
            return "Guest configuration persistence failed: \(detail)"
        case .guestExecutionUnavailable:
            return "Guest execution is not implemented in this phase"
        case .invalidState(let current, let requested):
            return "Invalid guest runtime transition from \(current.rawValue) to \(requested.rawValue)"
        }
    }
}

struct GuestRuntimeLogEvent: Codable, Equatable, Sendable {
    let phase: String
    let message: String
    let timestamp: Date

    init(phase: String, message: String, timestamp: Date = Date()) {
        self.phase = phase
        self.message = message
        self.timestamp = timestamp
    }
}
