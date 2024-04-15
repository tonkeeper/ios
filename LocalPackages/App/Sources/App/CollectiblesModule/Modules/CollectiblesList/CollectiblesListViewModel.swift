import Foundation
import TKUIKit
import KeeperCore
import TonSwift

protocol CollectiblesListModuleOutput: AnyObject {
  var didSelectNFT: ((NFT) -> Void)? { get set }
}

protocol CollectiblesListViewModel: AnyObject {
  var didRestartList: (() -> Void)? { get set }
  var didLoadNFTs: (([CollectibleCollectionViewCell.Model]) -> Void)? { get set }
  
  func viewDidLoad()
  func loadNext()
  func didSelectNftAt(index: Int)
}

final class CollectiblesListViewModelImplementation: CollectiblesListViewModel, CollectiblesListModuleOutput {
  
  // MARK: - CollectiblesListModuleOutput
  
  var didSelectNFT: ((NFT) -> Void)?
  
  // MARK: - CollectiblesListViewModel
  
  var didRestartList: (() -> Void)?
  var didLoadNFTs: (([CollectibleCollectionViewCell.Model]) -> Void)?
  
  func viewDidLoad() {
    Task {
      collectiblesListController.setDidGetEventHandler({ [weak self] event in
        switch event {
        case .cached(let nfts):
          self?.didGetCachedNFTs(nfts)
        case .loaded(let nfts):
          self?.didLoadedNfts(nfts)
        case .nextPage(let nfts):
          self?.didLoadedNextPage(nfts)
        default:
          break
        }
      })
      await collectiblesListController.start()
    }
  }
  
  func loadNext() {
    Task {
     await collectiblesListController.loadNext()
    }
  }
  
  func didSelectNftAt(index: Int) {
    Task {
      let nft = await collectiblesListController.nftAt(index: index)
      await MainActor.run {
        didSelectNFT?(nft)
      }
    }
  }
  
  // MARK: - Mapper
  
  private let collectiblesListMapper = CollectiblesListMapper()
  
  // MARK: - Dependencies
  
  private let collectiblesListController: CollectiblesListController
  
  // MARK: - Init
  
  init(collectiblesListController: CollectiblesListController) {
    self.collectiblesListController = collectiblesListController
  }
}

private extension CollectiblesListViewModelImplementation {
  func didGetCachedNFTs(_ nfts: [NFT]) {
    let models = collectiblesListMapper.map(nfts: nfts)
    Task { @MainActor in
      didRestartList?()
      didLoadNFTs?(models)
    }
  }
  
  func didLoadedNfts(_ nfts: [NFT]) {
    let models = collectiblesListMapper.map(nfts: nfts)
    Task { @MainActor in
      didRestartList?()
      didLoadNFTs?(models)
    }
  }
  
  func didLoadedNextPage(_ nfts: [NFT]) {
    let models = collectiblesListMapper.map(nfts: nfts)
    Task { @MainActor in
      didLoadNFTs?(models)
    }
  }
}
