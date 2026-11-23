@preconcurrency import BigInt
import ChainKit
import Foundation

/// Chain-specific data arrives in `payload`, so everything around the engines stays chain-agnostic.
struct MultichainSwapFeeContext {
    let swapWallet: MultichainSwapWallet
    let sourceAsset: MultichainAsset
    let payloadId: String
    let requiresApproval: Bool
    let payload: MultichainSwapBatteryPayload
    /// How much of `sourceAsset` the route takes out of the wallet, in its base units, so a fee
    /// in that asset is weighed next to it; nil when the route did not say.
    let spentSourceAmount: BigUInt?

    var wallet: Wallet {
        swapWallet.wallet
    }

    /// The account the swap spends from: the source asset at the address that signs on `chain`.
    func sourceAccount(on chain: MultichainChain) throws -> ChainKit.Account {
        guard let address = swapWallet.walletAddress(for: chain) else {
            throw ChainKitOperationError.unsupportedAccount(chain.rawValue)
        }
        return try ChainKitOperationSender.account(of: address, holding: sourceAsset.asset)
    }
}

/// What the relayer is owed for a swap, at the price the user confirmed.
enum MultichainSwapRelayedFee: Sendable, Hashable {
    case batteryCharges(Int)
    case gram(amountNano: BigUInt)
    case token(assetId: String, amount: BigUInt)
}

protocol MultichainSwapRelayedFeeEngine {
    /// Two engines can offer the same method on different chains, so the payload's chain decides which
    /// one answers for a swap.
    var chain: MultichainChain { get }

    /// The relayed methods that can pay for this swap, in the order they should be offered. Empty
    /// when none of them may be offered at all.
    func options(context: MultichainSwapFeeContext) async -> [MultichainSwapFeeOption]

    /// Prices the swap again and builds what will be signed, without any key. `confirmed` is the
    /// price the user agreed to, so the engine can refuse a fee the wallet can no longer cover.
    func prepare(
        context: MultichainSwapFeeContext,
        confirmed: MultichainSwapRelayedFee
    ) async throws(MultichainSwapExecutionFailure) -> MultichainSwapPreparedRelay
}

/// A relayed swap priced and built by its engine, not yet signed.
struct MultichainSwapPreparedRelay {
    /// What `send` will sign, as chain-kit reads it, for the review gate; built only when a check asks.
    let signables: (OperationIntent) async throws -> [SignableOperation]
    /// When what `send` signs stops being accepted; nil when nothing the engine relies on expires it.
    let expiresAt: Date?
    /// Signs what was prepared and relays it, returning its transaction hash — or nil when the
    /// relayer broadcasts on its own and names no transaction.
    let send: (MultichainTransferSigner) async throws(MultichainSwapExecutionFailure) -> String?

    /// Signing and relaying take a moment, and the deadline is checked when they arrive.
    func isExpired(at now: Date) -> Bool {
        expiresAt.map { $0.addingTimeInterval(-EVMGaslessEmulation.expiryLead) <= now } ?? false
    }
}

/// A relayed send with everything it needs, so no engine has to re-derive a price that may be
/// missing. Only a plan whose chosen method is priced and payable can produce one.
struct MultichainSwapRelayedSend {
    let payload: MultichainSwapBatteryPayload
    let confirmed: MultichainSwapRelayedFee
    let tokenFee: OperationIntent.Spend?
    /// The address the review holds what the swap pays to.
    let recipient: String?

    /// A Solana swap, and battery charges on an EVM chain and a TRON transfer, are asked about. A TON
    /// message, and elsewhere a fee in a token until the backend confirms the relayer's fee on its
    /// payload, are only logged.
    var presentation: OperationPresentation {
        if payload.chain == .sol {
            return .ask
        }
        if case .token = confirmed {
            return .logOnly
        }
        return payload.chain.isEVM || payload.chain == .tron ? .ask : .logOnly
    }
}

private extension MultichainSwapBatteryPayload {
    /// The address a route pays to, as its relayed payload names it: the contract the route's EVM call
    /// runs through, or the address its deposit pays, a token's deposit being a transfer on the token's
    /// contract. A TON route names none while it is only logged: a STON.fi one pays a wallet of its
    /// pool, such as pTON's, that the review cannot name yet.
    var routeRecipient: String? {
        switch self {
        case let .evm(relay):
            EvmCall.shared.decodeTransfer(callData_: relay.call.data)?.to ?? relay.call.to
        case let .tron(transfer):
            transfer.to
        case let .solana(relay):
            relay.call.transaction == nil ? relay.call.to : nil
        case .ton, .tonJettonDeposit, .evmBatch:
            nil
        }
    }
}

extension MultichainSwapExecutionPlan {
    func relayedSend(for method: MultichainSwapFeeMethod) -> MultichainSwapRelayedSend? {
        guard let batteryPayload,
              let option = feeOptions.first(where: { $0.method == method }),
              !option.isInsufficient,
              let confirmed = option.relayedFee
        else {
            return nil
        }
        let recipient: String? = switch signs {
        case .payloads:
            batteryPayload.routeRecipient
        // A route `/v3` prepared is held to what its operation names, relayed or not: the relayed
        // payload is only read out of it. One naming neither a deposit address nor a contract, as a
        // deposit made by a transfer, is held to what `/v2` names for the same relayed payload.
        case let .operation(swap):
            swap.recipient ?? batteryPayload.routeRecipient
        }
        return MultichainSwapRelayedSend(
            payload: batteryPayload,
            confirmed: confirmed,
            tokenFee: option.tokenFee,
            recipient: recipient
        )
    }
}
