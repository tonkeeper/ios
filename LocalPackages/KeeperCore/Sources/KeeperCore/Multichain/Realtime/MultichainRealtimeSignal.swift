import Foundation

enum MultichainRealtimeSignal: Sendable {
    case publication(walletId: String, payload: Data)
    case subscribed(walletId: String, resubscribed: Bool)
    case unsubscribed(walletId: String)
}
