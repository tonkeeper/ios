import Foundation
import TonAPI
import OpenAPIRuntime

public final class BackgroundUpdate {
  private var eventObservers = [UUID: (Wallet, BackgroundUpdateEvent) -> Void]()
  private var stateObservers = [UUID: (Wallet, BackgroundUpdateConnectionState) -> Void]()
  private let lock = NSLock()
  
  private var walletBackgroundUpdates = [Wallet: WalletBackgroundUpdate]()
  
  private let walletStore: WalletsStore
  private let walletBackgroundUpdateProvider: (Wallet) -> WalletBackgroundUpdate
  
  init(walletStore: WalletsStore,
       walletBackgroundUpdateProvider: @escaping (Wallet) -> WalletBackgroundUpdate) {
    self.walletStore = walletStore
    self.walletBackgroundUpdateProvider = walletBackgroundUpdateProvider
    
    setupObservations()
  }
  
  public func start() {
    guard let wallet = try? walletStore.activeWallet else { return }
    start(for: wallet)
  }
  
  public func stop() {
    walletBackgroundUpdates.values.forEach { $0.stop() }
  }
  
  public func getState(wallet: Wallet) -> BackgroundUpdateConnectionState {
    walletBackgroundUpdates[wallet]?.state ?? .connecting
  }
  
  public func addEventObserver<T: AnyObject>(_ observer: T,
                                              closure: @escaping (T, Wallet, BackgroundUpdateEvent) -> Void) {
    let id = UUID()
    let observerClosure: (Wallet, BackgroundUpdateEvent) -> Void = { [weak self, weak observer] wallet, event in
      guard let self else { return }
      guard let observer else {
        self.eventObservers.removeValue(forKey: id)
        return
      }
      closure(observer, wallet, event)
    }
    lock.withLock {
      self.eventObservers[id] = observerClosure
    }
  }
  
  public func addStateObserver<T: AnyObject>(_ observer: T,
                                              closure: @escaping (T, Wallet, BackgroundUpdateConnectionState) -> Void) {
    let id = UUID()
    let observerClosure: (Wallet, BackgroundUpdateConnectionState) -> Void = { [weak self, weak observer] wallet, state in
      guard let self else { return }
      guard let observer else {
        self.eventObservers.removeValue(forKey: id)
        return
      }
      closure(observer, wallet, state)
    }
    lock.withLock {
      self.stateObservers[id] = observerClosure
    }
  }
  
  private func setupObservations() {
    walletStore.addObserver(self) { observer, event in
      DispatchQueue.main.async {
        switch event {
        case .didChangeActiveWallet:
          observer.stop()
          guard let activeWallet = try? observer.walletStore.activeWallet else { return }
          observer.start(for: activeWallet)
        default: break
        }
      }
    }
  }
  
  private func start(for wallet: Wallet) {
    if let updater = walletBackgroundUpdates[wallet] {
      updater.start()
    } else {
      let updater = createWalletBackgroundUpdate(wallet: wallet)
      walletBackgroundUpdates[wallet] = updater
      updater.start()
    }
  }
  
  private func createWalletBackgroundUpdate(wallet: Wallet) -> WalletBackgroundUpdate {
    let update = walletBackgroundUpdateProvider(wallet)
    update.stateClosure = { [weak self] state in
      guard let self else { return }
      DispatchQueue.main.async {
        let observers = self.lock.withLock {
          self.stateObservers
        }
        observers.forEach { $0.value(wallet, state) }
      }
    }
    update.eventClosure = { [weak self] event in
      guard let self else { return }
      DispatchQueue.main.async {
        let observers = self.lock.withLock {
          self.eventObservers
        }
        observers.forEach { $0.value(wallet, event) }
      }
    }
    return update
  }
}

public extension Swift.Error {
  var isNoConnectionError: Bool {
    switch self {
    case let urlError as URLError:
      switch urlError.code {
      case URLError.Code.notConnectedToInternet,
        URLError.Code.networkConnectionLost:
        return true
      default: return false
      }
    case let clientError as OpenAPIRuntime.ClientError:
      return clientError.underlyingError.isNoConnectionError
    default:
      return false
    }
  }
  
  var isCancelledError: Bool {
    switch self {
    case _ as CancellationError:
      return true
    case let urlError as URLError:
      switch urlError.code {
      case URLError.Code.cancelled:
        return true
      default: return false
      }
    case let clientError as OpenAPIRuntime.ClientError:
      return clientError.underlyingError.isCancelledError
    case let tonApiErrorResponse as TonAPI.ErrorResponse:
      switch tonApiErrorResponse {
      case .error(_, _, _, let error):
        return error.isCancelledError
      }
    default:
      return false
    }
  }
}
