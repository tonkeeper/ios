import Foundation
import TKUIKit
import TKCore
import KeeperCore
import CoreComponents
import TonSwift

struct MergeMigration {
  
  enum MigrationResult {
    case failedMigrateMnemonics(error: MnemonicMigrationError)
    case failedMigrateWallets(error: WalletsMigrationError)
    case partialy(failedWallets: [RNWallet])
    case success
  }
  
  enum MnemonicMigrationError: Swift.Error {
    case noMnemonics
    case readStorageError(Swift.Error)
    case importError(Swift.Error)
  }
  
  enum WalletsMigrationResult {
    case success(failedWallets: [RNWallet])
    case failure(error: WalletsMigrationError)
  }
  
  enum WalletsMigrationError: Swift.Error {
    case noWallets
    case failedWalletsMigration(wallet: [RNWallet])
    case importError(Swift.Error)
  }

  private let asyncStorage: RNAsyncStorage
  private let appInfoProvider: TKCore.AppInfoProvider
  private let mnemonicsRepository: MnemonicsVault
  private let rnMnemonicsRepository: RNMnemonicsVault
  private let keeperInfoRepository: KeeperInfoRepository
  private let keeperInfoStore: KeeperInfoStore
  private let tonProofTokenService: TonProofTokenService
  
  init(asyncStorage: RNAsyncStorage, 
       appInfoProvider: TKCore.AppInfoProvider,
       mnemonicsRepository: MnemonicsVault,
       rnMnemonicsRepository: RNMnemonicsVault,
       keeperInfoRepository: KeeperInfoRepository,
       keeperInfoStore: KeeperInfoStore,
       tonProofTokenService: TonProofTokenService) {
    self.asyncStorage = asyncStorage
    self.appInfoProvider = appInfoProvider
    self.mnemonicsRepository = mnemonicsRepository
    self.rnMnemonicsRepository = rnMnemonicsRepository
    self.keeperInfoRepository = keeperInfoRepository
    self.keeperInfoStore = keeperInfoStore
    self.tonProofTokenService = tonProofTokenService
  }
  
  func isNeedToMigrateFromRN() async -> Bool {
    if let xFlag: Bool = try? await asyncStorage.getValue(key: "x"),
       xFlag {
      return false
    } else {
      if let walletsStore: RNWalletsStore = try? await asyncStorage.getValue(key: .rnWalletsStoreKey),
         !walletsStore.wallets.isEmpty {
        return true
      }
      return false
    }
  }
  
  func isNeedToMigrateFromNative() -> Bool {
    rnMnemonicsRepository.hasMnemonics() && !mnemonicsRepository.hasMnemonics()
  }
  
  func performNativeMigration(passcode: @escaping ( @escaping (String) -> Void ) -> Void,
                              completion: @escaping (MigrationResult) -> Void) {
    let mnemonicsMigrationResult = migrateMnemonics()
    switch mnemonicsMigrationResult {
    case .success:
      migratePasscodeRequiredItemsBiometryPasscode(passcode: passcode) {
        completion(.success)
      }
    case .failure(let failure):
      completion(.failedMigrateMnemonics(error: failure))
    }
  }
  
  func performRNMigration(passcode: @escaping ( @escaping (String) -> Void ) -> Void) async -> MigrationResult {
    let mnemonicsMigrationResult = migrateMnemonics()
    switch mnemonicsMigrationResult {
    case .success:
      let walletsMigrationResult = await migrateRNWallet()
      switch walletsMigrationResult {
      case .success(let failedWallets):
        await migratePasscodeRequiredItemsBiometryPasscode(passcode: passcode)
        if failedWallets.isEmpty {
          return .success
        } else {
          return .partialy(failedWallets: failedWallets)
        }
        
      case .failure(let error):
        return .failedMigrateWallets(error: error)
      }
    case .failure(let failure):
      return .failedMigrateMnemonics(error: failure)
    }
  }
  
  private func migrateMnemonics() -> Result<Void, MnemonicMigrationError> {
    guard rnMnemonicsRepository.hasMnemonics() else { return .failure(.noMnemonics) }
    let encryptedMnemonics: EncryptedMnemonics
    do {
      encryptedMnemonics = try rnMnemonicsRepository.getEncryptedMnemonics()
    } catch {
      return .failure(.readStorageError(error))
    }
    do {
      try mnemonicsRepository.importEncryptedMnemonics(encryptedMnemonics)
      return .success(())
    } catch {
      return .failure(.importError(error))
    }
  }
  
  private func migratePasscodeRequiredItemsBiometryPasscode(passcode: @escaping ( @escaping (String) -> Void ) -> Void) async {
    await withCheckedContinuation { continuation in
      migratePasscodeRequiredItemsBiometryPasscode(passcode: passcode) {
        continuation.resume()
      }
    }
  }
  
