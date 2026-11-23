import Foundation

public struct EarnPosition: Codable, Equatable, Sendable {
    public let network: String
    public let vaultId: String
    public let protocolName: String
    public let assetSymbol: String
    public let assetIconURL: URL?
    public let balanceFiat: [String: Decimal]
    /// Zero in every currency also when the backend could not tell the earnings.
    public let earnedFiat: [String: Decimal]

    public init(
        network: String,
        vaultId: String,
        protocolName: String,
        assetSymbol: String,
        assetIconURL: URL?,
        balanceFiat: [String: Decimal],
        earnedFiat: [String: Decimal]
    ) {
        self.network = network
        self.vaultId = vaultId
        self.protocolName = protocolName
        self.assetSymbol = assetSymbol
        self.assetIconURL = assetIconURL
        self.balanceFiat = balanceFiat
        self.earnedFiat = earnedFiat
    }
}
