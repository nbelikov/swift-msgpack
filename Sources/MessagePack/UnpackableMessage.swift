public struct UnpackableMessage {
    private final class Storage {
        var slice: ArraySlice<UInt8>

        init(slice: ArraySlice<UInt8>) { self.slice = slice }
    }

    private let storage: Storage
    // See comment for PackableMessage.count
    private var remainingCount: UInt?
    // This property should be directly accessed only by self.readFormatByte()
    // and self.peekFormatByte()
    private var _formatByte: FormatByte?

    public init(from bytes: [UInt8]) {
        self.init(from: bytes[bytes.startIndex ..< bytes.endIndex])
    }

    public init(from slice: ArraySlice<UInt8>) {
        self.storage = Storage(slice: slice)
    }

    private init(
        parent message: inout UnpackableMessage, remainingCount: UInt
    ) {
        self.storage = message.storage
        self.remainingCount = remainingCount
    }

    // FIXME: This recursive implementation can be easily tricked by malicious
    // user input into exhausting stack memory by recursively nesting an array
    // or a map deep enough.
    public mutating func unpackAny() throws -> Any? {
        let type = MessagePackType(try self.peekFormatByte())
        switch type {
        case .integer: return try self.unpackAnyInteger()
        case .`nil`:   return nil
        case .bool:    return try self.unpack() as Bool
        case .float:   return try self.unpack() as Double
        case .string:  return try self.unpack() as String
        case .binary:  return try self.unpackBinary()
        case .array:   return try self.unpackAnyArray()
        case .map:     return try self.unpackAnyMap()
        case .`extension`: return nil // FIXME
        }
    }

    public mutating func unpack<T: MessagePackCompatible>() throws -> T {
        try T(unpackFrom: &self)
    }

    // TODO: Should this return ArraySlice<UInt8> instead?
    public mutating func unpackBinary() throws -> [UInt8] {
        let formatByte = try self.readFormatByte()
        let type = MessagePackType(formatByte)
        guard type == .binary || type == .string else {
            throw MessagePackError.incompatibleType
        }
        let length = try self.readLength(formatByte)
        return try Array(self.readBytes(size: length))
    }

    // Security consideration: do not reserve capacity for `count` elements
    // unless you completely trust the input.  It is easy for an attacker to
    // set count to UInt32.max and cause memory exhaustion.
    public mutating func unpackArray<R>(
        _ closure: (inout UnpackableMessage, _ count: UInt) throws -> R
    ) throws -> R {
        let formatByte = try self.readFormatByte()
        let type = MessagePackType(formatByte)
        guard type == .array else { throw MessagePackError.incompatibleType }
        let length = try self.readLength(formatByte)
        var message = UnpackableMessage( parent: &self, remainingCount: length)
        let result = try closure(&message, length)
        precondition(
            message.remainingCount == 0,
            "\(message.remainingCount!) elements of an array were left " +
            "unpacked")
        return result
    }

    // See comment for unpackArray(:)
    public mutating func unpackMap<R>(
        _ closure: (inout UnpackableMessage, _ count: UInt) throws -> R
    ) throws -> R {
        let formatByte = try self.readFormatByte()
        let type = MessagePackType(formatByte)
        guard type == .map else { throw MessagePackError.incompatibleType }
        let length = try self.readLength(formatByte)
        // Check for possible overflow on 32-bit hosts.  Since the message's
        // body length is limited by what can fit inside [UInt8], that is, by
        // Int.max, if this exception wouldn't be thrown at this point, it is
        // guaranteed that it would be thrown later.
        guard length <= UInt.max / 2 else {
            throw MessagePackError.unexpectedEndOfMessage
        }
        var message = UnpackableMessage(
            parent: &self,
            remainingCount: length * 2)
        let result = try closure(&message, length)
        precondition(
            message.remainingCount! % 2 == 0,
            "A key was unpacked while it's paired value wasn't.  " +
            "\(message.remainingCount! / 2) elements of a map were left " +
            "unpacked")
        precondition(
            message.remainingCount == 0,
            "\(message.remainingCount! / 2) elements of a map were left " +
            "unpacked")
        return result
    }

    mutating func peekFormatByte() throws -> FormatByte {
        if self._formatByte == nil {
            self._formatByte = try self.readFormatByte()
        }
        return self._formatByte!
    }

    mutating func readFormatByte() throws -> FormatByte {
        if let formatByte = self._formatByte {
            self._formatByte = nil
            return formatByte
        }
        precondition(
            self.remainingCount != 0,
            "Attempt to unpack an element beyond the enclosing container's " +
            "boundary")
        let byte = try self.readInteger(as: UInt8.self)
        guard let formatByte = FormatByte(rawValue: byte) else {
            throw MessagePackError.invalidMessage
        }
        if self.remainingCount != nil { self.remainingCount! -= 1 }
        return formatByte
    }

    public var isEmpty: Bool { self.storage.slice.count == 0 }

    private mutating func unpackAnyInteger() throws -> Any {
        let formatByte = try self.peekFormatByte()
        if formatByte.format == .uint64 {
            let uint64: UInt64 = try self.unpack()
            // TODO: Why doesn't this work?
            // return Int(exactly: uint64) ?? UInt(exactly: uint64) ?? uint64
            if let int  = Int(exactly:  uint64) { return int }
            if let uint = UInt(exactly: uint64) { return uint }
            return uint64
        } else {
            let int64: Int64 = try self.unpack()
            if let int = Int(exactly: int64) { return int }
            return int64
        }
    }

    private mutating func unpackAnyArray() throws -> [Any?] {
        try self.unpackArray { message, count in
            var result: [Any?] = []
            // Don't: result.reserveCapacity(Int(count))
            // See comment for unpackArray(:) for explaination
            for _ in 0 ..< count { result.append(try message.unpackAny()) }
            return result
        }
    }

    mutating func unpackAnyMap() throws -> [AnyHashable : Any?] {
        return [:] // FIXME
    }

    mutating func readLength(_ formatByte: FormatByte) throws -> UInt {
        switch formatByte.format {
        case .fixmap, .fixarray, .fixstr: return UInt(formatByte.value)
        case .fixext1:  return 1
        case .fixext2:  return 2
        case .fixext4:  return 4
        case .fixext8:  return 8
        case .fixext16: return 16
        case .bin8,  .ext8,  .str8:
            return UInt(try self.readInteger(as: UInt8.self))
        case .bin16, .ext16, .str16, .array16, .map16:
            return UInt(try self.readInteger(as: UInt16.self))
        case .bin32, .ext32, .str32, .array32, .map32:
            return UInt(try self.readInteger(as: UInt32.self))
        default: preconditionFailure()
        }
    }

    mutating func readInteger<T: FixedWidthInteger>(as: T.Type) throws -> T {
        let size = MemoryLayout<T>.size
        let bytes = try self.readBytes(size: UInt(size))
        var bigEndian = T()
        withUnsafeMutableBytes(of: &bigEndian) {
            for i in 0 ..< size {
                $0[i] = bytes[bytes.startIndex + i]
            }
        }
        return T(bigEndian: bigEndian)
    }

    mutating func readBytes(size: UInt) throws -> ArraySlice<UInt8> {
        guard size <= self.storage.slice.count else {
            throw MessagePackError.unexpectedEndOfMessage
        }
        // The following conversion is safe even on 32-bit hosts thanks to the
        // check above.
        let result = self.storage.slice.prefix(Int(size))
        self.storage.slice = self.storage.slice.suffix(
            self.storage.slice.count - Int(size))
        return result
    }
}
