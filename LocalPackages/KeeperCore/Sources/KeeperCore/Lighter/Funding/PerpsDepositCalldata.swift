import BigInt
import Foundation
import TronSwift

enum PerpsDepositCalldataError: Error, Equatable {
    case missingCall(payloadId: String)
    case malformedCall(payloadId: String)
    case notAnApproval(payloadId: String)
    case approvalTokenMismatch(payloadId: String, to: String)
    case approvalSpenderMismatch(payloadId: String, spender: String)
    case approvalAmountMismatch(payloadId: String, amount: String)
    case unsafeGatewayCall(payloadId: String)
    case notABatch(payloadId: String)
    /// A batch call that carries coin or calls back into the account.
    case unsafeBatch(payloadId: String)
    case unsafeKeyRegistration(payloadId: String)
}

/// The calls a quote asks this wallet to sign, read before it signs them. The envelope has
/// already been checked against the request; these bytes are what moves the money.
enum PerpsDepositCalldata {
    /// `approve(address,uint256)`.
    static let approveSelector = "095ea7b3"
    /// Lighter's Ethereum mainnet ZkLighter proxy, `deposit(address,uint16,uint8,uint256)`.
    static let gatewayAddress = "0x3b4d794a66304f130a4db8f2551b0070dfcf5ca7"
    static let depositSelector = "8a857083"
    /// ERC-7821 `execute(bytes32,bytes)`.
    static let executeSelector = "e9ae5c53"
    /// ERC-7821 plain batch: call type `0x01`, the first failure reverts the whole batch, no
    /// `opData` — the mode `HermesDelegateV1` runs only for a call the address makes to itself.
    static let plainBatchMode = "01" + String(repeating: "0", count: 62)
    /// `HermesDelegateV1` (tonkeeper/Hermes), at this one address on each of `hermesChains`.
    static let hermesDelegate = "0x24b576bc271823bf9c24be627b4363b9b00191e9"
    static let hermesChains: Set<MultichainChain> = [.eth, .bsc, .arb, .base, .polygon, .robinhood]

    struct ApprovedSpending: Equatable {
        let spender: String
        let amountUnits: BigUInt
    }

    static func readApproval(
        _ payload: PerpsDepositQuotePayload,
        token: String,
        spender: String,
        amountUnits: BigUInt,
        exactAmount: Bool = true
    ) throws(PerpsDepositCalldataError) -> ApprovedSpending {
        let call = try call(of: payload)
        guard call.selector == approveSelector, call.arguments.count == 2 else {
            throw .notAnApproval(payloadId: payload.payloadId)
        }
        guard normalizedAddress(payload.to) == normalizedAddress(token) else {
            throw .approvalTokenMismatch(payloadId: payload.payloadId, to: payload.to)
        }
        guard let approved = address(word: call.arguments[0]) else {
            throw .malformedCall(payloadId: payload.payloadId)
        }
        guard approved == normalizedAddress(spender) else {
            throw .approvalSpenderMismatch(payloadId: payload.payloadId, spender: approved)
        }
        guard let approvedAmount = BigUInt(call.arguments[1], radix: 16),
              approvedAmount > 0,
              exactAmount ? approvedAmount == amountUnits : approvedAmount <= amountUnits
        else {
            throw .approvalAmountMismatch(
                payloadId: payload.payloadId,
                amount: BigUInt(call.arguments[1], radix: 16)?.description ?? call.arguments[1]
            )
        }
        return ApprovedSpending(spender: approved, amountUnits: approvedAmount)
    }

    static func checkGatewayCall(
        _ payload: PerpsDepositQuotePayload,
        beneficiary: String,
        amountUnits: BigUInt
    ) throws(PerpsDepositCalldataError) {
        let call = try call(of: payload)
        guard payload.to.lowercased() == gatewayAddress,
              call.selector == depositSelector,
              call.arguments.count == 4,
              address(word: call.arguments[0]) == beneficiary.lowercased(),
              BigUInt(call.arguments[1], radix: 16) == 3,
              BigUInt(call.arguments[2], radix: 16) == 0,
              BigUInt(call.arguments[3], radix: 16) == amountUnits
        else {
            throw .unsafeGatewayCall(payloadId: payload.payloadId)
        }
    }

    /// The batch's last call when the deposit registers the key: `changePubKey` into the gateway
    /// with exactly the key asked for, which the account makes as its owner.
    static func checkKeyRegistrationCall(
        _ payload: PerpsDepositQuotePayload,
        registration: PerpsKeyRegistration
    ) throws(PerpsDepositCalldataError) {
        guard payload.to.lowercased() == gatewayAddress,
              payload.data?.lowercased() == registration.calldata
        else {
            throw .unsafeKeyRegistration(payloadId: payload.payloadId)
        }
    }

    /// The calls of a plain batch, each as a payload of its own, so the checks that read a
    /// separate approval and payment read them here too. A batch runs as the account and pays
    /// from its balance directly: a call carrying coin, or calling back into the account and so
    /// past these checks, is refused. So is any encoding but the canonical one, which the
    /// contract could read differently from this reader.
    static func readBatch(_ payload: PerpsDepositQuotePayload) throws(PerpsDepositCalldataError) -> [PerpsDepositQuotePayload] {
        let call = try call(of: payload)
        guard call.selector == executeSelector, call.arguments.first == plainBatchMode else {
            throw .notABatch(payloadId: payload.payloadId)
        }
        guard let calls = batchCalls(call.arguments), executeArguments(calls) == call.arguments else {
            throw .malformedCall(payloadId: payload.payloadId)
        }
        var read = [PerpsDepositQuotePayload]()
        for batched in calls {
            guard batched.value == 0, batched.to != payload.to.lowercased() else {
                throw .unsafeBatch(payloadId: payload.payloadId)
            }
            read.append(PerpsDepositQuotePayload(
                payloadId: payload.payloadId,
                kind: .main,
                chainId: payload.chainId,
                to: batched.to,
                valueUnits: batched.value.description,
                data: "0x" + batched.data,
                mode: nil,
                gasLimitUnits: nil,
                delegation: nil
            ))
        }
        return read
    }

