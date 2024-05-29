import Foundation
import CoreComponents
import TonSwift

public final class WalletImportController {
  
  private let activeWalletService: ActiveWalletsService
  
  init(activeWalletService: ActiveWalletsService) {
    self.activeWalletService = activeWalletService
  }
  
  public func findActiveWallets(phrase: [String], isTestnet: Bool) async throws -> [ActiveWalletModel] {
    let mnemonic = try Mnemonic(mnemonicWords: phrase)
    let keyPair = try TonSwift.Mnemonic.mnemonicToPrivateKey(
      mnemonicArray: mnemonic.mnemonicWords
    )
    return try await activeWalletService.loadActiveWallets(publicKey: keyPair.publicKey, isTestnet: isTestnet)
  }
  
  public func findActiveWallets(publicKey: TonSwift.PublicKey, isTestnet: Bool) async throws -> [ActiveWalletModel] {
    return try await activeWalletService.loadActiveWallets(publicKey: publicKey, isTestnet: isTestnet)
  }
}
