import TonAPI

public extension StakingPoolImplementation {
    init(from: TonAPI.Components.Schemas.PoolImplementationType) {
        switch from {
        case .tf:
            self = .tf
        case .liquidTF:
            self = .liquidTF
        case .ffvault, .hipo:
            self = .unknown
        case .whales:
            self = .whales
        case .unknown:
            self = .unknown
        }
    }
}
