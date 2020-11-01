import MessagePack
import XCTest

final class MessagePackTests: XCTestCase {
    func testDataset() throws {
        self.runDatasetTests(nilDataset)
        self.runDatasetTests(boolDataset)
        // TODO: Test unpacking strings as Data
        self.runDatasetTests(binaryDataset)
        // TODO: Test on various integer types
        self.runDatasetTests(positiveIntDataset)
        self.runDatasetTests(negativeIntDataset)
        // TODO: Add tests for +-infinity and NaNs
        self.runDatasetTests(doubleDataset)
        self.runDatasetTests(stringDataset)
        // TODO: Test array
        // TODO: Test map
        // TODO: Test extersions
    }

    func testFloatDataset() {
        for entry in doubleDataset.entries {
            guard entry.packedValues.count > 1 else { continue }
            let float = Float(entry.value)
            let packedValue = entry.packedValues[1]
            self.doTestPack(value: float, packedValue: packedValue)
            self.doTestUnpack(value: float, variant: 1,
                              packedValue: packedValue)
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

    static var allTests = [
        ("testDataset", testDataset),
        ("testFloatDataset", testFloatDataset),
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
