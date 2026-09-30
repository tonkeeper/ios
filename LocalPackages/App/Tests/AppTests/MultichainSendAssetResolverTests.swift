@testable import App
import BigInt
import Foundation
@testable import KeeperCore
import XCTest

final class MultichainSendAssetResolverTests: XCTestCase {
    func test_resolveAssetReturnsBalanceAssetWithoutFallback() async {
        let balanceAsset = makeAsset(
            assetId: "eth/mainnet/coin",
            symbol: "ETH",
            balance: 42,
            price: MultichainAssetPrice(
                prices: ["usd": 1234],
                diff24h: ["usd": "1.2"],
                diff7d: ["usd": "2.3"],
                diff30d: ["usd": "3.4"]
            ),
            marketCap: ["usd": "1000000"]
        )
        let multichainService = SendAssetResolverMultichainServiceSpy(
            walletAssetsResult: .success(
                MultichainWalletAssetsPage(
                    assets: [balanceAsset],
                    nextCursor: nil,
                    fiatPrice: [:]
                )
            )
        )
        let assetDetailsService = SendAssetResolverTradingAssetDetailsServiceSpy(
            cachedDetails: makeDetails(assetId: "eth/mainnet/coin"),
            loadedDetailsResult: .failure(.networkError)
        )

        let result = await makeResolver(
            multichainService: multichainService,
            assetDetailsService: assetDetailsService
        ).resolveAsset(
            for: "eth/mainnet/coin",
            multichainState: makeMultichainState()
        )

        let assetDetailsIds = await assetDetailsService.assetDetailsIds()
        let loadAssetDetailsIds = await assetDetailsService.loadAssetDetailsIds()
        let showHiddenValues = await multichainService.walletAssetsRequests().map(\.showHidden)

        XCTAssertEqual(result, balanceAsset)
        XCTAssertEqual(assetDetailsIds, [])
        XCTAssertEqual(loadAssetDetailsIds, [])
        XCTAssertEqual(showHiddenValues, [true])
    }

    func test_resolveAssetBuildsFallbackAssetFromTradingAssetInfo() async {
        let assetId = "eth/mainnet/erc20/0xtoken"
        let details = makeDetails(
            assetId: assetId,
            title: "USD Coin",
            symbol: "USDC",
            decimals: 6,
            imageURL: URL(string: "https://example.com/usdc.png")
        )
        let multichainService = SendAssetResolverMultichainServiceSpy(
            walletAssetsResult: .success(
                MultichainWalletAssetsPage(
                    assets: [],
                    nextCursor: nil,
                    fiatPrice: [:]
                )
            )
        )
        let assetDetailsService = SendAssetResolverTradingAssetDetailsServiceSpy(
            cachedDetails: nil,
            loadedDetailsResult: .success(details)
        )

        let result = await makeResolver(
            multichainService: multichainService,
            assetDetailsService: assetDetailsService
        ).resolveAsset(
            for: assetId,
            multichainState: makeMultichainState()
        )

        XCTAssertEqual(result?.asset.assetId, assetId)
        XCTAssertEqual(result?.asset.name, "USD Coin")
        XCTAssertEqual(result?.asset.symbol, "USDC")
        XCTAssertEqual(result?.asset.decimals, 6)
        XCTAssertEqual(result?.asset.image, "https://example.com/usdc.png")
        let assetDetailsIds = await assetDetailsService.assetDetailsIds()
        let loadAssetDetailsIds = await assetDetailsService.loadAssetDetailsIds()

        XCTAssertEqual(assetDetailsIds, [assetId])
        XCTAssertEqual(loadAssetDetailsIds, [assetId])
    }

    func test_fallbackAssetHasZeroBalanceEmptyPriceAndEmptyMarketCap() async {
        let assetId = "base/mainnet/erc20/0xtoken"
        let multichainService = SendAssetResolverMultichainServiceSpy(
            walletAssetsResult: .success(
                MultichainWalletAssetsPage(
                    assets: [],
                    nextCursor: nil,
                    fiatPrice: [:]
                )
            )
        )
        let assetDetailsService = SendAssetResolverTradingAssetDetailsServiceSpy(
            cachedDetails: makeDetails(assetId: assetId),
            loadedDetailsResult: .failure(.networkError)
        )

        let result = await makeResolver(
            multichainService: multichainService,
            assetDetailsService: assetDetailsService
        ).resolveAsset(
            for: assetId,
            multichainState: makeMultichainState()
        )

        let loadAssetDetailsIds = await assetDetailsService.loadAssetDetailsIds()

        XCTAssertEqual(result?.balance, .zero)
        XCTAssertTrue(result?.price.prices.isEmpty == true)
        XCTAssertTrue(result?.price.diff24h.isEmpty == true)
        XCTAssertTrue(result?.price.diff7d.isEmpty == true)
        XCTAssertTrue(result?.price.diff30d.isEmpty == true)
        XCTAssertTrue(result?.marketCap.isEmpty == true)
        XCTAssertEqual(loadAssetDetailsIds, [])
    }

