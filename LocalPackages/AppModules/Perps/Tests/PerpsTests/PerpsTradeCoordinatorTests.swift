@testable import Perps
import PerpsModels
import TKCoordinator
import TKLocalize
import TKTestSupport
import TKUIKit
import UIKit
import XCTest

@MainActor
final class PerpsTradeCoordinatorTests: XCTestCase {
    func testAClosedTradeFormIsReleasedWhileTheFlowGoesOn() {
        let presenter = PresentationRecorder(rootViewController: UIViewController())
        let trade = makeTrade(presenter: presenter)
        weak var modal: UIViewController?
        weak var form: UIViewController?
        weak var formViewModel: PerpsSizeChangeViewModel?
        weak var session: PerpsSizeChangeSession?

        autoreleasepool {
            trade.openEditPositionSheet(loadedPage(), directions: [.add])
            modal = presenter.presented
            form = (modal as? UINavigationController)?.viewControllers.first
            formViewModel = form.flatMap { Mirror(reflecting: $0).descendant("viewModel") } as? PerpsSizeChangeViewModel
            session = formViewModel.flatMap { Mirror(reflecting: $0).descendant("session") } as? PerpsSizeChangeSession
            XCTAssertNotNil(formViewModel)
            XCTAssertNotNil(session)

            formViewModel?.onClose?()
            presenter.presented = nil
        }

        XCTAssertNil(modal)
        XCTAssertNil(form)
        XCTAssertNil(formViewModel)
        XCTAssertNil(session)
        XCTAssertNil(Mirror(reflecting: trade).descendant("preparation", "sizeChangeSession") as? PerpsSizeChangeSession)
    }

    func testTheTradeCoordinatorGoesAwayWithTheFlowEvenWithAFormOnScreen() {
        let parent = RouterCoordinator(router: NavigationControllerRouter(rootViewController: UINavigationController()))
        let presenter = PresentationRecorder(rootViewController: UIViewController())
        weak var flow: PerpsCoordinator?
        weak var trade: PerpsTradeCoordinator?
        weak var funding: PerpsFundingCoordinator?
        weak var context: PerpsFlowContext?
        weak var preparation: PerpsTradePreparation?

        autoreleasepool {
            let perps = PerpsCoordinator(
                router: NavigationControllerRouter(rootViewController: presenter),
                perpsAssembly: StubDependencies(),
                walletDependencies: makeWallet()
            )
            parent.addChild(perps)
            perps.start()
            trade = Mirror(reflecting: perps).descendant("tradeCoordinator") as? PerpsTradeCoordinator
            funding = Mirror(reflecting: perps).descendant("fundingCoordinator") as? PerpsFundingCoordinator
            context = Mirror(reflecting: perps).descendant("context") as? PerpsFlowContext
            preparation = trade.flatMap { Mirror(reflecting: $0).descendant("preparation") } as? PerpsTradePreparation
            XCTAssertNotNil(preparation)
            trade?.openEditPositionSheet(loadedPage(), directions: [.add])
            XCTAssertNotNil(presenter.presented)
            flow = perps
            parent.removeChild(perps)
        }

        XCTAssertNil(flow)
        XCTAssertNil(trade)
        XCTAssertNil(funding)
        XCTAssertNil(context)
        XCTAssertNil(preparation)
        XCTAssertNotNil(presenter.presented)
    }

    func testTheSizeChangeTakesItsDecimalsAndPriceFromThePage() {
        let presenter = PresentationRecorder(rootViewController: UIViewController())
        let trade = makeTrade(presenter: presenter)

        trade.openEditPositionSheet(loadedPage(), directions: [.add])

        let form = (presenter.presented as? UINavigationController)?.viewControllers.first
        let viewModel = form.flatMap { Mirror(reflecting: $0).descendant("viewModel") } as? PerpsSizeChangeViewModel
        let session = Mirror(reflecting: trade).descendant("preparation", "sizeChangeSession") as? PerpsSizeChangeSession
        XCTAssertEqual(session?.priceDecimals, 4)
        XCTAssertEqual(viewModel.flatMap { Mirror(reflecting: $0).descendant("sizeDecimals") } as? Int, 3)
        XCTAssertEqual(viewModel?.priceText, PerpsFormatting.test.price(123))
    }

