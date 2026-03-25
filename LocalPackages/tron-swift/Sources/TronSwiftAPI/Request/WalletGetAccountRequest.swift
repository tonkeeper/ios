import Foundation

struct WalletGetAccountRequest: Encodable {
    let address: String
    let visible: Bool
}
