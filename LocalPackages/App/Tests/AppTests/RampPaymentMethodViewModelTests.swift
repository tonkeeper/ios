@testable import App
import BigInt
@testable import KeeperCore
import XCTest

@MainActor
final class RampPaymentMethodViewModelTests: XCTestCase {
    func test_depositLoad_requestsUnscopedThenFiatScopedDetail() async {
        let service = MultichainRampServiceFake()
        service.onrampResults[nil] = .success(makeDetail(fiats: ["USD", "EUR"]))
        service.onrampResults["EUR"] = .success(makeDetail(methodTypes: ["card"], fiats: ["EUR"]))
        let viewModel = makeViewModel(flow: .deposit, preferredFiat: "EUR", service: service)

        viewModel.viewDidLoad()
        await waitUntil { viewModel.state == .loaded }

        XCTAssertEqual(service.recordedCalls, [.init(assetId: assetId, fiat: nil), .init(assetId: assetId, fiat: "EUR")])
        XCTAssertEqual(viewModel.currentCurrency?.code, "EUR")
        XCTAssertEqual(viewModel.rows.map(\.type), ["card"])

        var offeredCurrencies: [String] = []
        viewModel.onSelectCurrency = { currencies, _ in offeredCurrencies = currencies.map(\.code) }
        viewModel.tapCurrency()
        XCTAssertEqual(offeredCurrencies, ["USD", "EUR"])
    }

    func test_setCurrency_deposit_reloadsMethodsForNewFiatAndPassesScopedDetail() async {
        let service = MultichainRampServiceFake()
        let scopedUSD = makeDetail(methodTypes: ["bank"], fiats: ["USD"])
        service.onrampResults[nil] = .success(makeDetail(fiats: ["USD", "EUR"]))
        service.onrampResults["EUR"] = .success(makeDetail(methodTypes: ["card"], fiats: ["EUR"]))
        service.onrampResults["USD"] = .success(scopedUSD)
        let viewModel = makeViewModel(flow: .deposit, preferredFiat: "EUR", service: service)
        viewModel.viewDidLoad()
        await waitUntil { viewModel.state == .loaded }

        viewModel.setCurrency(makeCurrency("USD"))

        XCTAssertEqual(viewModel.state, .loading)
        XCTAssertTrue(viewModel.rows.isEmpty)
        await waitUntil { viewModel.state == .loaded }
        XCTAssertEqual(service.recordedCalls.last, .init(assetId: assetId, fiat: "USD"))
        XCTAssertEqual(service.recordedCalls.count, 3)
        XCTAssertEqual(viewModel.rows.map(\.type), ["bank"])

        var selectedDetail: OnRampAssetDetail?
        viewModel.onSelectPaymentMethod = { _, _, detail in selectedDetail = detail }
        viewModel.select(row: viewModel.rows[0])
        XCTAssertEqual(selectedDetail, scopedUSD)
    }

    func test_setCurrency_deposit_staleResponseDoesNotOverrideLaterSelection() async {
        let service = MultichainRampServiceFake()
        service.onrampResults[nil] = .success(makeDetail(fiats: ["USD", "EUR", "GBP"]))
        service.onrampResults["USD"] = .success(makeDetail(methodTypes: ["bank"], fiats: ["USD"]))
        service.onrampResults["EUR"] = .success(makeDetail(methodTypes: ["card"], fiats: ["EUR"]))
        service.onrampResults["GBP"] = .success(makeDetail(methodTypes: ["wire"], fiats: ["GBP"]))
        service.suspendedFiats = ["EUR"]
        let viewModel = makeViewModel(flow: .deposit, preferredFiat: "USD", service: service)
        viewModel.viewDidLoad()
        await waitUntil { viewModel.state == .loaded }

        viewModel.setCurrency(makeCurrency("EUR"))
        await service.waitForCalls(3)
        viewModel.setCurrency(makeCurrency("GBP"))
        await waitUntil { viewModel.state == .loaded }
        XCTAssertEqual(viewModel.rows.map(\.type), ["wire"])

        service.resumeSuspended(fiat: "EUR")
        await settle()

        XCTAssertEqual(viewModel.currentCurrency?.code, "GBP")
        XCTAssertEqual(viewModel.rows.map(\.type), ["wire"])
    }

