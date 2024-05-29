import Foundation

public final class SignerSignController {
  
  public let url: URL
  public let wallet: Wallet
  
  init(url: URL,
       wallet: Wallet) {
    self.url = url
    self.wallet = wallet
  }
}
