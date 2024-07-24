import Foundation
import KeeperCore
import BigInt
import TonSwift

final class StakingDepositInputModel: StakingInputModel {
  
  // MARK: - StakingInputModel
  
  var title: String {
    "Stake"
  }
  var didUpdateIsMax: ((Bool) -> Void)?
  var didUpdateConvertedItem: ((StakingInputModelConvertedItem) -> Void)?
  var didUpdateInputItem: ((StakingInputInputItem) -> Void)?
  var didUpdateRemainingItem: ((StakingInputRemainingItem) -> Void)?
  var didUpdateButtonItem: ((StakingInputButtonItem) -> Void)?
  var didUpdatePoolInfoItem: ((StakingInputPoolInfoItem?) -> Void)?
  
  // MARK: - State
  
  private(set) var selectedStackingPoolInfo: StackingPoolInfo? {
    didSet {
      updateButton()
      updateStakingPool()
    }
  }
  private var mostProfitableStackingPoolInfo: StackingPoolInfo?
  private var convertedBalance: ConvertedBalance? {
    didSet {
      if isMaxAmount {
        didToggleIsMax()
      }
      updateInputItem()
      updateConvertedItem()
      updateButton()
    }
  }
  private var isTonInput = true {
    didSet {
      updateInputItem()
      updateConvertedItem()
    }
  }
  private var isMaxAmount = false
  private var tonAmount: BigUInt = .zero {
    didSet {
      updateButton()
      updateConvertedItem()
      updateRemainingItem()
      updateStakingPool()
      toggleMaxIfNeeded()
      
    }
  }
  private var tonRates: [Rates.Rate] = [] {
    didSet {
      updateConvertedItem()
    }
  }
  private var currency: Currency?
  
  private let queue = DispatchQueue(label: "StakingDepositInputModelQueue")
  
  // MARK: - Dependencies
  
  private let wallet: Wallet
  private let balanceStore: ConvertedBalanceStoreV2
  private let stakingPoolsStore: StakingPoolsStore
  private let tonRatesStore: TonRatesStoreV2
  private let currencyStore: CurrencyStoreV2
  
  // MARK: - Init
  
  init(wallet: Wallet, 
       balanceStore: ConvertedBalanceStoreV2,
       stakingPoolsStore: StakingPoolsStore,
       tonRatesStore: TonRatesStoreV2,
       currencyStore: CurrencyStoreV2) {
    self.wallet = wallet
    self.balanceStore = balanceStore
    self.stakingPoolsStore = stakingPoolsStore
    self.tonRatesStore = tonRatesStore
    self.currencyStore = currencyStore
  }
  
  func start() {
    queue.async {
      self.stakingPoolsStore.addObserver(
        self,
        notifyOnAdded: false) { observer, newState, oldState in
          observer.didUpdateStakingPools(newState)
        }
      self.tonRatesStore.addObserver(
        self,
        notifyOnAdded: false) { observer, newState, oldState in
          observer.didUpdateTonRates(newState)
        }
      self.balanceStore.addObserver(
        self, notifyOnAdded: false) { observer, newState, oldState in
          observer.didUpdateBalance(newState)
        }
      self.setInitialBalance()
      self.setInitialStakingPool()
      self.setInitialCurrency()
      self.setInitialTonRates()
      self.updateButton()
      self.updateInputItem()
      self.updateConvertedItem()
      self.updateRemainingItem()
    }
  }
  
  func didEditAmountInput(_ input: String) {
    queue.async { [weak self] in
      guard let self else { return }
      if isTonInput {
        let (amount, _) = inputStringToAmount(
          input: input,
          targetFractionalDigits: TonInfo.fractionDigits
        )
        tonAmount = amount
      } else {
        let (amount, fractionalDigits) = inputStringToAmount(
          input: input,
          targetFractionalDigits: 2
        )
        if let currency = self.currency, let rate = tonRates.first(where: { $0.currency == currency }) {
          let reversedRate = Rates.Rate(currency: currency, rate: 1/rate.rate, diff24h: nil)
          let rateConverter = RateConverter()
          let (amount, fractionalDigits) = rateConverter.convert(
            amount: amount, 
            amountFractionLength: fractionalDigits,
            rate: reversedRate
          )
          let divider = BigUInt(stringLiteral: "1" + String(repeating: "0", count: fractionalDigits - TonInfo.fractionDigits))
          self.tonAmount = amount / divider
        } else {
          self.tonAmount = 0
        }
      }
    }
  }
  
  func toggleInputMode() {
    queue.async {
      self.isTonInput.toggle()
    }
  }
  
  func toggleIsMax() {
    queue.async {
      self.isMaxAmount.toggle()
      self.didToggleIsMax()
    }
  }
  
  func setSelectedStackingPool(_ pool: StackingPoolInfo) {
    queue.async {
      self.selectedStackingPoolInfo = pool
    }
  }
  