  private func migratePasscodeRequiredItemsBiometryPasscode(passcode: @escaping ( @escaping (String) -> Void ) -> Void, completion: @escaping () -> Void) {
    let isBiometryEnable = (try? keeperInfoRepository.getKeeperInfo().securitySettings.isBiometryEnabled) ?? false
    let missedTonProofWallets = tonProofTokenService.getWalletsWithMissedToken()
    
    if isBiometryEnable || !missedTonProofWallets.isEmpty {
      passcode({ [mnemonicsRepository] passcode in
        Task { @MainActor in
          if isBiometryEnable {
            try? mnemonicsRepository.savePassword(passcode)
          }
          for wallet in missedTonProofWallets {
            guard let mnemonic = try? await mnemonicsRepository.getMnemonic(wallet: wallet, password: passcode),
                  let keyPair = try? TonSwift.Mnemonic.mnemonicToPrivateKey(
                    mnemonicArray: mnemonic.mnemonicWords) else { continue }
            let pair = WalletPrivateKeyPair(
              wallet: wallet,
              privateKey: keyPair.privateKey
            )
            await tonProofTokenService.loadTokensFor(pairs: [pair])
          }
          completion()
        }
      })
    } else {
      completion()
    }
  }
  
  private func migrateRNWallet() async -> WalletsMigrationResult {
    guard let rnWalletsStore: RNWalletsStore = try? await asyncStorage.getValue(key: .rnWalletsStoreKey),
    !rnWalletsStore.wallets.isEmpty else {
      return .failure(error: .noWallets)
    }
    let activeWalletId = rnWalletsStore.selectedIdentifier
    
    let rnWallets = rnWalletsStore.wallets
    var wallets = [Wallet]()
    var rnWalletNotMigrated = [RNWallet]()
    for rnWallet in rnWalletsStore.wallets {
      let backupDate = try? await getRNWalletBackupDate(walletId: rnWallet.identifier)
      guard let wallet = try? rnWallet.getWallet(backupDate: backupDate) else {
        rnWalletNotMigrated.append(rnWallet)
        continue
      }
      guard !wallets.contains(where: { $0.identity == wallet.identity }) else { continue }
      wallets.append(wallet)
    }
    
    guard !wallets.isEmpty else {
      return .failure(error: .failedWalletsMigration(wallet: rnWallets))
    }
    
    let currentWallet = wallets.first(where: { $0.id == activeWalletId }) ?? wallets[0]
    let isBiometryEnabled = rnWalletsStore.biometryEnabled
    let isLockScreen = rnWalletsStore.lockScreenEnabled
    let currency: Currency = await {
      guard let tonPrice: RNTonPrice = try? await asyncStorage.getValue(key: "ton_price") else {
        return .USD
      }
      let currencyRaw = tonPrice.currency
      return Currency(rawValue: currencyRaw.uppercased()) ?? .USD
    }()
    
    let keeperInfo = KeeperInfo(
      wallets: wallets,
      currentWallet: currentWallet,
      currency: currency,
      securitySettings: SecuritySettings(
        isBiometryEnabled: isBiometryEnabled,
        isLockScreen: isLockScreen
      ),
      appSettings: KeeperInfo.AppSettings(
        isSecureMode: false,
        searchEngine: .duckduckgo
      ),
      country: .auto
    )
    
    let theme: TKTheme = await {
      guard let appTheme: RNAppTheme = try? await asyncStorage.getValue(key: .appTheme),
            let theme = TKTheme(rawValue: appTheme.state.selectedTheme) else {
        return .deepBlue
      }
      return theme
    }()
    await MainActor.run {
      TKThemeManager.shared.theme = theme
    }
    
    do {
      try keeperInfoRepository.saveKeeperInfo(keeperInfo)
      _ = await keeperInfoStore.updateKeeperInfo { _ in
        return keeperInfo
      }
      try? await asyncStorage.setValue(value: true, key: "x")
      return .success(failedWallets: rnWalletNotMigrated)
    } catch {
      return .failure(error: .importError(error))
    }
  }
  
  private func getRNWalletBackupDate(walletId: String) async throws -> Date? {
    let key = "\(walletId)/setup"
    guard let setupState: RNWalletSetupState? = try await asyncStorage.getValue(key: key),
          let lastBackupAt = setupState?.lastBackupAt else {
      return nil
    }
    return Date(timeIntervalSince1970: lastBackupAt / 1000)
  }
}

private extension String {
  static let rnWalletsStoreKey = "walletsStore"
  static let appTheme = "app-theme"
}
