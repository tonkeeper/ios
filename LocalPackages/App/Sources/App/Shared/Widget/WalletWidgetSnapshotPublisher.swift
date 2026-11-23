import Foundation
import KeeperCore
import TKFeatureFlags
import TKLocalize
import WidgetKit

/// Keeps the wallet widgets' snapshot in step with what the app shows: the same totals as the wallets
/// list, in the app's currency. Also keeps the assets the price widgets offer.
@MainActor
final class WalletWidgetSnapshotPublisher {
    private let walletsStore: WalletsStore
    private let totalBalanceStore: TotalBalanceStore
    private let portfolioStore: MultichainPortfolioStore
    private let currencyStore: CurrencyStore
    private let appSettingsStore: AppSettingsStore
    private let favoriteAssetsService: TradingFavoriteAssetsService
    private let configuration: Configuration
    private let amountFormatter: AmountFormatter
    private let signedAmountFormatter: AmountFormatter
    private let portfolioFormatting = MultichainPortfolioAmountFormatting()
    private var isPublishScheduled = false
    private var priceAssetsTask: Task<Void, Never>?

    init(
        walletsStore: WalletsStore,
        totalBalanceStore: TotalBalanceStore,
        portfolioStore: MultichainPortfolioStore,
        currencyStore: CurrencyStore,
        appSettingsStore: AppSettingsStore,
        favoriteAssetsService: TradingFavoriteAssetsService,
        configuration: Configuration,
        amountFormatter: AmountFormatter,
        signedAmountFormatter: AmountFormatter
    ) {
        self.walletsStore = walletsStore
        self.totalBalanceStore = totalBalanceStore
        self.portfolioStore = portfolioStore
        self.currencyStore = currencyStore
        self.appSettingsStore = appSettingsStore
        self.favoriteAssetsService = favoriteAssetsService
        self.configuration = configuration
        self.amountFormatter = amountFormatter
        self.signedAmountFormatter = signedAmountFormatter
    }

    deinit {
        priceAssetsTask?.cancel()
        // The coordinator owning this goes away on delete-all before the store event would arrive.
        let walletsStore = walletsStore
        Task { @MainActor in
            guard walletsStore.wallets.isEmpty else { return }
            WalletWidgetSnapshot.empty.save()
            PriceWidgetSnapshot.empty.save()
            WalletWidgetLink.Widget.walletKinds.forEach { WidgetCenter.shared.reloadTimelines(ofKind: $0.kind) }
            WalletWidgetLink.Widget.priceKinds.forEach { WidgetCenter.shared.reloadTimelines(ofKind: $0.kind) }
        }
    }

    func start() {
        let schedule: (WalletWidgetSnapshotPublisher) -> Void = { publisher in
            Task { @MainActor in publisher.schedulePublish() }
        }
        walletsStore.addObserver(self) { publisher, _ in schedule(publisher) }
        totalBalanceStore.addObserver(self) { publisher, _ in schedule(publisher) }
        portfolioStore.addObserver(self) { publisher, _ in schedule(publisher) }
        currencyStore.addObserver(self) { publisher, _ in schedule(publisher) }
        appSettingsStore.addObserver(self) { publisher, event in
            guard case .didUpdateIsSecureMode = event else { return }
            schedule(publisher)
        }
        publish()
    }

    /// Store events come in bursts; one write answers them all.
    private func schedulePublish() {
        guard !isPublishScheduled else { return }
        isPublishScheduled = true
        Task { @MainActor [weak self] in
            await Task.yield()
            self?.isPublishScheduled = false
            self?.publish()
        }
    }

    private func publish() {
        let snapshot = makeSnapshot()
        let previousHasNoWallets = WalletWidgetSnapshot.hasNoWallets
        if snapshot != WalletWidgetSnapshot.load() || snapshot.wallets.isEmpty != previousHasNoWallets {
            snapshot.save()
            WalletWidgetLink.Widget.walletKinds.forEach { WidgetCenter.shared.reloadTimelines(ofKind: $0.kind) }
            // Without wallets the price widgets show a message instead of prices.
            if snapshot.wallets.isEmpty != previousHasNoWallets {
                WalletWidgetLink.Widget.priceKinds.forEach { WidgetCenter.shared.reloadTimelines(ofKind: $0.kind) }
            }
        }
        publishPriceAssets()
    }

