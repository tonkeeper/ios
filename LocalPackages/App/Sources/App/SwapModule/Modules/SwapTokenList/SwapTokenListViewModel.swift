import UIKit
import TKUIKit
import KeeperCore

struct SwapTokenListModel {
  struct Button {
    let title: String
    let action: (() -> Void)?
  }
  
  let title: String
  let closeButton: Button
}

protocol SwapTokenListModuleOutput: AnyObject {
  var didTapCloseButton: (() -> Void)? { get set }
  var didChooseToken: (() -> Void)? { get set }
}

protocol SwapTokenListModuleInput: AnyObject {
  
}

protocol SwapTokenListViewModel: AnyObject {
  var didUpdateModel: ((SwapTokenListModel) -> Void)? { get set }
  var didUpdateListItems: (([SuggestedTokenCell.Configuration], [TKUIListItemCell.Configuration]) -> Void)? { get set }
  var amountInpuTextFieldFormatter: BuySellAmountTextFieldFormatter { get }
  
  func viewDidLoad()
  func didInputSearchText(_ searchText: String)
  func didSelectToken(_ symbol: String)
}

final class SwapTokenListViewModelImplementation: SwapTokenListViewModel, SwapTokenListModuleOutput, SwapTokenListModuleInput {

  // MARK: - SwapTokenListModuleOutput
  
  var didTapCloseButton: (() -> Void)?
  var didChooseToken: (() -> Void)?
  
  // MARK: - SwapTokenListModuleInput
  
  
  // MARK: - SwapTokenListViewModel
  
  var didUpdateModel: ((SwapTokenListModel) -> Void)?
  var didUpdateListItems: (([SuggestedTokenCell.Configuration], [TKUIListItemCell.Configuration]) -> Void)?
  
  func viewDidLoad() {
    update()
    
    swapTokenListController.didLoadListItems = { [weak self] tokenButtonListItemsModel, tokenListItemsModel in
      guard let self else { return }
      
      let suggestedItems = tokenButtonListItemsModel.items.map { item in
        self.itemMapper.mapTokenButtonListItem(item) {
          self.didSelectToken(item.symbol)
        }
      }
      
      let otherItems = tokenListItemsModel.items.map { item in
        self.itemMapper.mapTokenListItem(item) {
          self.didSelectToken(item.symbol)
        }
      }
      
      self.didUpdateListItems?(suggestedItems, otherItems)
    }
    
    Task {
      await swapTokenListController.start()
    }
  }
  
  func didInputSearchText(_ searchText: String) {
    print(searchText)
  }
  
  func didSelectToken(_ symbol: String) {
    print(symbol)
  }
  
  // MARK: - State
  
  private var isResolving = false {
    didSet {
      guard isResolving != oldValue else { return }
      update()
    }
  }
  
  // MARK: - Formatter
  
  let amountInpuTextFieldFormatter: BuySellAmountTextFieldFormatter = .makeAmountFormatter()
  
  // MARK: - Mapper
  
  private let itemMapper = SwapTokenListItemMapper()
  
  // MARK: - Dependencies
  
  private let swapTokenListController: SwapTokenListController
  
  // MARK: - Init
  
  init(swapTokenListController: SwapTokenListController) {
    self.swapTokenListController = swapTokenListController
    self.amountInpuTextFieldFormatter.maximumFractionDigits = TonInfo.fractionDigits
  }
  
  deinit {
    print("\(Self.self) deinit")
  }
}

// MARK: - Private

private extension SwapTokenListViewModelImplementation {
  func update() {
    let model = createModel()
    didUpdateModel?(model)
  }
  
  func createModel() -> SwapTokenListModel {
    SwapTokenListModel(
      title: "Choose Token",
      closeButton: SwapTokenListModel.Button(
        title: "Close",
        action: { [weak self] in
          self?.didTapCloseButton?()
        }
      )
    )
  }
}

private extension BuySellAmountTextFieldFormatter {
  static func makeAmountFormatter() -> BuySellAmountTextFieldFormatter {
    let numberFormatter = NumberFormatter()
    numberFormatter.groupingSize = 3
    numberFormatter.usesGroupingSeparator = true
    numberFormatter.groupingSeparator = " "
    numberFormatter.decimalSeparator = Locale.current.decimalSeparator
    numberFormatter.maximumIntegerDigits = 16
    numberFormatter.roundingMode = .down
    return BuySellAmountTextFieldFormatter(
      currencyFormatter: numberFormatter
    )
  }
}
