/// Chain-specific data arrives in `payload`, so everything around the engines stays chain-agnostic.
struct MultichainSwapFeeContext {
    let wallet: Wallet
    let sourceAsset: MultichainAsset
    let payloadId: String
    let requiresApproval: Bool
    let payload: MultichainSwapBatteryPayload
}

protocol MultichainSwapBatteryFeeEngine {
    /// Two engines can offer the same method on different chains, so the payload's chain decides which
    /// one answers for a swap.
    var chain: MultichainChain { get }

    /// `nil` when this method cannot pay for the swap and must not be offered.
    func option(context: MultichainSwapFeeContext) async -> MultichainSwapFeeOption?

    /// Signs and relays the swap, returning its transaction hash. `confirmedCharges` is the price the
    /// user agreed to, so the engine can refuse a fee the wallet can no longer cover.
    func send(
        context: MultichainSwapFeeContext,
        confirmedCharges: Int,
        passcodeProvider: @escaping () async -> String?
    ) async throws(MultichainSwapExecutionFailure) -> String
}

/// A battery send with everything it needs, so no engine has to re-derive a price that may be
/// missing. Only a plan whose battery option is priced and payable can produce one.
struct MultichainSwapBatterySend {
    let payload: MultichainSwapBatteryPayload
    let confirmedCharges: Int
}

extension MultichainSwapExecutionPlan {
    var batterySend: MultichainSwapBatterySend? {
        guard let batteryPayload,
              let option = feeOptions.first(where: { $0.method == .battery }),
              !option.isInsufficient,
              let confirmedCharges = option.batteryCharges
        else {
            return nil
        }
        return MultichainSwapBatterySend(
            payload: batteryPayload,
            confirmedCharges: confirmedCharges
        )
    }
}
