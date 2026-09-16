import Foundation

public struct WalletConnectSession: Sendable, Equatable {
    public var topic: String
    public var dapp: WalletConnectDapp
    public var walletId: String?
    public var sourceState: DappConnectionSourceState
    public var chains: [WalletConnectChain]

    public var source: DappConnectionSource? {
        sourceState.extraInfo?.source
    }

    public init(
        topic: String,
        dapp: WalletConnectDapp,
        walletId: String?,
        source: DappConnectionSource,
        createdAt: Date,
        chains: [WalletConnectChain] = []
    ) {
        self.init(
            topic: topic,
            dapp: dapp,
            walletId: walletId,
            sourceState: .known(
                DappConnectionExtraInfo(
                    source: source,
                    createdAt: createdAt
                )
            ),
            chains: chains
        )
    }

    public init(
        topic: String,
        dapp: WalletConnectDapp,
        walletId: String?,
        sourceState: DappConnectionSourceState = .unknown,
        chains: [WalletConnectChain] = []
    ) {
        self.topic = topic
        self.dapp = dapp
        self.walletId = walletId
        self.sourceState = sourceState
        self.chains = chains
    }
}
