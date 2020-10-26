import struct Foundation.Data

struct Dataset<T> {
    let entries: [Entry]

    struct Entry {
        let value: T
        let packedValues: [Data]
    }

    init(_ entries: [(value: T, packedValues: [String])]) {
        preconditionFailure() // FIXME
    }
}
