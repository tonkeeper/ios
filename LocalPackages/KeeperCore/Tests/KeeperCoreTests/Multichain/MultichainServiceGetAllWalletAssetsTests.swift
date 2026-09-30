import BigInt
@testable import KeeperCore
import KeeperCoreComponents
import XCTest

final class MultichainServiceGetAllWalletAssetsTests: XCTestCase {
    private let state = MultichainWalletState(walletId: "wallet-id", addresses: [])

    func test_stitchesAllPagesFollowingCursor() async throws {
        let service = MultichainServiceStub(pages: [
            Self.makePage(assetIds: ["ton/mainnet/coin", "eth/mainnet/coin"], nextCursor: "c1"),
            Self.makePage(assetIds: ["btc/mainnet/coin"], nextCursor: "c2"),
            Self.makePage(assetIds: ["tron/mainnet/coin"], nextCursor: nil),
        ])

        let result = try await service.getAllWalletAssets(
            state: state,
            currencies: ["usd"],
            capabilities: nil,
            chain: nil,
            search: nil,
            availableOnly: nil,
            showHidden: false,
            hideDust: nil
        )

        XCTAssertEqual(
            result.assets.map(\.asset.assetId),
            ["ton/mainnet/coin", "eth/mainnet/coin", "btc/mainnet/coin", "tron/mainnet/coin"]
        )
        XCTAssertNil(result.nextCursor)
        XCTAssertEqual(service.receivedCursors, [nil, "c1", "c2"])
        XCTAssertEqual(service.receivedLimits, [50, 50, 50])
    }

    func test_implementationPassesCapabilitiesFilterToTheAPIOnEveryPage() async throws {
        let setup = makeImplementation(pages: [
            MultichainWalletAssetRecordsPage(records: [], nextCursor: "c1"),
            MultichainWalletAssetRecordsPage(records: [], nextCursor: nil),
        ])
        defer { try? FileManager.default.removeItem(at: setup.storageDirectory) }

        _ = try await setup.service.getAllWalletAssets(
            state: state,
            currencies: ["usd"],
            capabilities: [.swap],
            chain: nil,
            search: nil,
            availableOnly: nil,
            showHidden: false,
            hideDust: nil
        )

        XCTAssertEqual(setup.api.receivedCapabilities, [[.swap], [.swap]])
    }

    func test_implementationPassesDustFilterToTheAPIOnEveryPage() async throws {
        let setup = makeImplementation(pages: [
            MultichainWalletAssetRecordsPage(records: [], nextCursor: "c1"),
            MultichainWalletAssetRecordsPage(records: [], nextCursor: nil),
        ])
        defer { try? FileManager.default.removeItem(at: setup.storageDirectory) }

        _ = try await setup.service.getAllWalletAssets(
            state: state,
            currencies: ["usd"],
            capabilities: nil,
            chain: nil,
            search: nil,
            availableOnly: nil,
            showHidden: false,
            hideDust: true
        )

        XCTAssertEqual(setup.api.receivedHideDust, [true, true])
    }

    func test_sumsFiatTotalsPerCurrencyAcrossPages() async throws {
        let service = MultichainServiceStub(pages: [
            Self.makePage(assetIds: ["ton/mainnet/coin"], nextCursor: "c1", fiatPrice: ["usd": "1.5", "rub": "10"]),
            Self.makePage(assetIds: ["btc/mainnet/coin"], nextCursor: nil, fiatPrice: ["usd": "2.25", "rub": "not-a-number"]),
        ])

        let result = try await service.getAllWalletAssets(
            state: state,
            currencies: ["usd", "rub"],
            capabilities: nil,
            chain: nil,
            search: nil,
            availableOnly: nil,
            showHidden: false,
            hideDust: nil
        )

        XCTAssertEqual(result.fiatPrice["usd"], "3.75")
        XCTAssertEqual(result.fiatPrice["rub"], "10")
    }

