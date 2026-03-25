import Foundation

public struct AccountEvent: Codable, Sendable {
    public typealias EventID = String

    public enum Extra: Codable, Sendable {
        case Fee(UInt64)
        case Refund(UInt64)
    }

    public let eventId: EventID
    public let date: Date
    public let account: WalletAccount
    public let isScam: Bool
    public let isInProgress: Bool
    public let extra: Extra
    public let excess: UInt64?
    public let progress: Double?
    public let actions: [AccountEventAction]

    public init(
        eventId: EventID,
        date: Date,
        account: WalletAccount,
        isScam: Bool,
        isInProgress: Bool,
        extra: Extra,
        excess: UInt64?,
        progress: Double?,
        actions: [AccountEventAction]
    ) {
        self.eventId = eventId
        self.date = date
        self.account = account
        self.isScam = isScam
        self.isInProgress = isInProgress
        self.extra = extra
        self.excess = excess
        self.progress = progress
        self.actions = actions
    }
}