  func getPickerSections(completion: @escaping (StakingListModel) -> Void) {
    queue.async {
      guard let walletAddress = try? self.wallet.friendlyAddress,
      let pools = self.stakingPoolsStore.getState()[walletAddress] else {
        return
      }
      
      let liquidPools = pools.filterByPoolKind(.liquidTF)
        .sorted(by: { $0.apy > $1.apy })
      let whalesPools = pools.filterByPoolKind(.whales)
        .sorted(by: { $0.apy > $1.apy })
      let tfPools = pools.filterByPoolKind(.tf)
        .sorted(by: { $0.apy > $1.apy })
      
      var sections = [StakingListSection]()
      
      sections.append(
        StakingListSection(
          title: .liquidStakingTitle,
          items: liquidPools.enumerated().map { index, pool in
              .pool(StakingListPool(pool: pool, isMaxAPY: index == 0))
          }
        )
      )
      
      func createGroup(_ pools: [StackingPoolInfo]) -> StakingListItem? {
        guard !pools.isEmpty else { return nil }
        let groupName = pools[0].implementation.name
        let groupImage = pools[0].implementation.icon
        let groupApy = pools[0].apy
        let minAmount = BigUInt(UInt64(pools[0].minStake))
        return StakingListItem.group(
          StakingListGroup(
            name: groupName,
            image: groupImage,
            apy: groupApy,
            minAmount: minAmount,
            items: pools.enumerated().map { StakingListPool(pool: $1, isMaxAPY: $0 == 0) }
          )
        )
      }
      
      sections.append(
        StakingListSection(
          title: .otherTitle, items: [whalesPools, tfPools].compactMap { createGroup($0) }
        )
      )

      completion(
        StakingListModel(
          title: "Options",
          sections: sections,
          selectedPool: self.selectedStackingPoolInfo
        )
      )
    }
  }
  
  func getStakingConfirmationItem(completion: @escaping (StakingConfirmationItem) -> Void) {
    queue.async {
      guard let selectedStackingPoolInfo = self.selectedStackingPoolInfo else { return }
      let item = StakingConfirmationItem(
        operation: .deposit(
          selectedStackingPoolInfo
        ),
        amount: self.tonAmount,
        isMax: self.isMaxAmount
      )
      completion(item)
    }
  }
  
  func setInitialStakingPool() {
    guard let walletAddress = try? wallet.friendlyAddress,
    let pool = stakingPoolsStore.getState()[walletAddress]?.profitablePool else { return }
    self.mostProfitableStackingPoolInfo = pool
    self.selectedStackingPoolInfo = pool
  }
  
  func setInitialCurrency() {
    self.currency = currencyStore.getState()
  }
  
  func setInitialTonRates() {
    self.tonRates = tonRatesStore.getState()
  }
  
  func setInitialBalance() {
    guard let walletAddress = try? wallet.friendlyAddress,
          let balance = balanceStore.getState()[walletAddress] else {
      return
    }
    self.convertedBalance = balance.balance
  }
  
  func didUpdateBalance(_ balances: [FriendlyAddress: ConvertedBalanceState]) {
    queue.async { [weak self] in
      guard let self else { return }
      guard let walletAddress = try? wallet.friendlyAddress else { return }
      self.convertedBalance = balances[walletAddress]?.balance
    }
  }

  func didUpdateStakingPools(_ pools: [FriendlyAddress: [StackingPoolInfo]]) {
    queue.async { [weak self] in
      guard let self else { return }
      guard let walletAddress = try? wallet.friendlyAddress,
            let walletPools = pools[walletAddress],
            !walletPools.isEmpty else {
        self.mostProfitableStackingPoolInfo = nil
        self.selectedStackingPoolInfo = nil
        return
      }
      
      self.mostProfitableStackingPoolInfo = walletPools.profitablePool
      
      if let selectedStackingPoolInfo, let updated = walletPools.first(where: { $0.address == selectedStackingPoolInfo.address }) {
        self.selectedStackingPoolInfo = updated
      } else {
        self.selectedStackingPoolInfo = mostProfitableStackingPoolInfo
      }
    }
  }
  
  func didUpdateTonRates(_ tonRates: [Rates.Rate]) {
    queue.async { [weak self] in
      guard let self else { return }
      self.tonRates = tonRates
    }
  }
  
  func updateButton() {
    var isEnable = false
    defer {
      didUpdateButtonItem?(
        StakingInputButtonItem(
          title: "Continue",
          isEnable: isEnable
        )
      )
    }
    guard let selectedPool = selectedStackingPoolInfo else {
      return
    }
    let isInputNotZero = !tonAmount.isZero
    let isAvailableAmount = tonAmount <= BigUInt(integerLiteral: UInt64((convertedBalance?.tonBalance.tonBalance.amount) ?? 0))
    let isGreaterThanMinimum = tonAmount >= BigUInt(selectedPool.minStake)
    
    isEnable = isInputNotZero && isAvailableAmount && isGreaterThanMinimum
  }
  
