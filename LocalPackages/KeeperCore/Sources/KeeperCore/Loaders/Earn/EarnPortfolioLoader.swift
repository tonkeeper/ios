import Foundation
import TKLogging

/// Rides every wallet balance load: the Earn positions are part of what the wallet holds, so they
/// refresh whenever its balance does.
struct EarnPortfolioLoader {
    private let api: EarnAPI
    private let store: EarnPortfolioStore
    private let dirtyFlags: EarnPortfolioDirtyFlags
    private let isEnabled: () -> Bool

    init(
        api: EarnAPI,
        store: EarnPortfolioStore,
        dirtyFlags: EarnPortfolioDirtyFlags,
        isEnabled: @escaping () -> Bool
    ) {
        self.api = api
        self.store = store
        self.dirtyFlags = dirtyFlags
        self.isEnabled = isEnabled
    }

    func loadPortfolio(wallet: Wallet, currency: Currency) async {
        guard isEnabled(), let walletId = wallet.earnWalletId else { return }
        var currencies = [currency.code.lowercased()]
        if currency != .defaultCurrency {
            currencies.append(Currency.defaultCurrency.code.lowercased())
        }
        let refresh = await dirtyFlags.isDirty(wallet: wallet)
        do {
            let balance = try await api.walletBalance(walletId: walletId, currencies: currencies, refresh: refresh)
            guard !Task.isCancelled else { return }
            await store.setPortfolio(EarnPortfolio(walletId: walletId, balance: balance), wallet: wallet)
        } catch {
            guard !Task.isCancelled else { return }
            Log.w("earn portfolio load failed", extraInfo: ["wallet": wallet.id, "error": "\(error)"])
            await store.setLoadFailed(wallet: wallet)
        }
    }
}
