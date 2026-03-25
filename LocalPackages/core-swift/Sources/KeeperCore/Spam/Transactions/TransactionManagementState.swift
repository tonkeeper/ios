import Foundation

public extension TransactionsManagement {
    typealias txID = String

    enum TransactionState: Codable, Equatable {
        case normal
        case spam
    }

    struct TransactionsStates: Codable, Equatable {
        public let states: [txID: TransactionState]
    }
}
