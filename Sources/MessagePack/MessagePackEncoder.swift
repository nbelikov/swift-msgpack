final class MessagePackEncoder: Encoder, SingleValueEncodingContainer {
    enum EncoderState {
        case empty
        case packed([UInt8])
        case keyedContainer([String : MessagePackEncoder])
        case unkeyedContainer([MessagePackEncoder])
    }

    // FIXME: Containers should not access directly.
    fileprivate var state = EncoderState.empty

    public private(set) var codingPath: [CodingKey]
    public private(set) var userInfo:   [CodingUserInfoKey : Any]

    init(userInfo: [CodingUserInfoKey: Any], codingPath: [CodingKey]) {
        self.userInfo   = userInfo
        self.codingPath = codingPath
    }

    // FIXME: type is not preserved.  It is possible to request an existing
    // container keyed by different type.
    public func container<Key>(keyedBy type: Key.Type)
    -> KeyedEncodingContainer<Key> where Key: CodingKey {
        switch self.state {
        case .empty:
            self.state = .keyedContainer([:])
            fallthrough
        case .keyedContainer:
            return KeyedEncodingContainer(KeyedContainer(encoder: self))
        default: preconditionFailure() // FIXME: Add message
        }
    }

    public func singleValueContainer() -> SingleValueEncodingContainer {
        switch self.state {
        case .empty: return self
        default: preconditionFailure() // FIXME: Add message
        }
    }

    public func unkeyedContainer() -> UnkeyedEncodingContainer {
        switch self.state {
        case .empty:
            self.state = .unkeyedContainer([])
            fallthrough
        case .unkeyedContainer:
            return UnkeyedContainer(encoder: self)
        default: preconditionFailure() // FIXME: Add message
        }
    }

    public func encodeNil() throws {
        self.encodeSingleValue { $0.packNil() }
    }

    public func encode(_ value: Bool)   throws { try self.doEncode(value) }
    public func encode(_ value: String) throws { try self.doEncode(value) }
    public func encode(_ value: Double) throws { try self.doEncode(value) }
    public func encode(_ value: Float)  throws { try self.doEncode(value) }
    public func encode(_ value: Int)    throws { try self.doEncode(value) }
    public func encode(_ value: Int8)   throws { try self.doEncode(value) }
    public func encode(_ value: Int16)  throws { try self.doEncode(value) }
    public func encode(_ value: Int32)  throws { try self.doEncode(value) }
    public func encode(_ value: Int64)  throws { try self.doEncode(value) }
    public func encode(_ value: UInt)   throws { try self.doEncode(value) }
    public func encode(_ value: UInt8)  throws { try self.doEncode(value) }
    public func encode(_ value: UInt16) throws { try self.doEncode(value) }
    public func encode(_ value: UInt32) throws { try self.doEncode(value) }
    public func encode(_ value: UInt64) throws { try self.doEncode(value) }

    public func encode<T: Encodable>(_ value: T) throws {
        // FIXME: Rethrow
        try value.encode(to: self)
        try self.flatten()
    }

    var bytes: [UInt8] {
        switch self.state {
        case .packed(let bytes): return bytes
        default: preconditionFailure()
        }
    }

    // TODO: Fail early (while encoding rather than flattening)
    private func flatten() throws {
        switch self.state {
        case .empty:
            preconditionFailure() // FIXME
        case .packed:
            break
        case .keyedContainer(let container):
            try self.encodeSingleValue { message in
                // FIXME: This call will throw wrong exception
                try message.packMap(count: UInt(container.count)) {
                    for (key, value) in container {
                        try $0.pack(key)
                        try value.flatten()
                        $0.write(bytes: value.bytes)
                        $0.count += 1 // FIXME
                    }
                }
            }
        case .unkeyedContainer(let container):
            try self.encodeSingleValue { message in
                // FIXME: This call will throw wrong exception
                try message.packArray(count: UInt(container.count)) {
                    for value in container {
                        try value.flatten()
                        $0.write(bytes: value.bytes)
                        $0.count += 1 // FIXME
                    }
                }
            }
        }
    }

    private func doEncode<T: MessagePackCompatible>(_ value: T) throws {
        try self.encodeSingleValue { message in
            do {
                try message.pack(value)
            } catch {
                let context = EncodingError.Context(
                    codingPath: self.codingPath,
                    debugDescription: "", // FIXME
                    underlyingError: error)
                throw EncodingError.invalidValue(value, context)
            }
        }
    }

    private func encodeSingleValue(
        _ closure: (inout PackableMessage) throws -> ()
    ) rethrows {
        switch self.state {
        case .empty:
            var message = PackableMessage()
            try closure(&message)
            self.state = .packed(message.bytes)
            default: preconditionFailure() // FIXME: Add message
        }
    }
}

