import Foundation

public struct WalletConnectProposalNamespace: Sendable, Equatable {
    public var key: String
    public var chains: [WalletConnectChain]
    public var methods: Set<WalletConnectMethod>
    public var events: Set<String>
    public var isRequired: Bool

    public init(
        key: String,
        chains: [WalletConnectChain],
        methods: Set<WalletConnectMethod>,
        events: Set<String>,
        isRequired: Bool
    ) {
        self.key = key
        self.chains = chains
        self.methods = methods
        self.events = events
        self.isRequired = isRequired
    }
}
