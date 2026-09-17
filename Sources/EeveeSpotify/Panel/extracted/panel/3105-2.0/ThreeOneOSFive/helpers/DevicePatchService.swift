import Foundation

enum DevicePatchService {
    private static let hostedAccessLock = NSLock()
    private static var hostedAccessActivated = false

    static func apply(project: PatchProject) throws -> PatchTransactionReceipt {
        let bundleIDs = orderedBundleIdentifiers(in: project)
        return try withResolvedContainers(bundleIDs: bundleIDs) { roots in
            try PatchTransaction.apply(
                project: project,
                backupRoot: try PatchProjectLibrary.backupRootURL(),
                containerResolver: { bundleID in
                    guard let root = roots[bundleID] else {
                        throw PatchPackageError.targetAppUnavailable(bundleID)
                    }
                    return root
                }
            )
        }
    }

    static func inspectRestore(receipt: PatchTransactionReceipt) throws -> PatchRestoreInspection {
        let bundleIDs = try PatchTransaction.requiredBundleIdentifiers(for: receipt)
        return try withResolvedContainers(bundleIDs: bundleIDs) { roots in
            try PatchTransaction.inspectRestore(
                receipt: receipt,
                containerResolver: { bundleID in
                    guard let root = roots[bundleID] else {
                        throw PatchPackageError.targetAppUnavailable(bundleID)
                    }
                    return root
                }
            )
        }
    }

    static func restore(
        receipt: PatchTransactionReceipt,
        allowChangedTargets: Bool = false
    ) throws {
        let bundleIDs = try PatchTransaction.requiredBundleIdentifiers(for: receipt)
        try withResolvedContainers(bundleIDs: bundleIDs) { roots in
            try PatchTransaction.restore(
                receipt: receipt,
                allowChangedTargets: allowChangedTargets,
                containerResolver: { bundleID in
                    guard let root = roots[bundleID] else {
                        throw PatchPackageError.targetAppUnavailable(bundleID)
                    }
                    return root
                }
            )
        }
    }

    static func resetToAppliedState(
        receipt: PatchTransactionReceipt,
        project: PatchProject
    ) throws {
        let bundleIDs = try PatchTransaction.requiredBundleIdentifiers(for: receipt)
        try withResolvedContainers(bundleIDs: bundleIDs) { roots in
            try PatchTransaction.resetToAppliedState(
                receipt: receipt,
                fallbackProject: project,
                containerResolver: { bundleID in
                    guard let root = roots[bundleID] else {
                        throw PatchPackageError.targetAppUnavailable(bundleID)
                    }
                    return root
                }
            )
        }
    }

    static func latestReceipt(projectID: UUID) -> PatchTransactionReceipt? {
        guard let backupRoot = try? PatchProjectLibrary.backupRootURL() else { return nil }
        return PatchTransaction.latestReceipt(projectID: projectID, backupRoot: backupRoot)
    }

    private static func orderedBundleIdentifiers(in project: PatchProject) -> [String] {
        project.allBundleIdentifiers
    }

    private static func withResolvedContainers<T>(
        bundleIDs: [String],
        operation: ([String: URL]) throws -> T
    ) throws -> T {
        if let roots = resolveContainers(bundleIDs: bundleIDs) {
            return try operation(roots)
        }

        if HostedPanelContext.isHostedInSpotify,
           activateHostedAccessOnDemand(),
           let roots = resolveContainers(bundleIDs: bundleIDs) {
            return try operation(roots)
        }

        let missingBundleID = bundleIDs.first {
            ContainerStore.resolveAppContainerPath(bundleID: $0) == nil
        } ?? bundleIDs.first ?? "unknown"
        throw PatchPackageError.targetAppUnavailable(missingBundleID)
    }

    private static func resolveContainers(bundleIDs: [String]) -> [String: URL]? {
        var roots: [String: URL] = [:]
        for bundleID in bundleIDs {
            guard let path = ContainerStore.resolveAppContainerPath(bundleID: bundleID),
                  ContainerStore.isApplicationContainerPath(path) else {
                return nil
            }
            roots[bundleID] = PatchPathValidator.canonicalFileURL(
                URL(fileURLWithPath: path, isDirectory: true)
            )
        }
        return roots
    }

    private static func activateHostedAccessOnDemand() -> Bool {
        hostedAccessLock.lock()
        defer { hostedAccessLock.unlock() }

        if hostedAccessActivated {
            return true
        }
        if KernelExploit.requiresSandboxEscape, KernelExploit.hasSandboxAccess() {
            hostedAccessActivated = true
            return true
        }

        let version = AppInfo.versionTuple
        guard ExploitSupportPolicy.isSupported(
            major: version.major,
            minor: version.minor,
            patch: version.patch,
            build: AppInfo.osBuild
        ) else {
            log("patch: hosted access unavailable on this iOS build")
            return false
        }

        log("patch: activating container access on explicit apply command")
        hostedAccessActivated = KernelExploit.run()
        return hostedAccessActivated
    }
}
