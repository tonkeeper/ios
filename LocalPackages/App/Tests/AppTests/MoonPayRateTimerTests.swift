@testable import App
import XCTest

@MainActor
final class MoonPayRateTimerTests: XCTestCase {
    func test_timerEndsOneSecondBeforeTheQuoteExpires() {
        XCTAssertEqual(MoonPayRampViewModel.rateTimerDuration(forQuoteLifetime: 10), 9)
    }

    func test_shortLifetimeNeverShrinksTheTimerBelowTheFloor() {
        XCTAssertEqual(MoonPayRampViewModel.rateTimerDuration(forQuoteLifetime: 2), 3)
        XCTAssertEqual(MoonPayRampViewModel.rateTimerDuration(forQuoteLifetime: -5), 3)
    }

    func test_longLifetimeIsCapped() {
        XCTAssertEqual(MoonPayRampViewModel.rateTimerDuration(forQuoteLifetime: 600), 60)
    }
}
