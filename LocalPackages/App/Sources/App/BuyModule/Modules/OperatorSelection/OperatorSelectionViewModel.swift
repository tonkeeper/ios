import UIKit
import KeeperCore
import TKCore
import TKUIKit
import TKLocalize
import BigInt

enum OperatorSelectionSection: Hashable {
  case currency
  case items
}

protocol OperatorSelectionViewModelOutput: AnyObject {
  var didTapCurrency: (() -> Void)? { get set }
  var didContinue: ((BuySellItemModel, TransactionAmountModel, Currency) -> Void)? { get set }
}

protocol OperatorSelectionViewModel: AnyObject {
  var didUpdateSnapshot: ((NSDiffableDataSourceSnapshot<OperatorSelectionSection, AnyHashable>) -> Void)? { get set }
  var didUpdateSelection: ((Bool) -> Void)? { get set }
  var currencyCellId: String { get }
  
  func didTapContinueButton()
  func viewDidLoad()
}

final class OperatorSelectionViewModelImplementation: OperatorSelectionViewModel, OperatorSelectionViewModelOutput {
  
  // MARK: - OperatorSelectionViewModel
  
  var didUpdateSnapshot: ((NSDiffableDataSourceSnapshot<OperatorSelectionSection, AnyHashable>) -> Void)?
  var didUpdateSelection: ((Bool) -> Void)?
  
  let currencyCellId = UUID().uuidString
  
  // MARK: - OperatorSelectionViewModelOutput
  
  var didTapCurrency: (() -> Void)?
  var didContinue: ((BuySellItemModel, TransactionAmountModel, Currency) -> Void)?
  
  private let settingsController: SettingsController
  private let buyListController: BuyListController
  private let currencyRateFormatter: CurrencyToTONFormatter
  private let currencyStore: CurrencyStore
  private let transactionModel: TransactionAmountModel
  
  private var buySellModels: [BuySellItemModel] = []
  private var selectedModelId: String? {
    didSet {
      didUpdateSelection?(selectedModelId != nil)
    }
  }
  
  init(
    settingsController: SettingsController,
    buyListController: BuyListController,
    currencyStore: CurrencyStore,
    currencyRateFormatter: CurrencyToTONFormatter,
    transactionModel: TransactionAmountModel
  ) {
    self.settingsController = settingsController
    self.buyListController = buyListController
    self.currencyStore = currencyStore
    self.currencyRateFormatter = currencyRateFormatter
    self.transactionModel = transactionModel
  }
  
  func viewDidLoad() {
    buyListController.didUpdateMethods = { [weak self] methods in
      self?.didUpdateMethods(methods)
    }
    Task {
      await startObservations()
      let currency = await settingsController.activeCurrency()
      
      await MainActor.run {
        didUpdateCurrency(currency)
      }
    }
    
    // TODO: setup loading snapshot?
  }
  
  func didTapContinueButton() {
    guard
      let selectedModelId,
      let buySellModel = buySellModels.first(where: { $0.id == selectedModelId })
    else {
      return
    }
    didContinue?(buySellModel, transactionModel, buySellModel.currency)
  }
  
  private func didUpdateCurrency(_ currency: Currency) {
    update(currency: currency)
    loadPaymentMethods(currency: currency)
  }
  
  private func didUpdateMethods(_ methods: [BuySellItemModel]) {
    Task { @MainActor in
      buySellModels = methods
      update(models: methods)
    }
  }
  
  private func loadPaymentMethods(currency: Currency) {
    Task {
      await buyListController.loadBuySellMethods(type: transactionModel.type, currency: currency)
    }
  }
  
  private func startObservations() async {
    _ = await currencyStore.addEventObserver(self) { [weak self] observer, event in
      switch event {
      case .didChangeCurrency(let currency):
        self?.didUpdateCurrency(currency)
      }
    }
  }
  
  private func update(currency: Currency) {
    snapshot.deleteAllItems()
    snapshot.appendSections([.currency])
    snapshot.appendItems([createCurrencyCell(currency: currency)])
    didUpdateSnapshot?(snapshot)
  }
  
