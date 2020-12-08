import Foundation // Provides String.init(bytes:encoding:)

public struct UnpackableMessage {
    private var slice: ArraySlice<UInt8>
    // See comment for PackableMessage.count
    private var remainingCount: UInt?

    public init(from bytes: [UInt8]) {
        self.init(from: bytes[bytes.startIndex ..< bytes.endIndex])
    }

    public init(from slice: ArraySlice<UInt8>) {
        self.slice = slice
    }

    private init(slice: ArraySlice<UInt8>, remainingCount: UInt) {
        self.slice = slice
        self.remainingCount = remainingCount
    }

    // FIXME: This recursive implementation can be easily tricked by malicious
    // user input into exhausting stack memory by recursively nesting an array
    // or a map deep enough.
    public mutating func unpackAny() throws -> Any? {
        let type = try self.nextValueType()
        switch type {
        case .integer: return try self.unpackAnyInteger()
        case .`nil`:   return try self.unpackNil()
        case .bool:    return try self.unpackBool()
        case .float:   return try self.unpackDouble()
        case .string:  return try self.unpackString()
        case .binary:  return try self.unpackBinary()
        case .array:   return try self.unpackAnyArray()
        case .map:     return try self.unpackAnyMap()
        case .`extension`: return nil // FIXME
        }
    }

    public mutating func unpack<T: MessagePackCompatible>() throws -> T {
        try T(unpackFrom: &self)
    }

    public mutating func unpackNil() throws {
        try self.unpackSingleValue {
            let formatByte = try $0.readFormatByte()
            guard formatByte.format == .`nil` else {
                throw MessagePackError.incompatibleType
            }
        }
    }

    public mutating func unpackBool() throws -> Bool {
        try self.unpackSingleValue {
            let formatByte = try $0.readFormatByte()
            switch formatByte.format {
            case .`false`: return false
            case .`true`:  return true
            default:       throw MessagePackError.incompatibleType
            }
        }
    }

    public mutating func unpackDouble() throws -> Double {
        try self.unpackSingleValue {
            let formatByte = try $0.readFormatByte()
            switch formatByte.format {
            case .float32:
                // FIXME: Reuse unpackFloat()
                let bitPattern = try $0.readInteger(as: UInt32.self)
                return Double(Float(bitPattern: bitPattern))
            case .float64:
                let bitPattern = try $0.readInteger(as: UInt64.self)
                return Double(bitPattern: bitPattern)
            default:
                throw MessagePackError.incompatibleType
            }
        }
    }

    public mutating func unpackFloat() throws -> Float {
        try self.unpackSingleValue {
            let formatByte = try $0.readFormatByte()
            switch formatByte.format {
            case .float32:
                let bitPattern = try $0.readInteger(as: UInt32.self)
                return Float(bitPattern: bitPattern)
            default:
                throw MessagePackError.incompatibleType
            }
        }
    }

    public mutating func unpackInteger<T: FixedWidthInteger>() throws -> T {
        try self.unpackSingleValue {
            let formatByte = try $0.readFormatByte()
            let result: T?
            switch formatByte.format { // TODO: Make this less repetitive?
            case .uint8:
                result = T(exactly: try $0.readInteger(as: UInt8.self))
            case .uint16:
                result = T(exactly: try $0.readInteger(as: UInt16.self))
            case .uint32:
                result = T(exactly: try $0.readInteger(as: UInt32.self))
            case .uint64:
                result = T(exactly: try $0.readInteger(as: UInt64.self))
            case .int8:
                result = T(exactly: try $0.readInteger(as: Int8.self))
            case .int16:
                result = T(exactly: try $0.readInteger(as: Int16.self))
            case .int32:
                result = T(exactly: try $0.readInteger(as: Int32.self))
            case .int64:
                result = T(exactly: try $0.readInteger(as: Int64.self))
            case .positiveFixint, .negativeFixint:
                result = T(exactly: formatByte.value)
            default: throw MessagePackError.incompatibleType
            }
            if result == nil { throw MessagePackError.incompatibleType }
            return result!
        }
    }

    public mutating func unpackString() throws -> String {
        try self.unpackSingleValue {
            let formatByte = try $0.readFormatByte()
            guard MessagePackType(formatByte) == .string else {
                throw MessagePackError.incompatibleType
            }
            let length = try $0.readLength(formatByte)
            let bytes = try $0.readBytes(size: length)
            guard let string = String(bytes: bytes, encoding: .utf8) else {
                throw MessagePackError.invalidUtf8String
            }
            return string
        }
    }

