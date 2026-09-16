import Foundation

public struct WalletConnectSessionRequest: Sendable, Equatable {
    public var id: String
    public var topic: String
    public var chain: WalletConnectChain
    public var method: WalletConnectMethod
    public var dapp: WalletConnectDapp
    public var payload: WalletConnectRequestPayload
    public var source: DappConnectionSource?
    public var walletId: String?

    public init(
        id: String,
        topic: String,
        chain: WalletConnectChain,
        method: WalletConnectMethod,
        dapp: WalletConnectDapp,
        payload: WalletConnectRequestPayload,
        source: DappConnectionSource?,
        walletId: String?
    ) {
        self.id = id
        self.topic = topic
        self.chain = chain
        self.method = method
        self.dapp = dapp
        self.payload = payload
        self.source = source
        self.walletId = walletId
    }
}
