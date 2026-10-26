import Foundation

@frozen public enum WalletConnectChain: String, CaseIterable, Codable, Sendable, Equatable, Hashable {
    case ton
    case eth
    case base
    case arb
    case bsc
    case tron
    case polygon
    case avax
    case robinhood
    case sol
}

public extension WalletConnectChain {
    init?(caip2: String) {
        let normalized = caip2.trimmingCharacters(in: .whitespacesAndNewlines)
        let match = WalletConnectChain.allCases
            .first { $0.accepts(caip2: normalized) }
        guard let match else {
            return nil
        }
        self = match
    }
}

public extension WalletConnectChain {
    var caip2: String {
        switch self {
        case .ton:
            return "ton:-239"
        case .eth:
            return "eip155:1"
        case .base:
            return "eip155:8453"
        case .arb:
            return "eip155:42161"
        case .bsc:
            return "eip155:56"
        case .tron:
            return "tron:0x2b6653dc"
        case .polygon:
            return "eip155:137"
        case .avax:
            return "eip155:43114"
        case .robinhood:
            return "eip155:4663"
        case .sol:
            return "solana:5eykt4UsFv8P8NJdTREpY1vzqKqZKvdp"
        }
    }

    /// Every CAIP-2 identifier dApps use for the chain, the advertised one first.
    var caip2Identifiers: [String] {
        switch self {
        case .sol:
            return [caip2, "solana:4sGjMW1sUnHzSxGspuhpqLDx6wiyjNtZ"]
        case .ton, .eth, .base, .arb, .bsc, .tron, .polygon, .avax, .robinhood:
            return [caip2]
        }
    }

    var namespace: String {
        caip2.components(separatedBy: ":").first ?? caip2
    }

    var multichainChain: MultichainChain {
        switch self {
        case .ton:
            return .ton
        case .eth:
            return .eth
        case .base:
            return .base
        case .arb:
            return .arb
        case .bsc:
            return .bsc
        case .tron:
            return .tron
        case .polygon:
            return .polygon
        case .avax:
            return .avax
        case .robinhood:
            return .robinhood
        case .sol:
            return .sol
        }
    }

    var eip155ChainId: Int32? {
        multichainChain.eip155ChainId.map(Int32.init)
    }

    var supportsEip1559Fees: Bool {
        switch self {
        case .eth, .base, .arb, .polygon, .avax, .robinhood:
            return true
        case .bsc, .ton, .tron, .sol:
            return false
        }
    }
}

private extension WalletConnectChain {
    var hasCaseSensitiveCaip2Reference: Bool {
        switch self {
        case .sol:
            return true
        case .ton, .eth, .base, .arb, .bsc, .tron, .polygon, .avax, .robinhood:
            return false
        }
    }

    func accepts(caip2: String) -> Bool {
        caip2Identifiers.contains { identifier in
            if hasCaseSensitiveCaip2Reference {
                return identifier == caip2
            }
            return identifier.caseInsensitiveCompare(caip2) == .orderedSame
        }
    }
}
