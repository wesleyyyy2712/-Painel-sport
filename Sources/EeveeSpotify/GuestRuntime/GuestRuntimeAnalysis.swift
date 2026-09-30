import Foundation

struct GuestLibraryInventoryEntry: Equatable, Sendable {
    enum LibraryKind: String, Sendable { case dylib, framework, executable, unknown }
    let logicalName: String
    let path: String
    let kind: LibraryKind
    let cpuType: Int32?
    let cpuSubtype: Int32?
    let version: String?
    let exists: Bool
    let origin: String
    let image: GuestMachOSlice?
}

struct GuestLibraryInventory: Sendable {
    private(set) var entries: [GuestLibraryInventoryEntry] = []
    mutating func register(_ entry: GuestLibraryInventoryEntry) { entries.append(entry) }
    func candidates(for name: String) -> [GuestLibraryInventoryEntry] {
        entries.filter { $0.logicalName == name || $0.path == name }
    }
}

enum GuestDependencyResolutionStatus: Equatable, Sendable {
    case found(GuestLibraryInventoryEntry)
    case missing
    case ambiguous([GuestLibraryInventoryEntry])
    case architectureMismatch([GuestLibraryInventoryEntry])
}

struct GuestDependencyResolution: Equatable, Sendable {
    let dependency: GuestMachODynamicDependency
    let status: GuestDependencyResolutionStatus
    let candidates: [String]
    let reason: String
}

struct GuestResolutionReport: Equatable, Sendable {
    let results: [GuestDependencyResolution]
    let missing: [String]
    let ambiguous: [String]
    let architectureMismatches: [String]
}

protocol GuestDependencyResolving: Sendable {
    func resolve(image: GuestMachOSlice, inventory: GuestLibraryInventory) -> GuestResolutionReport
}

struct GuestDependencyResolver: GuestDependencyResolving {
    func resolve(image: GuestMachOSlice, inventory: GuestLibraryInventory) -> GuestResolutionReport {
        var results: [GuestDependencyResolution] = []
        for dependency in image.dynamicDependencies {
            let candidates = inventory.candidates(for: dependency.name)
            let compatible = candidates.filter { entry in
                guard let cpu = entry.cpuType, let subtype = entry.cpuSubtype else { return true }
                return cpu == image.cpuType && subtype == image.cpuSubtype
            }
            let status: GuestDependencyResolutionStatus
            let reason: String
            if candidates.isEmpty { status = .missing; reason = "no inventory candidate" }
            else if compatible.isEmpty { status = .architectureMismatch(candidates); reason = "all candidates have incompatible architecture" }
            else if compatible.count > 1 { status = .ambiguous(compatible); reason = "more than one compatible candidate" }
            else { status = .found(compatible[0]); reason = "one compatible inventory candidate" }
            results.append(GuestDependencyResolution(dependency: dependency, status: status, candidates: candidates.map(\.path), reason: reason))
        }
        return GuestResolutionReport(
            results: results,
            missing: results.compactMap { if case .missing = $0.status { return $0.dependency.name }; return nil },
            ambiguous: results.compactMap { if case .ambiguous = $0.status { return $0.dependency.name }; return nil },
            architectureMismatches: results.compactMap { if case .architectureMismatch = $0.status { return $0.dependency.name }; return nil }
        )
    }
}

struct GuestDependencyGraph: Equatable, Sendable {
    struct Node: Equatable, Sendable { let identifier: String; let image: GuestMachOSlice? }
    struct Edge: Equatable, Sendable { let from: String; let to: String }
    private(set) var nodes: [Node] = []
    private(set) var edges: [Edge] = []
    mutating func addImage(identifier: String, image: GuestMachOSlice? = nil) { if !nodes.contains(where: { $0.identifier == identifier }) { nodes.append(Node(identifier: identifier, image: image)) } }
    mutating func addDependency(from: String, to: String) { addImage(identifier: from); addImage(identifier: to); if !edges.contains(Edge(from: from, to: to)) { edges.append(Edge(from: from, to: to)) } }
    func cycles() -> [[String]] {
        var result: [[String]] = []
        func visit(_ node: String, path: [String]) {
            if let index = path.firstIndex(of: node) { result.append(Array(path[index...]) + [node]); return }
            for edge in edges where edge.from == node { visit(edge.to, path: path + [node]) }
        }
        for node in nodes { visit(node.identifier, path: []) }
        return result
    }
    func analysisOrder() -> [String] { nodes.map(\.identifier) }
}

struct GuestLoadPlan: Equatable, Sendable {
    let image: GuestMachOSlice
    let dependencyReport: GuestResolutionReport?
    let graph: GuestDependencyGraph
    let diagnostics: [String]
}

enum GuestLoaderValidation: Equatable, Sendable { case valid, invalid([String]), unavailable }
protocol GuestLoader: Sendable {
    func validate(_ image: GuestMachOSlice) -> GuestLoaderValidation
    func preparePlan(_ image: GuestMachOSlice, inventory: GuestLibraryInventory) -> GuestLoadPlan
}

struct StructuralGuestLoader: GuestLoader {
    func validate(_ image: GuestMachOSlice) -> GuestLoaderValidation {
        guard image.header.fileType == 2 else { return .invalid(["image is not MH_EXECUTE"]) }
        return .valid
    }
    func preparePlan(_ image: GuestMachOSlice, inventory: GuestLibraryInventory) -> GuestLoadPlan {
        var graph = GuestDependencyGraph()
        graph.addImage(identifier: "main", image: image)
        for dependency in image.dynamicDependencies { graph.addDependency(from: "main", to: dependency.name) }
        let report = GuestDependencyResolver().resolve(image: image, inventory: inventory)
        var diagnostics = report.missing.map { "missing dependency: \($0)" }
        diagnostics += report.ambiguous.map { "ambiguous dependency: \($0)" }
        diagnostics += report.architectureMismatches.map { "architecture mismatch: \($0)" }
        return GuestLoadPlan(image: image, dependencyReport: report, graph: graph, diagnostics: diagnostics)
    }
}
