@testable import Perps
import PerpsModels
import TKLocalize
import XCTest

/// The root screen's word on a deposit is read from the journal through the account store,
/// and it has to survive the store announcing unrelated changes in between. A change is fed to
/// `applyFunding` directly: the store observer only hops to the main actor before calling it.
@MainActor
final class PerpsRootDepositToastTests: XCTestCase {
    func testADepositOnItsWayIsShownUntilItArrivesAndThenConfirmed() {
        let account = StubRootAccountStore()
        account.activity = PerpsFundingActivity(inFlight: ["op-1"])
        let viewModel = makeViewModel(account: account)

        XCTAssertEqual(viewModel.fundingToast, .progress(TKLocales.Perps.Toast.depositSending))

        viewModel.applyFunding(PerpsFundingActivity(completed: ["op-1"]))

        XCTAssertEqual(viewModel.fundingToast, .success(TKLocales.Perps.Toast.depositConfirmed))

        // Another change while the confirmation is up must not take it down early.
        viewModel.applyFunding(PerpsFundingActivity(completed: ["op-1"]))
        XCTAssertEqual(viewModel.fundingToast, .success(TKLocales.Perps.Toast.depositConfirmed))
    }

    func testADepositCreditedBeforeTheScreenSawItIsNotAnnounced() {
        let account = StubRootAccountStore()
        account.activity = PerpsFundingActivity(completed: ["op-1"])

        XCTAssertNil(makeViewModel(account: account).fundingToast)
    }

    func testAcceptedWithdrawalStopsSayingSendingAndCanStillAnnounceSettlement() {
        let account = StubRootAccountStore()
        account.activity = PerpsFundingActivity(inFlight: ["withdraw"])
        let viewModel = makeViewModel(account: account)

        viewModel.applyFunding(PerpsFundingActivity(pending: ["withdraw"]))
        XCTAssertNil(viewModel.fundingToast)

        viewModel.applyFunding(PerpsFundingActivity(completed: ["withdraw"]))
        XCTAssertEqual(viewModel.fundingToast, .success(TKLocales.Perps.Toast.depositConfirmed))
    }

    func testADepositThatFailedOnTheWayLeavesNothingBehind() {
        let account = StubRootAccountStore()
        account.activity = PerpsFundingActivity(inFlight: ["op-1"])
        let viewModel = makeViewModel(account: account)

        viewModel.applyFunding(PerpsFundingActivity())

        XCTAssertNil(viewModel.fundingToast)
    }

    func testOneArrivalWhileAnotherIsStillOnItsWayKeepsSaying() {
        let account = StubRootAccountStore()
        account.activity = PerpsFundingActivity(inFlight: ["op-1", "op-2"])
        let viewModel = makeViewModel(account: account)

        viewModel.applyFunding(PerpsFundingActivity(inFlight: ["op-2"], completed: ["op-1"]))

        XCTAssertEqual(viewModel.fundingToast, .progress(TKLocales.Perps.Toast.depositSending))
    }

    func testTheToastOpensTheHistoryOnTheOperationItIsAbout() {
        let account = StubRootAccountStore()
        let transactions = ["op-1": Set(["0xsource", "0xgateway"]), "op-2": Set(["0xother"])]
        account.activity = PerpsFundingActivity(inFlight: ["op-1"], completed: ["op-2"], transactions: transactions)
        let viewModel = makeViewModel(account: account)
        var opened: [Set<String>] = []
        viewModel.onOpenFunding = { opened.append($0) }

        viewModel.openFundingToast()
        viewModel.applyFunding(PerpsFundingActivity(completed: ["op-1", "op-2"], transactions: transactions))
        viewModel.openFundingToast()

        XCTAssertEqual(opened, [["0xsource", "0xgateway"], ["0xsource", "0xgateway"]])
    }

    func testNoToastOpensNothing() {
        let account = StubRootAccountStore()
        account.activity = PerpsFundingActivity(completed: ["op-1"], transactions: ["op-1": ["0xsource"]])
        let viewModel = makeViewModel(account: account)
        var opened = false
        viewModel.onOpenFunding = { _ in opened = true }

        viewModel.openFundingToast()

        XCTAssertFalse(opened)
    }

    private func makeViewModel(account: StubRootAccountStore) -> PerpsViewModel {
        PerpsViewModel(
            marketsStore: StubRootMarketsStore(),
            accountStore: account,
            format: PerpsFormatting(amounts: PerpsTestAmountFormatting())
        )
    }
}

final class StubRootAccountStore: PerpsAccountStoring {
    var activity = PerpsFundingActivity()
    var state: PerpsWalletAccountState = .inactive

    func addChangeObserver<T: AnyObject>(_: T, onChange _: @escaping (T) -> Void) {}

    func currentWalletState() -> PerpsWalletAccountState {
        state
    }

    func resolveIfNeeded() {}
    func refresh() {}
    func fundingActivity() -> PerpsFundingActivity {
        activity
    }

    func lifecycle(marketId _: Int64) -> PerpsMarketLifecycle {
        .flat
    }

    func matchingPosition(marketId _: Int64) -> PerpsPositionSummary? {
        nil
    }

    func beginOpening(_: PerpsOpeningDescriptor) {}
    func beginClosing(marketId _: Int64) {}
    func beginAdjusting(marketId _: Int64, direction _: PerpsSizeChangeDirection, baseSizeBefore _: Double) {}
    func beginAdjustingMargin(
        marketId _: Int64,
        direction _: PerpsMarginChangeDirection,
        allocatedMarginBefore _: Double,
        amountUsd _: Double
    ) {}
    func clearPending(marketId _: Int64) {}
    func marketExtras(marketId _: Int64) -> PerpsMarketExtras? {
        nil
    }

    func loadMarketExtras(marketId _: Int64, clearingPending _: Bool) {}
    func releaseMarketExtras(marketId _: Int64) {}
    func subscribePositions(cadence _: PerpsPositionsCadence) {}
    func unsubscribePositions(cadence _: PerpsPositionsCadence) {}
}

final class StubRootMarketsStore: PerpsMarketsStoring {
    private final class NoInterest: PerpsPriceInteresting {
        func set(marketIds _: Set<Int64>) {}
        func clear() {}
    }

    func addChangeObserver<T: AnyObject>(_: T, onChange _: @escaping (T) -> Void) {}
    func getState() -> PerpsMarketsState {
        .idle
    }

    func subscribe() {}
    func unsubscribe() {}
    func setSort(_: PerpsMarketsSort) {}
    func loadNextPage() {}
    func makePriceInterest() -> any PerpsPriceInteresting {
        NoInterest()
    }

    func price(marketId _: Int64) async -> Double? {
        nil
    }

    func snapshot(marketId _: Int64) async -> PerpsAssetMarketSnapshot? {
        nil
    }
}
