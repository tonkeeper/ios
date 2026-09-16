@preconcurrency import BigInt
import Foundation
import TKTradingAPI

public struct TradingAsset: Equatable, Identifiable, Sendable {
    public var id: String
    public var symbol: String
    public var category: TradingAssetCategory
    public var name: String
    public var subtitle: String
    public var imageURL: URL?
    public var price: BigInt?
    public var priceFractionDigits: Int
    public var change24hPercent: BigInt?
    public var change24hPercentFractionDigits: Int
    public var verification: TradingVerification

    public var isUnverified: Bool {
        verification.isUnverified
    }

    public var isTrusted: Bool {
        verification.isTrusted
    }
}

extension TradingAsset {
    init(item: Components.Schemas.MarketItem) {
        let price = item.metrics.price.decimalBigIntValue
        let change24hPercent = item.metrics.change_24h_percent.decimalBigIntValue

        self.init(
            id: item.asset.id,
            symbol: item.asset.symbol,
            category: item.asset.asset_type.asCategory,
            name: item.asset.name,
            subtitle: item.asset.name,
            imageURL: URL(string: item.asset.image_url),
            price: price?.value,
            priceFractionDigits: price?.fractionDigits ?? 0,
            change24hPercent: change24hPercent?.value,
            change24hPercentFractionDigits: change24hPercent?.fractionDigits ?? 0,
            verification: TradingVerification(api: item.asset.verification)
        )
    }
}

private struct DecimalBigIntValue {
    let value: BigInt
    let fractionDigits: Int
}

private extension String {
    var decimalBigIntValue: DecimalBigIntValue? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let isNegative = trimmed.hasPrefix("-")
        let unsignedValue = isNegative ? String(trimmed.dropFirst()) : trimmed
        let parts = unsignedValue.split(separator: ".", omittingEmptySubsequences: false)
        guard parts.count <= 2 else { return nil }

        let integerPart = String(parts[0])
        let fractionPart = parts.count == 2 ? String(parts[1]) : ""
        let digits = integerPart + fractionPart
        guard !digits.isEmpty, digits.allSatisfy(\.isNumber) else { return nil }

        let normalizedDigits = digits.trimmingLeadingZeros()
        guard let magnitude = BigInt(normalizedDigits) else { return nil }
        let value = isNegative ? -magnitude : magnitude

        return DecimalBigIntValue(
            value: value,
            fractionDigits: fractionPart.count
        )
    }

    func trimmingLeadingZeros() -> String {
        let trimmed = drop(while: { $0 == "0" })
        return trimmed.isEmpty ? "0" : String(trimmed)
    }
}
