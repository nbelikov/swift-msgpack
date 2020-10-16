import Foundation

struct FormatByte: RawRepresentable {
    let format: Format
    let value:  Int8

    enum Format: UInt8 {
        case positiveFixint = 0x00 // 0xxxxxxx  0x00 - 0x7f
        case fixmap         = 0x80 // 1000xxxx  0x80 - 0x8f
        case fixarray       = 0x90 // 1001xxxx  0x90 - 0x9f
        case fixstr         = 0xa0 // 101xxxxx  0xa0 - 0xbf
        case `nil`          = 0xc0
        // 0xc1 is an invalid value
        case bool           = 0xc2 // 1100001x  0xc2 - 0xc3
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
            case .positiveFixint, .fixmap, .fixarray, .fixstr, .bool,
                .negativeFixint: return true
            default: return false
            }
        }

        var rawValueRange: ClosedRange<UInt8> {
            switch self { // See bit patterns above
            case .positiveFixint: return rawValue...0x7f
            case .fixmap:         return rawValue...0x8f
            case .fixarray:       return rawValue...0x9f
            case .fixstr:         return rawValue...0xbf
            case .bool:           return rawValue...0xc3
            case .negativeFixint: return rawValue...0xff
            default:              return rawValue...rawValue
            }
        }

        var valueRange: ClosedRange<Int8> {
            switch self {
            case .negativeFixint:
                // Within defined value range, rawValue is the exact bit
                // representation of the assoviated value for two's complement
                // 8-bit integers.
                return Int8(bitPattern: rawValueRange.upperBound) ...
                       Int8(bitPattern: rawValueRange.lowerBound)
            default:
                return 0...(Int8(rawValueRange.upperBound -
                                 rawValueRange.lowerBound))
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
        case Format.positiveFixint.rawValueRange: format = .positiveFixint
        case Format.fixmap.rawValueRange:         format = .fixmap
        case Format.fixarray.rawValueRange:       format = .fixarray
        case Format.fixstr.rawValueRange:         format = .fixstr
        case Format.bool.rawValueRange:           format = .bool
        case Format.negativeFixint.rawValueRange: format = .negativeFixint
        default:
            guard let format = Format(rawValue: rawValue) else {
                // The only invalid value is 0xc1, anything else means a missed
                // range.
                assert(rawValue == 0xc1)
                return nil
            }
            self.format = format
        }
        value = format == .negativeFixint ?
            Int8(bitPattern: rawValue) : // See Format.valueRange
            Int8(rawValue ^ format.rawValue)
    }

    var rawValue: UInt8 {
        return format == .negativeFixint ?
            UInt8(bitPattern: value) : // See Format.valueRange
            format.rawValue ^ UInt8(value)
    }
}
