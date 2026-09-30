import BigInt
import Foundation

/// The two contracts this client ever asks a node to build, with the `Any` type url each carries
/// inside `raw_data`.
enum TronContractType: UInt64 {
    case transfer = 1
    case triggerSmartContract = 31

    var typeURL: String {
        switch self {
        case .transfer:
            return "type.googleapis.com/protocol.TransferContract"
        case .triggerSmartContract:
            return "type.googleapis.com/protocol.TriggerSmartContract"
        }
    }
}

public extension Transaction {
    /// The transfer a node was asked to build. TRON assembles `raw_data` server-side and the
    /// signature covers those bytes verbatim, so comparing them against the request is the only
    /// thing tying what the user confirmed to what the key signs.
    enum ExpectedContract {
        case nativeTransfer(owner: Address, to: Address, amountSun: BigUInt)
        case smartContractCall(owner: Address, contract: Address, data: Data, feeLimit: Int)
    }

    enum ContractMismatch: Swift.Error, Equatable {
        case malformedRawData
        /// Exactly one contract per transaction: a second one would ride along uncompared.
        case contractCount(Int)
        case contractType
        case typeURL
        /// A record this client does not model — `Permission_id`, a `call_value` of TRX attached to
        /// the call, a TRC10 token bundled into it. Refusing beats signing a field nobody compared.
        case unexpectedField(number: UInt32)
        case ownerAddress
        case toAddress
        case contractAddress
        case amount
        case callData
        case feeLimit
    }

    /// Checks that `raw_data` describes `expected` and nothing else. Called where the node's answer
    /// is parsed, so every `Transaction` in the app is already verified by the time it is signed;
    /// `extendingExpiration` rewrites only the expiration varint and copies the contract byte for
    /// byte, so the result of a verified transaction stays verified.
    func verify(matches expected: ExpectedContract) throws(ContractMismatch) {
        let bytes: [UInt8]
        do {
            bytes = try rawDataBytes()
        } catch {
            throw .malformedRawData
        }

        let rawData = try ProtobufMessage(bytes: bytes)
        let contractCount = rawData.count(of: Transaction.contractFieldNumber)
        guard contractCount == 1 else {
            throw .contractCount(contractCount)
        }
        let contract = try rawData.message(Transaction.contractFieldNumber, allowing: [1, 2])

        let type: TronContractType
        switch expected {
        case .nativeTransfer:
            type = .transfer
        case .smartContractCall:
            type = .triggerSmartContract
        }
        guard try contract.varint(1) == type.rawValue else {
            throw .contractType
        }

        let parameter = try contract.message(2, allowing: [1, 2])
        guard let typeURL = try parameter.payload(1),
              String(decoding: typeURL, as: UTF8.self) == type.typeURL
        else {
            throw .typeURL
        }

        switch expected {
        case let .nativeTransfer(owner, to, amountSun):
            let transfer = try parameter.message(2, allowing: [1, 2, 3])
            guard try transfer.payload(1) == owner.raw else {
                throw .ownerAddress
            }
            guard try transfer.payload(2) == to.raw else {
                throw .toAddress
            }
            guard let amount = try transfer.varint(3), BigUInt(amount) == amountSun else {
                throw .amount
            }
            // `createtransaction` never sets one, and a native transfer burns no energy anyway.
            guard try rawData.varint(Transaction.feeLimitFieldNumber) ?? 0 == 0 else {
                throw .feeLimit
            }

        case let .smartContractCall(owner, contract, data, feeLimit):
            // `call_value` (3), `call_token_value` (5) and `token_id` (6) are absent in what the
            // node builds from a `transfer` call, so rejecting them outright keeps a node from
            // attaching TRX or a TRC10 token to the transfer the user confirmed.
            let call = try parameter.message(2, allowing: [1, 2, 4])
            guard try call.payload(1) == owner.raw else {
                throw .ownerAddress
            }
            guard try call.payload(2) == contract.raw else {
                throw .contractAddress
            }
            guard try call.payload(4) == data else {
                throw .callData
            }
            guard let expectedFeeLimit = UInt64(exactly: feeLimit),
                  try rawData.varint(Transaction.feeLimitFieldNumber) ?? 0 == expectedFeeLimit
            else {
                throw .feeLimit
            }
        }
    }
}

private extension Transaction {
    static let contractFieldNumber: UInt32 = 11
    static let feeLimitFieldNumber: UInt32 = 18
}

/// A protobuf message read field by field, strict where a lenient decoder would hide something:
/// a repeated record where one is expected, or a field number this client cannot compare.
private struct ProtobufMessage {
    private let bytes: [UInt8]
    private let fields: [ProtobufWire.Field]

    init(bytes: [UInt8]) throws(Transaction.ContractMismatch) {
        let fields: [ProtobufWire.Field]
        do {
            fields = try ProtobufWire.scanFields(bytes)
        } catch {
            throw .malformedRawData
        }
        self.bytes = bytes
        self.fields = fields
    }

    func count(of number: UInt32) -> Int {
        fields.reduce(into: 0) { count, field in
            count += field.number == number ? 1 : 0
        }
    }

    func varint(_ number: UInt32) throws(Transaction.ContractMismatch) -> UInt64? {
        guard let field = try field(number) else {
            return nil
        }
        guard let varint = field.varint else {
            throw .malformedRawData
        }
        return varint
    }

    func payload(_ number: UInt32) throws(Transaction.ContractMismatch) -> Data? {
        guard let field = try field(number) else {
            return nil
        }
        guard let payload = field.payload else {
            throw .malformedRawData
        }
        return Data(bytes[payload])
    }

    func message(
        _ number: UInt32,
        allowing allowed: Set<UInt32>
    ) throws(Transaction.ContractMismatch) -> ProtobufMessage {
        guard let payload = try payload(number) else {
            throw .malformedRawData
        }
        let message = try ProtobufMessage(bytes: Array(payload))
        if let unexpected = message.fields.first(where: { !allowed.contains($0.number) }) {
            throw .unexpectedField(number: unexpected.number)
        }
        return message
    }

    private func field(_ number: UInt32) throws(Transaction.ContractMismatch) -> ProtobufWire.Field? {
        var match: ProtobufWire.Field?
        for field in fields where field.number == number {
            guard match == nil else {
                // Last-wins in protobuf, but a node never emits a duplicate here, so picking one
                // would be guesswork about which half the signature ends up describing.
                throw .malformedRawData
            }
            match = field
        }
        return match
    }
}
