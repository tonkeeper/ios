import Foundation
import TonSwift
import BigInt
import TKUIKit

public final class StakingWithdrawEditAmountController: StakingEditAmountController {
  
  // MARK: - StakingEditAmountController
  
  public var didUpdateTitle: ((String) -> Void)?
  public var didUpdateConvertedValue: ((String) -> Void)?
  public var didUpdatePrimaryAction: ((StakingEditAmountPrimaryAction) -> Void)?
  public var didUpdateInputValue: ((String?) -> Void)?
  public var didUpdateInputSymbol: ((String?) -> Void)?
  public var didUpdateMaximumFractionDigits: ((Int) -> Void)?
  public var didUpdateRemaining: ((StakingRemaining) -> Void)?
  public var didUpdateIsHiddenSwapIcon: ((Bool) -> Void)?
  public var didUpdateProviderModel: ((ProviderModel) -> Void)?
  public var didResetMax: (() -> Void)?
  
  public var stakingPool: StakingPool
  public private(set) var primaryAction: StakingEditAmountPrimaryAction = .init(action: .confirm, isEnable: false)
  public var wallet: Wallet {
    return walletStore.activeWallet
  }
  
  public func start() {
    didUpdateTitle?(.moduleTitle)
    
    Task {
      currency = await currencyStore.getActiveCurrency()
      
      await MainActor.run {
        updateAvailableStakingPools()
        updateMaximumFractionDigits()
        updateRates()
        updateInputValue()
        updateConvertedValue()
        didUpdateLpJettonAmount()
        startValidationTimer()
      }
    }
  }
  
  public func toggleMode() {
    isTokenAmountInput.toggle()
  }
  
  public func toggleMax() {
    isMaxAmount.toggle()
  }
  
  public func setStakingPool(_ pool: StakingPool) { }
  
  public func setInput(_ input: String) {
    let amountOfJettons: BigUInt
    
    if isTokenAmountInput {
      let (amount, _) = amountConverter.inputStringToAmount(
        input: input,
        targetFractionalDigits: TonInfo.fractionDigits
      )
      amountOfJettons = amount
    } else {
      let (amount, fractionalDigits) = amountConverter.inputStringToAmount(
        input: input,
        targetFractionalDigits: TonInfo.fractionDigits
      )
      let converted = amountConverter.currencyAmountToToken(
        amount: amount,
        fractionalDigits: fractionalDigits,
        rate: rate,
        currency: currency
      )
      
      amountOfJettons = converted.0.short(to: converted.1 - TonInfo.fractionDigits)
    }
    
    lpJettonAmount = amountOfJettons
    updateConvertedValue()
    updateIsMaxIfNeeded()
  }
  
  public func getOptionsListModel() -> StakingOptionsListModel? {
    nil
  }
  
  public func getStakeConfirmationItem() -> StakingConfirmationItem {
    return .init(operatiom: .withdraw(stakingPool), amount: lpJettonAmount, isMax: isMaxAmount)
  }
  
  private var isTokenAmountInput = true {
    didSet {
      didChangeInputMode()
    }
  }
  
  private var lpJettonAmount: BigUInt = .zero {
    didSet {
      didUpdateLpJettonAmount()
    }
  }
  
  private var isMaxAmount = false {
    didSet {
      didToggleMax()
    }
  }
  
  private var stakingPools: [StakingPool] = []
  private var rate: Rates.Rate?
  private var currency: Currency = .USD
  private var shouldUpdateInput: Bool = true
  
  private var validationTimer: Timer?
  private var validationEndTime: TimeInterval?
  
  private let walletStore: WalletsStore
  private let walletBalanceStore: WalletBalanceStore
  private let currencyStore: CurrencyStore
  private let ratesStore: RatesStore
  private let amountFormatter: AmountFormatter
  private let decimalFormatter: DecimalAmountFormatter
  private let stakingPoolsService: StakingPoolsService
  private let stakingPoolsMapper: StakingPoolsMapper = .init()
  private let amountConverter: StakingEditAmountConverter
  
  init(
    stakingPool: StakingPool,
    walletStore: WalletsStore,
    walletBalanceStore: WalletBalanceStore,
    ratesStore: RatesStore,
    currencyStore: CurrencyStore,
    amountFormatter: AmountFormatter,
    decimalFormatter: DecimalAmountFormatter,
    amountConverter: StakingEditAmountConverter,
    stakingPoolsService: StakingPoolsService
  ) {
    self.stakingPool = stakingPool
    self.walletStore = walletStore
    self.walletBalanceStore = walletBalanceStore
    self.ratesStore = ratesStore
    self.currencyStore = currencyStore
    self.amountFormatter = amountFormatter
    self.decimalFormatter = decimalFormatter
    self.amountConverter = amountConverter
    self.stakingPoolsService = stakingPoolsService
  }
}

// MARK: - Private methods

private extension StakingWithdrawEditAmountController {
  func updateRates() {
    let rates = ratesStore.getRates(jettons: []).ton
    rate = rates.first(where: { $0.currency == currency })
  }
  
  func updateAvailableStakingPools() {
    stakingPools = (try? stakingPoolsService.getPools(
      address: walletStore.activeWallet.address,
      isTestnet: walletStore.activeWallet.isTestnet
    )) ?? []
  }
  
  func updateMaximumFractionDigits() {
    let fractionDigits: Int
    if isTokenAmountInput {
      fractionDigits = TonInfo.fractionDigits
    } else {
      fractionDigits = 2
    }
    
    didUpdateMaximumFractionDigits?(fractionDigits)
  }
  
  func didChangeInputMode() {
    updateMaximumFractionDigits()
    updateInputValue()
    updateConvertedValue()
  }
  
