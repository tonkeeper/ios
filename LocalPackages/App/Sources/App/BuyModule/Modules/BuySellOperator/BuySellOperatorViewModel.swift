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
  struct PaymentMethod {
    let id: String
    let title: String
  }
  
  let buySellModel: BuySellModel
  let buySellItem: BuySellItem
  let paymentMethod: PaymentMethod
  let countryCode: String?
  
  var operation: BuySellModel.Operation {
    buySellModel.operation
  }
}

extension BuySellModel.Operation {
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
  var onOpenDetails: ((BuySellDetailsItem, BuySellTransactionModel) -> Void)? { get set }
  var onOpenProviderUrl: ((TitledURL?) -> Void)? { get set }
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
  var onOpenDetails: ((BuySellDetailsItem, BuySellTransactionModel) -> Void)?
  var onOpenProviderUrl: ((TitledURL?) -> Void)?
  
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
    let buySellTransactionModel = createBuySellTransaction()
    if selectedOperator.canOpenDetailsView() {
      let buySellDetailsItem = createBuySellDetailsItem()
      onOpenDetails?(buySellDetailsItem, buySellTransactionModel)
    } else {
      isResolving = true
      Task {
        let url = await buySellOperatorController.createActionUrl(
          actionTemplateURL: selectedOperator.actionTemplateURL,
          operatorId: selectedOperator.id,
          currencyFrom: buySellTransactionModel.itemSell.currencyCode,
          currencyTo: buySellTransactionModel.itemBuy.currencyCode
        )
        let providerUrl = TitledURL(title: selectedOperator.title, url: url)
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
      )
    )
  }
  
  func createBuySellTransaction() -> BuySellTransactionModel {
    let minimumLimits: BuySellTransactionModel.MinimumLimits
    let minTonBuyAmount = selectedOperator.minTonBuyAmount
    let minTonSellAmount = selectedOperator.minTonSellAmount
    if let minTonBuyAmount, let minTonSellAmount {
      minimumLimits = .amount(buy: minTonBuyAmount, sell: minTonSellAmount)
    } else {
      minimumLimits = .none
    }
    
    var buySellItem = buySellOperatorItem.buySellItem
    buySellItem.fiatItem.currency = selectedCurrency
    
    return BuySellTransactionModel(
      operation: buySellOperatorItem.buySellModel.operation,
      buySellItem: buySellItem,
      providerRate: selectedOperator.rate,
      minimumLimits: minimumLimits
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
    badge: nil,
    iconURL: nil,
    actionTemplateURL: nil,
    infoButtons: [],
    rate: .zero,
    formattedRate: "",
    minTonBuyAmount: nil,
    minTonSellAmount: nil
  )
}
