import Foundation
import TonSwift

public final class HistoryListController {
  
  public var didGetEvent: ((PaginationEvent<HistoryListSection>) -> Void)?
  
  private var didSendTransactionToken: NSObjectProtocol?
  
  private let walletsStore: WalletsStore
  private let paginator: HistoryListPaginator
  private let backgroundUpdateStore: BackgroundUpdateStore
  
  init(walletsStore: WalletsStore,
       paginator: HistoryListPaginator,
       backgroundUpdateStore: BackgroundUpdateStore) {
    self.walletsStore = walletsStore
    self.paginator = paginator
    self.backgroundUpdateStore = backgroundUpdateStore
  }
  
  public func start() async {
    didSendTransactionToken = NotificationCenter.default.addObserver(
      forName: NSNotification.Name(rawValue: "DID SEND TRANSACTION"),
      object: nil,
      queue: nil) { [weak self] notification in
        self?.didReceiveDidSendTransactionNotification()
      }
    
    _ = await backgroundUpdateStore.addEventObserver(self) { [walletsStore] observer, event in
      switch event {
      case .didUpdateState:
        break
      case .didReceiveUpdateEvent(let backgroundUpdateEvent):
        guard let walletAddress = try? walletsStore.activeWallet.address,
              backgroundUpdateEvent.accountAddress == walletAddress else { return }
        Task { await observer.didRecieveBackgroudUpdateEvent(backgroundUpdateEvent) }
      }
    }
    
    _ = walletsStore.addEventObserver(self) { observer, event in
      switch event {
      case .didUpdateActiveWallet:
        Task { await observer.paginator.start() }
      default:
        break
      }
    }
    
    await paginator.setEventHandler { [weak self] event in
      self?.didGetEvent(event)
    }
    await paginator.start()
  }
  
  public func reload() async {
    await paginator.reload()
  }
  
  public func loadNext() async {
    await paginator.loadNext()
  }
}

private extension HistoryListController {
  func didGetEvent(_ event: PaginationEvent<HistoryListSection>) {
    didGetEvent?(event)
  }
  
  func didRecieveBackgroudUpdateEvent(_ backgroundUpdateEvent: BackgroundUpdateEvent) async {
    try? await Task.sleep(nanoseconds: 2_000_000_000)
    await paginator.reload()
  }
  
  func didReceiveDidSendTransactionNotification() {
    Task {
      await paginator.reload()
    }
  }
}
