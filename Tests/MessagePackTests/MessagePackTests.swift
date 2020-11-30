import MessagePack
import XCTest

final class MessagePackTests: XCTestCase {
    // TODO: Test array
    // TODO: Test map
    // TODO: Test extersions

    func testNilDataset() {
        // TODO: Test on different optional types
        self.runDatasetTests(nilDataset)
    }

    func testBoolDataset() {
        self.runDatasetTests(boolDataset)
    }

    func testBinaryDataset() {
        // TODO: Test unpacking strings as Data
        binaryDataset.withFirstVariant(self.doTestPackBinary)
        binaryDataset.withAllVariants(self.doTestUnpackBinary)
    }

    func testIntegerDatasets() {
        // The entirety of this test is covered by testIntegerCompatiblity.
        // However, this test is much less prone to breaking, so it should be
        // left as a backup.
        self.runDatasetTests(positiveIntDataset)
        self.runDatasetTests(negativeIntDataset)
    }

    func testDoubleDataset() {
        // See note for doubleDataset in Dataset.swift.
        // TODO: Add tests for +-infinity and NaNs
        self.runDatasetTests(doubleDataset)
    }

    func testFloatWithDoubleDataset() {
        // See note for doubleDataset in Dataset.swift.
        // This test will check packing and unpacking Float values to/from
        // float32 format packed values, which are always at index 1 in this
        // dataset.
        for entry in doubleDataset.entries {
            guard entry.packedValues.count > 1 else { continue }
            let float = Float(entry.value)
            let packedValue = entry.packedValues[1]
            self.doTestPack(value: float, packedValue: packedValue)
            self.doTestUnpack(value: float, variant: 1,
                              packedValue: packedValue)
        }
    }

    func testIntegerCompatiblity() {
        self.runIntegerCompatibilityTests(for: Int.self)
        self.runIntegerCompatibilityTests(for: UInt.self)
        self.runIntegerCompatibilityTests(for: Int8.self)
        self.runIntegerCompatibilityTests(for: UInt8.self)
        self.runIntegerCompatibilityTests(for: Int16.self)
        self.runIntegerCompatibilityTests(for: UInt16.self)
        self.runIntegerCompatibilityTests(for: Int32.self)
        self.runIntegerCompatibilityTests(for: UInt32.self)
        self.runIntegerCompatibilityTests(for: Int64.self)
        self.runIntegerCompatibilityTests(for: UInt64.self)
    }

    func testStringDataset() {
        self.runDatasetTests(stringDataset)
    }

    func testCount() throws {
        // Individual types are tested in doTestPack(value:packedValue:)
        var message = PackableMessage()
        XCTAssertEqual(0, message.count)
        try message.pack("foo")
        XCTAssertEqual(1, message.count)
        try message.pack(true)
        XCTAssertEqual(2, message.count)
        message.packNil()
        XCTAssertEqual(3, message.count)
        try message.pack([1, 2, 3, 4])
        XCTAssertEqual(4, message.count)
        try message.packBinary("foo".utf8)
        XCTAssertEqual(5, message.count)
        try message.pack([0: "no", 1: "yes", 2: "maybe"])
        XCTAssertEqual(6, message.count)
    }

    func testPackArrayWithoutCount() throws {
        var referenceMessage = PackableMessage()
        try referenceMessage.pack([0, 1, 2])
        var message = PackableMessage()
        try message.packArray {
            try $0.pack(0); try $0.pack(1); try $0.pack(2)
        }
        XCTAssertEqual(
            StringConvertibleBytes(referenceMessage.bytes),
            StringConvertibleBytes(message.bytes))
    }

    func testPackArrayWithCount() throws {
        var referenceMessage = PackableMessage()
        try referenceMessage.pack([0, 1, 2])
        var message = PackableMessage()
        try message.packArray(count: 3) {
            try $0.pack(0); try $0.pack(1); try $0.pack(2)
        }
        XCTAssertEqual(
            StringConvertibleBytes(referenceMessage.bytes),
            StringConvertibleBytes(message.bytes))
    }

    func testUnpackArray() throws {
        let reference = [0, 1, 2]
        var referenceMessage = PackableMessage()
        try referenceMessage.pack(reference)
        var message = UnpackableMessage(from: referenceMessage.bytes)
        var result: [Int] = []
        try message.unpackArray { nestedMessage, count in
            for _ in 0 ..< count { result.append(try nestedMessage.unpack()) }
        }
        XCTAssertEqual(reference, result)
    }

    func testPackMapWithoutCount() throws {
        let reference = ["true": true, "false": false]
        var packableMessage = PackableMessage()
        try packableMessage.packMap {
            try $0.pack("true");  try $0.pack(true)
            try $0.pack("false"); try $0.pack(false)
        }
        var unpackableMessage = UnpackableMessage(from: packableMessage.bytes)
        XCTAssertEqual(
            reference,
            try unpackableMessage.unpack() as [String : Bool])
    }

