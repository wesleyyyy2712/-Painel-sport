import XCTest
@testable import EeveeSpotify

final class GuestRuntimeAnalysisTests: XCTestCase {
    func testResolverReportsMissingAndArchitectureMismatchWithoutLoading() throws {
        let image = try XCTUnwrap(GuestMachOParser().parse(data: analysisFixture()).first)
        var inventory = GuestLibraryInventory()
        inventory.register(GuestLibraryInventoryEntry(logicalName: "@rpath/SpotifyFramework", path: "/Frameworks/SpotifyFramework", kind: .framework, cpuType: 0x0100000c, cpuSubtype: 99, version: nil, exists: true, origin: "synthetic", image: nil))
        let report = GuestDependencyResolver().resolve(image: image, inventory: inventory)
        XCTAssertEqual(report.architectureMismatches, ["@rpath/SpotifyFramework"])
        XCTAssertTrue(report.missing.isEmpty)
    }

    func testGraphDetectsCycleAndStructuralLoaderProducesPlan() throws {
        let image = try XCTUnwrap(GuestMachOParser().parse(data: analysisFixture()).first)
        var graph = GuestDependencyGraph()
        graph.addDependency(from: "A", to: "B")
        graph.addDependency(from: "B", to: "A")
        XCTAssertFalse(graph.cycles().isEmpty)
        let plan = StructuralGuestLoader().preparePlan(image, inventory: GuestLibraryInventory())
        XCTAssertEqual(plan.graph.nodes.first?.identifier, "main")
        XCTAssertTrue(plan.diagnostics.contains { $0.contains("missing dependency") })
        XCTAssertEqual(StructuralGuestLoader().validate(image), .valid)
    }

    private func analysisFixture() -> Data {
        var data = Data(repeating: 0, count: 32)
        putLE(0xfeedfacf, &data, 0); putLE(0x0100000c, &data, 4); putLE(2, &data, 8); putLE(2, &data, 12)
        let command = dylibCommand()
        putLE(1, &data, 16); putLE(UInt32(command.count), &data, 20)
        data.append(contentsOf: command)
        return data
    }
    private func dylibCommand() -> [UInt8] {
        var bytes = [UInt8](repeating: 0, count: 48)
        putLE(0xc, &bytes, 0); putLE(48, &bytes, 4); putLE(24, &bytes, 8)
        bytes[24..<48] = Array("@rpath/SpotifyFramework".utf8) + [0]
        return bytes
    }
    private func putLE(_ value: UInt32, _ data: inout Data, _ offset: Int) {
        for i in 0..<4 { data[offset+i] = UInt8((value >> UInt32(i*8)) & 0xff) }
    }
    private func putLE(_ value: UInt32, _ data: inout [UInt8], _ offset: Int) {
        for i in 0..<4 { data[offset+i] = UInt8((value >> UInt32(i*8)) & 0xff) }
    }
}
