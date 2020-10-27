import MessagePack

struct Dataset<T: MessagePackCompatible & Equatable> {
    let entries: [Entry]

    struct Entry {
        let value: T
        let packedValues: [[UInt8]]
    }

    init(_ entries: [(value: T, packedValues: [String])]) {
        func convert(_ string: String) -> [UInt8] {
            string.split(separator: "-").map { UInt8($0, radix: 16)! }
        }
        self.entries = entries.map {
            Entry(value: $0.value, packedValues: $0.packedValues.map(convert))
        }
    }
}
