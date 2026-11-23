import CryptoKit
import Foundation

/// Ledger's Bitcoin app, version 2.1 and later: it signs PSBTv2 for a wallet policy and asks the client for
/// what it needs of them through commands answered by `BitcoinClient`.
public enum BitcoinApp {
    public struct Input: Sendable {
        /// In the byte order the transaction carries it, the reverse of the displayed id.
        public let previousTxid: Data
        public let previousIndex: UInt32
        public let amount: UInt64
        public let script: Data
        /// The compressed key that signs the input and its path.
        public let publicKey: Data
        public let path: [UInt32]
        /// The transaction the input spends, so the app can check its amount; `nil` when it could not be found.
        public let previousTransaction: Data?
        public let sequence: UInt32

        public init(previousTxid: Data, previousIndex: UInt32, amount: UInt64, script: Data, publicKey: Data, path: [UInt32], previousTransaction: Data?, sequence: UInt32) {
            self.previousTxid = previousTxid
            self.previousIndex = previousIndex
            self.amount = amount
            self.script = script
            self.publicKey = publicKey
            self.path = path
            self.previousTransaction = previousTransaction
            self.sequence = sequence
        }
    }

    public struct Output: Sendable {
        public let amount: UInt64
        public let script: Data
        /// The key and path of an output that pays back to the wallet, so the app does not show it as a payment.
        public let change: (publicKey: Data, path: [UInt32])?

        public init(amount: UInt64, script: Data, change: (publicKey: Data, path: [UInt32])?) {
            self.amount = amount
            self.script = script
            self.change = change
        }
    }

    public struct Transaction: Sendable {
        public let version: UInt32
        public let lockTime: UInt32
        public let inputs: [Input]
        public let outputs: [Output]

        public init(version: UInt32, lockTime: UInt32, inputs: [Input], outputs: [Output]) {
            self.version = version
            self.lockTime = lockTime
            self.inputs = inputs
            self.outputs = outputs
        }
    }

    /// A signature the app yielded: the input, the key it signed with, and DER followed by the sighash byte.
    public struct Signature: Equatable, Sendable {
        public let inputIndex: Int
        public let publicKey: Data
        public let signature: Data
    }

    /// `wpkh(@0/**)` over one account key, a default policy the app knows without registering it.
    public struct Policy: Sendable {
        let keyInfo: Data
        static let template = Data("wpkh(@0/**)".utf8)

        init(keyInfo: String) {
            self.keyInfo = Data(keyInfo.utf8)
        }

        /// `fingerprint` is the device's master key fingerprint; `accountXpub` the key at `m/84'/0'/account'`.
        public init(fingerprint: Data, account: Int, accountXpub: String) {
            let origin = fingerprint.map { String(format: "%02x", $0) }.joined()
            self.init(keyInfo: "[\(origin)/84'/0'/\(account)']\(accountXpub)")
        }

        var serialized: Data {
            Data([0x02, 0x00]) + compactSize(Self.template.count) + sha256(Self.template)
                + compactSize(1) + BitcoinMerkle.root(of: [keyInfo])
        }

        var id: Data {
            sha256(serialized)
        }

        var knowledge: BitcoinClient.Knowledge {
            BitcoinClient.Knowledge(lists: [[keyInfo]], preimages: [serialized, Self.template])
        }
    }

    /// `m/84'/0'/account'`, the native SegWit account Ledger Live uses.
    public static func accountPath(account: Int) -> [UInt32] {
        [84 | LedgerPath.hardened, LedgerPath.hardened, UInt32(account) | LedgerPath.hardened]
    }

    static let cla: UInt8 = 0xE1
    static let protocolVersion: UInt8 = 0x01