    // TODO: Should this return ArraySlice<UInt8> instead?
    public mutating func unpackBinary() throws -> [UInt8] {
        try self.unpackSingleValue {
            let formatByte = try $0.readFormatByte()
            let type = MessagePackType(formatByte)
            guard type == .binary || type == .string else {
                throw MessagePackError.incompatibleType
            }
            let length = try $0.readLength(formatByte)
            return try Array($0.readBytes(size: length))
        }
    }

    // Security consideration: do not reserve capacity for `count` elements
    // unless you completely trust the input.  It is easy for an attacker to
    // set count to UInt32.max and cause memory exhaustion.
    public mutating func unpackArray<R>(
        _ closure: (inout UnpackableMessage, _ count: UInt) throws -> R
    ) throws -> R {
        try self.unpackContainer(
            type: .array,
            count: { $0 },
            closure: closure,
            check: {
                precondition(
                    $0 == 0,
                    "\($0) elements of an array were left unpacked")
            }
        )
    }

    // See comment for unpackArray(:)
    public mutating func unpackMap<R>(
        _ closure: (inout UnpackableMessage, _ count: UInt) throws -> R
    ) throws -> R {
        try self.unpackContainer(
            type: .map,
            count: { length in
                // Check for possible overflow on 32-bit hosts.  Since the
                // message's body length is limited by what can fit inside
                // [UInt8], that is, by Int.max, if this exception wouldn't be
                // thrown at this point, it is guaranteed that it would be
                // thrown later.
                guard length <= UInt.max / 2 else {
                    throw MessagePackError.unexpectedEndOfMessage
                }
                return length * 2
            },
            closure: closure,
            check: {
                precondition(
                    $0 % 2 == 0,
                    "A key was unpacked while it's paired value wasn't.  " +
                    "\($0 / 2) elements of a map were left unpacked")
                precondition(
                    $0 == 0,
                    "\($0 / 2) elements of a map were left unpacked")
            }
        )
    }

    public var isEmpty: Bool {
        self.slice.count == 0 || self.remainingCount == 0
    }

    public func nextValueType() throws -> MessagePackType {
        var temporary = self
        return MessagePackType(try temporary.readFormatByte())
    }

    private mutating func unpackContainer<R>(
        type: MessagePackType,
        count: (UInt) throws -> UInt,
        closure: (inout UnpackableMessage, _ count: UInt) throws -> R,
        check: (UInt) -> ()
    ) throws -> R {
        try self.unpackSingleValue {
            let formatByte = try $0.readFormatByte()
            let actualType = MessagePackType(formatByte)
            guard actualType == type else {
                throw MessagePackError.incompatibleType
            }
            let length = try $0.readLength(formatByte)
            let remainingCount = try count(length)
            var subMessage = UnpackableMessage(
                slice: $0.slice, remainingCount: remainingCount)
            let result = try closure(&subMessage, length)
            check(subMessage.remainingCount!)
            $0.slice = subMessage.slice
            return result
        }
    }

    // Allows to revert to previous state if an error is thrown in the middle
    // of unpacking.
    private mutating func unpackSingleValue<R>(
        _ closure: (inout UnpackableMessage) throws -> R
    ) rethrows -> R {
        precondition(
            self.remainingCount != 0,
            "Attempt to unpack an element beyond the enclosing container's " +
            "boundary")
        var temporary = self
        let result = try closure(&temporary)
        self.slice = temporary.slice
        if self.remainingCount != nil { self.remainingCount! -= 1 }
        return result
    }

    private mutating func readFormatByte() throws -> FormatByte {
        let byte = try self.readInteger(as: UInt8.self)
        guard let formatByte = FormatByte(rawValue: byte) else {
            throw MessagePackError.invalidMessage
        }
        return formatByte
    }

    private mutating func unpackAnyInteger() throws -> Any {
        var temporary = self
        let formatByte = try temporary.readFormatByte()
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

    private mutating func unpackAnyMap() throws -> [AnyHashable : Any?] {
        return [:] // FIXME
    }

    private mutating func readLength(_ formatByte: FormatByte) throws -> UInt {
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

    private mutating func readInteger<T: FixedWidthInteger>(as: T.Type) throws
    -> T {
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

    private mutating func readBytes(size: UInt) throws -> ArraySlice<UInt8> {
        guard size <= self.slice.count else {
            throw MessagePackError.unexpectedEndOfMessage
        }
        // The following conversion is safe even on 32-bit hosts thanks to the
        // check above.
        let result = self.slice.prefix(Int(size))
        self.slice = self.slice.dropFirst(Int(size))
        return result
    }
}
