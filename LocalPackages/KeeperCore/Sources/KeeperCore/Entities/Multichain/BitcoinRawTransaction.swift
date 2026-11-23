import Foundation
import WalletCore

/// A Bitcoin transaction in its wire form: enough to read what a previous transaction pays and to put a
/// spend signed on a hardware wallet on the wire.
struct BitcoinRawTransaction: Equatable {
    struct Input: Equatable {
        /// In the byte order the transaction carries it, the reverse of the displayed id.
        let previousTxid: Data
        let previousIndex: UInt32
        let script: Data
        let sequence: UInt32
        let witness: [Data]
    }

    struct Output: Equatable {
        let amount: UInt64
        let script: Data
    }

    let version: UInt32
    let inputs: [Input]
    let outputs: [Output]
    let lockTime: UInt32
}

extension BitcoinRawTransaction {
    /// `nil` for bytes that are not exactly one transaction.
    init?(parsing data: Data) {
        var reader = Reader(bytes: [UInt8](data))
        guard let version = reader.uint32() else {
            return nil
        }
        let hasWitness = reader.peek(2) == [0x00, 0x01]
        if hasWitness {
            reader.skip(2)
        }
        guard let inputCount = reader.compactSize() else {
            return nil
        }
        var inputs: [(txid: Data, index: UInt32, script: Data, sequence: UInt32)] = []
        for _ in 0 ..< inputCount {
            guard let txid = reader.bytes(32), let index = reader.uint32(), let script = reader.sized(), let sequence = reader.uint32() else {
                return nil
            }
            inputs.append((txid, index, script, sequence))
        }
        guard let outputCount = reader.compactSize() else {
            return nil
        }
        var outputs: [Output] = []
        for _ in 0 ..< outputCount {
            guard let amount = reader.uint64(), let script = reader.sized() else {
                return nil
            }
            outputs.append(Output(amount: amount, script: script))
        }
        var witnesses: [[Data]] = Array(repeating: [], count: inputs.count)
        if hasWitness {
            for index in inputs.indices {
                guard let count = reader.compactSize() else {
                    return nil
                }
                for _ in 0 ..< count {
                    guard let item = reader.sized() else {
                        return nil
                    }
                    witnesses[index].append(item)
                }
            }
        }
        guard let lockTime = reader.uint32(), reader.isAtEnd else {
            return nil
        }
        self.init(
            version: version,
            inputs: zip(inputs, witnesses).map { Input(previousTxid: $0.txid, previousIndex: $0.index, script: $0.script, sequence: $0.sequence, witness: $1) },
            outputs: outputs,
            lockTime: lockTime
        )
    }

    func serialized(withWitness: Bool = true) -> Data {
        let hasWitness = withWitness && inputs.contains { !$0.witness.isEmpty }
        let inputParts: [Data] = inputs.map { input in
            [input.previousTxid, littleEndian(input.previousIndex), compactSize(input.script.count), input.script, littleEndian(input.sequence)].joined
        }
        let outputParts: [Data] = outputs.map(\.serialized)
        let witnessParts: [Data] = inputs.map { input in
            ([compactSize(input.witness.count)] + input.witness.flatMap { [compactSize($0.count), $0] }).joined
        }
        let head: [Data] = [littleEndian(version), hasWitness ? Data([0x00, 0x01]) : Data(), compactSize(inputs.count)]
        let tail: [Data] = [compactSize(outputs.count)] + outputParts + (hasWitness ? witnessParts : []) + [littleEndian(lockTime)]
        return (head + inputParts + tail).joined
    }

    /// In transaction byte order: the displayed id reversed.
    var txid: Data {
        Hash.sha256SHA256(data: serialized(withWitness: false))
    }

    /// The BIP-143 digest that input `index`, spending `amount` from the P2WPKH of `publicKey`, signs with SIGHASH_ALL.
    func witnessV0Sighash(input index: Int, amount: UInt64, publicKey: Data) -> Data {
        let input = inputs[index]
        let prevouts: Data = inputs.map { $0.previousTxid + littleEndian($0.previousIndex) }.joined
        let sequences: Data = inputs.map { littleEndian($0.sequence) }.joined
        let scriptCode: Data = Data([0x19, 0x76, 0xA9, 0x14]) + Hash.sha256RIPEMD(data: publicKey) + Data([0x88, 0xAC])
        let preimage: [Data] = [
            littleEndian(version),
            Hash.sha256SHA256(data: prevouts),
            Hash.sha256SHA256(data: sequences),
            input.previousTxid,
            littleEndian(input.previousIndex),
            scriptCode,
            littleEndian(amount),
            littleEndian(input.sequence),
            Hash.sha256SHA256(data: outputs.map(\.serialized).joined),
            littleEndian(lockTime),
            littleEndian(UInt32(1)),
        ]
        return Hash.sha256SHA256(data: preimage.joined)
    }

    /// `0 ‖ 20-byte key hash`, the script a P2WPKH output of `publicKey` locks with.
    static func witnessV0Script(publicKey: Data) -> Data {
        Data([0x00, 0x14]) + Hash.sha256RIPEMD(data: publicKey)
    }
}

private struct Reader {
    let bytes: [UInt8]
    private(set) var offset = 0

    var isAtEnd: Bool {
        offset == bytes.count
    }

    func peek(_ count: Int) -> [UInt8] {
        Array(bytes[offset ..< min(offset + count, bytes.count)])
    }

    mutating func skip(_ count: Int) {
        offset += count
    }

    mutating func bytes(_ count: Int) -> Data? {
        guard count >= 0, offset + count <= bytes.count else {
            return nil
        }
        defer { offset += count }
        return Data(bytes[offset ..< offset + count])
    }

    mutating func uint32() -> UInt32? {
        bytes(4).map { $0.reversed().reduce(UInt32(0)) { $0 << 8 | UInt32($1) } }
    }

    mutating func uint64() -> UInt64? {
        bytes(8).map { $0.reversed().reduce(UInt64(0)) { $0 << 8 | UInt64($1) } }
    }

    mutating func compactSize() -> Int? {
        guard let first = bytes(1)?.first else {
            return nil
        }
        let value: UInt64? = switch first {
        case 0xFD: bytes(2).map { $0.reversed().reduce(UInt64(0)) { $0 << 8 | UInt64($1) } }
        case 0xFE: uint32().map(UInt64.init)
        case 0xFF: uint64()
        default: UInt64(first)
        }
        return value.flatMap { $0 <= UInt64(bytes.count) ? Int($0) : nil }
    }

    mutating func sized() -> Data? {
        compactSize().flatMap { bytes($0) }
    }
}

private extension BitcoinRawTransaction.Output {
    var serialized: Data {
        [littleEndian(amount), compactSize(script.count), script].joined
    }
}

private extension [Data] {
    var joined: Data {
        reduce(Data(), +)
    }
}

private func compactSize(_ value: Int) -> Data {
    switch value {
    case ..<0xFD:
        Data([UInt8(value)])
    case ..<0x10000:
        Data([0xFD]) + littleEndian(UInt16(value))
    default:
        Data([0xFE]) + littleEndian(UInt32(value))
    }
}

private func littleEndian<T: FixedWidthInteger>(_ value: T) -> Data {
    withUnsafeBytes(of: value.littleEndian) { Data($0) }
}