fileprivate struct KeyedContainer<K: CodingKey>
: KeyedEncodingContainerProtocol {
    private let encoder: MessagePackEncoder

    fileprivate init(encoder: MessagePackEncoder) {
        self.encoder = encoder
    }

    public var codingPath: [CodingKey] { self.encoder.codingPath }

    public func encodeNil(forKey key: K) throws {
        try self.withEncoder(forKey: key) { try $0.encodeNil() }
    }

    public func encode(_ value: Bool, forKey key: K) throws {
        try self.withEncoder(forKey: key) { try $0.encode(value) }
    }

    public func encode(_ value: String, forKey key: K) throws {
        try self.withEncoder(forKey: key) { try $0.encode(value) }
    }

    public func encode(_ value: Double, forKey key: K) throws {
        try self.withEncoder(forKey: key) { try $0.encode(value) }
    }

    public func encode(_ value: Float, forKey key: K) throws {
        try self.withEncoder(forKey: key) { try $0.encode(value) }
    }

    public func encode(_ value: Int, forKey key: K) throws {
        try self.withEncoder(forKey: key) { try $0.encode(value) }
    }

    public func encode(_ value: Int8, forKey key: K) throws {
        try self.withEncoder(forKey: key) { try $0.encode(value) }
    }

    public func encode(_ value: Int16, forKey key: K) throws {
        try self.withEncoder(forKey: key) { try $0.encode(value) }
    }

    public func encode(_ value: Int32, forKey key: K) throws {
        try self.withEncoder(forKey: key) { try $0.encode(value) }
    }

    public func encode(_ value: Int64, forKey key: K) throws {
        try self.withEncoder(forKey: key) { try $0.encode(value) }
    }

    public func encode(_ value: UInt, forKey key: K) throws {
        try self.withEncoder(forKey: key) { try $0.encode(value) }
    }

    public func encode(_ value: UInt8, forKey key: K) throws {
        try self.withEncoder(forKey: key) { try $0.encode(value) }
    }

    public func encode(_ value: UInt16, forKey key: K) throws {
        try self.withEncoder(forKey: key) { try $0.encode(value) }
    }

    public func encode(_ value: UInt32, forKey key: K) throws {
        try self.withEncoder(forKey: key) { try $0.encode(value) }
    }

    public func encode(_ value: UInt64, forKey key: K) throws {
        try self.withEncoder(forKey: key) { try $0.encode(value) }
    }

    public func encode<T: Encodable>(_ value: T, forKey key: K) throws {
        try self.withEncoder(forKey: key) { try $0.encode(value) }
    }

    public func nestedContainer<NestedKey: CodingKey>(
        keyedBy keyType: NestedKey.Type, forKey key: K
    ) -> KeyedEncodingContainer<NestedKey> {
        self.withEncoder(forKey: key) { $0.container(keyedBy: keyType) }
    }

    public func nestedUnkeyedContainer(forKey key: K)
    -> UnkeyedEncodingContainer {
        self.withEncoder(forKey: key) { $0.unkeyedContainer() }
    }

    public func superEncoder() -> Encoder {
        superEncoder(forErasedKey: SubstituteCodingKey.`super`)
    }

    public func superEncoder(forKey key: K) -> Encoder {
        superEncoder(forErasedKey: key)
    }

    private func superEncoder(forErasedKey key: CodingKey) -> Encoder {
        self.withEncoder(forKey: key) { $0 }
    }

    private func withEncoder<R>(
        forKey key: CodingKey,
        _ closure: (MessagePackEncoder) throws -> R
    ) rethrows -> R {
        try self.withContainer { container in
            var path = self.encoder.codingPath
            path.append(key)
            let nestedEncoder = container[key.stringValue,
                default: MessagePackEncoder(
                    userInfo: self.encoder.userInfo,
                    codingPath: path)]
            let result = try closure(nestedEncoder)
            container[key.stringValue] = nestedEncoder
            return result
        }
    }

    private func withContainer<R>(
        _ closure: (inout [String : MessagePackEncoder]) throws -> R
    ) rethrows -> R {
        switch self.encoder.state {
        case .keyedContainer(var container):
            let result = try closure(&container)
            self.encoder.state = .keyedContainer(container)
            return result
        default: preconditionFailure()
        }
    }
}

