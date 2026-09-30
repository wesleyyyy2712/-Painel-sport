import Foundation

enum GuestMachOByteOrder: Equatable, Sendable {
    case little
    case big
}

enum GuestMachOFormat: Equatable, Sendable {
    case machO64
}

enum GuestMachOLoadCommandKind: String, Equatable, Sendable {
    case segment64
    case loadDylib
    case idDylib
    case rpath
    case uuid
    case codeSignature
    case chainedFixups
    case other
}

struct GuestMachOSection64: Equatable, Sendable {
    let sectionName: String
    let segmentName: String
    let address: UInt64
    let size: UInt64
    let fileOffset: UInt32
    let alignment: UInt32
    let relocationOffset: UInt32
    let relocationCount: UInt32
    let flags: UInt32
    let reserved1: UInt32
    let reserved2: UInt32
    let reserved3: UInt32
}

struct GuestMachOSegment64: Equatable, Sendable {
    let name: String
    let virtualAddress: UInt64
    let virtualSize: UInt64
    let fileOffset: UInt64
    let fileSize: UInt64
    let maximumProtection: Int32
    let initialProtection: Int32
    let flags: UInt32
    let sections: [GuestMachOSection64]
}

struct GuestMachOLoadCommand: Equatable, Sendable {
    let command: UInt32
    let size: UInt32
    let kind: GuestMachOLoadCommandKind
    let name: String?
    let segmentName: String?
    let dataOffset: UInt32?
    let dataSize: UInt32?
    let uuid: Data?
    let segment: GuestMachOSegment64?
}

struct GuestMachOSlice: Equatable, Sendable {
    let offset: UInt64
    let size: UInt64
    let format: GuestMachOFormat
    let byteOrder: GuestMachOByteOrder
    let cpuType: Int32
    let cpuSubtype: Int32
    let fileType: UInt32
    let commandCount: UInt32
    let commandsSize: UInt32
    let loadCommands: [GuestMachOLoadCommand]
    let segments: [GuestMachOSegment64]
}

enum GuestMachOParserError: Error, LocalizedError, Equatable {
    case truncated(offset: Int, required: Int, available: Int)
    case invalidMagic(offset: Int)
    case unsupportedFormat(String)
    case invalidFatHeader
    case invalidSlice(offset: UInt64, size: UInt64)
    case invalidLoadCommand(offset: Int, size: UInt32)
    case loadCommandsOutOfBounds
    case invalidStringOffset(command: UInt32, offset: UInt32)
    case invalidFileRange(context: String, offset: UInt64, size: UInt64, sliceSize: UInt64)
    case invalidAddressRange(context: String)

    var errorDescription: String? {
        switch self {
        case .truncated(let offset, let required, let available):
            return "Mach-O data truncated at \(offset): required \(required), available \(available)"
        case .invalidMagic(let offset):
            return "Invalid Mach-O magic at offset \(offset)"
        case .unsupportedFormat(let value):
            return "Unsupported Mach-O format: \(value)"
        case .invalidFatHeader:
            return "Invalid FAT Mach-O header"
        case .invalidSlice(let offset, let size):
            return "Invalid Mach-O slice offset=\(offset) size=\(size)"
        case .invalidLoadCommand(let offset, let size):
            return "Invalid load command at \(offset), size=\(size)"
        case .loadCommandsOutOfBounds:
            return "Mach-O load commands exceed slice bounds"
        case .invalidStringOffset(let command, let offset):
            return "Invalid string offset \(offset) in load command \(command)"
        case .invalidFileRange(let context, let offset, let size, let sliceSize):
            return "Invalid \(context) file range offset=\(offset) size=\(size) sliceSize=\(sliceSize)"
        case .invalidAddressRange(let context):
            return "Invalid \(context) virtual address range"
        }
    }
}

struct GuestMachOParser: Sendable {
    private static let fatMagic: UInt32 = 0xcafebabe
    private static let fatMagic64: UInt32 = 0xcafebabf
    private static let machOMagic64: UInt32 = 0xfeedfacf
    private static let machOCigam64: UInt32 = 0xcffaedfe

