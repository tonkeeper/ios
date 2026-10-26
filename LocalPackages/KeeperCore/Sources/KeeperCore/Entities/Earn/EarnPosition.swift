import Foundation

public struct EarnPosition: Codable, Equatable, Sendable {
    public let network: String
    public let vaultId: String
    public let protocolName: String
    public let assetSymbol: String
    public let assetIconURL: URL?
    public let balanceUsd: Decimal
    public let earnedUsd: Decimal?

    public init(
        network: String,
        vaultId: String,
        protocolName: String,
        assetSymbol: String,
        assetIconURL: URL?,
        balanceUsd: Decimal,
        earnedUsd: Decimal?
    ) {
        self.network = network
        self.vaultId = vaultId
        self.protocolName = protocolName
        self.assetSymbol = assetSymbol
        self.assetIconURL = assetIconURL
        self.balanceUsd = balanceUsd
        self.earnedUsd = earnedUsd
    }
}