    /// PSBTv2 as the app reads it: the global map, then a map per input and per output, each key to its value.
    static func psbt(_ transaction: Transaction, fingerprint: Data) -> (global: [Data: Data], inputs: [[Data: Data]], outputs: [[Data: Data]]) {
        let derivation = { (path: [UInt32]) in fingerprint + path.flatMap { littleEndian($0) } }
        let global: [Data: Data] = [
            Data([0x02]): littleEndian(transaction.version),
            Data([0x03]): littleEndian(transaction.lockTime),
            Data([0x04]): compactSize(transaction.inputs.count),
            Data([0x05]): compactSize(transaction.outputs.count),
            Data([0xFB]): littleEndian(UInt32(2)),
        ]
        let inputs = transaction.inputs.map { input in
            [
                Data([0x00]): input.previousTransaction,
                Data([0x01]): littleEndian(input.amount) + compactSize(input.script.count) + input.script,
                Data([0x06]) + input.publicKey: derivation(input.path),
                Data([0x0E]): input.previousTxid,
                Data([0x0F]): littleEndian(input.previousIndex),
                Data([0x10]): littleEndian(input.sequence),
            ].compactMapValues { $0 }
        }
        let outputs = transaction.outputs.map { output in
            [Data([0x03]): littleEndian(output.amount), Data([0x04]): output.script]
                .merging(output.change.map { [Data([0x02]) + $0.publicKey: derivation($0.path)] } ?? [:]) { first, _ in first }
        }
        return (global, inputs, outputs)
    }

    static func signature(yielded: Data) -> Signature? {
        let bytes = [UInt8](yielded)
        guard let (index, indexLength) = readCompactSize(bytes, at: 0), index < 0x8000_0000,
              bytes.count > indexLength, bytes.count > indexLength + 1 + Int(bytes[indexLength])
        else {
            return nil
        }
        let keyEnd = indexLength + 1 + Int(bytes[indexLength])
        return Signature(inputIndex: Int(index), publicKey: Data(bytes[indexLength + 1 ..< keyEnd]), signature: Data(bytes[keyEnd...]))
    }
}

public extension LedgerLink {
    func bitcoinMasterFingerprint() async throws -> Data {
        let reply = try await bitcoinCommand(ins: 0x05, data: Data(), client: BitcoinClient(), timeout: 10).reply
        guard reply.count == 4 else {
            throw LedgerTransportError.invalidResponse
        }
        return reply
    }

    /// The extended key of `path` as the app encodes it, `xpub…`.
    func bitcoinExtendedPublicKey(path: [UInt32], display: Bool = false) async throws -> String {
        let reply = try await bitcoinCommand(
            ins: 0x00,
            data: Data([display ? 1 : 0]) + LedgerPath.data(path),
            client: BitcoinClient(),
            timeout: display ? nil : 10
        ).reply
        return String(decoding: reply, as: UTF8.self)
    }

    /// The receive address `index` of `policy`; with `display` the device shows it for the user to confirm.
    func bitcoinWalletAddress(policy: BitcoinApp.Policy, index: UInt32, display: Bool) async throws -> String {
        let reply = try await bitcoinCommand(
            ins: 0x03,
            data: Data([display ? 1 : 0]) + policy.id + Data(count: 32) + Data([0]) + bigEndian(index),
            client: BitcoinClient(knowledge: policy.knowledge),
            timeout: display ? nil : 10
        ).reply
        return String(decoding: reply, as: UTF8.self)
    }

    /// Signs every input `policy` owns and returns what the app yielded.
    func signBitcoinTransaction(_ transaction: BitcoinApp.Transaction, policy: BitcoinApp.Policy, fingerprint: Data) async throws -> [BitcoinApp.Signature] {
        let (global, inputs, outputs) = BitcoinApp.psbt(transaction, fingerprint: fingerprint)
        let maps = [global] + inputs + outputs
        let inputCommitments = inputs.map(BitcoinMerkle.commitment)
        let outputCommitments = outputs.map(BitcoinMerkle.commitment)
        let knowledge = maps.map(BitcoinClient.Knowledge.init(map:)).reduce(policy.knowledge) { $0.merging($1) }
            .merging(BitcoinClient.Knowledge(lists: [inputCommitments, outputCommitments], preimages: []))
        let data = BitcoinMerkle.commitment(global)
            + compactSize(inputs.count) + BitcoinMerkle.root(of: inputCommitments)
            + compactSize(outputs.count) + BitcoinMerkle.root(of: outputCommitments)
            + policy.id + Data(count: 32)
        let client = try await bitcoinCommand(ins: 0x04, data: data, client: BitcoinClient(knowledge: knowledge), timeout: nil).client
        return client.yielded.compactMap(BitcoinApp.signature(yielded:))
    }

