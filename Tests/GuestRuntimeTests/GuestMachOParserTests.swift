import XCTest
@testable import EeveeSpotify

final class GuestMachOParserTests: XCTestCase {
    func testReadsThinMachO64AndEssentialCommands() throws {
        let data = MachOFixture.thinSlice(cpuSubtype: 2)
        let slice = try XCTUnwrap(GuestMachOParser().parse(data: data).first)

        XCTAssertEqual(slice.format, .machO64)
        XCTAssertEqual(slice.byteOrder, .little)
        XCTAssertEqual(slice.cpuType, 0x0100000c)
        XCTAssertEqual(slice.cpuSubtype, 2)
        XCTAssertEqual(slice.commandCount, 5)
        XCTAssertEqual(slice.loadCommands.map(\.kind), [.segment64, .loadDylib, .rpath, .uuid, .codeSignature])
        XCTAssertEqual(slice.loadCommands[0].segmentName, "__TEXT")
        XCTAssertEqual(slice.segments.count, 1)
        let text = try XCTUnwrap(slice.segments.first)
        XCTAssertEqual(text.name, "__TEXT")
        XCTAssertEqual(text.virtualAddress, 0x1000)
        XCTAssertEqual(text.virtualSize, 0x1000)
        XCTAssertEqual(text.fileOffset, 0)
        XCTAssertEqual(text.fileSize, 0x140)
        XCTAssertEqual(text.maximumProtection, 7)
        XCTAssertEqual(text.initialProtection, 5)
        XCTAssertEqual(text.sections.count, 1)
        XCTAssertEqual(text.sections[0].sectionName, "__text")
        XCTAssertEqual(text.sections[0].segmentName, "__TEXT")
        XCTAssertEqual(text.sections[0].address, 0x1000)
        XCTAssertEqual(text.sections[0].size, 0x20)
        XCTAssertEqual(text.sections[0].fileOffset, 0x100)
        XCTAssertEqual(text.sections[0].alignment, 2)
        XCTAssertEqual(text.sections[0].flags, 0x80000400)
        XCTAssertEqual(slice.loadCommands[1].name, "@rpath/SpotifyFramework")
        XCTAssertEqual(slice.loadCommands[2].name, "@executable_path/Frameworks")
        XCTAssertEqual(slice.loadCommands[3].uuid, Data((0..<16).map(UInt8.init)))
        XCTAssertEqual(slice.loadCommands[4].dataOffset, 0x1234)
        XCTAssertEqual(slice.loadCommands[4].dataSize, 0x40)
    }

    func testReadsUniversalFatMachOWithTwoSlices() throws {
        let first = MachOFixture.thinSlice(cpuSubtype: 0)
        let second = MachOFixture.thinSlice(cpuSubtype: 2)
        let data = MachOFixture.fat(slices: [first, second])
        let slices = try GuestMachOParser().parse(data: data)

        XCTAssertEqual(slices.count, 2)
        let firstOffset = UInt64(8 + 2 * 20)
        XCTAssertEqual(slices.map(\.offset), [firstOffset, firstOffset + UInt64(first.count)])
        XCTAssertEqual(slices.map(\.size), [UInt64(first.count), UInt64(second.count)])
        XCTAssertEqual(slices.map(\.cpuSubtype), [0, 2])
    }

    func testRejectsTruncatedLoadCommand() {
        var data = MachOFixture.thinSlice(cpuSubtype: 2)
        data[36] = 4 // first load command cmdsize, below the required 8 bytes

        XCTAssertThrowsError(try GuestMachOParser().parse(data: data)) { error in
            XCTAssertEqual(error as? GuestMachOParserError, .invalidLoadCommand(offset: 32, size: 4))
        }
    }

    func testParsesFromFileWithoutExecutingIt() throws {
        let fileURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("guest-runtime-mach-o-\(UUID().uuidString)")
        let data = MachOFixture.thinSlice(cpuSubtype: 2)
        defer { try? FileManager.default.removeItem(at: fileURL) }
        try data.write(to: fileURL, options: .atomic)

        let slices = try GuestMachOParser().parse(fileURL: fileURL)
        XCTAssertEqual(slices.count, 1)
        XCTAssertEqual(slices[0].commandCount, 5)
    }

