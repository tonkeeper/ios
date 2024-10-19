import Foundation

public final class WalletsStore: StoreV3<WalletsStore.Event, WalletsStore.State> {
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
    
    public var wallets: [Wallet] {
      switch self {
      case .empty:
        return []
      case .wallets(let wallets):
        return wallets.wallets
      }
    }
    
    public var activeWallet: Wallet {
      get throws {
        switch self {
        case .empty: throw Error.noWallets
        case .wallets(let state): return state.activeWalelt
        }
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
      switch state {
      case .empty: throw Error.noWallets
      case .wallets(let state): return state.activeWalelt
      }
    }
  }

  private let keeperInfoStore: KeeperInfoStore
  
  public override func createInitialState() -> State {
    getState(keeperInfo: keeperInfoStore.getState())
  }
  
  init(keeperInfoStore: KeeperInfoStore) {
    self.keeperInfoStore = keeperInfoStore
    super.init(state: State.empty)
  }
  
  @discardableResult
  public func addWallets(_ wallets: [Wallet]) async -> State {
    return await withCheckedContinuation { continuation in
      addWallets(wallets) { state in
        continuation.resume(returning: state)
      }
    }
  }
  
  public func addWallets(_ wallets: [Wallet], completion: @escaping (State) -> Void) {
    guard !wallets.isEmpty else { return }
    keeperInfoStore.updateKeeperInfo { keeperInfo in
      guard let keeperInfo else {
        return KeeperInfo.keeperInfo(wallets: wallets)
      }
      let filter: (Wallet) -> Bool = { wallet in
        !keeperInfo.wallets.contains(where: { $0.isIdentityEqual(wallet: wallet) })
      }
      let wallets = keeperInfo.wallets + wallets.filter(filter)
      let updateKeeperInfo = keeperInfo.updateWallets(wallets)
      return updateKeeperInfo
    } completion: { [weak self] keeperInfo in
      guard let self else { return }
      let state = self.getState(keeperInfo: keeperInfo)
      updateState { _ in
        return StateUpdate(newState: state)
      } completion: { [weak self] state in
        self?.sendEvent(.didAddWallets(wallets: wallets))
        completion(state)
      }
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
      let setupSettings = WalletSetupSettings(
        backupDate: backupDate,
        isSetupFinished: wallet.setupSettings.isSetupFinished
      )
      let updated = keeperInfo.updateWallet(
        wallet, 
        setupSettings: setupSettings
      )
      return updated.keeperInfo
    }
    await self.setState { _ in
      return StateUpdate(newState: self.getState(keeperInfo: updatedKeeperInfo))
    } notify: { _ in
      var wallet = wallet
      wallet.setupSettings = WalletSetupSettings(backupDate: backupDate, 
                                                 isSetupFinished: wallet.setupSettings.isSetupFinished)
      self.sendEvent(.didUpdateWalletSetupSettings(wallet: wallet))
    }
  }
  
  public func setWalletIsSetupFinished(wallet: Wallet, isSetupFinished: Bool) async {
    let updatedKeeperInfo = await keeperInfoStore.updateKeeperInfo { keeperInfo in
      guard let keeperInfo else { return nil }
      let setupSettings = WalletSetupSettings(
        backupDate: wallet.setupSettings.backupDate,
        isSetupFinished: isSetupFinished
      )
      let updated = keeperInfo.updateWallet(
        wallet,
        setupSettings: setupSettings
      )
      return updated.keeperInfo
    }
    await self.setState { _ in
      return StateUpdate(newState: self.getState(keeperInfo: updatedKeeperInfo))
    } notify: { _ in
      var wallet = wallet
      wallet.setupSettings = WalletSetupSettings(backupDate: wallet.setupSettings.backupDate,
                                                 isSetupFinished: isSetupFinished)
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
      appSettings: AppSettings(isSecureMode: false),
      country: .auto,
      assetsPolicy: AssetsPolicy(policies: [:], ordered: []),
      appCollection: AppCollection(connected: [:], recent: [], pinned: [])
    )
    return keeperInfo
  }
}
