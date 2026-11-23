@testable import TKUIKit
import UIKit
import XCTest

final class TKAmountDigitsTests: XCTestCase {
    func testIntegerPartIsGroupedByThousandsWithSpaces() {
        XCTAssertEqual(TKAmountDigits.grouped("1234567.891"), "1 234 567.891")
        XCTAssertEqual(TKAmountDigits.grouped("1000,5"), "1 000,5")
        XCTAssertEqual(TKAmountDigits.grouped("999"), "999")
        XCTAssertEqual(TKAmountDigits.grouped("0.1234567"), "0.1234567")
        XCTAssertEqual(TKAmountDigits.grouped(".1234567"), ".1234567")
        XCTAssertEqual(TKAmountDigits.grouped("-12345"), "-12 345")
        XCTAssertEqual(TKAmountDigits.grouped("1 2345"), "12 345")
        XCTAssertEqual(TKAmountDigits.grouped("22\u{00A0}043,1"), "22 043,1")
        XCTAssertEqual(TKAmountDigits.grouped(""), "")
        XCTAssertEqual(TKAmountDigits.ungrouped("1 234 567.8"), "1234567.8")
    }

    func testAnAmountIsNormalizedToAsciiDigitsWithADot() {
        XCTAssertEqual(TKAmountDigits.normalized("1,5"), "1.5")
        XCTAssertEqual(TKAmountDigits.normalized("1\u{066B}5"), "1.5")
        XCTAssertEqual(TKAmountDigits.normalized("1 234,56"), "1234.56")
        XCTAssertEqual(TKAmountDigits.normalized("1\u{00A0}234\u{202F}567,8\n"), "1234567.8")
        XCTAssertEqual(TKAmountDigits.normalized("\u{0661}\u{0662}\u{0663}\u{066B}\u{0664}\u{0665}"), "123.45")
        XCTAssertEqual(TKAmountDigits.normalized("\u{06F1}\u{06F2}\u{06F3}\u{066B}\u{06F4}\u{06F5}"), "123.45")
        XCTAssertEqual(TKAmountDigits.normalized("\u{FF11}\u{FF12}\u{FF0E}\u{1D7D1}"), "12.3")
        XCTAssertEqual(TKAmountDigits.normalized("0,000000001"), "0.000000001")
        XCTAssertEqual(TKAmountDigits.normalized("5."), "5.")
        XCTAssertEqual(TKAmountDigits.normalized(",5"), ".5")
        XCTAssertEqual(TKAmountDigits.normalized(","), ".")
        XCTAssertEqual(TKAmountDigits.normalized(""), "")
    }

    func testSeparatorsInARowCountOnce() {
        XCTAssertEqual(TKAmountDigits.normalized("0..05"), "0.05")
        XCTAssertEqual(TKAmountDigits.normalized("0,,"), "0.")
        XCTAssertEqual(TKAmountDigits.normalized("0,.5"), "0.5")
        XCTAssertEqual(TKAmountDigits.normalized("0\u{066B}\u{066B}5"), "0.5")
        XCTAssertEqual(TKAmountDigits.normalized("..5"), ".5")
    }

    func testASecondSeparatorAfterDigitsIsRejected() {
        XCTAssertNil(TKAmountDigits.normalized("1.5."))
        XCTAssertNil(TKAmountDigits.normalized("1,5,"))
        XCTAssertNil(TKAmountDigits.normalized("1.5.2"))
        XCTAssertNil(TKAmountDigits.normalized("1.234,56"))
        XCTAssertNil(TKAmountDigits.normalized("1,234.56"))
        XCTAssertNil(TKAmountDigits.normalized("1.234.567,89"))
        XCTAssertNil(TKAmountDigits.normalized("192.168.1.1"))
    }

    func testTextThatIsNotAnAmountIsRejected() {
        XCTAssertNil(TKAmountDigits.normalized("-5"))
        XCTAssertNil(TKAmountDigits.normalized("1e3"))
        XCTAssertNil(TKAmountDigits.normalized("abc"))
        XCTAssertNil(TKAmountDigits.normalized("$5"))
        XCTAssertNil(TKAmountDigits.normalized("1\u{2019}234.5"))
    }

