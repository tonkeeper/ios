import Foundation
import TKUIKit
import KeeperCore

struct CurrencyPickerItem {
  let identifier: String
  let currencyCode: String
  let currencyTitle: String
}

struct FiatOperatorModel {
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

protocol FiatOperatorModuleOutput: AnyObject {
  var didTapCurrencyPicker: ((CurrencyListItem) -> Void)? { get set }
  var didTapContinue: (() -> Void)? { get set }
}

protocol FiatOperatorModuleInput: AnyObject {
  func didChangeCurrency(_ currency: Currency)
}

protocol FiatOperatorViewModel: AnyObject {
  var didUpdateModel: ((FiatOperatorModel) -> Void)? { get set }
  var didUpdateCurrencyPickerItem: ((TKUIListItemCell.Configuration) -> Void)? { get set }
  var didUpdateFiatOperatorItems: (([SelectionCollectionViewCell.Configuration]) -> Void)? { get set }
  
  func viewDidLoad()
  func didSelectFiatOperatorId(_ id: String)
}

final class FiatOperatorViewModelImplementation: FiatOperatorViewModel, FiatOperatorModuleOutput, FiatOperatorModuleInput {
  
  // MARK: - FiatOperatorModelModuleOutput
  
  var didTapCurrencyPicker: ((CurrencyListItem) -> Void)?
  var didTapContinue: (() -> Void)?
  
  // MARK: - FiatOperatorModelModuleInput
  
  func didChangeCurrency(_ currency: Currency) {
    selectedCurrency = currency
    
    let currencyPickerItem = listItemMapper.mapCurrencyPickerItem(
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
  
  // MARK: - FiatOperatorModelViewModel
  
  var didUpdateModel: ((FiatOperatorModel) -> Void)?
  var didUpdateCurrencyPickerItem: ((TKUIListItemCell.Configuration) -> Void)?
  var didUpdateFiatOperatorItems: (([SelectionCollectionViewCell.Configuration]) -> Void)?
  
  func viewDidLoad() {
    update()
    
    fiatOperatorController.didUpdateFiatOperatorModel = { [weak self] fiatOperatorModel in
      self?.didUpdateFiatOperatorModel(fiatOperatorModel)
    }
    
    fiatOperatorController.didUpdateActiveCurrency = { [weak self] activeCurrency in
      self?.didChangeCurrency(activeCurrency)
    }
    
    Task {
      await fiatOperatorController.start()
    }
  }
  
  func didSelectFiatOperatorId(_ id: String) {
    selectedFiatOperatorId = id
  }
  
  // MARK: - State
  
  private var selectedCurrency = Currency.USD
  private var selectedFiatOperatorId = ""
  
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
  
  private let listItemMapper = FiatOperatorListItemMapper()
  
  // MARK: - Dependencies
  
  private let fiatOperatorController: FiatOperatorController
  private var buySellOperation: BuySellOperationModel
  
  // MARK: - Init
  
  init(fiatOperatorController: FiatOperatorController, buySellOperation: BuySellOperationModel) {
    self.fiatOperatorController = fiatOperatorController
    self.buySellOperation = buySellOperation
  }
  
  deinit {
    print("\(Self.self) deinit")
  }
}

// MARK: - Private

private extension FiatOperatorViewModelImplementation {
  func update() {
    let model = createModel()
    didUpdateModel?(model)
  }
  
  func createModel() -> FiatOperatorModel {
    FiatOperatorModel(
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
  
  func didUpdateFiatOperatorModel(_ model: FiatOperatorItemsModel) {
    let fiatOperatorItems = model.fiatOperatorItems.map {
      listItemMapper.mapFiatOperatorItem($0)
    }
    
    Task { @MainActor in
      didUpdateFiatOperatorItems?(fiatOperatorItems)
    }
  }
}
