import Foundation
import TonSwift

public actor HistoryPaginationLoader {
  public enum Event {
    case cached([AccountEvent])
    case loading
    case loadingFailed
    case loaded(AccountEvents, hasMore: Bool)
    case loadedPage(AccountEvents, hasMore: Bool)
    case pageLoading
    case pageLoadingFailed
  }
  
  enum State {
    case idle
    case isLoading
  }
  
  private var nextFrom: Int64?
  private var state: State = .idle
  
  private var continuation: AsyncStream<Event>.Continuation?
  
  private let wallet: Wallet
  private let loader: HistoryListLoader
  
  init(wallet: Wallet, 
       loader: HistoryListLoader) {
    self.wallet = wallet
    self.loader = loader
  }
  
  public func createStream() -> AsyncStream<Event> {
    AsyncStream { continuation in
      self.continuation = continuation
    }
  }
  
  nonisolated
  public func reload() {
    Task {
      await _reload()
    }
  }
  
  nonisolated
  public func loadNext() {
    Task {
      await _loadNext()
    }
  }
}

private extension HistoryPaginationLoader {
  func _reload() async {
    state = .isLoading
    nextFrom = nil
    do {
      let cached = try loader.cachedEvents(wallet: wallet)
      if !cached.isEmpty {
        continuation?.yield(.cached(cached))
      } else {
        continuation?.yield(.loading)
      }
    } catch {
      continuation?.yield(.loading)
    }
    do {
      let events = try await loadNextPage()
      continuation?.yield(.loaded(events, hasMore: events.nextFrom != 0))
    } catch {
      continuation?.yield(.loadingFailed)
    }
    state = .idle
  }
  
  func _loadNext() async {
    switch state {
    case .idle:
      guard nextFrom != 0 else { return }
      state = .isLoading
      continuation?.yield(.pageLoading)
      do {
        let events = try await loadNextPage()
        continuation?.yield(.loadedPage(events, hasMore: events.nextFrom != 0))
      } catch {
        continuation?.yield(.pageLoadingFailed)
      }
      state = .idle
    case.isLoading:
      return
    }
  }
  
  func loadNextPage() async throws -> AccountEvents {
//    try? await Task.sleep(nanoseconds: 2_000_000_000)
    let events = try await loader.loadEvents(
      wallet: wallet,
      beforeLt: nextFrom,
      limit: .limit
    )
    self.nextFrom = events.nextFrom
    if events.events.isEmpty && events.nextFrom != 0 {
      return try await loadNextPage()
    }
    return events
  }
}

private extension Int {
  static let limit: Int = 100
}