    func test_setCurrency_sameCurrency_doesNotRequest() async {
        let service = MultichainRampServiceFake()
        service.onrampResults[nil] = .success(makeDetail(fiats: ["USD", "EUR"]))
        service.onrampResults["EUR"] = .success(makeDetail(methodTypes: ["card"], fiats: ["EUR"]))
        let viewModel = makeViewModel(flow: .deposit, preferredFiat: "EUR", service: service)
        viewModel.viewDidLoad()
        await waitUntil { viewModel.state == .loaded }

        viewModel.setCurrency(makeCurrency("EUR"))
        await settle()

        XCTAssertEqual(viewModel.state, .loaded)
        XCTAssertEqual(service.recordedCalls.count, 2)
        XCTAssertEqual(viewModel.rows.map(\.type), ["card"])
    }

    func test_setCurrency_withdraw_filtersLocallyWithoutRequest() async {
        let service = MultichainRampServiceFake()
        service.offrampDetail = makeOfframpDetail(methods: [("card", "EUR"), ("bank", "USD")])
        let viewModel = makeViewModel(flow: .withdraw, preferredFiat: "EUR", service: service)
        viewModel.viewDidLoad()
        await waitUntil { viewModel.state == .loaded }
        XCTAssertEqual(viewModel.rows.map(\.type), ["card"])

        viewModel.setCurrency(makeCurrency("USD"))
        await waitUntil { viewModel.state == .loaded }

        XCTAssertEqual(viewModel.rows.map(\.type), ["bank"])
        XCTAssertTrue(service.recordedCalls.isEmpty)
    }

    func test_setCurrency_deposit_failedReloadShowsEmptyAndKeepsCurrencyPicker() async {
        let service = MultichainRampServiceFake()
        service.onrampResults[nil] = .success(makeDetail(fiats: ["USD", "EUR"]))
        service.onrampResults["EUR"] = .success(makeDetail(methodTypes: ["card"], fiats: ["EUR"]))
        service.onrampResults["USD"] = .failure(FakeError())
        let viewModel = makeViewModel(flow: .deposit, preferredFiat: "EUR", service: service)
        viewModel.viewDidLoad()
        await waitUntil { viewModel.state == .loaded }

        viewModel.setCurrency(makeCurrency("USD"))
        await waitUntil { viewModel.state == .loaded }

        XCTAssertTrue(viewModel.rows.isEmpty)
        XCTAssertEqual(viewModel.placeholderKind, .emptyNoCashForCurrency)
        var pickerOpened = false
        viewModel.onSelectCurrency = { _, _ in pickerOpened = true }
        viewModel.tapCurrency()
        XCTAssertTrue(pickerOpened)
    }
}

private extension RampPaymentMethodViewModelTests {
    var assetId: String {
        "eth/mainnet/native"
    }

    func makeViewModel(
        flow: RampFlow,
        preferredFiat: String?,
        service: MultichainRampServiceFake
    ) -> RampPaymentMethodViewModel {
        RampPaymentMethodViewModel(
            asset: MultichainAsset(
                asset: MultichainAssetDetails(
                    assetId: assetId,
                    name: "Ethereum",
                    symbol: "ETH",
                    decimals: 18,
                    image: ""
                ),
                price: MultichainAssetPrice(prices: [:], diff24h: [:], diff7d: [:], diff30d: [:]),
                balance: BigUInt(0)
            ),
            flow: flow,
            preferredFiat: preferredFiat,
            multichainRampService: service,
            currenciesService: CurrenciesServiceFake(
                currencies: ["USD", "EUR", "GBP", "RUB"].map(makeCurrency)
            ),
            currencyStore: CurrencyStore(
                keeperInfoStore: KeeperInfoStore(keeperInfoRepository: KeeperInfoRepositoryMock())
            ),
            walletId: nil
        )
    }

    func makeCurrency(_ code: String) -> RemoteCurrency {
        RemoteCurrency(code: code, name: code, image: "", type: "fiat")
    }

    func makeDetail(methodTypes: [String] = ["card"], fiats: [String]) -> OnRampAssetDetail {
        OnRampAssetDetail(
            assetId: assetId,
            symbol: "ETH",
            networkName: nil,
            networkImage: nil,
            image: nil,
            decimals: 18,
            stablecoin: false,
            extraIdRequired: false,
            extraIdName: nil,
            paymentMethods: methodTypes.map { type in
                OnRampPaymentMethod(
                    type: type,
                    name: type,
                    image: "",
                    isP2P: false,
                    providers: fiats.map { OnRampProvider(merchantId: "\(type)-\($0)", fiat: $0, limits: nil) }
                )
            }
        )
    }

