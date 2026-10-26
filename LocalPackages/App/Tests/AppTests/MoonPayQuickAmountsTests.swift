@testable import App
import XCTest

@MainActor
final class MoonPayQuickAmountsTests: XCTestCase {
    func test_withoutMinimum_usesDefaults() {
        XCTAssertEqual(MoonPayRampViewModel.quickAmounts(minimum: nil), [50, 100, 500])
        XCTAssertEqual(MoonPayRampViewModel.quickAmounts(minimum: 0), [50, 100, 500])
    }

    func test_dollarMinimum_keepsDefaults() {
        XCTAssertEqual(MoonPayRampViewModel.quickAmounts(minimum: 20), [50, 100, 500])
    }

    func test_scalesWithTheMinimumOfTheCurrency() {
        XCTAssertEqual(MoonPayRampViewModel.quickAmounts(minimum: 2800), [5000, 10000, 50000])
        XCTAssertEqual(MoonPayRampViewModel.quickAmounts(minimum: 10), [20, 50, 200])
    }

    func test_collidingOptionsStepUpToTheNextRoundValue() {
        XCTAssertEqual(MoonPayRampViewModel.quickAmounts(minimum: 6), [20, 50, 200])
    }

    func test_optionsAreAlwaysThreeAndStrictlyIncreasing() {
        for minimum in stride(from: Decimal(1), through: 5000, by: 7) {
            let amounts = MoonPayRampViewModel.quickAmounts(minimum: minimum)
            XCTAssertEqual(amounts.count, 3, "minimum \(minimum)")
            XCTAssertEqual(amounts, amounts.sorted(), "minimum \(minimum)")
            XCTAssertEqual(Set(amounts).count, 3, "minimum \(minimum)")
        }
    }
}