    func testTheLimitOrderEditorTakesItsDecimalsAndPriceFromThePage() {
        let presenter = PresentationRecorder(rootViewController: UIViewController())
        let trade = makeTrade(presenter: presenter)
        let order = PerpsLimitOrderSummary(orderIndex: 5, clientOrderIndex: 5, side: .long, limitPrice: 120, remainingBaseAmount: 1)

        trade.editLimitOrder(loadedPage(), order: order)

        let editor = (presenter.presented as? UINavigationController)?.viewControllers.first
        let viewModel = editor.flatMap { Mirror(reflecting: $0).descendant("viewModel") }
        let context = viewModel.flatMap { Mirror(reflecting: $0).descendant("context") } as? PerpsSetLimitPriceContext
        XCTAssertEqual(context?.priceDecimals, 4)
        XCTAssertEqual(context?.referencePrice, 123)
    }

    func testAFormThatFailedToLoadClosesAndStillTellsItsPage() async {
        let presenter = PresentationRecorder(rootViewController: UIViewController())
        let context = PerpsFlowContext(dependencies: StubDependencies(), wallet: makeWallet())
        let trade = makeTrade(presenter: presenter, context: context)
        let page = context.tradeRunner.outcomes(marketId: 1)

        trade.openOpenPosition(loadedPage(), side: .long)
        await waitUntil(presenter.presentations) { presenter.presented != nil }
        let form = (presenter.presented as? UINavigationController)?.viewControllers.first
        let viewModel = form.flatMap { Mirror(reflecting: $0).descendant("viewModel") } as? PerpsOpenPositionViewModel
        viewModel?.onLoadFailed?()

        let end = PerpsTradeRunner.Outcome.dismissToast(.progress("end"))
        context.tradeRunner.publish(end, marketId: 1)
        var received: [PerpsTradeRunner.Outcome] = []
        for await outcome in page {
            if outcome == end { break }
            received.append(outcome)
        }
        XCTAssertNil(context.openPositionFlow.composingMarketId)
        XCTAssertEqual(received, [.busy(false), .toast(.failure(TKLocales.Toast.serviceUnavailable))])
    }

    func testARetryWhoseFiguresCannotBeReadClosesAndTellsItsPage() async {
        let presenter = PresentationRecorder(rootViewController: UIViewController())
        let context = PerpsFlowContext(dependencies: StubDependencies(), wallet: makeWallet())
        let trade = makeTrade(presenter: presenter, context: context)
        let page = context.tradeRunner.outcomes(marketId: 1)

        trade.retryOpen(retryContext(), screen: loadedPage())
        let viewModel = confirmViewModel(in: presenter)
        XCTAssertEqual(context.openPositionFlow.composingMarketId, 1)
        XCTAssertEqual(viewModel?.isConfirmationEnabled, false)
        viewModel?.onAppear()
        await waitUntil(context.openPositionFlow) { context.openPositionFlow.composingMarketId == nil }

        let end = PerpsTradeRunner.Outcome.dismissToast(.progress("end"))
        context.tradeRunner.publish(end, marketId: 1)
        var received: [PerpsTradeRunner.Outcome] = []
        for await outcome in page {
            if outcome == end { break }
            received.append(outcome)
        }
        XCTAssertNil(context.openPositionFlow.composingMarketId)
        XCTAssertEqual(received, [.busy(false), .toast(.failure(TKLocales.Perps.Error.offline))])
    }