    func test_resolveAssetReturnsNilWhenBalanceAndTradingDetailsAreUnavailable() async {
        let assetId = "arb/mainnet/erc20/0xtoken"
        let multichainService = SendAssetResolverMultichainServiceSpy(
            walletAssetsResult: .success(
                MultichainWalletAssetsPage(
                    assets: [],
                    nextCursor: nil,
                    fiatPrice: [:]
                )
            )
        )
        let assetDetailsService = SendAssetResolverTradingAssetDetailsServiceSpy(
            cachedDetails: nil,
            loadedDetailsResult: .failure(.apiError(message: nil))
        )

        let result = await makeResolver(
            multichainService: multichainService,
            assetDetailsService: assetDetailsService
        ).resolveAsset(
            for: assetId,
            multichainState: makeMultichainState()
        )

        let assetDetailsIds = await assetDetailsService.assetDetailsIds()
        let loadAssetDetailsIds = await assetDetailsService.loadAssetDetailsIds()

        XCTAssertNil(result)
        XCTAssertEqual(assetDetailsIds, [assetId])
        XCTAssertEqual(loadAssetDetailsIds, [assetId])
    }
}

private extension MultichainSendAssetResolverTests {
    func makeResolver(
        multichainService: SendAssetResolverMultichainServiceSpy,
        assetDetailsService: SendAssetResolverTradingAssetDetailsServiceSpy
    ) -> MultichainSendAssetResolver {
        MultichainSendAssetResolver(
            multichainAssetBalanceProvider: MultichainAssetBalanceProvider(
                balanceService: multichainService,
                currencyStore: makeCurrencyStore()
            ),
            assetDetailsService: assetDetailsService
        )
    }

    func makeCurrencyStore() -> CurrencyStore {
        CurrencyStore(
            keeperInfoStore: KeeperInfoStore(
                keeperInfoRepository: SendAssetResolverKeeperInfoRepositoryMock(keeperInfo: nil)
            )
        )
    }

    func makeMultichainState() -> MultichainWalletState {
        MultichainWalletState(
            walletId: "wallet",
            addresses: [
                MultichainWalletAddress(chain: .eth, address: "0xwallet"),
            ]
        )
    }

    func makeAsset(
        assetId: String,
        symbol: String,
        balance: BigUInt = .zero,
        price: MultichainAssetPrice = MultichainAssetPrice(
            prices: [:],
            diff24h: [:],
            diff7d: [:],
            diff30d: [:]
        ),
        marketCap: [String: String] = [:]
    ) -> MultichainAsset {
        MultichainAsset(
            asset: MultichainAssetDetails(
                assetId: assetId,
                name: symbol,
                symbol: symbol,
                decimals: 18,
                image: ""
            ),
            price: price,
            balance: balance,
            marketCap: marketCap
        )
    }

    func makeDetails(
        assetId: String,
        title: String = "Ether",
        symbol: String = "ETH",
        decimals: Int = 18,
        imageURL: URL? = nil
    ) -> TradingAssetDetails {
        TradingAssetDetails(
            id: assetId,
            assetInfo: TradingAssetInfo(
                assetId: assetId,
                category: .tokens,
                address: assetId,
                symbol: symbol,
                decimals: decimals,
                title: title,
                imageURL: imageURL,
                price: nil,
                changePercent: nil,
                changeAmount: nil,
                earnAPY: nil,
                verification: .whitelist
            ),
            capabilities: [],
            aboutParagraph: "",
            overview: [],
            tradingActivity: nil,
            links: [],
            primaryActionTitle: "",
            infoSource: TradingAssetInfoSource(
                displayedName: "coinmarketcap.com",
                url: nil
            )
        )
    }
}

