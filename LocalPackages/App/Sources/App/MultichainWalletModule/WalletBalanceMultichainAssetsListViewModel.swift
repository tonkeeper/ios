import BigInt
import Combine
import Foundation
import KeeperCore
import TKLocalize
import TKUIKit
import UIKit

@MainActor
final class WalletBalanceMultichainAssetsListViewModel: ObservableObject {
    private enum AssetsListLayout {
        static let collapsedVisibleCount = 7
        static let moreButtonThreshold = collapsedVisibleCount + 1
    }

    private enum RowSelection {
        case asset(MultichainAsset)
        case staking(
            pool: StackingPoolInfo,
            info: AccountStackingInfo,
            isCollectable: Bool
        )
    }

    private let multichainService: MultichainService
    private let multichainAssetBalanceProvider: MultichainAssetBalanceProvider
    private let currencyStore: CurrencyStore
    private let amountFormatter: AmountFormatter
    private let portfolioStore: MultichainPortfolioStore
    private let stakingPoolsStore: StakingPoolsStore
    private let processedBalanceStore: ProcessedBalanceStore
    private let appSettingsStore: AppSettingsStore
    private let tonStakingAPYProvider: (Wallet) -> Decimal?
    private let tonStakingAPYTextFormatter: (Decimal?) -> String?
    private let multichainFormatter = MultichainPortfolioAmountFormatting()
    private let rateConverter = RateConverter()
    private let stakingCommentMapper: StakingItemCommentMapper

    private var allRows: [AssetBalanceRowCellContent] = []
    private var rowSelections: [String: RowSelection] = [:]
    private var isMoreAssetsExpanded = false
    private var currentWallet: Wallet?
    private var lastLoadedHidesDustBalances = false
    private var loadGeneration = 0
    private var appliedGeneration = 0
    private var loadTask: Task<Void, Never>?

    @Published private(set) var rows: [AssetBalanceRowCellContent] = []

    @Published private(set) var showsMoreAssetsButton = false
    @Published private(set) var moreAssetsPreviewAvatars: [AssetAvatarViewImageSource] = []

    @Published private(set) var showsAllAssetsHidden = false
    @Published private(set) var showsError = false

    /// Visible assets from the latest response, before staking presentation is applied.
    private(set) var lastLoadedAssets: [MultichainAsset] = []

    @Published private(set) var canManage: Bool

    var onSelectAsset: ((MultichainAsset) -> Void)?
    var onSelectStakingItem: ((
        _ wallet: Wallet,
        _ stakingPoolInfo: StackingPoolInfo,
        _ accountStakingInfo: AccountStackingInfo
    ) -> Void)?
    var onSelectCollectStakingItem: ((
        _ wallet: Wallet,
        _ stakingPoolInfo: StackingPoolInfo,
        _ accountStakingInfo: AccountStackingInfo
    ) -> Void)?
    var onTapOpenAssets: (() -> Void)?
    var onTapManage: (() -> Void)?
    var onRetry: (() -> Void)?

    init(
        multichainService: MultichainService,
        multichainAssetBalanceProvider: MultichainAssetBalanceProvider,
        currencyStore: CurrencyStore,
        amountFormatter: AmountFormatter,
        portfolioStore: MultichainPortfolioStore,
        stakingPoolsStore: StakingPoolsStore,
        processedBalanceStore: ProcessedBalanceStore,
        appSettingsStore: AppSettingsStore,
        tonStakingAPYProvider: @escaping (Wallet) -> Decimal?,
        tonStakingAPYTextFormatter: @escaping (Decimal?) -> String?,
        canManage: Bool
    ) {
        self.multichainService = multichainService
        self.multichainAssetBalanceProvider = multichainAssetBalanceProvider
        self.currencyStore = currencyStore
        self.amountFormatter = amountFormatter
        self.portfolioStore = portfolioStore
        self.stakingPoolsStore = stakingPoolsStore
        self.processedBalanceStore = processedBalanceStore
        self.appSettingsStore = appSettingsStore
        self.tonStakingAPYProvider = tonStakingAPYProvider
        self.tonStakingAPYTextFormatter = tonStakingAPYTextFormatter
        self.canManage = canManage
        stakingCommentMapper = StakingItemCommentMapper(amountFormatter: amountFormatter)

        appSettingsStore.addObserver(self) { observer, event in
            switch event {
            case .didUpdateIsSecureMode:
                Task { @MainActor in
                    observer.refreshPresentation()
                }
            case .didUpdateBalanceFilter:
                Task { @MainActor in
                    guard let wallet = observer.currentWallet else { return }
                    await observer.loadAssets(for: wallet)
                }
            case .didUpdateSearchEngine, .didUpdateHistoryFilter:
                break
            }
        }
    }

