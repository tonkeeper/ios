import Foundation
import TonAPI

struct PubkeysWalletsBulkRequest: Encodable {
    let publicKeys: [String]

    enum CodingKeys: String, CodingKey {
        case publicKeys = "public_keys"
    }
}

struct PubkeysWalletsBulkResponse: Decodable {
    let items: [PubkeyWalletsBulkItem]
}

struct PubkeyWalletsBulkItem: Decodable {
    let publicKey: String
    let wallets: [TonAPI.Components.Schemas.Wallet]

    enum CodingKeys: String, CodingKey {
        case publicKey = "public_key"
        case wallets
    }
}
