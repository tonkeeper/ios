import UIKit
import KeeperCore
import TKCore
import TKUIKit
import TKLocalize
import BigInt

enum OperatorSelectionSection: Hashable {
  case currency
  case items([AnyHashable])
}

protocol OperatorSelectionViewModelOutput: AnyObject {
  var didTapCurrency: (() -> Void)? { get set }
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
  
  private let settingsController: SettingsController
  private let buyListController: BuyListController
  private let decimalAmountFormatter: DecimalAmountFormatter
  private let currencyStore: CurrencyStore
  
  private var operators: [Operator] = []
  private var selectedOperatorId: String? {
    didSet {
      didUpdateSelection?(selectedOperatorId != nil)
    }
  }
  
  init(
    settingsController: SettingsController,
    buyListController: BuyListController,
    currencyStore: CurrencyStore,
    decimalAmountFormatter: DecimalAmountFormatter
  ) {
    self.settingsController = settingsController
    self.buyListController = buyListController
    self.currencyStore = currencyStore
    self.decimalAmountFormatter = decimalAmountFormatter
  }
  
  func viewDidLoad() {
    loadOperators()
    
    // TODO: setup loading snapshot?
  }
  
  func didTapContinueButton() {
    print("HIHI")
  }
  
  private func loadOperators() {
    Task {
      await startObservations()
      let currency = await settingsController.activeCurrency()
      let operators = await buyListController.fetchOperators(mode: .buy, currency: currency)
      await MainActor.run {
        self.operators = operators
        update(currency: currency, operators: operators)
      }
    }
  }
  
  private func startObservations() async {
    _ = await currencyStore.addEventObserver(self) { [weak self] observer, event in
      switch event {
      case .didChangeCurrency(let currency):
        self?.didUpdateCurrency(currency)
        self?.loadOperators()
      }
    }
  }
  
  private func didUpdateCurrency(_ currency: Currency) {
    update(currency: currency, operators: nil)
  }
  
  private func update(currency: Currency, operators: [Operator]?) {
    snapshot.deleteAllItems()
    
    snapshot.appendSections([.currency])
    snapshot.appendItems([createCurrencyCell(currency: currency)])
    if let operators {
      let items = operators.map {
        createOperatorCell(model: $0, currency: currency)
      }
      snapshot.appendSections([.items(items)])
      snapshot.appendItems(items)
    }
    
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
  
  private func createOperatorCell(model: Operator, currency: Currency) -> TKUIListItemCell.Configuration {
    
    let iconConfigurationImage: TKUIListItemImageIconView.Configuration.Image = .asyncImage(model.logo, TKCore.ImageDownloadTask(
      closure: {
        [imageLoader] imageView,
        size,
        cornerRadius in
        return imageLoader.loadImage(
          url: model.logo,
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
    
    let title = model.name.withTextStyle(
      .label1,
      color: .Text.primary,
      alignment: .left,
      lineBreakMode: .byTruncatingTail
    )
    
    let rate = decimalAmountFormatter.format(amount: model.rate, maximumFractionDigits: 4)
    
    let description = "\(rate) \(currency.rawValue) for 1 TON".withTextStyle(
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
        
        selectedOperatorId = model.id
      }
    )
  }
  
  // MARK: - State
  
  private var snapshot = NSDiffableDataSourceSnapshot<OperatorSelectionSection, AnyHashable>()
  
  // MARK: - Image Loader
  
  private let imageLoader = ImageLoader()
  
}
