import ChainKit

@frozen public enum MultichainChain: String, Sendable, Hashable, Codable, CaseIterable {
    case ton
    case eth
    case base
    case btc
    case tron
    case arb
    case bsc
    case sol
    case polygon
    case avax
    case robinhood
}

public extension MultichainChain {
    static let displayOrder: [MultichainChain] = [
        .ton,
        .eth,
        .bsc,
        .sol,
        .tron,
        .arb,
        .robinhood,
        .btc,
        .polygon,
        .base,
        .avax,
    ]

    static func orderedByDisplayOrder(_ chains: [MultichainChain]) -> [MultichainChain] {
        displayOrder.filter(chains.contains)
            + chains.filter { !displayOrder.contains($0) }
    }

    var displayOrderIndex: Int {
        Self.displayOrder.firstIndex(of: self) ?? Self.displayOrder.count
    }

    init?(assetId: String) {
        guard let components = AssetIdComponents(assetId: assetId) else {
            return nil
        }
        self.init(assetIdChain: components.chain)
    }

    init?(assetIdChain: String) {
        let chain = assetIdChain
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()

        switch chain {
        case "trx":
            self = .tron
        case "bnb":
            self = .bsc
        default:
            self.init(rawValue: chain)
        }
    }
}
