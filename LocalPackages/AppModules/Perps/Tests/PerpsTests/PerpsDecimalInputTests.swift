@testable import Perps
import XCTest

final class PerpsDecimalInputTests: XCTestCase {
    func test_sanitize_stripsInvalidCharactersAndExtraSeparators() {
        XCTAssertEqual(PerpsDecimalInput.sanitize("1a2.3.4", decimals: 2), "12.34")
    }

    func test_sanitize_normalizesUnicodeDigitsAndComma() {
        XCTAssertEqual(PerpsDecimalInput.sanitize("\u{0660}\u{0661},\u{0662}\u{0663}", decimals: 2), "1.23")
    }

    func test_sanitize_limitsFractionAndLeadingZeros() {
        XCTAssertEqual(PerpsDecimalInput.sanitize("00012.345", decimals: 2), "12.34")
    }

    func test_sanitize_preservesLegacyFallbackWhenFractionsAreDisabled() {
        XCTAssertEqual(PerpsDecimalInput.sanitize("12.3", decimals: 0), "12.3")
    }

    func test_double_acceptsBothDecimalSeparators() {
        XCTAssertEqual(PerpsDecimalInput.double(" 20,5 "), 20.5)
    }

    func test_usdText_roundsDownToCentsSoMaxStaysWithinBalance() {
        XCTAssertEqual(PerpsDecimalInput.usdText(10.076543), "10.07")
        XCTAssertEqual(PerpsDecimalInput.usdText(1.13), "1.13")
        XCTAssertEqual(PerpsDecimalInput.usdText(1.13.nextDown), "1.13")
        XCTAssertEqual(PerpsDecimalInput.usdText(8.2), "8.2")
    }

    func test_text_clampsPrecisionAndTrimsTrailingZeros() {
        XCTAssertEqual(PerpsDecimalInput.text(12.34000001, decimals: 12), "12.34000001")
        XCTAssertEqual(PerpsDecimalInput.text(12.3, decimals: 2), "12.3")
    }
}
