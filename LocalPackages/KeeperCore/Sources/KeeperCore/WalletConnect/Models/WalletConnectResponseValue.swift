@preconcurrency import AnyCodable
import Foundation

public enum WalletConnectResponseValue: Sendable, Equatable {
    case null
    case string(String)
    case object([String: String])
    case json(AnyCodable)
}
