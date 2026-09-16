@testable import App
import XCTest

final class BlockchainExplorerURLMatcherTests: XCTestCase {
    func test_transactionTemplateHostMatches() throws {
        XCTAssertTrue(
            try makeMatcher().matches(url: url("https://eth.blockscout.com/tx/0xabc"))
        )
    }

    func test_tokenTemplateHostMatches() throws {
        XCTAssertTrue(
            try makeMatcher().matches(url: url("https://solscan.io/token/So1111"))
        )
    }

    func test_legacyPercentPlaceholderTemplateHostMatches() throws {
        XCTAssertTrue(
            try makeMatcher().matches(url: url("https://testnet.tonviewer.com/transaction/abc"))
        )
    }

    func test_fragmentTemplateHostMatches() throws {
        XCTAssertTrue(
            try makeMatcher().matches(url: url("https://tronscan.org/#/transaction/abc"))
        )
    }

    /// Explorers come from the boot configuration only, so without it nothing is an explorer.
    func test_nothingMatchesWithoutConfiguredTemplates() throws {
        let matcher = makeMatcher(templates: [])

        XCTAssertFalse(try matcher.matches(url: url("https://tonviewer.com/transaction/abc")))
        XCTAssertFalse(try matcher.matches(url: url("https://tronscan.org/#/transaction/abc")))
    }

    func test_dappHostDoesNotMatch() throws {
        XCTAssertFalse(
            try makeMatcher().matches(url: url("https://app.ston.fi/swap"))
        )
    }

    func test_lookalikeHostDoesNotMatch() throws {
        let matcher = makeMatcher()

        XCTAssertFalse(try matcher.matches(url: url("https://tonviewer.com.evil.io/transaction/abc")))
        XCTAssertFalse(try matcher.matches(url: url("https://evil.tonviewer.com/transaction/abc")))
    }

    func test_hostMatchIgnoresCase() throws {
        XCTAssertTrue(
            try makeMatcher().matches(url: url("https://ETH.Blockscout.com/tx/0xabc"))
        )
    }

    func test_urlWithoutHostDoesNotMatch() throws {
        XCTAssertFalse(
            try makeMatcher().matches(url: url("mailto:support@tonkeeper.com"))
        )
    }
}

private extension BlockchainExplorerURLMatcherTests {
    func makeMatcher(templates: [String]? = nil) -> BlockchainExplorerURLMatcher {
        let templates = templates ?? [
            "https://eth.blockscout.com/tx/{tx_hash}",
            "https://solscan.io/token/{token_address}",
            "https://tronscan.org/#/transaction/{tx_hash}",
            "https://testnet.tonviewer.com/transaction/%s",
        ]
        return BlockchainExplorerURLMatcher(templatesProvider: { templates })
    }

    func url(_ string: String) throws -> URL {
        try XCTUnwrap(URL(string: string))
    }
}