    private struct BatchCall: Equatable {
        let to: String
        let value: BigUInt
        /// Lowercase hex, without `0x`.
        let data: String
    }

    /// Follows the offsets as an ABI decoder does, bounds-checked; `executeArguments` then
    /// says whether they were the canonical ones.
    private static func batchCalls(_ words: [String]) -> [BatchCall]? {
        func int(_ index: Int) -> Int? {
            guard words.indices.contains(index), let value = BigUInt(words[index], radix: 16),
                  value <= BigUInt(words.count * 32)
            else { return nil }
            return Int(value)
        }
        func wordIndex(_ offset: Int, from base: Int) -> Int? {
            offset % 32 == 0 ? base + offset / 32 : nil
        }
        // execute(mode, executionData) → abi.encode(Call[]): the array, its count, one offset
        // per call, and each call as (address, uint256, bytes).
        guard let bytesAt = int(1).flatMap({ wordIndex($0, from: 0) }),
              let arrayAt = int(bytesAt + 1).flatMap({ wordIndex($0, from: bytesAt + 1) }),
              let count = int(arrayAt)
        else { return nil }
        let heads = arrayAt + 1
        var calls = [BatchCall]()
        for index in 0 ..< count {
            guard let tupleAt = int(heads + index).flatMap({ wordIndex($0, from: heads) }),
                  words.indices.contains(tupleAt + 1),
                  let to = address(word: words[tupleAt]),
                  let value = BigUInt(words[tupleAt + 1], radix: 16),
                  let dataAt = int(tupleAt + 2).flatMap({ wordIndex($0, from: tupleAt) }),
                  let length = int(dataAt),
                  words.count >= dataAt + 1 + (length + 31) / 32
            else { return nil }
            let data = words[(dataAt + 1) ..< (dataAt + 1 + (length + 31) / 32)].joined()
            calls.append(BatchCall(to: to, value: value, data: String(data.prefix(length * 2))))
        }
        return calls
    }

    private static func executeArguments(_ calls: [BatchCall]) -> [String] {
        let tails: [[String]] = calls.map { call in
            let padding = String(repeating: "0", count: (64 - call.data.count % 64) % 64)
            let head = [
                String(repeating: "0", count: 24) + String(call.to.dropFirst(2)),
                word(call.value),
                word(0x60),
                word(BigUInt(call.data.count / 2)),
            ]
            return head + words(of: call.data + padding)
        }
        var offsets = [String]()
        var offset = calls.count * 32
        for tail in tails {
            offsets.append(word(BigUInt(offset)))
            offset += tail.count * 32
        }
        let executionData = [word(0x20), word(BigUInt(calls.count))] + offsets + tails.flatMap { $0 }
        return [plainBatchMode, word(0x40), word(BigUInt(executionData.count * 32))] + executionData
    }

    private static func word(_ value: BigUInt) -> String {
        let hex = String(value, radix: 16)
        return String(repeating: "0", count: max(0, 64 - hex.count)) + hex
    }

    private static func words(of hex: String) -> [String] {
        stride(from: 0, to: hex.count, by: 64).map { offset in
            let start = hex.index(hex.startIndex, offsetBy: offset)
            return String(hex[start ..< hex.index(start, offsetBy: 64)])
        }
    }

    private struct Call {
        let selector: String
        /// 32-byte words, lowercase hex, without the selector.
        let arguments: [String]
    }

    private static func call(of payload: PerpsDepositQuotePayload) throws(PerpsDepositCalldataError) -> Call {
        guard let data = payload.data?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(),
              data.hasPrefix("0x")
        else {
            throw .missingCall(payloadId: payload.payloadId)
        }
        let body = data.dropFirst(2)
        guard body.count >= 8, body.count % 2 == 0, body.allSatisfy(\.isHexDigit) else {
            throw .malformedCall(payloadId: payload.payloadId)
        }
        let arguments = String(body.dropFirst(8))
        guard arguments.count % 64 == 0 else {
            // Not every ABI encoding is a whole number of words, so this is not a refusal
            // of the call — only of reading arguments out of it.
            return Call(selector: String(body.prefix(8)), arguments: [])
        }
        return Call(
            selector: String(body.prefix(8)),
            arguments: stride(from: 0, to: arguments.count, by: 64).map { offset in
                let start = arguments.index(arguments.startIndex, offsetBy: offset)
                let end = arguments.index(start, offsetBy: 64)
                return String(arguments[start ..< end])
            }
        )
    }

    /// An address argument is right-aligned in its word; anything in the padding means the
    /// word is not an address, and truncating it would invent one.
    private static func address(word: String) -> String? {
        guard word.count == 64, word.prefix(24).allSatisfy({ $0 == "0" }) else { return nil }
        return "0x" + word.suffix(40)
    }

    private static func normalizedAddress(_ value: String) -> String {
        if let tron = try? TronSwift.Address(address: value) {
            return "0x" + tron.notPrefixed().map { String(format: "%02x", $0) }.joined()
        }
        return value.lowercased()
    }
}