    func testASignIsKeptOnlyWhereItIsAllowedAndLeads() {
        XCTAssertEqual(TKAmountDigits.normalized("-5,06", allowsSign: true), "-5.06")
        XCTAssertEqual(TKAmountDigits.normalized("\u{2212}5", allowsSign: true), "-5")
        XCTAssertEqual(TKAmountDigits.normalized("+5", allowsSign: true), "+5")
        XCTAssertEqual(TKAmountDigits.normalized("-", allowsSign: true), "-")
        XCTAssertNil(TKAmountDigits.normalized("5-", allowsSign: true))
        XCTAssertNil(TKAmountDigits.normalized("--5", allowsSign: true))
        XCTAssertNil(TKAmountDigits.normalized(".-5", allowsSign: true))
    }

    func testTheDecimalSeparatorIsShownAsTheLocaleWritesIt() {
        XCTAssertEqual(TKAmountDigits.localized("2.5", decimalSeparator: ","), "2,5")
        XCTAssertEqual(TKAmountDigits.localized("70 000.5", decimalSeparator: ","), "70 000,5")
        XCTAssertEqual(TKAmountDigits.localized("-5.06", decimalSeparator: "\u{066B}"), "-5\u{066B}06")
        XCTAssertEqual(TKAmountDigits.localized("2,5", decimalSeparator: "."), "2.5")
        XCTAssertEqual(TKAmountDigits.localized("1234", decimalSeparator: ","), "1234")
        XCTAssertEqual(TKAmountDigits.localized("", decimalSeparator: ","), "")
    }

    func testKeysAreDrawnWithTheDigitsOfTheSystemLocale() {
        let arabic = Locale(identifier: "ar_SA")
        XCTAssertEqual(TKAmountDigits.keyTitle("1", locale: arabic), "\u{0661}")
        XCTAssertEqual(TKAmountDigits.keyTitle("0", locale: arabic), "\u{0660}")
        XCTAssertEqual(TKAmountDigits.keyTitle(".", locale: arabic), "\u{066B}")
        XCTAssertEqual(TKAmountDigits.keyTitle("9", locale: Locale(identifier: "fa_IR")), "\u{06F9}")
        XCTAssertEqual(TKAmountDigits.keyTitle("1", locale: Locale(identifier: "ar_SA@numbers=latn")), "1")
        XCTAssertEqual(TKAmountDigits.keyTitle("1", locale: Locale(identifier: "ar_AE")), "1")
        XCTAssertEqual(TKAmountDigits.keyTitle(".", locale: Locale(identifier: "fr_CA")), ".")
        XCTAssertEqual(TKAmountDigits.keyTitle(",", locale: Locale(identifier: "en_US")), ",")
    }

    func testOffsetCountsCharactersPastTheGroupingSpaces() {
        let grouped = "12 345.6"

        XCTAssertEqual(TKAmountDigits.offset(afterCharacters: 0, in: grouped), 0)
        XCTAssertEqual(TKAmountDigits.offset(afterCharacters: 2, in: grouped), 2)
        XCTAssertEqual(TKAmountDigits.offset(afterCharacters: 3, in: grouped), 4)
        XCTAssertEqual(TKAmountDigits.offset(afterCharacters: 7, in: grouped), 8)
    }

    func testDigitsTypedAtTheEndKeepTheGlyphsBeforeThem() {
        let font = UIFont.systemFont(ofSize: 28)
        let ids = { TKAmountDigits.glyphs($0, font: font).glyphs.map(\.id) }

        XCTAssertEqual(ids("6 666"), ["i0:6", "g1", "i1:6", "i2:6", "i3:6"])
        XCTAssertEqual(ids("66 666"), ["i0:6", "i1:6", "g2", "i2:6", "i3:6", "i4:6"])
        XCTAssertEqual(ids("0,05"), ["i0:0", "d", "f0:0", "f1:5"])
        XCTAssertEqual(ids("-5"), ["o0:-", "i0:5"])
    }

    func testTextFitsAFieldSizedToItsUnroundedWidth() {
        let font = UIFont.systemFont(ofSize: 32)
        let width = ("12 345.67" as NSString).size(withAttributes: [.font: font]).width

        XCTAssertTrue(TKAmountDigits.fits("12 345.67", font: font, width: width))
        XCTAssertFalse(TKAmountDigits.fits("12 345.67", font: font, width: width - 2))
    }

    func testGlyphsAreLaidOutAsOneLine() {
        let font = UIFont.systemFont(ofSize: 28)
        let layout = TKAmountDigits.glyphs("12 345.6", font: font)
        let offsets = layout.glyphs.map(\.x)

        XCTAssertEqual(offsets.first, 0)
        XCTAssertEqual(offsets, offsets.sorted())
        XCTAssertEqual(layout.width, ceil(("12 345.6" as NSString).size(withAttributes: [.font: font]).width), accuracy: 1)
    }
}
