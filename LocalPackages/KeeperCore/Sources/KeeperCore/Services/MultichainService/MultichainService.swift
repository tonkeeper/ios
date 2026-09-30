import BigInt
import Foundation
import TonSwift

public enum MultichainServiceError: Error {
    case cancelled
    case connectionError
    case apiError(
        message: String?
    )
}

private enum WalletAssetsPagination {
    static let pageLimit = 50
    static let maxPages = 40
    static let repeatedCursorMessage = "Wallet assets pagination returned a repeated cursor"
    static let pageLimitMessage = "Wallet assets pagination exceeded \(maxPages) pages"
}

private func loadAllWalletAssetPages<Page>(
    fetchPage: (String?) async throws(MultichainServiceError) -> Page,
    nextCursor: (Page) -> String?
) async throws(MultichainServiceError) -> [Page] {
    var pages = [Page]()
    var seenCursors = Set<String>()
    var cursor: String?

    for _ in 0 ..< WalletAssetsPagination.maxPages {
        let page = try await fetchPage(cursor)
        pages.append(page)

        guard let nextCursor = nextCursor(page) else {
            return pages
        }
        guard seenCursors.insert(nextCursor).inserted else {
            throw .apiError(message: WalletAssetsPagination.repeatedCursorMessage)
        }
        cursor = nextCursor
    }

    throw .apiError(message: WalletAssetsPagination.pageLimitMessage)
}

public protocol MultichainService {
    func healthcheck() async throws(MultichainServiceError) -> MultichainHealth
    func searchAssets(
        currencies: [String],
        chain: MultichainChain?,
        search: String?,
        sort: MultichainAssetSearchSort,
        limit: Int?,
        cursor: String?
    ) async throws(MultichainServiceError) -> (assets: [MultichainAsset], nextCursor: String?)
    func getWallet(walletId: String) async throws(MultichainServiceError) -> MultichainRegisteredWallet
    func getWalletSyncStatus(walletId: String) async throws(MultichainServiceError) -> MultichainWalletSyncStatus
    /// Returns a single page. `limit: nil` does NOT mean "all assets": the backend
    /// applies its own default page size, so a nil-limit call silently drops the tail.
    /// Use `getAllWalletAssets` when you need the whole set; call this directly only for deliberate cursor-based paging.
    func getWalletAssets(
        state: MultichainWalletState,
        currencies: [String],
        assetIds: [String]?,
        capabilities: [MultichainAssetCapability]?,
        chain: MultichainChain?,
        search: String?,
        availableOnly: Bool?,
        showHidden: Bool?,
        hideDust: Bool?,
        limit: Int?,
        cursor: String?
    ) async throws(MultichainServiceError) -> MultichainWalletAssetsPage
    func getAllWalletAssets(
        state: MultichainWalletState,
        currencies: [String],
        capabilities: [MultichainAssetCapability]?,
        chain: MultichainChain?,
        search: String?,
        availableOnly: Bool?,
        showHidden: Bool?,
        hideDust: Bool?
    ) async throws(MultichainServiceError) -> MultichainWalletAssetsPage
    func saveWalletAssetsFilters(walletId: String, changes: [MultichainAssetFilterChange]) async throws(MultichainServiceError)
    func getWalletActivities(
        state: MultichainWalletState,
        limit: Int?,
        cursor: String?,
        chain: MultichainChain?,
        assetId: String?,
        activityTypeFilter: MultichainActivityTypeFilter?,
        showPerps: Bool?,
        hideDust: Bool?
    ) async throws(MultichainServiceError) -> MultichainWalletActivitiesPage
    func getWalletChallenge() async throws(MultichainServiceError) -> MultichainWalletChallenge
    func broadcastTx(chain: MultichainChain, signedTransaction: Data) async throws(MultichainServiceError) -> MultichainBroadcastResult
    func getFees(chain: MultichainChain) async throws(MultichainServiceError) -> MultichainFeeEstimate
    func getWalletRaffles(
        walletId: String,
        lang: String?,
        ids: [String]?,
        debugNow: Date?,
        isNewUser: Bool
    ) async throws(MultichainServiceError) -> [MultichainRaffle]
    func completeRaffleMigration(walletId: String) async throws(MultichainServiceError)
    func markRaffleImport(walletId: String, importedWalletId: String) async throws(MultichainServiceError)
    func forcePickRaffleWinners(
        raffleId: String,
        walletId: String?,
        prizeId: String?
    ) async throws(MultichainServiceError)
}

