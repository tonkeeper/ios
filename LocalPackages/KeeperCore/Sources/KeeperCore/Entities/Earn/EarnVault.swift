import Foundation

public struct EarnVault: Equatable, Sendable {
    public let network: String
    public let vaultId: String
    public let assetSymbol: String
    public let protocolName: String
    public let apy: Decimal
    public let iconURL: URL?

    public init(
        network: String,
        vaultId: String,
        assetSymbol: String,
        protocolName: String,
        apy: Decimal,
        iconURL: URL?
    ) {
        self.network = network
        self.vaultId = vaultId
        self.assetSymbol = assetSymbol
        self.protocolName = protocolName
        self.apy = apy
        self.iconURL = iconURL
    }
}
