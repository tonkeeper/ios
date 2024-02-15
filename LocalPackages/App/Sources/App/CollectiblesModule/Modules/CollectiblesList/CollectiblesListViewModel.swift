import Foundation
import TKUIKit
import KeeperCore

protocol CollectiblesListModuleOutput: AnyObject {
  
}

protocol CollectiblesListViewModel: AnyObject {
  var didUpdateSections: (([CollectiblesListSection]) -> Void)? { get set }
  
  func viewDidLoad()
  func loadNext()
}

final class CollectiblesListViewModelImplementation: CollectiblesListViewModel, CollectiblesListModuleOutput {
  
  // MARK: - CollectiblesListModuleOutput
  
  // MARK: - CollectiblesListViewModel
  
  var didUpdateSections: (([CollectiblesListSection]) -> Void)?
  
  func viewDidLoad() {
    Task {
      let handler: (CollectiblesListController.Event) -> Void = { [weak self] event in
        guard let self = self else { return }
        switch event {
        case .updateNFTs(let nfts):
          self.handleUpdatedNFTs(nfts: nfts)
        }
      }
      await collectiblesListController.setDidSendEventHandler(handler)
      await collectiblesListController.start()
    }
  }
  
  func loadNext() {
    Task {
     await collectiblesListController.loadNext()
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
  func handleUpdatedNFTs(nfts: [CollectiblesListController.NFTModel]) {
    let models = collectiblesListMapper.map(nftModels: nfts)
    let section = CollectiblesListSection.collectibles(items: models)
    Task { @MainActor in
      didUpdateSections?([section])
    }
  }
}
