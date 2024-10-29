import Foundation

public final class WalletsStore: Store<WalletsStore.Event, WalletsStore.State> {
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
    state.wallets
  }
  
  public var activeWallet: Wallet {
    get throws {
      try state.activeWallet
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
  
  @discardableResult
  public func makeWalletActive(_ wallet: Wallet) async -> State {
    return await withCheckedContinuation { continuation in
      makeWalletActive(wallet) { state in
        continuation.resume(returning: state)
      }
    }
  }
  
  @discardableResult
  public func updateWalletMetaData(_ wallet: Wallet,
                                   metaData: WalletMetaData) async -> State {
    return await withCheckedContinuation { continuation in
      updateWalletMetaData(wallet, metaData: metaData) { state in
        continuation.resume(returning: state)
      }
    }
  }
  
  @discardableResult
  public func deleteWallet(_ wallet: Wallet) async -> State {
    return await withCheckedContinuation { continuation in
      deleteWallet(wallet) { state in
        continuation.resume(returning: state)
      }
    }
  }
  
  @discardableResult
  public func deleteAllWallets() async -> State {
    return await withCheckedContinuation { continuation in
      deleteAllWallets() { state in
        continuation.resume(returning: state)
      }
    }
  }
  
  @discardableResult
  public func moveWallet(fromIndex: Int, toIndex: Int) async -> State {
    return await withCheckedContinuation { continuation in
      moveWallet(fromIndex: fromIndex, toIndex: toIndex) { state in
        continuation.resume(returning: state)
      }
    }
  }
  
  @discardableResult
  public func setWalletBackupDate(wallet: Wallet,
                                  backupDate: Date?) async -> State {
    return await withCheckedContinuation { continuation in
      setWalletBackupDate(wallet: wallet,
                          backupDate: backupDate) { state in
        continuation.resume(returning: state)
      }
    }
  }
  
  @discardableResult
  public func setWalletIsSetupFinished(wallet: Wallet,
                                       isSetupFinished: Bool) async -> State {
    return await withCheckedContinuation { continuation in
      setWalletIsSetupFinished(wallet: wallet,
                               isSetupFinished: isSetupFinished) { state in
        continuation.resume(returning: state)
      }
    }
  }
  
  public func addWallets(_ wallets: [Wallet],
                         completion: @escaping (State) -> Void) {
    guard !wallets.isEmpty else { return }
    let activeWallet = wallets[0]
    keeperInfoStore.updateKeeperInfo { keeperInfo in
      guard let keeperInfo else {
        return KeeperInfo.keeperInfo(wallets: wallets)
      }
      let filter: (Wallet) -> Bool = { wallet in
        !wallets.contains(where: { $0.isIdentityEqual(wallet: wallet) })
      }
      let wallets = keeperInfo.wallets.filter(filter) + wallets
      let updateKeeperInfo = keeperInfo.updateWallets(
        wallets,
        activeWallet: activeWallet
      )
      return updateKeeperInfo
    } completion: { [weak self] keeperInfo in
      guard let self else { return }
      let state = self.getState(keeperInfo: keeperInfo)
      updateState { _ in
        return StateUpdate(newState: state)
      } completion: { [weak self] state in
        self?.sendEvent(.didAddWallets(wallets: wallets))
        self?.sendEvent(.didChangeActiveWallet(wallet: activeWallet))
        completion(state)
      }
    }
  }
  
  public func makeWalletActive(_ wallet: Wallet,
                               completion: @escaping (State) -> Void) {
    keeperInfoStore.updateKeeperInfo { keeperInfo in
      guard let keeperInfo else { return nil }
      let updateKeeperInfo = keeperInfo.updateActiveWallet(wallet)
      return updateKeeperInfo
    } completion: { [weak self] keeperInfo in
      guard let self else { return }
      let state = self.getState(keeperInfo: keeperInfo)
      updateState { _ in
        return StateUpdate(newState: state)
      } completion: { [weak self] state in
        self?.sendEvent(.didChangeActiveWallet(wallet: wallet))
        completion(state)
      }
    }
  }
  
  public func updateWalletMetaData(_ wallet: Wallet,
                                   metaData: WalletMetaData,
                                   completion: @escaping (State) -> Void) {
    keeperInfoStore.updateKeeperInfo { keeperInfo in
      guard let keeperInfo else { return nil }
      let updateKeeperInfo = keeperInfo.updateWallet(wallet, metaData: metaData).keeperInfo
      return updateKeeperInfo
    } completion: { [weak self] keeperInfo in
      guard let self else { return }
      let state = self.getState(keeperInfo: keeperInfo)
      updateState { _ in
        return StateUpdate(newState: state)
      } completion: { [weak self] state in
        guard let wallet = state.wallets.first(where: { $0 == wallet }) else { return }
        self?.sendEvent(.didUpdateWalletMetaData(wallet: wallet))
        completion(state)
      }
    }
  }
  
  public func deleteWallet(_ wallet: Wallet,
                           completion: @escaping (State) -> Void) {
    keeperInfoStore.updateKeeperInfo { keeperInfo in
      guard let keeperInfo else { return nil }
      let updatedKeeperInfo = keeperInfo.deleteWallet(wallet)
      return updatedKeeperInfo
    } completion: { [weak self] keeperInfo in
      guard let self else { return }
      let state = self.getState(keeperInfo: keeperInfo)
      updateState { _ in
        return StateUpdate(newState: state)
      } completion: { [weak self] state in
        switch state {
        case .empty:
          self?.sendEvent(.didDeleteAll)
        case .wallets(let walletsState):
          self?.sendEvent(.didDeleteWallet(wallet: wallet))
          self?.sendEvent(.didChangeActiveWallet(wallet: walletsState.activeWalelt))
        }
        completion(state)
      }
    }
  }
  
  public func deleteAllWallets(completion: @escaping (State) -> Void) {
    keeperInfoStore.updateKeeperInfo { keeperInfo in
      return nil
    } completion: { [weak self] keeperInfo in
      guard let self else { return }
      updateState { _ in
        return StateUpdate(newState: .empty)
      } completion: { [weak self] state in
        self?.sendEvent(.didDeleteAll)
        completion(state)
      }
    }
  }
  
  public func moveWallet(fromIndex: Int, toIndex: Int, completion: @escaping (State) -> Void) {
    keeperInfoStore.updateKeeperInfo { keeperInfo in
      guard let keeperInfo else { return nil }
      let updatedKeeperInfo = keeperInfo.moveWallet(
        fromIndex: fromIndex,
        toIndex: toIndex
      )
      return updatedKeeperInfo
    } completion: { [weak self] keeperInfo in
      guard let self else { return }
      let state = self.getState(keeperInfo: keeperInfo)
      updateState { _ in
        return StateUpdate(newState: state)
      } completion: { [weak self] _ in
        self?.sendEvent(.didMoveWallet(fromIndex: fromIndex, toIndex: toIndex))
        completion(state)
      }
    }
  }
  
  public func setWalletBackupDate(wallet: Wallet,
                                  backupDate: Date?,
                                  completion: @escaping (State) -> Void) {
    keeperInfoStore.updateKeeperInfo { keeperInfo in
      guard let keeperInfo else { return nil }
      let updatedKeeperInfo = keeperInfo.updateWalletBackupDate(
        wallet,
        backupDate: backupDate
      )
      return updatedKeeperInfo
    } completion: { [weak self] keeperInfo in
      guard let self else { return }
      let state = self.getState(keeperInfo: keeperInfo)
      updateState { _ in
        return StateUpdate(newState: state)
      } completion: { [weak self] _ in
        self?.sendEvent(.didUpdateWalletSetupSettings(wallet: wallet))
        completion(state)
      }
    }
  }
  
  public func setWalletIsSetupFinished(wallet: Wallet,
                                       isSetupFinished: Bool,
                                       completion: @escaping (State) -> Void) {
    keeperInfoStore.updateKeeperInfo { keeperInfo in
      guard let keeperInfo else { return nil }
      let updatedKeeperInfo = keeperInfo.updateWalletIsSetupFinished(
        wallet,
        isSetupFinished: isSetupFinished
      )
      return updatedKeeperInfo
    } completion: { [weak self] keeperInfo in
      guard let self else { return }
      let state = self.getState(keeperInfo: keeperInfo)
      updateState { _ in
        return StateUpdate(newState: state)
      } completion: { [weak self] _ in
        self?.sendEvent(.didUpdateWalletSetupSettings(wallet: wallet))
        completion(state)
      }
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
      appSettings: AppSettings(isSecureMode: false, searchEngine: .duckduckgo),
      country: .auto,
      assetsPolicy: AssetsPolicy(policies: [:], ordered: []),
      appCollection: AppCollection(connected: [:], recent: [], pinned: [])
    )
    return keeperInfo
  }
}
