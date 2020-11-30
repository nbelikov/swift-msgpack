public struct PackableMessage {
    private final class Storage { var bytes: [UInt8] = [] }
    private let storage: Storage

    public var bytes: [UInt8] { self.storage.bytes }

    // While length of MessagePack objects is limited to UInt32.max, map type
    // will have inside twice as many objects as its declared length.
    // Additionally, the specification does not impose any limit on the number
    // of objects that may exist outside a container.  UInt is good enough to
    // represent all possible values on both 32- and 64-bit systems, given that
    // [UInt8] buffer can't hold more than Int.max bytes anyway.
    public internal(set) var count: UInt = 0

    public init() {
        self.storage = Storage()
    }

    private init(parent message: inout PackableMessage) {
        self.storage = message.storage
    }

    public mutating func pack<T: MessagePackCompatible>(_ object: T) throws {
        try object.pack(to: &self)
    }

    public mutating func packMessage(_ message: PackableMessage) {
        self.write(bytes: message.bytes)
        self.count += message.count
    }

    public mutating func packNil() {
        self.writeFormatByte(.`nil`)
    }

    public mutating func packBinary<C>(_ bytes: C) throws
    where C: Collection, C.Element == UInt8 {
        try self.writeHeader(forType: .binary, length: UInt(bytes.count))
        self.write(bytes: bytes)
    }

    public mutating func packArray(
        _ closure: (inout PackableMessage) throws -> ()
    ) throws {
        var message = PackableMessage()
        try closure(&message)
        try self.writeHeader(forType: .array, length: message.count)
        self.write(bytes: message.bytes)
    }

    public mutating func packArray(
        count: UInt, _ closure: (inout PackableMessage) throws -> ()
    ) throws {
        try self.writeHeader(forType: .array, length: count)
        var message = PackableMessage(parent: &self)
        try closure(&message)
        precondition(
            count == message.count,
            "Expected \(count) elements, got \(message.count)")
    }

    public mutating func packMap(
        _ closure: (inout PackableMessage) throws -> ()
    ) throws {
        var message = PackableMessage()
        try closure(&message)
        precondition(
            message.count % 2 == 0,
            "Unexpected key without a matching value")
        try self.writeHeader(forType: .map, length: UInt(message.count / 2))
        self.write(bytes: message.bytes)
    }

    public mutating func packMap(
        count: UInt, _ closure: (inout PackableMessage) throws -> ()
    ) throws {
        try self.writeHeader(forType: .map, length: count)
        var message = PackableMessage(parent: &self)
        try closure(&message)
        precondition(
            message.count % 2 == 0,
            "Unexpected key without a matching value")
        let pairCount = message.count / 2
        precondition(
            count == pairCount,
            "Expected \(count) elements, got \(pairCount)")
    }

    public mutating func encode<T: Encodable>(
        _ value: T, userInfo: [CodingUserInfoKey : Any] = [:]
    ) throws {
        let encoder = MessagePackEncoder(userInfo: userInfo, codingPath: [])
        try encoder.encode(value)
        self.write(bytes: encoder.bytes)
        self.count += 1
    }

    mutating func writeHeader(
        forType type: MessagePackType, length: UInt
    ) throws {
        guard length <= UInt32.max else {
            throw MessagePackError.objectTooBig
        }
        if let formatByte = Self.singleByteHeader(
            forType: type, length: length) {
            return self.writeFormatByte(formatByte)
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

    private static func singleByteHeader(
        forType type: MessagePackType, length: UInt
    ) -> FormatByte? {
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

    mutating func writeFormatAndInteger<T: FixedWidthInteger>(
        _ format: FormatByte.Format, _ value: T) {
        self.writeFormatByte(format)
        self.writeInteger(value)
    }

    mutating func writeFormatByte(_ format: FormatByte.Format) {
        self.writeFormatByte(FormatByte(format))
    }

    mutating func writeFormatByte(
        _ format: FormatByte.Format, withValue value: Int8
    ) {
        self.writeFormatByte(FormatByte(format, withValue: value))
    }

    mutating func writeFormatByte(_ formatByte: FormatByte) {
        self.writeInteger(formatByte.rawValue)
        self.count += 1
    }

    mutating func writeInteger<T: FixedWidthInteger>(_ value: T) {
        let bigEndian = T(bigEndian: value)
        withUnsafeBytes(of: bigEndian) {
            self.write(bytes: $0)
        }
    }

    mutating func write<S>(bytes: S) where S: Sequence, S.Element == UInt8 {
        self.storage.bytes += bytes
    }
}