  func updateInputValue() {
      let inputValue: String
      let symbol: String
      
      if isTokenAmountInput {
        let fractionDigits = TonInfo.fractionDigits
        let formatted = amountFormatter.formatAmount(
          lpJettonAmount,
          fractionDigits: fractionDigits,
          maximumFractionDigits: fractionDigits
        )
        
        inputValue = formatted
        symbol = TonInfo.symbol
      } else {
        let converted = amountConverter.tokenAmountToCurrency(amount: lpJettonAmount, token: .ton, rate: rate)
        let formatted = amountFormatter.formatAmount(
          converted.0,
          fractionDigits: converted.1,
          maximumFractionDigits: 2
        )
        inputValue = formatted
        symbol = currency.code
      }
    
    didUpdateInputValue?(inputValue)
    didUpdateInputSymbol?(symbol)
  }
  
  func didUpdateLpJettonAmount() {
    Task {
      let wallet = walletStore.activeWallet
      let balance: Balance
      do {
        balance = try await walletBalanceStore.getBalanceState(wallet: wallet).walletBalance.balance
      } catch {
        balance = Balance(tonBalance: TonBalance(amount: 0), jettonsBalance: [], stakingBalance: [])
      }
      
      await MainActor.run {
        updateRemaining(balance: balance)
      }
    }
  }
  
  func updateRemaining(balance: Balance) {
    let balanceAmount = balance.stakingBalance.first(where: { $0.pool.address == stakingPool.address })?.amount ?? 0
    
    let remaining: StakingRemaining
    if balanceAmount >= lpJettonAmount {
      let remainingAmount = balanceAmount - lpJettonAmount
      let formatted = amountFormatter.formatAmount(
        remainingAmount,
        fractionDigits: TonInfo.fractionDigits,
        maximumFractionDigits: 2,
        symbol: TonInfo.symbol
      )
      
      remaining = .remaining(formatted)
    } else {
      remaining = .insufficient
    }
    
    didUpdateRemaining?(remaining)
    updatePrimaryButton(remaining: remaining)
  }
  
  func updatePrimaryButton(remaining: StakingRemaining) {
    let isEmptyInput = lpJettonAmount.isZero
    guard !isEmptyInput else {
      primaryAction.isEnable = false
      primaryAction.action = .confirm
      didUpdatePrimaryAction?(primaryAction)
      return
    }
    
    switch remaining {
    case .insufficient:
      primaryAction.action = .confirm
      primaryAction.isEnable = false
    case .lessThenMinDeposit, .remaining:
      primaryAction.action = .confirm
      primaryAction.isEnable = true
    }
    
    didUpdatePrimaryAction?(primaryAction)
  }
  
  func updateConvertedValue() {
    let convertedValue: String
    if isTokenAmountInput {
      let converted =  amountConverter.tokenAmountToCurrency(
        amount: lpJettonAmount,
        token: .ton,
        rate: rate
      )
      let formatted = amountFormatter.formatAmount(
        converted.0,
        fractionDigits: converted.1,
        maximumFractionDigits: 2
      )
      
      convertedValue = "\(formatted) \(currency.code)"
    } else {
      let formatted = amountFormatter.formatAmount(
        lpJettonAmount,
        fractionDigits: TonInfo.fractionDigits,
        maximumFractionDigits: 2
      )
      
      convertedValue = "\(formatted) \(TonInfo.symbol)"
    }
    
    didUpdateIsHiddenSwapIcon?(lpJettonAmount != .zero)
    didUpdateConvertedValue?(convertedValue)
  }
  
  func didToggleMax() {
    Task {
      if !shouldUpdateInput {
        shouldUpdateInput.toggle()
        return
      }
      
      let lpJettonsAmount: BigUInt
      if isMaxAmount {
        let wallet = walletStore.activeWallet
        let balance: Balance
        do {
          balance = try await walletBalanceStore.getBalanceState(wallet: wallet).walletBalance.balance
        } catch {
          balance = Balance(tonBalance: TonBalance(amount: 0), jettonsBalance: [], stakingBalance: [])
        }
        
        lpJettonsAmount = balance.stakingBalance.first(where: { $0.pool == stakingPool })?.amount ?? 0
      } else {
        lpJettonsAmount = .zero
      }
      
      await MainActor.run {
        lpJettonAmount = lpJettonsAmount
        updateInputValue()
        updateConvertedValue()
      }
    }
  }
  
  func updateIsMaxIfNeeded() {
    if isMaxAmount {
      shouldUpdateInput = false
      isMaxAmount = false
      didResetMax?()
    }
  }
  
  func startValidationTimer() {
    stopValidationCycleTimer()
    
    validationEndTime = TimeInterval(stakingPool.cycleEnd)
    updateEndCycleTime()
    
    validationTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true, block: { [weak self] timer in
      self?.updateEndCycleTime()
    })
  }
  
  func stopValidationCycleTimer() {
    validationTimer?.invalidate()
    validationTimer = nil
  }
  
  func updateEndCycleTime() {
    guard let endTime = validationEndTime else { return }
    let remainingTime = max(0, endTime - Date().timeIntervalSince1970)
    if remainingTime <= 0 {
      stopValidationCycleTimer()
    }
    
    let timeString = timeString(from: remainingTime)
    didUpdateProviderModel?(.validationCycleEnding(timeString))
  }
  
  func timeString(from interval: TimeInterval) -> String {
    let hours = Int(interval) / 3600
    let minutes = (Int(interval) % 3600) / 60
    let seconds = Int(interval) % 60
    return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
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

private extension String {
  static let moduleTitle = "Unstake"
}
