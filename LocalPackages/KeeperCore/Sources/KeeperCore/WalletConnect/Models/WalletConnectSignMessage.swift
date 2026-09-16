import Foundation

public struct WalletConnectSignMessage: Sendable, Equatable {
    public var address: String?
    public var message: String
    public var kind: WalletConnectSignMessageKind

    public init(
        address: String?,
        message: String,
        kind: WalletConnectSignMessageKind
    ) {
        self.address = address
        self.message = message
        self.kind = kind
    }
}
