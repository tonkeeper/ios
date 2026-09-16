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
            case refunded(chargesCount: Int)
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
        let batteryBalance = balanceStore.getState()[wallet]?.walletBalance.batteryBalance
        let chargesCount = batteryBalance.flatMap {
            batteryCalculation.calculateCharges(tonAmount: $0.balanceDecimalNumber)
        } ?? 0

        let charge: State.Charge
        switch batteryBalance?.batteryState {
        case let .fill(percents):
            charge = .charged(chargesCount: chargesCount, batteryPercent: percents)
        case .negative:
            charge = .refunded(chargesCount: chargesCount)
        case .empty, .none:
            charge = .notCharged
        }

        return State(
            isBeta: false,
            charge: charge
        )
    }
}
