import Foundation
import TonSwift
import BigInt

public struct OptionItem {
  public let id: String
  public let title: String
  public let image: TokenImage
  public let apyPercents: String
  public let apyTokenAmount: String?
  public let isMaxAPY: Bool
  public let minDepositAmount: String
  public let isPrefferable: Bool
  public var isSelected: Bool
  
  public init(
    id: String,
    title: String,
    image: TokenImage,
    apyPercents: String,
    apyTokenAmount: String?,
    minDepositAmount: String,
    isMaxAPY: Bool,
    isPrefferable: Bool,
    isSelected: Bool
  ) {
    self.id = id
    self.title = title
    self.image = image
    self.apyPercents = apyPercents
    self.apyTokenAmount = apyTokenAmount
    self.isMaxAPY = isMaxAPY
    self.minDepositAmount = minDepositAmount
    self.isPrefferable = isPrefferable
    self.isSelected = isSelected
  }
}

let testUrl = URL(
  string: "https://cache.tonapi.io/imgproxy/GjhSro_E6Qxod2SDQeDhJA_F3yARNomyZFKeKw8TVOU/rs:fill:200:200:1/g:no/aHR0cHM6Ly90b25zdGFrZXJzLmNvbS9qZXR0b24vbG9nby5zdmc.webp"
)

public final class StakingController {
  public enum Remaining {
    case remaining(String)
    case insufficient
  }
  
  public var didUpdateConvertedValue: ((String) -> Void)?
  public var didUpdateInputValue: ((String?) -> Void)?
  public var didUpdateInputSymbol: ((String?) -> Void)?
  public var didUpdateMaximumFractionDigits: ((Int) -> Void)?
  public var didUpdateIsContinueEnabled: ((Bool) -> Void)?
  public var didUpdateRemaining: ((Remaining) -> Void)?
  public var didUpdateIsHiddenSwapIcon: ((Bool) -> Void)?
  public var didUpdateProvider: ((OptionItem) -> Void)?
  public var didResetMax: (() -> Void)?
  
  public private(set) var optionItem: OptionItem = .init(
    id: "Tonstakers",
    title: "Tonstakers",
    image: .url(testUrl),
    apyPercents: "5.01%",
    apyTokenAmount: nil,
    minDepositAmount: "1 TON",
    isMaxAPY: true,
    isPrefferable: true,
    isSelected: true
  )
  public private(set) var token: Token = .ton
  private var isTokenAmountInput = true {
    didSet {
      didChangeInputMode()
    }
  }
  
  public private(set) var tokenAmount: BigUInt = .zero {
    didSet {
      didUpdateTokenAmount()
    }
  }
  
  private var rate: Rates.Rate?
  private var currency: Currency = .USD
  private var shouldUpdateInput: Bool = true
  private var isMaxAmount = false {
    didSet {
      didToggleMax()
    }
  }
    
  private let walletStore: WalletsStore
  private let walletBalanceStore: WalletBalanceStore
  private let currencyStore: CurrencyStore
  private let ratesStore: RatesStore
  private let rateConverter: RateConverter
  private let amountFormatter: AmountFormatter
  
  init(
    walletStore: WalletsStore,
    walletBalanceStore: WalletBalanceStore,
    ratesStore: RatesStore,
    currencyStore: CurrencyStore,
    rateConverter: RateConverter,
    amountFormatter: AmountFormatter
  ) {
    self.walletStore = walletStore
    self.walletBalanceStore = walletBalanceStore
    self.ratesStore = ratesStore
    self.currencyStore = currencyStore
    self.rateConverter = rateConverter
    self.amountFormatter = amountFormatter
  }
  
  public func start() {
    Task {
      currency = await currencyStore.getActiveCurrency()
      
      await MainActor.run {
        updateMaximumFractionDigits()
        updateRates()
        updateInputValue()
        updateConvertedValue()
        didUpdateTokenAmount()
        updateProvider()
      }
    }
  }
  
  public func getActiveActiveWallet() -> Wallet {
    walletStore.activeWallet
  }
  
  public func toggleMode() {
    isTokenAmountInput.toggle()
  }
  
  public func toggleMax() {
    isMaxAmount.toggle()
  }
  
  public func setProvider(_ item: OptionItem) {
    optionItem = item
    updateProvider()
  }
  
