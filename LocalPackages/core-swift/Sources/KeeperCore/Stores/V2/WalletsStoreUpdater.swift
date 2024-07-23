import Foundation

public final class WalletsStoreUpdater {
  private let keeperInfoStore: KeeperInfoStore
  private let rnService: RNService
  
  init(keeperInfoStore: KeeperInfoStore,
       rnService: RNService) {
    self.keeperInfoStore = keeperInfoStore
    self.rnService = rnService
  }
  
  public func addWallets(_ wallets: [Wallet]) async {
    guard !wallets.isEmpty else { return }
    await keeperInfoStore.updateKeeperInfo { keeperInfo in
      if let keeperInfo {
        let addedIdentities = wallets.map { $0.identity }
        let updatedWallets = keeperInfo
          .wallets
          .filter { !addedIdentities.contains($0.identity) }
        + wallets
        return keeperInfo.setWallets(updatedWallets)
      } else {
        let createdKeeperInfo = KeeperInfo.keeperInfo(wallets: wallets)
        return createdKeeperInfo
      }
    }
    let rnWallets = wallets.map { RNWallet(wallet: $0) }
    try? await rnService.addWallets(rnWallets)
  }
  
  public func setWalletActive(_ wallet: Wallet) async {
    await keeperInfoStore.updateKeeperInfo { keeperInfo in
      guard let keeperInfo else { return keeperInfo }
      guard keeperInfo.wallets.contains(wallet) else { return keeperInfo}
      let updatedKeeperInfo = keeperInfo.setActiveWallet(wallet)
      return updatedKeeperInfo
    }
    try? await rnService.setWalletActive(RNWallet(wallet: wallet))
  }
  
  public func updateWalletMetaData(_ wallet: Wallet, metaData: WalletMetaData) async {
    await keeperInfoStore.updateKeeperInfo { keeperInfo in
      guard let keeperInfo else { return keeperInfo }
      let updatedWallet = Wallet(
        id: wallet.id,
        identity: wallet.identity,
        metaData: metaData,
        setupSettings: wallet.setupSettings,
        notificationSettings: wallet.notificationSettings,
        backupSettings: wallet.backupSettings,
        addressBook: wallet.addressBook
      )
      var wallets = keeperInfo.wallets
      guard let index = wallets.firstIndex(where: { $0.id == wallet.id }) else { return keeperInfo }
      wallets.remove(at: index)
      wallets.insert(updatedWallet, at: index)
      var updatedKeeperInfo = keeperInfo.setWallets(wallets)
      if keeperInfo.currentWallet.id == wallet.id {
        updatedKeeperInfo = updatedKeeperInfo.setActiveWallet(updatedWallet)
      }
      return updatedKeeperInfo
    }
    try? await rnService.updateWalletMetaData(RNWallet(wallet: wallet), metaData: metaData)
  }
  
  public func updateWallet(_ wallet: Wallet, setupSettings: WalletSetupSettings) async {
    await keeperInfoStore.updateKeeperInfo { keeperInfo in
      guard let keeperInfo else { return keeperInfo }
      let updatedWallet = Wallet(
        id: wallet.id,
        identity: wallet.identity,
        metaData: wallet.metaData,
        setupSettings: setupSettings,
        notificationSettings: wallet.notificationSettings,
        backupSettings: wallet.backupSettings,
        addressBook: wallet.addressBook
      )
      var wallets = keeperInfo.wallets
      guard let index = wallets.firstIndex(where: { $0.id == wallet.id }) else { return keeperInfo }
      wallets.remove(at: index)
      wallets.insert(updatedWallet, at: index)
      var updatedKeeperInfo = keeperInfo.setWallets(wallets)
      if keeperInfo.currentWallet.id == wallet.id {
        updatedKeeperInfo = updatedKeeperInfo.setActiveWallet(updatedWallet)
      }
      return updatedKeeperInfo
    }
    var lastBackupAt: TimeInterval?
    if let backupDate = setupSettings.backupDate?.timeIntervalSince1970 {
      lastBackupAt = backupDate * 1000
    }
    try? await rnService.updateWallet(RNWallet(wallet: wallet),
                                     lastBackupAt: lastBackupAt)
  }
  
  public func deleteWallet(_ wallet: Wallet) async {
    await keeperInfoStore.updateKeeperInfo { keeperInfo in
      guard let keeperInfo else { return keeperInfo }
      let wallets = keeperInfo.wallets.filter { $0 != wallet }
      if wallets.isEmpty {
        return nil
      } else {
        var updatedKeeperInfo = keeperInfo.setWallets(wallets)
        if keeperInfo.currentWallet == wallet {
          updatedKeeperInfo = updatedKeeperInfo.setActiveWallet(wallets[0])
        }
        return updatedKeeperInfo
      }
    }
    try? await rnService.deleteWallet(RNWallet(wallet: wallet))
  }
  
  public func deleteAllWallets() async {
    await keeperInfoStore.updateKeeperInfo { keeperInfo in
      return nil
    }
    try? await rnService.deleteAllWallets()
  }
  
  public func moveWallet(fromIndex: Int, toIndex: Int) async {
    await keeperInfoStore.updateKeeperInfo { keeperInfo in
      guard let keeperInfo else { return keeperInfo }
      guard fromIndex < keeperInfo.wallets.count,
            fromIndex >= 0,
            toIndex < keeperInfo.wallets.count,
            toIndex >= 0 else {
        return keeperInfo
      }
      var wallets = keeperInfo.wallets
      let wallet = wallets.remove(at: fromIndex)
      wallets.insert(wallet, at: toIndex)
      let updatedKeeperInfo = keeperInfo.setWallets(wallets)
      return updatedKeeperInfo
    }
    try? await rnService.moveWallet(fromIndex: fromIndex, toIndex: toIndex)
  }
}

private extension KeeperInfo {
  static func keeperInfo(wallets: [Wallet]) -> KeeperInfo {
    let keeperInfo = KeeperInfo(
      wallets: wallets,
      currentWallet: wallets[0],
      currency: .USD,
      securitySettings: SecuritySettings(isBiometryEnabled: false, isLockScreen: false),
      isSetupFinished: false,
      assetsPolicy: AssetsPolicy(policies: [:], ordered: []),
      appCollection: AppCollection(connected: [:], recent: [], pinned: [])
    )
    return keeperInfo
  }
}