    private static let lcSegment64: UInt32 = 0x19
    private static let lcLoadDylib: UInt32 = 0xc
    private static let lcIDDylib: UInt32 = 0xd
    private static let lcUUID: UInt32 = 0x1b
    private static let lcCodeSignature: UInt32 = 0x1d
    private static let lcRPath: UInt32 = 0x8000001c
    private static let lcDyldChainedFixups: UInt32 = 0x80000034

    func parse(data: Data) throws -> [GuestMachOSlice] {
        guard data.count >= 4 else {
            throw GuestMachOParserError.truncated(offset: 0, required: 4, available: data.count)
        }

        let bigMagic = try readUInt32(data, at: 0, order: .big)
        if bigMagic == Self.fatMagic || bigMagic == Self.fatMagic64 {
            return try parseFat(data: data, is64: bigMagic == Self.fatMagic64)
        }

        return [try parseThin(data: data, offset: 0, size: UInt64(data.count))]
    }

    /// Lê bytes do arquivo e somente analisa sua estrutura; não faz `exec`, `dlopen`
    /// nem qualquer outra operação de carregamento do binário.
    func parse(fileURL: URL) throws -> [GuestMachOSlice] {
        try parse(data: Data(contentsOf: fileURL, options: .mappedIfSafe))
    }

    private func parseFat(data: Data, is64: Bool) throws -> [GuestMachOSlice] {
        let headerSize = is64 ? 8 : 8
        guard data.count >= headerSize else { throw GuestMachOParserError.invalidFatHeader }
        let count = try readUInt32(data, at: 4, order: .big)
        guard count > 0, count <= 128 else { throw GuestMachOParserError.invalidFatHeader }

        let entrySize = is64 ? 32 : 20
        let tableSize = headerSize + Int(count) * entrySize
        guard tableSize <= data.count else { throw GuestMachOParserError.invalidFatHeader }

        var slices: [GuestMachOSlice] = []
        for index in 0..<Int(count) {
            let base = headerSize + index * entrySize
            let offset: UInt64
            let size: UInt64
            if is64 {
                offset = try readUInt64(data, at: base + 8, order: .big)
                size = try readUInt64(data, at: base + 16, order: .big)
            } else {
                offset = UInt64(try readUInt32(data, at: base + 8, order: .big))
                size = UInt64(try readUInt32(data, at: base + 12, order: .big))
            }
            guard offset <= UInt64(data.count), size <= UInt64(data.count) - offset else {
                throw GuestMachOParserError.invalidSlice(offset: offset, size: size)
            }
            slices.append(try parseThin(data: data, offset: Int(offset), size: size))
        }
        return slices
    }

