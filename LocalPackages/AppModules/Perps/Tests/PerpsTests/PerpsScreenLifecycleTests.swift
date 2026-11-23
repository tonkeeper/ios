import Combine
@testable import Perps
import PerpsModels
import TKTestSupport
import UIKit
import XCTest

@MainActor
final class PerpsScreenLifecycleTests: XCTestCase {
    func test_rootCatchesUpBeforeTheRevealEnds_andSubscribesAfterwards() {
        let account = StubRootAccountStore()
        account.state = .active(PerpsAccount(accountIndex: 1, availableBalance: "100"))
        let markets = StubRootMarketsStore()
        let viewModel = PerpsViewModel(marketsStore: markets, accountStore: account, access: { .available }, reloadAccess: { .available }, format: .test)
        let controller = PerpsViewController(viewModel: viewModel)
        viewModel.onAppear()
        viewModel.onDisappear()

        account.state = .active(PerpsAccount(accountIndex: 1, availableBalance: "200"))
        controller.viewWillAppear(true)

        guard case let .active(portfolio) = viewModel.accountState else {
            return XCTFail("expected an active account")
        }
        XCTAssertEqual(portfolio.balanceText, PerpsFormatting.test.balance("200"))
        XCTAssertEqual(account.positionsSubscribeCount, 1)
        XCTAssertEqual(markets.subscribeCount, 1)

        controller.viewDidAppear(true)
        XCTAssertEqual(account.positionsSubscribeCount, 2)
        XCTAssertEqual(markets.subscribeCount, 2)
        controller.viewWillDisappear(true)
        XCTAssertEqual(account.positionsUnsubscribeCount, 2)
        XCTAssertEqual(markets.unsubscribeCount, 2)
    }

    func test_rootShowsTheRegionBannerFromTheReloadedAccess() async {
        var access = PerpsAccess.available
        let viewModel = PerpsViewModel(
            marketsStore: StubRootMarketsStore(),
            accountStore: StubRootAccountStore(),
            access: { access },
            reloadAccess: {
                access = .restricted
                return access
            },
            format: .test
        )
        XCTAssertFalse(viewModel.isRegionRestricted)

        viewModel.onWillAppear()
        await waitUntil(viewModel) { viewModel.isRegionRestricted }
    }

    func test_rootReloadsAccessWhenTheAppComesBack() async {
        var reloads = 0
        let viewModel = PerpsViewModel(
            marketsStore: StubRootMarketsStore(),
            accountStore: StubRootAccountStore(),
            access: { reloads > 1 ? .restricted : .available },
            reloadAccess: {
                reloads += 1
                return reloads > 1 ? .restricted : .available
            },
            format: .test
        )
        viewModel.onWillAppear()
        await waitUntil(viewModel) { reloads == 1 }

        NotificationCenter.default.post(name: UIApplication.willEnterForegroundNotification, object: nil)
        await waitUntil(viewModel) { viewModel.isRegionRestricted }
        XCTAssertEqual(reloads, 2)
    }

    func test_rootShowsTheRegionBannerWhenAnotherLoadChangesTheAccess() {
        var access = PerpsAccess.available
        let viewModel = PerpsViewModel(
            marketsStore: StubRootMarketsStore(),
            accountStore: StubRootAccountStore(),
            access: { access },
            reloadAccess: { access },
            format: .test
        )

        access = .restricted
        viewModel.accessDidChange()
        XCTAssertTrue(viewModel.isRegionRestricted)

        access = .available
        viewModel.accessDidChange()
        XCTAssertFalse(viewModel.isRegionRestricted)
    }

    func test_cancelledRootReveal_doesNotUnsubscribeAnotherScreen() {
        let account = StubRootAccountStore()
        let markets = StubRootMarketsStore()
        let viewModel = PerpsViewModel(marketsStore: markets, accountStore: account, access: { .available }, reloadAccess: { .available }, format: .test)
        viewModel.onAppear()
        viewModel.onDisappear()

        viewModel.onWillAppear()
        viewModel.onDisappear()

        XCTAssertEqual(account.positionsSubscribeCount, 1)
        XCTAssertEqual(account.positionsUnsubscribeCount, 1)
        XCTAssertEqual(markets.subscribeCount, 1)
        XCTAssertEqual(markets.unsubscribeCount, 1)
    }

