import Foundation
import URKit

public final class KeystoneSignController {
  
  public let transaction: UR
  public let wallet: Wallet
  
  init(transaction: UR, wallet: Wallet) {
    self.transaction = transaction
    self.wallet = wallet
  }
}