    private func parseThin(data: Data, offset: Int, size: UInt64) throws -> GuestMachOSlice {
        guard size >= 32, offset >= 0, offset <= data.count,
              size <= UInt64(data.count - offset) else {
            throw GuestMachOParserError.invalidSlice(offset: UInt64(max(offset, 0)), size: size)
        }

        let littleMagic = try readUInt32(data, at: offset, order: .little)
        let byteOrder: GuestMachOByteOrder
        switch littleMagic {
        case Self.machOMagic64:
            byteOrder = .little
        case Self.machOCigam64:
            byteOrder = .big
        default:
            throw GuestMachOParserError.invalidMagic(offset: offset)
        }

        let cpuType = Int32(bitPattern: try readUInt32(data, at: offset + 4, order: byteOrder))
        let cpuSubtype = Int32(bitPattern: try readUInt32(data, at: offset + 8, order: byteOrder))
        let fileType = try readUInt32(data, at: offset + 12, order: byteOrder)
        let commandCount = try readUInt32(data, at: offset + 16, order: byteOrder)
        let commandsSize = try readUInt32(data, at: offset + 20, order: byteOrder)
        let commandsStart = offset + 32
        let sliceEnd = offset + Int(size)
        let commandsEnd = commandsStart + Int(commandsSize)
        guard commandsStart <= sliceEnd, commandsEnd >= commandsStart, commandsEnd <= sliceEnd else {
            throw GuestMachOParserError.loadCommandsOutOfBounds
        }

        var commands: [GuestMachOLoadCommand] = []
        var commandOffset = commandsStart
        for _ in 0..<commandCount {
            guard commandOffset + 8 <= commandsEnd else {
                throw GuestMachOParserError.invalidLoadCommand(offset: commandOffset, size: 0)
            }
            let command = try readUInt32(data, at: commandOffset, order: byteOrder)
            let commandSize = try readUInt32(data, at: commandOffset + 4, order: byteOrder)
            guard commandSize >= 8, commandOffset + Int(commandSize) <= commandsEnd else {
                throw GuestMachOParserError.invalidLoadCommand(offset: commandOffset, size: commandSize)
            }
            commands.append(try parseCommand(
                data: data,
                offset: commandOffset,
                command: command,
                size: commandSize,
                order: byteOrder,
                sliceSize: size
            ))
            commandOffset += Int(commandSize)
        }
        guard commandOffset == commandsEnd else {
            throw GuestMachOParserError.invalidLoadCommand(offset: commandOffset, size: 0)
        }

        let segments = commands.compactMap(\.segment)
        return GuestMachOSlice(
            offset: UInt64(offset),
            size: size,
            format: .machO64,
            byteOrder: byteOrder,
            cpuType: cpuType,
            cpuSubtype: cpuSubtype,
            fileType: fileType,
            commandCount: commandCount,
            commandsSize: commandsSize,
            loadCommands: commands,
            segments: segments
        )
    }

    private func parseCommand(
        data: Data,
        offset: Int,
        command: UInt32,
        size: UInt32,
        order: GuestMachOByteOrder,
        sliceSize: UInt64
    ) throws -> GuestMachOLoadCommand {
        let base = offset
        let kind: GuestMachOLoadCommandKind
        switch command {
        case Self.lcSegment64: kind = .segment64
        case Self.lcLoadDylib: kind = .loadDylib
        case Self.lcIDDylib: kind = .idDylib
        case Self.lcRPath: kind = .rpath
        case Self.lcUUID: kind = .uuid
        case Self.lcCodeSignature: kind = .codeSignature
        case Self.lcDyldChainedFixups: kind = .chainedFixups
        default: kind = .other
        }

        var name: String?
        var segmentName: String?
        var dataOffset: UInt32?
        var dataSize: UInt32?
        var uuid: Data?

        if kind == .segment64 {
            guard size >= 72 else { throw GuestMachOParserError.invalidLoadCommand(offset: offset, size: size) }
            let segment = try parseSegment64(
                data: data,
                offset: base,
                commandSize: size,
                order: order,
                sliceSize: sliceSize
            )
            segmentName = segment.name
            return GuestMachOLoadCommand(
                command: command,
                size: size,
                kind: kind,
                name: nil,
                segmentName: segment.name,
                dataOffset: nil,
                dataSize: nil,
                uuid: nil,
                segment: segment
            )
        } else if kind == .loadDylib || kind == .idDylib {
            guard size >= 24 else { throw GuestMachOParserError.invalidLoadCommand(offset: offset, size: size) }
            let nameOffset = try readUInt32(data, at: base + 8, order: order)
            name = try readCommandCString(data, commandOffset: base, commandSize: Int(size), stringOffset: nameOffset, command: command)
        } else if kind == .rpath {
            guard size >= 12 else { throw GuestMachOParserError.invalidLoadCommand(offset: offset, size: size) }
            let nameOffset = try readUInt32(data, at: base + 8, order: order)
            name = try readCommandCString(data, commandOffset: base, commandSize: Int(size), stringOffset: nameOffset, command: command)
        } else if kind == .uuid {
            guard size >= 24 else { throw GuestMachOParserError.invalidLoadCommand(offset: offset, size: size) }
            uuid = data.subdata(in: (base + 8)..<(base + 24))
        } else if kind == .codeSignature || kind == .chainedFixups {
            guard size >= 16 else { throw GuestMachOParserError.invalidLoadCommand(offset: offset, size: size) }
            dataOffset = try readUInt32(data, at: base + 8, order: order)
            dataSize = try readUInt32(data, at: base + 12, order: order)
        }

        return GuestMachOLoadCommand(
            command: command,
            size: size,
            kind: kind,
            name: name,
            segmentName: segmentName,
            dataOffset: dataOffset,
            dataSize: dataSize,
            uuid: uuid,
            segment: nil
        )
    }