final class MultichainServiceImplementation: MultichainService {
    static let defaultPendingTransactionsFlushTimeLimit: TimeInterval = 3

    private let multichainClientAPI: MultichainClientAPI
    private let visibilityChangesController: VisibilityChangesController
    private let pendingTransactionsService: PendingTransactionsService
    private let pendingTransactionsFlushTimeLimit: TimeInterval

    init(
        multichainClientAPI: MultichainClientAPI,
        visibilityChangesController: VisibilityChangesController,
        pendingTransactionsService: PendingTransactionsService,
        pendingTransactionsFlushTimeLimit: TimeInterval = MultichainServiceImplementation
            .defaultPendingTransactionsFlushTimeLimit
    ) {
        self.multichainClientAPI = multichainClientAPI
        self.visibilityChangesController = visibilityChangesController
        self.pendingTransactionsService = pendingTransactionsService
        self.pendingTransactionsFlushTimeLimit = pendingTransactionsFlushTimeLimit
    }

    func healthcheck() async throws(MultichainServiceError) -> MultichainHealth {
        try await serviceCall(await multichainClientAPI.healthcheck())
    }

    func searchAssets(
        currencies: [String],
        chain: MultichainChain?,
        search: String?,
        sort: MultichainAssetSearchSort,
        limit: Int?,
        cursor: String?
    ) async throws(MultichainServiceError) -> (assets: [MultichainAsset], nextCursor: String?) {
        try await serviceCall(await multichainClientAPI.searchAssets(
            currencies: currencies,
            chain: chain,
            search: search,
            sort: sort,
            limit: limit,
            cursor: cursor
        ))
    }

    func getWallet(walletId: String) async throws(MultichainServiceError) -> MultichainRegisteredWallet {
        try await serviceCall(await multichainClientAPI.getWallet(walletId: walletId))
    }

    func getWalletSyncStatus(walletId: String) async throws(MultichainServiceError) -> MultichainWalletSyncStatus {
        try await serviceCall(await multichainClientAPI.getWalletSyncStatus(walletId: walletId))
    }

    func getWalletAssets(
        state: MultichainWalletState,
        currencies: [String],
        assetIds: [String]?,
        capabilities: [MultichainAssetCapability]?,
        chain: MultichainChain?,
        search: String?,
        availableOnly: Bool?,
        showHidden: Bool?,
        hideDust: Bool?,
        limit: Int?,
        cursor: String?
    ) async throws(MultichainServiceError) -> MultichainWalletAssetsPage {
        let walletId = state.walletId
        visibilityChangesController.retryPendingChanges(walletId: walletId)
        let fetchToken = visibilityChangesController.beginServerFetch(walletId: walletId)

        let page: MultichainWalletAssetRecordsPage
        do {
            page = try await serviceCall(await multichainClientAPI.getWalletAssets(
                walletId: walletId,
                currencies: currencies,
                assetIds: assetIds,
                capabilities: capabilities,
                chain: chain,
                search: search,
                availableOnly: availableOnly,
                showHidden: showHidden,
                hideDust: hideDust,
                limit: limit,
                cursor: cursor
            ))
        } catch {
            visibilityChangesController.cancelServerFetch(walletId: walletId, token: fetchToken)
            throw error
        }

        let result = makeWalletAssetsPage(
            records: page.records,
            state: state,
            currencies: currencies,
            showHidden: showHidden,
            hideDust: hideDust,
            nextCursor: page.nextCursor
        )
        visibilityChangesController.endServerFetch(walletId: walletId, token: fetchToken)
        return result
    }

