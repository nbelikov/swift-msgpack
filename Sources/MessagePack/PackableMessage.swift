import struct Foundation.Data

public class PackableMessage {
    var writer: Writable

    public init() {
        self.writer = DataWriter()
    }

    @discardableResult
    public func pack<T: MessagePackCompatible>(_ object: T) throws -> Self {
        try object.pack(to: self)
        return self
    }

    func writeHeader(forType type: MessagePackType, length: UInt) throws {
        guard length <= UInt32.max else {
            throw MessagePackError.objectTooBig
        }
        if let formatByte = self.singleByteHeader(forType: type,
                                                  length:  length) {
            try self.writeInteger(formatByte.rawValue)
            return
        }
        let formats: [FormatByte.Format?]
        switch type {
        case .binary:      formats = [.bin8, .bin16,   .bin32]
        case .`extension`: formats = [.ext8, .ext16,   .ext32]
        case .string:      formats = [.str8, .str16,   .str32]
        case .array:       formats = [nil,   .array16, .array32]
        case .map:         formats = [nil,   .map16,   .map32]
        default: preconditionFailure()
        }
        switch length {
        case 0 ... UInt(UInt8.max) where formats[0] != nil:
            try self.writeFormatByte(formats[0]!)
            try self.writeInteger(UInt8(length))
        case 0 ... UInt(UInt16.max):
            try self.writeFormatByte(formats[1]!)
            try self.writeInteger(UInt16(length))
        default:
            try self.writeFormatByte(formats[2]!)
            try self.writeInteger(UInt32(length))
        }
    }

    func singleByteHeader(forType type: MessagePackType, length: UInt) ->
    FormatByte? {
        guard let intLength = Int8(exactly: length) else { return nil }
        switch (type, intLength) {
        case (.map,    FormatByte.Format.fixmap.valueRange):
            return FormatByte(.fixmap,   withValue: intLength)
        case (.array,  FormatByte.Format.fixarray.valueRange):
            return FormatByte(.fixarray, withValue: intLength)
        case (.string, FormatByte.Format.fixstr.valueRange):
            return FormatByte(.fixstr,   withValue: intLength)
        case (.`extension`,  1): return FormatByte(.fixext1)
        case (.`extension`,  2): return FormatByte(.fixext2)
        case (.`extension`,  4): return FormatByte(.fixext4)
        case (.`extension`,  8): return FormatByte(.fixext8)
        case (.`extension`, 16): return FormatByte(.fixext16)
        default: return nil
        }
    }

    func writeFormatByte(_ format: FormatByte.Format) throws {
        try self.writeInteger(FormatByte(format).rawValue)
    }

    func writeFormatByte(_ format: FormatByte.Format, withValue value: Int8)
    throws {
        try self.writeInteger(FormatByte(format, withValue: value).rawValue)
    }

    func writeInteger<T: FixedWidthInteger>(_ value: T) throws {
        var mutable = value // FIXME
        try self.writer.write(contentsOf: &mutable)
    }
}

protocol Writable {
    mutating func write<T>(contentsOf: UnsafePointer<T>) throws
    mutating func write(data: Data) throws
}

struct DataWriter: Writable {
    var data: Data

    init() {
        self.data = Data()
    }

    mutating func write<T>(contentsOf pointer: UnsafePointer<T>) throws {
        let size = MemoryLayout<T>.size
        pointer.withMemoryRebound(to: UInt8.self, capacity: size) {
            self.data.append($0, count: size)
        }
    }

    mutating func write(data: Data) throws {
        self.data.append(data)
    }
}