    func test_throwsOnRepeatedCursor() async {
        let service = MultichainServiceStub(pages: [
            Self.makePage(assetIds: ["ton/mainnet/coin"], nextCursor: "again"),
            Self.makePage(assetIds: ["btc/mainnet/coin"], nextCursor: "again"),
        ])

        await assertPaginationError(
            from: service,
            message: "Wallet assets pagination returned a repeated cursor"
        )
        XCTAssertEqual(service.receivedCursors, [nil, "again"])
    }

    func test_throwsAtPageCapInsteadOfReturningPartialResult() async {
        let service = MultichainServiceStub(pages: (0 ..< 40).map { index in
            Self.makePage(assetIds: ["asset-\(index)"], nextCursor: "c\(index)")
        })

        await assertPaginationError(
            from: service,
            message: "Wallet assets pagination exceeded 40 pages"
        )
        XCTAssertEqual(service.receivedCursors.count, 40)
    }

    func test_filtersPreferredAccountVersionAcrossPageBoundary() async throws {
        let preferredType = MultichainWalletAddressType.tonV5R1
        let state = MultichainWalletState(
            walletId: "wallet-id",
            addresses: [
                MultichainWalletAddress(chain: .ton, address: "preferred", type: preferredType),
            ]
        )
        let assetId = "ton/mainnet/coin"
        let setup = makeImplementation(pages: [
            MultichainWalletAssetRecordsPage(
                records: [Self.makeRecord(assetId: assetId, balance: 1, accountType: .tonV4R2)],
                nextCursor: "c1"
            ),
            MultichainWalletAssetRecordsPage(
                records: [Self.makeRecord(assetId: assetId, balance: 2, accountType: preferredType)],
                nextCursor: nil
            ),
        ])
        defer { try? FileManager.default.removeItem(at: setup.storageDirectory) }

        let result = try await setup.service.getAllWalletAssets(
            state: state,
            currencies: ["usd"],
            capabilities: nil,
            chain: nil,
            search: nil,
            availableOnly: nil,
            showHidden: false,
            hideDust: nil
        )

        XCTAssertEqual(result.assets.map(\.balance), [2])
        XCTAssertEqual(result.fiatPrice["usd"], "2")
        XCTAssertEqual(setup.api.receivedCursors, [nil, "c1"])
    }

    func test_dropsAssetsHeldOnlyByAnotherTonVersionOfTheSameWalletId() async throws {
        let state = MultichainWalletState(
            walletId: "wallet-id",
            addresses: [
                MultichainWalletAddress(chain: .ton, address: "preferred", type: .tonV5R1),
            ]
        )
        let setup = makeImplementation(pages: [
            MultichainWalletAssetRecordsPage(
                records: [
                    Self.makeRecord(assetId: "ton/mainnet/coin", balance: 2, accountType: .tonV5R1),
                    Self.makeRecord(assetId: "ton/mainnet/jetton/sibling", balance: 7, accountType: .tonV4R2),
                ],
                nextCursor: nil
            ),
        ])
        defer { try? FileManager.default.removeItem(at: setup.storageDirectory) }

        let result = try await setup.service.getAllWalletAssets(
            state: state,
            currencies: ["usd"],
            capabilities: nil,
            chain: nil,
            search: nil,
            availableOnly: nil,
            showHidden: false,
            hideDust: nil
        )

        XCTAssertEqual(result.assets.map(\.asset.assetId), ["ton/mainnet/coin"])
        XCTAssertEqual(result.fiatPrice["usd"], "2")
    }