    func testRejectsSegmentFileRangeOutsideSlice() {
        var data = MachOFixture.thinSlice(cpuSubtype: 2)
        MachOFixture.appendLE64(UInt64.max, to: &data, at: 32 + 48)

        XCTAssertThrowsError(try GuestMachOParser().parse(data: data)) { error in
            guard let parserError = error as? GuestMachOParserError,
                  case .invalidFileRange(let context, _, _, _) = parserError else {
                return XCTFail("Unexpected error: \(error)")
            }
            XCTAssertEqual(context, "segment")
        }
    }

    func testRejectsSectionFileRangeOutsideSlice() {
        var data = MachOFixture.thinSlice(cpuSubtype: 2)
        // First section starts at the segment command offset + 72.
        MachOFixture.appendLE64(UInt64.max, to: &data, at: 32 + 72 + 40)

        XCTAssertThrowsError(try GuestMachOParser().parse(data: data)) { error in
            guard let parserError = error as? GuestMachOParserError,
                  case .invalidFileRange(let context, _, _, _) = parserError else {
                return XCTFail("Unexpected error: \(error)")
            }
            XCTAssertEqual(context, "section __TEXT,__text")
        }
    }
}

private enum MachOFixture {
    static func thinSlice(cpuSubtype: UInt32) -> Data {
        var data = Data(repeating: 0, count: 32)
        appendLE(0xfeedfacf, to: &data, at: 0)
        appendLE(0x0100000c, to: &data, at: 4)
        appendLE(cpuSubtype, to: &data, at: 8)
        appendLE(2, to: &data, at: 12) // MH_EXECUTE

        let commands = segmentCommand() + dylibCommand() + rpathCommand() + uuidCommand() + codeSignatureCommand()
        appendLE(5, to: &data, at: 16)
        appendLE(UInt32(commands.count), to: &data, at: 20)
        data.append(contentsOf: commands)
        return data
    }

    static func fat(slices: [Data]) -> Data {
        var data = Data()
        appendBE(0xcafebabe, to: &data)
        appendBE(UInt32(slices.count), to: &data)
        var offset = UInt32(8 + slices.count * 20)
        for slice in slices {
            appendBE(0x0100000c, to: &data)
            appendBE(2, to: &data)
            appendBE(offset, to: &data)
            appendBE(UInt32(slice.count), to: &data)
            appendBE(2, to: &data) // 2^2 alignment
            offset += UInt32(slice.count)
        }
        for slice in slices { data.append(contentsOf: slice) }
        return data
    }

    static func segmentCommand() -> [UInt8] {
        var bytes = command(0x19, size: 152)
        bytes.append(contentsOf: Array("__TEXT".utf8))
        bytes.append(0)
        bytes.append(contentsOf: Array(repeating: 0, count: 16 - 7))
        appendLE64(0x1000, to: &bytes, at: 24)
        appendLE64(0x1000, to: &bytes, at: 32)
        appendLE64(0, to: &bytes, at: 40)
        appendLE64(0x140, to: &bytes, at: 48)
        appendLE(7, to: &bytes, at: 56)
        appendLE(5, to: &bytes, at: 60)
        appendLE(1, to: &bytes, at: 64)
        appendLE(0, to: &bytes, at: 68)

        var section = [UInt8](repeating: 0, count: 80)
        writeCString("__text", to: &section, at: 0, length: 16)
        writeCString("__TEXT", to: &section, at: 16, length: 16)
        appendLE64(0x1000, to: &section, at: 32)
        appendLE64(0x20, to: &section, at: 40)
        appendLE(0x100, to: &section, at: 48)
        appendLE(2, to: &section, at: 52)
        appendLE(0, to: &section, at: 56)
        appendLE(0, to: &section, at: 60)
        appendLE(0x80000400, to: &section, at: 64)
        appendLE(0, to: &section, at: 68)
        appendLE(0, to: &section, at: 72)
        appendLE(0, to: &section, at: 76)
        bytes.append(contentsOf: section)
        return bytes
    }

