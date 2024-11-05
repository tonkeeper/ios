import UIKit
import TKUIKit
import KeeperCore
import BigInt

enum AmountInputSymbol {
  case icon(UIImage)
  case text(String)
}

protocol AmountInputModuleOutput: AnyObject {
  var isEnable: Bool { get }
  
  var didUpdateSourceAmount: ((BigUInt) -> Void)? { get set }
  var didUpdateIsEnableState: ((Bool) -> Void)? { get set }
}

protocol AmountInputModuleInput: AnyObject {
  var sourceUnit: AmountInputUnit { get set }
  var destinationUnit: AmountInputUnit { get set }
  var rate: NSDecimalNumber { get set }
  var sourceBalance: BigUInt { get set }
  var minimumSourceAmount: BigUInt? { get set }
  var isMaxButtonVisible: Bool { get set }
}

protocol AmountInputViewModel: AnyObject {
  var didUpdateMaximumFractionDigits: ((Int) -> Void)? { get set }
  var didUpdateValueViewConfiguration: ((AmountInputValueView.Configuration) -> Void)? { get set }
  var didUpdateBalanceViewConfiguration: ((AmountInputBalanceView.Configuration) -> Void)? { get set }
  var didUpdateInputText: ((String) -> Void)? { get set }
  var didUpdateMaxButtonIsSelected: ((Bool) -> Void)? { get set }
  
  func viewDidLoad()
  func toggle()
  func didEditText(_ text: String?)
}

final class AmountInputViewModelImplementation: AmountInputViewModel, AmountInputModuleOutput, AmountInputModuleInput {
  
  // MARK: - AmountInputModuleOutput
  
  var didUpdateSourceAmount: ((BigUInt) -> Void)?
  var didUpdateIsEnableState: ((Bool) -> Void)?
  
  // MARK: - AmountInputModuleInput
  
  // MARK: - AmountInputViewModel
  
  var didUpdateMaximumFractionDigits: ((Int) -> Void)?
  var didUpdateValueViewConfiguration: ((AmountInputValueView.Configuration) -> Void)?
  var didUpdateBalanceViewConfiguration: ((AmountInputBalanceView.Configuration) -> Void)?
  var didUpdateInputText: ((String) -> Void)?
  var didUpdateMaxButtonIsSelected: ((Bool) -> Void)?
  
  func viewDidLoad() {
    didToggleMode()
    updateBalanceView()
    updateIsEnableState()
  }
  
  func toggle() {
    mode = mode.toggled
  }
  
  func didEditText(_ text: String?) {
    didUpdateInput(text ?? "")
  }
  
  private enum Mode {
    case source
    case destination
    
    var toggled: Mode {
      switch self {
      case .source:
        return .destination
      case .destination:
        return .source
      }
    }
  }
  private var mode: Mode = .source {
    didSet {
      didToggleMode()
    }
  }
  
  var isEnable: Bool = false {
    didSet {
      didUpdateIsEnableState?(isEnable)
    }
  }
  
  private let amountFormatter: AmountFormatter
  
  private var _sourceAmount: BigUInt = 0 {
    didSet {
      didUpdateSourceAmount?(_sourceAmount)
    }
  }
  private var sourceAmount: BigUInt {
    get {
      _sourceAmount
    }
    set {
      _sourceAmount = newValue
      recalculateDestination()
      isMax = (_sourceAmount == sourceBalance) && !_sourceAmount.isZero && !sourceBalance.isZero
    }
  }
  
  private var _destinationAmount: BigUInt = 0
  private var destinationAmount: BigUInt {
    get {
      _destinationAmount
    }
    set {
      _destinationAmount = newValue
      recalculateSource()
    }
  }
  
  var rate: NSDecimalNumber = 1 {
    didSet {
      didUpdateRate()
    }
  }
  var sourceBalance: BigUInt = 0 {
    didSet {
      didUpdateBalance()
    }
  }
  var minimumSourceAmount: BigUInt? {
    didSet {
      didUpdateMinimumSourceAmount()
    }
  }
  var isMaxButtonVisible: Bool = false {
    didSet {
      didUpdateIsMaxButtonVisible()
    }
  }
  var sourceUnit: AmountInputUnit {
    didSet {
      didUpdateSourceUnit()
    }
  }
  var destinationUnit: AmountInputUnit {
    didSet {
      didUpdateDestinationUnit()
    }
  }
  
  private var isMax: Bool = false {
    didSet {
      didUpdateIsMax()
    }
  }
  
  init(amountFormatter: AmountFormatter,
       sourceUnit: AmountInputUnit,
       destinationUnit: AmountInputUnit) {
    self.amountFormatter = amountFormatter
    self.sourceUnit = sourceUnit
    self.destinationUnit = destinationUnit
  }
  
