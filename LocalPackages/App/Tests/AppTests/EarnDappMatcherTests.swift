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
        let matcher = makeMatcher()

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

    func test_earnHostsCoverProductionAndDemoStand() {
        XCTAssertEqual(
            EarnDappMatcher.earnHostSuffixes,
            ["vaults.fyi", "vaults-tonkeeper-earn-demo.fly.dev"]
        )
    }

    func test_defaultEarnPageIsOnAnEarnHost() {
        XCTAssertTrue(EarnDappMatcher().matches(url: EarnHardcodedData.url))
    }
}

private extension EarnDappMatcherTests {
    func makeMatcher(hostSuffixes: Set<String> = ["vaults.fyi"]) -> EarnDappMatcher {
        EarnDappMatcher(hostSuffixes: hostSuffixes)
    }

    func url(_ string: String) throws -> URL {
        try XCTUnwrap(URL(string: string))
    }
}