    func test_keepsAssetsOfEveryRegisteredAddressTypeOfAChain() async throws {
        let state = MultichainWalletState(
            walletId: "wallet-id",
            addresses: [
                MultichainWalletAddress(chain: .btc, address: "p2wpkh", type: .btcP2WPKH),
                MultichainWalletAddress(chain: .btc, address: "p2tr", type: .btcP2TR),
            ]
        )
        let setup = makeImplementation(pages: [
            MultichainWalletAssetRecordsPage(
                records: [
                    Self.makeRecord(assetId: "btc/mainnet/coin", balance: 1, chain: .btc, accountType: .btcP2WPKH),
                    Self.makeRecord(assetId: "btc/mainnet/coin", balance: 1, chain: .btc, accountType: .btcP2TR),
                ],
                nextCursor: nil
            ),
        ])
        defer { try? FileManager.default.removeItem(at: setup.storageDirectory) }

        let result = try await setup.service.getAllWalletAssets(
            state: state,
            currencies: ["usd"],
            capabilities: nil,
            chain: nil,
            search: nil,
            availableOnly: nil,
            showHidden: false,
            hideDust: nil
        )

        XCTAssertEqual(result.assets.count, 2)
        XCTAssertEqual(result.fiatPrice["usd"], "2")
    }

    func test_appliesPendingShowOnlyOnceAfterAllPagesLoad() async throws {
        let shownAsset = Self.makeAsset(
            assetId: "ton/mainnet/jetton/shown",
            balance: 3,
            isHidden: true
        )
        let setup = makeImplementation(pages: [
            MultichainWalletAssetRecordsPage(records: [], nextCursor: "c1"),
            MultichainWalletAssetRecordsPage(records: [], nextCursor: nil),
        ])
        defer { try? FileManager.default.removeItem(at: setup.storageDirectory) }
        try setup.visibilityChangesController.enqueue(
            [MultichainAssetFilterChange(assetId: shownAsset.asset.assetId, action: .show)],
            walletId: state.walletId,
            assets: [shownAsset]
        )

        let result = try await setup.service.getAllWalletAssets(
            state: state,
            currencies: ["usd"],
            capabilities: nil,
            chain: nil,
            search: nil,
            availableOnly: nil,
            showHidden: false,
            hideDust: nil
        )

        XCTAssertEqual(result.assets.map(\.asset.assetId), [shownAsset.asset.assetId])
        XCTAssertEqual(result.assets.map(\.isHidden), [false])
        XCTAssertEqual(result.fiatPrice["usd"], "3")
    }

    func test_pendingShowOfDustAssetDoesNotBypassHideDust() async throws {
        let dustAsset = Self.makeAsset(
            assetId: "ton/mainnet/jetton/dust",
            balance: 1,
            isHidden: true,
            usdPrice: 0.001
        )
        let setup = makeImplementation(pages: [
            MultichainWalletAssetRecordsPage(records: [], nextCursor: nil),
        ])
        defer { try? FileManager.default.removeItem(at: setup.storageDirectory) }
        try setup.visibilityChangesController.enqueue(
            [MultichainAssetFilterChange(assetId: dustAsset.asset.assetId, action: .show)],
            walletId: state.walletId,
            assets: [dustAsset]
        )

        let result = try await setup.service.getAllWalletAssets(
            state: state,
            currencies: ["usd"],
            capabilities: nil,
            chain: nil,
            search: nil,
            availableOnly: nil,
            showHidden: false,
            hideDust: true
        )

        XCTAssertTrue(result.assets.isEmpty)
        XCTAssertEqual(result.fiatPrice["usd"], "0")
    }

    func test_pendingShowOfValuableAssetStillAppearsWhenHideDustIsOn() async throws {
        let shownAsset = Self.makeAsset(
            assetId: "ton/mainnet/jetton/shown",
            balance: 3,
            isHidden: true
        )
        let setup = makeImplementation(pages: [
            MultichainWalletAssetRecordsPage(records: [], nextCursor: nil),
        ])
        defer { try? FileManager.default.removeItem(at: setup.storageDirectory) }
        try setup.visibilityChangesController.enqueue(
            [MultichainAssetFilterChange(assetId: shownAsset.asset.assetId, action: .show)],
            walletId: state.walletId,
            assets: [shownAsset]
        )

        let result = try await setup.service.getAllWalletAssets(
            state: state,
            currencies: ["usd"],
            capabilities: nil,
            chain: nil,
            search: nil,
            availableOnly: nil,
            showHidden: false,
            hideDust: true
        )

        XCTAssertEqual(result.assets.map(\.asset.assetId), [shownAsset.asset.assetId])
        XCTAssertEqual(result.fiatPrice["usd"], "3")
    }

