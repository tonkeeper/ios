struct WalletGetAccountResourceResponse: Decodable {
    let energyLimit: Int?
    let energyUsed: Int?

    private enum CodingKeys: String, CodingKey {
        case energyLimit = "EnergyLimit"
        case energyUsed = "EnergyUsed"
    }
}
