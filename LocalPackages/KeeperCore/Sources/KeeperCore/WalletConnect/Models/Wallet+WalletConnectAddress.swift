import Foundation

public extension Wallet {
    func walletConnectAddress(for chain: WalletConnectChain) -> String? {
        guard case let .multichain(state) = multichain else {
            return nil
        }
        return state.address(
            for: chain.multichainChain,
            preferredType: preferredMultichainAddressType(for: chain.multichainChain)
        )
    }
}
