import BigInt
import ChainKit
import Foundation
import TKBatteryAPI
import TKPerpsAPI

/// A chain family with no relayable form of its main payload simply has no case here.
enum MultichainSwapBatteryPayload: Sendable, Hashable {
    case ton([TonSwapMessage])
    case tonJettonDeposit(TonJettonSwapDeposit)
    case tron(TronSwapTransfer)
    case evm(EVMSwapRelay)
    case evmBatch(EVMBatchRelay)
    /// A Solana route: its deposit transfer, or the transaction it built.
    case solana(EVMSwapRelay)
}

extension MultichainSwapBatteryPayload {
    var chain: MultichainChain {
        switch self {
        case .ton, .tonJettonDeposit:
            return .ton
        case .tron:
            return .tron
        case let .evm(relay):
            return relay.chain
        case let .evmBatch(relay):
            return relay.chain
        case .solana:
            return .sol
        }
    }

    var logValue: String {
        switch self {
        case let .ton(messages):
            return "ton messages=\(messages.count)"
        case .tonJettonDeposit:
            return "ton jetton deposit"
        case .tron:
            return "tron transfer"
        case let .evm(relay):
            return "evm call to=\(relay.call.to)"
        case let .evmBatch(relay):
            return "evm batch payload=\(relay.payload.id)"
        case let .solana(relay):
            return relay.call.transaction == nil ? "solana transfer to=\(relay.call.to)" : "solana transaction"
        }
    }
}

/// What the relayer is asked to carry for an EVM or Solana swap: the route's one call.
struct EVMSwapRelay: Sendable, Hashable {
    let chain: MultichainChain
    let call: EVMGaslessCall

    typealias Fee = HermesExecute.Fee

    /// Solana's relayer builds the whole transaction: emulation refuses one the sender pays the fee of,
    /// and the review holds it to the swap's intent.
    func refusal(of operation: MultichainRelayedOperation, fee: Fee, now: Date = Date()) -> String? {
        guard chain.isEVM else {
            return nil
        }
        return HermesExecute.refusal(of: operation, calls: [HermesExecute.Call(call)], chain: chain, owner: call.sender, fee: fee, now: now)
    }
}

/// A Hermes batch payload the relayer takes as the backend built it and runs through the address's
/// EIP-7702 delegate. Only battery charges pay for it: a fee in a token is one more call in the batch.
struct EVMBatchRelay: Sendable, Hashable {
    let chain: MultichainChain
    let sender: String
    let payload: TKBatteryAPI.Components.Schemas.GaslessV2Payload
    let calls: [HermesExecute.Call]

    func refusal(of operation: MultichainRelayedOperation, now: Date = Date()) -> String? {
        HermesExecute.refusal(of: operation, calls: calls, chain: chain, owner: sender, fee: .battery, now: now)
    }
}

struct HermesExecute {
    struct Refusal: Error {
        let reason: String
    }

    enum Fee: Equatable {
        case battery
        case token(contract: String, amount: BigUInt)
    }

    struct Call: Hashable, Sendable {
        let target: String
        let value: String
        let data: String

        init(target: String, value: String, data: String) {
            self.target = target.lowercased()
            self.value = BigUInt(value, radix: 10)?.description ?? value
            self.data = Self.hexDigits(data)
        }

        init(_ call: EVMGaslessCall) {
            self.init(target: call.to, value: call.value.description, data: call.data)
        }

        init(_ call: TKPerpsAPI.Components.Schemas.HermesExecuteCall) {
            self.init(target: call.target, value: call.value, data: call.data)
        }

        private static func hexDigits(_ data: String) -> String {
            let lowercased = data.lowercased()
            return lowercased.hasPrefix("0x") ? String(lowercased.dropFirst(2)) : lowercased
        }

        func isTransfer(on contract: String, atMost amount: BigUInt) -> Bool {
            let prefix = PerpsDepositCalldata.transferSelector
            guard target == contract.lowercased(), value == "0", data.hasPrefix(prefix) else {
                return false
            }
            let words = data.dropFirst(prefix.count)
            guard words.count == 128, words.allSatisfy(\.isHexDigit), words.prefix(24).allSatisfy({ $0 == "0" }),
                  let sent = BigUInt(String(words.suffix(64)), radix: 16)
            else {
                return false
            }
            return sent <= amount
        }
    }

    let payloadId: String
    let mode: String
    let calls: [Call]

