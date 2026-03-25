import BigInt
import Foundation
import KeeperCore
import TonSwift

final class BatteryRefillHeaderModel {
    var didUpdateState: ((State) -> Void)?

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
    private let batteryCalculation: BatteryCalculation

    init(
        wallet: Wallet,
        balanceStore: BalanceStore,
        batteryCalculation: BatteryCalculation
    ) {
        self.wallet = wallet
        self.balanceStore = balanceStore
        self.batteryCalculation = batteryCalculation

        balanceStore.addObserver(self) { observer, event in
            switch event {
            case let .didUpdateBalanceState(wallet):
                DispatchQueue.main.async {
                    guard wallet == observer.wallet else { return }
                    observer.didUpdateState?(observer.getState())
                }
            }
        }
    }

    func getState() -> State {
        let charge: State.Charge
        if let batteryBalance = balanceStore.getState()[wallet]?.walletBalance.batteryBalance, !batteryBalance.isBalanceZero {
            let chargesCount = batteryCalculation.calculateCharges(tonAmount: batteryBalance.balanceDecimalNumber) ?? 0
            charge = .charged(chargesCount: chargesCount, batteryPercent: batteryBalance.batteryState.percents)
        } else {
            charge = .notCharged
        }

        return State(
            isBeta: false,
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
