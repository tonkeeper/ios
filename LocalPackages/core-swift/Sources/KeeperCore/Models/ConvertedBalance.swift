import BigInt
import Foundation
import TonSwift

public enum ConvertedBalanceState: Equatable {
    case current(ConvertedBalance)
    case previous(ConvertedBalance)

    public var balance: ConvertedBalance {
        switch self {
        case let .current(convertedBalance):
            return convertedBalance
        case let .previous(convertedBalance):
            return convertedBalance
        }
    }
}

public struct ConvertedBalance: Codable, Equatable {
    public let date: Date
    public let currency: Currency
    public let tonBalance: ConvertedTonBalance
    public let jettonsBalance: [ConvertedJettonBalance]
    public let stackingBalance: [ConvertedStakingBalance]
    public let tronUSDT: ConvertedBalanceTronUSDTItem?
    public let batteryBalance: BatteryBalance?
}

public struct ConvertedTonBalance: Codable, Equatable {
    public let tonBalance: TonBalance
    public let converted: Decimal
    public let price: Decimal
    public let diff: String?
}

public struct ConvertedJettonBalance: Codable, Equatable {
    public let jettonBalance: JettonBalance
    public let converted: Decimal
    public let price: Decimal
    public let diff: String?

    public init(
        jettonBalance: JettonBalance,
        converted: Decimal,
        price: Decimal,
        diff: String?
    ) {
        self.jettonBalance = jettonBalance
        self.converted = converted
        self.price = price
        self.diff = diff
    }
}

public struct ConvertedStakingBalance: Codable, Equatable {
    public let stackingInfo: AccountStackingInfo
    public let amountConverted: Decimal
    public let pendingDepositConverted: Decimal
    public let pendingWithdrawConverted: Decimal
    public let readyWithdrawConverted: Decimal
    public let price: Decimal
}

public struct ConvertedBalanceTronUSDTItem: Equatable, Codable {
    public let amount: BigUInt
    public let converted: Decimal
    public let price: Decimal
    public let diff: String?
}
