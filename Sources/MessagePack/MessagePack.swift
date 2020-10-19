import struct Foundation.Data
import class  Foundation.InputStream
import class  Foundation.OutputStream

public class DecodableMessage {
    var reader: Readable

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
        guard let header = try self.readHeader() else { return nil }
        switch header {
        case .integer(let value): return value.asAny
        case .`nil`:              return nil
        case .bool(let value):    return value
        case .float(let value):   return value
        case .double(let value):  return value
        case .string(let length): return try self.readString(length)
        case .binary(let length): return try self.readBytes(length)
        case .array(let length):  return try self.readArray(length) as [Any?]
        case .map(let length):
            return try self.readMap(length) as [AnyHashable : Any?]
        case .ext(let type, let length):
            return try self.readExt(type: type, length: length)
        }
    }

    func readHeader() throws -> Header? {
        guard let byte = try self.readFormatByte() else { return nil }
        let h: Header
        switch byte.format {
        case .positiveFixint: h = .integer(value: .int(Int(byte.value)))
        case .fixmap:   h = .map(length:    UInt(byte.value))
        case .fixarray: h = .array(length:  UInt(byte.value))
        case .fixstr:   h = .string(length: UInt(byte.value))
        case .`nil`:    h = .`nil`
        case .`false`:  h = .bool(value: false)
        case .`true`:   h = .bool(value: true)
        case .bin8, .bin16, .bin32:
            h = .binary(length: try self.readLength(byte.format))
        case .ext8, .ext16, .ext32:
            // The order in which these values must be read differs from the
            // order of properties in `.ext` initializer.
            let length = try self.readLength(byte.format)
            let type   = try self.readExtType()
            h = .ext(type: type, length: length)
        case .float32:  h = .float(value:  try self.readFloat())
        case .float64:  h = .double(value: try self.readDouble())
        case .uint8, .uint16, .uint32, .uint64, .int8, .int16, .int32, .int64:
            h = .integer(value: try self.readIntValue(byte.format))
        case .fixext1:  h = .ext(type: try self.readExtType(), length:  1)
        case .fixext2:  h = .ext(type: try self.readExtType(), length:  2)
        case .fixext4:  h = .ext(type: try self.readExtType(), length:  4)
        case .fixext8:  h = .ext(type: try self.readExtType(), length:  8)
        case .fixext16: h = .ext(type: try self.readExtType(), length: 16)
        case .str8, .str16, .str32:
             h = .string(length: try self.readLength(byte.format))
        case .array16, .array32:
             h = .array(length:  try self.readLength(byte.format))
        case .map16, .map32:
             h = .map(length:    try self.readLength(byte.format))
        case .negativeFixint: h = .integer(value: .int(Int(byte.value)))
        }
        return h
    }

    func readFormatByte() throws -> FormatByte? {
        guard self.reader.hasMore else { return nil }
        let byte = try self.readInteger(as: UInt8.self)
        guard let formatByte = FormatByte(rawValue: byte) else {
            throw MessagePackError.invalidMessage
        }
        return formatByte
    }

    func readString(_ length: UInt) throws -> String {
        let data = try self.reader.readAsData(size: length)
        guard let string = String(data: data, encoding: .utf8) else {
            throw MessagePackError.invalidUtf8String
        }
        return string
    }

    func readBytes(_ length: UInt) throws -> [UInt8] {
        Array(try self.reader.readAsData(size: length))
    }

    // FIXME: self.unpackAny() returns nil both on a `nil` value and on end of
    // message,  so if length is bigger than actual element count, the array
    // will contain trailing nil elements.  An error must be thrown instead.
    func readArray(_ length: UInt) throws -> [Any?] {
        // Don't do this:
        //     return try (0 ..< length).map { _ in try self.unpackAny() }
        // The implementation of Collection.map(_:) will call
        // reserveCapacity(_:) on resulting array.  Since length is not
        // sanitized, this would open a possibility for a memory exhaustion
        // attack.
        var array = [Any?]()
        for _ in 0 ..< length {
            array.append(try self.unpackAny())
        }
        return array
    }

    func readMap<K: Hashable, V>(_ length: UInt) throws -> [K : V] {
        [:] // FIXME
    }

    func readIntValue(_ format: FormatByte.Format) throws -> Header.IntValue {
        var int: Header.IntValue
        switch format {
        case .uint8:  int = .int(Int(try   self.readInteger(as:  UInt8.self)))
        case .uint16: int = .int(Int(try   self.readInteger(as: UInt16.self)))
        case .uint32: int = .uInt(UInt(try self.readInteger(as: UInt32.self)))
        case .uint64: int = .uInt64(try    self.readInteger(as: UInt64.self))
        case .int8:   int = .int(Int(try   self.readInteger(as:   Int8.self)))
        case .int16:  int = .int(Int(try   self.readInteger(as:  Int16.self)))
        case .int32:  int = .int(Int(try   self.readInteger(as:  Int32.self)))
        case .int64:  int = .int64(try     self.readInteger(as:  Int64.self))
        default: preconditionFailure()
        }
        return int.normalized
    }

    func readFloat() throws -> Float {
        Float(bitPattern: try self.readInteger(as: UInt32.self))
    }

    func readDouble() throws -> Double {
        Double(bitPattern: try self.readInteger(as: UInt64.self))
    }

    func readExt(type: Header.ExtType, length: UInt) throws -> Any? {
        nil // FIXME
    }

    func readExtType() throws -> Header.ExtType { .timestamp } // FIXME

    func readLength(_ format: FormatByte.Format) throws -> UInt {
        switch format {
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

enum MessagePackError: Error {
    case invalidMessage
    case unexpectedEndOfMessage
    case invalidUtf8String
}

protocol Readable {
    mutating func read<T>(into: UnsafeMutablePointer<T>) throws
    mutating func readAsData(size: UInt) throws -> Data
    var hasMore: Bool { get }
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

    var hasMore: Bool {
        get { self.position < self.data.count }
    }
}

enum Header { // FIXME better name
    case integer(value: IntValue)
    case `nil`
    case bool(value: Bool)
    case float(value: Float)
    case double(value: Double)
    case string(length: UInt)
    case binary(length: UInt)
    case array(length: UInt)
    case map(length: UInt)
    case ext(type: ExtType, length: UInt)

    enum ExtType {
        case timestamp // FIXME
    }

    enum IntValue {
        case int(Int)
        case uInt(UInt)
        case int64(Int64)
        case uInt64(UInt64)

        // Try to use a more convenient and compact integer type
        // UInt64 ---> Int64 ---> Int <--- UInt
        var normalized: IntValue {
            get {
                switch self {
                case .uInt(let value)   where value <= Int.max:
                    return .int(Int(value))
                case .int64(let value)  where value <= Int.max &&
                                              value >= Int.min:
                    return .int(Int(value))
                case .uInt64(let value) where value <= Int64.max:
                    return IntValue.int64(Int64(value)).normalized
                default: return self
                }
            }
        }

        var asAny: Any {
            get {
                switch self {
                case .int(let    value): return value
                case .uInt(let   value): return value
                case .int64(let  value): return value
                case .uInt64(let value): return value
                }
            }
        }
    }
}

struct FormatByte: RawRepresentable {
    let format: Format
    let value:  Int8

    enum Format: UInt8 {
        case positiveFixint = 0x00 // 0xxxxxxx  0x00 - 0x7f
        case fixmap         = 0x80 // 1000xxxx  0x80 - 0x8f
        case fixarray       = 0x90 // 1001xxxx  0x90 - 0x9f
        case fixstr         = 0xa0 // 101xxxxx  0xa0 - 0xbf
        case `nil`    = 0xc0
        // 0xc1 is an invalid value
        case `false`  = 0xc2, `true`  = 0xc3
        case bin8     = 0xc4, bin16   = 0xc5, bin32   = 0xc6
        case ext8     = 0xc7, ext16   = 0xc8, ext32   = 0xc9
        case float32  = 0xca, float64 = 0xcb
        case uint8    = 0xcc, uint16  = 0xcd, uint32  = 0xce, uint64  = 0xcf
        case int8     = 0xd0, int16   = 0xd1, int32   = 0xd2, int64   = 0xd3
        case fixext1  = 0xd4, fixext2 = 0xd5, fixext4 = 0xd6, fixext8 = 0xd7
        case fixext16 = 0xd8
        case str8     = 0xd9, str16   = 0xda, str32   = 0xdb
        case array16  = 0xdc, array32 = 0xdd
        case map16    = 0xde, map32   = 0xdf
        case negativeFixint = 0xe0 // 111xxxxx  0xe0 - 0xff

        var hasValue: Bool {
            switch self {
            case .positiveFixint, .fixmap, .fixarray, .fixstr, .negativeFixint:
                return true
            default: return false
            }
        }

        var rawValueRange: ClosedRange<UInt8> {
            switch self { // See bit patterns above
            case .positiveFixint: return self.rawValue ... 0x7f
            case .fixmap:         return self.rawValue ... 0x8f
            case .fixarray:       return self.rawValue ... 0x9f
            case .fixstr:         return self.rawValue ... 0xbf
            case .negativeFixint: return self.rawValue ... 0xff
            default:              return self.rawValue ... self.rawValue
            }
        }

        var valueRange: ClosedRange<Int8> {
            switch self {
            case .negativeFixint:
                // Within defined value range, rawValue is the exact bit
                // representation of the assoviated value for two's complement
                // 8-bit integers.
                return Int8(bitPattern: self.rawValueRange.upperBound) ...
                       Int8(bitPattern: self.rawValueRange.lowerBound)
            default:
                return 0 ... (Int8(self.rawValueRange.upperBound -
                                   self.rawValueRange.lowerBound))
            }
        }
    }

    init(format: Format) {
        precondition(!format.hasValue)
        self.format = format
        self.value  = 0
    }

    init(format: Format, withValue value: Int8) {
        precondition(format.hasValue)
        precondition(format.valueRange.contains(value))
        self.format = format
        self.value  = value
    }

    init?(rawValue: UInt8) {
        switch rawValue {
        case Format.positiveFixint.rawValueRange: self.format = .positiveFixint
        case Format.fixmap.rawValueRange:         self.format = .fixmap
        case Format.fixarray.rawValueRange:       self.format = .fixarray
        case Format.fixstr.rawValueRange:         self.format = .fixstr
        case Format.negativeFixint.rawValueRange: self.format = .negativeFixint
        default:
            guard let format = Format(rawValue: rawValue) else {
                // The only invalid value is 0xc1, anything else means a missed
                // range.
                assert(rawValue == 0xc1)
                return nil
            }
            self.format = format
        }
        self.value = self.format == .negativeFixint ?
            Int8(bitPattern: rawValue) : // See Format.valueRange
            Int8(rawValue ^ self.format.rawValue)
    }

    var rawValue: UInt8 {
        return self.format == .negativeFixint ?
            UInt8(bitPattern: self.value) : // See Format.valueRange
            self.format.rawValue ^ UInt8(self.value)
    }
}
