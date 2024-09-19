import Foundation
import TonSwift

public final class HistoryPaginationLoader {
  
  public enum Event {
    case loading
    case loadingFailed
    case loaded(AccountEvents, hasMore: Bool)
    case loadedPage(AccountEvents, hasMore: Bool)
    case pageLoading
    case pageLoadingFailed
  }
  
  enum State {
    case idle
    case loading(Task<Void, Never>)
  }
  
  public var didGetEvent: ((Event) -> Void)?
  
  private let queue = DispatchQueue(label: "HistoryPaginationLoaderQueue")
  private var state: State = .idle
  private var nextFrom: Int64?
  
  private let wallet: Wallet
  private let loader: HistoryListLoader
  
  init(wallet: Wallet, loader: HistoryListLoader) {
    self.wallet = wallet
    self.loader = loader
  }
  
  public func reload() {
    queue.async { [weak self] in
      guard let self else { return }
      if case let .loading(task) = self.state {
        task.cancel()
      }
      
      let nextFrom = nextFrom
      
      self.didGetEvent?(.loading)
      let task = Task {
        let loadEvent: Event
        let newNextFrom: Int64?
        do {
          let events = try await self.loadNextPage(nextFrom: nextFrom)
          guard !Task.isCancelled else { return }
          loadEvent = .loaded(events, hasMore: events.nextFrom != 0)
          newNextFrom = events.nextFrom
        } catch {
          loadEvent = .loadingFailed
          newNextFrom = nextFrom
        }
        self.queue.async {
          self.nextFrom = newNextFrom
          self.didGetEvent?(loadEvent)
          self.state = .idle
        }
      }
      
      self.state = .loading(task)
    }
  }
  
  public func loadNext() {
    queue.async { [weak self] in
      guard let self else { return }
      guard case .idle = self.state else {
        return
      }
      
      guard nextFrom != 0 else { return }
      
      didGetEvent?(.pageLoading)
      
      let nextFrom = nextFrom
      
      let task = Task {
        let loadEvent: Event
        let newNextFrom: Int64?
        do {
          let events = try await self.loadNextPage(nextFrom: nextFrom)
          guard !Task.isCancelled else { return }
          loadEvent = .loadedPage(events, hasMore: events.nextFrom != 0)
          newNextFrom = events.nextFrom
        } catch {
          loadEvent = .pageLoadingFailed
          newNextFrom = nextFrom
        }
        self.queue.async {
          self.nextFrom = newNextFrom
          self.didGetEvent?(loadEvent)
          self.state = .idle
        }
      }
      
      self.state = .loading(task)
    }
  }
  
  public func loadNextPage(nextFrom: Int64?) async throws -> AccountEvents {
    let events = try await loader.loadEvents(
      wallet: wallet,
      beforeLt: nextFrom,
      limit: .limit
    )
    if events.events.isEmpty && events.nextFrom != 0 {
      return try await loadNextPage(nextFrom: events.nextFrom)
    }
    return events
  }
}

private extension Int {
  static let limit: Int = 25
}