  private func update(models: [BuySellItemModel]) {
    snapshot.deleteSections([.items])
    snapshot.appendSections([.items])
    let items = models.map {
      createOperatorCell(model: $0)
    }
    snapshot.appendItems(items)
    didUpdateSnapshot?(snapshot)
  }
  
  private func createCurrencyCell(currency: Currency) -> TKUIListItemCell.Configuration {
    let title = NSMutableAttributedString()
    
    let code = "\(currency.code) ".withTextStyle(
      .label1,
      color: .Text.primary,
      alignment: .left,
      lineBreakMode: .byTruncatingTail
    )

    let name = currency.title.withTextStyle(
      .body1,
      color: .Text.secondary,
      alignment: .left,
      lineBreakMode: .byTruncatingTail
    )
    
    title.append(code)
    title.append(name)
    
    let leftItemConfiguration = TKUIListItemContentLeftItem.Configuration(
      title: title,
      tagViewModel: nil,
      subtitle: nil,
      description: nil,
      descriptionNumberOfLines: 0
    )
    
    let listItemConfiguration = TKUIListItemView.Configuration(
      contentConfiguration: TKUIListItemContentView.Configuration(
        leftItemConfiguration: leftItemConfiguration,
        rightItemConfiguration: nil
      ),
      accessoryConfiguration: .image(
        .init(
          image: .TKUIKit.Icons.Size16.switch,
          tintColor: .Text.tertiary,
          padding: .init(top: 0, left: 0, bottom: 0, right: 6)
        )
      )
    )
    
    return TKUIListItemCell.Configuration(
      id: currencyCellId,
      listItemConfiguration: listItemConfiguration,
      selectionClosure: { [weak self] in
        guard let self else { return }
        
        didTapCurrency?()
      }
    )
  }
  
  private func createOperatorCell(model: BuySellItemModel) -> TKUIListItemCell.Configuration {
    
    let iconConfigurationImage: TKUIListItemImageIconView.Configuration.Image = .asyncImage(model.iconURL, TKCore.ImageDownloadTask(
      closure: {
        [imageLoader] imageView,
        size,
        cornerRadius in
        return imageLoader.loadImage(
          url: model.iconURL,
          imageView: imageView,
          size: size,
          cornerRadius: cornerRadius
        )
      }
    ))
    
    let iconConfiguration = TKUIListItemIconView.Configuration(
      iconConfiguration: .image(
        .init(
          image: iconConfigurationImage,
          tintColor: .clear,
          backgroundColor: .clear,
          size: CGSize(width: 44, height: 44),
          cornerRadius: 12
        )
      ),
      alignment: .center
    )
    
    let title = model.title.withTextStyle(
      .label1,
      color: .Text.primary,
      alignment: .left,
      lineBreakMode: .byTruncatingTail
    )
    
    let rate = currencyRateFormatter.format(currency: model.currency, rate: model.rate)
    
    let description = rate.withTextStyle(
      .body2,
      color: .Text.secondary,
      alignment: .left,
      lineBreakMode: .byWordWrapping
    )
    
    let leftItemConfiguration = TKUIListItemContentLeftItem.Configuration(
      title: title,
      tagViewModel: nil,
      subtitle: nil,
      description: description,
      descriptionNumberOfLines: 0
    )
    
    let listItemConfiguration = TKUIListItemView.Configuration(
      iconConfiguration: iconConfiguration,
      contentConfiguration: TKUIListItemContentView.Configuration(
        leftItemConfiguration: leftItemConfiguration,
        rightItemConfiguration: nil
      ),
      accessoryConfiguration: TKUIListItemAccessoryView.Configuration.none
    )
    
    return TKUIListItemCell.Configuration(
      id: model.id,
      listItemConfiguration: listItemConfiguration,
      selectionClosure: { [weak self] in
        guard let self else { return }
        
        selectedModelId = model.id
      }
    )
  }
  
  // MARK: - State
  
  private var snapshot = NSDiffableDataSourceSnapshot<OperatorSelectionSection, AnyHashable>()
  
  // MARK: - Image Loader
  
  private let imageLoader = ImageLoader()
  
}
