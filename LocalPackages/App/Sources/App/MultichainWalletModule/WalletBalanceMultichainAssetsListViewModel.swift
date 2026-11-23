import AppUI
import BigInt
import Combine
import Foundation
import KeeperCore
import TKLocalize
import TKLogging
import TKUIKit
import UIKit

@MainActor
final class WalletBalanceMultichainAssetsListViewModel: ObservableObject {
    private struct AssetsQuery: Equatable {
        let multichainState: MultichainWalletState
        let displayCurrency: Currency
        let hidesDustBalances: Bool
    }

    private struct AssetsRequest {
        let query: AssetsQuery
        let token: UInt64
        let firstPage: AsyncStream<MultichainWalletAssetsPage>
        let task: Task<MultichainWalletAssetsPage, Error>
    }

    private struct EarnOffersScope: Equatable {
        let assetIds: Set<String>
        let hasEvmAddress: Bool
        let isEarnEnabled: Bool
    }

    private static let earnOffersMaxAge: TimeInterval = 5 * 60

    private enum AssetsListLayout {
        static let previewAvatarCount = 2

        /// The collapsed list shows its first rows and the avatars of the next two.
        static func collapsedRowCount(_ limit: WalletSectionLimit) -> Int {
            limit.count + previewAvatarCount
        }
    }

    struct RowData {
        let assets: [MultichainAsset]
        let rows: [AssetBalanceRowCellContent]
        let hidesDustBalances: Bool
        /// False when `rows` stop at what the collapsed list shows.
        let hasAllRows: Bool

        fileprivate let selections: [String: RowSelection]

        static let initial = RowData(
            assets: [],
            rows: [],
            hidesDustBalances: false,
            hasAllRows: true,
            selections: [:]
        )
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
        case moreAssets(previewAvatars: [AssetAvatarViewImageSource], limit: WalletSectionLimit)

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
    private let earnAssetOffersRepository: EarnAssetOffersRepository?
    private var earnOffers = [String: EarnAssetOffer]()
    private var earnOffersScope: EarnOffersScope?
    private var earnOffersLoadedAt: Date?
    private(set) var earnOffersTask: Task<Void, Never>?
    private let isEarnEnabled: () -> Bool
    private let now: () -> Date
    private let multichainFormatter = MultichainPortfolioAmountFormatting()
    private let rateConverter = RateConverter()
    private let stakingCommentMapper: StakingItemCommentMapper
    private var isActive = true
    private var needsPresentationRefresh = false
    private var startedRequest: AssetsRequest?
    private let limitModel: WalletSectionLimitModel
    private var limitSubscription: AnyCancellable?

    @Published private(set) var state: State = .idle

    var limit: WalletSectionLimit {
        limitModel.limit
    }

