import Foundation
import TKUIKit
import KeeperCore



struct CurrencyPickerItem {
  let identifier: String
  let currencyCode: String
  let currencyTitle: String
}

struct BuySellOperatorItem {
  enum Operation {
    case buy(amount: String)
    case sell(amount: String)
  }
  
  let operation: Operation
  let paymentMethodId: String
  var amount: String {
    switch operation {
    case .buy(let amount), .sell(let amount):
      return amount
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
  var didUpdateCurrencyPickerItem: ((TKUIListItemCell.Configuration) -> Void)? { get set }
  var didUpdateBuySellOperatorItems: (([SelectionCollectionViewCell.Configuration]) -> Void)? { get set }
  
  func viewDidLoad()
  func didSelectOperatorId(_ id: String)
}

final class BuySellOperatorViewModelImplementation: BuySellOperatorViewModel, BuySellOperatorModuleOutput, BuySellOperatorModuleInput {
  
  // MARK: - BuySellOperatorModelModuleOutput
  
  var didTapCurrencyPicker: ((CurrencyListItem) -> Void)?
  var didTapContinue: ((BuySellDetailsItem) -> Void)?
  
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
    
    Task {
      await buySellOperatorController.loadRate(for: currency)
    }
  }
  
  // MARK: - BuySellOperatorModelViewModel
  
  var didUpdateModel: ((BuySellOperatorModel) -> Void)?
  var didUpdateCurrencyPickerItem: ((TKUIListItemCell.Configuration) -> Void)?
  var didUpdateBuySellOperatorItems: (([SelectionCollectionViewCell.Configuration]) -> Void)?
  
  func viewDidLoad() {
    update()
    
    buySellOperatorController.didUpdateFiatOperatorItems = { [weak self] fiatOperatorItems in
      self?.operatorList = fiatOperatorItems
      self?.didUpdateFiatOperatorItems(fiatOperatorItems)
    }
    
    buySellOperatorController.didUpdateActiveCurrency = { [weak self] activeCurrency in
      self?.didChangeCurrency(activeCurrency)
    }
    
    Task {
      await buySellOperatorController.start()
    }
    
//    let buySellDetailsItem = createBuySellDetailsItem()
//    didTapContinue?(buySellDetailsItem)
  }
  
  func didSelectOperatorId(_ id: String) {
    selectedOperatorId = id
  }
  
  // MARK: - State
  
  private var selectedCurrency = Currency.USD
  private var selectedOperatorId = ""
  private var operatorList: [FiatOperator] = []
  
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
      description: "Credit card", // TODO: Get text from BuySellOperationModel
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
    let fiatOperator = operatorList.first(where: { $0.id == selectedOperatorId })!
    
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
  
  func didUpdateFiatOperatorItems(_ items: [FiatOperator]) {
    let buySellOperatorItems = items.map {
      itemMapper.mapFiatOperatorItem($0)
    }
    
    Task { @MainActor in
      didUpdateBuySellOperatorItems?(buySellOperatorItems)
    }
  }
}
