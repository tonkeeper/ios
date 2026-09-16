import SwapAPI

public struct MultichainSwapConfig: Sendable, Hashable {
    public var defaultPair: MultichainSwapDefaultPair
    public var slippage: MultichainSwapSlippage

    public init(
        defaultPair: MultichainSwapDefaultPair,
        slippage: MultichainSwapSlippage
    ) {
        self.defaultPair = defaultPair
        self.slippage = slippage
    }
}

extension MultichainSwapConfig {
    init(api: SwapAPI.Components.Schemas.CrossSwapConfig) {
        self.init(
            defaultPair: MultichainSwapDefaultPair(api: api.swap_pair),
            slippage: MultichainSwapSlippage(
                chains: api.slippages.additionalProperties.mapValues {
                    MultichainSwapSlippageOptions(api: $0)
                }
            )
        )
    }
}
