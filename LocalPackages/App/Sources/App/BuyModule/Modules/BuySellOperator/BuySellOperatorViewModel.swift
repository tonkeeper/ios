import Foundation
import TKUIKit
import TKLocalize
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
  var fiatOperatorCategory: FiatOperatorCategory {
    switch self {
    case .buy:
      return .buy
    case .sell:
      return .sell
    }
  }
}

protocol BuySellOperatorModuleOutput: AnyObject {
  var didTapCurrencyPicker: ((CurrencyListItem) -> Void)? { get set }
  var onOpenDetails: ((BuySellDetailsItem) -> Void)? { get set }
  var onOpenProviderUrl: ((URL?) -> Void)? { get set }
}

protocol BuySellOperatorModuleInput: AnyObject {
  func didChangeCurrency(_ currency: Currency)
}

protocol BuySellOperatorViewModel: AnyObject {
  var didUpdateModel: ((BuySellOperatorView.Model) -> Void)? { get set }
  var didLoadListItems: ((TKUIListItemCell.Configuration, [SelectionCollectionViewCell.Configuration]) -> Void)? { get set }
  var didUpdateCurrencyPickerItem: ((TKUIListItemCell.Configuration) -> Void)? { get set }
  var didUpdateFiatOperatorItems: (([SelectionCollectionViewCell.Configuration]) -> Void)? { get set }
  
  func viewDidLoad()
}

final class BuySellOperatorViewModelImplementation: BuySellOperatorViewModel, BuySellOperatorModuleOutput, BuySellOperatorModuleInput {
  
  // MARK: - BuySellOperatorModelModuleOutput
  
  var didTapCurrencyPicker: ((CurrencyListItem) -> Void)?
  var onOpenDetails: ((BuySellDetailsItem) -> Void)?
  var onOpenProviderUrl: ((URL?) -> Void)?
  
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
      await buySellOperatorController.updateFiatOperatorItems(forCurrency: currency)
      await buySellOperatorController.loadRate(for: currency)
    }
  }
  
  // MARK: - BuySellOperatorModelViewModel
  
  var didUpdateModel: ((BuySellOperatorView.Model) -> Void)?
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
      await buySellOperatorController.start()
    }
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
  
  func createModel() -> BuySellOperatorView.Model {
    BuySellOperatorView.Model(
      title: ModalTitleView.Model(
        title: "Operator",
        description: buySellOperatorItem.paymentMethod.title
      ),
      button: BuySellOperatorView.Model.Button(
        title: TKLocales.Actions.continue_action,
        isEnabled: !isResolving && isContinueEnable,
        isActivity: isResolving,
        action: { [weak self] in
          self?.handleContinueButtonTap()
        }
      )
    )
  }
  
  func handleContinueButtonTap() {
    if selectedOperator.canOpenDetailsView() {
      onOpenDetails?(createBuySellDetailsItem())
    } else {
      isResolving = true
      let transaction = createTransaction()
      Task {
        let providerUrl = await buySellOperatorController.createActionUrl(
          actionTemplateURL: selectedOperator.actionTemplateURL,
          operatorId: selectedOperator.id,
          currencyFrom: transaction.currencyPay,
          currencyTo: transaction.currencyGet
        )
        await MainActor.run {
          onOpenProviderUrl?(providerUrl)
          isResolving = false
        }
      }
    }
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
      iconURL: fiatOperator.iconURL,
      actionTemplateURL: fiatOperator.actionTemplateURL,
      serviceTitle: fiatOperator.title,
      serviceSubtitle: fiatOperator.description,
      serviceInfo: .init(
        id: fiatOperator.id,
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
    rate: .zero,
    formattedRate: "",
    badge: nil,
    iconURL: nil,
    actionTemplateURL: nil,
    infoButtons: []
  )
}