    func test_getWalletAssetFiltersTheRequestToTheTargetAssetId() async throws {
        let assetId = "ton/mainnet/coin"
        let setup = makeImplementation(pages: [
            MultichainWalletAssetRecordsPage(
                records: [Self.makeRecord(assetId: assetId, balance: 5, accountType: .tonV5R1)],
                nextCursor: nil
            ),
        ])
        defer { try? FileManager.default.removeItem(at: setup.storageDirectory) }

        let asset = try await setup.service.getWalletAsset(
            state: state,
            assetId: assetId,
            currencies: ["usd"],
            showHidden: true
        )

        XCTAssertEqual(asset?.balance, 5)
        XCTAssertEqual(setup.api.receivedAssetIds, [[assetId]])
        XCTAssertEqual(setup.api.receivedCursors, [nil])
    }

    func test_getWalletAssetReturnsNilWhenTheFilteredListingIsEmpty() async throws {
        let setup = makeImplementation(pages: [
            MultichainWalletAssetRecordsPage(records: [], nextCursor: nil),
        ])
        defer { try? FileManager.default.removeItem(at: setup.storageDirectory) }

        let asset = try await setup.service.getWalletAsset(
            state: state,
            assetId: "tron/mainnet/coin",
            currencies: ["usd"],
            showHidden: true
        )

        XCTAssertNil(asset)
    }

    func test_getWalletAssetPicksTheRecordOwnedByTheWalletWithinOnePage() async throws {
        let assetId = "ton/mainnet/coin"
        let state = MultichainWalletState(
            walletId: "wallet-id",
            addresses: [
                MultichainWalletAddress(chain: .ton, address: "preferred", type: .tonV5R1),
            ]
        )
        let setup = makeImplementation(pages: [
            MultichainWalletAssetRecordsPage(
                records: [
                    Self.makeRecord(assetId: assetId, balance: 1, accountType: .tonV4R2),
                    Self.makeRecord(assetId: assetId, balance: 9, accountType: .tonV5R1),
                ],
                nextCursor: nil
            ),
        ])
        defer { try? FileManager.default.removeItem(at: setup.storageDirectory) }

        let asset = try await setup.service.getWalletAsset(
            state: state,
            assetId: assetId,
            currencies: ["usd"],
            showHidden: true
        )

        XCTAssertEqual(asset?.balance, 9)
        XCTAssertEqual(setup.api.receivedCursors, [nil])
    }

    func test_assetBalanceProviderRequestsOnlyTheTargetAsset() async {
        let assetId = "btc/mainnet/coin"
        let service = MultichainServiceStub(pages: [
            Self.makePage(assetIds: [assetId], nextCursor: nil),
        ])
        let provider = MultichainAssetBalanceProvider(
            balanceService: service,
            currencyStore: CurrencyStore(
                keeperInfoStore: KeeperInfoStore(
                    keeperInfoRepository: MultichainServiceKeeperInfoRepositoryFake()
                )
            )
        )

        _ = await provider.loadAsset(
            for: assetId,
            multichainState: state,
            includingHidden: true
        )

        XCTAssertEqual(service.receivedAssetIds, [[assetId]])
    }

