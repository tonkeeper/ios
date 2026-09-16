import Foundation

// TODO: revise
typealias PublicKey = String
typealias SecretKey = String
typealias SharedKey = String

// TODO: revise
struct WalletVoucher: Codable {
    let publicKey: PublicKey
    let secretKey: SecretKey
    let sharedKey: SharedKey
    let voucher: String
}
