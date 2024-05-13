import Foundation
import TKUIKit
import KeeperCore

struct CurrencyPickerItem {
  let id: String
  let currencyCode: String
  let currencyTitle: String
}

struct BuySellOperatorItem {
  enum Operation {
    case buy(amount: String)
    case sell(amount: String)
  }
  
  struct PaymentMethod {
    let id: String
    let title: String
  }
  
  let operation: Operation
  let paymentMethod: PaymentMethod
  let countryCode: String?
  var amount: String {
    switch operation {
    case .buy(let amount), .sell(let amount):
      return amount
    }
  }
}

extension BuySellOperatorItem.Operation {
  var buySellOperationType: BuySellOperationType {
    switch self {
    case .buy:
      return .buy
    case .sell:
      return .sell
    }
  }
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
  var didTapContinue: ((BuySellDetailsItem) -> Void)? { get set }
}

protocol BuySellOperatorModuleInput: AnyObject {
  func didChangeCurrency(_ currency: Currency)
}

protocol BuySellOperatorViewModel: AnyObject {
  var didUpdateModel: ((BuySellOperatorModel) -> Void)? { get set }
  var didLoadListItems: ((TKUIListItemCell.Configuration, [SelectionCollectionViewCell.Configuration]) -> Void)? { get set }
  var didUpdateCurrencyPickerItem: ((TKUIListItemCell.Configuration) -> Void)? { get set }
  var didUpdateFiatOperatorItems: (([SelectionCollectionViewCell.Configuration]) -> Void)? { get set }
  
  func viewDidLoad()
}

final class BuySellOperatorViewModelImplementation: BuySellOperatorViewModel, BuySellOperatorModuleOutput, BuySellOperatorModuleInput {
  
  // MARK: - BuySellOperatorModelModuleOutput
  
  var didTapCurrencyPicker: ((CurrencyListItem) -> Void)?
  var didTapContinue: ((BuySellDetailsItem) -> Void)?
  
  // MARK: - BuySellOperatorModelModuleInput
  
  func didChangeCurrency(_ currency: Currency) {
    selectedCurrency = currency
    
    let currencyPickerItem = itemMapper.mapCurrencyPickerItem(
      createCurrencyPickerItem(activeCurrency: currency),
      selectionClosure: { [weak self] in
        let currencyListItem = CurrencyListItem(selected: currency)
        self?.didTapCurrencyPicker?(currencyListItem)
      }
    )
    
    didUpdateCurrencyPickerItem?(currencyPickerItem)
    
    Task {
      await buySellOperatorController.loadRate(for: currency)
    }
  }
  
  // MARK: - BuySellOperatorModelViewModel
  
  var didUpdateModel: ((BuySellOperatorModel) -> Void)?
  var didLoadListItems: ((TKUIListItemCell.Configuration, [SelectionCollectionViewCell.Configuration]) -> Void)?
  var didUpdateCurrencyPickerItem: ((TKUIListItemCell.Configuration) -> Void)?
  var didUpdateFiatOperatorItems: (([SelectionCollectionViewCell.Configuration]) -> Void)?
  
  func viewDidLoad() {
    update()
    
    buySellOperatorController.didLoadListItems = { [weak self] activeCurrency, fiatOperatorItems in
      self?.didLoadListItems(activeCurrency, fiatOperatorItems)
      self?.isResolving = false
    }
    
    buySellOperatorController.didUpdateFiatOperatorItems = { [weak self] fiatOperatorItems in
      self?.didUpdateFiatOperatorItems(fiatOperatorItems)
    }
    
    buySellOperatorController.didUpdateActiveCurrency = { [weak self] activeCurrency in
      self?.didChangeCurrency(activeCurrency)
    }
    
    Task {
      let buySellOperationType = buySellOperatorItem.operation.buySellOperationType
      await buySellOperatorController.start(buySellOperationType: buySellOperationType)
    }
    
//    let buySellDetailsItem = createBuySellDetailsItem()
//    didTapContinue?(buySellDetailsItem)
  }
  
  // MARK: - State
  
  private var selectedCurrency = Currency.USD
  private var selectedOperator: FiatOperator = .emptyItem
  
