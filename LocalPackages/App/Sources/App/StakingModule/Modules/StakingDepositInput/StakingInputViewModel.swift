import UIKit
import TKUIKit
import TKCore
import TKLocalize
import KeeperCore
import BigInt

protocol StakingInputModuleOutput: AnyObject {
  var didUpdateInputAmount: ((BigUInt) -> Void)? { get set }
  var didConfirm: ((StakingConfirmationItem) -> Void)? { get set }
  var didClose: (() -> Void)? { get set }
}

protocol StakingInputModuleInput: AnyObject {
  func setPool(_ pool: StackingPoolInfo)
}

protocol StakingInputViewModel: AnyObject {
  var didUpdateTitle: ((String) -> Void)? { get set }
  var didUpdateButton:((String, Bool) -> Void)? { get set }
  
  func viewDidLoad()
  func didTapContinue()
  func didTapCloseButton()
  func didTapStakingInfoButton()
}

final class StakingInputViewModelImplementation: StakingInputViewModel, StakingInputModuleOutput, StakingInputModuleInput {

  private var isEnable: Bool = false {
    didSet {
      updateButton()
    }
  }
  
  private let amountInputModuleInput: AmountInputModuleInput
  private let amountInputModuleOutput: AmountInputModuleOutput
  private let viewModelConfiguration: StakingInputViewModelConfiguration
  private let currencyStore: CurrencyStore
  private let tonRatesStore: TonRatesStore
  private let configuration: Configuration
  private let urlOpener: URLOpener
  
  init(amountInputModuleInput: AmountInputModuleInput,
       amountInputModuleOutput: AmountInputModuleOutput,
       viewModelConfiguration: StakingInputViewModelConfiguration,
       currencyStore: CurrencyStore,
       tonRatesStore: TonRatesStore,
       configuration: Configuration,
       urlOpener: URLOpener) {
    self.amountInputModuleInput = amountInputModuleInput
    self.amountInputModuleOutput = amountInputModuleOutput
    self.viewModelConfiguration = viewModelConfiguration
    self.currencyStore = currencyStore
    self.tonRatesStore = tonRatesStore
    self.configuration = configuration
    self.urlOpener = urlOpener
  }
  
  // MARK: - StakingInputModuleOutput
  
  var didUpdateInputAmount: ((BigUInt) -> Void)?
  var didConfirm: ((StakingConfirmationItem) -> Void)?
  var didClose: (() -> Void)?
  
  // MARK: - StakingInputModuleInput
  
  func setPool(_ pool: StackingPoolInfo) {
    viewModelConfiguration.setStakingPool(pool)
  }
  
  // MARK: - StakingViewModel
  
  var didUpdateTitle: ((String) -> Void)?
  var didUpdateButton: ((String, Bool) -> Void)?
  var didUpdateDetailsViewIsHidden: ((Bool) -> Void)?
  
  func viewDidLoad() {
    setup()
    setupAmountInput()
    updateButton()
  }
  
  func didTapContinue() {
    guard let confirmationItem = viewModelConfiguration.getStakingConfirmationItem() else {
      return
    }
    didConfirm?(confirmationItem)
  }
  
  func didTapCloseButton() {
    didClose?()
  }
  
  func didTapStakingInfoButton() {
    guard let url = configuration.stakingInfoUrl else { return }
    urlOpener.open(url: url)
  }
  
  private func setup() {
    didUpdateTitle?(viewModelConfiguration.title)
  }
  
  private func setupAmountInput() {
    viewModelConfiguration.didUpdateBalance = { [weak self] in
      guard let self else { return }
      amountInputModuleInput.sourceBalance = viewModelConfiguration.balance
    }
    viewModelConfiguration.didUpdateMinimumInput = { [weak self] in
      guard let self else { return  }
      amountInputModuleInput.minimumSourceAmount = viewModelConfiguration.minimumInput
    }
    
    let currency = currencyStore.state
    let tonRate = tonRatesStore.state.first(where: { $0.currency == currency })?.rate ?? 1
    amountInputModuleInput.sourceUnit = Token.ton
    amountInputModuleInput.destinationUnit = currency
    amountInputModuleInput.rate = NSDecimalNumber(decimal: tonRate)
    amountInputModuleInput.sourceBalance = viewModelConfiguration.balance
    amountInputModuleInput.minimumSourceAmount = viewModelConfiguration.minimumInput
    amountInputModuleInput.isMaxButtonVisible = true

    amountInputModuleOutput.didUpdateIsEnableState = { [weak self] in
      self?.isEnable = $0
    }
    amountInputModuleOutput.didUpdateSourceAmount = { [weak self] in
      self?.viewModelConfiguration.setInputAmount($0)
      self?.didUpdateInputAmount?($0)
    }
    isEnable = amountInputModuleOutput.isEnable
  }
  
  private func updateButton() {
    didUpdateButton?(TKLocales.StakingDepositInput.continueTitle, isEnable)
  }
}
