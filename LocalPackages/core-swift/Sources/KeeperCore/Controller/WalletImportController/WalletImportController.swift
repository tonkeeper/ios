import Foundation
import CoreComponents
import TonSwift
import TonTransport

public final class WalletImportController {
  
  private let activeWalletService: ActiveWalletsService
  private let currencyService: CurrencyService
  
  init(activeWalletService: ActiveWalletsService,
       currencyService: CurrencyService) {
    self.activeWalletService = activeWalletService
    self.currencyService = currencyService
  }
  
  public func findActiveWallets(phrase: [String], isTestnet: Bool) async throws -> [ActiveWalletModel] {
    let mnemonic = try Mnemonic(mnemonicWords: phrase)
    let keyPair = try TonSwift.Mnemonic.mnemonicToPrivateKey(
      mnemonicArray: mnemonic.mnemonicWords
    )
    let currency = (try? currencyService.getActiveCurrency()) ?? .USD
    return try await activeWalletService.loadActiveWallets(
      publicKey: keyPair.publicKey,
      isTestnet: isTestnet,
      currency: currency
    )
  }
  
  public func findActiveWallets(publicKey: TonSwift.PublicKey, isTestnet: Bool) async throws -> [ActiveWalletModel] {
    let currency = (try? currencyService.getActiveCurrency()) ?? .USD
    return try await activeWalletService.loadActiveWallets(
      publicKey: publicKey,
      isTestnet: isTestnet,
      currency: currency
    )
  }
  
  public func findActiveWallets(accounts: [(id: String, address: Address, revision: WalletContractVersion)], 
                                isTestnet: Bool) async throws -> [ActiveWalletModel] {
    let currency = (try? currencyService.getActiveCurrency()) ?? .USD
    return try await activeWalletService.loadActiveWallets(
      accounts: accounts,
      isTestnet: isTestnet,
      currency: currency
    )
  }
}
