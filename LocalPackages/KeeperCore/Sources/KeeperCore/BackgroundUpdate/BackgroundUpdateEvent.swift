import Foundation

public struct BackgroundUpdateEvent: @unchecked Sendable {
    public let wallet: Wallet
    public let lt: Int64
    public let txHash: String
}
