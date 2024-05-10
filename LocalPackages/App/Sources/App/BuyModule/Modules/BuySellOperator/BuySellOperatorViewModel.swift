import Foundation
import TKUIKit
import KeeperCore

struct CurrencyPickerItem {
  let identifier: String
  let currencyCode: String
  let currencyTitle: String
}

struct BuySellOperatorModel {
  struct Button {
    let title: String
    let isEnabled: Bool
    let isActivity: Bool
    let action: (() -> Void)
  }
  
  let title: String
  let description: String
  let button: Button
}

protocol BuySellOperatorModuleOutput: AnyObject {
  var didTapCurrencyPicker: ((CurrencyListItem) -> Void)? { get set }
  var didTapContinue: (() -> Void)? { get set }
}

protocol BuySellOperatorModuleInput: AnyObject {
  func didChangeCurrency(_ currency: Currency)
}

protocol BuySellOperatorViewModel: AnyObject {
  var didUpdateModel: ((BuySellOperatorModel) -> Void)? { get set }
  var didUpdateCurrencyPickerItem: ((TKUIListItemCell.Configuration) -> Void)? { get set }
  var didUpdateBuySellOperatorItems: (([SelectionCollectionViewCell.Configuration]) -> Void)? { get set }
  
  func viewDidLoad()
  func didSelectOperatorId(_ id: String)
}

final class BuySellOperatorViewModelImplementation: BuySellOperatorViewModel, BuySellOperatorModuleOutput, BuySellOperatorModuleInput {
  
  // MARK: - BuySellOperatorModelModuleOutput
  
  var didTapCurrencyPicker: ((CurrencyListItem) -> Void)?
  var didTapContinue: (() -> Void)?
  
  // MARK: - BuySellOperatorModelModuleInput
  
  func didChangeCurrency(_ currency: Currency) {
    selectedCurrency = currency
    
    let currencyPickerItem = itemMapper.mapCurrencyPickerItem(
      .init(
        identifier: "currencyPicker",
        currencyCode: currency.code,
        currencyTitle: currency.title
      ),
      selectionClosure: { [weak self] in
        let currencyListItem = CurrencyListItem(selected: currency)
        self?.didTapCurrencyPicker?(currencyListItem)
      }
    )
    
    didUpdateCurrencyPickerItem?(currencyPickerItem)
  }
  
  // MARK: - BuySellOperatorModelViewModel
  
  var didUpdateModel: ((BuySellOperatorModel) -> Void)?
  var didUpdateCurrencyPickerItem: ((TKUIListItemCell.Configuration) -> Void)?
  var didUpdateBuySellOperatorItems: (([SelectionCollectionViewCell.Configuration]) -> Void)?
  
  func viewDidLoad() {
    update()
    
    buySellOperatorController.didUpdateBuySellOperatorItemsModel = { [weak self] buySellOperatorItemsModel in
      self?.didUpdateBuySellOperatorItemsModel(buySellOperatorItemsModel)
    }
    
    buySellOperatorController.didUpdateActiveCurrency = { [weak self] activeCurrency in
      self?.didChangeCurrency(activeCurrency)
    }
    
    Task {
      await buySellOperatorController.start()
    }
  }
  
  func didSelectOperatorId(_ id: String) {
    selectedOperatorId = id
  }
  
  // MARK: - State
  
  private var selectedCurrency = Currency.USD
  private var selectedOperatorId = ""
  
  private var isResolving = false {
    didSet {
      guard isResolving != oldValue else { return }
      update()
    }
  }
  
  private var isContinueEnable: Bool {
    true
  }
  
  // MARK: - Mapper
  
  private let itemMapper = BuySellOperatorItemMapper()
  
  // MARK: - Dependencies
  
  private let buySellOperatorController: BuySellOperatorController
  private var buySellOperation: BuySellOperationModel
  
  // MARK: - Init
  
  init(buySellOperatorController: BuySellOperatorController, buySellOperation: BuySellOperationModel) {
    self.buySellOperatorController = buySellOperatorController
    self.buySellOperation = buySellOperation
  }
  
  deinit {
    print("\(Self.self) deinit")
  }
}

// MARK: - Private

private extension BuySellOperatorViewModelImplementation {
  func update() {
    let model = createModel()
    didUpdateModel?(model)
  }
  
  func createModel() -> BuySellOperatorModel {
    BuySellOperatorModel(
      title: "Operator",
      description: "Credit card", // TODO: Get text from BuySellOperationModel
      button: .init(
        title: "Continue",
        isEnabled: !isResolving && isContinueEnable,
        isActivity: isResolving,
        action: { [weak self] in
          self?.didTapContinue?()
        }
      )
    )
  }
  
  func didUpdateBuySellOperatorItemsModel(_ model: BuySellOperatorItemsModel) {
    let buySellOperatorItems = model.items.map {
      itemMapper.mapBuySellOperatorItem($0)
    }
    
    Task { @MainActor in
      didUpdateBuySellOperatorItems?(buySellOperatorItems)
    }
  }
}
