@testable import App
import Combine
@testable import KeeperCore
import XCTest

@MainActor
final class PerpsTradeConfirmViewModelTests: XCTestCase {
    /// The observer is registered once for the view model's lifetime; appear
    /// cycles only balance the price interest. A second cycle used to stack a
    /// duplicate observer, doubling every rows refresh.
    func test_appearCycles_keepSinglePricesObserver() async throws {
        let store = PerpsMarketsStore.makeForTests()
        let session = FakePerpsTradingService.makeReviewingSizeChangeSession()
        let viewModel = try XCTUnwrap(PerpsTradeConfirmViewModel(
            sizeChangeSession: session,
            sizeDecimals: 2,
            marketsStore: store
        ))

        viewModel.onAppear()
        viewModel.onDisappear()
        viewModel.onAppear()

        // Let the interest churn from the appear cycles settle before counting.
        try await Task.sleep(nanoseconds: 300_000_000)

        var refreshes = 0
        let watching = viewModel.$rows.dropFirst().sink { _ in refreshes += 1 }
        store.sendEvent(.didUpdate(store.getState()))
        try await Task.sleep(nanoseconds: 500_000_000)
        withExtendedLifetime(watching) {}

        XCTAssertEqual(refreshes, 1, "one prices event must refresh the confirm rows exactly once")
        viewModel.onDisappear()
    }
}