    func test_assetCatchesUpPriceActionsAndToastBeforeTheRevealEnds() {
        let account = StubRootAccountStore()
        let markets = StubRootMarketsStore()
        let viewModel = makeAssetViewModel(account: account, markets: markets)
        viewModel.onAppear()
        viewModel.onDisappear()
        XCTAssertEqual(viewModel.state.ready?.actions, .longShort(enabled: true))
        XCTAssertNil(viewModel.tradeToast)

        markets.markets = PerpsMarkets(sort: .volume, items: [], livePrices: [1: 150], hasNextPage: false, isLoadingNextPage: false)
        account.marketLifecycle = .opening(PerpsOpeningDescriptor(
            marketId: 1, symbol: "BTC", side: .long, marginUsd: 20, leverage: 10, isLimit: false
        ))
        viewModel.onWillAppear()

        XCTAssertEqual(viewModel.lastMarkPrice, 150)
        XCTAssertEqual(viewModel.state.ready?.actions, .longShort(enabled: false))
        XCTAssertNotNil(viewModel.tradeToast)
        XCTAssertEqual(account.positionsSubscribeCount, 1)

        viewModel.onAppear()
        XCTAssertEqual(account.positionsSubscribeCount, 2)
        viewModel.onDisappear()
        XCTAssertEqual(account.positionsUnsubscribeCount, 2)
    }

    func test_cancelledAssetReveal_stopsUpdatesWithoutReleasingAnotherScreensSubscription() async {
        let account = StubRootAccountStore()
        let flow = PerpsOpenPositionFlow()
        let viewModel = makeAssetViewModel(account: account, markets: StubRootMarketsStore(), flow: flow)
        viewModel.onAppear()
        viewModel.onDisappear()
        viewModel.onWillAppear()
        viewModel.onDisappear()

        XCTAssertEqual(account.positionsSubscribeCount, 1)
        XCTAssertEqual(account.positionsUnsubscribeCount, 1)
        XCTAssertEqual(account.extrasReleaseCount, 1)

        let ignored = expectation(description: "cancelled reveal stays covered")
        ignored.isInverted = true
        ignored.assertForOverFulfill = false
        let cancellable = viewModel.$state.dropFirst().sink { _ in ignored.fulfill() }
        _ = flow.begin(marketId: 1)
        _ = flow.beginSubmitting(PerpsOpeningDescriptor(
            marketId: 1, symbol: "BTC", side: .long, marginUsd: 20, leverage: 10, isLimit: false
        ))
        await fulfillment(of: [ignored], timeout: 0.1)
        withExtendedLifetime(cancellable) {}
    }

    func test_assetDefersAutoCloseRequestUntilAppearanceCompletes() {
        let viewModel = makeAssetViewModel(account: StubRootAccountStore(), markets: StubRootMarketsStore())
        viewModel.presentsAutoCloseWhenReady = true

        viewModel.onWillAppear()
        XCTAssertTrue(viewModel.presentsAutoCloseWhenReady)

        viewModel.onAppear()
        XCTAssertFalse(viewModel.presentsAutoCloseWhenReady)
        viewModel.onDisappear()
    }

    func test_loyaltyBannerWaitsForLoadedPositionsAndHidesOnceAPositionOpens() {
        let account = StubRootAccountStore()
        account.state = .active(PerpsAccount(accountIndex: 1, availableBalance: "100", positionsLoaded: false))
        let viewModel = makeAssetViewModel(account: account, markets: StubRootMarketsStore(), loyalty: FakeLoyalty(showsBanner: true))

        viewModel.onWillAppear()
        XCTAssertFalse(viewModel.showsLoyaltyBanner)

        account.state = .active(PerpsAccount(accountIndex: 1, availableBalance: "100"))
        viewModel.onWillAppear()
        XCTAssertTrue(viewModel.showsLoyaltyBanner)

        account.marketLifecycle = .opening(PerpsOpeningDescriptor(
            marketId: 1, symbol: "BTC", side: .long, marginUsd: 20, leverage: 10, isLimit: false
        ))
        viewModel.onWillAppear()
        XCTAssertFalse(viewModel.showsLoyaltyBanner)
        viewModel.onDisappear()
    }

