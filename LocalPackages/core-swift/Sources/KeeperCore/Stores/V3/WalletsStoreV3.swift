import Foundation

public final class WalletsStoreV3: StoreV3<WalletsStoreV3.Event, WalletsStoreV3.State> {
  public enum Error: Swift.Error {
    case noWallets
  }
  
  public enum Event {
    case didAddWallets(wallets: [Wallet])
    case didChangeActiveWallet(wallet: Wallet)
    case didMoveWallet(fromIndex: Int, toIndex: Int)
    case didUpdateWalletMetaData(wallet: Wallet)
    case didUpdateWalletSetupSettings(wallet: Wallet)
    case didDeleteWallet(wallet: Wallet)
    case didDeleteAll
  }
  
  public enum State {
    public struct Wallets {
      public let wallets: [Wallet]
      public let activeWalelt: Wallet
    }
    
    case empty
    case wallets(Wallets)
  }
  
  public var stateWallets: State.Wallets {
    get throws {
      switch getState() {
      case .empty:
        throw Error.noWallets
      case .wallets(let wallets):
        return wallets
      }
    }
  }
  
  public var wallets: [Wallet] {
    switch getState() {
    case .empty:
      return []
    case .wallets(let wallets):
      return wallets.wallets
    }
  }
  
  public func getActiveWallet() throws -> Wallet {
    switch getState() {
    case .empty:
      throw Error.noWallets
    case .wallets(let wallets):
      return wallets.activeWalelt
    }
  }
  
  public func getActiveWallet() async throws -> Wallet {
    switch await getState() {
    case .empty:
      throw Error.noWallets
    case .wallets(let wallets):
      return wallets.activeWalelt
    }
  }

  private let keeperInfoStore: KeeperInfoStoreV3
  
  public override var initialState: State {
    getState(keeperInfo: keeperInfoStore.getState())
  }
  
  init(keeperInfoStore: KeeperInfoStoreV3) {
    self.keeperInfoStore = keeperInfoStore
    super.init(state: State.empty)
  }
  
  public func addWallets(_ wallets: [Wallet]) async {
    guard !wallets.isEmpty else { return }
    
    let updatedKeeperInfo = await keeperInfoStore.updateKeeperInfo { keeperInfo in
      if let keeperInfo {
        let updatedWallets = keeperInfo.wallets
          .filter { keeperInfoWallet in !wallets.contains(where: { $0.identity == keeperInfoWallet.identity }) }
        + wallets
        let updatedKeeperInfo = keeperInfo.updateWallets(
          updatedWallets,
          activeWallet: wallets[0]
        )
        return updatedKeeperInfo
      } else {
        return KeeperInfo.keeperInfo(wallets: wallets)
      }
    }
    
    await setState { _ in
      return StateUpdate(newState: self.getState(keeperInfo: updatedKeeperInfo))
    } notify: { _ in
      self.sendEvent(.didAddWallets(wallets: wallets))
      self.sendEvent(.didChangeActiveWallet(wallet: wallets[0]))
    }
  }
  
  public func setWalletActive(_ wallet: Wallet) async {
    let updatedKeeperInfo = await keeperInfoStore.updateKeeperInfo { keeperInfo in
      guard let keeperInfo else { return nil }
      let updatedKeeperInfo = keeperInfo.updateActiveWallet(wallet)
      return updatedKeeperInfo
    }
    
    await setState { _ in
      return StateUpdate(newState: self.getState(keeperInfo: updatedKeeperInfo))
    } notify: { _ in
      self.sendEvent(.didChangeActiveWallet(wallet: wallet))
    }
  }
  
  public func setWallet(_ wallet: Wallet, metaData: WalletMetaData) async {
    let updatedKeeperInfo = await keeperInfoStore.updateKeeperInfo { keeperInfo in
      guard let keeperInfo else { return nil }
      let updated = keeperInfo.updateWallet(wallet, metaData: metaData)
      return updated.keeperInfo
    }
    
    await setState { _ in
      return StateUpdate(newState: self.getState(keeperInfo: updatedKeeperInfo))
    } notify: { _ in
      var updatedWallet = wallet
      updatedWallet.metaData = metaData
      self.sendEvent(.didUpdateWalletMetaData(wallet: updatedWallet))
    }
  }
  
  public func deleteWallet(_ wallet: Wallet) async {
    let updatedKeeperInfo = await keeperInfoStore.updateKeeperInfo { keeperInfo in
      guard let keeperInfo else { return nil }
      let updatedKeeperInfo = keeperInfo.deleteWallet(wallet)
      return updatedKeeperInfo
    }
    
    await setState { _ in
      return StateUpdate(newState: self.getState(keeperInfo: updatedKeeperInfo))
    } notify: { state in
      switch state {
      case .empty:
        self.sendEvent(.didDeleteAll)
      case .wallets(let walletsState):
        self.sendEvent(.didDeleteWallet(wallet: wallet))
        self.sendEvent(.didChangeActiveWallet(wallet: walletsState.activeWalelt))
      }
    }
  }
  
  public func deleteAllWallets() async {
    await keeperInfoStore.updateKeeperInfo { keeperInfo in
      return nil
    }
    await self.setState { _ in
      return StateUpdate(newState: .empty)
    } notify: { _ in
      self.sendEvent(.didDeleteAll)
    }
  }
  
  public func moveWallet(fromIndex: Int, toIndex: Int) async {
    let updatedKeeperInfo = await keeperInfoStore.updateKeeperInfo { keeperInfo in
      guard let keeperInfo else { return nil }
      let updated = keeperInfo.moveWallet(fromIndex: fromIndex, toIndex: toIndex)
      return updated
    }
    await self.setState { _ in
      return StateUpdate(newState: self.getState(keeperInfo: updatedKeeperInfo))
    } notify: { _ in
      self.sendEvent(.didMoveWallet(fromIndex: fromIndex, toIndex: toIndex))
    }
  }
  
  public func setWalletBackupDate(wallet: Wallet, backupDate: Date?) async {
    let updatedKeeperInfo = await keeperInfoStore.updateKeeperInfo { keeperInfo in
      guard let keeperInfo else { return nil }
      let updated = keeperInfo.updateWallet(
        wallet, 
        setupSettings: WalletSetupSettings(backupDate: backupDate)
      )
      return updated.keeperInfo
    }
    await self.setState { _ in
      return StateUpdate(newState: self.getState(keeperInfo: updatedKeeperInfo))
    } notify: { _ in
      var wallet = wallet
      wallet.setupSettings = WalletSetupSettings(backupDate: backupDate)
      self.sendEvent(.didUpdateWalletSetupSettings(wallet: wallet))
    }
  }
  
  private func getState(keeperInfo: KeeperInfo?) -> State {
    if let keeperInfo = keeperInfoStore.getState() {
      return .wallets(State.Wallets(wallets: keeperInfo.wallets, activeWalelt: keeperInfo.currentWallet))
    } else {
      return .empty
    }
  }
}

private extension KeeperInfo {
  static func keeperInfo(wallets: [Wallet]) -> KeeperInfo {
    let keeperInfo = KeeperInfo(
      wallets: wallets,
      currentWallet: wallets[0],
      currency: .defaultCurrency,
      securitySettings: SecuritySettings(isBiometryEnabled: false, isLockScreen: false),
      appSettings: AppSettings(isSetupFinished: false, isSecureMode: false),
      assetsPolicy: AssetsPolicy(policies: [:], ordered: []),
      appCollection: AppCollection(connected: [:], recent: [], pinned: [])
    )
    return keeperInfo
  }
}
