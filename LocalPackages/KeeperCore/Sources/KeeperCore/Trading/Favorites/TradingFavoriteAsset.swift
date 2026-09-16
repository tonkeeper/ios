import Foundation

public struct TradingFavoriteAsset: Equatable, Identifiable, Sendable {
    public var id: String
    public var symbol: String
    public var imageURL: URL?
    public var addedAt: Date
}

public struct TradingFavoriteAssetContext: Equatable, Sendable {
    public var id: String
    public var symbol: String?
    public var imageURL: URL?

    public init(
        id: String,
        symbol: String?,
        imageURL: URL?
    ) {
        self.id = id
        self.symbol = symbol
        self.imageURL = imageURL
    }
}
