import Foundation
import KeeperCore
import BigInt

final class BatteryRechargeModel {
  
  enum OptionItem: Equatable {
    struct Prefilled: Equatable {
      let identifier: String
      let chargesCount: Int
      let tokenAmount: BigUInt
      let tokenSymbol: String
      let tokenDigits: Int
      let fiatAmount: Decimal
      let currency: Currency
      let batteryPercent: CGFloat
      let isEnable: Bool
    }
    
    case prefilled(Prefilled)
    case custom
    
    var identifier: String {
      switch self {
      case .prefilled(let prefilled):
        prefilled.identifier
      case .custom:
        "custom"
      }
    }
    
    var isEnable: Bool {
      switch self {
      case .prefilled(let prefilled):
        prefilled.isEnable
      case .custom:
        true
      }
    }
    
    var batteryPercent: CGFloat {
      switch self {
      case .prefilled(let prefilled):
        return prefilled.batteryPercent
      case .custom:
        return 0
      }
    }
  }

  var didUpdateOptionItems: (() -> Void)?
  private(set) var optionsItems = [OptionItem]() {
    didSet { didUpdateOptionItems?() }
  }
  
  var didUpdateIsContinueEnable: (() -> Void)?
  private(set) var isContinueEnable = false {
    didSet { didUpdateIsContinueEnable?() }
  }
  
  var didUpdateIsCustomInputEnable: (() -> Void)?
  private(set) var isCustomInputEnable = false {
    didSet { didUpdateIsCustomInputEnable?() }
  }
  
  var didUpdateToken: (() -> Void)?
  var didUpdateRate: (() -> Void)?
  
  var selectedOptionItem: OptionItem? {
    didSet {
      switch selectedOptionItem {
      case .prefilled(let prefilled):
        isCustomInputEnable = false
        amount = prefilled.tokenAmount
      case .custom:
        isCustomInputEnable = true
        amount = 0
      case nil:
        isCustomInputEnable = false
        amount = 0
      }
    }
  }
  
  var didUpdateBalance: (() -> Void)?
  var balance: BigUInt {
    let balance = balanceStore.getState()[wallet]?.walletBalance.balance
    switch token {
    case .ton:
      return BigUInt(balance?.tonBalance.amount ?? 0)
    case .jetton(let jettonItem):
      return (balance?.jettonsBalance.first(where: { $0.item == jettonItem })?.quantity ?? 0)
    }
  }
  
  var amount: BigUInt = 0 {
    didSet {
      updateIsContinueEnable()
    }
  }
  
  var token: Token {
    didSet {
      start()
      
    }
  }
  
  var promocode: String?
  var recipient: Recipient? {
    didSet {
      updateIsContinueEnable()
    }
  }
  
  private(set) var tonChargeRate: NSDecimalNumber = 1 {
    didSet {
      didUpdateRate?()
    }
  }
  private(set) var chargeTonRate: NSDecimalNumber = 1
  
  private let wallet: Wallet
  private let balanceStore: BalanceStore
  private let currencyStore: CurrencyStore
  private let tonRatesStore: TonRatesStore
  private let batteryService: BatteryService
  private let configuration: Configuration
  let isGift: Bool
  
  init(token: Token,
       wallet: Wallet,
       balanceStore: BalanceStore,
       currencyStore: CurrencyStore,
       tonRatesStore: TonRatesStore,
       batteryService: BatteryService,
       configuration: Configuration,
       isGift: Bool) {
    self.token = token
    self.wallet = wallet
    self.balanceStore = balanceStore
    self.currencyStore = currencyStore
    self.tonRatesStore = tonRatesStore
    self.batteryService = batteryService
    self.configuration = configuration
    self.isGift = isGift
    
    configuration.addUpdateObserver(self) { observer in
      DispatchQueue.main.async {
        observer.updateOptionsItems()
      }
    }
    balanceStore.addObserver(self) { observer, event in
      switch event {
      case .didUpdateBalanceState(let wallet):
        guard wallet == observer.wallet else { return }
        DispatchQueue.main.async {
          observer.updateOptionsItems()
          observer.didUpdateBalance?()
        }
      }
    }
    tonRatesStore.addObserver(self) { observer, event in
      switch event {
      case .didUpdateTonRates:
        guard wallet == observer.wallet else { return }
        DispatchQueue.main.async {
          observer.updateOptionsItems()
        }
      }
    }
  }
  
  func getConfirmationPayload() -> BatteryRechargePayload {
    BatteryRechargePayload(
      token: token,
      amount: amount,
      promocode: promocode,
      recipient: recipient
    )
  }
  
  func start() {
    calculateTonChargeRate()
    updateOptionsItems()
    updateIsContinueEnable()
    didUpdateToken?()
    didUpdateRate?()
  }
  