    func getAllWalletAssets(
        state: MultichainWalletState,
        currencies: [String],
        capabilities: [MultichainAssetCapability]?,
        chain: MultichainChain?,
        search: String?,
        availableOnly: Bool?,
        showHidden: Bool?,
        hideDust: Bool?
    ) async throws(MultichainServiceError) -> MultichainWalletAssetsPage {
        let walletId = state.walletId
        visibilityChangesController.retryPendingChanges(walletId: walletId)
        let fetchToken = visibilityChangesController.beginServerFetch(walletId: walletId)

        let pages: [MultichainWalletAssetRecordsPage]
        do {
            pages = try await loadAllWalletAssetPages(
                fetchPage: { (cursor: String?) async throws(MultichainServiceError) in
                    try await serviceCall(await multichainClientAPI.getWalletAssets(
                        walletId: walletId,
                        currencies: currencies,
                        assetIds: nil,
                        capabilities: capabilities,
                        chain: chain,
                        search: search,
                        availableOnly: availableOnly,
                        showHidden: showHidden,
                        hideDust: hideDust,
                        limit: WalletAssetsPagination.pageLimit,
                        cursor: cursor
                    ))
                },
                nextCursor: \.nextCursor
            )
        } catch {
            visibilityChangesController.cancelServerFetch(walletId: walletId, token: fetchToken)
            throw error
        }

        let result = makeWalletAssetsPage(
            records: pages.flatMap(\.records),
            state: state,
            currencies: currencies,
            showHidden: showHidden,
            hideDust: hideDust,
            nextCursor: nil
        )
        visibilityChangesController.endServerFetch(walletId: walletId, token: fetchToken)
        return result
    }

    func saveWalletAssetsFilters(walletId: String, changes: [MultichainAssetFilterChange]) async throws(MultichainServiceError) {
        try await serviceCall(await multichainClientAPI.saveWalletAssetsFilters(walletId: walletId, changes: changes))
    }

    func getWalletActivities(
        state: MultichainWalletState,
        limit: Int?,
        cursor: String?,
        chain: MultichainChain?,
        assetId: String?,
        activityTypeFilter: MultichainActivityTypeFilter?,
        showPerps: Bool?,
        hideDust: Bool?
    ) async throws(MultichainServiceError) -> MultichainWalletActivitiesPage {
        await withTimeLimit(pendingTransactionsFlushTimeLimit) { [pendingTransactionsService] in
            await pendingTransactionsService.flushRetained()
        }
        let page = try await serviceCall(await multichainClientAPI.getWalletActivities(
            walletId: state.walletId,
            limit: limit,
            cursor: cursor,
            chain: chain,
            assetId: assetId,
            activityTypeFilter: activityTypeFilter,
            showPerps: showPerps,
            hideDust: hideDust
        ))
        return MultichainWalletActivitiesPage(
            activities: Self.filteringForeignAccounts(in: page.activities, state: state),
            nextCursor: page.nextCursor
        )
    }

    func getWalletChallenge() async throws(MultichainServiceError) -> MultichainWalletChallenge {
        try await serviceCall(await multichainClientAPI.getWalletChallenge())
    }

    func broadcastTx(chain: MultichainChain, signedTransaction: Data) async throws(MultichainServiceError) -> MultichainBroadcastResult {
        try await serviceCall(await multichainClientAPI.broadcastTx(chain: chain, signedTransaction: signedTransaction))
    }

    func getFees(chain: MultichainChain) async throws(MultichainServiceError) -> MultichainFeeEstimate {
        try await serviceCall(await multichainClientAPI.getFees(chain: chain))
    }

    func getWalletRaffles(
        walletId: String,
        lang: String?,
        ids: [String]?,
        debugNow: Date?,
        isNewUser: Bool
    ) async throws(MultichainServiceError) -> [MultichainRaffle] {
        try await serviceCall(
            await multichainClientAPI.getWalletRaffles(
                walletId: walletId,
                lang: lang,
                ids: ids,
                debugNow: debugNow,
                isNewUser: isNewUser
            )
        )
    }

    func completeRaffleMigration(walletId: String) async throws(MultichainServiceError) {
        try await serviceCall(
            await multichainClientAPI.completeRaffleMigration(walletId: walletId)
        )
    }

    func markRaffleImport(walletId: String, importedWalletId: String) async throws(MultichainServiceError) {
        try await serviceCall(
            await multichainClientAPI.markRaffleImport(walletId: walletId, importedWalletId: importedWalletId)
        )
    }

