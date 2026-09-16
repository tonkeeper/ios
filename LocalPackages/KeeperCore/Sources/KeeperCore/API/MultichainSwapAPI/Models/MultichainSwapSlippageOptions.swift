import SwapAPI

public struct MultichainSwapSlippageOptions: Sendable, Hashable {
    public var optionsBps: [Int]
    public var defaultBps: Int

    public init(optionsBps: [Int], defaultBps: Int) {
        self.optionsBps = optionsBps
        self.defaultBps = defaultBps
    }
}

extension MultichainSwapSlippageOptions {
    init(api: SwapAPI.Components.Schemas.CrossSwapSlippageOptions) {
        self.init(
            optionsBps: api.options_bps,
            defaultBps: api.default_bps
        )
    }
}
