import Foundation
import BigInt
import TKLocalize
import KeeperCore

protocol TokenDetailsConfigurator {
  func getTokenModel(balance: ConvertedBalance?, isSecureMode: Bool) -> TokenDetailsModel
  func getDetailsURL() -> URL?
}

extension String {
  static let tonviewer = "https://tonviewer.com"
  static let tronscan = "https://tronscan.org/#/address"
}