    private func assertPaginationError(
        from service: MultichainService,
        message: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) async {
        do {
            _ = try await service.getAllWalletAssets(
                state: state,
                currencies: ["usd"],
                capabilities: nil,
                chain: nil,
                search: nil,
                availableOnly: nil,
                showHidden: false,
                hideDust: nil
            )
            XCTFail("Expected pagination error", file: file, line: line)
        } catch let MultichainServiceError.apiError(actualMessage) {
            XCTAssertEqual(actualMessage, message, file: file, line: line)
        } catch {
            XCTFail("Unexpected error: \(error)", file: file, line: line)
        }
    }

    private func makeImplementation(
        pages: [MultichainWalletAssetRecordsPage]
    ) -> (
        service: MultichainServiceImplementation,
        api: MultichainClientAPIStub,
        visibilityChangesController: VisibilityChangesController,
        storageDirectory: URL
    ) {
        let storageDirectory = FileManager.default.temporaryDirectory.appendingPathComponent(
            UUID().uuidString,
            isDirectory: true
        )
        let visibilityChangesController = VisibilityChangesController(
            vault: FileSystemVault(fileManager: .default, directory: storageDirectory),
            writer: MultichainServiceVisibilityChangesWriterFake()
        )
        let api = MultichainClientAPIStub(pages: pages)
        return (
            MultichainServiceImplementation(
                multichainClientAPI: api,
                visibilityChangesController: visibilityChangesController,
                pendingTransactionsService: PendingTransactionsServiceFake()
            ),
            api,
            visibilityChangesController,
            storageDirectory
        )
    }

    private static func makePage(
        assetIds: [String],
        nextCursor: String?,
        fiatPrice: [String: String] = [:]
    ) -> MultichainWalletAssetsPage {
        MultichainWalletAssetsPage(
            assets: assetIds.map { makeAsset(assetId: $0, balance: 1) },
            nextCursor: nextCursor,
            fiatPrice: fiatPrice
        )
    }

    private static func makeRecord(
        assetId: String,
        balance: BigUInt,
        chain: MultichainChain = .ton,
        accountType: MultichainWalletAddressType
    ) -> MultichainWalletAssetRecord {
        MultichainWalletAssetRecord(
            asset: makeAsset(assetId: assetId, balance: balance),
            account: MultichainWalletAddress(
                chain: chain,
                address: accountType.rawValue,
                type: accountType
            )
        )
    }

    private static func makeAsset(
        assetId: String,
        balance: BigUInt,
        isHidden: Bool = false,
        usdPrice: Double = 1
    ) -> MultichainAsset {
        MultichainAsset(
            asset: MultichainAssetDetails(
                assetId: assetId,
                name: assetId,
                symbol: assetId,
                decimals: 0,
                image: ""
            ),
            price: MultichainAssetPrice(
                prices: ["usd": usdPrice],
                diff24h: [:],
                diff7d: [:],
                diff30d: [:]
            ),
            isHidden: isHidden,
            balance: balance
        )
    }
}

private final class MultichainServiceStub: MultichainService {
    private let pages: [MultichainWalletAssetsPage]
    private(set) var receivedCursors: [String?] = []
    private(set) var receivedLimits: [Int?] = []
    private(set) var receivedAssetIds: [[String]?] = []

    init(pages: [MultichainWalletAssetsPage]) {
        self.pages = pages
    }

    func getWalletAssets(
        state _: MultichainWalletState,
        currencies _: [String],
        assetIds: [String]?,
        capabilities _: [MultichainAssetCapability]?,
        chain _: MultichainChain?,
        search _: String?,
        availableOnly _: Bool?,
        showHidden _: Bool?,
        hideDust _: Bool?,
        limit: Int?,
        cursor: String?
    ) async throws(MultichainServiceError) -> MultichainWalletAssetsPage {
        let index = receivedCursors.count
        receivedCursors.append(cursor)
        receivedLimits.append(limit)
        receivedAssetIds.append(assetIds)
        if index < pages.count {
            return pages[index]
        }
        throw .apiError(message: "unexpected page request \(index)")
    }

