@testable import Perps
import PerpsModels
import TKCoordinator
import TKTestSupport
import UIKit
import XCTest

private let untilCancelled = TestGate()

@MainActor
final class PerpsFundingCoordinatorTests: XCTestCase {
    func testTheCoordinatorItsScreensAndTheContextGoAwayWithTheFlow() async {
        let recovery = RecoveryProbe()
        weak var coordinator: PerpsFundingCoordinator?
        weak var context: PerpsFlowContext?
        weak var depositScreen: UIViewController?
        weak var depositViewModel: AnyObject?
        weak var withdrawScreen: UIViewController?
        weak var withdrawViewModel: AnyObject?

        autoreleasepool {
            let navigationController = UINavigationController(rootViewController: UIViewController())
            let parent = RouterCoordinator(router: NavigationControllerRouter(rootViewController: navigationController))
            let flowContext = PerpsFlowContext(
                dependencies: StubDependencies(),
                wallet: PerpsWalletDependencies(
                    accountStore: StubRootAccountStore(),
                    tradingService: StubTradingService(),
                    activateAccount: { _, _, _ in .canceled },
                    signingPasscode: { _, _ in nil },
                    recoverFunding: { await recovery.run() },
                    refreshFunding: {},
                    makeDeposit: { _ in FundingDepositStub(holdsTradingKey: true) },
                    makeWithdraw: { WithdrawStub() },
                    makeHistory: { _, _, _, _, _ in nil },
                    track: { _ in }
                )
            )
            let funding = PerpsFundingCoordinator(
                router: parent.router,
                context: flowContext,
                passcodeProvider: { nil },
                presentSheet: { _ in },
                sheetPresenter: { nil }
            )
            parent.addChild(funding)
            funding.start()

            funding.openDeposit(from: .home)
            funding.openWithdraw()

            XCTAssertEqual(navigationController.viewControllers.count, 3)
            depositScreen = navigationController.viewControllers[1]
            withdrawScreen = navigationController.viewControllers[2]
            depositViewModel = depositScreen.flatMap { Mirror(reflecting: $0).descendant("viewModel") as AnyObject? }
            withdrawViewModel = withdrawScreen.flatMap { Mirror(reflecting: $0).descendant("viewModel") as AnyObject? }
            XCTAssertNotNil(depositViewModel)
            XCTAssertNotNil(withdrawViewModel)
            coordinator = funding
            context = flowContext
        }

        XCTAssertNil(coordinator)
        XCTAssertNil(context)
        XCTAssertNil(depositScreen)
        XCTAssertNil(depositViewModel)
        XCTAssertNil(withdrawScreen)
        XCTAssertNil(withdrawViewModel)

        await waitUntil(recovery.cancelled) { recovery.wasCancelled }
        XCTAssertTrue(recovery.wasCancelled)
    }

    func testARestrictedRegionShowsTheSheetInsteadOfTheDepositAndLeavesTheWithdrawal() {
        let navigationController = UINavigationController(rootViewController: UIViewController())
        var presentedSheets = 0
        let funding = PerpsFundingCoordinator(
            router: NavigationControllerRouter(rootViewController: navigationController),
            context: PerpsFlowContext(
                dependencies: StubDependencies(access: .restricted),
                wallet: PerpsWalletDependencies(
                    accountStore: StubRootAccountStore(),
                    tradingService: StubTradingService(),
                    activateAccount: { _, _, _ in .canceled },
                    signingPasscode: { _, _ in nil },
                    recoverFunding: {},
                    refreshFunding: {},
                    makeDeposit: { _ in FundingDepositStub(holdsTradingKey: true) },
                    makeWithdraw: { WithdrawStub() },
                    makeHistory: { _, _, _, _, _ in nil },
                    track: { _ in }
                )
            ),
            passcodeProvider: { nil },
            presentSheet: { _ in presentedSheets += 1 },
            sheetPresenter: { nil }
        )

        funding.openDeposit(from: .home)
        funding.openWithdraw()

        XCTAssertEqual(presentedSheets, 1)
        XCTAssertEqual(navigationController.viewControllers.count, 2)
    }

