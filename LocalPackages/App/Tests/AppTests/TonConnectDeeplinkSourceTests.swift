@testable import KeeperCore
import XCTest

final class TonConnectDeeplinkSourceTests: XCTestCase {
    func testParserUsesBrowserSourceForTonConnect() throws {
        let deeplink = try parser.parse(
            string: tonConnectURLString(),
            source: .browser
        )

        guard case let .tonconnect(.withParameters(parameters, _)) = deeplink else {
            return XCTFail("Expected TON Connect deeplink")
        }

        XCTAssertEqual(parameters.source, .browser)
    }

    func testParserUsesQRSourceForTonConnect() throws {
        let deeplink = try parser.parse(
            string: tonConnectURLString(),
            source: .qr
        )

        guard case let .tonconnect(.withParameters(parameters, _)) = deeplink else {
            return XCTFail("Expected TON Connect deeplink")
        }

        XCTAssertEqual(parameters.source, .qr)
    }

    func testParserUsesDeeplinkSourceByDefaultForTonConnect() throws {
        let deeplink = try parser.parse(string: tonConnectURLString())

        guard case let .tonconnect(.withParameters(parameters, _)) = deeplink else {
            return XCTFail("Expected TON Connect deeplink")
        }

        XCTAssertEqual(parameters.source, .deeplink)
    }

    private var parser: DeeplinkParser {
        DeeplinkParser(walletConnectDeeplinkValidator: WalletConnectDeeplinkValidatorImplementation())
    }

    private func tonConnectURLString() -> String {
        let requestPayload = #"{"manifestUrl":"https://example.com/tonconnect-manifest.json","items":[]}"#
        var allowedCharacters = CharacterSet.urlQueryAllowed
        allowedCharacters.remove(charactersIn: "&=?")
        let encodedPayload = requestPayload.addingPercentEncoding(withAllowedCharacters: allowedCharacters)!
        return "tc://?v=2&id=client&r=\(encodedPayload)"
    }
}
