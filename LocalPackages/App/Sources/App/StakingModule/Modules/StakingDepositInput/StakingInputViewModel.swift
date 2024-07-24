import UIKit
import TKUIKit
import TKCore
import KeeperCore
import BigInt

protocol StakingInputModuleOutput: AnyObject {
  var didTapPoolPicker: ((_ model: StakingListModel) -> Void)? { get set }
  var didConfirm: ((StakingConfirmationItem) -> Void)? { get set }
}

protocol StakingInputModuleInput: AnyObject {
  func setPool(_ pool: StackingPoolInfo)
}

protocol StakingInputViewModel: AnyObject {
  var didUpdateTitle: ((String) -> Void)? { get set }
  var didUpdateConvertedValue: ((String) -> Void)? { get set }
  var didUpdateInputValue: ((String?) -> Void)? { get set }
  var didUpdateInputSymbol: ((String?) -> Void)? { get set }
  var didUpdateMaximumFractionDigits: ((Int) -> Void)? { get set }
  var didUpdateRemaining: ((NSAttributedString) -> Void)? { get set }
  var didUpdateSwapIcon: ((Bool) -> Void)? { get set }
  var didUpdateIsMax: ((Bool) -> Void)? { get set }
  var didUpdateButton:((String, Bool) -> Void)? { get set }
  var didUpdatePoolInfoView: ((StakingInputPoolInfoView.Model?) -> Void)? { get set }
  
  func viewDidLoad()
  func didEditAmountInput(_ input: String)
  func didToggleInputMode()
  func didToggleIsMax()
  func didTapInfoView()
  func didTapContinue()
}

final class StakingInputViewModelImplementation: StakingInputViewModel, StakingInputModuleOutput, StakingInputModuleInput {
  
  private let model: StakingInputModel
  private let decimalFormatter: DecimalAmountFormatter
  private let amountFormatter: AmountFormatter
  
  init(model: StakingInputModel,
       decimalFormatter: DecimalAmountFormatter,
       amountFormatter: AmountFormatter) {
    self.model = model
    self.decimalFormatter = decimalFormatter
    self.amountFormatter = amountFormatter
  }
  
  // MARK: - StakingInputModuleOutput
  
  var didTapPoolPicker: ((_ model: StakingListModel) -> Void)?
  var didConfirm: ((StakingConfirmationItem) -> Void)?
  
  // MARK: - StakingInputModuleInput
  
  func setPool(_ pool: StackingPoolInfo) {
    model.setSelectedStackingPool(pool)
  }
  
  // MARK: - StakingViewModel
  
  var didUpdateTitle: ((String) -> Void)?
  var didUpdateConvertedValue: ((String) -> Void)?
  var didUpdateInputValue: ((String?) -> Void)?
  var didUpdateInputSymbol: ((String?) -> Void)?
  var didUpdateMaximumFractionDigits: ((Int) -> Void)?
  var didUpdateRemaining: ((NSAttributedString) -> Void)?
  var didUpdateSwapIcon: ((Bool) -> Void)?
  var didUpdateIsMax: ((Bool) -> Void)?
  var didUpdateButton: ((String, Bool) -> Void)?
  var didUpdatePoolInfoView: ((StakingInputPoolInfoView.Model?) -> Void)?
  
  func viewDidLoad() {
    didUpdateTitle?(model.title)
    
    model.didUpdateButtonItem = { [weak self] buttonItem in
      DispatchQueue.main.async {
        self?.didUpdateButtonItem(buttonItem)
      }
    }
    
    model.didUpdatePoolInfoItem = { [weak self] item in
      DispatchQueue.main.async {
        self?.didUpdatePoolInfoItem(item)
      }
    }
    
    model.didUpdateConvertedItem = { [weak self] item in
      DispatchQueue.main.async {
        self?.didUpdateConvertedItem(item)
      }
    }
    
    model.didUpdateInputItem = { [weak self] item in
      DispatchQueue.main.async {
        self?.didUpdateInputItem(item)
      }
    }
    
    model.didUpdateRemainingItem = { [weak self] item in
      DispatchQueue.main.async {
        self?.didUpdateRemainingItem(item)
      }
    }
    
    model.didUpdateIsMax = { [weak self] isMax in
      DispatchQueue.main.async {
        self?.didUpdateIsMax?(isMax)
      }
    }
    
    model.start()
  }
  
  func didEditAmountInput(_ input: String) {
    model.didEditAmountInput(input)
  }
  
  func didToggleInputMode() {
    model.toggleInputMode()
  }
  
  func didToggleIsMax() {
    model.toggleIsMax()
  }
  
  func didTapInfoView() {
    model.getPickerSections { model in
      DispatchQueue.main.async {
        self.didTapPoolPicker?(model)
      }
    }
  }
  
  func didTapContinue() {
    model.getStakingConfirmationItem { item in
      DispatchQueue.main.async {
        self.didConfirm?(item)
      }
    }
  }
}

private extension StakingInputViewModelImplementation {
  func didUpdatePoolInfoItem(_ item: StakingInputPoolInfoItem?) {
    guard let item else {
      didUpdatePoolInfoView?(nil)
      return
    }
    let model: StakingInputPoolInfoView.Model = {
      switch item {
      case let .poolInfo(stackingPoolInfo, isMostProfitable, profit):
        return .listItem(mapStakingPoolItem(stackingPoolInfo, isMostProfitable: isMostProfitable, profit: profit))
      case .cycleInfo(let string):
        return .text(string.withTextStyle(.body2, color: .Text.secondary, alignment: .left, lineBreakMode: .byWordWrapping))
      }
    }()
    
    didUpdatePoolInfoView?(model)
  }
  
