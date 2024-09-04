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
  
  public var activeWallet: Wallet {
    get throws {
      switch getState() {
      case .empty:
        throw Error.noWallets
      case .wallets(let wallets):
        return wallets.activeWalelt
      }
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
    
    var updatedKeeperInfo: KeeperInfo?
    await keeperInfoStore.updateKeeperInfo { keeperInfo in
      if let keeperInfo {
        let updatedWallets = keeperInfo.wallets
          .filter { !wallets.contains($0) }
        + wallets
        
        updatedKeeperInfo = keeperInfo.updateWallets(
          updatedWallets,
          activeWallet: wallets[0]
        )
      } else {
        updatedKeeperInfo = KeeperInfo.keeperInfo(wallets: wallets)
      }
      return updatedKeeperInfo
    }
    await setState { _ in
      return StateUpdate(newState: self.getState(keeperInfo: updatedKeeperInfo))
    } notify: {
      self.sendEvent(.didAddWallets(wallets: wallets))
    }
  }
  
  public func setWalletActive(_ wallet: Wallet) async {
    var updatedKeeperInfo: KeeperInfo?
    await keeperInfoStore.updateKeeperInfo { keeperInfo in
      guard let keeperInfo else { return nil }
      updatedKeeperInfo = keeperInfo.updateActiveWallet(wallet)
      return updatedKeeperInfo
    }
    await self.setState { _ in
      return StateUpdate(newState: self.getState(keeperInfo: updatedKeeperInfo))
    } notify: {
      self.sendEvent(.didChangeActiveWallet(wallet: wallet))
    }
  }
  
  public func setWallet(_ wallet: Wallet, metaData: WalletMetaData) async {
    var updatedKeeperInfo: KeeperInfo?
    await keeperInfoStore.updateKeeperInfo { keeperInfo in
      guard let keeperInfo else { return nil }
      
      let updated = keeperInfo.updateWallet(wallet, metaData: metaData)
      updatedKeeperInfo = updated.keeperInfo
      return updated.keeperInfo
    }
    await self.setState { _ in
      return StateUpdate(newState: self.getState(keeperInfo: updatedKeeperInfo))
    } notify: {
      self.sendEvent(.didUpdateWalletMetaData(wallet: wallet))
    }
  }
  
  public func deleteWallet(_ wallet: Wallet) async {
    var updatedKeeperInfo: KeeperInfo?
    await keeperInfoStore.updateKeeperInfo { keeperInfo in
      guard let keeperInfo else { return nil }
      
      let updated = keeperInfo.deleteWallet(wallet)
      updatedKeeperInfo = updated
      return updated
    }
    await self.setState { _ in
      return StateUpdate(newState: self.getState(keeperInfo: updatedKeeperInfo))
    } notify: {
      self.sendEvent(.didDeleteWallet(wallet: wallet))
    }
  }
  
  public func moveWallet(fromIndex: Int, toIndex: Int) async {
    var updatedKeeperInfo: KeeperInfo?
    await keeperInfoStore.updateKeeperInfo { keeperInfo in
      guard let keeperInfo else { return nil }
      
      let updated = keeperInfo.moveWallet(fromIndex: fromIndex, toIndex: toIndex)
      updatedKeeperInfo = updated
      return updated
    }
    await self.setState { _ in
      return StateUpdate(newState: self.getState(keeperInfo: updatedKeeperInfo))
    } notify: {
      self.sendEvent(.didMoveWallet(fromIndex: fromIndex, toIndex: toIndex))
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
      isSetupFinished: false,
      assetsPolicy: AssetsPolicy(policies: [:], ordered: []),
      appCollection: AppCollection(connected: [:], recent: [], pinned: [])
    )
    return keeperInfo
  }
}
