struct WalletGetAccountNetResponse: Decodable {
    var freeNetLimit: Int?
    var freeNetUsed: Int?
    var netLimit: Int?
    var netUsed: Int?

    private enum CodingKeys: String, CodingKey {
        case freeNetLimit
        case freeNetUsed
        case netLimit = "NetLimit"
        case netUsed = "NetUsed"
    }
}
