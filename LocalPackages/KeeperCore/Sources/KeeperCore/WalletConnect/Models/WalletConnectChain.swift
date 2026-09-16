import Foundation

public enum WalletConnectChain: String, CaseIterable, Codable, Sendable, Equatable, Hashable {
    case ton
    case eth
    case base
    case arb
    case bsc
    case tron
}

public extension WalletConnectChain {
    init?(caip2: String) {
        let normalized = caip2
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        let match = WalletConnectChain.allCases
            .first { $0.caip2 == normalized }
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
        }
    }

    var eip155ChainId: Int32? {
        multichainChain.eip155ChainId.map(Int32.init)
    }

    var supportsEip1559Fees: Bool {
        switch self {
        case .eth, .base, .arb:
            return true
        case .bsc, .ton, .tron:
            return false
        }
    }
}
