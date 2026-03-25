import Foundation
import TronSwift

public enum HistoryEvent: Codable {
    case tonAccountEvent(AccountEvent)
    case tronEvent(TronTransaction)

    public var timestamp: Int64 {
        switch self {
        case let .tonAccountEvent(event):
            return Int64(event.date.timeIntervalSince1970)
        case let .tronEvent(event):
            return Int64(event.timestamp)
        }
    }

    public var date: Date {
        switch self {
        case let .tonAccountEvent(event):
            return event.date
        case let .tronEvent(event):
            return Date(timeIntervalSince1970: TimeInterval(event.timestamp))
        }
    }

    public var eventId: String {
        switch self {
        case let .tonAccountEvent(event):
            return event.eventId
        case let .tronEvent(event):
            return event.txID
        }
    }

    public var identifier: String {
        switch self {
        case let .tonAccountEvent(event):
            return "ton\(event.eventId)"
        case let .tronEvent(event):
            return "tron\(event.txID)"
        }
    }

    public var isScam: Bool {
        switch self {
        case let .tonAccountEvent(event):
            return event.isScam
        case .tronEvent:
            return false
        }
    }

    public func isSent(wallet: Wallet) -> Bool {
        switch self {
        case let .tonAccountEvent(event):
            return event.actions.contains { action in
                switch action.type {
                case let .tonTransfer(tonTransfer):
                    return tonTransfer.sender == event.account
                case let .jettonTransfer(jettonTransfer):
                    return jettonTransfer.sender == event.account
                default:
                    return false
                }
            }
        case let .tronEvent(transaction):
            guard let tronAddress = wallet.tron?.address else { return false }
            return transaction.getTransactionType(address: tronAddress) == .send
        }
    }

    public func isReceived(wallet: Wallet) -> Bool {
        switch self {
        case let .tonAccountEvent(event):
            return event.actions.contains { action in
                switch action.type {
                case let .tonTransfer(tonTransfer):
                    return tonTransfer.recipient == event.account
                case let .jettonTransfer(jettonTransfer):
                    return jettonTransfer.recipient == event.account
                default:
                    return false
                }
            }
        case let .tronEvent(transaction):
            guard let tronAddress = wallet.tron?.address else { return false }
            return transaction.getTransactionType(address: tronAddress) == .receive
        }
    }
}
