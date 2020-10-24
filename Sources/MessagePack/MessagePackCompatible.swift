public protocol MessagePackCompatible {
    init(unpackFrom: UnpackableMessage) throws
    // func pack(to: PackableMessage) throws
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
}

extension Double: MessagePackCompatible {
    public init(unpackFrom message: UnpackableMessage) throws {
        let formatByte = try message.readFormatByte()
        guard formatByte.format == .float64 else {
            throw MessagePackError.incompatibleType
        }
        self.init(bitPattern: try message.readInteger(as: UInt64.self))
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
}

extension String: MessagePackCompatible {
    public init(unpackFrom message: UnpackableMessage) throws {
        let formatByte = try message.readFormatByte()
        guard MessagePackType(formatByte) == .string else {
            throw MessagePackError.incompatibleType
        }
        let length = try message.readLength(formatByte)
        let data = try message.reader.readAsData(size: length)
        guard let string = String(data: data, encoding: .utf8) else {
            throw MessagePackError.invalidUtf8String
        }
        self = string
    }
}

extension Array: MessagePackCompatible where Element: MessagePackCompatible {
    public init(unpackFrom message: UnpackableMessage) throws {
        let formatByte = try message.readFormatByte()
        guard MessagePackType(formatByte) == .array else {
            throw MessagePackError.incompatibleType
        }
        let length = try message.readLength(formatByte)
        // Don't do this:
        //     self = try (0 ..< length).map { try message.unpack() }
        // The implementation of Collection.map(_:) will call
        // reserveCapacity(_:) on resulting array.  Since length is not
        // sanitized, this would open a possibility for a memory exhaustion
        // attack.
        self.init()
        for _ in 0 ..< length {
            self.append(try message.unpack())
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
}
