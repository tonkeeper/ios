// BigInt 5.3.0 has copy-on-write values but no Sendable annotations; remove this after updating it.
@preconcurrency import BigInt
import Foundation
import TKBatteryAPI

public struct BatteryAssetRechargeMethod: Codable, Hashable, Sendable {
    public let chainId: String
    public let assetId: String
    public let symbol: String
    public let decimals: Int
    public let imageURL: URL?
    public let minimum: String?
    public let rate: String
    public let chargesRate: String?

    public var chain: MultichainChain? {
        MultichainChain(assetId: assetId)
    }

    init?(_ method: Components.Schemas.RechargeMethods.methodsPayloadPayload) {
        guard method.support_recharge, (0 ... 38).contains(method.decimals),
              let chain = MultichainChain(assetId: method.asset_id), chain != .ton, chain != .btc,
              method.chain == method.asset_id.split(separator: "/").prefix(2).joined(separator: "/")
        else { return nil }
        switch method._type {
        case .erc20 where chain.isEVM: break
        case .spl where chain == .sol: break
        case .trc20 where chain == .tron: break
        case .coin: break
        default: return nil
        }
        if let minimum = method.min_bootstrap_value {
            guard BatteryRechargeMath.decimal(minimum) != nil else { return nil }
        }
        chainId = method.chain
        assetId = method.asset_id
        symbol = method.symbol
        decimals = method.decimals
        imageURL = method.image.flatMap(URL.init(string:))
        minimum = method.min_bootstrap_value
        rate = method.rate
        chargesRate = method.charges_rate
    }

    public func chargesPerUnit(chargeCost: String) -> Decimal? {
        BatteryRechargeMath.chargesRate(chargesRate, rate: rate, chargeCost: chargeCost)
    }

    public static func sameAsset(_ lhs: String, _ rhs: String) -> Bool {
        let left = lhs.split(separator: "/", omittingEmptySubsequences: false)
        let right = rhs.split(separator: "/", omittingEmptySubsequences: false)
        guard left.count == right.count, (3 ... 4).contains(left.count),
              left.prefix(2) == right.prefix(2) else { return false }
        if left.count == 3 { return left[2] == right[2] }
        return sameAddress(String(left[3]), String(right[3]))
    }

    static func sameAddress(_ lhs: String, _ rhs: String) -> Bool {
        if lhs.lowercased().hasPrefix("0x"), rhs.lowercased().hasPrefix("0x") {
            return lhs.caseInsensitiveCompare(rhs) == .orderedSame
        }
        return lhs == rhs
    }
}

@frozen public enum BatteryRechargeMath {
    public static func chargesRate(_ sent: String?, rate: String, chargeCost: String) -> Decimal? {
        if let sent = sent.flatMap(decimal), sent > 0 { return sent }
        guard let rate = decimal(rate), rate > 0,
              let cost = decimal(chargeCost), cost > 0 else { return nil }
        let result = rate / cost
        return !result.isNaN && result > 0 ? result : nil
    }

    public static func decimal(_ text: String) -> Decimal? {
        guard text.range(of: "^[0-9]+(?:\\.[0-9]+)?$", options: .regularExpression) != nil,
              let number = Decimal(string: text, locale: Locale(identifier: "en_US_POSIX")), !number.isNaN else { return nil }
        return number
    }

    public static func charges(amount: Decimal, rate: Decimal) -> BigUInt {
        guard amount > 0, rate > 0 else { return 0 }
        return units(amount * rate, decimals: 0) ?? 0
    }

    public static func amount(charges: Int, rate: Decimal, decimals: Int) -> BigUInt? {
        guard charges > 0, rate > 0 else { return nil }
        return units(Decimal(charges) / rate, decimals: decimals, rounding: .up)
    }

    public static func tonAmount(charges: Int64, chargeCost: String) -> Decimal? {
        guard charges > 0, let cost = decimal(chargeCost), cost > 0 else { return nil }
        let amount = Decimal(charges) * cost
        return !amount.isNaN && amount > 0 ? amount : nil
    }

    public static func units(_ amount: Decimal, decimals: Int, rounding: Decimal.RoundingMode = .down) -> BigUInt? {
        guard amount >= 0, !amount.isNaN, (0 ... 38).contains(decimals) else { return nil }
        var scaled = amount * pow(Decimal(10), decimals)
        var rounded = Decimal()
        NSDecimalRound(&rounded, &scaled, 0, rounding)
        return BigUInt(NSDecimalNumber(decimal: rounded).stringValue)
    }

    public static func value(_ units: BigUInt, decimals: Int) -> Decimal? {
        guard (0 ... 38).contains(decimals), let amount = decimal(units.description) else { return nil }
        return amount / pow(Decimal(10), decimals)
    }

    public static func minimumUnits(_ text: String?, decimals: Int) -> BigUInt? {
        guard let text else { return 1 }
        guard let value = decimal(text), value >= 0 else { return nil }
        guard let units = units(value, decimals: decimals, rounding: .up) else { return nil }
        return max(1, units)
    }
}

public struct BatteryPurchaseRequest: Equatable, Sendable {
    public let method: BatteryAssetRechargeMethod
    public let sender: String
    public let amount: BigUInt
    public let promo: String?

    public init(method: BatteryAssetRechargeMethod, sender: String, amount: BigUInt, promo: String?) {
        self.method = method
        self.sender = sender
        self.amount = amount
        self.promo = promo
    }

    var apiRequest: Components.Schemas.PurchaseBatteryEmulateRequest {
        .init(chain_id: method.chainId, sender_address: sender, asset_id: method.assetId, amount: amount.description, promo: promo)
    }
}

public struct BatteryPurchaseQuote: Equatable, Sendable {
    public let charges: Int64
    public let grossCharges: Int64
    public let fundsReceiver: String
    public init(charges: Int64, grossCharges: Int64, fundsReceiver: String) {
        self.charges = charges
        self.grossCharges = grossCharges
        self.fundsReceiver = fundsReceiver
    }

    public var feeCharges: Int64 {
        max(0, grossCharges - charges)
    }
}

public struct BatteryPurchaseReview: Sendable {
    public let quote: BatteryPurchaseQuote
    let request: BatteryPurchaseRequest
    let response: Components.Schemas.PurchaseBatteryEmulateResponse
    let receivedAt: Date

    func isExpired(at now: Date) -> Bool {
        now.timeIntervalSince(receivedAt) >= min(response.expires_at.timeIntervalSince(response.created_at) - 5, request.method.chain == .sol ? 20 : .infinity)
    }
}

@frozen public enum BatteryPurchaseError: Error {
    case invalidQuote
    case changedQuote(BatteryPurchaseReview)
    case expired
    case rejected
    case outcomeUnknown(BatteryPurchaseReview)
}
