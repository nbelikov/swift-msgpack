import MessagePack
import XCTest

final class MessagePackTests: XCTestCase {
    func testDataset() throws {
        try self.runDatasetTests(nilDataset)
        try self.runDatasetTests(boolDataset)
        // TODO: Test unpacking strings as Data
        try self.runDatasetTests(binaryDataset)
        try self.runDatasetTests(positiveIntDataset)
        try self.runDatasetTests(negativeIntDataset)
        try self.runDatasetTests(floatDataset)
        try self.runDatasetTests(stringDataset)
    }

    func runDatasetTests<T>(_ dataset: Dataset<T>) throws {
        try dataset.withFirstVariant {
            let context = "while packing \(T.self) value \"\($0.value)\""
            let message = PackableMessage()
            XCTAssertNoThrow(try message.pack($0.value), context)
            XCTAssertEqual(StringConvertibleData($0.packedValue),
                           StringConvertibleData(message.data), context)
        }
        try dataset.withAllVariants {
            let context = "while unpacking variant \($0.variant) of " +
                "\(T.self) value \"\($0.value)\""
            let message = UnpackableMessage(fromData: $0.packedValue)
            XCTAssertEqual($0.value, try message.unpack(), context)
        }
    }

    static var allTests = [
        ("testDataset", testDataset),
    ]
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
