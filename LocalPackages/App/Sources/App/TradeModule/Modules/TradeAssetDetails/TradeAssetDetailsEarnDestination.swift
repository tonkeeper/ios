import KeeperCore

enum TradeAssetDetailsEarnDestination: Equatable {
    case none
    case staking
    case vault(EarnAssetOffer)

    init(isStakingAsset: Bool, offer: EarnAssetOffer?) {
        if isStakingAsset {
            self = .staking
        } else if let offer {
            self = .vault(offer)
        } else {
            self = .none
        }
    }
}
