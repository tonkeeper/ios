import Foundation
import TKUIKit
import KeeperCore

struct CurrencyPickerItem {
  let identifier: String
  let currencyNameShort: String
  let currencyNameFull: String
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
  var didTapCurrencyPicker: (() -> Void)? { get set }
  var didTapContinue: (() -> Void)? { get set }
}

protocol FiatOperatorModuleInput: AnyObject {
  func didChangeCurrency(_ currency: Currency)
}

protocol FiatOperatorViewModel: AnyObject {
  var didUpdateModel: ((FiatOperatorModel) -> Void)? { get set }
  var didUpdateCurrencyPickerItem: ((TKUIListItemCell.Configuration) -> Void)? { get set }
  var didUpdateFiatOperatorItems: (([RadioButtonCollectionViewCell.Configuration]) -> Void)? { get set }
  
  func viewDidLoad()
  func didSelectFiatOperatorId(_ id: String)
}

final class FiatOperatorViewModelImplementation: FiatOperatorViewModel, FiatOperatorModuleOutput, FiatOperatorModuleInput {
  
  // MARK: - FiatOperatorModelModuleOutput
  
  var didTapCurrencyPicker: (() -> Void)?
  var didTapContinue: (() -> Void)?
  
  // MARK: - FiatOperatorModelModuleInput
  
  func didChangeCurrency(_ currency: Currency) {
    let currencyPickerItem = listItemMapper.mapCurrencyPickerItem(
      .init(
        identifier: "currencyPicker",
        currencyNameShort: currency.code,
        currencyNameFull: currency.title
      ),
      selectionClosure: { [weak self] in
        self?.didTapCurrencyPicker?()
      }
    )
    
    didUpdateCurrencyPickerItem?(currencyPickerItem)
  }
  
  // MARK: - FiatOperatorModelViewModel
  
  var didUpdateModel: ((FiatOperatorModel) -> Void)?
  var didUpdateCurrencyPickerItem: ((TKUIListItemCell.Configuration) -> Void)?
  var didUpdateFiatOperatorItems: (([RadioButtonCollectionViewCell.Configuration]) -> Void)?
  
  func viewDidLoad() {
    update()
    didChangeCurrency(Currency.USD)
    
    fiatOperatorController.didUpdateFiatOperatorModel = { [weak self] fiatOperatorModel in
      self?.didUpdateFiatOperatorModel(fiatOperatorModel)
    }
    
    Task {
      await fiatOperatorController.start()
    }
  }
  
  func didSelectFiatOperatorId(_ id: String) {
    selectedFiatOperatorId = id
  }
  
  // MARK: - State
  
  private var currency = Currency.USD
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