    func testARegionRefusalOnTheFormClosesTheDepositAndShowsTheSheetOnce() async {
        let navigationController = UINavigationController(rootViewController: UIViewController())
        let window = UIWindow(frame: UIScreen.main.bounds)
        window.rootViewController = navigationController
        window.makeKeyAndVisible()
        defer { window.isHidden = true }
        var presentedSheets = 0
        let presented = TestSignal()
        let funding = PerpsFundingCoordinator(
            router: NavigationControllerRouter(rootViewController: navigationController),
            context: PerpsFlowContext(
                dependencies: StubDependencies(),
                wallet: PerpsWalletDependencies(
                    accountStore: StubRootAccountStore(),
                    tradingService: StubTradingService(),
                    activateAccount: { _, _, _ in .canceled },
                    signingPasscode: { _, _ in nil },
                    recoverFunding: {},
                    refreshFunding: {},
                    makeDeposit: { _ in FundingDepositStub(holdsTradingKey: true) },
                    makeWithdraw: { WithdrawStub() },
                    makeHistory: { _, _, _, _, _ in nil },
                    track: { _ in }
                )
            ),
            passcodeProvider: { nil },
            presentSheet: { _ in
                presentedSheets += 1
                presented.send()
            },
            sheetPresenter: {
                while navigationController.transitionCoordinator != nil {
                    await Task.yield()
                }
                return navigationController
            }
        )

        funding.openDeposit(from: .home)
        let form = navigationController.viewControllers.last
        let viewModel = form.flatMap { Mirror(reflecting: $0).descendant("viewModel") as? PerpsDepositAmountViewModel }
        XCTAssertNotNil(viewModel)
        viewModel?.onRegionRestricted?()
        viewModel?.onRegionRestricted?()
        await waitUntil(presented) { presentedSheets > 0 }

        XCTAssertEqual(presentedSheets, 1)
        XCTAssertEqual(navigationController.viewControllers.count, 1)
    }

    func testTheDepositOffersAnotherWalletOnlyWhenThereIsOne() {
        for hasOtherWallets in [false, true] {
            let navigationController = UINavigationController(rootViewController: UIViewController())
            let funding = PerpsFundingCoordinator(
                router: NavigationControllerRouter(rootViewController: navigationController),
                context: PerpsFlowContext(
                    dependencies: StubDependencies(),
                    wallet: PerpsWalletDependencies(
                        accountStore: StubRootAccountStore(),
                        tradingService: StubTradingService(),
                        activateAccount: { _, _, _ in .canceled },
                        signingPasscode: { _, _ in nil },
                        recoverFunding: {},
                        refreshFunding: {},
                        makeDeposit: { _ in FundingDepositStub(holdsTradingKey: true) },
                        makeHistory: { _, _, _, _, _ in nil },
                        hasOtherWallets: { hasOtherWallets },
                        track: { _ in }
                    )
                ),
                passcodeProvider: { nil },
                presentSheet: { _ in },
                sheetPresenter: { nil }
            )

            funding.openDeposit(from: .home)

            let viewModel = navigationController.viewControllers.last
                .flatMap { Mirror(reflecting: $0).descendant("viewModel") as? PerpsDepositAmountViewModel }
            XCTAssertNotNil(viewModel)
            XCTAssertEqual(viewModel?.onChooseAnotherWallet != nil, hasOtherWallets, "hasOtherWallets: \(hasOtherWallets)")
        }
    }
}

@MainActor
private final class RecoveryProbe {
    private(set) var wasCancelled = false
    let cancelled = TestSignal()

    func run() async {
        do {
            try await untilCancelled.wait()
        } catch {
            wasCancelled = true
            cancelled.send()
        }
    }
}

@MainActor
private final class WithdrawStub: PerpsWithdrawing {
    let destination = FundingDepositStub.usdc

    func availableDestinations() async -> [PerpsDepositSourceOption] {
        []
    }

    func selectDestination(assetId _: String) {}

    func loadBalance() async -> PerpsFundingBalance? {
        nil
    }

    func review(amount _: String) async throws -> PerpsReviewedWithdraw {
        throw CancellationError()
    }

    func message(for _: Error) -> PerpsWithdrawMessage {
        .failed
    }
}

struct StubDependencies: PerpsDependencies {
    let marketsRepository: any PerpsMarketsSearching = NoMarkets()
    let marketsStore: any PerpsMarketsStoring = StubRootMarketsStore()
    let chartService: any PerpsChartProviding = NoChart()
    var access = PerpsAccess.available
    let format = PerpsFormatting.test

    func reloadAccess() async -> PerpsAccess {
        access
    }

    func observeAccess<Observer: AnyObject>(_: Observer, onChange _: @escaping @Sendable (Observer) -> Void) {}

    func makeMarketDetailsStore() -> any PerpsMarketDetailsStoring {
        NoMarketDetails()
    }
}

private final class NoMarkets: PerpsMarketsSearching {
    func markets(query _: String?, sort _: PerpsMarketsSort, cursor _: String?, filter _: PerpsMarketFilter) async throws -> PerpsMarketsPage {
        throw CancellationError()
    }
}

private final class NoChart: PerpsChartProviding {
    func watchChart(
        marketId _: Int64,
        timeframe _: PerpsChartTimeframe,
        onUpdate _: @escaping @Sendable (PerpsChartSnapshot) -> Void,
        onReconnecting _: @escaping @Sendable () -> Void,
        onFailed _: @escaping @Sendable () -> Void
    ) -> PerpsChartWatch {
        PerpsChartWatch(onCancel: {})
    }
}

final class NoMarketDetails: PerpsMarketDetailsStoring {
    func addChangeObserver<T: AnyObject>(_: T, onChange _: @escaping (T) -> Void) {}
    func getState() -> PerpsMarketDetailsState {
        .idle
    }

    func load(marketId _: Int64) {}
}
