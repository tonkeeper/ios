@testable import App
@testable import KeeperCore
import XCTest

final class EarnDappMatcherTests: XCTestCase {
    func test_earnHostMatches() throws {
        XCTAssertTrue(
            try makeMatcher().matches(url: url("https://vaults.fyi/"))
        )
    }

    func test_earnHostSubdomainMatches() throws {
        XCTAssertTrue(
            try makeMatcher().matches(url: url("https://app.vaults.fyi/earn"))
        )
    }

    func test_hostMatchIgnoresCase() throws {
        XCTAssertTrue(
            try makeMatcher().matches(url: url("HTTPS://App.Vaults.FYI/earn"))
        )
    }

    func test_lookalikeHostDoesNotMatch() throws {
        let matcher = try makeMatcher()

        XCTAssertFalse(try matcher.matches(url: url("https://vaults.fyi.evil.io/earn")))
        XCTAssertFalse(try matcher.matches(url: url("https://myvaults.fyi/earn")))
    }

    func test_insecureSchemeDoesNotMatch() throws {
        XCTAssertFalse(
            try makeMatcher().matches(url: url("http://vaults.fyi/earn"))
        )
    }

    func test_hostOutsideEarnDoesNotMatch() throws {
        XCTAssertFalse(
            try makeMatcher().matches(url: url("https://app.ston.fi/swap"))
        )
    }

    func test_otherPortDoesNotMatch() throws {
        let matcher = try makeMatcher()

        XCTAssertFalse(try matcher.matches(url: url("https://vaults.fyi:8443/earn")))
        XCTAssertTrue(try matcher.matches(url: url("https://vaults.fyi:443/earn")))
    }

    func test_parentOfTheEarnHostDoesNotMatch() throws {
        XCTAssertFalse(
            try makeMatcher(earnURL: "https://app.vaults.fyi/earn").matches(url: url("https://vaults.fyi/earn"))
        )
    }

    func test_onlyTheConfiguredEarnHostMatches() throws {
        let matcher = try makeMatcher(earnURL: "https://earn.example.com/")

        XCTAssertTrue(try matcher.matches(url: url("https://earn.example.com/earn/base/0xVAULT")))
        XCTAssertFalse(try matcher.matches(url: url("https://vaults.fyi/")))
        XCTAssertFalse(try matcher.matches(url: url("https://vaults-tonkeeper-earn-demo.fly.dev/")))
    }

    func test_insecureEarnPageMatchesNothing() throws {
        let matcher = try makeMatcher(earnURL: "http://vaults.fyi/")

        XCTAssertFalse(try matcher.matches(url: url("http://vaults.fyi/earn")))
        XCTAssertFalse(try matcher.matches(url: url("https://vaults.fyi/earn")))
    }

    func test_vaultPageOfTheDefaultEarnPageMatches() {
        let earnURL = BootConfiguration.empty.earnUrl

        XCTAssertTrue(
            EarnDappMatcher(earnURL: earnURL).matches(url: earnURL.appendingEarnVaultPath(network: "base", vaultId: "0xVAULT"))
        )
    }
}

private extension EarnDappMatcherTests {
    func makeMatcher(earnURL: String = "https://vaults.fyi/") throws -> EarnDappMatcher {
        try EarnDappMatcher(earnURL: url(earnURL))
    }

    func url(_ string: String) throws -> URL {
        try XCTUnwrap(URL(string: string))
    }
}