    /// Sends one command and answers the app's client commands until it finishes.
    private func bitcoinCommand(ins: UInt8, data: Data, client: BitcoinClient, timeout: TimeInterval?) async throws -> (reply: Data, client: BitcoinClient) {
        var request = Data([BitcoinApp.cla, ins, 0x00, BitcoinApp.protocolVersion, UInt8(data.count)]) + data
        var client = client
        while true {
            let response = if let timeout {
                try await[UInt8](exchange(request, timeout: timeout))
            } else {
                try await[UInt8](exchange(request))
            }
            guard response.count >= 2 else {
                throw LedgerTransportError.invalidResponse
            }
            let statusWord = UInt16(response[response.count - 2]) << 8 | UInt16(response[response.count - 1])
            let reply = Data(response.dropLast(2))
            switch statusWord {
            case 0x9000:
                return (reply, client)
            case 0xE000:
                let (answer, next) = try client.answering(reply)
                guard answer.count <= 255 else {
                    throw LedgerTransportError.invalidRequest
                }
                client = next
                request = Data([0xF8, 0x01, 0x00, BitcoinApp.protocolVersion, UInt8(answer.count)]) + answer
            default:
                throw LedgerStatusError(statusWord: statusWord)
            }
        }
    }
}

/// What the client tells the app on request: preimages of hashes it committed to, Merkle proofs of the
/// lists, and the elements that did not fit a reply. Each answer returns the client for the next request.
struct BitcoinClient: Sendable {
    struct Knowledge: Sendable {
        let preimages: [Data: Data]
        let trees: [Data: [Data]]

        init(lists: [[Data]], preimages: [Data]) {
            let leaves = lists.flatMap { $0 }.map { Data([0x00]) + $0 }
            self.preimages = Dictionary((leaves + preimages).map { (sha256($0), $0) }, uniquingKeysWith: { first, _ in first })
            trees = Dictionary(lists.map { (BitcoinMerkle.root(of: $0), $0.map(BitcoinMerkle.leaf)) }, uniquingKeysWith: { first, _ in first })
        }

        /// A map's keys and values are each a list.
        init(map: [Data: Data]) {
            let keys = map.keys.sorted { $0.lexicographicallyPrecedes($1) }
            self.init(lists: [keys, keys.compactMap { map[$0] }], preimages: [])
        }

        private init(preimages: [Data: Data], trees: [Data: [Data]]) {
            self.preimages = preimages
            self.trees = trees
        }

        func merging(_ other: Knowledge) -> Knowledge {
            Knowledge(
                preimages: preimages.merging(other.preimages) { first, _ in first },
                trees: trees.merging(other.trees) { first, _ in first }
            )
        }
    }

    let knowledge: Knowledge
    let pending: [Data]
    let yielded: [Data]

    init(knowledge: Knowledge = Knowledge(lists: [], preimages: []), pending: [Data] = [], yielded: [Data] = []) {
        self.knowledge = knowledge
        self.pending = pending
        self.yielded = yielded
    }

    func answering(_ request: Data) throws -> (answer: Data, client: BitcoinClient) {
        let bytes = [UInt8](request)
        switch bytes.first {
        case 0x10:
            return (Data(), BitcoinClient(knowledge: knowledge, pending: pending, yielded: yielded + [Data(bytes.dropFirst())]))
        case 0x40:
            guard bytes.count == 34, bytes[1] == 0, let preimage = knowledge.preimages[Data(bytes[2...])] else {
                throw LedgerTransportError.invalidRequest
            }
            let prefix = compactSize(preimage.count)
            let inline = min(preimage.count, 255 - prefix.count - 1)
            let rest = preimage.dropFirst(inline).map { Data([$0]) }
            return (prefix + Data([UInt8(inline)]) + preimage.prefix(inline), with(pending: pending + rest))
        case 0x41:
            guard bytes.count >= 35, pending.isEmpty, let leaves = knowledge.trees[Data(bytes[1 ..< 33])] else {
                throw LedgerTransportError.invalidRequest
            }
            guard let (size, sizeLength) = readCompactSize(bytes, at: 33),
                  let (index, indexLength) = readCompactSize(bytes, at: 33 + sizeLength)
            else {
                throw LedgerTransportError.invalidRequest
            }
            guard 33 + sizeLength + indexLength == bytes.count, size == UInt64(leaves.count), index < size else {
                throw LedgerTransportError.invalidRequest
            }
            let proof = BitcoinMerkle.proof(of: Int(index), in: leaves)
            let inline = min(proof.count, (255 - 32 - 1 - 1) / 32)
            let answer = leaves[Int(index)] + Data([UInt8(proof.count), UInt8(inline)]) + proof.prefix(inline).reduce(Data(), +)
            return (answer, with(pending: Array(proof.dropFirst(inline))))
        case 0x42:
            guard bytes.count == 65, let leaves = knowledge.trees[Data(bytes[1 ..< 33])] else {
                throw LedgerTransportError.invalidRequest
            }
            let index = leaves.firstIndex(of: Data(bytes[33...]))
            return (Data([index == nil ? 0 : 1]) + compactSize(index ?? 0), self)
        case 0xA0:
            guard bytes.count == 1, let length = pending.first?.count, pending.allSatisfy({ $0.count == length }) else {
                throw LedgerTransportError.invalidRequest
            }
            let count = min(pending.count, 253 / length)
            return (Data([UInt8(count), UInt8(length)]) + pending.prefix(count).reduce(Data(), +), with(pending: Array(pending.dropFirst(count))))
        default:
            throw LedgerTransportError.invalidRequest
        }
    }

