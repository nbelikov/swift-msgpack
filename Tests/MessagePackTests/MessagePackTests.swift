import MessagePack
import XCTest

final class MessagePackTests: XCTestCase {
    func testDataset() throws {
        try self.runDatasetTests(nilData)
        try self.runDatasetTests(boolData)
        try self.runDatasetTests(positiveIntData)
        try self.runDatasetTests(negativeIntData)
        try self.runDatasetTests(floatData)
        try self.runDatasetTests(stringData)
    }

    func runDatasetTests<T>(_ dataset: Dataset<T>) throws {
        try self.runDatasetPack(dataset)
        try self.runDatasetUnpack(dataset)
    }

    func runDatasetPack<T>(_ dataset: Dataset<T>) throws {
        for entry in dataset.entries {
            let msg = { "while packing \(T.self) value \"\(entry.value)\"" }
            let message = PackableMessage()
            XCTAssertNoThrow(try message.pack(entry.value), msg())
            XCTAssertEqual(message.bytes(), entry.packedValues[0], msg())
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