    func selectAsset(row: AssetBalanceRowCellContent) {
        guard let selection = rowSelections[row.id] else {
            return
        }

        switch selection {
        case let .asset(asset):
            onSelectAsset?(asset)
        case let .staking(pool, info, _):
            guard let currentWallet else { return }
            onSelectStakingItem?(currentWallet, pool, info)
        }
    }

    func commentAction(for row: AssetBalanceRowCellContent) -> (() -> Void)? {
        guard case let .staking(pool, info, isCollectable) = rowSelections[row.id], isCollectable else {
            return nil
        }
        return { [weak self] in
            guard let self, let currentWallet else { return }
            onSelectCollectStakingItem?(currentWallet, pool, info)
        }
    }

    func expandMoreAssets() {
        guard showsMoreAssetsButton else { return }
        isMoreAssetsExpanded = true
        updateDisplayedRows()
    }

    func refreshPresentation() {
        guard !lastLoadedAssets.isEmpty else { return }
        let displayCurrency = currencyStore.getState()
        _ = applyAssets(lastLoadedAssets, displayCurrency: displayCurrency)
    }

    func applyVisibilityUpdate(_ update: TokenManagementVisibilityUpdate) {
        guard !update.changes.isEmpty else { return }

        // The optimistic delta runs on lastLoadedAssets, which is only valid while the active
        // dust filter still matches the one that list was loaded under. If it diverged (the filter
        // was toggled in the same Manage session), skip the optimistic write — the coordinator's
        // follow-up reloadAssetsList refetches under the current filter.
        let appSettings = appSettingsStore.getState()
        guard appSettings.hidesDustBalances == lastLoadedHidesDustBalances else { return }

        loadGeneration += 1
        appliedGeneration = loadGeneration

        let hideIDs = Set(
            update.changes
                .filter { $0.action == .hide }
                .map(\.assetId)
        )
        let showIDs = Set(
            update.changes
                .filter { $0.action == .show }
                .map(\.assetId)
        )

        // Apply hide/show deltas onto the already-loaded balance list so a
        // partially loaded Manage Crypto session cannot truncate portfolio assets.
        var assets = lastLoadedAssets.compactMap { asset -> MultichainAsset? in
            hideIDs.contains(asset.asset.assetId) ? nil : asset
        }
        let existingIDs = Set(assets.map(\.asset.assetId))
        for asset in update.visibleAssets {
            let assetID = asset.asset.assetId
            guard showIDs.contains(assetID), !existingIDs.contains(assetID) else {
                continue
            }
            assets.append(asset)
        }

        let displayCurrency = currencyStore.getState()
        let sorted = applyAssets(assets, displayCurrency: displayCurrency)
        let fiatTotal = portfolioFiatTotal(from: sorted, displayCurrency: displayCurrency)
        if let currentWallet {
            // An empty price is how "nothing left to add up" reaches the store: hiding the last
            // asset has to move the total the header renders, not leave the previous one standing.
            portfolioStore.setPortfolioTotal(
                fiatTotal.map { [$0.currency.code.lowercased(): "\($0.amount)"] } ?? [:],
                wallet: currentWallet,
                hidesDustBalances: lastLoadedHidesDustBalances
            )
        }
    }

    func loadAssets(for wallet: Wallet?) async {
        loadTask?.cancel()
        let task = Task { @MainActor [weak self] in
            guard let self else { return }
            await self.performLoadAssets(for: wallet)
        }
        loadTask = task
        await withTaskCancellationHandler {
            await task.value
        } onCancel: {
            task.cancel()
        }
    }

