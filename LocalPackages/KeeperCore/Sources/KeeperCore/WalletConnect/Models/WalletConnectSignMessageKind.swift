import Foundation

@frozen public enum WalletConnectSignMessageKind: Sendable, Equatable {
    case personal
    case typedDataV4
    case tron
    case solana
}
