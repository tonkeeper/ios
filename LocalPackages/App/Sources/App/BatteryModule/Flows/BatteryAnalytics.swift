import Foundation
import KeeperCore
import TKCore

enum BatteryAnalyticsSource {
    case wallet
    case settings
    case tronFees
    case insufficientFunds
    case deeplink
    case send
    case batteryBanner

    var batteryOpenFrom: BatteryOpen.From {
        switch self {
        case .wallet: .wallet
        case .settings: .settings
        case .tronFees: .tronFees
        case .insufficientFunds: .insufficientFunds
        case .deeplink: .deeplink
        case .send: .send
        case .batteryBanner: .batteryBanner
        }
    }

    var batterySelectFrom: BatterySelect.From {
        switch self {
        case .wallet: .wallet
        case .settings: .settings
        case .tronFees: .tronFees
        case .insufficientFunds: .insufficientFunds
        case .deeplink: .deeplink
        case .send: .send
        case .batteryBanner: .batteryBanner
        }
    }

    var batterySuccessFrom: BatterySuccess.From {
        switch self {
        case .wallet: .wallet
        case .settings: .settings
        case .tronFees: .tronFees
        case .insufficientFunds: .insufficientFunds
        case .deeplink: .deeplink
        case .send: .send
        case .batteryBanner: .batteryBanner
        }
    }
}

struct BatteryAnalyticsPurchase: Equatable {
    enum PaymentType: Equatable {
        case crypto(jetton: String)
        case fiat
    }

    enum Size: String, Equatable {
        case small
        case medium
        case large
        case custom
    }

    let paymentType: PaymentType
    let size: Size
    let promocode: String?

    static func fiat(pack: BatteryIAPPack, promocode: String?) -> BatteryAnalyticsPurchase {
        let size: Size = switch pack {
        case .small: .small
        case .medium: .medium
        case .large: .large
        }
        return BatteryAnalyticsPurchase(paymentType: .fiat, size: size, promocode: promocode)
    }

    static func crypto(
        option: BatteryRechargeModel.OptionItem?,
        token: TonToken,
        promocode: String?
    ) -> BatteryAnalyticsPurchase {
        let size = option.flatMap { Size(rawValue: $0.identifier) } ?? .custom
        return BatteryAnalyticsPurchase(paymentType: .crypto(jetton: token.symbol), size: size, promocode: promocode)
    }
}

struct BatteryAnalytics {
    let source: BatteryAnalyticsSource
    let utm: UtmParameters
    let analyticsProvider: AnalyticsProvider

    func logOpen() {
        analyticsProvider.log(BatteryOpen(from: source.batteryOpenFrom), utm: utm)
    }

    func logSelect(_ purchase: BatteryAnalyticsPurchase) {
        analyticsProvider.log(Self.selectEvent(source: source, purchase: purchase), utm: utm)
    }

    func logSuccess(_ purchase: BatteryAnalyticsPurchase) {
        analyticsProvider.log(Self.successEvent(source: source, purchase: purchase), utm: utm)
    }

    static func selectEvent(source: BatteryAnalyticsSource, purchase: BatteryAnalyticsPurchase) -> BatterySelect {
        let type: BatterySelect.ModelType
        let jetton: String?
        switch purchase.paymentType {
        case let .crypto(symbol):
            type = .crypto
            jetton = symbol
        case .fiat:
            type = .fiat
            jetton = nil
        }
        let size: BatterySelect.Size = switch purchase.size {
        case .small: .small
        case .medium: .medium
        case .large: .large
        case .custom: .custom
        }
        return BatterySelect(
            from: source.batterySelectFrom,
            type: type,
            size: size,
            promo: purchase.promocode,
            jetton: jetton
        )
    }

    static func successEvent(source: BatteryAnalyticsSource, purchase: BatteryAnalyticsPurchase) -> BatterySuccess {
        let type: BatterySuccess.ModelType
        let jetton: String?
        switch purchase.paymentType {
        case let .crypto(symbol):
            type = .crypto
            jetton = symbol
        case .fiat:
            type = .fiat
            jetton = nil
        }
        let size: BatterySuccess.Size = switch purchase.size {
        case .small: .small
        case .medium: .medium
        case .large: .large
        case .custom: .custom
        }
        return BatterySuccess(
            from: source.batterySuccessFrom,
            type: type,
            size: size,
            promo: purchase.promocode,
            jetton: jetton
        )
    }
}
