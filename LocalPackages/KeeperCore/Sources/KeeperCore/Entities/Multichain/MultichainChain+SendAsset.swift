import TronSwift

public extension MultichainChain {
    var defaultSendAssetId: String {
        switch self {
        case .tron:
            return "tron/mainnet/trc20/\(TronSwift.USDT.address.base58)"
        default:
            return "\(rawValue)/mainnet/coin"
        }
    }
}
