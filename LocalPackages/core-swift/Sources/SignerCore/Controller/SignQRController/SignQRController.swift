import Foundation

public final class SignQRController {
  
  public let hexBody: String
  public let walletKey: WalletKey
  public let url: URL
  
  init(hexBody: String,
       walletKey: WalletKey,
       url: URL) {
    self.hexBody = hexBody
    self.walletKey = walletKey
    self.url = url
  }
}
