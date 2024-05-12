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

    let buySellDetailsItem = createBuySellDetailsItem()
    didTapContinue?(buySellDetailsItem)
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
          guard let self else { return }
          let buySellDetailsItem = createBuySellDetailsItem()
          self.didTapContinue?(buySellDetailsItem)
        }
      )
    )
  }
  
  func createBuySellDetailsItem() -> BuySellDetailsItem {
    BuySellDetailsItem(
      iconUrl: URL(string: "https://tonkeeper.com/assets/mercuryo-icon-new.png")!,
      serviceTitle: "Mercuryo",
      serviceSubtitle: "Instantly buy with a credit card",
      serviceInfo: .init(
        provider: "Mercuryo",
        leftButton: .init(title: "Privacy Policy", url: URL(string: "https://example.com")!),
        rightButton: .init(title: "Terms of Use", url: URL(string: "https://example.com")!)
      ),
      amountPay: "50",
      transaction: createTransaction()
    )
  }
  
  func createTransaction() -> BuySellDetailsItem.Transaction {
    BuySellDetailsItem.Transaction(
      operation: .buyTon(fiatCurrency: .USD)
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