    func makeOfframpDetail(methods: [(type: String, fiat: String)]) -> OffRampAssetDetail {
        OffRampAssetDetail(
            assetId: assetId,
            symbol: "ETH",
            networkName: nil,
            networkImage: nil,
            image: nil,
            decimals: 18,
            stablecoin: false,
            extraIdRequired: false,
            extraIdName: nil,
            payoutMethods: methods.map { method in
                OffRampPayoutMethod(
                    type: method.type,
                    name: method.type,
                    image: "",
                    providers: [OffRampProvider(merchantId: method.type, fiat: method.fiat, limits: nil)]
                )
            }
        )
    }

    func waitUntil(_ condition: @escaping @MainActor () -> Bool) async {
        for _ in 0 ..< 10000 where !condition() {
            await Task.yield()
        }
        XCTAssertTrue(condition(), "condition not met")
    }

    func settle() async {
        for _ in 0 ..< 50 {
            await Task.yield()
        }
    }
}

private struct FakeError: Error {}

private final class MultichainRampServiceFake: MultichainRampService, @unchecked Sendable {
    struct Call: Equatable {
        let assetId: String
        let fiat: String?
    }

    var onrampResults: [String?: Result<OnRampAssetDetail, Error>] = [:]
    var offrampDetail: OffRampAssetDetail?
    var suspendedFiats: Set<String> = []

    private let lock = NSLock()
    private var calls: [Call] = []
    private var suspended: [String: [CheckedContinuation<OnRampAssetDetail, Error>]] = [:]

    var recordedCalls: [Call] {
        lock.withLock { calls }
    }

    func waitForCalls(_ count: Int) async {
        while recordedCalls.count < count {
            await Task.yield()
        }
    }

    func resumeSuspended(fiat: String) {
        let continuations = lock.withLock { suspended.removeValue(forKey: fiat) ?? [] }
        let result = onrampResults[fiat] ?? .failure(FakeError())
        continuations.forEach { $0.resume(with: result) }
    }

    func getOnrampAsset(assetId: String, fiat: String?, walletId _: String?) async throws -> OnRampAssetDetail {
        lock.withLock { calls.append(Call(assetId: assetId, fiat: fiat)) }
        if let fiat, suspendedFiats.contains(fiat) {
            return try await withCheckedThrowingContinuation { continuation in
                lock.withLock { suspended[fiat, default: []].append(continuation) }
            }
        }
        return try (onrampResults[fiat] ?? .failure(FakeError())).get()
    }

    func getOfframpAsset(assetId _: String) async throws -> OffRampAssetDetail {
        guard let offrampDetail else { throw FakeError() }
        return offrampDetail
    }

    func getLayoutCards(flow _: String, currency _: String?) async throws -> OnRampLayoutCards {
        fatalError("unused")
    }

    func getOnrampChains(query _: OnRampChainsQuery, walletId _: String?) async throws -> OnRampChains {
        fatalError("unused")
    }

    func getOnrampConfiguration(query _: OnRampConfigurationQuery, walletId _: String?) async throws -> OnRampConfiguration {
        fatalError("unused")
    }

    func onrampQuote(request _: OnRampQuoteRequest, walletId _: String?) async throws -> OnRampQuotesResult {
        fatalError("unused")
    }

    func createOnrampOrder(request _: OnRampCreateOrderRequest, walletId _: String?) async throws -> OnRampOrder {
        fatalError("unused")
    }

    func getOnrampOrder(orderId _: String) async throws -> OnRampOrder {
        fatalError("unused")
    }

    func getOfframpConfiguration(query _: OffRampConfigurationQuery) async throws -> OffRampConfiguration {
        fatalError("unused")
    }

    func offrampQuote(request _: OffRampQuoteRequest) async throws -> OffRampQuotesResult {
        fatalError("unused")
    }

    func createOfframpOrder(request _: OffRampCreateOrderRequest) async throws -> OffRampOrder {
        fatalError("unused")
    }

    func getOfframpOrder(orderId _: String) async throws -> OffRampOrder {
        fatalError("unused")
    }
}

private final class CurrenciesServiceFake: CurrenciesService {
    private let currencies: [RemoteCurrency]

    init(currencies: [RemoteCurrency]) {
        self.currencies = currencies
    }

    func loadCurrencies() async throws -> [RemoteCurrency] {
        currencies
    }

    func clearCachedCurrencies() {}
}

private final class KeeperInfoRepositoryMock: KeeperInfoRepository {
    private struct NoKeeperInfo: Error {}
    private var keeperInfo: KeeperInfo?

    func getKeeperInfo() throws -> KeeperInfo {
        guard let keeperInfo else { throw NoKeeperInfo() }
        return keeperInfo
    }

    func saveKeeperInfo(_ keeperInfo: KeeperInfo) throws {
        self.keeperInfo = keeperInfo
    }

    func removeKeeperInfo() throws {
        keeperInfo = nil
    }
}
