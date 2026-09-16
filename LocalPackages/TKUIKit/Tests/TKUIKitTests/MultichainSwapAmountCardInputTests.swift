@testable import TKUIKit
import XCTest

final class MultichainSwapAmountCardInputTests: XCTestCase {
    func testLeadingZeroGetsDecimalSeparator() {
        XCTAssertEqual(normalize("0"), "0.")
        XCTAssertEqual(normalize("0", decimalSeparator: ","), "0,")
        XCTAssertEqual(normalize("012", decimalSeparator: ","), "0,12")
    }

    func testLeadingZeroShortcutIsSkippedWhileDeleting() {
        XCTAssertEqual(
            normalize("0", decimalSeparator: ",", interpretsLeadingZeroAsFractionalShortcut: false),
            "0"
        )
    }

    func testLeadingZeroShortcutIsSkippedForIntegerOnlyInput() {
        XCTAssertEqual(normalize("0", maximumFractionDigits: 0), "0")
    }

    func testSeparatorIsRewrittenToTheLocaleOne() {
        XCTAssertEqual(normalize("12.45", decimalSeparator: ","), "12,45")
        XCTAssertEqual(normalize("12,45"), "12.45")
    }

    func testOnlySeparatorBecomesZeroPrefixed() {
        XCTAssertEqual(normalize(","), "0.")
        XCTAssertEqual(normalize(".5", decimalSeparator: ","), "0,5")
    }

    func testSecondSeparatorAndInvalidCharactersAreDropped() {
        XCTAssertEqual(normalize("1.2.3"), "1.23")
        XCTAssertEqual(normalize("1a2"), "12")
    }

    func testFractionDigitsAreLimited() {
        XCTAssertEqual(normalize("1.23456", maximumFractionDigits: 2), "1.23")
        XCTAssertEqual(normalize("1.2", maximumFractionDigits: 0), "12")
    }

    func testEmptyInputStaysEmpty() {
        XCTAssertEqual(normalize(""), "")
        XCTAssertEqual(normalize("abc"), "")
    }

    private func normalize(
        _ raw: String,
        maximumFractionDigits: Int? = 9,
        decimalSeparator: String = ".",
        interpretsLeadingZeroAsFractionalShortcut: Bool = true
    ) -> String {
        MultichainSwapAmountCard.normalizeDecimalInput(
            raw,
            maximumFractionDigits: maximumFractionDigits,
            decimalSeparator: decimalSeparator,
            interpretsLeadingZeroAsFractionalShortcut: interpretsLeadingZeroAsFractionalShortcut
        )
    }
}
