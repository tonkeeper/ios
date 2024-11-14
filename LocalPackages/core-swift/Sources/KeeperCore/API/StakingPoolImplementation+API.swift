import TonAPI
extension StakingPoolImplementation {
  public init(from: PoolImplementationType) {
    switch from {
    case .tf:
      self = .tf
    case .liquidtf:
      self = .liquidTF
    case .whales:
      self = .whales
    case .unknownDefaultOpenApi:
      self = .unknown
    }
  }
}
