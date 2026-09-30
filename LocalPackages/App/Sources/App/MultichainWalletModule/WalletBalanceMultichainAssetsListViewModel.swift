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

    struct RowData {
        let assets: [MultichainAsset]
        let rows: [AssetBalanceRowCellContent]
        let isMoreAssetsExpanded: Bool
        let hidesDustBalances: Bool

        fileprivate let selections: [String: RowSelection]

        static let initial = RowData(
            assets: [],
            rows: [],
            isMoreAssetsExpanded: false,
            hidesDustBalances: false,
            selections: [:]
        )

        func settingMoreAssetsExpanded() -> RowData {
            RowData(
                assets: assets,
                rows: rows,
                isMoreAssetsExpanded: true,
                hidesDustBalances: hidesDustBalances,
                selections: selections
            )
        }
    }

    enum State {
        case idle
        case loading(previous: Answer?, task: Task<Void, Never>)
        case answered(Answer)

        enum Answer {
            case rows(RowData)
            case failed
        }
    }

    enum Presentation: Equatable {
        case rows([Row])
        case allAssetsHidden
        case error
    }

    enum Row: Equatable, Identifiable {
        case asset(AssetBalanceRowCellContent)
        case moreAssets(previewAvatars: [AssetAvatarViewImageSource])

        var id: String {
            switch self {
            case let .asset(row):
                row.id
            case .moreAssets:
                "more-assets"
            }
        }
    }

    fileprivate enum RowSelection {
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
    private var isActive = true
    private var needsPresentationRefresh = false

    @Published private(set) var state: State = .idle

    var presentation: Presentation {
        switch state {
        case .idle:
            return .rows([])
        case let .loading(previous, _):
            return previous.map(Self.presentation(for:)) ?? .rows([])
        case let .answered(answer):
            return Self.presentation(for: answer)
        }
    }

    let canManage: Bool

    private(set) var wallet: Wallet

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
    var onNeedsReload: (() -> Void)?

    init(
        wallet: Wallet,
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
        self.wallet = wallet
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
                    observer.onNeedsReload?()
                }
            case .didUpdateSearchEngine, .didUpdateHistoryFilter:
                break
            }
        }
    }

    func adopt(wallet: Wallet) {
        guard self.wallet == wallet else { return }
        self.wallet = wallet
    }

    func selectAsset(row: AssetBalanceRowCellContent) {
        guard let selection = state.rowData?.selections[row.id] else {
            return
        }

        switch selection {
        case let .asset(asset):
            onSelectAsset?(asset)
        case let .staking(pool, info, _):
            onSelectStakingItem?(wallet, pool, info)
        }
    }

    func commentAction(for row: AssetBalanceRowCellContent) -> (() -> Void)? {
        guard case let .staking(pool, info, isCollectable) = state.rowData?.selections[row.id], isCollectable else {
            return nil
        }
        return { [weak self] in
            guard let self else { return }
            onSelectCollectStakingItem?(wallet, pool, info)
        }
    }

    func expandMoreAssets() {
        guard let rowData = state.rowData, !rowData.isMoreAssetsExpanded else { return }
        state = state.settingRowData(rowData.settingMoreAssetsExpanded())
    }

    func setActive(_ isActive: Bool) {
        guard self.isActive != isActive else { return }
        self.isActive = isActive
        guard isActive, needsPresentationRefresh else { return }
        refreshPresentation()
    }

    func refreshPresentation() {
        guard isActive else {
            needsPresentationRefresh = true
            return
        }
        needsPresentationRefresh = false
        guard let rowData = state.rowData, !rowData.assets.isEmpty else { return }
        state = state.settingRowData(
            makeRowData(
                assets: rowData.assets,
                displayCurrency: currencyStore.getState(),
                isMoreAssetsExpanded: rowData.isMoreAssetsExpanded,
                hidesDustBalances: rowData.hidesDustBalances
            )
        )
    }

    func applyVisibilityUpdate(_ update: TokenManagementVisibilityUpdate) {
        guard !update.changes.isEmpty else { return }

        let rowData = state.rowData ?? .initial
        guard appSettingsStore.getState().hidesDustBalances == rowData.hidesDustBalances else {
            return
        }

        state.task?.cancel()

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

        var assets = rowData.assets.compactMap { asset -> MultichainAsset? in
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
        let updated = makeRowData(
            assets: assets,
            displayCurrency: displayCurrency,
            isMoreAssetsExpanded: rowData.isMoreAssetsExpanded,
            hidesDustBalances: rowData.hidesDustBalances
        )
        let hadAnswer = state.answer != nil
        state = .answered(.rows(updated))
        guard hadAnswer, case let .multichain(multichainState) = wallet.multichain else { return }

        let fiatTotal = portfolioFiatTotal(from: updated.assets, displayCurrency: displayCurrency)
        portfolioStore.setPortfolio(
            MultichainPortfolio(
                fiatPrice: fiatTotal.map { [$0.currency.code.lowercased(): "\($0.amount)"] } ?? [:],
                assets: updated.assets,
                accountsIdentifier: multichainState.accountsIdentifier,
                currencyCode: displayCurrency.code.lowercased(),
                hidesDustBalances: updated.hidesDustBalances
            ),
            wallet: wallet
        )
    }

    @discardableResult
    func restoreCachedAssets() -> Bool {
        guard state.answer == nil,
              case let .multichain(multichainState) = wallet.multichain
        else {
            return false
        }
        let displayCurrency = currencyStore.getState()
        guard let portfolio = portfolioStore.getState()[wallet],
              portfolio.accountsIdentifier == multichainState.accountsIdentifier,
              portfolio.hidesDustBalances == appSettingsStore.getState().hidesDustBalances,
              portfolio.currencyCode == displayCurrency.code.lowercased()
        else {
            return false
        }
        multichainAssetBalanceProvider.restoreCache(
            assets: portfolio.assets,
            multichainState: multichainState
        )
        state = state.settingRowData(
            makeRowData(
                assets: portfolio.assets,
                displayCurrency: displayCurrency,
                isMoreAssetsExpanded: false,
                hidesDustBalances: portfolio.hidesDustBalances
            )
        )
        return true
    }

    func loadAssets() async {
        let previous = state.answer
        state.task?.cancel()
        let task = Task { @MainActor [weak self] in
            guard let self else { return }
            await performLoadAssets()
        }
        state = .loading(previous: previous, task: task)
        await withTaskCancellationHandler {
            await task.value
        } onCancel: {
            task.cancel()
        }
    }

    private func performLoadAssets() async {
        guard case let .multichain(multichainState) = wallet.multichain else {
            state = .idle
            return
        }

        let displayCurrency = currencyStore.getState()
        var currencyCodes = [displayCurrency.code.lowercased()]
        if displayCurrency != .defaultCurrency {
            currencyCodes.append(Currency.defaultCurrency.code.lowercased())
        }

        let appSettings = appSettingsStore.getState()
        let requestToken = portfolioStore.makeRequestToken()
        do {
            let page = try await multichainService.getAllWalletAssets(
                state: multichainState,
                currencies: currencyCodes,
                capabilities: nil,
                chain: nil,
                search: nil,
                availableOnly: nil,
                showHidden: false,
                hideDust: appSettings.hidesDustBalances ? true : nil
            )
            guard !Task.isCancelled else { return }

            let visibleAssets = page.assets.filter { !$0.isHidden }
            multichainAssetBalanceProvider.primeCache(
                assets: visibleAssets,
                multichainState: multichainState
            )
            let rowData = makeRowData(
                assets: visibleAssets,
                displayCurrency: displayCurrency,
                isMoreAssetsExpanded: state.rowData?.isMoreAssetsExpanded ?? false,
                hidesDustBalances: appSettings.hidesDustBalances
            )
            state = .answered(.rows(rowData))
            portfolioStore.setPortfolio(
                MultichainPortfolio(
                    fiatPrice: page.fiatPrice,
                    assets: rowData.assets,
                    accountsIdentifier: multichainState.accountsIdentifier,
                    currencyCode: displayCurrency.code.lowercased(),
                    hidesDustBalances: appSettings.hidesDustBalances
                ),
                wallet: wallet,
                requestToken: requestToken
            )
        } catch {
            guard !Task.isCancelled, !error.isCancellation else { return }
            guard let rowData = state.rowData, !rowData.rows.isEmpty else {
                state = .answered(.failed)
                return
            }
            state = .answered(.rows(rowData))
        }
    }

    private static func presentation(for answer: State.Answer) -> Presentation {
        switch answer {
        case let .rows(rowData):
            let rows = displayRows(from: rowData)
            return rows.isEmpty ? .allAssetsHidden : .rows(rows)
        case .failed:
            return .error
        }
    }

    private static func displayRows(from rowData: RowData) -> [Row] {
        guard !rowData.isMoreAssetsExpanded,
              rowData.rows.count > AssetsListLayout.moreButtonThreshold
        else {
            return rowData.rows.map(Row.asset)
        }

        let previewAvatars = rowData.rows
            .dropFirst(AssetsListLayout.collapsedVisibleCount)
            .prefix(2)
            .map { previewAvatarSource(from: $0.avatarImageSource) }
        return rowData.rows
            .prefix(AssetsListLayout.collapsedVisibleCount)
            .map(Row.asset)
            + [.moreAssets(previewAvatars: previewAvatars)]
    }

    private func makeRowData(
        assets: [MultichainAsset],
        displayCurrency: Currency,
        isMoreAssetsExpanded: Bool,
        hidesDustBalances: Bool
    ) -> RowData {
        let visibleAssets = assets.filter {
            $0.asset.chain != nil
        }

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

        return RowData(
            assets: visibleAssets,
            rows: rows,
            isMoreAssetsExpanded: isMoreAssetsExpanded,
            hidesDustBalances: hidesDustBalances,
            selections: selections
        )
    }

    private func makeTonstakersStakingPresentation(
        assets: [MultichainAsset],
        allAssets: [MultichainAsset],
        displayCurrency: Currency,
        isSecureMode: Bool
    ) -> (row: AssetBalanceRowCellContent, selection: RowSelection)? {
        guard !assets.isEmpty else {
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

    private static func previewAvatarSource(from source: AssetAvatarViewImageSource) -> AssetAvatarViewImageSource {
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
        guard case .ton = TradingAssetToken(assetId: assetId) else {
            return nil
        }
        return tonStakingAPYTextFormatter(tonStakingAPYProvider(wallet))
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

private extension WalletBalanceMultichainAssetsListViewModel.State {
    var answer: Answer? {
        switch self {
        case .idle:
            nil
        case let .loading(previous, _):
            previous
        case let .answered(answer):
            answer
        }
    }

    var rowData: WalletBalanceMultichainAssetsListViewModel.RowData? {
        answer?.rowData
    }

    var task: Task<Void, Never>? {
        guard case let .loading(_, task) = self else { return nil }
        return task
    }

    func settingRowData(_ rowData: WalletBalanceMultichainAssetsListViewModel.RowData) -> Self {
        switch self {
        case let .loading(_, task):
            .loading(previous: .rows(rowData), task: task)
        case .idle, .answered:
            .answered(.rows(rowData))
        }
    }
}

private extension WalletBalanceMultichainAssetsListViewModel.State.Answer {
    var rowData: WalletBalanceMultichainAssetsListViewModel.RowData? {
        guard case let .rows(rowData) = self else { return nil }
        return rowData
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
