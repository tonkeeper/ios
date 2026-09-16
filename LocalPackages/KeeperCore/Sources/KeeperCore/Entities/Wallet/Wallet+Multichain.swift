public extension Wallet {
    var isMultichain: Bool {
        multichainWalletState != nil
    }

    var multichainWalletState: MultichainWalletState? {
        guard case let .multichain(state) = multichain,
              !state.addresses.isEmpty
        else {
            return nil
        }
        return state
    }

    var multichainWalletId: String? {
        multichainWalletState?.walletId
    }

    var multichainEthereumAddress: String? {
        multichainWalletState?.addresses.first { $0.chain == .eth }?.address
    }
}
