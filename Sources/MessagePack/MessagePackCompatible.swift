public protocol MessagePackCompatible {
    init(unpackFrom: inout UnpackableMessage) throws
    func pack(to: inout PackableMessage) throws
}

extension Optional: MessagePackCompatible
where Wrapped: MessagePackCompatible {
    public init(unpackFrom message: inout UnpackableMessage) throws {
        let type = try message.nextValueType()
        if type == .`nil` {
            try message.unpackNil()
            self = .none
        } else {
            self = .some(try message.unpack())
        }
    }

    public func pack(to message: inout PackableMessage) throws {
        switch self {
        case .none: message.packNil()
        case .some(let wrapped): try message.pack(wrapped)
        }
    }
}

extension Bool: MessagePackCompatible {
    public init(unpackFrom message: inout UnpackableMessage) throws {
        self = try message.unpackBool()
    }

    public func pack(to message: inout PackableMessage) {
        message.writeFormatByte(self ? .`true` : .`false`)
    }
}

extension Double: MessagePackCompatible {
    public init(unpackFrom message: inout UnpackableMessage) throws {
        self = try message.unpackDouble()
    }

    public func pack(to message: inout PackableMessage) {
        message.writeFormatAndInteger(.float64, self.bitPattern)
    }
}

extension Float: MessagePackCompatible {
    public init(unpackFrom message: inout UnpackableMessage) throws {
        self = try message.unpackFloat()
    }

    public func pack(to message: inout PackableMessage) {
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
    public init(unpackFrom message: inout UnpackableMessage) throws {
        self = try message.unpackInteger()
    }

    public func pack(to message: inout PackableMessage) {
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
    public init(unpackFrom message: inout UnpackableMessage) throws {
        self = try message.unpackString()
    }

    public func pack(to message: inout PackableMessage) throws {
        let length = UInt(self.utf8.count)
        try message.writeHeader(forType: .string, length: length)
        message.write(bytes: self.utf8)
    }
}

extension Array: MessagePackCompatible where Element: MessagePackCompatible {
    public init(unpackFrom message: inout UnpackableMessage) throws {
        self = try message.unpackArray { message, count in
            var result: [Element] = []
            // Don't: result.reserveCapacity(Int(count))
            // See comment for UnpackableMessage.unpackArray(:) for
            // explaination.
            for _ in 0 ..< count { result.append(try message.unpack()) }
            return result
        }
    }

    public func pack(to message: inout PackableMessage) throws {
        try message.packArray(count: UInt(self.count)) {
            for element in self { try $0.pack(element) }
        }
    }
}

extension Dictionary: MessagePackCompatible
where Key: MessagePackCompatible, Value: MessagePackCompatible {
    public init(unpackFrom message: inout UnpackableMessage) throws {
        self = try message.unpackMap { message, count in
            var result: [Key : Value] = [:]
            // Don't: result.reserveCapacity(Int(count))
            // See comment for UnpackableMessage.unpackArray(:) for
            // explaination.
            for _ in 0 ..< count {
                let key:   Key   = try message.unpack()
                let value: Value = try message.unpack()
                if result.updateValue(value, forKey: key) != nil {
                    throw MessagePackError.duplicateMapKey
                }
            }
            return result
        }
    }

    public func pack(to message: inout PackableMessage) throws {
        try message.packMap(count: UInt(self.count)) {
            for (key, value) in self {
                try $0.pack(key)
                try $0.pack(value)
            }
        }
    }
}
