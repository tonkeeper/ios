import Foundation

struct WalletCreateTransactionRequest: Encodable {
    let ownerAddress: String
    let toAddress: String
    let amount: Int64
    let visible: Bool

    enum CodingKeys: String, CodingKey {
        case ownerAddress = "owner_address"
        case toAddress = "to_address"
        case amount
        case visible
    }
}