    private func performLoadAssets(for wallet: Wallet?) async {
        guard let wallet, case let .multichain(state) = wallet.multichain else {
            currentWallet = nil
            resetAssetsList()
            return
        }

        let previousWallet = currentWallet
        currentWallet = wallet

        if previousWallet?.id != wallet.id {
            resetAssetsList()
        }

        loadGeneration += 1
        let generation = loadGeneration

        let displayCurrency = currencyStore.getState()
        var currencyCodes = [displayCurrency.code.lowercased()]
        if displayCurrency != .defaultCurrency {
            currencyCodes.append(Currency.defaultCurrency.code.lowercased())
        }

        let appSettings = appSettingsStore.getState()
        let requestToken = portfolioStore.makeRequestToken()
        do {
            let page = try await multichainService.getAllWalletAssets(
                state: state,
                currencies: currencyCodes,
                capabilities: nil,
                chain: nil,
                search: nil,
                availableOnly: nil,
                showHidden: false,
                hideDust: appSettings.hidesDustBalances ? true : nil
            )
            guard !Task.isCancelled else { return }
            guard generation > appliedGeneration else { return }
            appliedGeneration = generation

            let visibleAssets = page.assets.filter { !$0.isHidden }
            lastLoadedHidesDustBalances = appSettings.hidesDustBalances
            multichainAssetBalanceProvider.primeCache(
                assets: visibleAssets,
                multichainState: state
            )
            _ = applyAssets(visibleAssets, displayCurrency: displayCurrency)
            portfolioStore.setPortfolioTotal(
                page.fiatPrice,
                wallet: wallet,
                hidesDustBalances: appSettings.hidesDustBalances,
                requestToken: requestToken
            )
        } catch {
            guard !Task.isCancelled else { return }
            guard generation > appliedGeneration else { return }
            // A cancelled request must not consume the generation: a still-inflight
            // earlier request would otherwise get its successful result discarded.
            if error.isCancellation {
                return
            }
            appliedGeneration = generation
            if allRows.isEmpty {
                setShowsError(true)
            }
        }
    }

    private func resetAssetsList() {
        appliedGeneration = loadGeneration
        allRows = []
        rowSelections = [:]
        lastLoadedAssets = []
        lastLoadedHidesDustBalances = false
        isMoreAssetsExpanded = false
        setShowsAllAssetsHidden(false)
        setShowsError(false)
        updateDisplayedRows()
    }

    private func applyAssets(
        _ assets: [MultichainAsset],
        displayCurrency: Currency
    ) -> [MultichainAsset] {
        let visibleAssets = assets.filter {
            $0.asset.chain != nil
        }
        lastLoadedAssets = visibleAssets

        let isSecureMode = appSettingsStore.getState().isSecureMode
        let tonstakersAssets = visibleAssets.filter(isTonstakersLiquidStakingJetton)
        let stakingPresentation = makeTonstakersStakingPresentation(
            assets: tonstakersAssets,
            allAssets: visibleAssets,
            displayCurrency: displayCurrency,
            isSecureMode: isSecureMode
        )

        var rows: [AssetBalanceRowCellContent] = []
        var selections: [String: RowSelection] = [:]
        var didEmitStakingRow = false

        for asset in visibleAssets {
            if isTonstakersLiquidStakingJetton(asset) {
                if !didEmitStakingRow, let stakingPresentation {
                    rows.append(stakingPresentation.row)
                    selections[stakingPresentation.row.id] = stakingPresentation.selection
                    didEmitStakingRow = true
                } else if stakingPresentation == nil {
                    let row = makeRow(
                        from: asset,
                        displayCurrency: displayCurrency,
                        isSecureMode: isSecureMode
                    )
                    rows.append(row)
                    selections[row.id] = .asset(asset)
                }
                continue
            }

            let row = makeRow(
                from: asset,
                displayCurrency: displayCurrency,
                isSecureMode: isSecureMode
            )
            rows.append(row)
            selections[row.id] = .asset(asset)
        }

        allRows = rows
        rowSelections = selections
        setShowsAllAssetsHidden(visibleAssets.isEmpty)
        setShowsError(false)
        updateDisplayedRows()
        return visibleAssets
    }