  private func didUpdateSourceUnit() {
    sourceAmount = 0
    mode = .source
    updateBalanceView()
    updateIsEnableState()
  }
  
  private func didUpdateDestinationUnit() {
    destinationAmount = 0
    mode = .source
    updateBalanceView()
    updateIsEnableState()
  }
  
  private func didUpdateRate() {
    switch mode {
    case .source:
      recalculateDestination()
    case .destination:
      recalculateSource()
    }
    updateValueView()
  }
  
  private func didUpdateBalance() {
    updateBalanceView()
    updateIsEnableState()
  }
  
  private func didUpdateMinimumSourceAmount() {
    updateBalanceView()
    updateIsEnableState()
  }
  
  private func didUpdateIsMaxButtonVisible() {
    updateBalanceView()
  }
  
  private func didUpdateIsMax() {
    didUpdateMaxButtonIsSelected?(isMax)
  }
  
  private func updateIsEnableState() {
    var isEnable = true
    
    isEnable = isEnable && (sourceAmount > 0)
    isEnable = isEnable && (sourceAmount <= sourceBalance)
    if let minimumSourceAmount {
      isEnable = isEnable && (sourceAmount >= minimumSourceAmount)
    }

    self.isEnable = isEnable
  }
  
  private func didToggleMode() {
    switch mode {
    case .source:
      didUpdateMaximumFractionDigits?(sourceUnit.fractionalDigits)
    case .destination:
      didUpdateMaximumFractionDigits?(destinationUnit.fractionalDigits)
    }
    updateValueView()
    updateInput()
  }
  
  private func updateValueView() {
    let configuration = AmountInputValueView.Configuration(
      inputControlConfiguration: AmountInputInputControl.Configuration(
        symbolViewConfiguration: inputSymbolConfiguration
      ),
      convertedButtonConfiguration: AmountInputConvertedButton.Configuration(
        text: convertedFormattedValue,
        symbolConfiguration: convertedSymbolConfiguration
      )
    )
    
    didUpdateValueViewConfiguration?(configuration)
  }
  
  private var inputSymbolConfiguration: AmountInputSymbolView.Configuration {
    let configurationSymbol: AmountInputSymbol
    switch mode {
    case .source:
      configurationSymbol = sourceUnit.inputSymbol
    case .destination:
      configurationSymbol = destinationUnit.inputSymbol
    }
    let item: AmountInputSymbolView.Configuration.Item
    let verticalOffset: CGFloat
    switch configurationSymbol {
    case .icon(let image):
      verticalOffset = 0
      item = .icon(icon: image, size: CGSize(width: 28, height: 36), tintColor: .Icon.secondary)
    case .text(let text):
      verticalOffset = 5
      item = .text(text.withTextStyle(.num2, color: .Text.secondary))
    }
    return AmountInputSymbolView.Configuration(
      item: item,
      verticalOffset: verticalOffset
    )
  }
  
  private var convertedSymbolConfiguration: AmountInputSymbolView.Configuration {
    let configurationSymbol: AmountInputSymbol
    switch mode {
    case .source:
      configurationSymbol = destinationUnit.inputSymbol
    case .destination:
      configurationSymbol = sourceUnit.inputSymbol
    }
    let item: AmountInputSymbolView.Configuration.Item
    switch configurationSymbol {
    case .icon(let image):
      item = .icon(icon: image, size: CGSize(width: 16, height: 16), tintColor: .Icon.secondary)
    case .text(let text):
      item = .text(text.withTextStyle(.body1, color: .Text.secondary))
    }
    return AmountInputSymbolView.Configuration(
      item: item,
      verticalOffset: 0
    )
  }
  
  private var convertedFormattedValue: String {
    switch mode {
    case .source:
      amountFormatter.formatAmount(
        destinationAmount,
        fractionDigits: sourceUnit.fractionalDigits,
        maximumFractionDigits: 2
      )
    case .destination:
      amountFormatter.formatAmount(
        sourceAmount,
        fractionDigits: sourceUnit.fractionalDigits,
        maximumFractionDigits: 2
      )
    }
  }
  
