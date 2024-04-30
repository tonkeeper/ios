import Foundation

// TODO: revise
public typealias PublicKey = String
public typealias SecretKey = String
public typealias SharedKey = String

// TODO: revise
public struct WalletVoucher: Codable {
  let publicKey: PublicKey
  let secretKey: SecretKey
  let sharedKey: SharedKey
  let voucher: String
}