  func updateInputItem() {
    let symbol: String
    let maximumFractionDigits: Int
    let amount: BigUInt
    let fractionDigits: Int
    if isTonInput {
      symbol = TonInfo.symbol
      maximumFractionDigits = TonInfo.fractionDigits
      amount = tonAmount
      fractionDigits = TonInfo.fractionDigits
    } else {
      symbol = currency?.code ?? ""
      maximumFractionDigits = 2
      if let rate = tonRates.first(where: { $0.currency == currency }) {
        let converted = RateConverter().convert(
          amount: tonAmount,
          amountFractionLength: TonInfo.fractionDigits,
          rate: rate
        )
        amount = converted.amount
        fractionDigits = converted.fractionLength
      } else {
        amount = 0
        fractionDigits = 2
      }
    }
    let item = StakingInputInputItem(
      amount: amount,
      fractionDigits: fractionDigits,
      symbol: symbol,
      maximumFractionDigits: maximumFractionDigits
    )
    didUpdateInputItem?(item)
  }
  
  func updateConvertedItem() {
    let rateConverter = RateConverter()
    let amount: BigUInt
    let fractionDigits: Int
    let symbol: String
    let isIconHidden = !tonAmount.isZero
    
    if isTonInput {
      symbol = currency?.code ?? ""
      if let rate = tonRates.first(where: { $0.currency == currency }) {
        let converted = rateConverter.convert(
          amount: tonAmount,
          amountFractionLength: TonInfo.fractionDigits,
          rate: rate
        )
        amount = converted.amount
        fractionDigits = converted.fractionLength
      } else {
        amount = 0
        fractionDigits = 2
      }
    } else {
      amount = tonAmount
      fractionDigits = TonInfo.fractionDigits
      symbol = TonInfo.symbol
    }

    didUpdateConvertedItem?(
      StakingInputModelConvertedItem(
        amount: amount,
        fractionDigits: fractionDigits,
        symbol: symbol,
        isIconHidden: isIconHidden
      )
    )
  }
  
  func updateRemainingItem() {
    guard let tonBalance = convertedBalance?.tonBalance.tonBalance.amount else {
      didUpdateRemainingItem?(.insufficient)
      return
    }
    
    guard tonAmount > 0 else {
      let remaining = BigUInt(UInt64(tonBalance)) - tonAmount
      didUpdateRemainingItem?(.remaining(remaining, TonInfo.fractionDigits))
      return
    }
    
    guard tonAmount <= BigUInt(UInt64(tonBalance)) else {
      didUpdateRemainingItem?(.insufficient)
      return
    }
    
    guard let selectedStackingPoolInfo else {
      didUpdateRemainingItem?(.lessThanMinDeposit(0, TonInfo.fractionDigits))
      return
    }
    
    guard tonAmount >= BigUInt(UInt64(selectedStackingPoolInfo.minStake)) else {
      didUpdateRemainingItem?(.lessThanMinDeposit(BigUInt(UInt64(selectedStackingPoolInfo.minStake)), TonInfo.fractionDigits))
      return
    }
    
    let remaining = BigUInt(UInt64(tonBalance)) - tonAmount
    didUpdateRemainingItem?(.remaining(remaining, TonInfo.fractionDigits))
  }
  
  func updateStakingPool() {
    guard let selectedStackingPoolInfo else {
      didUpdatePoolInfoItem?(nil)
      return
    }
    
    let profit: BigUInt = {
      let apy = selectedStackingPoolInfo.apy
      let apyFractionLength = max(Int(-apy.exponent), 0)
      let apyPlain = NSDecimalNumber(decimal: apy).multiplying(byPowerOf10: Int16(apyFractionLength))
      let apyBigInt = BigUInt(stringLiteral: apyPlain.stringValue)
    
      let scalingFactor = BigUInt(100) * BigUInt(10).power(apyFractionLength)
      
      return tonAmount * apyBigInt / scalingFactor
    }()
    
    didUpdatePoolInfoItem?(.poolInfo(
      selectedStackingPoolInfo,
      isMostProfitable: selectedStackingPoolInfo.address == mostProfitableStackingPoolInfo?.address,
      profit: profit)
    )
  }
  
  func toggleMaxIfNeeded() {
    guard let amount = convertedBalance?.tonBalance.tonBalance.amount else {
      return
    }
    isMaxAmount = tonAmount == BigUInt(integerLiteral: UInt64(amount))
    didUpdateIsMax?(isMaxAmount)
  }
  
  func didToggleIsMax() {
    let amount = convertedBalance?.tonBalance.tonBalance.amount ?? 0
    if isMaxAmount {
      tonAmount = BigUInt(integerLiteral: UInt64(amount))
    } else {
      tonAmount = .zero
    }
    updateInputItem()
  }
  
  func inputStringToAmount(input: String, targetFractionalDigits: Int) -> (amount: BigUInt, fractionalDigits: Int) {
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
}

private extension String {
  static var fractionalSeparator: String? {
    Locale.current.decimalSeparator
  }
  
  static let liquidStakingTitle = "Liquid Staking"
  static let otherTitle = "Other"
}
