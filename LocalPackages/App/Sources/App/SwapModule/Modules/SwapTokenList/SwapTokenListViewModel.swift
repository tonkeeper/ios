import UIKit
import TKUIKit
import KeeperCore
import TonSwift

struct SwapTokenListModel {
  struct Button {
    let title: String
    let action: (() -> Void)?
  }
  
  let title: String
  let noSearchResultsTitle: String
  let closeButton: Button
}

struct SwapTokenListItem {
  var contractAddressForPair: Address?
}

protocol SwapTokenListModuleOutput: AnyObject {
  var didFinish: (() -> Void)? { get set }
  var didChooseToken: ((SwapAsset) -> Void)? { get set }
}

protocol SwapTokenListModuleInput: AnyObject {
  
}

protocol SwapTokenListViewModel: AnyObject {
  var didUpdateModel: ((SwapTokenListModel) -> Void)? { get set }
  var didUpdateListItems: (([SuggestedTokenCell.Configuration], [TKUIListItemCell.Configuration]) -> Void)? { get set }
  var didUpdateSearchResultsItems: (([TKUIListItemCell.Configuration]) -> Void)? { get set }
  
  func viewDidLoad()
  func reloadListItems()
  func didInputSearchText(_ searchText: String)
  func didSelectToken(_ asset: SwapAsset)
}

final class SwapTokenListViewModelImplementation: SwapTokenListViewModel, SwapTokenListModuleOutput, SwapTokenListModuleInput {

  // MARK: - SwapTokenListModuleOutput
  
  var didFinish: (() -> Void)?
  var didChooseToken: ((SwapAsset) -> Void)?
  
  // MARK: - SwapTokenListModuleInput
  
  // MARK: - SwapTokenListViewModel
  
  var didUpdateModel: ((SwapTokenListModel) -> Void)?
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
  
  // MARK: - State
  
  private var isResolving = false {
    didSet {
      guard isResolving != oldValue else { return }
      update()
    }
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
  
  func createModel() -> SwapTokenListModel {
    SwapTokenListModel(
      title: "Choose Token",
      noSearchResultsTitle: "Your search returned no results",
      closeButton: SwapTokenListModel.Button(
        title: "Close",
        action: { [weak self] in
          self?.didFinish?()
        }
      )
    )
  }
}