    func healthcheck() async throws(MultichainServiceError) -> MultichainHealth {
        throw .connectionError
    }

    func searchAssets(
        currencies _: [String],
        chain _: MultichainChain?,
        search _: String?,
        sort _: MultichainAssetSearchSort,
        limit _: Int?,
        cursor _: String?
    ) async throws(MultichainServiceError) -> (assets: [MultichainAsset], nextCursor: String?) {
        throw .connectionError
    }

    func getWallet(walletId _: String) async throws(MultichainServiceError) -> MultichainRegisteredWallet {
        throw .connectionError
    }

    func getWalletSyncStatus(walletId _: String) async throws(MultichainServiceError) -> MultichainWalletSyncStatus {
        throw .connectionError
    }

    func saveWalletAssetsFilters(
        walletId _: String,
        changes _: [MultichainAssetFilterChange]
    ) async throws(MultichainServiceError) {
        throw .connectionError
    }

    func getWalletActivities(
        state _: MultichainWalletState,
        limit _: Int?,
        cursor _: String?,
        chain _: MultichainChain?,
        assetId _: String?,
        activityTypeFilter _: MultichainActivityTypeFilter?,
        showPerps _: Bool?,
        hideDust _: Bool?
    ) async throws(MultichainServiceError) -> MultichainWalletActivitiesPage {
        throw .connectionError
    }

    func getWalletChallenge() async throws(MultichainServiceError) -> MultichainWalletChallenge {
        throw .connectionError
    }

    func broadcastTx(
        chain _: MultichainChain,
        signedTransaction _: Data
    ) async throws(MultichainServiceError) -> MultichainBroadcastResult {
        throw .connectionError
    }

    func getFees(chain _: MultichainChain) async throws(MultichainServiceError) -> MultichainFeeEstimate {
        throw .connectionError
    }

    func getWalletRaffles(
        walletId _: String,
        lang _: String?,
        ids _: [String]?,
        debugNow _: Date?,
        isNewUser _: Bool
    ) async throws(MultichainServiceError) -> [MultichainRaffle] {
        throw .connectionError
    }

    func completeRaffleMigration(walletId _: String) async throws(MultichainServiceError) {
        throw .connectionError
    }

    func markRaffleImport(walletId _: String, importedWalletId _: String) async throws(MultichainServiceError) {
        throw .connectionError
    }

    func forcePickRaffleWinners(
        raffleId _: String,
        walletId _: String?,
        prizeId _: String?
    ) async throws(MultichainServiceError) {
        throw .connectionError
    }
}

private final class MultichainClientAPIStub: MultichainClientAPI {
    private let pages: [MultichainWalletAssetRecordsPage]
    private(set) var receivedCursors: [String?] = []
    private(set) var receivedAssetIds: [[String]?] = []
    private(set) var receivedCapabilities: [[MultichainAssetCapability]?] = []
    private(set) var receivedHideDust: [Bool?] = []

    init(pages: [MultichainWalletAssetRecordsPage]) {
        self.pages = pages
    }

    func getWalletAssets(
        walletId _: String,
        currencies _: [String],
        assetIds: [String]?,
        capabilities: [MultichainAssetCapability]?,
        chain _: MultichainChain?,
        search _: String?,
        availableOnly _: Bool?,
        showHidden _: Bool?,
        hideDust: Bool?,
        limit _: Int?,
        cursor: String?
    ) async throws(MultichainClientAPIError) -> MultichainWalletAssetRecordsPage {
        let index = receivedCursors.count
        receivedCursors.append(cursor)
        receivedAssetIds.append(assetIds)
        receivedCapabilities.append(capabilities)
        receivedHideDust.append(hideDust)
        guard index < pages.count else {
            throw .badStatus(message: "unexpected page request \(index)")
        }
        return pages[index]
    }

    func healthcheck() async throws(MultichainClientAPIError) -> MultichainHealth {
        throw .connectionError(underlying: nil)
    }

