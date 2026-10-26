import KeeperCore

enum MultichainSwapAssetSource {
    /// The assets the multichain backend lists for a registered wallet.
    case walletAssets(MultichainWalletState, initialSelection: MultichainSwapInitialAssetSelection?)
    case legacyPair(sendAssetId: String, receiveAssetId: String)

    var isAssetSelectionLocked: Bool {
        switch self {
        case .walletAssets:
            false
        case .legacyPair:
            true
        }
    }
}
