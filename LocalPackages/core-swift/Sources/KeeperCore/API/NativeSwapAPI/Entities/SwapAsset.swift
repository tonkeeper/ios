import Foundation

public struct SwapAsset: Codable, Equatable {
    public let symbol: String
    public let name: String
    public let decimals: Int
    public let address: String
    public let image: URL?
    public var rates: [Currency: Rates.Rate]?
}
