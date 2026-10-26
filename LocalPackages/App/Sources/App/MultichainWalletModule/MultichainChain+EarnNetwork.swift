import KeeperCore

extension MultichainChain {
    init?(earnNetwork: String) {
        switch earnNetwork.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "mainnet":
            self = .eth
        case "base":
            self = .base
        case "arbitrum":
            self = .arb
        case "bsc":
            self = .bsc
        default:
            return nil
        }
    }
}
