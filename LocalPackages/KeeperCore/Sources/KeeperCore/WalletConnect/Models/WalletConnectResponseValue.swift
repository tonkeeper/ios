@preconcurrency import AnyCodable
import Foundation

@frozen public enum WalletConnectResponseValue: Sendable, Equatable {
    case null
    case string(String)
    case object([String: String])
    case json(AnyCodable)
}
