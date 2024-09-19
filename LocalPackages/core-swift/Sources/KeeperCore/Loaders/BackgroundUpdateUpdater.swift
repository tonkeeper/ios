import Foundation
import TonStreamingAPI
import EventSource
import TonSwift
import OpenAPIRuntime
import TonAPI

public actor BackgroundUpdateUpdater {
  private var task: Task<Void, Never>?
  private let jsonDecoder = JSONDecoder()
  private var observations = [UUID: (WalletBackgroundUpdate.Event) -> Void]()

  private var walletUpdaters = [Wallet: WalletBackgroundUpdate]()
  
  private let backgroundUpdateStore: BackgroundUpdateStore
  private let walletsStore: WalletsStore
  private let streamingAPI: StreamingAPI
  
  init(backgroundUpdateStore: BackgroundUpdateStore,
       walletsStore: WalletsStore,
       streamingAPI: StreamingAPI) {
    self.backgroundUpdateStore = backgroundUpdateStore
    self.walletsStore = walletsStore
    self.streamingAPI = streamingAPI
    
    walletsStore.addObserver(self) { observer, event in
      Task {
        switch event {
        case .didDeleteWallet(let wallet):
          await observer.setWalletUpdater(
            wallet: wallet, updater: observer.createUpdater(wallet: wallet)
          )
        case .didAddWallets(let wallets):
          for wallet in wallets {
            await observer.setWalletUpdater(wallet: wallet, updater: observer.createUpdater(wallet: wallet))
          }
        default:
          break
        }
      }
    }
  }
  
  public func start() {
    let wallets = walletsStore.wallets
    let updaters: [WalletBackgroundUpdate] = wallets.map { wallet in
      if let updater = walletUpdaters[wallet] {
        return updater
      }
      let updater = createUpdater(wallet: wallet)
      walletUpdaters[wallet] = updater
      return updater
    }
    
    for updater in updaters {
      Task {
        await updater.start()
      }
    }
  }
  
  public func stop() {
    for updater in walletUpdaters.values {
      Task {
        await updater.stop()
      }
    }
  }
  
  private func createUpdater(wallet: Wallet) -> WalletBackgroundUpdate {
    WalletBackgroundUpdate(
      wallet: wallet,
      backgroundUpdateStore: backgroundUpdateStore,
      streamingAPI: streamingAPI) { [weak self] event in
        guard let self else { return }
        Task {
          try? await Task.sleep(nanoseconds: 10_000_000_000)
          await self.observations.values.forEach { $0(event) }
        }
      }
  }
  
  private func setWalletUpdater(wallet: Wallet, updater: WalletBackgroundUpdate) {
    walletUpdaters[wallet] = updater
  }
  
  @discardableResult
  nonisolated
  public func addEventObserver<T: AnyObject>(_ observer: T,
                                      closure: @escaping (T, WalletBackgroundUpdate.Event) -> Void) -> ObservationToken {
    let id = UUID()
    let eventHandler: (WalletBackgroundUpdate.Event) -> Void = { [weak self, weak observer] event in
      guard let self else { return }
      guard let observer else {
        Task { await self.removeObservation(key: id) }
        return
      }
      
      closure(observer, event)
    }
    
    Task {
      await addObserver(eventHandler, key: id)
    }
    
    return ObservationToken { [weak self] in
      guard let self else { return }
      Task { await self.removeObservation(key: id) }
    }
  }
  
  func addObserver(_ eventHandler: @escaping (WalletBackgroundUpdate.Event) -> Void, key: UUID) {
    observations[key] = eventHandler
  }
  
  func removeObservation(key: UUID) {
    observations.removeValue(forKey: key)
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