  private var isResolving = true {
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
  private var buySellOperatorItem: BuySellOperatorItem
  
  // MARK: - Init
  
  init(buySellOperatorController: BuySellOperatorController, buySellOperatorItem: BuySellOperatorItem) {
    self.buySellOperatorController = buySellOperatorController
    self.buySellOperatorItem = buySellOperatorItem
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
      description: buySellOperatorItem.paymentMethod.title,
      button: .init(
        title: "Continue",
        isEnabled: !isResolving && isContinueEnable,
        isActivity: isResolving,
        action: { [weak self] in
          guard let self else { return }
          let buySellDetailsItem = createBuySellDetailsItem()
          self.didTapContinue?(buySellDetailsItem)
        }
      )
    )
  }
  
  func createBuySellDetailsItem() -> BuySellDetailsItem {
    let fiatOperator = selectedOperator
    
    var leftInfoButton: BuySellDetailsItem.ServiceInfo.InfoButton?
    var rightInfoButton: BuySellDetailsItem.ServiceInfo.InfoButton?
    
    if fiatOperator.infoButtons.count > 0 {
      let left = fiatOperator.infoButtons[0]
      leftInfoButton = .init(title: left.title, url: left.url)
    }
    
    if fiatOperator.infoButtons.count > 1 {
      let right = fiatOperator.infoButtons[1]
      rightInfoButton = .init(title: right.title, url: right.url)
    }
    
    return BuySellDetailsItem(
      iconUrl: fiatOperator.iconURL,
      serviceTitle: fiatOperator.title,
      serviceSubtitle: fiatOperator.description,
      serviceInfo: .init(
        provider: fiatOperator.title,
        leftButton: leftInfoButton,
        rightButton: rightInfoButton
      ),
      inputAmount: buySellOperatorItem.amount,
      transaction: createTransaction()
    )
  }
  
  func createTransaction() -> BuySellDetailsItem.Transaction {
    let fiatCurrency = selectedCurrency
    
    let transactionOperation: BuySellDetailsItem.Transaction.Operation
    switch buySellOperatorItem.operation {
    case .buy:
      transactionOperation = .buyTon(fiatCurrency: fiatCurrency)
    case .sell:
      transactionOperation = .sellTon(fiatCurrency: fiatCurrency)
    }

    return BuySellDetailsItem.Transaction(
      operation: transactionOperation
    )
  }
  
  func didLoadListItems(_ activeCurrency: Currency, _ fiatOperatorItems: [FiatOperator]) {
    let currencyPickerItem = itemMapper.mapCurrencyPickerItem(
      createCurrencyPickerItem(activeCurrency: activeCurrency),
      selectionClosure: { [weak self] in
        let currencyListItem = CurrencyListItem(selected: activeCurrency)
        self?.didTapCurrencyPicker?(currencyListItem)
      }
    )
    
    let fiatOperatorItems = fiatOperatorItems.map { fiatOperator in
      itemMapper.mapFiatOperatorItem(fiatOperator) { [weak self] in
        self?.selectedOperator = fiatOperator
      }
    }
    
    Task { @MainActor in
      didLoadListItems?(currencyPickerItem, fiatOperatorItems)
    }
  }
  
  func didUpdateFiatOperatorItems(_ items: [FiatOperator]) {
    let fiatOperatorItems = items.map { fiatOperator in
      itemMapper.mapFiatOperatorItem(fiatOperator) { [weak self] in
        self?.selectedOperator = fiatOperator
      }
    }
    
    Task { @MainActor in
      didUpdateFiatOperatorItems?(fiatOperatorItems)
    }
  }
  
  func createCurrencyPickerItem(activeCurrency: Currency) -> CurrencyPickerItem {
    CurrencyPickerItem(
      id: "currencyPicker",
      currencyCode: activeCurrency.code,
      currencyTitle: activeCurrency.title
    )
  }
}

private extension FiatOperator {
  static let emptyItem = FiatOperator(
    id: "0",
    title: "",
    description: "",
    rate: "",
    badge: nil,
    iconURL: nil,
    actionTemplateURL: nil,
    infoButtons: []
  )
}
