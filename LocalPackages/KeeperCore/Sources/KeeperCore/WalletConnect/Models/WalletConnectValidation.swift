import Foundation

@frozen public enum WalletConnectValidation: String, Sendable, Equatable {
    case valid
    case invalid
    case scam
    case unknown
}