    func test_loyaltyBannerFollowsTheReloadedProfileAndHidesForGoodOnDismiss() async {
        let account = StubRootAccountStore()
        account.state = .unbound
        let loyalty = FakeLoyalty(showsBanner: false)
        loyalty.showsBannerAfterReload = true
        let viewModel = makeAssetViewModel(account: account, markets: StubRootMarketsStore(), loyalty: loyalty)
        let shown = expectation(description: "banner shown after reload")
        let cancellable = viewModel.$showsLoyaltyBanner.dropFirst().filter { $0 }.sink { _ in shown.fulfill() }

        viewModel.onWillAppear()
        XCTAssertFalse(viewModel.showsLoyaltyBanner)
        await fulfillment(of: [shown], timeout: 1)

        viewModel.dismissLoyaltyBanner()
        XCTAssertFalse(viewModel.showsLoyaltyBanner)
        XCTAssertEqual(loyalty.hideBannerCount, 1)
        viewModel.onDisappear()
        withExtendedLifetime(cancellable) {}
    }

    func test_loyaltyBannerStaysHiddenWhenAReloadInFlightEndsAfterTheDismiss() async {
        let account = StubRootAccountStore()
        account.state = .unbound
        let loyalty = FakeLoyalty(showsBanner: true)
        let reloadStarted = expectation(description: "reload started")
        var finishReload: CheckedContinuation<Void, Never>?
        loyalty.reloadGate = {
            await withCheckedContinuation {
                finishReload = $0
                reloadStarted.fulfill()
            }
        }
        let viewModel = makeAssetViewModel(account: account, markets: StubRootMarketsStore(), loyalty: loyalty)

        viewModel.onWillAppear()
        await fulfillment(of: [reloadStarted], timeout: 1)
        XCTAssertTrue(viewModel.showsLoyaltyBanner)

        viewModel.dismissLoyaltyBanner()
        loyalty.showsBanner = true
        finishReload?.resume()
        try? await Task.sleep(nanoseconds: 50_000_000)
        XCTAssertFalse(viewModel.showsLoyaltyBanner)
        viewModel.onDisappear()
    }

    private func makeAssetViewModel(
        account: StubRootAccountStore,
        markets: StubRootMarketsStore,
        flow: PerpsOpenPositionFlow? = nil,
        loyalty: FakeLoyalty? = nil
    ) -> PerpsAssetPageViewModel {
        PerpsAssetPageViewModel(
            marketId: 1,
            store: markets,
            marketDetailsStore: LifecycleMarketDetailsStore(),
            accountStore: account,
            openPositionFlow: flow ?? PerpsOpenPositionFlow(),
            tradeOutcomes: { AsyncStream { $0.finish() } },
            format: .test,
            loyalty: loyalty?.port
        )
    }
}

@MainActor
final class FakeLoyalty {
    var showsBanner: Bool
    var showsBannerAfterReload: Bool?
    var reloadGate: (@MainActor () async -> Void)?
    private(set) var hideBannerCount = 0

    init(showsBanner: Bool) {
        self.showsBanner = showsBanner
    }

    var port: PerpsLoyalty {
        PerpsLoyalty(
            showsBanner: { [self] in showsBanner },
            reload: { [self] in
                await reloadGate?()
                if let showsBannerAfterReload { showsBanner = showsBannerAfterReload }
            },
            hideBanner: { [self] in
                hideBannerCount += 1
                showsBanner = false
            },
            reward: { _ in nil }
        )
    }
}

final class LifecycleMarketDetailsStore: PerpsMarketDetailsStoring {
    func addChangeObserver<T: AnyObject>(_: T, onChange _: @escaping (T) -> Void) {}
    func load(marketId _: Int64) {}

    func getState() -> PerpsMarketDetailsState {
        .loaded(PerpsAssetMarketSnapshot(
            marketId: 1, symbol: "BTC", displayName: "BTC", status: "active", maxLeverage: 40,
            priceDecimals: 2, sizeDecimals: 2, price: 100, priceChangePercent: 0, priceChangeAmount: 0,
            volume24h: 1000, openInterest: 1000, fundingRatePercent: nil, about: nil, openEnabled: true
        ))
    }
}