    func testAnOpenRefusedForTheRegionShowsTheRegionSheetOnceAndNoToast() async {
        let presenter = PresentationRecorder(rootViewController: UIViewController())
        let context = PerpsFlowContext(
            dependencies: StubDependencies(),
            wallet: makeWallet(tradingService: StubTradingService(submit: .failed(.regionUnavailable)))
        )
        let trade = makeTrade(presenter: presenter, context: context)
        let page = context.tradeRunner.outcomes(marketId: 1)
        trade.retryOpen(retryContext(), screen: loadedPage())
        let confirm = presenter.presented
        var presentations = 0
        presenter.onPresent = { presentations += 1 }

        confirmViewModel(in: presenter)?.onConfirm?()
        await waitUntil(presenter.presentations) { presenter.presented !== confirm }
        await waitUntil(context.openPositionFlow) { context.openPositionFlow.composingMarketId == nil }

        let sheet = (presenter.presented as? UINavigationController)?.viewControllers.first as? TKBottomSheetViewController
        let content = sheet.flatMap { Mirror(reflecting: $0).descendant("contentViewController") } as? InfoPopupBottomSheetViewController
        XCTAssertEqual(content?.configuration?.title, TKLocales.Perps.RegionRestricted.title)
        XCTAssertEqual(presentations, 1)
        let end = PerpsTradeRunner.Outcome.dismissToast(.progress("end"))
        context.tradeRunner.publish(end, marketId: 1)
        var received: [PerpsTradeRunner.Outcome] = []
        for await outcome in page {
            if outcome == end { break }
            received.append(outcome)
        }
        XCTAssertEqual(received, [.busy(false)])
    }

    func testOverlappingRegionRefusalsShowOneSheetAndALaterOneShowsItAgain() async {
        let presenter = PresentationRecorder(rootViewController: UIViewController())
        let context = PerpsFlowContext(dependencies: StubDependencies(), wallet: makeWallet())
        let trade = makeTrade(presenter: presenter, context: context)
        var presentations = 0
        presenter.onPresent = { presentations += 1 }

        context.tradeRunner.onRegionRestricted?(1)
        context.tradeRunner.onRegionRestricted?(2)
        await waitUntil(presenter.presentations) { presentations == 1 }
        XCTAssertEqual(presentations, 1)

        presenter.presented = nil
        context.tradeRunner.onRegionRestricted?(1)
        await waitUntil(presenter.presentations) { presentations == 2 }
        XCTAssertEqual(presentations, 2)
        withExtendedLifetime(trade) {}
    }

    func testRegionRefusalsWithNothingSettledToPresentOnTellEachPage() async {
        let presenter = PresentationRecorder(rootViewController: UIViewController())
        let context = PerpsFlowContext(dependencies: StubDependencies(), wallet: makeWallet())
        let trade = makeTrade(presenter: presenter, context: context, settles: false)
        let pages = [1, 2].map { context.tradeRunner.outcomes(marketId: $0) }

        context.tradeRunner.onRegionRestricted?(1)
        context.tradeRunner.onRegionRestricted?(2)

        for page in pages {
            var received: [PerpsTradeRunner.Outcome] = []
            for await outcome in page {
                received.append(outcome)
                if case .toast = outcome { break }
            }
            XCTAssertEqual(received, [.busy(false), .toast(.failure(TKLocales.Perps.Error.regionUnavailable))])
        }
        XCTAssertNil(presenter.presented)
        withExtendedLifetime(trade) {}
    }

