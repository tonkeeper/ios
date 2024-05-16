import UIKit
import TKUIKit
import TKLocalize
import TKCore
import KeeperCore
import BigInt

public struct TokenListItemsModel {
  public let items: [Item]
  
  public init(items: [Item]) {
    self.items = items
  }
}

public extension TokenListItemsModel {
  struct Item {
    enum Image {
      case image(UIImage)
      case asyncImage(URL?)
    }
    
    //let kind: String
    let image: Image
    let symbol: String
    let displayName: String
    let badge: String?
    let balance: String?
    let balanceConverted: String?
  }
}

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
    
    Task {
      await swapTokenListController.start()
    }
    
    let suggestedItems: [SuggestedTokenCell.Configuration] = [
      .init(id: "0", tokenButtonModel: .init(title: "ANON".withTextStyle(.body2, color: .white), icon: .image(.TKCore.Icons.Size44.tonLogo)), selectionClosure: nil),
      .init(id: "1", tokenButtonModel: .init(title: "TON".withTextStyle(.body2, color: .white), icon: .image(.TKCore.Icons.Size44.tonLogo)), selectionClosure: nil),
      .init(id: "2", tokenButtonModel: .init(title: "jUSDT".withTextStyle(.body2, color: .white), icon: .image(.TKCore.Icons.Size44.tonLogo)), selectionClosure: nil),
      .init(id: "3", tokenButtonModel: .init(title: "GRAM".withTextStyle(.body2, color: .white), icon: .image(.TKCore.Icons.Size44.tonLogo)), selectionClosure: nil),
      .init(id: "4", tokenButtonModel: .init(title: "USDT".withTextStyle(.body2, color: .white), icon: .image(.TKCore.Icons.Size44.tonLogo)), selectionClosure: nil),
    ]
    
    let otherItemsModel: TokenListItemsModel = .init(items: [
      .init(image: .image(.TKCore.Icons.Size44.tonLogo), symbol: "TON", displayName: "Toncoin", badge: nil, balance: "100,000.01", balanceConverted: "$600,000.01"),
      .init(image: .image(.TKCore.Icons.Size44.tonLogo), symbol: "USD₮", displayName: "Tether USD", badge: "TON", balance: "100,000.01", balanceConverted: "$100,000.01"),
      .init(image: .image(.TKCore.Icons.Size44.tonLogo), symbol: "ANON", displayName: "ANON", badge: nil, balance: nil, balanceConverted: nil),
      .init(image: .image(.TKCore.Icons.Size44.tonLogo), symbol: "GLINT", displayName: "Glint Coin", badge: nil,balance: nil, balanceConverted: nil),
    ])
    
    let otherItems = otherItemsModel.items.map { item in
      itemMapper.mapTokenListItem(item) { [weak self] in
        self?.didSelectToken(item.symbol)
      }
    }
    
    didUpdateListItems?(suggestedItems, otherItems)
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