    func testPackMapWithCount() throws {
        let reference = ["true": true, "false": false]
        var packableMessage = PackableMessage()
        try packableMessage.packMap(count: 2) {
            try $0.pack("true");  try $0.pack(true)
            try $0.pack("false"); try $0.pack(false)
        }
        var unpackableMessage = UnpackableMessage(from: packableMessage.bytes)
        XCTAssertEqual(
            reference,
            try unpackableMessage.unpack() as [String : Bool])
    }

    func testUnpackMap() throws {
        let reference = ["true": true, "false": false]
        var referenceMessage = PackableMessage()
        try referenceMessage.pack(reference)
        var message = UnpackableMessage(from: referenceMessage.bytes)
        var result: [String : Bool] = [:]
        try message.unpackMap { nestedMessage, count in
            for _ in 0 ..< count {
                result[try nestedMessage.unpack()] = try nestedMessage.unpack()
            }
        }
        XCTAssertEqual(reference, result)
    }

    func runIntegerCompatibilityTests<T>(for type: T.Type)
    where T: BinaryInteger & MessagePackCompatible {
        self.runIntegerCompatibilityTests(for: type, on: positiveIntDataset)
        self.runIntegerCompatibilityTests(for: type, on: negativeIntDataset)
    }

    // For each entry in dataset, test that:
    // 1. If a value can be represented by type T, it can be encoded.
    // 2. If a value can be represented by type T, it can be decoded.
    // 3. If a value cannot be represented by type T, on attempt to decode it
    //    MessagePackError.incompatibleType is thrown.
    func runIntegerCompatibilityTests<T, U>(
        for type: T.Type, on dataset: Dataset<U>
    ) where T: BinaryInteger & MessagePackCompatible, U: BinaryInteger {
        dataset.withFirstVariant {
            guard let value: T = T(exactly: $0.value) else { return }
            self.doTestPack(value: value, packedValue: $0.packedValue)
        }
        dataset.withAllVariants {
            if let value: T = T(exactly: $0.value) {
                self.doTestUnpack(value: value, variant: $0.variant,
                                  packedValue: $0.packedValue)
            } else {
                self.doTestUnpackFailure(
                    as: T.self, value: $0.value, variant: $0.variant,
                    packedValue: $0.packedValue,
                    expectedError: .incompatibleType)
            }
        }
    }

    func runDatasetTests<T>(_ dataset: Dataset<T>) {
        dataset.withFirstVariant(self.doTestPack)
        dataset.withAllVariants(self.doTestUnpack)
    }

    func doTestPack<T>(value: T, packedValue: [UInt8])
    where T: MessagePackCompatible & Equatable {
        let context = "while packing \(T.self) value \"\(value)\""
        var message = PackableMessage()
        XCTAssertNoThrow(try message.pack(value), context)
        XCTAssertEqual(StringConvertibleBytes(packedValue),
                       StringConvertibleBytes(message.bytes), context)
        XCTAssertEqual(1, message.count, context)
    }

    func doTestUnpack<T>(value: T, variant: Int, packedValue: [UInt8])
    where T: MessagePackCompatible & Equatable {
        let context = "while unpacking variant \(variant) of " +
            "\(T.self) value \"\(value)\""
        var message = UnpackableMessage(from: packedValue)
        XCTAssertEqual(value, try message.unpack(), context)
    }

    // FIXME this is almost a verbatim copy of doTestPack
    func doTestPackBinary(value: [UInt8], packedValue: [UInt8]) {
        let context = "while packing value \"\(value)\""
        var message = PackableMessage()
        XCTAssertNoThrow(try message.packBinary(value), context)
        XCTAssertEqual(StringConvertibleBytes(packedValue),
                       StringConvertibleBytes(message.bytes), context)
        XCTAssertEqual(1, message.count, context)
    }

    // FIXME this is almost a verbatim copy of doTestUnpack
    func doTestUnpackBinary(value: [UInt8], variant: Int, packedValue: [UInt8])
    {
        let context = "while unpacking variant \(variant) of " +
            "value \"\(value)\""
        var message = UnpackableMessage(from: packedValue)
        XCTAssertEqual(value, try message.unpackBinary(), context)
    }

    func doTestUnpackFailure<T, U>(
        as type: T.Type, value: U, variant: Int, packedValue: [UInt8],
        expectedError: MessagePackError
    ) where T: MessagePackCompatible & Equatable {
        let context = "while unpacking variant \(variant) of " +
            "value \"\(value)\" as \(T.self)"
        var message = UnpackableMessage(from: packedValue)
        XCTAssertThrowsError(try message.unpack() as T, context) {
            XCTAssertEqual(expectedError, $0 as? MessagePackError, context)
        }
    }
}

// A simple wrapper for [UInt8] which provides a human-readable description
// when equality assertion fails and imposes no runtime cost otherwise.
struct StringConvertibleBytes: Equatable, CustomStringConvertible {
    let bytes: [UInt8]

    init(_ bytes: [UInt8]) {
        self.bytes = bytes
    }

    var description: String {
        self.bytes.lazy.map { String(format: "%02x", $0) }
            .joined(separator: "-")
    }
}
