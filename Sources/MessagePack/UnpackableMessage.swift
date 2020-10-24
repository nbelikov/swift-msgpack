import struct Foundation.Data

public class UnpackableMessage {
    var reader: Readable

    // This property should be directly accessed only by self.readFormatByte()
    // and self.peekFormatByte()
    var _formatByte: FormatByte?

    public init(fromData data: Data) {
        self.reader = DataReader(data: data)
    }

    public convenience init(fromBytes bytes: [UInt8]) {
        self.init(fromData: Data(bytes))
    }

    // FIXME: This recursive implementation can be easily tricked by malicious
    // user input into exhausting stack memory by recursively nesting an array
    // or a map deep enough.
    public func unpackAny() throws -> Any? {
        let type = MessagePackType(try self.peekFormatByte())
        switch type {
        case .integer: return try self.unpackAnyInteger()
        case .`nil`:   return nil
        case .bool:    return try self.unpack() as Bool
        case .float:   return try self.unpack() as Float
        case .double:  return try self.unpack() as Double
        case .string:  return try self.unpack() as String
        case .binary:  return try self.unpackBytes()
        case .array:   return try self.unpackAnyArray()
        case .map:     return try self.unpackAnyMap()
        case .`extension`: return nil // FIXME
        }
    }

    public func unpack<T: MessagePackCompatible>() throws -> T {
        try T(unpackFrom: self)
    }

    func peekFormatByte() throws -> FormatByte {
        if self._formatByte == nil {
            self._formatByte = try self.readFormatByte()
        }
        return self._formatByte!
    }

    func readFormatByte() throws -> FormatByte {
        if let formatByte = self._formatByte {
            self._formatByte = nil
            return formatByte
        }
        let byte = try self.readInteger(as: UInt8.self)
        guard let formatByte = FormatByte(rawValue: byte) else {
            throw MessagePackError.invalidMessage
        }
        return formatByte
    }

    public func isEmpty() throws -> Bool {
        try self.reader.isEmpty()
    }

    public func unpackBytes() throws -> [UInt8] {
        let formatByte = try self.readFormatByte()
        let type = MessagePackType(formatByte)
        guard type == .binary || type == .string else {
            throw MessagePackError.incompatibleType
        }
        let length = try self.readLength(formatByte)
        return Array(try self.reader.readAsData(size: length))
    }

    func unpackAnyInteger() throws -> Any {
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

    func unpackAnyArray() throws -> [Any?] {
        return [] // FIXME
    }

    func unpackAnyMap() throws -> [AnyHashable : Any?] {
        return [:] // FIXME
    }

    func readLength(_ formatByte: FormatByte) throws -> UInt {
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

    func readInteger<T: FixedWidthInteger>(as: T.Type) throws -> T {
        var bigEndianInt = T()
        try self.reader.read(into: &bigEndianInt)
        return T(bigEndian: bigEndianInt)
    }
}

protocol Readable {
    mutating func read<T>(into: UnsafeMutablePointer<T>) throws
    mutating func readAsData(size: UInt) throws -> Data
    mutating func isEmpty() throws -> Bool // FIXME: does it need to throw?
}

struct DataReader: Readable {
    var data: Data
    var position: Int = 0

    mutating func read<T>(into pointer: UnsafeMutablePointer<T>) throws {
        let size = MemoryLayout<T>.size
        let subData = try self.readAsData(size: UInt(size))
        pointer.withMemoryRebound(to: UInt8.self, capacity: size) {
            subData.copyBytes(to: $0, count: size)
        }
    }

    mutating func readAsData(size: UInt) throws -> Data {
        // This could overflow on 32-bit hosts:
        //     let intSize = Int(exactly: size) else { ... }
        //     let endPosition = self.position + intSize
        //     guard endPosition <= self.data.count else { ... }
        let remaining = self.data.count - self.position
        guard size <= remaining else {
            throw MessagePackError.unexpectedEndOfMessage
        }
        // The following conversion is safe even on 32-bit hosts thanks to the
        // check above.
        let endPosition = self.position + Int(size)
        let range = self.position ..< endPosition
        self.position = endPosition
        return data[range]
    }

    func isEmpty() throws -> Bool {
        self.position == self.data.count
    }
}