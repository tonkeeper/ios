@preconcurrency import BigInt

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

    /// Signs and relays the swap, returning its transaction hash — or nil when the relayer
    /// broadcasts on its own and names no transaction. `confirmed` is the price the user agreed
    /// to, so the engine can refuse a fee the wallet can no longer cover.
    func send(
        context: MultichainSwapFeeContext,
        confirmed: MultichainSwapRelayedFee,
        passcodeProvider: @escaping () async -> String?
    ) async throws(MultichainSwapExecutionFailure) -> String?
}

/// A relayed send with everything it needs, so no engine has to re-derive a price that may be
/// missing. Only a plan whose chosen method is priced and payable can produce one.
struct MultichainSwapRelayedSend {
    let payload: MultichainSwapBatteryPayload
    let confirmed: MultichainSwapRelayedFee
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
        return MultichainSwapRelayedSend(
            payload: batteryPayload,
            confirmed: confirmed
        )
    }
}
