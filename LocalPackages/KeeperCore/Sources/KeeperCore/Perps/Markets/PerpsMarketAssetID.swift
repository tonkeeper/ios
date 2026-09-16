import Foundation

enum PerpsMarketAssetID {
    private static let prefix = "lighter/mainnet/"

    static func make(marketId: Int64) -> String {
        "\(prefix)\(marketId)"
    }

    static func marketId(assetId: String) -> Int64? {
        guard assetId.hasPrefix(prefix) else { return nil }
        return Int64(assetId.dropFirst(prefix.count))
    }
}
