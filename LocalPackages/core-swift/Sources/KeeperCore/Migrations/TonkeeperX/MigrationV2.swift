import Foundation
import CoreComponents
import TonSwift

public struct MigrationV2 {
  
  private let keeperInfoDirectory: URL
  private let walletsStoreUpdate: WalletsStoreUpdate
  private let mnemonicsRepositoryV1: WalletMnemonicRepository
  private let mnemonicsRepository: MnemonicsRepository
  private let passcodeRepository: PasscodeRepository
  private var settingsRepository: SettingsRepository
  
  public init(keeperInfoDirectory: URL,
              walletsStoreUpdate: WalletsStoreUpdate,
              mnemonicsRepositoryV1: WalletMnemonicRepository,
              mnemonicsRepository: MnemonicsRepository,
              passcodeRepository: PasscodeRepository,
              settingsRepository: SettingsRepository) {
    self.keeperInfoDirectory = keeperInfoDirectory
    self.walletsStoreUpdate = walletsStoreUpdate
    self.mnemonicsRepositoryV1 = mnemonicsRepositoryV1
    self.mnemonicsRepository = mnemonicsRepository
    self.passcodeRepository = passcodeRepository
    self.settingsRepository = settingsRepository
  }

  public func checkIfNeedToMigrate() -> Bool {
    !settingsRepository.didMigrateV2 && needToMigrate()
  }
  
  public mutating func migrate(passcodeProvider: () async -> String) async throws {
    let keeperInfoV1Vault: FileSystemVault<Version11V1.KeeperInfo, String> =
    FileSystemVault(
      fileManager: .default,
      directory: keeperInfoDirectory)
    
    do {
      let version1KeeperInfo = try keeperInfoV1Vault.loadItem(key: "KeeperInfo")
      guard !version1KeeperInfo.wallets.isEmpty else { return }

      var mnemonics = Mnemonics()
      var newWallets = [Wallet]()
      
      for oldWallet in version1KeeperInfo.wallets {
        let kind: WalletKind
        let hasMnemonic: Bool
        switch oldWallet.identity.kind {
        case .Regular(let publicKey, let walletContractVersion):
          kind = .Regular(publicKey, walletContractVersion)
          hasMnemonic = true
        case .Lockup(let publicKey, let lockupConfig):
          kind = .Lockup(publicKey, lockupConfig)
          hasMnemonic = false
        case .Watchonly(let resolvableAddress):
          kind = .Watchonly(resolvableAddress)
          hasMnemonic = false
        case .External(let publicKey, let walletContractVersion):
          kind = .Signer(publicKey, walletContractVersion)
          hasMnemonic = false
        }
        
        let identity = WalletIdentity(
          network: oldWallet.identity.network,
          kind: kind
        )
        
        let metaData = WalletMetaData(
          label: oldWallet.metaData.label,
          tintColor: .defaultColor,
          icon: .emoji(oldWallet.metaData.emoji)
        )
        
        let newWallet = Wallet(
          id: UUID().uuidString,
          identity: identity,
          metaData: metaData,
          setupSettings: oldWallet.setupSettings,
          notificationSettings: oldWallet.notificationSettings,
          backupSettings: oldWallet.backupSettings,
          addressBook: oldWallet.addressBook
        )
        newWallets.append(newWallet)
        
        if hasMnemonic {
          let mnemonic = try mnemonicsRepositoryV1.getMnemonic(forWallet: oldWallet)
          mnemonics[newWallet.id] = mnemonic
        }
      }
      
      if !mnemonics.isEmpty {
        try await mnemonicsRepository.importMnemonics(mnemonics, password: passcodeProvider())
      }
      try walletsStoreUpdate.addWallets(newWallets)
      try? mnemonicsRepositoryV1.deleteAll()
      try? passcodeRepository.deletePasscode()
    }
    settingsRepository.didMigrateV2 = true
  }

  private func needToMigrate() -> Bool {
    let keeperInfoVault: FileSystemVault<Version11V1.KeeperInfo, String> =
    FileSystemVault(
      fileManager: .default,
      directory: keeperInfoDirectory
    )
    
    do {
      let keeperInfo = try keeperInfoVault.loadItem(key: "KeeperInfo")
      return !keeperInfo.wallets.isEmpty
    } catch {
      return false
    }
  }
}
