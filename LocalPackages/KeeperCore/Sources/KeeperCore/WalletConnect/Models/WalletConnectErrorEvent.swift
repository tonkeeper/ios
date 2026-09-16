import Foundation

public struct WalletConnectErrorEvent: Sendable, Equatable {
    public let topic: String?
    public let message: String

    public init(topic: String?, message: String) {
        self.topic = topic
        self.message = message
    }
}