  func didUpdateButtonItem(_ item: StakingInputButtonItem) {
    didUpdateButton?(item.title, item.isEnable)
  }
  
  func didUpdateInputItem(_ item: StakingInputInputItem) {
    didUpdateInputSymbol?(item.symbol)
    didUpdateMaximumFractionDigits?(item.maximumFractionDigits)
    didUpdateInputValue?(
      amountFormatter.formatAmount(
        item.amount,
        fractionDigits: item.fractionDigits,
        maximumFractionDigits: item.maximumFractionDigits,
        symbol: nil
      )
    )
  }
  
  func didUpdateConvertedItem(_ item: StakingInputModelConvertedItem) {
    let formatted = amountFormatter.formatAmount(
      item.amount,
      fractionDigits: item.fractionDigits,
      maximumFractionDigits: 2
    )
    
    let convertedValue = "\(formatted) \(item.symbol)"
    didUpdateConvertedValue?(convertedValue)
    didUpdateSwapIcon?(item.isIconHidden)
  }
  
  func didUpdateRemainingItem(_ item: StakingInputRemainingItem) {
    let string: NSAttributedString
    switch item {
    case .lessThanMinDeposit(let amount, let fractionDigits):
      let formatted = amountFormatter.formatAmount(
        amount,
        fractionDigits: fractionDigits,
        maximumFractionDigits: TonInfo.fractionDigits,
        symbol: TonInfo.symbol
      )
      string = "Minimum \(formatted)".withTextStyle(
        .body2,
        color: .Accent.red,
        alignment: .right,
        lineBreakMode: .byTruncatingTail
      )
    case .remaining(let amount, let fractionDigits):
      let formatted = amountFormatter.formatAmount(
        amount,
        fractionDigits: fractionDigits,
        maximumFractionDigits: TonInfo.fractionDigits,
        symbol: TonInfo.symbol
      )
      string = "Available: \(formatted)".withTextStyle(
        .body2,
        color: .Text.secondary,
        alignment: .right,
        lineBreakMode: .byTruncatingTail
      )
    case .insufficient:
      string = "Insufficient balance".withTextStyle(
        .body2,
        color: .Accent.red,
        alignment: .right,
        lineBreakMode: .byTruncatingTail
      )
    }
    didUpdateRemaining?(string)
  }
}

private extension StakingInputViewModelImplementation {

  func mapStakingPoolItem(_ item: StackingPoolInfo, isMostProfitable: Bool, profit: BigUInt) -> TKUIListItemView.Configuration {
    let tagText: String? = isMostProfitable ? .mostProfitableTag : nil
    let percentFormatted = decimalFormatter.format(amount: item.apy, maximumFractionDigits: 2)
    var subtitle = "\(String.apy) ≈ \(percentFormatted)%"
    if profit >= BigUInt(stringLiteral: "1000000000") {
      let formatted = amountFormatter.formatAmount(
        profit,
        fractionDigits: TonInfo.fractionDigits,
        maximumFractionDigits: 2,
        symbol: TonInfo.symbol
      )
      subtitle += " · \(formatted)"
    }
    
    let title = item.name.withTextStyle(
      .label1,
      color: .Text.primary,
      alignment: .left,
      lineBreakMode: .byTruncatingTail
    )
    
    var tagViewModel: TKUITagView.Configuration?
    if let tagText {
      tagViewModel = TKUITagView.Configuration(
        text: tagText,
        textColor: .Accent.green,
        backgroundColor: .Accent.green.withAlphaComponent(0.16)
      )
    }
    
    return TKUIListItemView.Configuration(
      iconConfiguration: TKUIListItemIconView.Configuration(
        iconConfiguration: .image(
          TKUIListItemImageIconView.Configuration(
            image: TKUIListItemImageIconView.Configuration.Image.image(item.implementation.icon),
            tintColor: .clear,
            backgroundColor: .clear,
            size: CGSize(width: 44, height: 44),
            cornerRadius: 22
          )
        ),
        alignment: .center
      ),
      contentConfiguration: TKUIListItemContentView.Configuration(
        leftItemConfiguration: TKUIListItemContentLeftItem.Configuration(
          title: title,
          tagViewModel: tagViewModel,
          subtitle: subtitle.withTextStyle(
            .body2,
            color: .Text.secondary,
            alignment: .left,
            lineBreakMode: .byTruncatingTail
          ),
          description: nil
        ),
        rightItemConfiguration: nil
      ),
      accessoryConfiguration: .image(
        TKUIListItemImageAccessoryView.Configuration(
          image: .TKUIKit.Icons.Size16.switch,
          tintColor: .Icon.tertiary,
          padding: .zero
        )
      )
    )
  }
}

extension StackingPoolInfo.Implementation {
  var icon: UIImage {
    switch type {
    case .liquidTF: .TKUIKit.Icons.Size44.tonStakersLogo
    case .tf: .TKUIKit.Icons.Size44.tonNominatorsLogo
    case .whales: .TKUIKit.Icons.Size44.tonWhalesLogo
    }
  }
}

private extension String {
  static let mostProfitableTag = "MAX APY"
  static let apy = "APY"
}
