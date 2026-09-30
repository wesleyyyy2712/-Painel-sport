import XCTest
@testable import EeveeSpotify

final class GuestMachOLinkEditAnalysisTests: XCTestCase {
    func testReads64BitSymbolAndNameWithoutResolvingIt() throws {
        var data = Data(repeating: 0, count: 21)
        put32(1, &data, 0)
        data[4] = 0x0f
        data[5] = 1
        put16(0, &data, 6)
        put64(0x1234, &data, 8)
        data[16..<21] = Array([UInt8(0), 116, 101, 115, 116])
        let table = try GuestMachOSymbolTableParser().parse(data: data, symbolOffset: 0, symbolCount: 1, stringOffset: 16, stringSize: 5, is64Bit: true)
        XCTAssertEqual(table.symbols.first?.name, "test")
        XCTAssertEqual(table.symbols.first?.value, 0x1234)
    }

    func testRejectsSymbolTableRangeOutsideData() {
        XCTAssertThrowsError(try GuestMachOSymbolTableParser().parse(data: Data(repeating: 0, count: 8), symbolOffset: 4, symbolCount: 1, stringOffset: 0, stringSize: 1, is64Bit: true))
    }

    func testReadsMinimalExportsTrie() throws {
        let trie = Data([0, 1, 102, 111, 111, 0, 7, 2, 0, 42, 0])
        let exports = try GuestMachOExportsTrieParser().parse(data: trie)
        XCTAssertEqual(exports, [GuestMachOExport(name: "foo", flags: 0, address: 42)])
    }

    func testRejectsExportsTrieCycle() {
        XCTAssertThrowsError(try GuestMachOExportsTrieParser().parse(data: Data([0, 1, 0, 0, 0])))
    }

    func testReadsChainedFixupsHeaderWithoutApplyingFixups() throws {
        var data = Data(repeating: 0, count: 28)
        put32(0, &data, 0); put32(28, &data, 4); put32(28, &data, 8); put32(28, &data, 12); put32(0, &data, 16); put32(1, &data, 20); put32(0, &data, 24)
        let result = try GuestMachOChainedFixupsParser().parse(data: data)
        XCTAssertEqual(result.startsOffset, 28)
        XCTAssertEqual(result.importsFormat, 1)
    }

    func testRejectsChainedFixupsOffsetOutsideBlob() {
        var data = Data(repeating: 0, count: 28)
        put32(0, &data, 0); put32(29, &data, 4)
        XCTAssertThrowsError(try GuestMachOChainedFixupsParser().parse(data: data))
    }

    private func put16(_ value: UInt16, _ data: inout Data, _ offset: Int) { data[offset] = UInt8(value & 0xff); data[offset+1] = UInt8(value >> 8) }
    private func put32(_ value: UInt32, _ data: inout Data, _ offset: Int) { for i in 0..<4 { data[offset+i] = UInt8((value >> UInt32(i*8)) & 0xff) } }
    private func put64(_ value: UInt64, _ data: inout Data, _ offset: Int) { for i in 0..<8 { data[offset+i] = UInt8((value >> UInt64(i*8)) & 0xff) } }
}
