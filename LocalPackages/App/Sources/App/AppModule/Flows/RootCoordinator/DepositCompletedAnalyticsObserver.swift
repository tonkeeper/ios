import BigInt
import Foundation
import KeeperCore
import TKCore

final class DepositCompletedAnalyticsObserver {
    private let totalBalanceStore: TotalBalanceStore
    private let depositPendingTracker: DepositPendingTracker
    private let analyticsProvider: AnalyticsProvider
    private var lastAmounts: [Wallet: [String: BigUInt]] = [:]

    init(
        totalBalanceStore: TotalBalanceStore,
        depositPendingTracker: DepositPendingTracker,
        analyticsProvider: AnalyticsProvider
    ) {
        self.totalBalanceStore = totalBalanceStore
        self.depositPendingTracker = depositPendingTracker
        self.analyticsProvider = analyticsProvider

        totalBalanceStore.addObserver(self) { observer, event in
            switch event {
            case let .didUpdateTotalBalance(wallet):
                observer.handleUpdate(for: wallet)
            }
        }
    }

    private func handleUpdate(for wallet: Wallet) {
        guard let balance = totalBalanceStore.state[wallet]?.totalBalance?.balance else { return }
        let current = amounts(for: balance)
        if let last = lastAmounts[wallet],
           didIncrease(from: last, to: current),
           depositPendingTracker.consumeIfPending(wallet: wallet)
        {
            analyticsProvider.logDepositCompleted()
        }
        lastAmounts[wallet] = current
    }

    private func amounts(for balance: ManagedBalance) -> [String: BigUInt] {
        var result: [String: BigUInt] = [:]
        for item in balance.tonItems {
            result[item.id] = BigUInt(item.amount)
        }
        for item in balance.pinnedItems + balance.unpinnedItems {
            result[item.identifier] = rawAmount(for: item)
        }
        return result
    }

    private func rawAmount(for item: ProcessedBalanceItem) -> BigUInt {
        switch item {
        case let .ton(item):
            return BigUInt(item.amount)
        case let .jetton(item):
            return item.amount
        case let .staking(item):
            return BigUInt(item.info.amount)
        case let .tronUSDT(item):
            return item.amount
        case let .tronTRX(item):
            return item.amount
        case let .ethena(item):
            return item.amount
        }
    }

    private func didIncrease(from last: [String: BigUInt], to current: [String: BigUInt]) -> Bool {
        current.contains { $0.value > (last[$0.key] ?? 0) }
    }
}
