import Foundation
import TonSwift
import BigInt
import TKUIKit

public final class StakingDepositEditAmountController: StakingEditAmountController {
  public var didUpdateTitle: ((String) -> Void)?
  public var didUpdateConvertedValue: ((String) -> Void)?
  public var didUpdateInputValue: ((String?) -> Void)?
  public var didUpdateInputSymbol: ((String?) -> Void)?
  public var didUpdateMaximumFractionDigits: ((Int) -> Void)?
  public var didUpdateIsContinueEnabled: ((Bool) -> Void)?
  public var didUpdateRemaining: ((StakingRemaining) -> Void)?
  public var didUpdateIsHiddenSwapIcon: ((Bool) -> Void)?
  public var didUpdateProviderModel: ((ProviderModel) -> Void)?
  public var didResetMax: (() -> Void)?

  private let token: Token
  public var stakingPool: StakingPool {
    didSet {
      updateStakingPoolItem()
    }
  }
  
  private var stakingPools: [StakingPool] = []
  private var rate: Rates.Rate?
  private var currency: Currency = .USD
  private var shouldUpdateInput: Bool = true
  private var isMaxAmount = false {
    didSet {
      didToggleMax()
    }
  }
  
  private var tokenAmount: BigUInt = .zero {
    didSet {
      didUpdateTokenAmount()
    }
  }
    
  private let walletStore: WalletsStore
  private let walletBalanceStore: WalletBalanceStore
  private let currencyStore: CurrencyStore
  private let ratesStore: RatesStore
  private let amountFormatter: AmountFormatter
  private let decimalFormatter: DecimalAmountFormatter
  private let stakingPoolsService: StakingPoolsService
  private let stakingPoolsMapper: StakingPoolsMapper = .init()
  private let amountConverter: StakingEditAmountConverter
  
  private var isTokenAmountInput = true {
    didSet {
      didChangeInputMode()
    }
  }
  
  init(
    depositModel: DepositModel,
    walletStore: WalletsStore,
    walletBalanceStore: WalletBalanceStore,
    ratesStore: RatesStore,
    currencyStore: CurrencyStore,
    amountFormatter: AmountFormatter,
    decimalFormatter: DecimalAmountFormatter,
    amountConverter: StakingEditAmountConverter,
    stakingPoolsService: StakingPoolsService
  ) {
    self.token = depositModel.token
    self.stakingPool = depositModel.pool
    self.walletStore = walletStore
    self.walletBalanceStore = walletBalanceStore
    self.ratesStore = ratesStore
    self.currencyStore = currencyStore
    self.amountFormatter = amountFormatter
    self.decimalFormatter = decimalFormatter
    self.amountConverter = amountConverter
    self.stakingPoolsService = stakingPoolsService
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
        didUpdateTokenAmount()
        updateStakingPoolItem()
      }
    }
  }
  
  public func toggleMode() {
    isTokenAmountInput.toggle()
  }
  
  public func toggleMax() {
    isMaxAmount.toggle()
  }
  
  public func setStakingPool(_ pool: StakingPool) {
    stakingPool = pool
  }
  
  public func setInput(_ input: String) {
    let amountOfTokens: BigUInt
    
    if isTokenAmountInput {
      let (amount, _) = amountConverter.inputStringToAmount(
        input: input,
        targetFractionalDigits: token.fractionDigits
      )
      amountOfTokens = amount
    } else {
      let (amount, fractionalDigits) = amountConverter.inputStringToAmount(
        input: input,
        targetFractionalDigits: token.fractionDigits
      )
      let converted = amountConverter.currencyAmountToToken(
        amount: amount,
        fractionalDigits: fractionalDigits,
        rate: rate,
        currency: currency
      )
      
      amountOfTokens = converted.0.short(to: converted.1 - token.fractionDigits)
    }
    
    tokenAmount = amountOfTokens
    updateConvertedValue()
    updateIsMaxIfNeeded()
    updateStakingPoolItem()
  }
  
  public func getOptionsListModel() -> StakingOptionsListModel? {
    let poolImplementations = StakingPool.Implementation.Kind.allCases.map { kind in
      let pools = self.stakingPools.filterByPoolKind(kind)
      return stakingPoolsMapper.mapToPoolType(stakingPools: pools)
    }

    return .init(listType: .nested(poolImplementations.compactMap { $0 }))
  }
  
  public func getStakeConfirmationItem() -> StakingConfirmationItem {
    let depositModel = DepositModel(pool: stakingPool, token: token)
    return .init(operatiom: .deposit(depositModel), amount: tokenAmount)
  }
}

// MARK: - Private methods

