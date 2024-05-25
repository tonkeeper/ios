import UIKit
import TKUIKit
import KeeperCore
import TonSwift

struct SwapTokenListItem {
  var contractAddressForPair: Address?
}

protocol SwapTokenListModuleOutput: AnyObject {
  var didFinish: (() -> Void)? { get set }
  var didChooseToken: ((SwapAsset) -> Void)? { get set }
}

protocol SwapTokenListViewModel: AnyObject {
  var didUpdateModel: ((SwapTokenListView.Model) -> Void)? { get set }
  var didUpdateListItems: (([SuggestedTokenCell.Configuration], [TKUIListItemCell.Configuration]) -> Void)? { get set }
  var didUpdateSearchResultsItems: (([TKUIListItemCell.Configuration]) -> Void)? { get set }
  
  func viewDidLoad()
  func reloadListItems()
  func didInputSearchText(_ searchText: String)
  func didSelectToken(_ asset: SwapAsset)
}

final class SwapTokenListViewModelImplementation: SwapTokenListViewModel, SwapTokenListModuleOutput {

  // MARK: - SwapTokenListModuleOutput
  
  var didFinish: (() -> Void)?
  var didChooseToken: ((SwapAsset) -> Void)?
  
  // MARK: - SwapTokenListViewModel
  
  var didUpdateModel: ((SwapTokenListView.Model) -> Void)?
  var didUpdateListItems: (([SuggestedTokenCell.Configuration], [TKUIListItemCell.Configuration]) -> Void)?
  var didUpdateSearchResultsItems: (([TKUIListItemCell.Configuration]) -> Void)?
  
  func viewDidLoad() {
    update()
    
    swapTokenListController.didUpdateListItems = { [weak self] tokenButtonListItemsModel, tokenListItemsModel in
      guard let self else { return }
      
      let suggestedItems = tokenButtonListItemsModel.items.map { item in
        self.itemMapper.mapTokenButtonListItem(item) {
          self.didSelectToken(item.asset)
        }
      }
      
      let otherItems = tokenListItemsModel.items.map { item in
        self.itemMapper.mapTokenListItem(item) {
          self.didSelectToken(item.asset)
        }
      }
      
      self.didUpdateListItems?(suggestedItems, otherItems)
    }
    
    swapTokenListController.didUpdateSearchResultsItems = { [weak self] tokenListItemsModel in
      guard let self else { return }
      
      let searchResultsItems = tokenListItemsModel.items.map { item in
        self.itemMapper.mapTokenListItem(item) {
          self.didSelectToken(item.asset)
        }
      }
      
      self.didUpdateSearchResultsItems?(searchResultsItems)
    }
    
    Task {
      await swapTokenListController.start(contractAddressForPair: swapTokenListItem.contractAddressForPair)
    }
  }
  
  func reloadListItems() {
    Task {
      await swapTokenListController.updateListItems()
    }
  }
  
  func didInputSearchText(_ searchText: String) {
    swapTokenListController.performSearch(with: searchText)
  }
  
  func didSelectToken(_ asset: SwapAsset) {
    didChooseToken?(asset)
    didFinish?()
  }
  
  // MARK: - Mapper
  
  private let itemMapper = SwapTokenListItemMapper()
  
  // MARK: - Dependencies
  
  private let swapTokenListController: SwapTokenListController
  private let swapTokenListItem: SwapTokenListItem
  
  // MARK: - Init
  
  init(swapTokenListController: SwapTokenListController, swapTokenListItem: SwapTokenListItem) {
    self.swapTokenListController = swapTokenListController
    self.swapTokenListItem = swapTokenListItem
  }
  
  deinit {
    print("\(Self.self) deinit")
  }
}

// MARK: - Private

private extension SwapTokenListViewModelImplementation {
  func update() {
    let model = createModel()
    didUpdateModel?(model)
  }
  
  func createModel() -> SwapTokenListView.Model {
    SwapTokenListView.Model(
      title: ModalTitleView.Model(title: "Choose Token"),
      noSearchResultsTitle: "Your search returned no results".withTextStyle(.body1, color: .Text.secondary),
      closeButton: SwapTokenListView.Model.Button(
        title: "Close",
        action: { [weak self] in
          self?.didFinish?()
        }
      )
    )
  }
}
