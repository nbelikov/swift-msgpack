enum MessagePackError: Error {
    case invalidMessage
    case unexpectedEndOfMessage
    case invalidUtf8String
    case duplicateMapKey
    case incompatibleType
}

public enum MessagePackType {
    case integer
    case `nil`
    case bool
    case float
    case double
    case string
    case binary
    case array
    case map
    case `extension`

    init(_ formatByte: FormatByte) {
        switch formatByte.format {
        case .uint8, .uint16, .uint32, .uint64, .int8, .int16, .int32, .int64,
             .positiveFixint, .negativeFixint: self = .integer
        case .`nil`:                         self = .`nil`
        case .`false`, .`true`:              self = .bool
        case .float32:                       self = .float
        case .float64:                       self = .double
        case .fixstr, .str8, .str16, .str32: self = .string
        case .bin8, .bin16, .bin32:          self = .binary
        case .fixarray, .array16, .array32:  self = .array
        case .fixmap, .map16, .map32:        self = .map
        case .fixext1, .fixext2, .fixext4, .fixext8, .fixext16,
             .ext8, .ext16, .ext32: self = .`extension`
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
