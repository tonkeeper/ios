@testable import App
import KeeperCore
import TKUIKit
import UIKit
import XCTest

final class SendAmountTextFieldFormatterTests: XCTestCase {
    @MainActor
    func testLeadingZeroShortcutFormatsSequentialInput() {
        let formatter = makeFormatter()
        let textField = UITextField()
        let separator = AmountFormatter.Configuration.defaultLocale.decimalSeparator ?? "."

        apply(formatter, to: textField, replacement: "0")
        XCTAssertEqual(textField.text, "0\(separator)")

        apply(formatter, to: textField, replacement: "0")
        apply(formatter, to: textField, replacement: "0")
        apply(formatter, to: textField, replacement: "0")

        XCTAssertEqual(textField.text, "0\(separator)000")
    }

    @MainActor
    func testLeadingZeroShortcutFormatsPastedInput() {
        let formatter = makeFormatter()
        let textField = UITextField()
        let separator = AmountFormatter.Configuration.defaultLocale.decimalSeparator ?? "."

        apply(formatter, to: textField, replacement: "01")
        XCTAssertEqual(textField.text, "0\(separator)1")

        apply(
            formatter,
            to: textField,
            replacement: "001",
            range: NSRange(location: 0, length: textField.text?.utf16.count ?? 0)
        )
        XCTAssertEqual(textField.text, "0\(separator)01")
    }

    @MainActor
    func testLeadingZeroShortcutCanBeDeleted() {
        let formatter = makeFormatter()
        let textField = UITextField()
        let separator = AmountFormatter.Configuration.defaultLocale.decimalSeparator ?? "."

        apply(formatter, to: textField, replacement: "0")
        XCTAssertEqual(textField.text, "0\(separator)")

        apply(
            formatter,
            to: textField,
            replacement: "",
            range: NSRange(location: 1, length: separator.utf16.count)
        )
        XCTAssertEqual(textField.text, "0")

        apply(
            formatter,
            to: textField,
            replacement: "",
            range: NSRange(location: 0, length: 1)
        )
        XCTAssertEqual(textField.text, "")
    }

    @MainActor
    func testDeletingDecimalSeparatorFromFractionalInputTurnsItIntoIntegerInput() {
        let formatter = makeFormatter()
        let textField = UITextField()
        let separator = AmountFormatter.Configuration.defaultLocale.decimalSeparator ?? "."

        apply(formatter, to: textField, replacement: "0")
        apply(formatter, to: textField, replacement: "1")
        XCTAssertEqual(textField.text, "0\(separator)1")

        apply(
            formatter,
            to: textField,
            replacement: "",
            range: NSRange(location: 1, length: separator.utf16.count)
        )
        XCTAssertEqual(textField.text, "1")
        XCTAssertEqual(formatter.unformatString(textField.text), "1")
    }

    @MainActor
    func testZeroFractionDigitsDoNotUseFractionalShortcut() {
        let formatter = makeFormatter(maximumFractionDigits: 0)
        let textField = UITextField()

        apply(formatter, to: textField, replacement: "0")
        XCTAssertEqual(textField.text, "0")

        apply(
            formatter,
            to: textField,
            replacement: ".",
            range: NSRange(location: 0, length: textField.text?.utf16.count ?? 0)
        )
        XCTAssertEqual(textField.text, "0")

        apply(
            formatter,
            to: textField,
            replacement: "01",
            range: NSRange(location: 0, length: textField.text?.utf16.count ?? 0)
        )
        XCTAssertEqual(textField.text, "1")
    }

    @MainActor
    func testConvertsArabicLocaleDigitsToAsciiDuringTextFieldInput() {
        let formatter = makeFormatter()
        let textField = UITextField()

        apply(formatter, to: textField, replacement: "\u{0661}")
        apply(formatter, to: textField, replacement: "\u{0662}")
        apply(formatter, to: textField, replacement: "\u{0663}")

        XCTAssertEqual(textField.text, "123")
    }

    @MainActor
    func testAcceptsArabicDecimalSeparatorsDuringTextFieldInput() {
        let formatter = makeFormatter()
        let separator = AmountFormatter.Configuration.defaultLocale.decimalSeparator ?? "."

        for arabicSeparator in ["\u{066B}", "\u{060C}"] {
            let textField = UITextField()

            apply(formatter, to: textField, replacement: "\u{0661}")
            apply(formatter, to: textField, replacement: arabicSeparator)
            apply(formatter, to: textField, replacement: "\u{0662}")
            apply(formatter, to: textField, replacement: "\u{0663}")

            XCTAssertEqual(textField.text, "1\(separator)23")
        }
    }

    func testUnformatStringRemovesGroupingSeparatorsForProgrammaticInput() {
        let formatter = makeFormatter()
        let separator = AmountFormatter.Configuration.defaultLocale.decimalSeparator ?? "."

        XCTAssertEqual(
            formatter.unformatString("12 345.67"),
            "12345\(separator)67"
        )
        XCTAssertEqual(
            formatter.unformatString("12\u{202F}345,67"),
            "12345\(separator)67"
        )
    }

    @MainActor
    func testNumPadGroupsTheIntegerPartWithSpaces() {
        TKNumPadView.isEnabled = true
        defer { TKNumPadView.isEnabled = false }
        let formatter = makeFormatter()
        let textField = UITextField()
        let separator = AmountFormatter.Configuration.defaultLocale.decimalSeparator ?? "."

        for character in ["1", "2", "3", "4", separator, "5"] {
            apply(formatter, to: textField, replacement: character)
        }
        XCTAssertEqual(textField.text, "1 234\(separator)5")

        apply(formatter, to: textField, replacement: "", range: NSRange(location: 2, length: 1))
        XCTAssertEqual(textField.text, "134\(separator)5")

        apply(formatter, to: textField, replacement: "98", range: NSRange(location: 0, length: 0))
        XCTAssertEqual(textField.text, "98 134\(separator)5")
    }

    @MainActor
    private func apply(
        _ formatter: SendAmountTextFieldFormatter,
        to textField: UITextField,
        replacement: String,
        range: NSRange? = nil
    ) {
        let range = range ?? NSRange(location: textField.text?.utf16.count ?? 0, length: 0)
        let shouldChange = formatter.textField(
            textField,
            shouldChangeCharactersIn: range,
            replacementString: replacement
        )
        XCTAssertFalse(shouldChange)
    }

    private func makeFormatter(maximumFractionDigits: Int = 9) -> SendAmountTextFieldFormatter {
        let numberFormatter = NumberFormatter()
        numberFormatter.maximumIntegerDigits = 16
        numberFormatter.maximumFractionDigits = maximumFractionDigits
        let formatter = SendAmountTextFieldFormatter(currencyFormatter: numberFormatter)
        formatter.maximumFractionDigits = maximumFractionDigits
        return formatter
    }
}