  public func setInput(_ input: String) {
    let amountOfTokens: BigUInt
    
    if isTokenAmountInput {
      let (amount, _) = convertInputStringToAmount(
        input: input,
        targetFractionalDigits: token.fractionDigits
      )
      amountOfTokens = amount
    } else {
      let (amount, fractionalDigits) = convertInputStringToAmount(
        input: input,
        targetFractionalDigits: token.fractionDigits
      )
      let converted = convertCurrencyAmountToToken(
        amount: amount,
        fractionalDigits: fractionalDigits
      )
      amountOfTokens = converted.0.short(to: converted.1 - token.fractionDigits)
    }
    
    tokenAmount = amountOfTokens
    updateConvertedValue()
    updateIsMaxIfNeeded()
  }
}

// MARK: - Private methods

private extension StakingController {
  func updateRates() {
    let rates: [Rates.Rate]
    switch token {
    case .ton:
      rates = ratesStore.getRates(jettons: []).ton
    case .jetton(let jettonItem):
      rates = ratesStore.getRates(jettons: [jettonItem.jettonInfo]).jettonsRates.first(where: { $0.jettonInfo == jettonItem.jettonInfo })?.rates ?? []
    }
    
    rate = rates.first(where: { $0.currency == currency })
  }
  
  func didToggleMax() {
    Task {
      if !shouldUpdateInput {
        shouldUpdateInput.toggle()
        return 
      }
      
      let amountOfTokens: BigUInt
      
      if isMaxAmount {
        let wallet = walletStore.activeWallet
        let balance: Balance
        do {
          balance = try await walletBalanceStore.getBalanceState(walletAddress: try wallet.address).walletBalance.balance
        } catch {
          balance = Balance(tonBalance: TonBalance(amount: 0), jettonsBalance: [])
        }
        
        switch token {
        case .ton:
          amountOfTokens = BigUInt(balance.tonBalance.amount)
        case .jetton(let jettonItem):
          let jettonBalance = balance.jettonsBalance.first(where: { $0.item.jettonInfo == jettonItem.jettonInfo })
          amountOfTokens = jettonBalance?.quantity ?? 0
        }
      } else {
        amountOfTokens = .zero
      }
      
      await MainActor.run {
        tokenAmount = amountOfTokens
        updateInputValue()
        updateConvertedValue()
      }
    }
  }
  
  func didUpdateTokenAmount() {
    Task {
      let wallet = walletStore.activeWallet
      let balance: Balance
      do {
        balance = try await walletBalanceStore.getBalanceState(walletAddress: try wallet.address).walletBalance.balance
      } catch {
        balance = Balance(tonBalance: TonBalance(amount: 0), jettonsBalance: [])
      }
      
      await MainActor.run {
        updateRemaining(balance: balance)
        updateContinueIsEnabled(balance: balance)
      }
    }
  }
  
  func updateRemaining(balance: Balance) {
    let amount: BigUInt
    let tokenSymbol: String?
    let fractionalDigits: Int
    switch token {
    case .ton:
      amount = BigUInt(balance.tonBalance.amount)
      tokenSymbol = TonInfo.symbol
      fractionalDigits = TonInfo.fractionDigits
    case .jetton(let jettonItem):
      amount = balance.jettonsBalance.first(where: { $0.item.jettonInfo == jettonItem.jettonInfo })?.quantity ?? 0
      tokenSymbol = jettonItem.jettonInfo.symbol
      fractionalDigits = jettonItem.jettonInfo.fractionDigits
    }
    
    let remaining: Remaining
    if amount >= tokenAmount {
      let remainingAmount = amount - tokenAmount
      let formatted = amountFormatter.formatAmount(
        remainingAmount,
        fractionDigits: fractionalDigits,
        maximumFractionDigits: fractionalDigits,
        symbol: tokenSymbol
      )
      
      remaining = .remaining(formatted)
    } else {
      remaining = .insufficient
    }
    
    didUpdateRemaining?(remaining)
    updateContinueIsEnabled(balance: balance)
  }
  
  func updateContinueIsEnabled(balance: Balance) {
    let isEmptyInput = tokenAmount.isZero
    guard !isEmptyInput else {
      didUpdateIsContinueEnabled?(false)
      return
    }
    
    let isBalanceValid: Bool
    switch token {
    case .ton:
      isBalanceValid = BigUInt(balance.tonBalance.amount) >= tokenAmount
    case .jetton(let jettonItem):
      let jettonBalanceAmount = balance.jettonsBalance.first(where: { $0.item.jettonInfo == jettonItem.jettonInfo })?.quantity ?? 0
      isBalanceValid = jettonBalanceAmount >= tokenAmount
    }
    
    didUpdateIsContinueEnabled?(isBalanceValid)
  }
  
