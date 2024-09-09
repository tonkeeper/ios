import Foundation
import KeeperCore
import BigInt
import TonSwift

final class StakingInputModelImplementation: StakingInputModel {
  
  // MARK: - StakingInputModel
  
  var title: String {
    configurator.title
  }
  var didUpdateIsMax: ((Bool) -> Void)?
  var didUpdateConvertedItem: ((StakingInputModelConvertedItem) -> Void)?
  var didUpdateInputItem: ((StakingInputInputItem) -> Void)?
  var didUpdateRemainingItem: ((StakingInputRemainingItem) -> Void)?
  var didUpdateButtonItem: ((StakingInputButtonItem) -> Void)?
  var didUpdateDetailsIsHidden: ((Bool) -> Void)?
  
  // MARK: - State
  
  private(set) var selectedStackingPoolInfo: StackingPoolInfo? {
    didSet {
      updateButton()
      updateStakingPool()
      updateRemainingItem()
    }
  }
  private var mostProfitableStackingPoolInfo: StackingPoolInfo?
  private var balanceAmount: UInt64? {
    didSet {
      if isMaxAmount {
        didToggleIsMax()
      }
      updateInputItem()
      updateConvertedItem()
      updateButton()
      updateRemainingItem()
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
  private let detailsInput: StakingInputDetailsModuleInput
  private let configurator: StakingInputModelConfigurator
  private let stakingPoolsStore: StakingPoolsStore
  private let tonRatesStore: TonRatesStore
  private let currencyStore: CurrencyStoreV3
  
  // MARK: - Init
  
  init(wallet: Wallet,
       stakingPoolInfo: StackingPoolInfo? = nil,
       detailsInput: StakingInputDetailsModuleInput,
       configurator: StakingInputModelConfigurator,
       stakingPoolsStore: StakingPoolsStore,
       tonRatesStore: TonRatesStore,
       currencyStore: CurrencyStoreV3) {
    self.wallet = wallet
    self.detailsInput = detailsInput
    self.configurator = configurator
    self.stakingPoolsStore = stakingPoolsStore
    self.tonRatesStore = tonRatesStore
    self.currencyStore = currencyStore
    self.selectedStackingPoolInfo = stakingPoolInfo
  }
  
  func start() {
    queue.async {
      self.stakingPoolsStore.addObserver(self) { observer, event in
        observer.didGetStakingPoolsStoreEvent(event)
      }
      self.tonRatesStore.addObserver(self) { observer, event in
        observer.didGetTonRatesStoreEvent(event)
      }
      self.configurator.didUpdateBalance = { [weak self] balance in
        self?.didUpdateBalance(balance: balance)
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
      self.configurator.stakingPoolInfo = pool
      self.selectedStackingPoolInfo = pool
    }
  }
  
  func getPickerSections(completion: @escaping (StakingListModel) -> Void) {
    queue.async { [wallet] in
      guard let pools = self.stakingPoolsStore.getState()[wallet] else {
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
      guard let item = self.configurator.getStakingConfirmationItem(
        tonAmount: self.tonAmount,
        isMaxAmount: self.isMaxAmount
      ) else { return }
      completion(item)
    }
  }
  
  func setInitialStakingPool() {
    guard selectedStackingPoolInfo == nil else {
      configurator.stakingPoolInfo = selectedStackingPoolInfo
      updateButton()
      updateStakingPool()
      return
    }
    guard let pool = stakingPoolsStore.getState()[wallet]?.profitablePool else { return }
    self.mostProfitableStackingPoolInfo = pool
    self.selectedStackingPoolInfo = pool
    self.configurator.stakingPoolInfo = pool
  }
  
  func setInitialCurrency() {
    self.currency = currencyStore.getState()
  }
  
  func setInitialTonRates() {
    self.tonRates = tonRatesStore.getState()
  }
  
  func setInitialBalance() {
    self.balanceAmount = configurator.getBalance()
  }
  
  func didUpdateBalance(balance: UInt64) {
    queue.async { [weak self] in
      guard let self else { return }
      self.balanceAmount = balance
    }
  }

  func didGetStakingPoolsStoreEvent(_ event: StakingPoolsStore.Event) {
    switch event {
    case .didUpdateStakingPools(_, let wallet):
      guard wallet == wallet else {
        return
      }
      queue.async { [weak self] in
        guard let self else { return }
        guard let pools = self.stakingPoolsStore.getState()[wallet],
              !pools.isEmpty else {
          self.mostProfitableStackingPoolInfo = nil
          self.selectedStackingPoolInfo = nil
          self.configurator.stakingPoolInfo = nil
          return
        }
        
        self.mostProfitableStackingPoolInfo = pools.profitablePool
        
        if let selectedStackingPoolInfo, let updated = pools.first(where: { $0.address == selectedStackingPoolInfo.address }) {
          self.selectedStackingPoolInfo = updated
          self.configurator.stakingPoolInfo = updated
        } else {
          self.selectedStackingPoolInfo = mostProfitableStackingPoolInfo
          self.configurator.stakingPoolInfo = mostProfitableStackingPoolInfo
        }
      }
    }
  }
  
  func didGetTonRatesStoreEvent(_ event: TonRatesStore.Event) {
    switch event {
    case .didUpdateTonRates:
      queue.async {
        self.tonRates = self.tonRatesStore.getState()
      }
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
    isEnable = configurator.isContinueEnable(tonAmount: tonAmount)
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
    let remaining = configurator.getStakingInputRemainingItem(tonAmount: tonAmount)
    didUpdateRemainingItem?(remaining)
  }
  
  func updateStakingPool() {
    guard let selectedStackingPoolInfo else {
      didUpdateDetailsIsHidden?(true)
      return
    }
    
    detailsInput.configureWith(
      stackingPoolInfo: selectedStackingPoolInfo,
      tonAmount: tonAmount,
      isMostProfitable: selectedStackingPoolInfo.address == mostProfitableStackingPoolInfo?.address
    )
    didUpdateDetailsIsHidden?(false)
  }
  
  func toggleMaxIfNeeded() {
    guard let amount = balanceAmount else {
      return
    }
    isMaxAmount = tonAmount == BigUInt(integerLiteral: UInt64(amount))
    didUpdateIsMax?(isMaxAmount)
  }
  
  func didToggleIsMax() {
    let amount = balanceAmount ?? 0
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
