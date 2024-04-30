import Foundation
import TonSwift

public final class CollectiblesListController {
  actor State {
    var nfts = [NFT]()
    
    func setNfts(_ nfts: [NFT]) {
      self.nfts = nfts
    }
  }
  
  
  public enum Event {
    case updateNFTs(nfts: [NFT])
  }
  
  public var didGetEvent: ((PaginationEvent<NFT>) -> Void)?
  
  // MARK: - State
  
  private var state = State()
  
  // MARK: - Dependencies
  
  private let wallet: Wallet
  private let nftsListPaginator: NftsListPaginator
  private let nftsStore: NftsStore

  // MARK: - Init
  
  init(wallet: Wallet,
       nftsListPaginator: NftsListPaginator,
       nftsStore: NftsStore) {
    self.wallet = wallet
    self.nftsListPaginator = nftsListPaginator
    self.nftsStore = nftsStore
  }
  
  // MARK: - Logic
  
  public func start() async {
    _ = await nftsStore.addEventObserver(self) { observer, event in
      switch event {
      case .nftsUpdate(let nfts, let walletAddress):
        guard let address = try? observer.wallet.address, walletAddress == address else { return }
        Task { 
          await observer.state.setNfts(nfts)
          observer.didGetEvent?(.loaded(nfts))
        }
      }
    }
    
    guard let nfts = try? await nftsStore.getNfts(walletAddress: wallet.address) else {
      didGetEvent?(.empty)
      return
    }
    
    await state.setNfts(nfts)
    didGetEvent?(.loaded(nfts))
  }
  
  public func loadNext() async {}
  
  public func setDidGetEventHandler(_ handler: ((PaginationEvent<NFT>) -> Void)?) {
    self.didGetEvent = handler
  }
  
  public func nftAt(index: Int) async -> NFT {
    await state.nfts[index]
  }
}

private extension CollectiblesListController {
  func handleUpdatedNfts(_ nfts: [NFT]) {
  }
}