    func testARetryClosedBeforeItsReadFailsLeavesANewerOpenAlone() async {
        let presenter = PresentationRecorder(rootViewController: UIViewController())
        let context = PerpsFlowContext(dependencies: StubDependencies(), wallet: makeWallet())
        let trade = makeTrade(presenter: presenter, context: context)
        let page = context.tradeRunner.outcomes(marketId: 1)
        trade.retryOpen(retryContext(), screen: loadedPage())
        let viewModel = confirmViewModel(in: presenter)
        let read = viewModel?.onRefreshReview
        let finished = expectation(description: "read finished")
        viewModel?.onRefreshReview = {
            await read?()
            finished.fulfill()
        }

        viewModel?.onAppear()
        viewModel?.close()
        XCTAssertTrue(context.openPositionFlow.begin(marketId: 1))
        await fulfillment(of: [finished], timeout: 1)

        let end = PerpsTradeRunner.Outcome.dismissToast(.progress("end"))
        context.tradeRunner.publish(end, marketId: 1)
        var received: [PerpsTradeRunner.Outcome] = []
        for await outcome in page {
            if outcome == end { break }
            received.append(outcome)
        }
        XCTAssertEqual(context.openPositionFlow.composingMarketId, 1)
        XCTAssertEqual(received, [.busy(false)])
    }

    func testAFailedOpenLeavesItsLeverageForTheNextFormAfterARelaunch() async throws {
        let suite = "PerpsTradeCoordinatorTests.openLeverage"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defaults.removePersistentDomain(forName: suite)
        defer { defaults.removePersistentDomain(forName: suite) }
        let wallet = makeWallet(
            state: .active(PerpsAccount(accountIndex: 5908, availableBalance: "100")),
            tradingService: StubTradingService(openContext: PerpsOpenMarketContext(
                marketId: 1, side: .long, symbol: "BTC", displayPrice: 123, priceDecimals: 4, sizeDecimals: 3,
                leverageBounds: PerpsLeverageBounds(min: 1, max: 20), defaultLeverage: 20, maxSlippage: 0.01,
                minBaseSize: 0.001, minNotionalUsd: 0
            ))
        )
        let presenter = PresentationRecorder(rootViewController: UIViewController())
        let context = PerpsFlowContext(
            dependencies: StubDependencies(), wallet: wallet, inputMemory: PerpsTradeInputMemory(userDefaults: defaults)
        )
        let trade = makeTrade(presenter: presenter, context: context)

        trade.openOpenPosition(loadedPage(), side: .long)
        await waitUntil(presenter.presentations) { presenter.presented != nil }
        openFormViewModel(in: presenter)?.onReview?(PerpsConfirmContext(
            intent: PerpsOpenMarketIntent(marketId: 1, side: .long, marginUsd: "10", leverage: 7, maxSlippage: 0.01, autoClose: nil),
            sizeDecimals: 3,
            priceDecimals: 4,
            review: PerpsOpenOrderReview(
                symbol: "BTC", marginUsd: 10, entryPrice: 123, liquidationPrice: nil, notionalUsd: 70, baseSize: 0.5,
                estimatedFeeUsd: nil, feeRatePercent: nil, liquidationUnavailableReason: nil
            )
        ))
        let confirm = (presenter.presented as? UINavigationController)?.viewControllers.last
        let confirmViewModel = confirm.flatMap { Mirror(reflecting: $0).descendant("viewModel") } as? PerpsTradeConfirmViewModel
        XCTAssertNotNil(confirmViewModel)
        confirmViewModel?.onConfirm?()
        await waitUntil(context.openPositionFlow) { context.openPositionFlow.activeTrade(marketId: 1) == nil }

        let relaunched = PresentationRecorder(rootViewController: UIViewController())
        let next = makeTrade(presenter: relaunched, context: PerpsFlowContext(
            dependencies: StubDependencies(), wallet: wallet, inputMemory: PerpsTradeInputMemory(userDefaults: defaults)
        ))
        next.openOpenPosition(loadedPage(), side: .long)
        await waitUntil(relaunched.presentations) { relaunched.presented != nil }
        let form = openFormViewModel(in: relaunched)
        form?.onAppear()
        if let form {
            await waitUntil(form) { form.viewState == .ready }
        }
        XCTAssertEqual(form?.viewState, .ready)
        XCTAssertEqual(form?.leverage, 7)
    }

