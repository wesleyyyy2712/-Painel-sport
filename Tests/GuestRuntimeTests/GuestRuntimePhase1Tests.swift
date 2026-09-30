import XCTest
@testable import EeveeSpotify

final class GuestRuntimePhase1Tests: XCTestCase {
    private let host = GuestHostIdentity(
        bundleIdentifier: "com.apple.mobile.MobileHouseArrest",
        executableName: "ThreeOneOSFive"
    )
    private let guest = GuestIdentity(
        bundleIdentifier: "com.spotify.client",
        displayName: "Spotify",
        executableName: "Spotify"
    )

    func testHostGuestTargetRemainDistinct() throws {
        let target = GuestTargetIdentity(bundleIdentifier: guest.bundleIdentifier)
        let descriptor = GuestRuntimeDescriptor(
            host: host,
            guest: guest,
            target: target,
            containerIdentifier: "spotify-guest"
        )

        XCTAssertNotEqual(descriptor.host.bundleIdentifier, descriptor.guest.bundleIdentifier)
        XCTAssertNotEqual(descriptor.target?.bundleIdentifier, descriptor.host.bundleIdentifier)
    }

    func testPathLayoutDoesNotUseHostRoot() throws {
        let layout = try GuestPathLayout(rootURL: URL(fileURLWithPath: "/tmp/3105-guests/spotify"))

        let spotifyBundle = try layout.bundleURL(for: guest)
        XCTAssertTrue(spotifyBundle.path.hasSuffix("/Bundle/client.app"))
        XCTAssertTrue(layout.dataURL.path.hasSuffix("/Data"))
        XCTAssertTrue(layout.preferencesURL.path.hasSuffix("/Data/Library/Preferences"))
        XCTAssertFalse(layout.bundleURL.path.hasPrefix("/var/mobile/Containers/Data/Application/"))
    }

    func testRelativePathTraversalIsRejected() throws {
        let layout = try GuestPathLayout(rootURL: URL(fileURLWithPath: "/tmp/3105-guests/spotify"))

        XCTAssertThrowsError(try layout.resolvingGuestRelativePath("../host/secret"))
        XCTAssertThrowsError(try layout.resolvingGuestRelativePath("/absolute/path"))
    }

    func testPrepareDoesNotClaimExecution() throws {
        let root = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("guest-runtime-tests-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: root) }

        let layout = try GuestPathLayout(rootURL: root)
        let runtime = GuestRuntime()
        let descriptor = GuestRuntimeDescriptor(
            host: host,
            guest: guest,
            target: GuestTargetIdentity(bundleIdentifier: guest.bundleIdentifier),
            containerIdentifier: "spotify-guest"
        )

        try runtime.prepare(descriptor: descriptor, layout: layout)
        XCTAssertEqual(runtime.state, .prepared)
        XCTAssertThrowsError(try runtime.start()) { error in
            XCTAssertEqual(error as? GuestRuntimeError, .guestExecutionUnavailable)
        }
        XCTAssertEqual(runtime.state, .loadingUnavailable)
    }
}
