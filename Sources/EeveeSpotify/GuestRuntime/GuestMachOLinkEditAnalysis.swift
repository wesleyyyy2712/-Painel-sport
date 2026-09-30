import Foundation

struct GuestMachOSymbol: Equatable, Sendable {
    let stringIndex: UInt32
    let type: UInt8
    let section: UInt8
    let description: UInt16
    let value: UInt64
    let name: String?
}

struct GuestMachOSymbolTableDescription: Equatable, Sendable {
    let symbolOffset: UInt64
    let symbolCount: UInt64
    let stringOffset: UInt64
    let stringSize: UInt64
    let symbols: [GuestMachOSymbol]
}

enum GuestMachOLinkEditAnalysisError: Error, LocalizedError, Equatable {
    case invalidRange(context: String)
    case invalidAlignment(context: String)
    case malformedULEB(offset: Int)
    case malformedExportsTrie(offset: Int, reason: String)
    case malformedChainedFixups(reason: String)
    var errorDescription: String? {
        switch self {
        case .invalidRange(let context): return "Invalid LINKEDIT range: \(context)"
        case .invalidAlignment(let context): return "Invalid LINKEDIT alignment: \(context)"
        case .malformedULEB(let offset): return "Malformed ULEB at offset \(offset)"
        case .malformedExportsTrie(let offset, let reason): return "Malformed exports trie at \(offset): \(reason)"
        case .malformedChainedFixups(let reason): return "Malformed chained fixups: \(reason)"
        }
    }
}

struct GuestMachOSymbolTableParser: Sendable {
    func parse(data: Data, symbolOffset: UInt64, symbolCount: UInt64, stringOffset: UInt64, stringSize: UInt64, is64Bit: Bool) throws -> GuestMachOSymbolTableDescription {
        let entrySize: UInt64 = is64Bit ? 16 : 12
        let symbolBytes = try checkedProduct(symbolCount, entrySize, context: "symbol table")
        try validateRange(offset: symbolOffset, size: symbolBytes, dataCount: data.count, context: "symbol table")
        try validateRange(offset: stringOffset, size: stringSize, dataCount: data.count, context: "string table")
        var symbols: [GuestMachOSymbol] = []
        for index in 0..<symbolCount {
            let base = Int(symbolOffset + index * entrySize)
            let stringIndex = try read32(data, base)
            let type = data[base + 4]
            let section = data[base + 5]
            let description = try read16(data, base + 6)
            let value = is64Bit ? try read64(data, base + 8) : UInt64(try read32(data, base + 8))
            let name = try string(data, offset: stringOffset, size: stringSize, index: stringIndex)
            symbols.append(GuestMachOSymbol(stringIndex: stringIndex, type: type, section: section, description: description, value: value, name: name))
        }
        return GuestMachOSymbolTableDescription(symbolOffset: symbolOffset, symbolCount: symbolCount, stringOffset: stringOffset, stringSize: stringSize, symbols: symbols)
    }
    private func string(_ data: Data, offset: UInt64, size: UInt64, index: UInt32) throws -> String? {
        guard UInt64(index) < size else { return nil }
        let start = Int(offset + UInt64(index)); let end = Int(offset + size)
        let bytes = data[start..<end]; let terminator = bytes.firstIndex(of: 0) ?? bytes.endIndex
        return String(decoding: bytes[..<terminator], as: UTF8.self)
    }
    private func validateRange(offset: UInt64, size: UInt64, dataCount: Int, context: String) throws {
        guard offset <= UInt64(dataCount), size <= UInt64(dataCount) - offset else { throw GuestMachOLinkEditAnalysisError.invalidRange(context: context) }
    }
    private func checkedProduct(_ a: UInt64, _ b: UInt64, context: String) throws -> UInt64 {
        guard b == 0 || a <= UInt64.max / b else { throw GuestMachOLinkEditAnalysisError.invalidRange(context: context) }; return a * b
    }
    private func read16(_ d: Data, _ o: Int) throws -> UInt16 { guard o >= 0 && o + 2 <= d.count else { throw GuestMachOLinkEditAnalysisError.invalidRange(context: "u16") }; return UInt16(d[o]) | UInt16(d[o+1]) << 8 }
    private func read32(_ d: Data, _ o: Int) throws -> UInt32 { guard o >= 0 && o + 4 <= d.count else { throw GuestMachOLinkEditAnalysisError.invalidRange(context: "u32") }; return UInt32(d[o]) | UInt32(d[o+1]) << 8 | UInt32(d[o+2]) << 16 | UInt32(d[o+3]) << 24 }
    private func read64(_ d: Data, _ o: Int) throws -> UInt64 { UInt64(try read32(d,o)) | UInt64(try read32(d,o+4)) << 32 }
}

