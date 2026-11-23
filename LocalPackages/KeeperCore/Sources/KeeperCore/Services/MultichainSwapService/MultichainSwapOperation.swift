@preconcurrency import BigInt
@preconcurrency import ChainKit
import Foundation
import KeeperCoreComponents
import TKLogging
import TonSwift
import TronSwift

/// A route `/v3` prepared, as its plan signs it: the backend's operation, priced payload by payload.
struct MultichainSwapOperation: Sendable {
    /// Approvals first, the swap last.
    let operation: ChainKit.Operation
    /// The account of the asset sold, the one the review reads.
    let account: ChainKit.Account
    /// The account chain-kit signs from: a Solana token's own, which its transfer moves, and the
    /// chain's coin elsewhere.
    let signingAccount: ChainKit.Account
    /// One per payload, in its order: what each is signed at.
    let fees: [any Fee]
    /// Where the swap pays: the deposit address the route names, else the contract its last payload
    /// calls. The review of a relayed send holds what the relayer built to it.
    let recipient: String?
    /// Nothing of the operation is signed or sent past this.
    let expiresAt: Date
    /// The quoted route as the operation receives.
    let route: MultichainSwapRoute

    /// How long before the backend's deadline the operation stops being sent: signing and
    /// broadcasting take a moment.
    static let expiryLead: TimeInterval = 2
}

extension ChainKit.Operation {
    /// The contract a swap runs through: its last payload's destination when that calls one, in a TON
    /// batch that of the first message that does. A transfer names its recipient itself and calls none:
    /// a plain one, a token's `transfer` on its contract, ERC-20 and TRC-20 alike, and a jetton's,
    /// which the account's own wallet of the jetton makes.
    var calledContract: String? {
        switch payloads.last?.meta {
        case let meta as PayloadMetaEvmMain:
            meta.data.isBlank || meta.data?.hasTokenTransferSelector == true ? nil : meta.to.display
        case let meta as PayloadMetaTonMain:
            meta.calledContract
        case let meta as PayloadMetaTonBatch:
            meta.calls.lazy.compactMap { ($0 as? PayloadMetaTonMain)?.calledContract }.first
        case let meta as PayloadMetaTronMain:
            meta.data.isBlank || meta.data?.hasTokenTransferSelector == true ? nil : meta.to.display
        default:
            nil
        }
    }

    /// The chain's coin the payloads send out of the account, beside any token they move.
    var coinValue: BignumBigInteger {
        payloads.reduce(BignumBigInteger.Companion.shared.ZERO) { $0.add(other: $1.meta.coinValue) }
    }
}

extension MultichainSwapBatteryPayload {
    /// `operation`, a route `/v3` prepared, in the shape a relayed fee method carries the main payload
    /// of a `/v2` route in, so a route is offered the same methods whichever API prepared it: its one
    /// payload as it states itself, sold from `sender`. Nil where `/v2` relays nothing — a swap behind
    /// its approve — and where the payload states more than a relayer would send.
    init?(relaying operation: ChainKit.Operation, selling sourceAsset: MultichainAsset, from sender: String) {
        guard operation.payloads.count == 1, let meta = operation.payloads.first?.meta, let chain = sourceAsset.asset.chain else {
            return nil
        }
        switch meta {
        case let main as PayloadMetaEvmMain where chain.isEVM:
            guard let call = main.relayedCall(on: chain, from: sender) else {
                return nil
            }
            self = .evm(EVMSwapRelay(chain: chain, call: call))
        case let main as PayloadMetaTonMain where chain == .ton && main.token != nil:
            guard let deposit = main.relayedDeposit(of: sourceAsset) else {
                return nil
            }
            self = .tonJettonDeposit(deposit)
        case let main as PayloadMetaTonMain where chain == .ton:
            guard let message = main.relayedMessage else {
                return nil
            }
            self = .ton([message])
        case let batch as PayloadMetaTonBatch where chain == .ton:
            let messages = batch.calls.compactMap { ($0 as? PayloadMetaTonMain)?.relayedMessage }
            guard messages.count == batch.calls.count else {
                return nil
            }
            self = .ton(messages)
        case let main as PayloadMetaTronMain where chain == .tron:
            guard let transfer = main.relayedTransfer(of: sourceAsset.asset) else {
                return nil
            }
            self = .tron(transfer)
        case let main as PayloadMetaSolanaMain where chain == .sol:
            guard let call = main.relayedDeposit(of: sourceAsset.asset, from: sender) else {
                return nil
            }
            self = .solana(EVMSwapRelay(chain: .sol, call: call))
        case let prebuild as PayloadMetaSolanaPrebuild where chain == .sol:
            self = .solana(EVMSwapRelay(chain: .sol, call: .solanaSwap(sender: sender, transaction: prebuild.data)))
        default:
            return nil
        }
    }
}