    private func retryContext() -> PerpsConfirmContext {
        PerpsConfirmContext(
            intent: PerpsOpenMarketIntent(marketId: 1, side: .long, marginUsd: "10", leverage: 7, maxSlippage: 0.01, autoClose: nil),
            sizeDecimals: 3,
            priceDecimals: 4,
            review: PerpsOpenOrderReview(
                symbol: "BTC", marginUsd: 10, entryPrice: 123, liquidationPrice: nil, notionalUsd: 70, baseSize: 0.5,
                estimatedFeeUsd: nil, feeRatePercent: nil, liquidationUnavailableReason: nil
            )
        )
    }

    private func confirmViewModel(in presenter: PresentationRecorder) -> PerpsTradeConfirmViewModel? {
        let confirm = (presenter.presented as? UINavigationController)?.viewControllers.first
        return confirm.flatMap { Mirror(reflecting: $0).descendant("viewModel") } as? PerpsTradeConfirmViewModel
    }

    private func openFormViewModel(in presenter: PresentationRecorder) -> PerpsOpenPositionViewModel? {
        let form = (presenter.presented as? UINavigationController)?.viewControllers.first
        return form.flatMap { Mirror(reflecting: $0).descendant("viewModel") } as? PerpsOpenPositionViewModel
    }

    private func makeTrade(
        presenter: UINavigationController,
        context: PerpsFlowContext? = nil,
        settles: Bool = true
    ) -> PerpsTradeCoordinator {
        let trade = PerpsTradeCoordinator(
            router: NavigationControllerRouter(rootViewController: presenter),
            context: context ?? PerpsFlowContext(dependencies: StubDependencies(), wallet: makeWallet()),
            passcodeProvider: { nil },
            openDeposit: { _, _ in },
            sheetPresenter: { settles ? presenter : nil }
        )
        trade.start()
        return trade
    }

    private func makeWallet(
        state: PerpsWalletAccountState = .inactive,
        tradingService: StubTradingService = StubTradingService()
    ) -> PerpsWalletDependencies {
        let account = StubRootAccountStore()
        account.state = state
        account.marketLifecycle = .open(position)
        return PerpsWalletDependencies(
            accountStore: account,
            tradingService: tradingService,
            activateAccount: { _, _, _ in .canceled },
            signingPasscode: { _, _ in nil },
            recoverFunding: {},
            refreshFunding: {},
            makeDeposit: { _ in nil },
            makeHistory: { _, _, _, _, _ in nil },
            track: { _ in }
        )
    }

    private func loadedPage() -> PerpsMarketScreenContext {
        PerpsMarketScreenContext(
            market: PerpsAssetMarketSnapshot(
                marketId: 1, symbol: "BTC", displayName: "Bitcoin", status: "active", maxLeverage: 20,
                priceDecimals: 4, sizeDecimals: 3, price: 123, priceChangePercent: 0, priceChangeAmount: 0,
                volume24h: 0, openInterest: 0, fundingRatePercent: nil, about: nil, openEnabled: true
            ),
            markPrice: 123,
            lifecycle: .open(position)
        )
    }

    private let position = PerpsPositionSummary(
        positionId: "lighter:1", marketId: 1, symbol: "BTC", side: .long, baseSize: 1, notionalUsd: 100,
        marginUsd: 10, equityUsd: 10, leverage: 10, roiPercent: nil, entryPrice: 100, liquidationPrice: 90,
        unrealizedPnlUsd: 0, realizedPnlUsd: 0, fundingPaidUsd: nil
    )
}

private final class PresentationRecorder: UINavigationController {
    var presented: UIViewController?
    var onPresent: (() -> Void)?
    let presentations = TestSignal()

    override func present(_ viewController: UIViewController, animated _: Bool, completion _: (() -> Void)? = nil) {
        presented = viewController
        onPresent?()
        presentations.send()
    }
}
