import Foundation

struct FormatByte: RawRepresentable {
    let format: Format
    let value:  UInt8

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

        var maximalValue: UInt8 {
            switch self {
            case .positiveFixint: return 0x7f // See bit patterns above
            case .fixmap:         return 0x0f
            case .fixarray:       return 0x0f
            case .fixstr:         return 0x1f
            case .bool:           return 0x01
            case .negativeFixint: return 0x1f
            default:              return 0x00
            }
        }

        var rawValueRange: ClosedRange<UInt8> {
            return self.rawValue...(self.rawValue + self.maximalValue)
        }
    }

    init(format: Format) {
        precondition(format.maximalValue == 0)
        self.format = format
        self.value  = 0
    }

    init(format: Format, withValue value: UInt8) {
        precondition(format.maximalValue > 0)
        precondition(value <= format.maximalValue)
        self.format = format
        self.value  = value
    }

    init?(rawValue: UInt8) {
        let format: Format?
        switch rawValue {
        case Format.positiveFixint.rawValueRange: format = .positiveFixint
        case Format.fixmap.rawValueRange:         format = .fixmap
        case Format.fixarray.rawValueRange:       format = .fixarray
        case Format.fixstr.rawValueRange:         format = .fixstr
        case Format.bool.rawValueRange:           format = .bool
        case Format.negativeFixint.rawValueRange: format = .negativeFixint
        default: format = Format(rawValue: rawValue)
        }
        if format == nil { return nil }
        self.format = format!
        self.value  = rawValue ^ format!.rawValue
    }

    var rawValue: UInt8 {
        return self.format.rawValue ^ self.value
    }
}
