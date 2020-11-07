public class PackableMessage {
    public internal(set) var bytes: [UInt8] = []

    public init() { }

    @discardableResult
    public func pack<T: MessagePackCompatible>(_ object: T) throws -> Self {
        try object.pack(to: self)
        return self
    }

    public func packBinary<C>(_ bytes: C) throws
    where C: Collection, C.Element == UInt8 {
        try self.writeHeader(forType: .binary, length: UInt(bytes.count))
        self.write(bytes: bytes)
    }

    func writeHeader(forType type: MessagePackType, length: UInt) throws {
        guard length <= UInt32.max else {
            throw MessagePackError.objectTooBig
        }
        if let formatByte = self.singleByteHeader(forType: type,
                                                  length:  length) {
            self.writeInteger(formatByte.rawValue)
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
            self.writeFormatAndInteger(formats[0]!, UInt8(length))
        case 0 ... UInt(UInt16.max):
            self.writeFormatAndInteger(formats[1]!, UInt16(length))
        default:
            self.writeFormatAndInteger(formats[2]!, UInt32(length))
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

    func writeFormatAndInteger<T: FixedWidthInteger>(
        _ format: FormatByte.Format, _ value: T) {
        self.writeFormatByte(format)
        self.writeInteger(value)
    }

    func writeFormatByte(_ format: FormatByte.Format) {
        self.writeInteger(FormatByte(format).rawValue)
    }

    func writeFormatByte(_ format: FormatByte.Format, withValue value: Int8) {
        self.writeInteger(FormatByte(format, withValue: value).rawValue)
    }

    func writeInteger<T: FixedWidthInteger>(_ value: T) {
        let bigEndian = T(bigEndian: value)
        withUnsafeBytes(of: bigEndian) {
            self.write(bytes: $0)
        }
    }

    func write<S>(bytes: S) where S: Sequence, S.Element == UInt8 {
        self.bytes += bytes
    }
}