private extension StakingDepositEditAmountController {
  func updateAvailableStakingPools() {
    stakingPools = (try? stakingPoolsService.getPools(
      address: walletStore.activeWallet.address,
      isTestnet: walletStore.activeWallet.isTestnet
    )) ?? []
  }
  
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
          balance = try await walletBalanceStore.getBalanceState(wallet: wallet).walletBalance.balance
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
        balance = try await walletBalanceStore.getBalanceState(wallet: wallet).walletBalance.balance
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
    let balanceAmount: BigUInt
    let tokenSymbol: String?
    let fractionalDigits: Int
    let minDeposit = BigInt(integerLiteral: stakingPool.minStake)
    
    switch token {
    case .ton:
      balanceAmount = BigUInt(balance.tonBalance.amount)
      tokenSymbol = token.symbol
      fractionalDigits = token.fractionDigits
    case .jetton(let jettonItem):
      balanceAmount = balance.jettonsBalance.first(where: { $0.item.jettonInfo == jettonItem.jettonInfo })?.quantity ?? 0
      tokenSymbol = jettonItem.jettonInfo.symbol
      fractionalDigits = jettonItem.jettonInfo.fractionDigits
    }
    
    let remaining: StakingRemaining
    if tokenAmount != .zero, tokenAmount < minDeposit, tokenAmount <= balanceAmount {
      let formatted = amountFormatter.formatAmount(
        minDeposit,
        fractionDigits: fractionalDigits,
        maximumFractionDigits: fractionalDigits
      )
      remaining = .lessThenMinDeposit("\(formatted) \(token.symbol)")
    } else if balanceAmount >= tokenAmount {
      let remainingAmount = balanceAmount - tokenAmount
      let formatted = amountFormatter.formatAmount(
        remainingAmount,
        fractionDigits: fractionalDigits,
        maximumFractionDigits: 2,
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
    
    let minDeposit = BigInt(integerLiteral: stakingPool.minStake)
    let balanceAmount: BigUInt
    
    switch token {
    case .ton:
      balanceAmount = BigUInt(balance.tonBalance.amount)
    case .jetton(let jettonItem):
      balanceAmount = balance.jettonsBalance.first(where: { $0.item.jettonInfo == jettonItem.jettonInfo })?.quantity ?? 0
    }
    
    let isBalanceValid = balanceAmount >= tokenAmount
    let isMoreThenMinimumDeposit = tokenAmount >= minDeposit
    
    didUpdateIsContinueEnabled?(isBalanceValid && isMoreThenMinimumDeposit)
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
      fractionDigits = 2
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
        let converted = amountConverter.tokenAmountToCurrency(
          amount: tokenAmount,
          token: token,
          rate: rate
        )
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
  
  func updateConvertedValue() {
    let convertedValue: String
    if isTokenAmountInput {
      let converted =  amountConverter.tokenAmountToCurrency(
        amount: tokenAmount,
        token: token,
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
        tokenAmount,
        fractionDigits: token.fractionDigits,
        maximumFractionDigits: 2
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
  
  func updateStakingPoolItem() {
    var apyProfitFormatted: String?
    let apyProfit = amountConverter.apy(stakingPool.apy, investing: tokenAmount)
    if apyProfit >= .OneTon {
      apyProfitFormatted = amountFormatter.formatAmount(
        apyProfit,
        fractionDigits: token.fractionDigits,
        maximumFractionDigits: 2
      ) + " \(token.symbol)"
    }
    
    let apyPercents = decimalFormatter.format(amount: stakingPool.apy, maximumFractionDigits: 2)
    let minDepoAmount = amountFormatter.formatAmount(
      BigInt(stakingPool.minStake),
      fractionDigits: token.fractionDigits,
      maximumFractionDigits: token.fractionDigits
    )
    
    let isMax = stakingPools.mostProfitablePool?.address == stakingPool.address
    
    let item = StakingEditAmountPoolItem(
      address: stakingPool.address,
      name: stakingPool.name,
      icon: .fromResource,
      implementation: stakingPool.implementation.type,
      profit: apyProfitFormatted,
      apyPercents: "\(apyPercents)%",
      minDepositAmount: "\(minDepoAmount) \(token.symbol)",
      isMaxAPY: isMax
    )
    
    didUpdateProviderModel?(.pool(item))
  }
}

private extension BigUInt {
  static let zero: Self = .init(integerLiteral: .zero)
  static let OneTon: Self = .init(integerLiteral: 1_000_000_000)
  
  func short(to count: Int) -> BigUInt {
    let divider = BigUInt(stringLiteral: "1" + String(repeating: "0", count: count))
    let newValue = self / divider
    return newValue
  }
}

private extension String {
  static let moduleTitle = "Stake"
}
