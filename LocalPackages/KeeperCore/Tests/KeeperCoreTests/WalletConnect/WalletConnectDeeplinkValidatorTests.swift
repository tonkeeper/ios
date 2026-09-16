@testable import KeeperCore
import XCTest

final class WalletConnectDeeplinkValidatorTests: XCTestCase {
    private let validator = WalletConnectDeeplinkValidatorImplementation()

    func testValidPairingURIs() {
        let uris = [
            "wc:123@2?relay-protocol=irn&symKey=abc",
            "wc:123@2?symkey=abc&relay-protocol=irn",
            "wc:123@2?relay-protocol=irn&SYMKEY=abc",
            " \nWC:topic@2?relay-protocol=irn&symKey=value\t",
        ]

        for uri in uris {
            XCTAssertTrue(validator.isPairingURI(uri), uri)
        }
    }

    func testInvalidPairingURIs() {
        let uris = [
            "",
            "wc:123@2",
            "wc:123@2?",
            "wc:123@1?relay-protocol=irn&symKey=abc",
            "wc:@2?relay-protocol=irn&symKey=abc",
            "wc:123?relay-protocol=irn&symKey=abc",
            "wc:123@2?relay-protocol=irn",
            "wc:123@2?symKey=",
            "tc:123@2?relay-protocol=irn&symKey=abc",
        ]

        for uri in uris {
            XCTAssertFalse(validator.isPairingURI(uri), uri)
        }
    }

    func testWrappedWalletConnectDeeplinksAreNotPairingURIs() {
        let uris = [
            "tonkeeper://wc?uri=wc:123@2?relay-protocol=irn&symKey=abc",
            "tonkeeper://wc?uri=wc%3A123%402%3Frelay-protocol%3Dirn%26symKey%3Dabc",
            "tonkeeper-mob://wc?uri=wc%3A123%402%3Frelay-protocol%3Dirn%26symKey%3Dabc",
            "https://app.tonkeeper.com/wc?uri=wc:123@2?relay-protocol=irn&symKey=abc",
            "https://app.tonkeeper.com/wc?uri=wc%3A123%402%3Frelay-protocol%3Dirn%26symKey%3Dabc",
            "https://app.tonkeeper.org/wc?uri=wc%3A123%402%3Frelay-protocol%3Dirn%26symKey%3Dabc",
        ]

        for uri in uris {
            XCTAssertFalse(validator.isPairingURI(uri), uri)
        }
    }

    func testURIParserNormalizesWhitespaceAndUppercaseConsistently() throws {
        let uri = " \nWC:topic@2?relay-protocol=irn&symKey=value\t"

        XCTAssertTrue(validator.isPairingURI(uri))
        XCTAssertEqual(
            WalletConnectURIParser.normalized(uri),
            "wc:topic@2?relay-protocol=irn&symKey=value"
        )
        XCTAssertEqual(WalletConnectURIParser.pairingTopic(from: uri), "topic")
        XCTAssertEqual(try WalletConnectURIParser.requiredPairingTopic(from: uri), "topic")
    }

    func testURIParserExtractsDocsFormatWrappedURI() {
        let uris = [
            "tonkeeper://wc?uri=wc:topic@2?relay-protocol=irn&symKey=value",
            "https://app.tonkeeper.com/wc?uri=wc:topic@2?relay-protocol=irn&symKey=value",
            "tonkeeper://wc?uri=wc%3Atopic%402%3Frelay-protocol%3Dirn%26symKey%3Dvalue",
        ]

        for uri in uris {
            XCTAssertEqual(
                WalletConnectURIParser.normalized(uri),
                "wc:topic@2?relay-protocol=irn&symKey=value",
                uri
            )
            XCTAssertEqual(WalletConnectURIParser.pairingTopic(from: uri), "topic", uri)
        }
    }

    func testURIParserDoesNotAppendOuterQueryToPercentEncodedURI() {
        let uri = "tonkeeper://wc?uri=wc%3Atopic%402%3Frelay-protocol%3Dirn%26symKey%3Dvalue&source=outer"

        XCTAssertEqual(
            WalletConnectURIParser.normalized(uri),
            "wc:topic@2?relay-protocol=irn&symKey=value"
        )
    }

    func testURIParserDoesNotAppendOuterQueryToPercentEncodedWakeUpURI() {
        let uri = "tonkeeper://wc?uri=wc%3Atopic%402&source=outer"

        XCTAssertEqual(WalletConnectURIParser.normalized(uri), "wc:topic@2")
        XCTAssertEqual(WalletConnectURIParser.wakeUpTopic(from: uri), "topic")
        XCTAssertNil(WalletConnectURIParser.pairingTopic(from: uri))
    }

    func testURIParserRejectsIncompleteSignRequestAsPairingURI() {
        let uri = "wc:topic@2"

        XCTAssertFalse(validator.isPairingURI(uri))
        XCTAssertEqual(WalletConnectURIParser.wakeUpTopic(from: uri), "topic")
        XCTAssertNil(WalletConnectURIParser.pairingTopic(from: uri))
        XCTAssertThrowsError(try WalletConnectURIParser.requiredPairingTopic(from: uri)) { error in
            XCTAssertEqual(error as? WalletConnectPairingError, .invalidURI(uri))
        }
    }

    func testURIParserDoesNotTreatMissingSymKeyPairingAsWakeUpURI() {
        let uri = "wc:topic@2?relay-protocol=irn"

        XCTAssertNil(WalletConnectURIParser.wakeUpTopic(from: uri))
        XCTAssertNil(WalletConnectURIParser.pairingTopic(from: uri))
    }
}
