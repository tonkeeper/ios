import Foundation
import TKUIKit
import KeeperCore
import TonSwift

protocol CollectiblesListModuleOutput: AnyObject {
  var didSelectNFT: ((Address) -> Void)? { get set }
}

protocol CollectiblesListViewModel: AnyObject {
  var didUpdateSections: (([CollectiblesListSection]) -> Void)? { get set }
  
  func viewDidLoad()
  func loadNext()
  func didSelectNftAt(index: Int)
}

final class CollectiblesListViewModelImplementation: CollectiblesListViewModel, CollectiblesListModuleOutput {
  
  // MARK: - CollectiblesListModuleOutput
  
  var didSelectNFT: ((Address) -> Void)?
  
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
  
  func didSelectNftAt(index: Int) {
    Task {
      let model = await collectiblesListController.modelAt(index: index)
      await MainActor.run(body: {
        didSelectNFT?(model.address)
      })
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
  func handleUpdatedNFTs(nfts: [NFTModel]) {
    let models = collectiblesListMapper.map(nftModels: nfts)
    let section = CollectiblesListSection.collectibles(items: models)
    Task { @MainActor in
      didUpdateSections?([section])
    }
  }
}
