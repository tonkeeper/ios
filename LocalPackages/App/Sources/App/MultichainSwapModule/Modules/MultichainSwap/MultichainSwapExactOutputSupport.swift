import KeeperCore

/// Whether the backend can quote a pair by the amount to receive (`exact_output`). Only swaps.xyz quotes
/// that way — within TON the backend also searches Omniston's quotes, and every asset Omniston serves is on
/// swaps.xyz's list — so both assets have to be on it.
struct MultichainSwapExactOutputSupport {
    let isEnabled: Bool

    func supports(sendAsset: MultichainAsset, receiveAsset: MultichainAsset) -> Bool {
        isEnabled && [sendAsset, receiveAsset].allSatisfy { $0.asset.swapAggregators?.contains(.swapsXyz) == true }
    }
}
