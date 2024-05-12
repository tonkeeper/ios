import Foundation
import TKUIKit
import KeeperCore

struct CurrencyListItem {
  var selected: Currency
}

struct CurrencyListModel {
  let title: String
}

public struct CurrencyListItemsModel {
  public let currencyListItems: [Item]
  
  public init(currencyListItems: [Item]) {
    self.currencyListItems = currencyListItems
  }
}

public extension CurrencyListItemsModel {
  struct Item {
    public let identifier: String
    public let currency: Currency
  }
}

protocol CurrencyListModuleOutput: AnyObject {
  var didChangeCurrency: ((Currency) -> Void)? { get set }
}

protocol CurrencyListViewModel: AnyObject {
  var didUpdateModel: ((CurrencyListModel) -> Void)? { get set }
  var didUpdateCurrencyListItems: (([SelectionCollectionViewCell.Configuration], String) -> Void)? { get set }
  
  func viewDidLoad()
  func didSelectCurrency(_ currency: Currency)
}

final class CurrencyListViewModelImplementation: CurrencyListViewModel, CurrencyListModuleOutput {
  
  // MARK: - CurrencyListModuleOutput
  
  var didChangeCurrency: ((Currency) -> Void)?
  
  // MARK: - CurrencyListViewModel
  
  var didUpdateModel: ((CurrencyListModel) -> Void)?
  var didUpdateCurrencyListItems: (([SelectionCollectionViewCell.Configuration], String) -> Void)?
  
  func viewDidLoad() {
    update()
    
    currencyListController.didUpdateCurrencyList = { [weak self] currencyList in
      let currencyListItems = currencyList.map({ CurrencyListItemsModel.Item(identifier: $0.code, currency: $0) })
      let currencyListItemsModel = CurrencyListItemsModel(currencyListItems: currencyListItems)
      self?.didUpdateCurrencyListItemsModel(currencyListItemsModel)
    }
    
    currencyListController.start()
  }
  
  func didSelectCurrency(_ currency: Currency) {
    guard currency != currencyListItem.selected else { return }
    currencyListItem.selected = currency
    didChangeCurrency?(currency)
  }
  
  // MARK: - Mapper
  
  private let listItemMapper = CurrencyListItemMapper()
  
  // MARK: - Dependencies
  
  private let currencyListController: CurrencyListController
  private var currencyListItem: CurrencyListItem
  
  // MARK: - Init
  
  init(currencyListController: CurrencyListController, currencyListItem: CurrencyListItem) {
    self.currencyListController = currencyListController
    self.currencyListItem = currencyListItem
  }
  
  deinit {
    print("\(Self.self) deinit")
  }
}

// MARK: - Private

private extension CurrencyListViewModelImplementation {
  func update() {
    let model = createModel()
    didUpdateModel?(model)
  }
  
  func createModel() -> CurrencyListModel {
    CurrencyListModel(
      title: "Currency"
    )
  }
  
  func didUpdateCurrencyListItemsModel(_ model: CurrencyListItemsModel) {
    let currencyListItems = model.currencyListItems.map { item in
      listItemMapper.mapCurrencyListItem(item) { [weak self] in
        self?.didSelectCurrency(item.currency)
      }
    }
    
    Task { @MainActor in
      didUpdateCurrencyListItems?(currencyListItems, currencyListItem.selected.code)
    }
  }
}
