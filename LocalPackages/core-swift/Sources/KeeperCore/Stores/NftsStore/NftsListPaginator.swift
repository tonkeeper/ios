import Foundation
import TonSwift

actor NftsListPaginator {
  enum State {
    case idle
    case isLoading
  }
  
  var eventHandler: ((PaginationEvent<NFT>) -> Void)?
  func setEventHandler(_ eventHandler: @escaping ((PaginationEvent<NFT>) -> Void)) { self.eventHandler = eventHandler }
  
  // MARK: - State
  
  private let limit = 25
  private var offset: Int = 0
  private var hasMore = true
  private var state: State = .idle
  
  private(set) var nfts = [NFT]()
  
  // MARK: - Dependencies
  
  private let wallet: Wallet
  private let accountNftsService: AccountNFTService
  
  // MARK: - Init
  
  init(wallet: Wallet,
       accountNftsService: AccountNFTService) {
    self.wallet = wallet
    self.accountNftsService = accountNftsService
  }
  
  // MARK: - Logic
  
  func start() async {
    state = .isLoading
    offset = 0
    nfts = []
    let cached = accountNftsService.getAccountNfts(wallet: wallet)
    if !cached.isEmpty {
      eventHandler?(.cached(cached))
      self.nfts = cached
    } else {
      eventHandler?(.loading)
    }
    
    do {
      let nfts = try await loadAll()
      if nfts.isEmpty {
        eventHandler?(.empty)
      } else {
        eventHandler?(.loaded(nfts))
      }
      self.nfts = nfts
    } catch {
      nfts = []
      eventHandler?(.empty)
    }
    state = .idle
  }
  
  func loadNext() async {
    switch state {
    case .idle:
      guard hasMore else { return }
      state = .isLoading
      eventHandler?(.pageLoading)
      do {
        let nfts = try await loadNextPage()
        eventHandler?(.nextPage(nfts))
        self.nfts.append(contentsOf: nfts)
      } catch {
        eventHandler?(.pageLoadingFailed)
      }
      state = .idle
    case .isLoading:
      return
    }
  }
}

private extension NftsListPaginator {
  private func loadAll() async throws -> [NFT] {
    let nfts = try await accountNftsService.loadAccountNFTs(
      wallet: wallet,
      collectionAddress: nil,
      limit: nil,
      offset: nil,
      isIndirectOwnership: true
    )
    try Task.checkCancellation()
    hasMore = false
    return nfts
  }
  
  private func loadNextPage() async throws -> [NFT] {
    let nfts = try await accountNftsService.loadAccountNFTs(
      wallet: wallet,
      collectionAddress: nil,
      limit: nil,
      offset: nil,
      isIndirectOwnership: true
    )
    try Task.checkCancellation()
    if nfts.count > limit {
      hasMore = false
    }
    offset += limit
    return nfts
  }
}
