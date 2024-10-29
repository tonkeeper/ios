import UIKit
import TKUIKit
import TKCore
import KeeperCore
import BigInt

protocol StakingInputDetailsModuleInput: AnyObject {
  func configureWith(stackingPoolInfo: StackingPoolInfo,
                     tonAmount: BigUInt,
                     isMostProfitable: Bool)
}

protocol StakingInputModuleOutput: AnyObject {
  var didTapPoolPicker: ((_ model: StakingListModel) -> Void)? { get set }
  var didConfirm: ((StakingConfirmationItem) -> Void)? { get set }
  var didClose: (() -> Void)? { get set }
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
  var didUpdateDetailsViewIsHidden: ((Bool) -> Void)? { get set}
  
  func viewDidLoad()
  func didEditAmountInput(_ input: String)
  func didToggleInputMode()
  func didToggleIsMax()
  func didTapContinue()
  func didTapCloseButton()
  func didTapStakingInfoButton()
}

final class StakingInputViewModelImplementation: StakingInputViewModel, StakingInputModuleOutput, StakingInputModuleInput {
  
  private let model: StakingInputModel
  private let configurationStore: ConfigurationStore
  private let decimalFormatter: DecimalAmountFormatter
  private let amountFormatter: AmountFormatter
  private let urlOpener: URLOpener
  
  init(model: StakingInputModel,
       configurationStore: ConfigurationStore,
       decimalFormatter: DecimalAmountFormatter,
       amountFormatter: AmountFormatter,
       urlOpener: URLOpener) {
    self.model = model
    self.configurationStore = configurationStore
    self.decimalFormatter = decimalFormatter
    self.amountFormatter = amountFormatter
    self.urlOpener = urlOpener
  }
  
  // MARK: - StakingInputModuleOutput
  
  var didTapPoolPicker: ((_ model: StakingListModel) -> Void)?
  var didConfirm: ((StakingConfirmationItem) -> Void)?
  var didClose: (() -> Void)?
  
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
  var didUpdateDetailsViewIsHidden: ((Bool) -> Void)?
  
  func viewDidLoad() {
    didUpdateTitle?(model.title)
    
    model.didUpdateButtonItem = { [weak self] buttonItem in
      DispatchQueue.main.async {
        self?.didUpdateButtonItem(buttonItem)
      }
    }
    
    model.didUpdateDetailsIsHidden = { [weak self] isHidden in
      DispatchQueue.main.async {
        self?.didUpdateDetailsViewIsHidden?(isHidden)
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
  
  func didTapContinue() {
    model.getStakingConfirmationItem { item in
      DispatchQueue.main.async {
        self.didConfirm?(item)
      }
    }
  }
  
  func didTapCloseButton() {
    didClose?()
  }
  
  func didTapStakingInfoButton() {
    let configuration = configurationStore.getConfiguration()
    guard let url = configuration.stakingInfoUrl else { return }
    urlOpener.open(url: url)
  }
}

private extension StakingInputViewModelImplementation {
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

extension StackingPoolInfo.Implementation {
  var icon: UIImage {
    switch type {
    case .liquidTF: .TKUIKit.Icons.Size44.tonStakersLogo
    case .tf: .TKUIKit.Icons.Size44.tonNominatorsLogo
    case .whales: .TKUIKit.Icons.Size44.tonWhalesLogo
    }
  }
  
  var bigIcon: UIImage {
    switch type {
    case .liquidTF: .App.Images.StakingImplementation.tonstakers
    case .tf: .App.Images.StakingImplementation.tonNominators
    case .whales: .App.Images.StakingImplementation.whales
    }
  }
}
