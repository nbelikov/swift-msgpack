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
            XCTAssertEqual(Bytes($0.packedValue),
                           Bytes(message.bytes()), context)
        }
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

// A simple wrapper for a byte array which provides a human-readable
// description when equality assertion fails and imposes no runtime cost
// otherwise.
// FIXME: Needs a less common name
struct Bytes: Equatable, CustomStringConvertible {
    let bytes: [UInt8]

    init(_ bytes: [UInt8]) {
        self.bytes = bytes
    }

    var description: String {
        bytes.lazy.map { String(format: "%02x", $0) }.joined(separator: "-")
    }
}