  private func calculateTonChargeRate() {
    let methods = batteryService.getRechargeMethods(wallet: wallet, includeRechargeOnly: false)
    guard let method: BatteryRechargeMethod = {
      switch token {
      case .ton:
        return methods.first(where: { $0.token == .ton })
      case .jetton(let jettonItem):
        return methods.first(where: { $0.jettonMasterAddress == jettonItem.jettonInfo.address })
      }
    }(), let batteryMeanFees = configuration.batteryMeanFeesDecimaNumber else {
      tonChargeRate = 1
      return
    }
    
    let methodRate = method.rate
    let chargeTonRate = batteryMeanFees
      .dividing(by: methodRate, 
                withBehavior: NSDecimalNumberHandler.multiplyingRoundBehaviour)
    let tonChargeRate = NSDecimalNumber(1)
      .dividing(by: chargeTonRate,
                withBehavior: NSDecimalNumberHandler.multiplyingRoundBehaviour)
    self.tonChargeRate = tonChargeRate
    self.chargeTonRate = chargeTonRate
  }

  private func calculateTokenAmount(chargesCount: Int) -> BigUInt {
    let value = chargeTonRate
      .multiplying(by: NSDecimalNumber(value: chargesCount))
      .multiplying(byPowerOf10: Int16(token.fractionDigits))
      .rounding(accordingToBehavior: NSDecimalNumberHandler.zeroRoundBehaviour)
      .uint64Value
    
    return BigUInt(value)
  }
  
  private func calculateFiatAmount(tokenAmount: BigUInt, currency: Currency, rates: Rates.Rate?) -> Decimal {
    guard let rates else { return 0 }
    return RateConverter().convertToDecimal(amount: tokenAmount, amountFractionLength: token.fractionDigits, rate: rates)
  }
  
  private func updateIsContinueEnable() {
    let balance = balanceStore.getState()[wallet]?.walletBalance.balance
    let isAmountAvailable: Bool
    switch token {
    case .ton:
      isAmountAvailable = (balance?.tonBalance.amount ?? 0) >= amount
    case .jetton(let jettonItem):
      isAmountAvailable = (balance?.jettonsBalance.first(where: { $0.item == jettonItem })?.quantity ?? 0) >= amount
    }
    self.isContinueEnable = isAmountAvailable && amount > 0 && (!isGift || (isGift && recipient != nil) )
  }
  
  private func updateOptionsItems() {
    let currency = currencyStore.getState()
    let balance = balanceStore.getState()[wallet]?.walletBalance.balance
    let rates: Rates.Rate? = {
      switch self.token {
      case .ton:
        let tonRates = tonRatesStore.getState().first(where: { $0.currency == currency })
        return tonRates
      case .jetton(let jettonItem):
        let rate = balance?
          .jettonsBalance
          .first(where: { $0.item == jettonItem })?
          .rates[currency]
        return rate
      }
    }()
    
    var items = BatteryRechargeItem.allCases.map { rechargeItem -> OptionItem in
      let tokenAmount = calculateTokenAmount(
        chargesCount: rechargeItem.chargesCount
      )
      
      let isEnable = {
        switch token {
        case .ton:
          (balance?.tonBalance.amount ?? 0) >= tokenAmount
        case .jetton(let jettonItem):
          (balance?.jettonsBalance.first(where: { $0.item == jettonItem })?.quantity ?? 0) >= tokenAmount
        }
      }()
      
      if rechargeItem.rawValue == selectedOptionItem?.identifier, !isEnable {
        self.selectedOptionItem = nil
      }

      let fiatAmount = calculateFiatAmount(tokenAmount: tokenAmount, currency: currency, rates: rates)
      
      return OptionItem.prefilled(
        OptionItem.Prefilled(
          identifier: rechargeItem.rawValue,
          chargesCount: rechargeItem.chargesCount,
          tokenAmount: calculateTokenAmount(chargesCount: rechargeItem.chargesCount),
          tokenSymbol: token.symbol,
          tokenDigits: token.fractionDigits,
          fiatAmount: fiatAmount,
          currency: currency,
          batteryPercent: rechargeItem.batteryPercent,
          isEnable: isEnable
        )
      )
    }
    items.append(.custom)
    self.optionsItems = items
  }
}


private extension NSDecimalNumberHandler {
  static var multiplyingRoundBehaviour: NSDecimalNumberHandler {
    return NSDecimalNumberHandler(
      roundingMode: .plain,
      scale: 20,
      raiseOnExactness: false,
      raiseOnOverflow: false,
      raiseOnUnderflow: false,
      raiseOnDivideByZero: false
    )
  }
  
  static var roundBehaviour: NSDecimalNumberHandler {
    return NSDecimalNumberHandler(
      roundingMode: .plain,
      scale: 2,
      raiseOnExactness: false,
      raiseOnOverflow: false,
      raiseOnUnderflow: false,
      raiseOnDivideByZero: false
    )
  }
  
  static var zeroRoundBehaviour: NSDecimalNumberHandler {
    return NSDecimalNumberHandler(
      roundingMode: .plain,
      scale: 0,
      raiseOnExactness: false,
      raiseOnOverflow: false,
      raiseOnUnderflow: false,
      raiseOnDivideByZero: false
    )
  }
}
