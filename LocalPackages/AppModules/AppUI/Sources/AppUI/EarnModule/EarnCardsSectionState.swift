import TKUIKit

public struct EarnCardViewData: Identifiable, Equatable {
    public let network: String
    public let vaultId: String
    public let title: String
    public let apy: String
    public let protocolName: String
    public let imageSource: AssetAvatarViewImageSource

    public var id: String {
        "\(network)/\(vaultId)"
    }

    public init(
        network: String,
        vaultId: String,
        title: String,
        apy: String,
        protocolName: String,
        imageSource: AssetAvatarViewImageSource
    ) {
        self.network = network
        self.vaultId = vaultId
        self.title = title
        self.apy = apy
        self.protocolName = protocolName
        self.imageSource = imageSource
    }
}
