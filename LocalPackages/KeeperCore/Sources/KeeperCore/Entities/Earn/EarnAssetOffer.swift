import Foundation

public struct EarnAssetOffer: Equatable, Sendable {
    public let assetId: String
    public let network: String
    public let vaultId: String
    public let apy: Decimal

    public init(
        assetId: String,
        network: String,
        vaultId: String,
        apy: Decimal
    ) {
        self.assetId = assetId
        self.network = network
        self.vaultId = vaultId
        self.apy = apy
    }
}
