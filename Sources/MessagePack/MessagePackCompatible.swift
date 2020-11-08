import Foundation // Provides String.init(bytes:encoding:)

public protocol MessagePackCompatible {
    init(unpackFrom: UnpackableMessage) throws
    func pack(to: PackableMessage) throws
}

extension Optional: MessagePackCompatible
where Wrapped: MessagePackCompatible {
    public init(unpackFrom message: UnpackableMessage) throws {
        if try message.peekFormatByte().format == .`nil` {
            _ = try message.readFormatByte()
            self = .none
        } else {
            self = .some(try message.unpack())
        }
    }

    public func pack(to message: PackableMessage) throws {
        switch self {
        case .none:              message.writeFormatByte(.`nil`)
        case .some(let wrapped): try message.pack(wrapped)
        }
    }
}

extension Bool: MessagePackCompatible {
    public init(unpackFrom message: UnpackableMessage) throws {
        let formatByte = try message.readFormatByte()
        switch formatByte.format {
        case .`false`: self = false
        case .`true`:  self = true
        default:       throw MessagePackError.incompatibleType
        }
    }

    public func pack(to message: PackableMessage) {
        message.writeFormatByte(self ? .`true` : .`false`)
    }
}

extension Double: MessagePackCompatible {
    public init(unpackFrom message: UnpackableMessage) throws {
        let formatByte = try message.readFormatByte()
        switch formatByte.format {
        case .float32:
            let bitPattern = try message.readInteger(as: UInt32.self)
            self.init(Float(bitPattern: bitPattern))
        case .float64:
            self.init(bitPattern: try message.readInteger(as: UInt64.self))
        default: throw MessagePackError.incompatibleType
        }
    }

    public func pack(to message: PackableMessage) {
        message.writeFormatAndInteger(.float64, self.bitPattern)
    }
}

extension Float: MessagePackCompatible {
    public init(unpackFrom message: UnpackableMessage) throws {
        let formatByte = try message.readFormatByte()
        guard formatByte.format == .float32 else {
            throw MessagePackError.incompatibleType
        }
        self.init(bitPattern: try message.readInteger(as: UInt32.self))
    }

    public func pack(to message: PackableMessage) {
        message.writeFormatAndInteger(.float32, self.bitPattern)
    }
}

// FIXME: This is ugly.
extension Int:    MessagePackCompatible { }
extension Int8:   MessagePackCompatible { }
extension Int16:  MessagePackCompatible { }
extension Int32:  MessagePackCompatible { }
extension Int64:  MessagePackCompatible { }
extension UInt:   MessagePackCompatible { }
extension UInt8:  MessagePackCompatible { }
extension UInt16: MessagePackCompatible { }
extension UInt32: MessagePackCompatible { }
extension UInt64: MessagePackCompatible { }

extension MessagePackCompatible where Self: FixedWidthInteger {
    public init(unpackFrom message: UnpackableMessage) throws {
        let formatByte = try message.readFormatByte()
        let result: Self?
        switch formatByte.format { // TODO: Make this less repetitive?
        case .uint8:
            result = Self(exactly: try message.readInteger(as: UInt8.self))
        case .uint16:
            result = Self(exactly: try message.readInteger(as: UInt16.self))
        case .uint32:
            result = Self(exactly: try message.readInteger(as: UInt32.self))
        case .uint64:
            result = Self(exactly: try message.readInteger(as: UInt64.self))
        case .int8:
            result = Self(exactly: try message.readInteger(as: Int8.self))
        case .int16:
            result = Self(exactly: try message.readInteger(as: Int16.self))
        case .int32:
            result = Self(exactly: try message.readInteger(as: Int32.self))
        case .int64:
            result = Self(exactly: try message.readInteger(as: Int64.self))
        case .positiveFixint, .negativeFixint:
            result = Self(exactly: formatByte.value)
        default: throw MessagePackError.incompatibleType
        }
        if result == nil { throw MessagePackError.incompatibleType }
        self.init(result!)
    }

    public func pack(to message: PackableMessage) {
        if let int8 = Int8(exactly: self) {
            switch int8 {
            case FormatByte.Format.positiveFixint.valueRange:
                message.writeFormatByte(.positiveFixint, withValue: int8)
            case FormatByte.Format.negativeFixint.valueRange:
                message.writeFormatByte(.negativeFixint, withValue: int8)
            default:
                message.writeFormatAndInteger(.int8, int8)
            }
        } else if let uint8  = UInt8(exactly: self) {
            message.writeFormatAndInteger(.uint8,  uint8)
        } else if let int16  = Int16(exactly: self) {
            message.writeFormatAndInteger(.int16,  int16)
        } else if let uint16 = UInt16(exactly: self) {
            message.writeFormatAndInteger(.uint16, uint16)
        } else if let int32  = Int32(exactly: self) {
            message.writeFormatAndInteger(.int32,  int32)
        } else if let uint32 = UInt32(exactly: self) {
            message.writeFormatAndInteger(.uint32, uint32)
        } else if let int64  = Int64(exactly: self) {
            message.writeFormatAndInteger(.int64,  int64)
        } else if let uint64 = UInt64(exactly: self) {
            message.writeFormatAndInteger(.uint64, uint64)
        } else {
            preconditionFailure()
        }
    }
}

extension String: MessagePackCompatible {
    public init(unpackFrom message: UnpackableMessage) throws {
        let formatByte = try message.readFormatByte()
        guard MessagePackType(formatByte) == .string else {
            throw MessagePackError.incompatibleType
        }
        let length = try message.readLength(formatByte)
        let bytes = try message.readBytes(size: length)
        guard let string = String(bytes: bytes, encoding: .utf8) else {
            throw MessagePackError.invalidUtf8String
        }
        self = string
    }

    public func pack(to message: PackableMessage) throws {
        let length = UInt(self.utf8.count)
        try message.writeHeader(forType: .string, length: length)
        message.write(bytes: self.utf8)
    }
}

extension Array: MessagePackCompatible where Element: MessagePackCompatible {
    public init(unpackFrom message: UnpackableMessage) throws {
        // FIXME: This is dumb.  UnpackableMessage.unpack() calls
        // Array.init(unpackFrom:) which in turn calls
        // UnpackableMessage.readArray(readElement:).
        self = try message.readArray() { try message.unpack() }
    }

    public func pack(to message: PackableMessage) throws {
        try message.writeHeader(forType: .array, length: UInt(self.count))
        for element in self {
            try message.pack(element)
        }
    }
}

extension Dictionary: MessagePackCompatible
where Key: MessagePackCompatible, Value: MessagePackCompatible {
    public init(unpackFrom message: UnpackableMessage) throws {
        let formatByte = try message.readFormatByte()
        guard MessagePackType(formatByte) == .map else {
            throw MessagePackError.incompatibleType
        }
        let length = try message.readLength(formatByte)
        self.init()
        // Don't do this:
        //     self.reserveCapacity(Int(length))
        // See Array.init(unpackFrom:) for explanation
        for _ in 0 ..< length {
            let key:   Key   = try message.unpack()
            let value: Value = try message.unpack()
            if self.updateValue(value, forKey: key) != nil {
                throw MessagePackError.duplicateMapKey
            }
        }
    }

    public func pack(to message: PackableMessage) throws {
        try message.writeHeader(forType: .array, length: UInt(self.count))
        for (key, value) in self {
            try message.pack(key)
            try message.pack(value)
        }
    }
}
