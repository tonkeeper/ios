import Foundation
@testable import KeeperCore
import XCTest

final class AppSettingsCodableTests: XCTestCase {
    func test_decodingLegacyPayload_appliesFilterDefaults() throws {
        let legacyPayload = Data("""
        {"isSecureMode": true, "searchEngine": "Google"}
        """.utf8)

        let settings = try JSONDecoder().decode(KeeperInfo.AppSettings.self, from: legacyPayload)

        XCTAssertTrue(settings.isSecureMode)
        XCTAssertEqual(settings.searchEngine, .google)
        XCTAssertFalse(settings.hidesDustTransactions)
        XCTAssertFalse(settings.hidesDustBalances)
    }

    func test_codingRoundTrip_preservesFilterFlags() throws {
        let settings = KeeperInfo.AppSettings(
            isSecureMode: false,
            searchEngine: .duckduckgo,
            hidesDustTransactions: true,
            hidesDustBalances: true
        )

        let decoded = try JSONDecoder().decode(
            KeeperInfo.AppSettings.self,
            from: JSONEncoder().encode(settings)
        )

        XCTAssertEqual(decoded, settings)
    }

    func test_updating_changesOnlyRequestedFields() {
        let settings = KeeperInfo.AppSettings(
            isSecureMode: true,
            searchEngine: .google,
            hidesDustTransactions: true,
            hidesDustBalances: false
        )

        let updated = settings.updating(hidesDustBalances: true)

        XCTAssertEqual(
            updated,
            KeeperInfo.AppSettings(
                isSecureMode: true,
                searchEngine: .google,
                hidesDustTransactions: true,
                hidesDustBalances: true
            )
        )
    }
}
