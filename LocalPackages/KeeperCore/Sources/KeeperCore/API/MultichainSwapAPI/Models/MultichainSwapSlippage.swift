
public struct MultichainSwapSlippage: Sendable, Hashable {
    public var chains: [String: MultichainSwapSlippageOptions]
    public var defaultPair: MultichainSwapDefaultPair?

    public init(
        chains: [String: MultichainSwapSlippageOptions],
        defaultPair: MultichainSwapDefaultPair? = nil
    ) {
        self.chains = chains
        self.defaultPair = defaultPair
    }
}
