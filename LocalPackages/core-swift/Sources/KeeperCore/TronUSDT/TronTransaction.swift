@preconcurrency import BigInt
import Foundation
import TKBatteryAPI
import TronSwift
import TronSwiftAPI

public struct TronTransaction: Codable, Hashable, Equatable, Sendable {
    public enum TransactionType {
        case send
        case receive
    }

    public enum Error: Swift.Error {
        case invalidValue
    }

    enum CodingKeys: String, CodingKey {
        case txID = "txid"
        case timestamp
        case fromAccount = "from_account"
        case toAccount = "to_account"
        case amount
        case isPending = "is_pending"
        case isFailed = "is_failed"
        case batteryCharges = "battery_charges"
    }

    public let txID: String
    public let timestamp: Int64
    public let fromAccount: TronSwift.Address
    public let toAccount: TronSwift.Address
    public let amount: BigUInt
    public var isPending: Bool
    public let isFailed: Bool
    public let batteryCharges: Int?

    init(
        txID: String,
        timestamp: Int64,
        fromAccount: TronSwift.Address,
        toAccount: TronSwift.Address,
        amount: BigUInt,
        isPending: Bool,
        isFailed: Bool,
        batteryCharges: Int?
    ) {
        self.txID = txID
        self.timestamp = timestamp
        self.fromAccount = fromAccount
        self.toAccount = toAccount
        self.amount = amount
        self.isPending = isPending
        self.isFailed = isFailed
        self.batteryCharges = batteryCharges
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        txID = try container.decode(String.self, forKey: .txID)
        timestamp = try container.decode(Int64.self, forKey: .timestamp)

        let rawFromAccount = try container.decode(String.self, forKey: .fromAccount)
        fromAccount = try Address(address: rawFromAccount)

        let rawToAccount = try container.decode(String.self, forKey: .toAccount)
        toAccount = try Address(address: rawToAccount)

        isPending = try container.decode(Bool.self, forKey: .isPending)
        isFailed = try container.decode(Bool.self, forKey: .isFailed)
        batteryCharges = try container.decodeIfPresent(Int.self, forKey: .batteryCharges)

        if let amount = try? container.decode(BigUInt.self, forKey: .amount) {
            self.amount = amount
        } else {
            let rawAmount = try container.decode(String.self, forKey: .amount)
            guard let amount = BigUInt(rawAmount) else {
                throw Error.invalidValue
            }
            self.amount = amount
        }
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(txID, forKey: .txID)
        try container.encode(timestamp, forKey: .timestamp)
        try container.encode(fromAccount.base58, forKey: .fromAccount)
        try container.encode(toAccount.base58, forKey: .toAccount)
        try container.encode(isPending, forKey: .isPending)
        try container.encode(isFailed, forKey: .isFailed)
        try container.encodeIfPresent(batteryCharges, forKey: .batteryCharges)
        try container.encode(amount, forKey: .amount)
    }

    public func getTransactionType(address: TronSwift.Address) -> TransactionType {
        switch toAccount {
        case address:
            return .receive
        default:
            return .send
        }
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(txID)
    }

    public static func == (lhs: TronTransaction, rhs: TronTransaction) -> Bool {
        lhs.txID == rhs.txID
    }
}

extension TronTransaction {
    init(apiTransaction: Components.Schemas.TronTransactionsList.transactionsPayloadPayload) throws {
        self.txID = apiTransaction.txid
        self.timestamp = Int64(apiTransaction.timestamp)
        self.fromAccount = try TronSwift.Address(address: apiTransaction.from_account)
        self.toAccount = try TronSwift.Address(address: apiTransaction.to_account)
        self.amount = BigUInt(apiTransaction.amount) ?? 0
        self.isPending = apiTransaction.is_pending
        self.isFailed = apiTransaction.is_failed
        self.batteryCharges = apiTransaction.battery_charges
    }
}

extension TronTransaction {
    init(tronTransaction: TronSwiftAPI.EventTransaction) {
        self.txID = tronTransaction.transactionId
        self.timestamp = tronTransaction.timestamp / 1000
        self.fromAccount = tronTransaction.from
        self.toAccount = tronTransaction.to
        self.amount = tronTransaction.value
        self.isPending = false
        self.isFailed = false
        self.batteryCharges = nil
    }
}