  private func updateBalanceView() {
    let balance: String
    let color: UIColor
    if sourceAmount.isZero {
      let formattedBalance = amountFormatter.formatAmount(
        sourceBalance,
        fractionDigits: sourceUnit.fractionalDigits,
        maximumFractionDigits: sourceUnit.fractionalDigits,
        symbol: sourceUnit.symbol)
      balance = "Available: \(formattedBalance)"
      color = .Text.secondary
    } else if sourceAmount > sourceBalance {
      balance = "Insufficient balance"
      color = .Accent.red
    } else if let minimumSourceAmount, sourceAmount < minimumSourceAmount {
      let formattedMinimum = amountFormatter.formatAmount(
        minimumSourceAmount,
        fractionDigits: sourceUnit.fractionalDigits,
        maximumFractionDigits: sourceUnit.fractionalDigits,
        symbol: sourceUnit.symbol)
      balance = "Minimum \(formattedMinimum)"
      color = .Accent.red
    } else {
      let formattedBalance = amountFormatter.formatAmount(
        sourceBalance - sourceAmount,
        fractionDigits: sourceUnit.fractionalDigits,
        maximumFractionDigits: sourceUnit.fractionalDigits,
        symbol: sourceUnit.symbol)
      balance = "Available: \(formattedBalance)"
      color = .Text.secondary
    }

    let string = balance.withTextStyle(.body2, color: color, alignment: .right)
    
    var maxButtonConfiguration: TKButton.Configuration?
    if isMaxButtonVisible {
      maxButtonConfiguration = TKButton.Configuration.maxButtonConfiguration
      maxButtonConfiguration?.content = TKButton.Configuration.Content(title: .plainString("MAX"))
      maxButtonConfiguration?.action = { [weak self] in
        guard let self else { return }
        isMax.toggle()
        let isMax = isMax
        if isMax {
          sourceAmount = sourceBalance
        } else {
          sourceAmount = 0
        }
        
        updateValueView()
        updateBalanceView()
        updateInput()
      }
    }
    
    didUpdateBalanceViewConfiguration?(
      AmountInputBalanceView.Configuration(
        maxButtonConfiguration: maxButtonConfiguration,
        balance: string
      )
    )
  }
  
  private func didUpdateIsEnable() {
    didUpdateIsEnableState?(isEnable)
  }
  
  private func updateInput() {
    let formatted: String = {
      switch mode {
      case .source:
        amountFormatter.formatAmount(
          sourceAmount,
          fractionDigits: sourceUnit.fractionalDigits,
          maximumFractionDigits: sourceUnit.fractionalDigits
        )
      case .destination:
        amountFormatter.formatAmount(
          destinationAmount,
          fractionDigits: sourceUnit.fractionalDigits,
          maximumFractionDigits: destinationUnit.fractionalDigits
        )
      }
    }()
    didUpdateInputText?(formatted)
    updateIsEnableState()
  }
  
  func didUpdateInput(_ text: String) {
    let amount = inputStringToAmount(input: text)
    switch mode {
    case .source:
      sourceAmount = amount
    case .destination:
      destinationAmount = amount
    }
    updateValueView()
    updateBalanceView()
    updateIsEnableState()
  }
  
  func recalculateSource() {
    let converted = RateConverter().convertFromCurrency(amount: destinationAmount,
                                                        amountFractionLength: destinationUnit.fractionalDigits,
                                                        rate: rate)
    _sourceAmount = converted
  }
  
  func recalculateDestination() {
    let converted = RateConverter().convert(amount: sourceAmount,
                                            amountFractionLength: sourceUnit.fractionalDigits,
                                            rate: rate)
    _destinationAmount = converted
  }
  
  func inputStringToAmount(input: String) -> BigUInt {
    guard !input.isEmpty else { return 0 }
    let fractionalSeparator: String = Locale.current.decimalSeparator ?? ""
    let components = input.components(separatedBy: fractionalSeparator)
    guard components.count < 3 else {
      return 0
    }
    
    let fractionalDigits = components.count == 2 ? components[1].count : 0
    let targetFractionalDigits: Int = {
      switch mode {
      case .source:
        sourceUnit.fractionalDigits
      case .destination:
        sourceUnit.fractionalDigits
      }
    }()
    let zeroString = String(repeating: "0", count: max(0, targetFractionalDigits - fractionalDigits))
    let bigIntValue = BigUInt(stringLiteral: components.joined() + zeroString)
    return bigIntValue
  }
}

private extension TKButton.Configuration {
  static var maxButtonConfiguration: TKButton.Configuration {
    return TKButton.Configuration(
      contentPadding: UIEdgeInsets(top: 6, left: 16, bottom: 6, right: 16),
      padding: UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 0),
      textStyle: .label2,
      textColor: .Button.secondaryForeground,
      backgroundColors: [
        .normal: .Button.secondaryBackground,
        .highlighted: .Button.secondaryBackgroundHighlighted,
        .disabled: .Button.secondaryBackgroundDisabled,
        .selected: .Button.primaryBackground
      ],
      cornerRadius: 16
    )
  }
}