    private func with(pending: [Data]) -> BitcoinClient {
        BitcoinClient(knowledge: knowledge, pending: pending, yielded: yielded)
    }
}

/// The Merkle trees the app commits to lists with: leaves `sha256(0 ‖ element)`, nodes `sha256(1 ‖ left ‖ right)`,
/// the left subtree the largest power of two below the count.
enum BitcoinMerkle {
    static func leaf(_ element: Data) -> Data {
        sha256(Data([0x00]) + element)
    }

    static func root(of elements: [Data]) -> Data {
        elements.isEmpty ? Data(count: 32) : node(elements.map(leaf))
    }

    /// The siblings on the way from leaf `index` up to the root.
    static func proof(of index: Int, in leaves: [Data]) -> [Data] {
        guard leaves.count > 1 else {
            return []
        }
        let split = leftCount(leaves.count)
        return index < split
            ? proof(of: index, in: Array(leaves[..<split])) + [node(Array(leaves[split...]))]
            : proof(of: index - split, in: Array(leaves[split...])) + [node(Array(leaves[..<split]))]
    }

    /// `count ‖ root of the sorted keys ‖ root of their values`.
    static func commitment(_ map: [Data: Data]) -> Data {
        let keys = map.keys.sorted { $0.lexicographicallyPrecedes($1) }
        return compactSize(keys.count) + root(of: keys) + root(of: keys.compactMap { map[$0] })
    }

    private static func node(_ leaves: [Data]) -> Data {
        guard leaves.count > 1 else {
            return leaves[0]
        }
        let split = leftCount(leaves.count)
        return sha256(Data([0x01]) + node(Array(leaves[..<split])) + node(Array(leaves[split...])))
    }

    private static func leftCount(_ count: Int) -> Int {
        var power = 1
        while power * 2 < count {
            power *= 2
        }
        return power
    }
}

private func sha256(_ data: Data) -> Data {
    Data(SHA256.hash(data: data))
}

func compactSize(_ value: Int) -> Data {
    switch value {
    case ..<0xFD:
        Data([UInt8(value)])
    case ..<0x10000:
        Data([0xFD]) + littleEndian(UInt16(value))
    default:
        Data([0xFE]) + littleEndian(UInt32(value))
    }
}

func readCompactSize(_ bytes: [UInt8], at offset: Int) -> (value: UInt64, length: Int)? {
    guard offset < bytes.count else {
        return nil
    }
    let length = switch bytes[offset] {
    case 0xFD: 2
    case 0xFE: 4
    case 0xFF: 8
    default: 0
    }
    guard length > 0 else {
        return (UInt64(bytes[offset]), 1)
    }
    guard offset + 1 + length <= bytes.count else {
        return nil
    }
    let value = bytes[offset + 1 ... offset + length].reversed().reduce(UInt64(0)) { $0 << 8 | UInt64($1) }
    return (value, 1 + length)
}

func littleEndian<T: FixedWidthInteger>(_ value: T) -> Data {
    withUnsafeBytes(of: value.littleEndian) { Data($0) }
}

private func bigEndian(_ value: UInt32) -> Data {
    withUnsafeBytes(of: value.bigEndian) { Data($0) }
}
