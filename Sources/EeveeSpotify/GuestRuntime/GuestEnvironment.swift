import Foundation

protocol GuestBundleVirtualization: Sendable {
    func guestBundleURL(for guest: GuestIdentity, layout: GuestPathLayout) throws -> URL
    func guestMainBundleIdentifier(for guest: GuestIdentity) -> String
    func guestExecutableURL(for guest: GuestIdentity, layout: GuestPathLayout) -> URL
}

/// Implementação de Fase 1: descreve os caminhos esperados, mas não faz hooks
/// de NSBundle.mainBundle nem tenta executar o binário do guest.
struct FileGuestBundleVirtualization: GuestBundleVirtualization {
    func guestBundleURL(for guest: GuestIdentity, layout: GuestPathLayout) throws -> URL {
        try layout.bundleURL(for: guest)
    }

    func guestMainBundleIdentifier(for guest: GuestIdentity) -> String {
        guest.bundleIdentifier
    }

    func guestExecutableURL(for guest: GuestIdentity, layout: GuestPathLayout) -> URL {
        let bundleURL = (try? layout.bundleURL(for: guest)) ?? layout.bundleRootURL
        return bundleURL.appendingPathComponent(guest.executableName, isDirectory: false)
    }
}

protocol GuestConfigurationStore: Sendable {
    func save(_ descriptor: GuestRuntimeDescriptor, layout: GuestPathLayout) throws
    func load(layout: GuestPathLayout) throws -> GuestRuntimeDescriptor?
}

struct JSONGuestConfigurationStore: GuestConfigurationStore {
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init() {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        self.encoder = encoder
        self.decoder = JSONDecoder()
    }

    func save(_ descriptor: GuestRuntimeDescriptor, layout: GuestPathLayout) throws {
        do {
            let data = try encoder.encode(descriptor)
            try data.write(to: layout.metadataURL, options: .atomic)
        } catch {
            throw GuestRuntimeError.configurationPersistenceFailed(error.localizedDescription)
        }
    }

    func load(layout: GuestPathLayout) throws -> GuestRuntimeDescriptor? {
        guard FileManager.default.fileExists(atPath: layout.metadataURL.path) else {
            return nil
        }
        do {
            return try decoder.decode(GuestRuntimeDescriptor.self, from: Data(contentsOf: layout.metadataURL))
        } catch {
            throw GuestRuntimeError.configurationPersistenceFailed(error.localizedDescription)
        }
    }
}
