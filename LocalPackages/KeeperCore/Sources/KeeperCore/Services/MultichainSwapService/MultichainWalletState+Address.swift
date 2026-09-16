import TKLogging

public extension MultichainWalletState {
    /// `walletId` is derived from the seed alone, so two local wallets that differ only in TON
    /// contract version share it; the account set is what tells them apart.
    var accountsIdentifier: String {
        ([walletId] + addresses.map(\.address).sorted()).joined(separator: "|")
    }

    func address(for chain: MultichainChain) -> String? {
        walletAddress(for: chain)?.address
    }

    func address(
        for chain: MultichainChain,
        preferredType: MultichainWalletAddressType?
    ) -> String? {
        walletAddress(for: chain, preferredType: preferredType)?.address
    }

    func walletAddress(
        for chain: MultichainChain,
        preferredType: MultichainWalletAddressType? = nil
    ) -> MultichainWalletAddress? {
        if let preferredType {
            if let address = addresses.first(where: { $0.chain == chain && $0.type == preferredType }) {
                return address
            }
            Log.w(
                "Multichain address resolution fell back to the first matching address",
                error: MultichainLoggingError.preferredAddressMissing(
                    chain: chain,
                    type: preferredType
                )
            )
        }
        return addresses.first { $0.chain == chain }
    }
}

public extension Wallet {
    func preferredMultichainAddressType(for chain: MultichainChain) -> MultichainWalletAddressType? {
        guard chain == .ton else {
            return nil
        }
        do {
            // Multichain TON state intentionally stores only v4R2 and v5R1 addresses.
            switch try contractVersion {
            case .v5R1:
                return .tonV5R1
            case .v3R1, .v3R2, .v4R1, .v4R2, .v5Beta:
                return .tonV4R2
            }
        } catch {
            Log.w(
                "Multichain: failed to read wallet contract version for address resolution",
                error: error,
                extraInfo: ["chain": "\(chain)"]
            )
            return .tonV4R2
        }
    }

    func multichainAddress(for chain: MultichainChain) -> String? {
        multichainWalletState?.address(
            for: chain,
            preferredType: preferredMultichainAddressType(for: chain)
        )
    }
}
