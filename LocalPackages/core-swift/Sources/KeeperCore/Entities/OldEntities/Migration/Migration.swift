//import Foundation
//import CoreComponents
//import TonSwift
//
//public struct KeeperInfoMigration {
//  private let keeperInfoDirectory: URL
//  private let sharedKeychainGroup: String
//  
//  public init(keeperInfoDirectory: URL,
//              sharedKeychainGroup: String) {
//    self.keeperInfoDirectory = keeperInfoDirectory
//    self.sharedKeychainGroup = sharedKeychainGroup
//  }
//  
//  public func migrateKeeperInfoIfNeeded() {
//    let version_1_0_0_Vault: FileSystemVault<
//      Version_1_0_0.KeeperInfo,
//      String
//    > = FileSystemVault(
//      fileManager: .default,
//      directory: keeperInfoDirectory
//    )
//    
//    let keeperInfoVault: FileSystemVault<KeeperInfo, String> =
//    FileSystemVault(
//      fileManager: .default,
//      directory: keeperInfoDirectory
//    )
//    
//    do {
//      let version_1_0_0_KeeperInfo = try version_1_0_0_Vault.loadItem(key: "KeeperInfo")
//      guard !version_1_0_0_KeeperInfo.wallets.isEmpty else { return }
//      
//      let oldWallet = version_1_0_0_KeeperInfo.wallets[0]
//      let walletKind: WalletKind
//      let oldWalletPublicKey: TonSwift.PublicKey
//      switch oldWallet.identity.kind {
//      case .Regular(let publicKey):
//        walletKind = .Regular(publicKey, .v4R2)
//        oldWalletPublicKey = publicKey
//      case .Lockup:
//        return
//      case .Watchonly:
//        return
//      case .External:
//        return
//      }
//      
//      let wallet = Wallet(
//        id: UUID().uuidString,
//        identity: WalletIdentity(
//          network: .mainnet,
//          kind: walletKind
//        ),
//        metaData: WalletMetaData(
//          label: "Wallet",
//          tintColor: .steelGray,
//          emoji: "👽"
//        ),
//        setupSettings: WalletSetupSettings(backupDate: nil),
//        notificationSettings: oldWallet.notificationSettings,
//        backupSettings: oldWallet.backupSettings,
//        addressBook: oldWallet.addressBook
//      )
//      let keeperInfo = KeeperInfo(
//        wallets: [wallet],
//        currentWallet: wallet,
//        currency: .USD,
//        securitySettings: SecuritySettings(isBiometryEnabled: version_1_0_0_KeeperInfo.securitySettings.isBiometryEnabled),
//        isSetupFinished: version_1_0_0_KeeperInfo.securitySettings.isBiometryEnabled,
//        assetsPolicy: version_1_0_0_KeeperInfo.assetsPolicy,
//        appCollection: version_1_0_0_KeeperInfo.appCollection
//      )
//
//      let keychainVault = KeychainVaultImplementation(keychain: KeychainImplementation())
//      let queryableItem = KeychainGenericPasswordItem(service: try oldWallet.identity.id().string,
//                                                      account: oldWalletPublicKey.hexString,
//                                                      accessGroup: sharedKeychainGroup,
//                                                      accessible: .whenUnlockedThisDeviceOnly)
//      let oldMnemonic: CoreComponents.Mnemonic = try keychainVault.readValue(queryableItem)
//      
//      let mnemonicVault = MnemonicVault(keychainVault: keychainVault, accessGroup: nil)
//      try mnemonicVault.saveMnemonic(oldMnemonic, forWallet: wallet)
//      try keeperInfoVault.saveItem(keeperInfo, key: "KeeperInfo")
//    } catch {}
//  }
//}
