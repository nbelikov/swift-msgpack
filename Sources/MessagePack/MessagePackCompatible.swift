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
        case .none:              try message.writeFormatByte(.`nil`)
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

    public func pack(to message: PackableMessage) throws {
        try message.writeFormatByte(self ? .`true` : .`false`)
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

    public func pack(to message: PackableMessage) throws {
        try message.writeFormatByte(.float64)
        try message.writeInteger(self.bitPattern)
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

    public func pack(to message: PackableMessage) throws {
        try message.writeFormatByte(.float32)
        try message.writeInteger(self.bitPattern)
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

    public func pack(to message: PackableMessage) throws {
        if let int8 = Int8(exactly: self) {
            switch int8 {
            case FormatByte.Format.positiveFixint.valueRange:
                try message.writeFormatByte(.positiveFixint, withValue: int8)
            case FormatByte.Format.negativeFixint.valueRange:
                try message.writeFormatByte(.negativeFixint, withValue: int8)
            default:
                try self.write(to: message, format: .int8, value: int8)
            }
        } else if let uint8  = UInt8(exactly: self) {
            try self.write(to: message, format: .uint8,  value: uint8)
        } else if let int16  = UInt16(exactly: self) {
            try self.write(to: message, format: .int16,  value: int16)
        } else if let uint16 = UInt16(exactly: self) {
            try self.write(to: message, format: .uint16, value: uint16)
        } else if let int32  = UInt32(exactly: self) {
            try self.write(to: message, format: .int32,  value: int32)
        } else if let uint32 = UInt32(exactly: self) {
            try self.write(to: message, format: .uint32, value: uint32)
        } else if let int64  = UInt64(exactly: self) {
            try self.write(to: message, format: .int64,  value: int64)
        } else if let uint64 = UInt64(exactly: self) {
            try self.write(to: message, format: .uint64, value: uint64)
        }
    }

    func write<T: FixedWidthInteger>(to message: PackableMessage,
        format: FormatByte.Format, value: T) throws {
        try message.writeFormatByte(format)
        try message.writeInteger(value)
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

    public func pack(to message: PackableMessage) throws {
        guard let data = self.data(using: .utf8) else {
            throw MessagePackError.invalidUtf8String
        }
        try message.writeHeader(forType: .string, length: UInt(data.count))
        try message.writer.write(data: data)
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
