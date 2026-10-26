import Foundation

@frozen public enum PerpsMarketAssetID {
    private static let currentPrefix = "lighter/mainnet/market/"
    private static let legacyPrefix = "lighter/mainnet/"

    public static func make(marketId: Int64) -> String {
        "\(currentPrefix)\(marketId)"
    }

    public static func marketId(assetId: String) -> Int64? {
        if assetId.hasPrefix(currentPrefix) {
            return Int64(assetId.dropFirst(currentPrefix.count))
        }
        guard assetId.hasPrefix(legacyPrefix),
              !assetId.hasPrefix(currentPrefix)
        else {
            return nil
        }
        return Int64(assetId.dropFirst(legacyPrefix.count))
    }
}