fileprivate struct UnkeyedContainer: UnkeyedEncodingContainer {
    private let encoder: MessagePackEncoder

    fileprivate init(encoder: MessagePackEncoder) {
        self.encoder = encoder
    }

    public var codingPath: [CodingKey] { self.encoder.codingPath }

    public var count: Int {
        self.withContainer { $0.count }
    }

    public func encodeNil() throws {
        try self.withEncoder { try $0.encodeNil() }
    }

    public func encode(_ value: Bool) throws {
        try self.withEncoder { try $0.encode(value) }
    }

    public func encode(_ value: String) throws {
        try self.withEncoder { try $0.encode(value) }
    }

    public func encode(_ value: Double) throws {
        try self.withEncoder { try $0.encode(value) }
    }

    public func encode(_ value: Float) throws {
        try self.withEncoder { try $0.encode(value) }
    }

    public func encode(_ value: Int) throws {
        try self.withEncoder { try $0.encode(value) }
    }

    public func encode(_ value: Int8) throws {
        try self.withEncoder { try $0.encode(value) }
    }

    public func encode(_ value: Int16) throws {
        try self.withEncoder { try $0.encode(value) }
    }

    public func encode(_ value: Int32) throws {
        try self.withEncoder { try $0.encode(value) }
    }

    public func encode(_ value: Int64) throws {
        try self.withEncoder { try $0.encode(value) }
    }

    public func encode(_ value: UInt) throws {
        try self.withEncoder { try $0.encode(value) }
    }

    public func encode(_ value: UInt8) throws {
        try self.withEncoder { try $0.encode(value) }
    }

    public func encode(_ value: UInt16) throws {
        try self.withEncoder { try $0.encode(value) }
    }

    public func encode(_ value: UInt32) throws {
        try self.withEncoder { try $0.encode(value) }
    }

    public func encode(_ value: UInt64) throws {
        try self.withEncoder { try $0.encode(value) }
    }

    public func encode<T: Encodable>(_ value: T) throws {
        try self.withEncoder { try $0.encode(value) }
    }

    public func nestedContainer<NestedKey>(keyedBy keyType: NestedKey.Type)
    -> KeyedEncodingContainer<NestedKey> where NestedKey : CodingKey {
        self.withEncoder { $0.container(keyedBy: keyType) }
    }

    public func nestedUnkeyedContainer() -> UnkeyedEncodingContainer {
        self.withEncoder { $0.unkeyedContainer() }
    }

    public func superEncoder() -> Encoder {
        self.withEncoder { $0 }
    }

    private func withEncoder<R>(
        _ closure: (MessagePackEncoder) throws -> R
    ) rethrows -> R {
        // FIXME: This is almost exact copy of KeyedContainer.withEncoder
        try self.withContainer { container in
            var path = self.encoder.codingPath
            path.append(SubstituteCodingKey.arrayIndex(container.count))
            let encoder = MessagePackEncoder(
                userInfo: self.encoder.userInfo, codingPath: path)
            let result = try closure(encoder)
            container.append(encoder)
            return result
        }
    }

    private func withContainer<R>(
        _ closure: (inout [MessagePackEncoder]) throws -> R
    ) rethrows -> R {
        // FIXME: This is almost exact copy of KeyedContainer.withContainer
        switch self.encoder.state {
        case .unkeyedContainer(var container):
            let result = try closure(&container)
            self.encoder.state = .unkeyedContainer(container)
            return result
        default: preconditionFailure()
        }
    }
}

fileprivate enum SubstituteCodingKey: CodingKey {
    case `super`
    case arrayIndex(Int)

    init?(stringValue: String) { fatalError("Do not use directly") }
    init?(intValue: Int)       { fatalError("Do not use directly") }

    var stringValue: String {
        switch self {
        case .`super`: return "super"
        case .arrayIndex(let index): return String(index)
        }
    }

    var intValue: Int? {
        switch self {
        case .`super`: return 0
        case .arrayIndex(let index): return index
        }
    }
}
