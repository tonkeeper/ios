import Foundation
import CoreComponents
import TonSwift

public final class WalletImportController {
  
  private let activeWalletService: ActiveWalletsService
  
  init(activeWalletService: ActiveWalletsService) {
    self.activeWalletService = activeWalletService
  }
  
  public func findActiveWallets(phrase: [String]) async throws -> [ActiveWalletModel] {
    let mnemonic = try Mnemonic(mnemonicWords: phrase)
    return try await activeWalletService.loadActiveWallets(mnemonic: mnemonic)
  }
}