    func searchAssets(
        currencies _: [String],
        chain _: MultichainChain?,
        search _: String?,
        sort _: MultichainAssetSearchSort,
        limit _: Int?,
        cursor _: String?
    ) async throws(MultichainClientAPIError) -> (assets: [MultichainAsset], nextCursor: String?) {
        throw .connectionError(underlying: nil)
    }

    func getWallet(walletId _: String) async throws(MultichainClientAPIError) -> MultichainRegisteredWallet {
        throw .connectionError(underlying: nil)
    }

    func getWalletSyncStatus(walletId _: String) async throws(MultichainClientAPIError) -> MultichainWalletSyncStatus {
        throw .connectionError(underlying: nil)
    }

    func saveWalletAssetsFilters(
        walletId _: String,
        changes _: [MultichainAssetFilterChange]
    ) async throws(MultichainClientAPIError) {
        throw .connectionError(underlying: nil)
    }

    func getWalletActivities(
        walletId _: String,
        limit _: Int?,
        cursor _: String?,
        chain _: MultichainChain?,
        assetId _: String?,
        activityTypeFilter _: MultichainActivityTypeFilter?,
        showPerps _: Bool?,
        hideDust _: Bool?
    ) async throws(MultichainClientAPIError) -> MultichainWalletActivitiesPage {
        throw .connectionError(underlying: nil)
    }

    func getWalletChallenge() async throws(MultichainClientAPIError) -> MultichainWalletChallenge {
        throw .connectionError(underlying: nil)
    }

    func broadcastTx(
        chain _: MultichainChain,
        signedTransaction _: Data
    ) async throws(MultichainClientAPIError) -> MultichainBroadcastResult {
        throw .connectionError(underlying: nil)
    }

    func addPendingTransaction(_: MultichainPendingTransaction) async throws(MultichainClientAPIError) {
        throw .connectionError(underlying: nil)
    }

    func getFees(chain _: MultichainChain) async throws(MultichainClientAPIError) -> MultichainFeeEstimate {
        throw .connectionError(underlying: nil)
    }

    func getWalletRaffles(
        walletId _: String,
        lang _: String?,
        ids _: [String]?,
        debugNow _: Date?,
        isNewUser _: Bool
    ) async throws(MultichainClientAPIError) -> [MultichainRaffle] {
        throw .connectionError(underlying: nil)
    }

    func completeRaffleMigration(walletId _: String) async throws(MultichainClientAPIError) {
        throw .connectionError(underlying: nil)
    }

    func markRaffleImport(walletId _: String, importedWalletId _: String) async throws(MultichainClientAPIError) {
        throw .connectionError(underlying: nil)
    }

    func forcePickRaffleWinners(
        raffleId _: String,
        walletId _: String?,
        prizeId _: String?
    ) async throws(MultichainClientAPIError) {
        throw .connectionError(underlying: nil)
    }

    func getRealtimeConnectionToken() async throws(MultichainClientAPIError) -> String {
        throw .connectionError(underlying: nil)
    }

    func getWalletRealtimeToken(walletId _: String) async throws(MultichainClientAPIError) -> String {
        throw .connectionError(underlying: nil)
    }
}

private struct MultichainServiceVisibilityChangesWriterFake: MultichainAssetVisibilityChangesWriter {
    func saveWalletAssetsFilters(
        walletId _: String,
        changes _: [MultichainAssetFilterChange]
    ) async throws(MultichainServiceError) {}
}

private enum MultichainServiceGetAllWalletAssetsTestError: Error {
    case unused
}

private final class MultichainServiceKeeperInfoRepositoryFake: KeeperInfoRepository {
    func getKeeperInfo() throws -> KeeperInfo {
        throw MultichainServiceGetAllWalletAssetsTestError.unused
    }

    func saveKeeperInfo(_: KeeperInfo) throws {}

    func removeKeeperInfo() throws {}
}
