/// The battery option comes first, in engine order, so a swap that can be relayed is preselected over
/// spending the chain's own coin.
struct MultichainSwapFeeMethodResolver {
    private let engines: [any MultichainSwapBatteryFeeEngine]

    init(engines: [any MultichainSwapBatteryFeeEngine]) {
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
        if let context,
           let engine = engine(payload: context.payload),
           let option = await engine.option(context: context)
        {
            options.append(option)
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
    ) -> (any MultichainSwapBatteryFeeEngine)? {
        engines.first { $0.chain == payload.chain }
    }
}
