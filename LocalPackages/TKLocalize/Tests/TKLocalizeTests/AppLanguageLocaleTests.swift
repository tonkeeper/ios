@testable import TKLocalize
import XCTest

final class AppLanguageLocaleTests: XCTestCase {
    func testUsesAppPreferredLocalization() {
        let locale = Locale.appLanguage(
            preferredLocalizations: ["en"],
            developmentLocalization: nil,
            fallback: Locale(identifier: "ru_RU")
        )

        XCTAssertEqual(locale.decimalSeparator, ".")
    }

    func testFallsBackToDevelopmentLocalizationForBase() {
        let locale = Locale.appLanguage(
            preferredLocalizations: ["Base"],
            developmentLocalization: "en",
            fallback: Locale(identifier: "ru_RU")
        )

        XCTAssertEqual(locale.decimalSeparator, ".")
    }
}