    private func makeTonstakersStakingPresentation(
        assets: [MultichainAsset],
        allAssets: [MultichainAsset],
        displayCurrency: Currency,
        isSecureMode: Bool
    ) -> (row: AssetBalanceRowCellContent, selection: RowSelection)? {
        guard let wallet = currentWallet, !assets.isEmpty else {
            return nil
        }

        let processedItem = processedBalanceStore.getState()[wallet]?.balance.stakingItems.first {
            $0.poolInfo?.liquidJettonMaster == JettonMasterAddress.tonstakers
        }
        let pool = processedItem?.poolInfo
            ?? stakingPoolsStore.getState()[wallet]?.first {
                $0.liquidJettonMaster == JettonMasterAddress.tonstakers
            }

        guard let pool else {
            return nil
        }

        let tonAmount = convertedTonAmountNanotons(
            from: assets,
            allAssets: allAssets,
            displayCurrency: displayCurrency
        ) ?? processedItem?.info.amount ?? 0

        let info = processedItem?.info ?? AccountStackingInfo(
            pool: pool.address,
            amount: tonAmount,
            pendingDeposit: 0,
            pendingWithdraw: 0,
            readyWithdraw: 0
        )

        let fiatTotal = assets.reduce(Decimal.zero) { partial, asset in
            partial + (multichainFormatter.convertedAmount(for: asset, currency: displayCurrency) ?? .zero)
        }
        let displayAmount = BigUInt(max(tonAmount, 0))
        let balanceText = isSecureMode
            ? String.secureModeValueShort
            : amountFormatter.format(
                amount: displayAmount,
                fractionDigits: TonInfo.fractionDigits
            )
        let fiatText = isSecureMode
            ? String.secureModeValueShort
            : amountFormatter.format(
                decimal: fiatTotal,
                accessory: .fiat(displayCurrency),
                style: .fiatBalance
            )

        let comment = processedItem.flatMap {
            stakingCommentMapper.comment(for: $0, isSecure: isSecureMode)
        }

        let row = AssetBalanceRowCellContent(
            id: Self.tonstakersStakingRowId,
            title: TKLocales.BalanceList.StakingItem.title,
            badge: nil,
            apy: nil,
            displayMode: .includingDiffs(
                balance: balanceText,
                price: pool.name,
                delta: nil,
                fiat: fiatText,
                showsPin: false,
                priceColor: .textSecondary
            ),
            avatarImageSource: .image(
                .TKUIKit.Icons.Size44.tonLogo,
                chainIcon: pool.icon
            ),
            comment: comment?.text
        )

        return (
            row,
            .staking(
                pool: pool,
                info: info,
                isCollectable: comment?.isCollectable == true && wallet.isStakeEnable
            )
        )
    }

    private func convertedTonAmountNanotons(
        from assets: [MultichainAsset],
        allAssets: [MultichainAsset],
        displayCurrency: Currency
    ) -> Int64? {
        guard let gramAsset = allAssets.first(where: { isTonNativeCoin($0) }) else {
            return nil
        }

        var totalTon = Decimal.zero
        var didConvert = false
        for asset in assets {
            guard let prices = multichainFormatter.pairedPrices(
                lhs: asset.price.prices,
                rhs: gramAsset.price.prices,
                preferred: displayCurrency
            ) else {
                continue
            }
            let rate = Rates.Rate(
                currency: displayCurrency,
                rate: Decimal(prices.lhs) / Decimal(prices.rhs),
                diff24h: nil
            )
            totalTon += rateConverter.convertToDecimal(
                amount: asset.balance,
                amountFractionLength: asset.asset.decimals,
                rate: rate
            )
            didConvert = true
        }

        guard didConvert else {
            return nil
        }

        let nanotons = NSDecimalNumber(decimal: totalTon)
            .multiplying(
                byPowerOf10: Int16(TonInfo.fractionDigits),
                withBehavior: Self.nanotonRoundingBehavior
            )
        return nanotons.int64Value
    }

    private func portfolioFiatTotal(
        from assets: [MultichainAsset],
        displayCurrency: Currency
    ) -> (amount: Decimal, currency: Currency)? {
        let amounts = assets.compactMap {
            multichainFormatter.convertedAmount(
                for: $0,
                currency: displayCurrency
            )
        }
        guard !amounts.isEmpty else {
            return nil
        }

        let total = amounts.reduce(Decimal.zero, +)
        return (total, displayCurrency)
    }

    private func updateDisplayedRows() {
        let rows: [AssetBalanceRowCellContent]
        let showsMoreAssetsButton: Bool
        let moreAssetsPreviewAvatars: [AssetAvatarViewImageSource]

        if isMoreAssetsExpanded || allRows.count <= AssetsListLayout.moreButtonThreshold {
            rows = allRows
            showsMoreAssetsButton = false
            moreAssetsPreviewAvatars = []
        } else {
            rows = Array(allRows.prefix(AssetsListLayout.collapsedVisibleCount))
            showsMoreAssetsButton = true
            moreAssetsPreviewAvatars = allRows
                .dropFirst(AssetsListLayout.collapsedVisibleCount)
                .prefix(2)
                .map { previewAvatarSource(from: $0.avatarImageSource) }
        }

        if self.rows != rows {
            self.rows = rows
        }
        if self.showsMoreAssetsButton != showsMoreAssetsButton {
            self.showsMoreAssetsButton = showsMoreAssetsButton
        }
        if self.moreAssetsPreviewAvatars != moreAssetsPreviewAvatars {
            self.moreAssetsPreviewAvatars = moreAssetsPreviewAvatars
        }
    }

    private func setShowsAllAssetsHidden(_ value: Bool) {
        guard showsAllAssetsHidden != value else { return }
        showsAllAssetsHidden = value
    }