struct GuestMachOExport: Equatable, Sendable { let name: String; let flags: UInt64; let address: UInt64? }

struct GuestMachOExportsTrieParser: Sendable {
    func parse(data: Data, maxDepth: Int = 256) throws -> [GuestMachOExport] {
        var result: [GuestMachOExport] = []; var visited = Set<Int>()
        func walk(_ offset: Int, _ prefix: String, _ depth: Int) throws {
            guard depth <= maxDepth, offset >= 0, offset < data.count else { throw GuestMachOLinkEditAnalysisError.malformedExportsTrie(offset: offset, reason: "depth or offset out of bounds") }
            guard visited.insert(offset).inserted else { throw GuestMachOLinkEditAnalysisError.malformedExportsTrie(offset: offset, reason: "cycle or repeated node") }
            var cursor = offset; let terminalSize = try readULEB(data, &cursor)
            guard terminalSize <= UInt64(Int.max - cursor) else { throw GuestMachOLinkEditAnalysisError.malformedExportsTrie(offset: offset, reason: "terminal size overflow") }
            let terminalEnd = cursor + Int(terminalSize); guard terminalEnd <= data.count else { throw GuestMachOLinkEditAnalysisError.malformedExportsTrie(offset: offset, reason: "terminal out of bounds") }
            if terminalSize > 0 { let flags = try readULEB(data, &cursor); let address = try readULEB(data, &cursor); result.append(GuestMachOExport(name: prefix, flags: flags, address: address)) }
            cursor = terminalEnd; guard cursor < data.count else { throw GuestMachOLinkEditAnalysisError.malformedExportsTrie(offset: offset, reason: "missing child count") }
            let childCount = Int(data[cursor]); cursor += 1
            for _ in 0..<childCount { var bytes: [UInt8] = []; while cursor < data.count && data[cursor] != 0 { bytes.append(data[cursor]); cursor += 1 }; guard cursor < data.count else { throw GuestMachOLinkEditAnalysisError.malformedExportsTrie(offset: cursor, reason: "unterminated edge") }; cursor += 1; let child = try readULEB(data, &cursor); try walk(Int(child), prefix + String(decoding: bytes, as: UTF8.self), depth + 1) }
        }
        if !data.isEmpty { try walk(0, "", 0) }; return result
    }
    private func readULEB(_ data: Data, _ cursor: inout Int) throws -> UInt64 { var value: UInt64 = 0; var shift: UInt64 = 0; while cursor < data.count && shift < 64 { let byte=data[cursor]; cursor += 1; value |= UInt64(byte & 0x7f) << shift; if byte & 0x80 == 0 { return value }; shift += 7 }; throw GuestMachOLinkEditAnalysisError.malformedULEB(offset: cursor) }
}

struct GuestMachOChainedFixupsDescription: Equatable, Sendable {
    let version: UInt32
    let startsOffset: UInt32
    let importsOffset: UInt32
    let symbolsOffset: UInt32
    let importsCount: UInt32
    let importsFormat: UInt32
    let symbolsFormat: UInt32
}

struct GuestMachOChainedFixupsParser: Sendable {
    func parse(data: Data) throws -> GuestMachOChainedFixupsDescription {
        guard data.count >= 28 else { throw GuestMachOLinkEditAnalysisError.malformedChainedFixups(reason: "header truncated") }
        let version=try read32(data,0); let starts=try read32(data,4); let imports=try read32(data,8); let symbols=try read32(data,12); let count=try read32(data,16); let importFormat=try read32(data,20); let symbolFormat=try read32(data,24)
        for (name, offset) in [("starts",starts),("imports",imports),("symbols",symbols)] { guard UInt64(offset) <= UInt64(data.count) else { throw GuestMachOLinkEditAnalysisError.malformedChainedFixups(reason: "\(name) offset out of bounds") } }
        return GuestMachOChainedFixupsDescription(version: version, startsOffset: starts, importsOffset: imports, symbolsOffset: symbols, importsCount: count, importsFormat: importFormat, symbolsFormat: symbolFormat)
    }
    private func read32(_ d: Data, _ o: Int) throws -> UInt32 { guard o >= 0 && o+4 <= d.count else { throw GuestMachOLinkEditAnalysisError.invalidRange(context: "fixups header") }; return UInt32(d[o]) | UInt32(d[o+1]) << 8 | UInt32(d[o+2]) << 16 | UInt32(d[o+3]) << 24 }
}
