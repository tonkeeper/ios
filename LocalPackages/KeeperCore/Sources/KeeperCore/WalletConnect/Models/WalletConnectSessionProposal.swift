import Foundation

public struct WalletConnectSessionProposal: Sendable, Equatable {
    public var id: String
    public var pairingTopic: String
    public var dapp: WalletConnectDapp
    public var namespaces: [WalletConnectProposalNamespace]
    public var validation: WalletConnectValidation
    public var source: DappConnectionSource

    public init(
        id: String,
        pairingTopic: String,
        dapp: WalletConnectDapp,
        namespaces: [WalletConnectProposalNamespace],
        validation: WalletConnectValidation,
        source: DappConnectionSource
    ) {
        self.id = id
        self.pairingTopic = pairingTopic
        self.dapp = dapp
        self.namespaces = namespaces
        self.validation = validation
        self.source = source
    }
}

public extension WalletConnectSessionProposal {
    func canBeApproved(wallet: Wallet) -> Bool {
        let requiredChains = Set(namespaces.filter(\.isRequired).flatMap(\.chains))
        guard requiredChains.allSatisfy({ wallet.walletConnectAddress(for: $0) != nil }) else {
            return false
        }
        return !approvableNamespaces(wallet: wallet).isEmpty
    }

    func approvableNamespaces(wallet: Wallet) -> [WalletConnectProposalNamespace] {
        namespaces.compactMap { namespace in
            let approvableChains = namespace.chains.filter {
                wallet.walletConnectAddress(for: $0) != nil
            }
            guard !approvableChains.isEmpty, !namespace.methods.isEmpty else {
                return nil
            }
            var approvableNamespace = namespace
            approvableNamespace.chains = approvableChains
            return approvableNamespace
        }
    }
}
