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
            bytes.lazy.map {
                String(format: "%02x", $0)
            }.joined(separator: "-")
        }
        for entry in dataset.entries {
            let msg = { "while packing \(T.self) value \"\(entry.value)\"" }
            let message = PackableMessage()
            XCTAssertNoThrow(try message.pack(entry.value), msg())
            // XCTAssertEqual(message.bytes(), entry.packedValues[0], msg())
            XCTAssertEqual(toString(message.bytes()),
                           toString(entry.packedValues[0]), msg())
        }
    }

    func runDatasetUnpack<T>(_ dataset: Dataset<T>) throws {
        let testCases = dataset.entries.lazy.flatMap { entry in
            entry.packedValues.enumerated().lazy.map {
                (variant, packedValue) in (entry.value, variant, packedValue)
            }
        }
        for (value, variant, packedValue) in testCases {
            let message = UnpackableMessage(fromBytes: packedValue)
            XCTAssertEqual(try message.unpack(), value,
                "while unpacking variant \(variant) of " +
                "\(T.self) value \"\(value)\"")
        }
    }

    static var allTests = [
        ("testDataset", testDataset),
    ]
}