    func forcePickRaffleWinners(
        raffleId: String,
        walletId: String?,
        prizeId: String?
    ) async throws(MultichainServiceError) {
        try await serviceCall(
            await multichainClientAPI.forcePickRaffleWinners(
                raffleId: raffleId,
                walletId: walletId,
                prizeId: prizeId
            )
        )
    }
}

private extension MultichainServiceImplementation {
    func makeWalletAssetsPage(
        records: [MultichainWalletAssetRecord],
        state: MultichainWalletState,
        currencies: [String],
        showHidden: Bool?,
        hideDust: Bool?,
        nextCursor: String?
    ) -> MultichainWalletAssetsPage {
        let records = Self.filteringForeignAccounts(
            in: records,
            state: state
        )
        let pendingSnapshot = visibilityChangesController.pendingSnapshot(walletId: state.walletId)
        let overlayedAssets = visibilityChangesController.applyingPendingChanges(
            to: records.map(\.asset),
            snapshot: pendingSnapshot
        )
        var assets = if showHidden == true {
            overlayedAssets
        } else {
            overlayedAssets.filter { !$0.isHidden }
        }
        if hideDust == true {
            assets = assets.filter { !Self.isDust($0) }
        }
        return MultichainWalletAssetsPage(
            assets: assets,
            nextCursor: nextCursor,
            fiatPrice: Self.fiatPrice(from: assets, currencies: currencies)
        )
    }

    /// The backend keys a wallet by the seed-derived `walletId`, which two local wallets that
    /// differ only in TON contract version share, so its response mixes both of their accounts.
    static func filteringForeignAccounts(
        in records: [MultichainWalletAssetRecord],
        state: MultichainWalletState
    ) -> [MultichainWalletAssetRecord] {
        var addressTypesByChain = [MultichainChain: Set<MultichainWalletAddressType>]()
        for address in state.addresses {
            guard let type = address.type else {
                continue
            }
            addressTypesByChain[address.chain, default: []].insert(type)
        }

        return records.filter { record in
            guard let chain = record.asset.asset.chain,
                  let ownedTypes = addressTypesByChain[chain],
                  let accountType = record.account.type
            else {
                return true
            }
            return ownedTypes.contains(accountType)
        }
    }

    /// Same collision as above, but an activity carries no account type — only the address it
    /// belongs to — so the sibling's TON activities are told apart by that address. A value that
    /// is absent or belongs to another chain says nothing about ownership and is kept.
    static func filteringForeignAccounts(
        in activities: [MultichainActivity],
        state: MultichainWalletState
    ) -> [MultichainActivity] {
        guard let ownAddress = state.address(for: .ton).flatMap(tonRawAddress) else {
            return activities
        }
        return activities.filter { activity in
            guard let address = activity.walletAddress.flatMap(tonRawAddress) else {
                return true
            }
            return address == ownAddress
        }
    }

    /// The backend echoes TON addresses raw while the wallet stores them user-friendly.
    static func tonRawAddress(_ value: String) -> String? {
        (try? AnyAddress(rawAddress: value))?.address.toRaw()
    }

    func serviceCall<T>(
        _ block: @autoclosure () async throws(MultichainClientAPIError) -> T
    ) async throws(MultichainServiceError) -> T {
        do {
            return try await block()
        } catch {
            throw Self.mapError(error)
        }
    }

    static func mapError(_ error: MultichainClientAPIError) -> MultichainServiceError {
        MultichainServiceError(clientAPIError: error)
    }

    static let dustFiatThreshold = Decimal(sign: .plus, exponent: -2, significand: 1)

    static func isDust(_ asset: MultichainAsset) -> Bool {
        guard let price = price(for: "usd", in: asset.price.prices) else {
            return false
        }
        return decimalAmount(
            amount: asset.balance,
            fractionDigits: asset.asset.decimals
        ) * Decimal(price) < dustFiatThreshold
    }

