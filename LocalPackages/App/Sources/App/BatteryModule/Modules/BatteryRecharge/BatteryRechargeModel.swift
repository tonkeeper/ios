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

  struct State {
    let items: [OptionItem]
    let isContinueButtonEnable: Bool
  }
  
  var didUpdateState: ((State) -> Void)?
  
  var state: State {
    getState()
  }
  
  var amount: BigUInt = 0 {
    didSet {
      didUpdateAmount()
    }
  }
  
  var selectedOption: OptionItem? {
    didSet {
      didUpdateAmount()
    }
  }
  
  private var token: Token
  private var rate: NSDecimalNumber?
  private let wallet: Wallet
  private let balanceStore: BalanceStore
  private let currencyStore: CurrencyStore
  private let tonRatesStore: TonRatesStore
  private let configuration: Configuration
  
  init(token: Token,
       rate: NSDecimalNumber?,
       wallet: Wallet,
       balanceStore: BalanceStore,
       currencyStore: CurrencyStore,
       tonRatesStore: TonRatesStore,
       configuration: Configuration) {
    self.token = token
    self.rate = rate
    self.wallet = wallet
    self.balanceStore = balanceStore
    self.currencyStore = currencyStore
    self.tonRatesStore = tonRatesStore
    self.configuration = configuration
    
    configuration.addUpdateObserver(self) { observer in
      let state = observer.getState()
      observer.didUpdateState?(state)
    }
  }
  
  private func getState() -> State {
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
        chargesCount: rechargeItem.chargesCount,
        rate: rate,
        batteryMeanFees: configuration.batteryMeanFeesDecimaNumber
      )
      
      let isEnable = {
        switch token {
        case .ton:
          (balance?.tonBalance.amount ?? 0) >= tokenAmount
        case .jetton(let jettonItem):
          (balance?.jettonsBalance.first(where: { $0.item == jettonItem })?.quantity ?? 0) >= tokenAmount
        }
      }()

      let fiatAmount = calculateFiatAmount(tokenAmount: tokenAmount, currency: currency, rates: rates)
      
      return OptionItem.prefilled(
        OptionItem.Prefilled(
          identifier: rechargeItem.rawValue,
          chargesCount: rechargeItem.chargesCount,
          tokenAmount: calculateTokenAmount(chargesCount: rechargeItem.chargesCount,
                                            rate: rate,
                                            batteryMeanFees: configuration.batteryMeanFeesDecimaNumber),
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
    return State(items: items, isContinueButtonEnable: isContinueButtonEnabled())
  }
  
  private func isContinueButtonEnabled() -> Bool {
    let balance = balanceStore.getState()[wallet]?.walletBalance.balance
    let isAmountAvailable = {
      switch token {
      case .ton:
        (balance?.tonBalance.amount ?? 0) >= amount
      case .jetton(let jettonItem):
        (balance?.jettonsBalance.first(where: { $0.item == jettonItem })?.quantity ?? 0) >= amount
      }
    }()
    return isAmountAvailable && amount > 0
  }
  
  private func calculateTokenAmount(chargesCount: Int,
                                    rate: NSDecimalNumber?,
                                    batteryMeanFees: NSDecimalNumber?) -> BigUInt {
    guard let rate, let batteryMeanFees else { return 0 }
    let amount = NSDecimalNumber(integerLiteral: chargesCount)
      .multiplying(by: batteryMeanFees, withBehavior: NSDecimalNumberHandler.multiplyingRoundBehaviour)
      .dividing(by: rate, withBehavior: NSDecimalNumberHandler.multiplyingRoundBehaviour)
      .rounding(accordingToBehavior: NSDecimalNumberHandler.roundBehaviour)
      .multiplying(byPowerOf10: Int16(token.fractionDigits))
      .uint64Value
    return BigUInt(integerLiteral: amount)
  }
  
  private func calculateFiatAmount(tokenAmount: BigUInt, currency: Currency, rates: Rates.Rate?) -> Decimal {
    guard let rates else { return 0 }
    return RateConverter().convertToDecimal(amount: tokenAmount, amountFractionLength: token.fractionDigits, rate: rates)
  }
  
  private func didUpdateAmount() {
    let state = getState()
    didUpdateState?(state)
  }
  
  private func didUpdateSelectedOption() {
    
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
}
