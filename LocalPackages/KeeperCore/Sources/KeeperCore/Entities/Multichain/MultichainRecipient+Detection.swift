import ChainKit
import Foundation

public extension MultichainRecipientCandidates {
    init?(string: String) {
        let address = string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !address.isEmpty else {
            return nil
        }
        let chains = Address.Companion.shared
            .findChainsByAddress(address: address)
            .map(\.network.type)
            .compactMap(MultichainChain.init(chainKitNetwork:))
        guard !chains.isEmpty else {
            return nil
        }
        self.init(address: address, chains: chains)
    }

    /// TON is the only chain here whose address encodes the network it belongs to, and ChainKit
    /// reads the format without the test-only tag, so a testnet address stays a valid TON candidate
    /// for a mainnet wallet. Dropping `.ton` leaves the other chains the address is valid on intact.
    func filteringNetworkMismatch(_ network: Network) -> MultichainRecipientCandidates? {
        guard chains.contains(.ton), !network.matchesTonAddress(address) else {
            return self
        }
        let remaining = chains.filter { $0 != .ton }
        return remaining.isEmpty ? nil : MultichainRecipientCandidates(address: address, chains: remaining)
    }
}

public extension MultichainRecipient {
    init?(string: String, chain: MultichainChain, network: Network) {
        guard let candidates = MultichainRecipientCandidates(string: string)?
            .filteringNetworkMismatch(network),
            candidates.chains.contains(chain)
        else {
            return nil
        }
        self.init(chain: chain, address: candidates.address)
    }
}