    static func fiatPrice(
        from assets: [MultichainAsset],
        currencies: [String]
    ) -> [String: String] {
        var result = [String: String]()
        for currency in currencies {
            let code = currency.lowercased()
            let total = assets.reduce(Decimal.zero) { result, asset in
                guard let price = price(for: code, in: asset.price.prices) else {
                    return result
                }
                return result + decimalAmount(
                    amount: asset.balance,
                    fractionDigits: asset.asset.decimals
                ) * Decimal(price)
            }
            result[code] = total.description
        }
        return result
    }

    static func price(
        for currencyCode: String,
        in prices: [String: Double]
    ) -> Double? {
        for key in [currencyCode, currencyCode.uppercased(), currencyCode.lowercased()] {
            if let price = prices[key] {
                return price
            }
        }
        return prices.first { $0.key.caseInsensitiveCompare(currencyCode) == .orderedSame }?.value
    }

    static func decimalAmount(amount: BigUInt, fractionDigits: Int) -> Decimal {
        guard let raw = Decimal(string: String(amount)) else {
            return .zero
        }
        var divisor = Decimal(1)
        for _ in 0 ..< max(0, fractionDigits) {
            divisor *= 10
        }
        return raw / divisor
    }
}

public extension MultichainService {
    func getWalletActivities(
        state: MultichainWalletState,
        limit: Int?,
        cursor: String?,
        assetId: String,
        activityTypeFilter: MultichainActivityTypeFilter?,
        hideDust: Bool?
    ) async throws(MultichainServiceError) -> MultichainWalletActivitiesPage {
        try await getWalletActivities(
            state: state,
            limit: limit,
            cursor: cursor,
            chain: nil,
            assetId: assetId,
            activityTypeFilter: activityTypeFilter,
            showPerps: nil,
            hideDust: hideDust
        )
    }

    func getWalletAsset(
        state: MultichainWalletState,
        assetId: String,
        currencies: [String],
        showHidden: Bool
    ) async throws(MultichainServiceError) -> MultichainAsset? {
        try await getWalletAssets(
            state: state,
            currencies: currencies,
            assetIds: [assetId],
            capabilities: nil,
            chain: nil,
            search: nil,
            availableOnly: nil,
            showHidden: showHidden,
            hideDust: nil,
            limit: WalletAssetsPagination.pageLimit,
            cursor: nil
        ).assets.first { $0.asset.assetId == assetId }
    }

    func getAllWalletAssets(
        state: MultichainWalletState,
        currencies: [String],
        capabilities: [MultichainAssetCapability]?,
        chain: MultichainChain?,
        search: String?,
        availableOnly: Bool?,
        showHidden: Bool?,
        hideDust: Bool?
    ) async throws(MultichainServiceError) -> MultichainWalletAssetsPage {
        let pages: [MultichainWalletAssetsPage] = try await loadAllWalletAssetPages(
            fetchPage: { (cursor: String?) async throws(MultichainServiceError) in
                try await getWalletAssets(
                    state: state,
                    currencies: currencies,
                    assetIds: nil,
                    capabilities: capabilities,
                    chain: chain,
                    search: search,
                    availableOnly: availableOnly,
                    showHidden: showHidden,
                    hideDust: hideDust,
                    limit: WalletAssetsPagination.pageLimit,
                    cursor: cursor
                )
            },
            nextCursor: \.nextCursor
        )

        let assets = pages.flatMap(\.assets)
        var fiatTotals = [String: Decimal]()
        for page in pages {
            for (code, value) in page.fiatPrice {
                guard let amount = Decimal(string: value) else { continue }
                fiatTotals[code, default: .zero] += amount
            }
        }

        return MultichainWalletAssetsPage(
            assets: assets,
            nextCursor: nil,
            fiatPrice: fiatTotals.mapValues(\.description)
        )
    }
}

extension MultichainServiceError {
    init(clientAPIError error: MultichainClientAPIError) {
        switch error {
        case .cancelled:
            self = .cancelled
        case .connectionError:
            self = .connectionError
        case .badResponse:
            self = .apiError(message: nil)
        case let .badStatus(message):
            self = .apiError(message: message)
        case let .unauthorized(message):
            self = .apiError(message: message)
        case let .forbidden(message):
            self = .apiError(message: message)
        case let .undocumented(statusCode):
            self = .apiError(message: "HTTP \(statusCode)")
        }
    }
}