    /// The Trade tab tells no one about favorites, so the app also publishes them when it leaves the screen.
    /// Like the Trade tab, it lists them only for a multichain wallet: the favorites are kept for all wallets.
    func publishPriceAssets() {
        let walletAssets = makeWalletAssets()
        let currency = currencyStore.getState().code
        let listsFavorites = (try? walletsStore.activeWallet)?.isMultichain == true
        priceAssetsTask?.cancel()
        priceAssetsTask = Task { @MainActor [favoriteAssetsService] in
            let favorites = listsFavorites
                ? await favoriteAssetsService.assets.map { PriceWidgetSnapshot.Asset(id: $0.id, symbol: $0.symbol) }
                : []
            guard !Task.isCancelled else { return }
            let snapshot = PriceWidgetSnapshot(favorites: favorites, walletAssets: walletAssets, currency: currency)
            guard snapshot != PriceWidgetSnapshot.load() else { return }
            snapshot.save()
            WalletWidgetLink.Widget.priceKinds.forEach { WidgetCenter.shared.reloadTimelines(ofKind: $0.kind) }
        }
    }

    func makeWalletAssets() -> [PriceWidgetSnapshot.Asset] {
        guard let wallet = try? walletsStore.activeWallet,
              let portfolio = portfolioStore.getState()[wallet]
        else { return [] }
        return Self.largestAssets(portfolio.assets, currency: currencyStore.getState())
            .map { PriceWidgetSnapshot.Asset(id: $0.asset.asset.assetId, symbol: $0.asset.asset.symbol) }
    }

    /// The assets the wallet screen lists, largest in fiat first, as many as the largest watchlist shows.
    nonisolated static func largestAssets(_ assets: [MultichainAsset], currency: Currency) -> [(asset: MultichainAsset, fiat: Decimal)] {
        let formatting = MultichainPortfolioAmountFormatting()
        return Array(
            assets
                .filter { !$0.isHidden && !$0.asset.isScam }
                .compactMap { asset in
                    formatting.convertedAmount(for: asset, currency: currency).flatMap { $0 > 0 ? (asset, $0) : nil }
                }
                .sorted { $0.1 > $1.1 }
                .prefix(5)
        )
    }

    /// What the wallet's tokens gained or lost in 24 hours at their prices, in `currency` only: `nil` when
    /// any listed token lacks its price or change there, rather than a sum that leaves some of them out.
    nonisolated static func change24h(_ assets: [MultichainAsset], currency: Currency) -> Decimal? {
        let formatting = MultichainPortfolioAmountFormatting()
        var change = Decimal.zero
        var hasValue = false
        for asset in assets where !asset.isHidden && !asset.asset.isScam && asset.balance > 0 {
            guard let price = exactValue(in: asset.price.prices, currency: currency) else { return nil }
            let value = formatting.decimalAmount(amount: asset.balance, fractionDigits: asset.asset.decimals) * Decimal(price)
            guard value > 0 else { continue }
            guard let percent = exactValue(in: asset.price.diff24h, currency: currency).flatMap(parsePercent),
                  percent > -100
            else { return nil }
            change += value * percent / (100 + percent)
            hasValue = true
        }
        return hasValue ? change : nil
    }

    /// `8.2K`-style, for the circular Lock Screen widget.
    nonisolated static func compactFiat(_ amount: Decimal, currency: Currency, locale: Locale) -> String {
        let number = NSDecimalNumber(decimal: amount).doubleValue.formatted(
            FloatingPointFormatStyle<Double>.number
                .locale(locale)
                .notation(.compactName)
                .precision(.fractionLength(0 ... 1))
                .rounded(rule: .towardZero)
        )
        return currency.symbolOnLeft ? "\(currency.symbol)\(number)" : "\(number) \(currency.symbol)"
    }

    private nonisolated static func exactValue<T>(in map: [String: T], currency: Currency) -> T? {
        map.first { $0.key.caseInsensitiveCompare(currency.code) == .orderedSame }?.value
    }

