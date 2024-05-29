import UIKit
import TKUIKit
import TKLocalize
import KeeperCore
import BigInt

protocol StakeModuleOutput: AnyObject {
  var didTapStakePool: (() -> Void)? { get set }
  var didTapContinue: (() -> Void)? { get set }
}

protocol StakeModuleInput: AnyObject {
  func didSelectPool(_ pool: StakePool)
}

protocol StakeViewModel: AnyObject {
  var didUpdateModel: ((StakeView.Model) -> Void)? { get set }
  var didUpdateInputAmountText: ((String) -> Void)? { get set }
  var didUpdateAvailableTitle: ((NSAttributedString) -> Void)? { get set }
  var didUpdateSelectedPool: ((StakePoolContainerView.Model) -> Void)? { get set }
  
  var textFieldFormatter: InputAmountTextFieldFormatter { get }
  
  func viewDidLoad()
  func didInputAmount(_ string: String)
  func didTapConvertedButton()
  func didTapMaxButton()
}

final class StakeViewModelImplementation: StakeViewModel, StakeModuleOutput, StakeModuleInput {
  
  enum Remaining: Equatable {
    case available(BigUInt)
    case insufficient
  }
  
  // MARK: - StakeModuleOutput
  
  var didTapStakePool: (() -> Void)?
  var didTapContinue: (() -> Void)?
  
  // MARK: - StakeModuleInput
  
  func didSelectPool(_ pool: StakePool) {
    selectedPool = pool
    didUpdateSelectedPool?(createPoolContainerModel())
  }
  
  // MARK: - StakeViewModel
  
  var didUpdateModel: ((StakeView.Model) -> Void)?
  var didUpdateInputAmountText: ((String) -> Void)?
  var didUpdateAvailableTitle: ((NSAttributedString) -> Void)?
  var didUpdateSelectedPool: ((StakePoolContainerView.Model) -> Void)? 
  
  func viewDidLoad() {
    updateWithInitalData()
    
    Task {
      await stakeController.start()
    }
  }
  
  func didInputAmount(_ string: String) {
    guard string != inputItem.amountString else { return }
    updateStakeItems(withInput: string)
  }
  
  func didTapConvertedButton() {
    stakeItem.input = stakeItem.input.opposite
    textFieldFormatter.maximumFractionDigits = inputItem.fractionDigits
    didUpdateInputAmountText?(inputItem.amountString)
    update()
  }
  
  func didTapMaxButton() {
    Task {
      let balance = await stakeController.getTonBalanceAmount()
      let convertedBalance = stakeController.convertAmountToString(amount: balance, fractionDigits: stakeItem.tokenItem.fractionDigits)
      await MainActor.run {
        stakeItem.tokenItem = stakeItem.tokenItem.updated(amount: balance, amountString: convertedBalance)
        didUpdateInputAmountText?(convertedBalance)
        reloadStakeItems()
      }
    }
  }
  
  // MARK: - State
  
  private var stakeItem = BuySellItem(input: .token, tokenItem: .ton, fiatItem: .usd)
  
  private var inputItem: BuySellItem.Item {
    stakeItem.getItem(forInput: stakeItem.input)
  }
  private var outputItem: BuySellItem.Item {
    stakeItem.getItem(forInput: stakeItem.output)
  }
  
  private var minimumValidTokenAmountString = "0"
  private var minimumValidTokenAmount = BigUInt(0)
  
  private var selectedPool: StakePool = .emptyItem
  
  private var remaining = Remaining.available(0) {
    didSet {
      guard remaining != oldValue else { return }
      let availableTitle = createAvailableTitle()
      didUpdateAvailableTitle?(availableTitle)
    }
  }
  
  private var isAmountValid: Bool = false {
    didSet {
      guard isAmountValid != oldValue else { return }
      update()
    }
  }
  
  private var isResolving = false {
    didSet {
      guard isResolving != oldValue else { return }
      update()
    }
  }
  
  private var isContinueEnable: Bool {
    isAmountValid && remaining != .insufficient
  }
  
  // MARK: - Formatter
  
  let textFieldFormatter = InputAmountTextFieldFormatter()
  
  // MARK: - Dependencies
  
  private let stakeController: StakeController
  
  // MARK: - Init
  
  init(stakeController: StakeController) {
    self.stakeController = stakeController
    self.textFieldFormatter.maximumFractionDigits = stakeItem.tokenItem.fractionDigits
  }
  
  deinit {
    print("\(Self.self) deinit")
  }
}

// MARK: - Private

private extension StakeViewModelImplementation {
  func updateWithInitalData() {
    stakeItem = BuySellItem(
      input: .token,
      tokenItem: BuySellItem.Token(
        amount: 0,
        amountString: "0",
        token: .ton
      ),
      fiatItem: BuySellItem.Fiat(
        amount: 0,
        amountString: "0",
        currency: .USD
      )
    )
    
    let minimumTokenAmountString = "1"
    updateMinimumValidAmount(minimumTokenAmountString)
    
    let tokenAmountString = "0"
    
    didSelectPool(.testData[0])
    
    update()
    updateFiatCurrency()
    reloadStakeItems()
    didUpdateInputAmountText?(tokenAmountString)
  }
  