    var presentation: Presentation {
        switch state {
        case .idle:
            return .rows([])
        case let .loading(previous, _):
            return previous.map { Self.presentation(for: $0, limit: limit) } ?? .rows([])
        case let .answered(answer):
            return Self.presentation(for: answer, limit: limit)
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
        earnAssetOffersRepository: EarnAssetOffersRepository?,
        isEarnEnabled: @escaping () -> Bool,
        canManage: Bool,
        limitModel: WalletSectionLimitModel,
        now: @escaping () -> Date = Date.init
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
        self.earnAssetOffersRepository = earnAssetOffersRepository
        self.isEarnEnabled = isEarnEnabled
        self.canManage = canManage
        self.limitModel = limitModel
        self.now = now
        stakingCommentMapper = StakingItemCommentMapper(amountFormatter: amountFormatter)

        limitSubscription = limitModel.limitChanges.sink { [weak self] limit in
            self?.applyLimit(limit)
        }

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

    func selectLimit(_ limit: WalletSectionLimit) {
        limitModel.select(limit)
    }

    private func applyLimit(_ limit: WalletSectionLimit) {
        guard let rowData = state.rowData, !rowData.hasAllRows else {
            objectWillChange.send()
            return
        }
        state = state.settingRowData(
            makeRowData(
                assets: rowData.assets,
                displayCurrency: currencyStore.getState(),
                hidesDustBalances: rowData.hidesDustBalances,
                rowLimit: AssetsListLayout.collapsedRowCount(limit)
            )
        )
    }

    func setActive(_ isActive: Bool) {
        guard self.isActive != isActive else { return }
        self.isActive = isActive
        if !isActive {
            startedRequest?.task.cancel()
            startedRequest = nil
        }
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
            hidesDustBalances: rowData.hidesDustBalances
        )
        state = .answered(.rows(updated))
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
        // Formatting every row delays the launch frame; the fresh portfolio or a larger limit builds the rest.
        let rowData = makeRowData(
            assets: portfolio.assets,
            displayCurrency: displayCurrency,
            hidesDustBalances: portfolio.hidesDustBalances,
            rowLimit: AssetsListLayout.collapsedRowCount(limit)
        )
        AssetAvatarView.prefetch(rowData.rows.map(\.avatarImageSource))
        state = state.settingRowData(rowData)
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

    /// Starts the request of the next `loadAssets()` at once. The load runs on the main actor, which
    /// on launch is busy with the first frame, and the request needs nothing from it.
    func startAssetsRequest() {
        guard let query = makeAssetsQuery(), startedRequest?.query != query else { return }
        startedRequest?.task.cancel()
        startedRequest = makeAssetsRequest(query)
    }

    private func performLoadAssets() async {
        guard let query = makeAssetsQuery() else {
            state = .idle
            return
        }
        let multichainState = query.multichainState
        let displayCurrency = query.displayCurrency
        let hidesDustBalances = query.hidesDustBalances

        let request = takeAssetsRequest(for: query)
        do {
            let page = try await withTaskCancellationHandler {
                for await firstPage in request.firstPage {
                    guard !Task.isCancelled else { break }
                    applyFirstPage(firstPage, query: query, token: request.token)
                }
                return try await request.task.value
            } onCancel: {
                request.task.cancel()
            }
            ScreenRenderTracker.shared.requestFinished(for: .portfolio)
            guard !Task.isCancelled else { return }

            let visibleAssets = page.assets.filter { !$0.isHidden }
            multichainAssetBalanceProvider.primeCache(
                assets: visibleAssets,
                multichainState: multichainState
            )
            let rowData = makeRowData(
                assets: visibleAssets,
                displayCurrency: displayCurrency,
                hidesDustBalances: hidesDustBalances
            )
            state = .answered(.rows(rowData))
            ScreenRenderTracker.shared.contentApplied(.fresh, for: .portfolio)
            portfolioStore.setPortfolio(
                makePortfolio(page: page, assets: rowData.assets, query: query),
                wallet: wallet,
                requestToken: request.token
            )
            reloadEarnOffers(assetIds: visibleAssets.map(\.asset.assetId))
        } catch {
            guard !Task.isCancelled, !error.isCancellation else { return }
            ScreenRenderTracker.shared.requestFinished(for: .portfolio)
            ScreenRenderTracker.shared.failed(.portfolio, error: ScreenRenderErrorKind(error))
            guard let rowData = state.rowData, !rowData.rows.isEmpty else {
                state = .answered(.failed)
                return
            }
            state = .answered(.rows(rowData))
        }
    }

    /// The backend sorts assets by value and puts the portfolio total on the first page, so that page
    /// already holds what the collapsed list and the header show.
    private func applyFirstPage(_ page: MultichainWalletAssetsPage, query: AssetsQuery, token: UInt64) {
        let visibleAssets = page.assets.filter { !$0.isHidden }
        let rowData = makeRowData(
            assets: visibleAssets,
            displayCurrency: query.displayCurrency,
            hidesDustBalances: query.hidesDustBalances,
            rowLimit: AssetsListLayout.collapsedRowCount(limit)
        )
        guard !rowData.hasAllRows else { return }
        multichainAssetBalanceProvider.primeCache(assets: visibleAssets, multichainState: query.multichainState)
        state = state.settingRowData(rowData)
        ScreenRenderTracker.shared.requestFinished(for: .portfolio)
        ScreenRenderTracker.shared.contentApplied(.fresh, for: .portfolio)
        portfolioStore.setPortfolio(
            makePortfolio(page: page, assets: rowData.assets, query: query),
            wallet: wallet,
            requestToken: token,
            persists: false
        )
    }

    private func makePortfolio(page: MultichainWalletAssetsPage, assets: [MultichainAsset], query: AssetsQuery) -> MultichainPortfolio {
        MultichainPortfolio(
            fiatPrice: page.fiatPrice,
            assets: assets,
            accountsIdentifier: query.multichainState.accountsIdentifier,
            currencyCode: query.displayCurrency.code.lowercased(),
            hidesDustBalances: query.hidesDustBalances,
            perpsFiatPrice: page.perpsFiatPrice ?? portfolioStore.getState()[wallet]?.perpsFiatPrice
        )
    }

    private func takeAssetsRequest(for query: AssetsQuery) -> AssetsRequest {
        defer { startedRequest = nil }
        if let startedRequest, startedRequest.query == query {
            return startedRequest
        }
        startedRequest?.task.cancel()
        return makeAssetsRequest(query)
    }

    private func makeAssetsQuery() -> AssetsQuery? {
        guard case let .multichain(multichainState) = wallet.multichain else { return nil }
        return AssetsQuery(
            multichainState: multichainState,
            displayCurrency: currencyStore.getState(),
            hidesDustBalances: appSettingsStore.getState().hidesDustBalances
        )
    }

    private func makeAssetsRequest(_ query: AssetsQuery) -> AssetsRequest {
        let token = portfolioStore.makeRequestToken()
        ScreenRenderTracker.shared.requestStarted(for: .portfolio)
        let (firstPage, task) = Self.fetchAssets(query, service: multichainService)
        return AssetsRequest(query: query, token: token, firstPage: firstPage, task: task)
    }

    /// Nonisolated, so the task starts on a background thread instead of queueing on the main actor.
    private nonisolated static func fetchAssets(
        _ query: AssetsQuery,
        service: MultichainService
    ) -> (firstPage: AsyncStream<MultichainWalletAssetsPage>, task: Task<MultichainWalletAssetsPage, Error>) {
        var currencyCodes = [query.displayCurrency.code.lowercased()]
        if query.displayCurrency != .defaultCurrency {
            currencyCodes.append(Currency.defaultCurrency.code.lowercased())
        }
        let (firstPage, continuation) = AsyncStream.makeStream(of: MultichainWalletAssetsPage.self)
        let task = Task {
            defer { continuation.finish() }
            return try await service.getAllWalletAssets(
                state: query.multichainState,
                currencies: currencyCodes,
                capabilities: nil,
                chain: nil,
                search: nil,
                availableOnly: nil,
                showHidden: false,
                showAll: nil,
                hideDust: query.hidesDustBalances ? true : nil,
                onFirstPage: { continuation.yield($0) }
            )
        }
        return (firstPage, task)
    }

    private static func presentation(for answer: State.Answer, limit: WalletSectionLimit) -> Presentation {
        switch answer {
        case let .rows(rowData):
            let rows = displayRows(from: rowData, limit: limit)
            return rows.isEmpty ? .allAssetsHidden : .rows(rows)
        case .failed:
            return .error
        }
    }

    private static func displayRows(from rowData: RowData, limit: WalletSectionLimit) -> [Row] {
        guard rowData.rows.count > limit.count else {
            return rowData.rows.map(Row.asset)
        }

        let previewAvatars = rowData.rows
            .dropFirst(limit.count)
            .prefix(AssetsListLayout.previewAvatarCount)
            .map(\.avatarImageSource)
        return rowData.rows
            .prefix(limit.count)
            .map(Row.asset)
            + [.moreAssets(previewAvatars: previewAvatars, limit: limit)]
    }

    private func makeRowData(
        assets: [MultichainAsset],
        displayCurrency: Currency,
        hidesDustBalances: Bool,
        rowLimit: Int? = nil
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
        var hasAllRows = true

        for asset in visibleAssets {
            if let rowLimit, rows.count == rowLimit {
                hasAllRows = false
                break
            }
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
            hidesDustBalances: hidesDustBalances,
            hasAllRows: hasAllRows,
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

        let hasLiquidBalance = assets.contains { $0.balance > 0 }
        let hasPendingOperations = processedItem.map {
            $0.info.pendingDeposit > 0 || $0.info.pendingWithdraw > 0 || $0.info.readyWithdraw > 0
        } ?? false
        guard hasLiquidBalance || hasPendingOperations else {
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
        if case .ton = TradingAssetToken(assetId: assetId) {
            return tonStakingAPYTextFormatter(tonStakingAPYProvider(wallet))
        }
        return earnOffers[assetId].flatMap { tonStakingAPYTextFormatter($0.apy) }
    }

    /// Not awaited by the asset load: the rows and the total must not wait for an APY badge.
    /// Every portfolio reload lands here, so the same assets reuse an in-flight or recent answer.
    private func reloadEarnOffers(assetIds: [String]) {
        let scope = EarnOffersScope(
            assetIds: Set(assetIds),
            hasEvmAddress: wallet.walletConnectAddress(for: .eth) != nil,
            isEarnEnabled: isEarnEnabled()
        )
        guard !canReuseEarnOffers(for: scope) else { return }
        earnOffersTask?.cancel()
        earnOffersScope = scope
        earnOffersLoadedAt = nil
        earnOffersTask = Task { [weak self] in
            guard let self else { return }
            let previous = earnOffers
            let isLoaded = await loadEarnOffers(assetIds: assetIds)
            guard !Task.isCancelled else { return }
            if isLoaded {
                earnOffersLoadedAt = now()
            } else {
                earnOffersScope = nil
            }
            guard earnOffers != previous else { return }
            refreshPresentation()
        }
    }

    /// A scope without a load date is still in flight.
    private func canReuseEarnOffers(for scope: EarnOffersScope) -> Bool {
        guard scope == earnOffersScope else { return false }
        guard let earnOffersLoadedAt else { return true }
        let age = now().timeIntervalSince(earnOffersLoadedAt)
        return age >= 0 && age < Self.earnOffersMaxAge
    }

    private func loadEarnOffers(assetIds: [String]) async -> Bool {
        guard let earnAssetOffersRepository, wallet.walletConnectAddress(for: .eth) != nil else {
            earnOffers = [:]
            return true
        }
        do {
            let offers = try await earnAssetOffersRepository.offers(assetIds: assetIds)
            guard !Task.isCancelled else { return false }
            earnOffers = offers
            return true
        } catch {
            guard !Task.isCancelled else { return false }
            Log.w("failed to load earn offers", extraInfo: ["error": "\(error)"])
            return false
        }
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
