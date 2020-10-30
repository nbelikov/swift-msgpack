import MessagePack
import XCTest

final class MessagePackTests: XCTestCase {
    func testDataset() throws {
        try self.runDatasetTests(nilDataset)
        try self.runDatasetTests(boolDataset)
        try self.runDatasetTests(positiveIntDataset)
        try self.runDatasetTests(negativeIntDataset)
        try self.runDatasetTests(floatDataset)
        try self.runDatasetTests(stringDataset)
    }

    func runDatasetTests<T>(_ dataset: Dataset<T>) throws {
        try self.runDatasetPack(dataset)
        try self.runDatasetUnpack(dataset)
    }

    func runDatasetPack<T>(_ dataset: Dataset<T>) throws {
        func toString(_ bytes: [UInt8]) -> String {
            bytes.lazy.map { String(format: "%02x", $0)
            }.joined(separator: "-")
        }
        try dataset.withFirstVariant {
            let context = "while packing \(T.self) value \"\($0.value)\""
            let message = PackableMessage()
            XCTAssertNoThrow(try message.pack($0.value), context)
            // TODO: Disable converting to string for better performance
            // XCTAssertEqual($0.packedValue, message.bytes(), context)
            XCTAssertEqual(toString($0.packedValue),
                           toString(message.bytes()), context)
        }
    }

    func runDatasetUnpack<T>(_ dataset: Dataset<T>) throws {
        try dataset.withAllVariants {
            let context = "while unpacking variant \($0.variant) of " +
                "\(T.self) value \"\($0.value)\""
            let message = UnpackableMessage(fromBytes: $0.packedValue)
            XCTAssertEqual($0.value, try message.unpack(), context)
        }
    }

    static var allTests = [
        ("testDataset", testDataset),
    ]
}
