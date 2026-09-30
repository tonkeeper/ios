import Foundation

/// What refreshing one wallet from the wallets list costs. A multichain wallet earns both: the
/// portfolio total is what the list renders, and the fan-out is what keeps its balance, staking
/// pools and NFTs warm for the screens behind the list.
enum TotalBalanceLoaderTarget: Equatable {
    case portfolioTotal(wallet: Wallet, state: MultichainWalletState)
    case walletBalance(wallet: Wallet)

    var wallet: Wallet {
        switch self {
        case let .portfolioTotal(wallet, _):
            wallet
        case let .walletBalance(wallet):
            wallet
        }
    }
}

extension TotalBalanceLoaderTarget {
    static let freshnessInterval: TimeInterval = 60

    static func from(
        wallets: [Wallet],
        balanceStates: [Wallet: WalletBalanceState],
        portfolioTotals: [Wallet: MultichainPortfolio],
        currencyCode: String,
        hidesDustBalances: Bool = false,
        now: Date
    ) -> [TotalBalanceLoaderTarget] {
        wallets.flatMap { wallet -> [TotalBalanceLoaderTarget] in
            var targets = [TotalBalanceLoaderTarget]()
            if let state = wallet.multichainWalletState,
               needsPortfolioTotal(
                   wallet: wallet,
                   portfolioTotals: portfolioTotals,
                   currencyCode: currencyCode,
                   hidesDustBalances: hidesDustBalances,
                   now: now
               )
            {
                targets.append(.portfolioTotal(wallet: wallet, state: state))
            }
            if needsWalletBalance(wallet: wallet, balanceStates: balanceStates, now: now) {
                targets.append(.walletBalance(wallet: wallet))
            }
            return targets
        }
    }

    private static func needsWalletBalance(
        wallet: Wallet,
        balanceStates: [Wallet: WalletBalanceState],
        now: Date
    ) -> Bool {
        guard let balanceState = balanceStates[wallet] else { return true }
        return balanceState.needsListRefresh(at: now, freshnessInterval: freshnessInterval)
    }

    private static func needsPortfolioTotal(
        wallet: Wallet,
        portfolioTotals: [Wallet: MultichainPortfolio],
        currencyCode: String,
        hidesDustBalances: Bool,
        now: Date
    ) -> Bool {
        guard let total = portfolioTotals[wallet] else { return true }
        let isFresh = now.timeIntervalSince(total.date) < freshnessInterval
        let hasCurrency = total.fiatPrice[currencyCode] != nil
        let hasMatchingFilters = total.hidesDustBalances == hidesDustBalances
        return !isFresh || !hasCurrency || !hasMatchingFilters
    }
}