    private func setShowsError(_ value: Bool) {
        guard showsError != value else { return }
        showsError = value
    }

    private func previewAvatarSource(from source: AssetAvatarViewImageSource) -> AssetAvatarViewImageSource {
        switch source {
        case let .url(url, _):
            return .url(url)
        case let .image(image, _):
            return .image(image)
        case .shimmer:
            return .shimmer
        }
    }

    private func makeRow(
        from item: MultichainAsset,
        displayCurrency: Currency,
        isSecureMode: Bool
    ) -> AssetBalanceRowCellContent {
        let imageSource = AssetIdResolver.imageSource(
            for: item.asset.assetId,
            imageUrl: URL(
                string: item.asset.image
                    .trimmingCharacters(in: .whitespacesAndNewlines)
            ),
            multichainEnabled: true
        )
        let unitPrice = multichainFormatter.lookupDouble(
            in: item.price.prices,
            currency: displayCurrency
        ) ?? 0
        let balance = isSecureMode
            ? String.secureModeValueShort
            : multichainFormatter.formatAmount(
                amount: item.balance,
                fractionDigits: item.asset.decimals,
                amountFormatter: amountFormatter
            )
        let fiatTotal = multichainFormatter.convertedAmount(
            for: item,
            currency: displayCurrency
        ) ?? .zero

        let priceText = amountFormatter.format(
            decimal: Decimal(unitPrice),
            accessory: .fiat(displayCurrency),
            style: .compact
        )
        let fiatText = isSecureMode
            ? String.secureModeValueShort
            : amountFormatter.format(
                decimal: fiatTotal,
                accessory: .fiat(displayCurrency),
                style: .compact
            )

        let diff24h = multichainFormatter.lookupString(
            in: item.price.diff24h,
            currency: displayCurrency
        )
        let deltaPositive: Bool = {
            guard let diff24h else { return true }
            let trimmed = diff24h.trimmingCharacters(in: .whitespacesAndNewlines)
            return !trimmed.hasPrefix("-")
        }()

        let badge = AssetIdResolver.tag(
            for: item.asset.assetId,
            multichainEnabled: true
        )
        let verificationStatus = MultichainAssetListVerificationStatus(details: item.asset)
        let priceSubtitle = verificationStatus?.subtitle ?? priceText
        let priceDelta: AssetBalanceRowCellContent.Delta? = {
            guard verificationStatus == nil, let diff24h else { return nil }
            return AssetBalanceRowCellContent.Delta(
                text: diff24h,
                isPositive: deltaPositive
            )
        }()

        return AssetBalanceRowCellContent(
            id: item.asset.assetId,
            title: item.asset.symbol,
            badge: badge,
            apy: apyText(for: item.asset.assetId),
            displayMode: .includingDiffs(
                balance: balance,
                price: priceSubtitle,
                delta: priceDelta,
                fiat: fiatText,
                showsPin: false,
                priceColor: verificationStatus?.subtitleColor ?? .textSecondary
            ),
            avatarImageSource: imageSource,
            showsVerificationCheckmark: item.asset.isTrusted
        )
    }

    private func apyText(for assetId: String) -> String? {
        guard let currentWallet, case .ton = TradingAssetToken(assetId: assetId) else {
            return nil
        }
        return tonStakingAPYTextFormatter(tonStakingAPYProvider(currentWallet))
    }

    private func isTonstakersLiquidStakingJetton(_ asset: MultichainAsset) -> Bool {
        guard case let .jetton(address) = TradingAssetToken(assetId: asset.asset.assetId) else {
            return false
        }
        return address == JettonMasterAddress.tonstakers
    }

    private func isTonNativeCoin(_ asset: MultichainAsset) -> Bool {
        if case .ton = TradingAssetToken(assetId: asset.asset.assetId) {
            return true
        }
        return false
    }
}

private extension WalletBalanceMultichainAssetsListViewModel {
    static let tonstakersStakingRowId = "staking/ton/tonstakers"

    static let nanotonRoundingBehavior = NSDecimalNumberHandler(
        roundingMode: .plain,
        scale: 0,
        raiseOnExactness: false,
        raiseOnOverflow: false,
        raiseOnUnderflow: false,
        raiseOnDivideByZero: false
    )
}

private extension Error {
    var isCancellation: Bool {
        if let serviceError = self as? MultichainServiceError, case .cancelled = serviceError {
            return true
        }
        return self is CancellationError || (self as? URLError)?.code == .cancelled
    }
}