    static func dylibCommand() -> [UInt8] {
        var bytes = command(0xc, size: 48)
        appendLE(24, to: &bytes, at: 8)
        bytes.append(contentsOf: Array("@rpath/SpotifyFramework".utf8) + [0])
        bytes.append(contentsOf: Array(repeating: 0, count: 48 - bytes.count))
        return bytes
    }

    static func rpathCommand() -> [UInt8] {
        var bytes = command(0x8000001c, size: 48)
        appendLE(12, to: &bytes, at: 8)
        bytes.append(contentsOf: Array("@executable_path/Frameworks".utf8) + [0])
        bytes.append(contentsOf: Array(repeating: 0, count: 48 - bytes.count))
        return bytes
    }

    static func uuidCommand() -> [UInt8] {
        command(0x1b, size: 24) + Array(0..<16)
    }

    static func codeSignatureCommand() -> [UInt8] {
        var bytes = command(0x1d, size: 16)
        appendLE(0x1234, to: &bytes, at: 8)
        appendLE(0x40, to: &bytes, at: 12)
        return bytes
    }

    static func command(_ command: UInt32, size: UInt32) -> [UInt8] {
        var bytes = [UInt8](repeating: 0, count: 8)
        appendLE(command, to: &bytes, at: 0)
        appendLE(size, to: &bytes, at: 4)
        return bytes
    }

    static func appendLE(_ value: UInt32, to data: inout Data, at offset: Int? = nil) {
        let bytes = [UInt8(value & 0xff), UInt8((value >> 8) & 0xff), UInt8((value >> 16) & 0xff), UInt8((value >> 24) & 0xff)]
        if let offset {
            for (index, byte) in bytes.enumerated() { data[offset + index] = byte }
        } else { data.append(contentsOf: bytes) }
    }

    static func appendLE(_ value: UInt32, to data: inout [UInt8], at offset: Int? = nil) {
        let bytes = [UInt8(value & 0xff), UInt8((value >> 8) & 0xff), UInt8((value >> 16) & 0xff), UInt8((value >> 24) & 0xff)]
        if let offset {
            for (index, byte) in bytes.enumerated() { data[offset + index] = byte }
        } else { data.append(contentsOf: bytes) }
    }

    static func appendLE64(_ value: UInt64, to data: inout Data, at offset: Int? = nil) {
        let bytes = [
            UInt8(value & 0xff), UInt8((value >> 8) & 0xff),
            UInt8((value >> 16) & 0xff), UInt8((value >> 24) & 0xff),
            UInt8((value >> 32) & 0xff), UInt8((value >> 40) & 0xff),
            UInt8((value >> 48) & 0xff), UInt8((value >> 56) & 0xff)
        ]
        if let offset {
            for (index, byte) in bytes.enumerated() { data[offset + index] = byte }
        } else { data.append(contentsOf: bytes) }
    }

    static func appendLE64(_ value: UInt64, to data: inout [UInt8], at offset: Int? = nil) {
        let bytes = [
            UInt8(value & 0xff), UInt8((value >> 8) & 0xff),
            UInt8((value >> 16) & 0xff), UInt8((value >> 24) & 0xff),
            UInt8((value >> 32) & 0xff), UInt8((value >> 40) & 0xff),
            UInt8((value >> 48) & 0xff), UInt8((value >> 56) & 0xff)
        ]
        if let offset {
            for (index, byte) in bytes.enumerated() { data[offset + index] = byte }
        } else { data.append(contentsOf: bytes) }
    }

    static func writeCString(_ value: String, to data: inout [UInt8], at offset: Int, length: Int) {
        let bytes = Array(value.utf8)
        for index in 0..<min(bytes.count, length - 1) { data[offset + index] = bytes[index] }
        data[offset + min(bytes.count, length - 1)] = 0
    }

    static func appendBE(_ value: UInt32, to data: inout Data) {
        data.append(contentsOf: [UInt8((value >> 24) & 0xff), UInt8((value >> 16) & 0xff), UInt8((value >> 8) & 0xff), UInt8(value & 0xff)])
    }
}
