import KeeperCore

extension Wallet {
    func multichainAddress(for chain: MultichainChain) -> String? {
        guard case let .multichain(state) = multichain else {
            return nil
        }
        return state.address(for: chain, preferredType: preferredMultichainAddressType(for: chain))
    }

    func legacyOnRampWalletAddress(isTronNetwork: Bool) -> String? {
        if isTronNetwork {
            return tron?.address.base58
        }
        return try? friendlyAddress.toString()
    }
}
