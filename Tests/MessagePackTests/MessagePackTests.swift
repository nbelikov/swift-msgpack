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
        self.runDatasetTests(binaryDataset)
    }

    func testIntegerDatasets() {
        // The entirety of this test is covered by testIntegerCompatiblity.
        // However, this test is much less prone to breaking, so it should be
        // left as a backup.
        self.runDatasetTests(positiveIntDataset)
        self.runDatasetTests(negativeIntDataset)
    }

    func testDoubleDataset() {
        // TODO: Add tests for +-infinity and NaNs
        self.runDatasetTests(doubleDataset)
    }

    func testStringDataset() {
        self.runDatasetTests(stringDataset)
    }

    func testFloatWithDoubleDataset() {
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

    func doTestPack<T>(value: T, packedValue: Data)
    where T: MessagePackCompatible & Equatable {
        let context = "while packing \(T.self) value \"\(value)\""
        let message = PackableMessage()
        XCTAssertNoThrow(try message.pack(value), context)
        XCTAssertEqual(StringConvertibleData(packedValue),
                       StringConvertibleData(message.data), context)
    }

    func doTestUnpack<T>(value: T, variant: Int, packedValue: Data)
    where T: MessagePackCompatible & Equatable {
        let context = "while unpacking variant \(variant) of " +
            "\(T.self) value \"\(value)\""
        let message = UnpackableMessage(fromData: packedValue)
        XCTAssertEqual(value, try message.unpack(), context)
    }

    func doTestUnpackFailure<T, U>(
        as type: T.Type, value: U, variant: Int, packedValue: Data,
        expectedError: MessagePackError
    ) where T: MessagePackCompatible & Equatable {
        let context = "while unpacking variant \(variant) of " +
            "value \"\(value)\" as \(T.self)"
        let message = UnpackableMessage(fromData: packedValue)
        XCTAssertThrowsError(try message.unpack() as T, context) {
            XCTAssertEqual(expectedError, $0 as? MessagePackError, context)
        }
    }
}

// A simple wrapper for Data which provides a human-readable description when
// equality assertion fails and imposes no runtime cost otherwise.
struct StringConvertibleData: Equatable, CustomStringConvertible {
    let data: Data

    init(_ data: Data) {
        self.data = data
    }

    var description: String {
        data.lazy.map { String(format: "%02x", $0) }.joined(separator: "-")
    }
}
