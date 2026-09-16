import ChainKit

/// Read-only result of preparing every payload in a route as one execution unit.
/// Fees are pinned for confirmation and execution, while approval availability is
/// derived from an actual ChainKit `buildApproval` result.
struct MultichainSwapPipelinePreparation {
    let fees: [MultichainTransactionEmulationResult]
    let payloadFees: MultichainSwapPayloadFees
    let requiresApproval: Bool
    /// The main payload in the shape a battery fee method could send instead of ChainKit; `nil`
    /// when the source chain has no relayable form.
    let batteryPayload: MultichainSwapBatteryPayload?
    /// Set when the wallet cannot cover the chain's own fee. The preparation still succeeds because a
    /// battery method may pay instead; without one the pipeline fails as it always did.
    let nativeFeeShortage: MultichainNativeFeeShortage?

    init(
        fees: [MultichainTransactionEmulationResult],
        payloadFees: MultichainSwapPayloadFees,
        requiresApproval: Bool,
        batteryPayload: MultichainSwapBatteryPayload? = nil,
        nativeFeeShortage: MultichainNativeFeeShortage? = nil
    ) {
        self.fees = fees
        self.payloadFees = payloadFees
        self.requiresApproval = requiresApproval
        self.batteryPayload = batteryPayload
        self.nativeFeeShortage = nativeFeeShortage
    }
}