private actor SendAssetResolverMultichainServiceSpy: MultichainService {
    struct WalletAssetsRequest {
        let walletId: String
        let currencies: [String]
        let assetIds: [String]?
        let showHidden: Bool?
    }

    private let walletAssetsResult: Result<MultichainWalletAssetsPage, MultichainServiceError>
    private var recordedWalletAssetsRequests = [WalletAssetsRequest]()

    init(walletAssetsResult: Result<MultichainWalletAssetsPage, MultichainServiceError>) {
        self.walletAssetsResult = walletAssetsResult
    }

    func walletAssetsRequests() -> [WalletAssetsRequest] {
        recordedWalletAssetsRequests
    }

    func getWalletAssets(
        state: MultichainWalletState,
        currencies: [String],
        assetIds: [String]?,
        capabilities _: [MultichainAssetCapability]?,
        chain _: MultichainChain?,
        search _: String?,
        availableOnly _: Bool?,
        showHidden: Bool?,
        hideDust _: Bool?,
        limit _: Int?,
        cursor _: String?
    ) async throws(MultichainServiceError) -> MultichainWalletAssetsPage {
        recordedWalletAssetsRequests.append(
            WalletAssetsRequest(
                walletId: state.walletId,
                currencies: currencies,
                assetIds: assetIds,
                showHidden: showHidden
            )
        )
        return try walletAssetsResult.get()
    }

    func healthcheck() async throws(MultichainServiceError) -> MultichainHealth {
        throw .apiError(message: "Unimplemented")
    }

    func searchAssets(
        currencies _: [String],
        chain _: MultichainChain?,
        search _: String?,
        sort _: MultichainAssetSearchSort,
        limit _: Int?,
        cursor _: String?
    ) async throws(MultichainServiceError) -> (assets: [MultichainAsset], nextCursor: String?) {
        throw .apiError(message: "Unimplemented")
    }

    func getWallet(walletId _: String) async throws(MultichainServiceError) -> MultichainRegisteredWallet {
        throw .apiError(message: "Unimplemented")
    }

    func getWalletSyncStatus(walletId _: String) async throws(MultichainServiceError) -> MultichainWalletSyncStatus {
        throw .apiError(message: "Unimplemented")
    }

    func getWalletChallenge() async throws(MultichainServiceError) -> MultichainWalletChallenge {
        throw .apiError(message: "Unimplemented")
    }

    func saveWalletAssetsFilters(walletId _: String, changes _: [MultichainAssetFilterChange]) async throws(MultichainServiceError) {
        throw .apiError(message: "Unimplemented")
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
        throw .apiError(message: "Unimplemented")
    }

    func registerWallet(walletId _: String, addresses _: [MultichainWalletAddress]) async throws(MultichainServiceError) -> MultichainRegisteredWallet {
        throw .apiError(message: "Unimplemented")
    }

    func broadcastTx(chain _: MultichainChain, signedTransaction _: Data) async throws(MultichainServiceError) -> MultichainBroadcastResult {
        throw .apiError(message: "Unimplemented")
    }

    func getFees(chain _: MultichainChain) async throws(MultichainServiceError) -> MultichainFeeEstimate {
        throw .apiError(message: "Unimplemented")
    }

    func getWalletRaffles(
        walletId _: String,
        lang _: String?,
        ids _: [String]?,
        debugNow _: Date?,
        isNewUser _: Bool
    ) async throws(MultichainServiceError) -> [MultichainRaffle] {
        throw .apiError(message: "Unimplemented")
    }

    func completeRaffleMigration(walletId _: String) async throws(MultichainServiceError) {
        throw .apiError(message: "Unimplemented")
    }

    func markRaffleImport(walletId _: String, importedWalletId _: String) async throws(MultichainServiceError) {
        throw .apiError(message: "Unimplemented")
    }

    func forcePickRaffleWinners(
        raffleId _: String,
        walletId _: String?,
        prizeId _: String?
    ) async throws(MultichainServiceError) {
        throw .apiError(message: "Unimplemented")
    }
}

private actor SendAssetResolverTradingAssetDetailsServiceSpy: TradingAssetDetailsService {
    private let cachedDetails: TradingAssetDetails?
    private let loadedDetailsResult: Result<TradingAssetDetails, TradingAssetDetailsServiceFailure>
    private var recordedAssetDetailsIds = [String]()
    private var recordedLoadAssetDetailsIds = [String]()

    init(
        cachedDetails: TradingAssetDetails?,
        loadedDetailsResult: Result<TradingAssetDetails, TradingAssetDetailsServiceFailure>
    ) {
        self.cachedDetails = cachedDetails
        self.loadedDetailsResult = loadedDetailsResult
    }

    func assetDetailsIds() -> [String] {
        recordedAssetDetailsIds
    }

    func loadAssetDetailsIds() -> [String] {
        recordedLoadAssetDetailsIds
    }

    func assetDetails(for assetId: String) async -> TradingAssetDetails? {
        recordedAssetDetailsIds.append(assetId)
        return cachedDetails
    }

    func loadAssetDetails(id: String) async throws(TradingAssetDetailsServiceFailure) -> TradingAssetDetails {
        recordedLoadAssetDetailsIds.append(id)
        return try loadedDetailsResult.get()
    }
}

private final class SendAssetResolverKeeperInfoRepositoryMock: KeeperInfoRepository {
    enum Error: Swift.Error {
        case noKeeperInfo
    }

    var keeperInfo: KeeperInfo?

    init(keeperInfo: KeeperInfo?) {
        self.keeperInfo = keeperInfo
    }

    func getKeeperInfo() throws -> KeeperInfo {
        guard let keeperInfo else {
            throw Error.noKeeperInfo
        }
        return keeperInfo
    }

    func saveKeeperInfo(_ keeperInfo: KeeperInfo) throws {
        self.keeperInfo = keeperInfo
    }

    func removeKeeperInfo() throws {
        keeperInfo = nil
    }
}
