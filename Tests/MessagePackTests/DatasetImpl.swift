import MessagePack
import struct Foundation.Data

struct Dataset<T: MessagePackCompatible & Equatable> {
    let entries: [Entry]

    struct Entry {
        let value: T
        let packedValues: [Data]
    }

    init(_ entries: [(value: T, packedValues: [String])]) {
        func convert(_ string: String) -> Data {
            Data(string.split(separator: "-").lazy.map {
                UInt8($0, radix: 16)!
            })
        }
        self.entries = entries.map {
            Entry(value: $0.value, packedValues: $0.packedValues.map(convert))
        }
    }

    // NOTE: Due to a long-standing bug in Swift [1], the closures are declared
    // as throwing.
    // [1]: https://bugs.swift.org/browse/SR-487

    func withAllVariants(_ closure:
        ((value: T, variant: Int, packedValue: Data)) throws -> ()
    ) rethrows {
        for entry in self.entries {
            for (variant, packedValue) in entry.packedValues.enumerated() {
                try closure((entry.value, variant, packedValue))
            }
        }
    }

    // For each entry, execute the closure only with the first variant, that
    // is, the one to which the implementation is supposed to pack the value.
    func withFirstVariant(_ closure:
        ((value: T, packedValue: Data)) throws -> ()
    ) rethrows {
        for entry in self.entries {
            try closure((entry.value, entry.packedValues[0]))
        }
    }
}