  func updateStakeItems(withInput string: String) {
    let input = stakeItem.input
    let inputAmount = convertStringToAmount(string, targetFractionDigits: inputItem.fractionDigits)
    
    let tokenItem = stakeItem.tokenItem
    let fiatItem = stakeItem.fiatItem
    
    Task {
      let updatedToken: BuySellItem.Token
      let updatedFiat: BuySellItem.Fiat
      
      switch input {
      case .token:
        updatedToken = tokenItem.updated(amount: inputAmount, amountString: string)
        updatedFiat = await stakeController.convertTokenToFiat(updatedToken, currency: fiatItem.currency)
      case .fiat:
        updatedFiat = fiatItem.updated(amount: inputAmount, amountString: string)
        updatedToken = await stakeController.convertFiatToToken(updatedFiat, token: tokenItem.token)
      }
      
      let balance = await stakeController.getTonBalanceAmount()
      let updatedRemaining: Remaining
      if updatedToken.amount <= balance {
        updatedRemaining = .available(balance - updatedToken.amount)
      } else {
        updatedRemaining = .insufficient
      }
      
      await MainActor.run {
        stakeItem.tokenItem = updatedToken
        stakeItem.fiatItem = updatedFiat
        
        isAmountValid = minimumValidTokenAmount <= updatedToken.amount
        remaining = updatedRemaining
        
        update()
      }
    }
  }
  
  func reloadStakeItems() {
    updateStakeItems(withInput: inputItem.amountString)
  }
  
  func updateMinimumValidAmount(_ string: String) {
    minimumValidTokenAmountString = string
    minimumValidTokenAmount = convertStringToAmount(string, targetFractionDigits: stakeItem.tokenItem.fractionDigits)
  }
  
  func convertStringToAmount(_ string: String, targetFractionDigits: Int) -> BigUInt {
    let unformatted = textFieldFormatter.unformatString(string) ?? "0"
    let converted = stakeController.convertStringToAmount(
      string: unformatted,
      targetFractionalDigits: targetFractionDigits
    )
    return converted.amount
  }
  
  func update() {
    let model = createModel()
    didUpdateModel?(model)
  }
  
  func createModel() -> StakeView.Model {
    StakeView.Model(
      title: ModalTitleView.Model(title: "Stake"),
      input: StakeAmountInputView.Model(
        inputCurrency: inputItem.currencyCode,
        convertedAmount: StakeAmountInputView.Model.Amount(
          value: outputItem.amountString,
          currency: outputItem.currencyCode
        )
      ),
      footer: StakeFooterView.Model(
        maxButton: StakeFooterView.Model.Button(
          title: "MAX",
          isEnabled: true,
          action: { [weak self] in
            self?.didTapMaxButton()
          }
        ),
        description: createAvailableTitle()
      ),
      selectedPool: createPoolContainerModel(),
      button: StakeView.Model.Button(
        title: TKLocales.Actions.continue_action,
        isEnabled: !isResolving && isContinueEnable,
        isActivity: isResolving,
        action: { [weak self] in
          self?.didTapContinue?()
        }
      )
    )
  }
  
  func createPoolContainerModel() -> StakePoolContainerView.Model {
    let title = selectedPool.title.withTextStyle(.label1, color: .Text.primary)
    var tagViewModel: TKUITagView.Configuration?
    if let tagText = selectedPool.tag {
      tagViewModel = TKUITagView.Configuration(text: tagText, textColor: .Accent.green, backgroundColor: .Accent.green.withAlphaComponent(0.16))
    }
    
    let apyTitle = "APY ≈ \(selectedPool.apy)"
    let subtitleText = "\(apyTitle) · 50.01 TON"
    let subtitle = subtitleText.withTextStyle(.body2, color: .Text.secondary)
    
    let iconView = TKUIListItemImageIconView.Configuration(
      image: .image(selectedPool.image),
      tintColor: .clear,
      backgroundColor: .Background.contentTint,
      size: CGSize(width: 44, height: 44),
      cornerRadius: 22
    )
    let iconConfiguration = TKUIListItemIconView.Configuration(
      iconConfiguration: .image(iconView),
      alignment: .center
    )
    
    let contentConfiguration = TKUIListItemContentView.Configuration(
      leftItemConfiguration: TKUIListItemContentLeftItem.Configuration(
        title: title,
        tagViewModel: tagViewModel,
        subtitle: subtitle,
        description: nil
      ),
      rightItemConfiguration: nil
    )
    
    let accessoryImageConfiguration = TKUIListItemImageAccessoryView.Configuration(
      image: .TKUIKit.Icons.Size16.switch,
      tintColor: .Icon.secondary,
      padding: .init(top: 0, left: 0, bottom: 0, right: 8)
    )
    
    return StakePoolContainerView.Model(
      icon: iconConfiguration,
      content: contentConfiguration,
      accessory: .image(accessoryImageConfiguration),
      selectionClosure: { [weak self] in
        self?.didTapStakePool?()
      }
    )
  }
  
  func createAvailableTitle() -> NSAttributedString {
    switch remaining {
    case .available(let amount):
      let convertedAmount = stakeController.convertAmountToString(amount: amount, fractionDigits: stakeItem.tokenItem.fractionDigits)
      return "Available: \(convertedAmount) \(stakeItem.tokenItem.currencyCode)".withTextStyle(.body2, color: .Text.secondary)
    case .insufficient:
      return "Insufficient balance".withTextStyle(.body2, color: .Accent.red)
    }
  }
  
  func updateFiatCurrency() {
    Task {
      let activeCurrency = await stakeController.getActiveCurrency()
      await MainActor.run {
        guard stakeItem.fiatItem.currency != activeCurrency else { return }
        stakeItem.fiatItem.currency = activeCurrency
        reloadStakeItems()
      }
    }
  }
}

private extension StakePool {
  static let emptyItem = StakePool(id: "", image: .init(), title: "", tag: nil, apy: "", minimumDeposit: nil)
}
