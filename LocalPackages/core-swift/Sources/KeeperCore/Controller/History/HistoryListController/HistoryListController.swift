import Foundation
import TonSwift

public final class HistoryListController {
  
  public var didGetEvent: ((PaginationEvent<HistoryListSection>) -> Void)?
  
  private var didSendTransactionToken: NSObjectProtocol?
  
  private let walletsStore: WalletsStore
  private let paginator: HistoryListPaginator
  private let backgroundUpdateUpdater: BackgroundUpdateUpdater
  
  init(walletsStore: WalletsStore,
       paginator: HistoryListPaginator,
       backgroundUpdateUpdater: BackgroundUpdateUpdater) {
    self.walletsStore = walletsStore
    self.paginator = paginator
    self.backgroundUpdateUpdater = backgroundUpdateUpdater
  }
  
  public func start() async {
    didSendTransactionToken = NotificationCenter.default.addObserver(
      forName: NSNotification.Name(rawValue: "DID SEND TRANSACTION"),
      object: nil,
      queue: nil) { [weak self] notification in
        self?.didReceiveDidSendTransactionNotification()
      }
    
    backgroundUpdateUpdater.addEventObserver(self) { observer, event in
//      guard let walletAddress = try? observer.walletsStore.getState().activeWallet.friendlyAddress,
//            event.accountAddress == walleshtAddress.address else { return }
//      Task { await observer.didRecieveBackgroudUpdateEvent(event) }
    }
    
    walletsStore.addObserver(self, notifyOnAdded: false) { observer, newState, oldState in
      guard newState.activeWallet.id != oldState.activeWallet.id else { return }
      Task { await observer.paginator.start() }
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
  
  func didRecieveBackgroudUpdateEvent(_ backgroundUpdateEvent: BackgroundUpdateUpdater.BackgroundUpdateEvent) async {
    try? await Task.sleep(nanoseconds: 2_000_000_000)
    await paginator.reload()
  }
  
  func didReceiveDidSendTransactionNotification() {
    Task {
      await paginator.reload()
    }
  }
}
