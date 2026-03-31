import BigInt
import Foundation
import TonSwift
import TronSwift

public struct ProcessedBalance: Equatable, Codable {
    public let items: [ProcessedBalanceItem]
    public let tonItem: ProcessedBalanceTonItem
    public let tronUSDTItem: ProcessedBalanceTronUSDTItem?
    public let jettonItems: [ProcessedBalanceJettonItem]
    public let stakingItems: [ProcessedBalanceStakingItem]
    public let batteryBalance: BatteryBalance?
    public let ethenaItem: ProcessedBalanceEthenaItem

    public let currency: Currency
    public let date: Date

    public func getBalanceForJetton(_ jettonInfo: JettonInfo) -> ProcessedBalanceJettonItem? {
        if jettonInfo.address == JettonMasterAddress.USDe {
            return ethenaItem.usde
        }

        if jettonInfo.address == JettonMasterAddress.tsUSDe {
            return ethenaItem.stakedUsde
        }

        if let jettonItem = jettonItems.first(where: { $0.jetton.jettonInfo == jettonInfo }) {
            return jettonItem
        }

        if let stakingItem = stakingItems.first(where: { $0.jetton?.jetton.jettonInfo == jettonInfo }) {
            return stakingItem.jetton
        }

        return nil
    }
}

public enum ProcessedBalanceItem: Equatable, Codable {
    case ton(ProcessedBalanceTonItem)
    case jetton(ProcessedBalanceJettonItem)
    case staking(ProcessedBalanceStakingItem)
    case tronUSDT(ProcessedBalanceTronUSDTItem)
    case ethena(ProcessedBalanceEthenaItem)

    var shouldCalculateInTotal: Bool {
        switch self {
        case let .ton(item):
            return item.shouldCalculateInTotal
        case let .jetton(item):
            return item.shouldCalculateInTotal
        case let .staking(item):
            return item.shouldCalculateInTotal
        case let .tronUSDT(item):
            return item.shouldCalculateInTotal
        case let .ethena(item):
            let usdeFlag = item.usde?.shouldCalculateInTotal ?? false
            let stakedFlag = item.stakedUsde?.shouldCalculateInTotal ?? false
            return usdeFlag || stakedFlag
        }
    }

    var converted: Decimal {
        switch self {
        case let .ton(item):
            return item.converted
        case let .jetton(item):
            return item.converted
        case let .staking(item):
            return item.amountConverted
        case let .tronUSDT(item):
            return item.converted
        case let .ethena(item):
            return (item.usde?.converted ?? 0) + (item.stakedUsde?.converted ?? 0)
        }
    }

    public var identifier: String {
        switch self {
        case .ton:
            return TonInfo.symbol
        case let .jetton(jetton):
            return jetton.jetton.jettonInfo.address.toRaw()
        case let .staking(staking):
            return staking.info.pool.toRaw()
        case .tronUSDT:
            return USDT.address.base58
        case .ethena:
            return JettonMasterAddress.USDe.toRaw()
        }
    }

    public var isZeroBalance: Bool {
        switch self {
        case let .ton(ton):
            return ton.amount == 0
        case let .jetton(jetton):
            return jetton.amount.isZero
        case let .staking(staking):
            return staking.info.amount == 0
        case let .tronUSDT(item):
            return item.amount == 0
        case let .ethena(item):
            return ((item.usde?.amount ?? 0) + (item.stakedUsde?.amount ?? 0)) == 0
        }
    }
}

public struct ProcessedBalanceTonItem: Equatable, Codable {
    public let id: String
    public let title: String
    public let amount: UInt64
    public let fractionalDigits: Int
    public let currency: Currency
    public let converted: Decimal
    public let price: Decimal
    public let diff: String?
    public let shouldCalculateInTotal: Bool
}

public struct ProcessedBalanceJettonItem: Equatable, Codable {
    public let id: String
    public let jetton: JettonItem
    public let amount: BigUInt
    public let fractionalDigits: Int
    public let tag: String?
    public let currency: Currency
    public let converted: Decimal
    public let price: Decimal
    public let diff: String?
    public let shouldCalculateInTotal: Bool
}

public struct ProcessedBalanceTronUSDTItem: Equatable, Codable {
    public let id: String
    public let amount: BigUInt
    public let trxAmount: BigUInt
    public let fractionalDigits: Int
    public let tag: String?
    public let currency: Currency
    public let converted: Decimal
    public let price: Decimal
    public let diff: String?
    public let shouldCalculateInTotal: Bool
}

public struct ProcessedBalanceStakingItem: Equatable, Codable {
    public let id: String
    public let info: AccountStackingInfo
    public let poolInfo: StackingPoolInfo?
    public let jetton: ProcessedBalanceJettonItem?
    public let currency: Currency
    public let amountConverted: Decimal
    public let pendingDepositConverted: Decimal
    public let pendingWithdrawConverted: Decimal
    public let readyWithdrawConverted: Decimal
    public let price: Decimal
    public let shouldCalculateInTotal: Bool
}

public struct ProcessedBalanceEthenaItem: Equatable, Codable {
    public var usdeJettonItem: JettonItem {
        return usde?.jetton ?? .usde
    }

    public var stakedUSDeJettonItem: JettonItem {
        return stakedUsde?.jetton ?? .stakedUsde
    }

    public var id: String {
        USDe.address.toRaw()
    }

    public var title: String {
        USDe.symbol
    }

    public let usde: ProcessedBalanceJettonItem?
    public let stakedUsde: ProcessedBalanceJettonItem?
    public let amount: BigUInt
    public let stakedAmount: BigUInt
    public let fractionalDigits: Int
    public let tag: String?
    public let currency: Currency
    public let converted: Decimal
    public let stakedConverted: Decimal
    public let price: Decimal
    public let diff: String?
}
