@preconcurrency import BigInt
import Foundation
import TKTradingAPI

public struct TradingAssetInfo: Equatable, Sendable {
    public var assetId: String
    public var category: TradingAssetCategory
    public var address: String
    public var symbol: String
    public var decimals: Int
    public var title: String
    public var imageURL: URL?
    public var price: BigInt?
    public var changePercent: BigInt?
    public var changeAmount: BigInt?
    public var earnAPY: Decimal?
    public var verification: TradingVerification

    public var isUnverified: Bool {
        verification.isUnverified
    }

    public var isTrusted: Bool {
        verification.isTrusted
    }

    public init(
        assetId: String,
        category: TradingAssetCategory,
        address: String,
        symbol: String,
        decimals: Int,
        title: String,
        imageURL: URL?,
        price: BigInt?,
        changePercent: BigInt?,
        changeAmount: BigInt?,
        earnAPY: Decimal?,
        verification: TradingVerification
    ) {
        self.assetId = assetId
        self.category = category
        self.address = address
        self.symbol = symbol
        self.decimals = decimals
        self.title = title
        self.imageURL = imageURL
        self.price = price
        self.changePercent = changePercent
        self.changeAmount = changeAmount
        self.earnAPY = earnAPY
        self.verification = verification
    }
}
