import Foundation
import TonSwift

public final class HistoryListController {
  
  public var didGetEvent: ((PaginationEvent<HistoryListSection>) -> Void)?
  
  private var didSendTransactionToken: NSObjectProtocol?
  
  private let wallet: Wallet
  private let paginator: HistoryListPaginator
  private let backgroundUpdateStore: BackgroundUpdateStore
  
  init(wallet: Wallet,
       paginator: HistoryListPaginator,
       backgroundUpdateStore: BackgroundUpdateStore) {
    self.wallet = wallet
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
    
    _ = await backgroundUpdateStore.addEventObserver(self) { [wallet] observer, event in
      switch event {
      case .didUpdateState:
        break
      case .didReceiveUpdateEvent(let backgroundUpdateEvent):
        guard let walletAddress = try? wallet.address,
              backgroundUpdateEvent.accountAddress == walletAddress else { return }
        Task { await observer.didRecieveBackgroudUpdateEvent(backgroundUpdateEvent) }
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
