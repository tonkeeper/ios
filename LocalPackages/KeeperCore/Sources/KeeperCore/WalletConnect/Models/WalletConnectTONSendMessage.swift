import Foundation

public struct WalletConnectTONSendMessage: Sendable, Equatable {
    public var from: String?
    public var messagesCount: Int
    public var rawParamsJSON: String

    public init(
        from: String?,
        messagesCount: Int,
        rawParamsJSON: String
    ) {
        self.from = from
        self.messagesCount = messagesCount
        self.rawParamsJSON = rawParamsJSON
    }
}
