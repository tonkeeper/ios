import TKCore

enum DappCatalogMode {
    case ton
    case multichain
}

extension DappCatalogMode {
    var nilChainFallback: AssetChain {
        switch self {
        case .ton:
            return .ton
        case .multichain:
            return .multichain
        }
    }
}

extension DappCatalogMode: CustomStringConvertible {
    var description: String {
        switch self {
        case .ton:
            "ton"
        case .multichain:
            "multichain"
        }
    }
}