private extension PayloadMetaSolanaMain {
    /// The deposit as the relayer asks for a Solana transfer: the sold asset's amount to the route's
    /// address, its memo kept. One that moves another asset than the one sold is not the route's deposit.
    func relayedDeposit(of sourceAsset: MultichainAssetDetails, from sender: String) -> EVMGaslessCall? {
        guard let amount = BigUInt(value.description),
              let call = EVMGaslessCall.transfer(
                  chain: .sol,
                  sender: sender,
                  assetId: sourceAsset.assetId,
                  recipient: to.display,
                  amount: amount,
                  memo: memo
              ),
              call.token == token?.display
        else {
            return nil
        }
        return EVMGaslessCall(
            kind: .swap,
            chainId: call.chainId,
            sender: call.sender,
            to: call.to,
            value: call.value,
            data: call.data,
            token: call.token,
            memo: call.memo
        )
    }
}

private extension PayloadMetaEvmMain {
    /// The call as it stands, under the swap's kind: `value` of the coin to `to` with its calldata. One
    /// that authorizes a delegate of its own is more than the call.
    func relayedCall(on chain: MultichainChain, from sender: String) -> EVMGaslessCall? {
        guard authorization == nil, EVMGaslessCall.isAddress(to.display), let amount = BigUInt(value.description) else {
            return nil
        }
        return EVMGaslessCall(
            kind: .swap,
            chainId: chain.relayerChainId,
            sender: sender,
            to: to.display,
            value: amount,
            data: data ?? EVMGaslessCall.emptyData
        )
    }
}

private extension PayloadMetaTonMain {
    /// The message's destination, which a body other than a jetton's transfer calls; one that does not
    /// parse is read as a call.
    var calledContract: String? {
        body.isBlank || isJettonTransfer ? nil : to.display
    }

    var isJettonTransfer: Bool {
        guard let body, let op = try? Cell.fromBase64(src: body.fixBase64()).beginParse().loadUint(bits: 32) else {
            return false
        }
        return op == OpCodes.JETTON_TRANSFER
    }

    /// The message as `/v2` relays one: recipient, value and body.
    var relayedMessage: TonSwapMessage? {
        guard token == nil, isRebuiltWhole, let amount = BigUInt(value.description) else {
            return nil
        }
        return TonSwapMessage(to: to.display, amount: amount, payload: body, stateInit: nil)
    }

    /// A deposit of the jetton sold as `/v2` relays one: `value` of it to `to`, in the transfer the
    /// account's own wallet of the jetton makes.
    func relayedDeposit(of sourceAsset: MultichainAsset) -> TonJettonSwapDeposit? {
        guard let token, body == nil, isRebuiltWhole,
              let sold = TonJettonSwapTransferFactory.jettonMasterAddress(sourceAsset: sourceAsset),
              let amount = BigUInt(value.description)
        else {
            return nil
        }
        do {
            guard try TonSwift.Address.parse(token.display) == sold else {
                return nil
            }
        } catch {
            Log.multichainSwap.w("relayed jetton deposit not offered: unreadable jetton", error: error, extraInfo: ["jetton": token.display])
            return nil
        }
        return TonJettonSwapDeposit(recipient: to.display, amount: amount)
    }

