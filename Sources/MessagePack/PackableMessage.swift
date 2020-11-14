public class PackableMessage {
    private var parentBytes:  [[UInt8]] = []
    private var parentCounts: [UInt]    = []

    public internal(set) var bytes: [UInt8] = []

    // While length of MessagePack objects is limited to UInt32.max, map type
    // will have inside twice as many objects as its declared length.
    // Additionally, the specification does not impose any limit on the number
    // of objects that may exist outside a container.  UInt is good enough to
    // represent all possible values on both 32- and 64-bit systems, given that
    // [UInt8] buffer can't hold more than Int.max bytes anyway.
    public internal(set) var count: UInt = 0

    public init() { }

    @discardableResult
    public func pack<T: MessagePackCompatible>(_ object: T) throws -> Self {
        try object.pack(to: self)
        return self
    }

    @discardableResult
    public func packBinary<C>(_ bytes: C) throws -> Self
    where C: Collection, C.Element == UInt8 {
        try self.writeHeader(forType: .binary, length: UInt(bytes.count))
        self.write(bytes: bytes)
        return self
    }

    @discardableResult
    public func packArray(_ closure: () throws -> ()) throws -> Self {
        self.enterScope()
        try closure()
        let (bytes, count) = self.leaveScope()
        try self.writeHeader(forType: .array, length: count)
        self.write(bytes: bytes)
        return self
    }

    @discardableResult
    public func packArray(count: UInt, _ closure: () throws -> ()) throws
    -> Self {
        try self.writeHeader(forType: .array, length: count)
        self.enterCountScope()
        try closure()
        let actualCount = self.leaveCountScope()
        precondition(count == actualCount,
            "Expected \(count) elements, got \(actualCount)")
        return self
    }

    @discardableResult
    public func packMap(_ closure: () throws -> ()) throws
    -> Self {
        self.enterScope()
        try closure()
        let (bytes, count) = self.leaveScope()
        precondition(count % 2 == 0,
            "Unexpected key without a matching value")
        try self.writeHeader(forType: .map, length: UInt(count / 2))
        self.write(bytes: bytes)
        return self
    }

    @discardableResult
    public func packMap(count: UInt, _ closure: () throws -> ()) throws
    -> Self {
        try self.writeHeader(forType: .map, length: count)
        self.enterCountScope()
        try closure()
        let objectCount = self.leaveCountScope()
        precondition(objectCount % 2 == 0,
            "Unexpected key without a matching value")
        let actualCount = objectCount / 2
        precondition(count == actualCount,
            "Expected \(count) elements, got \(actualCount)")
        return self
    }

    private func enterScope() {
        self.parentBytes.append(self.bytes)
        self.parentCounts.append(self.count)
        self.bytes = []
        self.count = 0
    }

    private func leaveScope() -> (bytes: [UInt8], count: UInt) {
        defer {
            self.bytes = self.parentBytes.removeLast()
            self.count = self.parentCounts.removeLast()
        }
        return (self.bytes, self.count)
    }

    private func enterCountScope() {
        self.parentCounts.append(self.count)
        self.count = 0
    }

    private func leaveCountScope() -> UInt {
        defer {
            self.count = self.parentCounts.removeLast()
        }
        return self.count
    }

    func writeHeader(forType type: MessagePackType, length: UInt) throws {
        guard length <= UInt32.max else {
            throw MessagePackError.objectTooBig
        }
        if let formatByte = self.singleByteHeader(
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
        self.writeFormatByte(FormatByte(format))
    }

    func writeFormatByte(_ format: FormatByte.Format, withValue value: Int8) {
        self.writeFormatByte(FormatByte(format, withValue: value))
    }

    func writeFormatByte(_ formatByte: FormatByte) {
        self.writeInteger(formatByte.rawValue)
        self.count += 1
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
