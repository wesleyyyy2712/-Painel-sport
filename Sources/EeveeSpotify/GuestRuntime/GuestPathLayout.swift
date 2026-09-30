import Foundation

struct GuestPathLayout: Codable, Equatable, Sendable {
    let rootURL: URL

    init(rootURL: URL) throws {
        let normalized = rootURL.standardizedFileURL
        guard normalized.isFileURL, normalized.path != "/" else {
            throw GuestRuntimeError.invalidPath(rootURL.path)
        }
        self.rootURL = normalized
    }

    var bundleRootURL: URL { rootURL.appendingPathComponent("Bundle", isDirectory: true) }
    var dataURL: URL { rootURL.appendingPathComponent("Data", isDirectory: true) }
    var documentsURL: URL { dataURL.appendingPathComponent("Documents", isDirectory: true) }
    var libraryURL: URL { dataURL.appendingPathComponent("Library", isDirectory: true) }
    var preferencesURL: URL { libraryURL.appendingPathComponent("Preferences", isDirectory: true) }
    var tmpURL: URL { dataURL.appendingPathComponent("tmp", isDirectory: true) }
    var metadataURL: URL { rootURL.appendingPathComponent("GuestRuntime.json") }

    var requiredDirectories: [URL] {
        [rootURL, bundleRootURL, dataURL, documentsURL, libraryURL, preferencesURL, tmpURL]
    }

    func bundleURL(for guest: GuestIdentity) throws -> URL {
        let appName = guest.bundleIdentifier.split(separator: ".").last.map(String.init) ?? "Guest"
        guard !appName.isEmpty else { throw GuestRuntimeError.invalidIdentifier(guest.bundleIdentifier) }
        return bundleRootURL.appendingPathComponent("\(appName).app", isDirectory: true)
    }

    func resolvingGuestRelativePath(_ relativePath: String) throws -> URL {
        guard !relativePath.isEmpty,
              !relativePath.hasPrefix("/"),
              !relativePath.split(separator: "/").contains("..") else {
            throw GuestRuntimeError.invalidPath(relativePath)
        }
        let resolved = rootURL.appendingPathComponent(relativePath).standardizedFileURL
        guard resolved.path == rootURL.path || resolved.path.hasPrefix(rootURL.path + "/") else {
            throw GuestRuntimeError.invalidPath(relativePath)
        }
        return resolved
    }

    func prepare(using fileManager: FileManager = .default) throws {
        for directory in requiredDirectories {
            try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        }
    }
}
