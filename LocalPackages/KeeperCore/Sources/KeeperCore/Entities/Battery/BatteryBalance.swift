import BigInt
import Foundation
import TonSwift

public struct BatteryBalance: Codable, Equatable {
    public var balanceDecimalNumber: NSDecimalNumber {
        NSDecimalNumber.number(stringValue: balance) ?? 0
    }

    public var reservedDecimalNumber: NSDecimalNumber {
        NSDecimalNumber.number(stringValue: reserved) ?? 0
    }

    public let balance: String
    public let reserved: String

    public var isZero: Bool {
        balanceDecimalNumber == NSDecimalNumber.zero && reservedDecimalNumber == NSDecimalNumber.zero
    }

    public var isBalanceZero: Bool {
        balanceDecimalNumber == NSDecimalNumber.zero
    }

    /// A store refund can take back more charges than the wallet had left, so the service balance
    /// goes below zero until the customer tops it up again.
    public var isBalanceNegative: Bool {
        balanceDecimalNumber.compare(NSDecimalNumber.zero) == .orderedAscending
    }

    public init(balance: String, reserved: String) {
        self.balance = balance
        self.reserved = reserved
    }

    public static var empty: BatteryBalance {
        BatteryBalance(balance: "0", reserved: "0")
    }
}
