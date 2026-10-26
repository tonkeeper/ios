@testable import Perps
import PerpsModels
import XCTest

@MainActor
final class PerpsDraftReviewerTests: XCTestCase {
    func test_reload_landsAfterALoadAlreadyInFlight() async {
        let draftReviewer = PerpsDraftReviewer()
        let older = StubReviewer()
        let fresher = StubReviewer()
        let (started, startedContinuation) = AsyncStream<Void>.makeStream()
        let (release, releaseContinuation) = AsyncStream<Void>.makeStream()
        draftReviewer.loadIfNeeded {
            startedContinuation.yield()
            for await _ in release {
                break
            }
            return older
        } then: {}
        for await _ in started {
            break
        }

        let reloaded = Task { await draftReviewer.reload { fresher } }
        releaseContinuation.yield()
        await reloaded.value

        XCTAssertTrue(draftReviewer.current === fresher)
    }
}

private final class StubReviewer: PerpetualReviewer {
    let isStale = false

    func reviewOpen(_: PerpsOpenMarketIntent) -> PerpsOpenOrderReview? {
        nil
    }

    func minimumOpenMarginUsd(_: PerpsOpenMarketIntent) -> Double? {
        nil
    }

    func reviewMarginChange(_: PerpsMarginChangeIntent) -> PerpsMarginChangeReview? {
        nil
    }
}
