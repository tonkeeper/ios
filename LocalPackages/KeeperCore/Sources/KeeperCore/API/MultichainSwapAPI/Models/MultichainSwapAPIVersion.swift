/// The `/crosschain` API a swap is quoted on, and so prepared and signed on.
@frozen public enum MultichainSwapAPIVersion: Sendable, Hashable {
    /// Each provider's own payloads, normalized by the app into the transactions it signs.
    case v2
    /// The Generic Payload operation the backend builds for the route, signed as it stands.
    case v3
}

public extension MultichainSwapWallet {
    /// `/v3` for a registered wallet that signs with its own mnemonic while `isV3Enabled`, unless it sells
    /// bitcoin: chain-kit signs a bitcoin payment without the memo a `/v3` deposit may carry.
    func swapAPIVersion(selling asset: MultichainAssetDetails, isV3Enabled: Bool) -> MultichainSwapAPIVersion {
        guard isV3Enabled,
              walletId != nil,
              keys == .hd,
              case .Regular = wallet.identity.kind,
              let chain = asset.chain,
              chain != .btc
        else {
            return .v2
        }
        return .v3
    }
}
