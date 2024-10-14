import Foundation
import KeeperCore
import BigInt
import TonSwift

final class BatteryRefillHeaderModel {
  
  struct State {
    enum Charge {
      case notCharged
      case charged(chargesCount: Int, batteryPercent: CGFloat)
    }
    let isBeta: Bool
    let charge: Charge
  }
  
  private let wallet: Wallet
  private let balanceStore: BalanceStore
  private let configurationStore: ConfigurationStore

  init(wallet: Wallet,
       balanceStore: BalanceStore,
       configurationStore: ConfigurationStore) {
    self.wallet = wallet
    self.balanceStore = balanceStore
    self.configurationStore = configurationStore
  }
  
  func getState() -> State {
    let configuration = configurationStore.getConfiguration()
    let isBeta = configurationStore.getConfiguration().isBatteryBeta
    let charge: State.Charge
    if let batteryBalance = balanceStore.getState()[wallet]?.walletBalance.batteryBalance, !batteryBalance.isBalanceZero {
      let chargesCount: Int = {
        guard let meanFees = configuration.batteryMeanFeesDecimaNumber else { return 0 }
        return (batteryBalance.balanceDecimalNumber?.dividing(by: meanFees, withBehavior: NSDecimalNumberHandler.roundBehaviour))?.intValue ?? 0
      }()
      charge = .charged(chargesCount: chargesCount, batteryPercent: batteryBalance.batteryState.percents)
    } else {
      charge = .notCharged
    }
    
    return State(
      isBeta: isBeta,
      charge: charge
    )
  }
}

private extension NSDecimalNumberHandler {
  static var roundBehaviour: NSDecimalNumberHandler {
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