    private func parseSegment64(
        data: Data,
        offset: Int,
        commandSize: UInt32,
        order: GuestMachOByteOrder,
        sliceSize: UInt64
    ) throws -> GuestMachOSegment64 {
        let minimumSize: UInt64 = 72
        guard UInt64(commandSize) >= minimumSize else {
            throw GuestMachOParserError.invalidLoadCommand(offset: offset, size: commandSize)
        }

        let name = try readCString(data, at: offset + 8, length: 16)
        let virtualAddress = try readUInt64(data, at: offset + 24, order: order)
        let virtualSize = try readUInt64(data, at: offset + 32, order: order)
        let fileOffset = try readUInt64(data, at: offset + 40, order: order)
        let fileSize = try readUInt64(data, at: offset + 48, order: order)
        let maximumProtection = Int32(bitPattern: try readUInt32(data, at: offset + 56, order: order))
        let initialProtection = Int32(bitPattern: try readUInt32(data, at: offset + 60, order: order))
        let sectionCount = try readUInt32(data, at: offset + 64, order: order)
        let flags = try readUInt32(data, at: offset + 68, order: order)

        guard fileOffset <= sliceSize, fileSize <= sliceSize - fileOffset else {
            throw GuestMachOParserError.invalidFileRange(
                context: "segment",
                offset: fileOffset,
                size: fileSize,
                sliceSize: sliceSize
            )
        }
        guard virtualSize <= UInt64.max - virtualAddress else {
            throw GuestMachOParserError.invalidAddressRange(context: "segment")
        }

        let sectionBytes = UInt64(sectionCount) * 80
        guard sectionBytes <= UInt64(commandSize) - minimumSize else {
            throw GuestMachOParserError.invalidLoadCommand(offset: offset, size: commandSize)
        }

        var sections: [GuestMachOSection64] = []
        for index in 0..<Int(sectionCount) {
            let sectionOffset = offset + 72 + index * 80
            let section = try parseSection64(
                data: data,
                offset: sectionOffset,
                order: order,
                sliceSize: sliceSize
            )
            let sectionType = section.flags & 0xff
            if sectionType != 1 && section.size > 0 {
                let sectionFileOffset = UInt64(section.fileOffset)
                guard sectionFileOffset >= fileOffset,
                      sectionFileOffset - fileOffset <= fileSize,
                      section.size <= fileSize - (sectionFileOffset - fileOffset) else {
                    throw GuestMachOParserError.invalidFileRange(
                        context: "section \(section.segmentName),\(section.sectionName) outside segment",
                        offset: sectionFileOffset,
                        size: section.size,
                        sliceSize: fileSize
                    )
                }
            }
            sections.append(section)
        }

        return GuestMachOSegment64(
            name: name,
            virtualAddress: virtualAddress,
            virtualSize: virtualSize,
            fileOffset: fileOffset,
            fileSize: fileSize,
            maximumProtection: maximumProtection,
            initialProtection: initialProtection,
            flags: flags,
            sections: sections
        )
    }

