import Foundation

// TODO: revise
public struct WalletBackupSettings: Codable {
  // TBD: revisit these
  let enabled: Bool
  let revision: Int
  let voucher: WalletVoucher?
}