    private nonisolated static func parsePercent(_ text: String) -> Decimal? {
        let cleaned = text
            .replacingOccurrences(of: "\u{2212}", with: "-")
            .replacingOccurrences(of: "%", with: "")
            .replacingOccurrences(of: "+", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return Decimal(string: cleaned, locale: Locale(identifier: "en_US_POSIX"))
    }

    func makeSnapshot() -> WalletWidgetSnapshot {
        let hidesAmounts = appSettingsStore.getState().isSecureMode
        let currency = currencyStore.getState()
        let totals = totalBalanceStore.getState()
        let portfolios = portfolioStore.getState()

        let wallets = walletsStore.wallets.compactMap { wallet -> WalletWidgetSnapshot.Wallet? in
            guard let id = try? wallet.identity.identifier().string else { return nil }
            let (emoji, icon): (String?, String?) = switch wallet.icon {
            case let .emoji(value): (value, nil)
            case let .icon(image): (nil, image.rawValue)
            }
            var total: (amount: Decimal, currency: Currency)?
            var updatedAt: Date?
            var change: Decimal?
            var topAssets: [(asset: MultichainAsset, fiat: Decimal)] = []
            if wallet.isMultichain {
                if let portfolio = portfolios[wallet] {
                    total = portfolioFormatting.portfolioFiatTotalAndCurrency(from: portfolio.fiatPrice, displayCurrency: currency)
                    updatedAt = portfolio.date
                    let totalCurrency = total?.currency ?? currency
                    change = Self.change24h(portfolio.assets, currency: totalCurrency)
                    topAssets = Self.largestAssets(
                        portfolio.assets.filter { Self.exactValue(in: $0.price.prices, currency: totalCurrency) != nil },
                        currency: totalCurrency
                    )
                }
            } else if let balance = totals[wallet]?.totalBalance {
                total = (balance.amount, balance.currency)
                updatedAt = balance.date
            }
            let totalCurrency = total?.currency ?? currency
            return WalletWidgetSnapshot.Wallet(
                id: id,
                name: wallet.label,
                emoji: emoji,
                icon: icon,
                total: hidesAmounts ? nil : total.map {
                    amountFormatter.format(decimal: $0.amount, accessory: .fiat($0.currency), style: .fiatBalance)
                },
                totalCompact: hidesAmounts ? nil : total.map {
                    Self.compactFiat($0.amount, currency: $0.currency, locale: amountFormatter.config.locale)
                },
                change: hidesAmounts ? nil : change.map {
                    let text = signedAmountFormatter.format(decimal: $0, accessory: .fiat(totalCurrency), style: .fiatBalance)
                    return WalletWidgetSnapshot.Change(text: text, isDown: text.contains(String.Symbol.minus))
                },
                topAssets: topAssets.prefix(3).map {
                    WalletWidgetSnapshot.Asset(
                        id: $0.asset.asset.assetId,
                        symbol: $0.asset.asset.symbol,
                        amount: hidesAmounts
                            ? nil
                            : amountFormatter.format(decimal: $0.fiat, accessory: .fiat(totalCurrency), style: .fiatBalance),
                        iconURL: URL(string: $0.asset.asset.image)
                    )
                },
                updatedAt: updatedAt,
                actions: Set(WalletWidgetLink.Action.allCases.filter { wallet.enablesWidgetAction($0, configuration: configuration) })
            )
        }
        return WalletWidgetSnapshot(
            wallets: wallets,
            activeWalletId: try? walletsStore.activeWallet.identity.identifier().string,
            hidesAmounts: hidesAmounts,
            isRampEnabled: configuration.featureEnabled(.moonpayRampEnabled),
            decimalSeparator: amountFormatter.config.locale.decimalSeparator ?? "."
        )
    }
}

extension Wallet {
    /// Matches the wallet screen's buttons, so a widget never opens a flow the wallet cannot sign.
    func enablesWidgetAction(_ action: WalletWidgetLink.Action, configuration: Configuration) -> Bool {
        switch action {
        case .open: true
        case .send: isSendEnable
        case .buy: isReceiveEnable
        case .swap: isSwapEnable && !configuration.flag(\.isSwapDisable, network: network) && !configuration.isLedgerDappsLocked(self)
        case .stake: isStakeEnable && !configuration.flag(\.stakingDisabled, network: network)
        }
    }
}