    enum Execution: Equatable {
        case `default`
        case `try`
    }

    static func execution(ofRelayedMode mode: String) -> Execution? {
        let lowercased = mode.lowercased()
        let digits = lowercased.hasPrefix("0x") ? lowercased.dropFirst(2) : Substring(lowercased)
        guard digits.count == 64, digits.allSatisfy(\.isHexDigit),
              digits.prefix(2) == "01",
              digits.dropFirst(4).prefix(8).allSatisfy({ $0 == "0" }),
              digits.dropFirst(12).prefix(8) == "78210001"
        else { return nil }
        switch digits.dropFirst(2).prefix(2) {
        case "00" where digits.dropFirst(20).allSatisfy { $0 == "0" }:
            return .default
        case "01":
            return .try
        default:
            return nil
        }
    }

    static func refusal(
        of operation: MultichainRelayedOperation,
        calls requested: [Call],
        chain: MultichainChain,
        owner: String,
        fee: Fee,
        now: Date
    ) -> String? {
        let execute: HermesExecute
        switch read(operation, delegate: PerpsDepositCalldata.hermesDelegate, chain: chain, owner: owner, now: now) {
        case let .failure(refusal):
            return refusal.reason
        case let .success(read):
            execute = read
        }
        switch (fee, execution(ofRelayedMode: execute.mode)) {
        case (.battery, .default?):
            guard execute.calls == requested else {
                return "payload \(execute.payloadId) executes other calls"
            }
        case let (.token(contract, amount), .try?):
            guard execute.calls.count == requested.count + 1,
                  execute.calls[0].isTransfer(on: contract, atMost: amount),
                  Array(execute.calls.dropFirst()) == requested
            else {
                return "payload \(execute.payloadId) executes other calls"
            }
        default:
            return "payload \(execute.payloadId) runs in mode \(execute.mode)"
        }
        return nil
    }

    static func read(
        _ operation: MultichainRelayedOperation,
        delegate: String,
        chain: MultichainChain,
        owner: String,
        now: Date
    ) -> Result<HermesExecute, Refusal> {
        guard let chainId = chain.eip155ChainId.map(Int64.init) else {
            return .failure(Refusal(reason: "\(chain.rawValue) has no EIP-155 chain id"))
        }
        var executes = [HermesExecute]()
        var authorizations = 0
        for payload in operation.operation.payloads {
            guard payload.chain.caip2 == chain.asChainKitChain.caip2, payload.version == 1 else {
                return .failure(Refusal(reason: "payload \(payload.id) is for \(payload.chain.caip2) v\(payload.version)"))
            }
            switch payload.meta {
            case let authorization as PayloadMetaEvmAuthorization:
                authorizations += 1
                guard authorizations == 1,
                      authorization.address.display.lowercased() == delegate.lowercased(),
                      authorization.chainId == chainId,
                      (Int64(authorization.nonce.description) ?? -1) >= 0
                else {
                    return .failure(Refusal(
                        reason: "payload \(payload.id) delegates to \(authorization.address.display) on chain \(authorization.chainId)"
                    ))
                }
            case let execute as PayloadMetaEvmHermesDelegate:
                guard UniqueKeyJSON.isWellFormed(execute.typedData) else {
                    return .failure(Refusal(reason: "payload \(payload.id) repeats a key"))
                }
                guard let document = try? JSONDecoder().decode(
                    TKPerpsAPI.Components.Schemas.HermesExecuteTypedData.self,
                    from: Data(execute.typedData.utf8)
                ) else {
                    return .failure(Refusal(reason: "payload \(payload.id) is not an Execute document"))
                }
                if let fault = PerpsDepositQuoteReader.hermesEnvelopeFault(of: document, chainId: chainId, owner: owner, delegate: delegate, now: now) {
                    return .failure(Refusal(reason: "payload \(payload.id) has another \(fault.rawValue)"))
                }
                executes.append(HermesExecute(
                    payloadId: payload.id,
                    mode: document.message.mode.lowercased(),
                    calls: document.message.calls.map(Call.init)
                ))
            default:
                return .failure(Refusal(reason: "payload \(payload.id) is a \(payload.type.id)"))
            }
        }
        guard executes.count == 1, let execute = executes.first else {
            return .failure(Refusal(reason: "\(executes.count) Execute documents"))
        }
        return .success(execute)
    }
}
