import KeeperCore

/// The battery offered once, on the empty swap screen, to a wallet whose battery holds no charges.
struct MultichainSwapBatteryPromo {
    /// Which send assets the battery would pay the swap of, or `nil` when there is nothing to offer: the
    /// promo was shown before, or the wallet's battery holds charges or could not be read.
    typealias Load = @MainActor () async -> ((MultichainAsset) -> Bool)?

    let load: Load
    let markShown: @MainActor () -> Void
}
