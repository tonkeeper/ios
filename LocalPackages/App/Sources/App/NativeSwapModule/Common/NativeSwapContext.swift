import Foundation
@preconcurrency import KeeperCore

public struct NativeSwapContext: Sendable {
    public enum TokenData: Equatable, Sendable {
        case descriptor(address: String?, symbol: String?)
        case prefetched(KeeperCore.Token, category: TradingAssetCategory? = nil)
    }

    public var from: TokenData
    public var to: TokenData
    public var utm: UtmParameters
    public var transactionSentNotificationPatch: @Sendable (inout [String: Any]) -> Void

    public init(
        from: TokenData,
        to: TokenData,
        utm: UtmParameters = .empty,
        transactionSentNotificationPatch: @Sendable @escaping (inout [String: Any]) -> Void = { _ in }
    ) {
        self.from = from
        self.to = to
        self.utm = utm
        self.transactionSentNotificationPatch = transactionSentNotificationPatch
    }

    public init(
        fromTokenAddress: String? = nil,
        toTokenAddress: String? = nil,
        fromTokenSymbol: String? = nil,
        toTokenSymbol: String? = nil,
        utm: UtmParameters = .empty,
        transactionSentNotificationPatch: @Sendable @escaping (inout [String: Any]) -> Void = { _ in }
    ) {
        from = .descriptor(address: fromTokenAddress, symbol: fromTokenSymbol)
        to = .descriptor(address: toTokenAddress, symbol: toTokenSymbol)
        self.utm = utm
        self.transactionSentNotificationPatch = transactionSentNotificationPatch
    }
}
