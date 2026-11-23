import Foundation

enum MultichainRealtimeSignal: Sendable {
    case publication(walletId: String, payload: Data)
    case subscribed(walletId: String, resubscribed: Bool)
    case unsubscribed(walletId: String)
    case perpsSubscribed(walletId: String, recovered: Bool)
    case perpsUnsubscribed(walletId: String)
}