    private func parseSection64(
        data: Data,
        offset: Int,
        order: GuestMachOByteOrder,
        sliceSize: UInt64
    ) throws -> GuestMachOSection64 {
        let sectionName = try readCString(data, at: offset, length: 16)
        let segmentName = try readCString(data, at: offset + 16, length: 16)
        let address = try readUInt64(data, at: offset + 32, order: order)
        let size = try readUInt64(data, at: offset + 40, order: order)
        let fileOffset = try readUInt32(data, at: offset + 48, order: order)
        let alignment = try readUInt32(data, at: offset + 52, order: order)
        let relocationOffset = try readUInt32(data, at: offset + 56, order: order)
        let relocationCount = try readUInt32(data, at: offset + 60, order: order)
        let flags = try readUInt32(data, at: offset + 64, order: order)
        let reserved1 = try readUInt32(data, at: offset + 68, order: order)
        let reserved2 = try readUInt32(data, at: offset + 72, order: order)
        let reserved3 = try readUInt32(data, at: offset + 76, order: order)

        // S_ZEROFILL sections have no bytes in the file. All other sections
        // must fit within the slice before any future consumer can read them.
        let sectionType = flags & 0xff
        if sectionType != 1 && size > 0 {
            let sectionFileOffset = UInt64(fileOffset)
            guard sectionFileOffset <= sliceSize,
                  size <= sliceSize - sectionFileOffset else {
                throw GuestMachOParserError.invalidFileRange(
                    context: "section \(segmentName),\(sectionName)",
                    offset: sectionFileOffset,
                    size: size,
                    sliceSize: sliceSize
                )
            }
        }
        guard size <= UInt64.max - address else {
            throw GuestMachOParserError.invalidAddressRange(context: "section \(segmentName),\(sectionName)")
        }

        return GuestMachOSection64(
            sectionName: sectionName,
            segmentName: segmentName,
            address: address,
            size: size,
            fileOffset: fileOffset,
            alignment: alignment,
            relocationOffset: relocationOffset,
            relocationCount: relocationCount,
            flags: flags,
            reserved1: reserved1,
            reserved2: reserved2,
            reserved3: reserved3
        )
    }

    private func readCommandCString(
        _ data: Data,
        commandOffset: Int,
        commandSize: Int,
        stringOffset: UInt32,
        command: UInt32
    ) throws -> String {
        guard stringOffset < UInt32(commandSize) else {
            throw GuestMachOParserError.invalidStringOffset(command: command, offset: stringOffset)
        }
        return try readCString(data, at: commandOffset + Int(stringOffset), length: commandSize - Int(stringOffset))
    }

    private func readCString(_ data: Data, at offset: Int, length: Int) throws -> String {
        guard offset >= 0, length >= 0, offset <= data.count, length <= data.count - offset else {
            throw GuestMachOParserError.truncated(offset: offset, required: length, available: data.count - max(offset, 0))
        }
        let bytes = data[offset..<(offset + length)]
        let end = bytes.firstIndex(of: 0) ?? bytes.endIndex
        return String(decoding: bytes[..<end], as: UTF8.self)
    }

    private func readUInt32(_ data: Data, at offset: Int, order: GuestMachOByteOrder) throws -> UInt32 {
        guard offset >= 0, offset + 4 <= data.count else {
            throw GuestMachOParserError.truncated(offset: offset, required: 4, available: data.count - max(offset, 0))
        }
        let b0 = UInt32(data[offset])
        let b1 = UInt32(data[offset + 1])
        let b2 = UInt32(data[offset + 2])
        let b3 = UInt32(data[offset + 3])
        switch order {
        case .little: return b0 | b1 << 8 | b2 << 16 | b3 << 24
        case .big: return b3 | b2 << 8 | b1 << 16 | b0 << 24
        }
    }

    private func readUInt64(_ data: Data, at offset: Int, order: GuestMachOByteOrder) throws -> UInt64 {
        let first = UInt64(try readUInt32(data, at: offset, order: order))
        let second = UInt64(try readUInt32(data, at: offset + 4, order: order))
        switch order {
        case .little: return first | second << 32
        case .big: return first << 32 | second
        }
    }
}
