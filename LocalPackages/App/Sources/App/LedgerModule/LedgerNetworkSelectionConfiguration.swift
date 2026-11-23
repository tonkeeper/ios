import KeeperCore

/// Default selections for the Ledger pairing picker.
struct LedgerNetworkSelectionConfiguration: Sendable {
    static let client = LedgerNetworkSelectionConfiguration(pairingDefaultChains: MultichainChain.displayOrder)

    private let pairingDefaultChains: Set<MultichainChain>

    init(pairingDefaultChains: [MultichainChain]) {
        self.pairingDefaultChains = Set(pairingDefaultChains)
    }

    func pairingSelection(among availableChains: [MultichainChain]) -> [MultichainChain] {
        MultichainChain.orderedByDisplayOrder(availableChains.filter { chain in
            pairingDefaultChains.contains(chain) || chain == .ton
        })
    }
}