    /// A relayer rebuilds a message from its recipient, value and body alone, so one that states more —
    /// a state init, a mode, a bounce flag, an expiry, a comment chain-kit would forward — is sent as
    /// it stands, in the coin.
    var isRebuiltWhole: Bool {
        stateInit == nil && mode == nil && bounce == nil && expireAt == nil && (comment ?? "").isEmpty
    }
}

private extension PayloadMetaTronMain {
    /// The transfer as `/v2` relays one. For the chain's coin, TRX paid to `to`. For a token, the
    /// `transfer(address,uint256)` its own contract is called with and no TRX, read back only where it
    /// encodes again into the very calldata, so the transfer relayed is the one the operation states.
    func relayedTransfer(of asset: MultichainAssetDetails) -> TronSwapTransfer? {
        guard memo == nil, let amount = BigUInt(value.description) else {
            return nil
        }
        switch AssetIdComponents(assetId: asset.assetId) {
        case .coin:
            return data == nil ? TronSwapTransfer(to: to.display, amount: amount) : nil
        case let .asset(_, _, _, contract):
            guard amount == 0, to.display == contract, let data else {
                return nil
            }
            let calldata = "0x" + data.hexBody
            guard let transfer = EvmCall.shared.decodeTransfer(callData_: calldata),
                  let tokens = BigUInt(transfer.amount.description),
                  EVMGaslessCall.erc20TransferData(recipient: transfer.to, amount: tokens) == calldata,
                  let recipient = Data(strictHex: transfer.to)
            else {
                return nil
            }
            do {
                return try TronSwapTransfer(to: TronSwift.Address(raw: Data([0x41]) + recipient).base58, amount: tokens)
            } catch {
                Log.multichainSwap.w("relayed tron deposit not offered: unreadable recipient", error: error, extraInfo: ["recipient": transfer.to])
                return nil
            }
        case nil:
            return nil
        }
    }
}

private extension PayloadMeta {
    /// What chain-kit 26.11.4 attaches to the jetton transfer it signs for a TON jetton deposit:
    /// `RECOMMENDED_JETTON_TON_AMOUNT + JETTON_FORWARD_TON_AMOUNT` of `TonTransactionalSignDelegate`,
    /// which its Swift header does not export. Sent with errors of the action phase ignored, a
    /// transfer the balance cannot cover is dropped and its fee charged all the same.
    static var jettonTransferCoin: BignumBigInteger {
        BignumBigInteger(long: 80_000_001)
    }

    var coinValue: BignumBigInteger {
        switch self {
        case let meta as PayloadMetaTonMain:
            // A jetton's value is the jetton's: the coin is what chain-kit attaches to its transfer.
            meta.token == nil ? meta.value : Self.jettonTransferCoin
        case let meta as PayloadMetaTonBatch:
            meta.calls.reduce(BignumBigInteger.Companion.shared.ZERO) { $0.add(other: $1.coinValue) }
        case let meta as PayloadMetaEvmMain:
            meta.value
        case let meta as PayloadMetaTronMain:
            meta.value
        case let meta as PayloadMetaSolanaMain:
            meta.token == nil ? meta.value : BignumBigInteger.Companion.shared.ZERO
        default:
            BignumBigInteger.Companion.shared.ZERO
        }
    }
}

private extension String {
    /// Hex digits as calldata is compared: lowercased, without the `0x` prefix.
    var hexBody: String {
        (hasPrefix("0x") ? String(dropFirst(2)) : self).lowercased()
    }

    /// `transfer(address,uint256)`, the call ERC-20 and TRC-20 tokens move by.
    var hasTokenTransferSelector: Bool {
        hexBody.hasPrefix("a9059cbb")
    }
}

private extension String? {
    var isBlank: Bool {
        self?.allSatisfy(\.isWhitespace) ?? true
    }
}