  func didChangeInputMode() {
    
    updateMaximumFractionDigits()
    updateInputValue()
    updateConvertedValue()
  }
  
  func updateMaximumFractionDigits() {
    let fractionDigits: Int
    if isTokenAmountInput {
      fractionDigits = token.fractionDigits
    } else {
      fractionDigits = .fiatFractionDigits
    }
    
    didUpdateMaximumFractionDigits?(fractionDigits)
  }
  
  func updateInputValue() {
      let inputValue: String
      let symbol: String
      
      if isTokenAmountInput {
        let fractionDigits = token.fractionDigits
        let formatted = amountFormatter.formatAmount(
          tokenAmount,
          fractionDigits: fractionDigits,
          maximumFractionDigits: fractionDigits
        )
        
        inputValue = formatted
        symbol = token.symbol
      } else {
        let converted = convertTokenAmountToCurrency(amount: tokenAmount)
        let formatted = amountFormatter.formatAmount(
          converted.0,
          fractionDigits: converted.1,
          maximumFractionDigits: .fiatFractionDigits
        )
        inputValue = formatted
        symbol = currency.code
      }
    
    didUpdateInputValue?(inputValue)
    didUpdateInputSymbol?(symbol)
  }
  
  func convertTokenAmountToCurrency(amount: BigUInt) -> (BigUInt, Int) {
    if let rate {
      return rateConverter.convert(
        amount: amount,
        amountFractionLength: token.fractionDigits,
        rate: rate
      )
    } else {
      return (0, 2)
    }
  }
  
  func convertCurrencyAmountToToken(amount: BigUInt, fractionalDigits: Int) -> (BigUInt, Int) {
    if let rate {
      let reversedRate = Rates.Rate(currency: currency, rate: 1/rate.rate, diff24h: nil)
      return rateConverter.convert(amount: amount, amountFractionLength: fractionalDigits, rate: reversedRate)
    } else {
      return (0, fractionalDigits)
    }
  }
  
  func convertInputStringToAmount(input: String, targetFractionalDigits: Int) -> (amount: BigUInt, fractionalDigits: Int) {
    guard !input.isEmpty else { return (0, targetFractionalDigits) }
    let fractionalSeparator: String = .fractionalSeparator ?? ""
    let components = input.components(separatedBy: fractionalSeparator)
    guard components.count < 3 else {
      return (0, targetFractionalDigits)
    }
    
    var fractionalDigits = 0
    if components.count == 2 {
        let fractionalString = components[1]
        fractionalDigits = fractionalString.count
    }
    let zeroString = String(repeating: "0", count: max(0, targetFractionalDigits - fractionalDigits))
    let bigIntValue = BigUInt(stringLiteral: components.joined() + zeroString)
    return (bigIntValue, targetFractionalDigits)
  }
  
  func updateConvertedValue() {
    let convertedValue: String
    if isTokenAmountInput {
      let converted = convertTokenAmountToCurrency(amount: tokenAmount)
      let formatted = amountFormatter.formatAmount(
        converted.0,
        fractionDigits: converted.1,
        maximumFractionDigits: 2
      )
      
      convertedValue = "\(formatted) \(currency.code)"
    } else {
      let formatted = amountFormatter.formatAmount(
        tokenAmount,
        fractionDigits: token.fractionDigits,
        maximumFractionDigits: token.fractionDigits
      )
      
      convertedValue = "\(formatted) \(token.symbol)"
    }
    
    didUpdateIsHiddenSwapIcon?(tokenAmount != .zero)
    didUpdateConvertedValue?(convertedValue)
  }
  
  func updateIsMaxIfNeeded() {
    if isMaxAmount {
      shouldUpdateInput = false
      isMaxAmount = false
      didResetMax?()
    }
  }
  
  func updateProvider() {
    didUpdateProvider?(optionItem)
  }
}

private extension String {
  static var fractionalSeparator: String? {
    Locale.current.decimalSeparator
  }
}

private extension BigUInt {
  static let zero: Self = .init(integerLiteral: .zero)
  
  func short(to count: Int) -> BigUInt {
    let divider = BigUInt(stringLiteral: "1" + String(repeating: "0", count: count))
    let newValue = self / divider
    return newValue
  }
}

extension Int {
  static let fiatFractionDigits: Self = 2
}
