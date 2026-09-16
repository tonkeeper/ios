import KeeperCore

struct MultichainSendRecipientResolver {
    enum DeeplinkResolution: Equatable {
        case send(recipient: MultichainRecipient, availableChains: Set<MultichainChain>)
        case legacy
        case unsupported
    }

    func resolveDeeplink(
        candidates: MultichainRecipientCandidates,
        walletChains: [MultichainChain]?,
        network: Network
    ) -> DeeplinkResolution {
        guard let walletChains else {
            // A non-multichain wallet resolves the recipient through `RecipientResolver`, which
            // rejects a network mismatch itself and with a better error than `.unsupported`.
            let isLegacyAddress = candidates.chains.contains { $0 == .ton || $0 == .tron }
            return isLegacyAddress ? .legacy : .unsupported
        }

        guard let candidates = candidates.filteringNetworkMismatch(network) else {
            return .unsupported
        }

        let availableChains = candidates.chains.filter(walletChains.contains)
        guard let seedChain = seedChain(candidates: candidates, availableChains: availableChains) else {
            return .unsupported
        }
        return .send(
            recipient: MultichainRecipient(chain: seedChain, address: candidates.address),
            availableChains: Set(availableChains)
        )
    }

    func resolveScan(
        candidates: MultichainRecipientCandidates,
        selectedChain: MultichainChain?,
        walletChains: [MultichainChain],
        network: Network
    ) -> MultichainRecipient? {
        guard let candidates = candidates.filteringNetworkMismatch(network) else {
            return nil
        }
        if let selectedChain, candidates.chains.contains(selectedChain) {
            return MultichainRecipient(chain: selectedChain, address: candidates.address)
        }
        let availableChains = candidates.chains.filter(walletChains.contains)
        guard let seedChain = seedChain(candidates: candidates, availableChains: availableChains) else {
            return nil
        }
        return MultichainRecipient(chain: seedChain, address: candidates.address)
    }

    private func seedChain(
        candidates: MultichainRecipientCandidates,
        availableChains: [MultichainChain]
    ) -> MultichainChain? {
        if let primary = candidates.chains.first, availableChains.contains(primary) {
            return primary
        }
        return availableChains.first(where: \.isLayer1) ?? availableChains.first
    }
}
