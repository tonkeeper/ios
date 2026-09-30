@testable import KeeperCore
import XCTest

final class UtmParametersTests: XCTestCase {
    func testEveryStandardParameterIsRead() {
        let parameters = UtmParameters(
            link: "tonkeeper://staking?utm_source=newsletter&utm_medium=email"
                + "&utm_campaign=autumn_2026&utm_term=stake&utm_content=header_button"
        )

        XCTAssertEqual(parameters.source, "newsletter")
        XCTAssertEqual(parameters.medium, "email")
        XCTAssertEqual(parameters.campaign, "autumn_2026")
        XCTAssertEqual(parameters.term, "stake")
        XCTAssertEqual(parameters.content, "header_button")
        XCTAssertFalse(parameters.isEmpty)
    }

    func testUniversalLinksAndPartialTaggingAreRead() {
        let parameters = UtmParameters(link: "https://app.tonkeeper.com/transfer/EQD?amount=1&utm_source=promo")

        XCTAssertEqual(parameters.source, "promo")
        XCTAssertNil(parameters.campaign)
        XCTAssertFalse(parameters.isEmpty)
    }

    func testDoubleEncodedLinkStillCarriesItsCampaign() {
        let parameters = UtmParameters(link: "tonkeeper://dapp/https%253A%252F%252Fapp.io%253Futm_source%253Dpromo")

        XCTAssertEqual(parameters.source, "promo")
    }

    func testUntaggedLinksCarryNothing() {
        XCTAssertTrue(UtmParameters(link: nil).isEmpty)
        XCTAssertTrue(UtmParameters(link: "").isEmpty)
        XCTAssertTrue(UtmParameters(link: "tonkeeper://staking").isEmpty)
        XCTAssertTrue(UtmParameters(link: "tonkeeper://staking?utm_source=").isEmpty)
        XCTAssertTrue(UtmParameters(link: "tonkeeper://staking?utm_source=%20%20").isEmpty)
        // The parameter names are case sensitive, the way every campaign builder writes them.
        XCTAssertTrue(UtmParameters(link: "tonkeeper://staking?UTM_SOURCE=promo").isEmpty)
        // A label inside a nested url belongs to that url, not to the link that carries it.
        XCTAssertTrue(UtmParameters(
            link: "tonkeeper://browser?url=https%3A%2F%2Fexample.com%2F%3Fx%3D1%26utm_source%3Dnested"
        ).isEmpty)
    }

    func testValuesAreTrimmed() {
        XCTAssertEqual(UtmParameters(link: "tonkeeper://staking?utm_source=%20promo%20").source, "promo")
    }
}
