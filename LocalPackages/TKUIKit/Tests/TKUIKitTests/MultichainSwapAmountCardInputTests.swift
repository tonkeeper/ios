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

    func testTheFieldsOwnSeparatorIsKept() {
        XCTAssertEqual(normalize("1\u{066B}5", decimalSeparator: "\u{066B}"), "1\u{066B}5")
        XCTAssertEqual(normalize("1.5", decimalSeparator: "\u{066B}"), "1\u{066B}5")
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

    func testEditInTheFieldsFormatIsNormalized() {
        XCTAssertEqual(
            normalizedText(amountText("1.234", digits: 2), previous: amountText("1.23", digits: 2)),
            "1.23"
        )
    }

    /// A currency toggle or a flip sets a text written for a new format; cut to the old one, it would
    /// come back to the screen as an edit.
    func testTextArrivingWithANewFormatIsLeftAsSet() {
        XCTAssertEqual(
            normalizedText(amountText("31.234567", digits: 6), previous: amountText("123.45", digits: 2)),
            "31.234567"
        )
        XCTAssertEqual(
            normalizedText(amountText("20.123456789", digits: 9), previous: amountText("100", digits: 6)),
            "20.123456789"
        )
        XCTAssertEqual(normalizedText(amountText("0", digits: 9), previous: amountText("1.5", digits: 2)), "0")
    }

    func testBackspacingTheSeparatorDoesNotReAddIt() {
        XCTAssertEqual(normalizedText(amountText("0", digits: 9), previous: amountText("0.", digits: 9)), "0")
    }

    private func normalizedText(
        _ amountText: MultichainSwapAmountCard.AmountText,
        previous: MultichainSwapAmountCard.AmountText
    ) -> String {
        MultichainSwapAmountCard.normalizedAmountText(amountText, previous: previous).text
    }

    private func amountText(_ text: String, digits: Int) -> MultichainSwapAmountCard.AmountText {
        MultichainSwapAmountCard.AmountText(text: text, maximumFractionDigits: digits, decimalSeparator: ".")
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
