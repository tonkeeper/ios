import KeeperCore

/// How a scanned transfer should reach the send form: on the asset already selected, or after
/// switching to another one.
///
/// `allowsAutomaticChainSwitch` guards against overriding a manual token pick with a chain
/// *inferred* from an address that is valid on several of them. A link that names its chain and
/// token is not an inference but a later, explicit instruction, so it switches regardless.
enum MultichainScanApplication: Equatable {
    case switchAsset(assetId: String)
    case applyInPlace

    init(
        scannedAssetId: String?,
        selectedAssetId: String?,
        recipientChain: MultichainChain,
        selectedChain: MultichainChain?,
        allowsAutomaticChainSwitch: Bool
    ) {
        if let scannedAssetId {
            self = scannedAssetId == selectedAssetId
                ? .applyInPlace
                : .switchAsset(assetId: scannedAssetId)
            return
        }

        guard recipientChain != selectedChain, allowsAutomaticChainSwitch else {
            self = .applyInPlace
            return
        }
        self = .switchAsset(assetId: recipientChain.defaultSendAssetId)
    }
}
