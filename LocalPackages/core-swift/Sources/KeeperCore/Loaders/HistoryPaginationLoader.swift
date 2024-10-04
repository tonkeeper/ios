import Foundation
import TonSwift

public final class HistoryPaginationLoader {
  public enum Event {
    case initialLoading
    case initialLoadingFailed
    case initialLoaded(AccountEvents)
    case pageLoading
    case pageLoadingFailed
    case pageLoaded(AccountEvents)
  }
  
  public var eventHandler: ((Event) -> Void)?
  
  private enum State {
    case idle
    case loading(Task<Void, Never>)
  }
  
  private let queue = DispatchQueue(label: "HistoryPaginationLoaderQueue")
  private var state: State = .idle
  private var nextFrom: Int64?
  
  private let wallet: Wallet
  private let loader: HistoryListLoader
  private let nftService: NFTService
  
  init(wallet: Wallet,
       loader: HistoryListLoader,
       nftService: NFTService) {
    self.wallet = wallet
    self.loader = loader
    self.nftService = nftService
  }
  
  public func reload() {
    queue.async {
      if case let .loading(task) = self.state {
        task.cancel()
      }
      self.nextFrom = nil
            
      let task = Task {
        do {
          let events = try await self.loadNextPage(nextFrom: nil)
          try Task.checkCancellation()
          self.queue.async {
            self.nextFrom = events.nextFrom
            self.eventHandler?(.initialLoaded(events))
            self.state = .idle
          }
        } catch {
          self.queue.async {
            guard !error.isCancelledError else { return }
            self.eventHandler?(.initialLoadingFailed)
            self.state = .idle
          }
        }
      }
      
      self.eventHandler?(.initialLoading)
      self.state = .loading(task)
    }
  }
  
  public func loadNext() {
    queue.async {
      guard case .idle = self.state else {
        return
      }
      guard self.nextFrom != 0 else { return }
      
      let nextFrom = self.nextFrom
      
      let task = Task {
        do {
          let events = try await self.loadNextPage(nextFrom: nextFrom)
          try Task.checkCancellation()
          self.queue.async {
            self.nextFrom = events.nextFrom
            self.eventHandler?(.pageLoaded(events))
            self.state = .idle
          }
        } catch {
          self.queue.async {
            guard !error.isCancelledError else { return }
            self.eventHandler?(.pageLoadingFailed)
            self.state = .idle
          }
        }
      }
      
      self.eventHandler?(.pageLoading)
      self.state = .loading(task)
    }
  }
  
  func loadNextPage(nextFrom: Int64?) async throws -> AccountEvents {
    let events = try await loader.loadEvents(
      wallet: wallet,
      beforeLt: nextFrom,
      limit: .limit
    )
    try Task.checkCancellation()
    await handleEventsWithNFTs(events: events.events)
    if events.events.isEmpty && events.nextFrom != 0 {
      return try await loadNextPage(nextFrom: events.nextFrom)
    }
    return events
  }
  
  func handleEventsWithNFTs(events: [AccountEvent]) async {
      let actions = events.flatMap { $0.actions }
      var nftAddressesToLoad = Set<Address>()
      for action in actions {
        switch action.type {
        case .nftItemTransfer(let nftItemTransfer):
          nftAddressesToLoad.insert(nftItemTransfer.nftAddress)
        case .nftPurchase(let nftPurchase):
          try? nftService.saveNFT(nft: nftPurchase.nft, isTestnet: wallet.isTestnet)
        default: continue
        }
      }
      guard !nftAddressesToLoad.isEmpty else { return }
      _ = try? await nftService.loadNFTs(addresses: Array(nftAddressesToLoad), isTestnet: wallet.isTestnet)
    }
}

private extension Int {
  static let limit: Int = 50
}
