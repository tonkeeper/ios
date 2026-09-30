/// The relayed methods come first, in engine order, so a swap that can be relayed is preselected over
/// spending the chain's own coin.
struct MultichainSwapFeeMethodResolver {
    private let engines: [any MultichainSwapRelayedFeeEngine]

    init(engines: [any MultichainSwapRelayedFeeEngine]) {
        self.engines = engines
    }

    func options(
        context: MultichainSwapFeeContext?,
        nativeFees: [MultichainTransactionEmulationResult],
        isNativeInsufficient: Bool = false
    ) async -> [MultichainSwapFeeOption] {
        var options = [MultichainSwapFeeOption]()
        // The engine that prices the swap is the one that would send it, so the row the user picks and
        // the engine that honours it cannot come apart.
        if let context, let engine = engine(payload: context.payload) {
            options.append(contentsOf: await engine.options(context: context))
        }
        if !nativeFees.isEmpty {
            options.append(
                MultichainSwapFeeOption(cost: .native(nativeFees, isInsufficient: isNativeInsufficient))
            )
        }
        return options
    }

    func engine(
        payload: MultichainSwapBatteryPayload
    ) -> (any MultichainSwapRelayedFeeEngine)? {
        engines.first { $0.chain == payload.chain }
    }
}
