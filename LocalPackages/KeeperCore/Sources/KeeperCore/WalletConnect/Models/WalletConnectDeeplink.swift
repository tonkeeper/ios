import Foundation

public struct WalletConnectDeeplink: Equatable {
    public let uri: String
    public let source: DappConnectionSource

    public init(uri: String, source: DappConnectionSource) {
        self.uri = uri
        self.source = source
    }
}
