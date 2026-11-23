/// Which swaps the battery pays the fee of, as far as the asset sold tells before any route is quoted: a
/// route can still rule it out, such as by needing an approval first.
public struct MultichainSwapBatteryCoverage {
    let swapWallet: MultichainSwapWallet
    let isBatteryEnabled: Bool
    let isTRXOnlyRegion: Bool
    let relayedEVMChains: Set<MultichainChain>

    public func covers(_ sourceAsset: MultichainAsset) -> Bool {
        guard let chain = sourceAsset.asset.chain,
              MultichainSwapBatteryFeeRules.isBatteryAllowed(
                  wallet: swapWallet.wallet,
                  chain: chain,
                  isBatteryEnabled: isBatteryEnabled,
                  isBatterySendEnabled: isBatteryEnabled
              )
        else {
            return false
        }
        guard chain.isEVM || chain == .sol else {
            return MultichainSwapBatteryFeeRules.relayedAsset(
                swapWallet: swapWallet,
                sourceAsset: sourceAsset,
                requiresApproval: false,
                isTRXOnlyRegion: isTRXOnlyRegion
            ) != nil
        }
        return relayedEVMChains.contains(chain)
            && MultichainSwapBatteryFeeRules.relaysSwaps(of: swapWallet, on: chain)
    }
}
