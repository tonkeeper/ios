@testable import MoonPay
import XCTest

final class MoonPayFrameURLTests: XCTestCase {
    private let environment = MoonPayEnvironment.production

    func testCheckConnectionURL() throws {
        let url = try MoonPayFrame
            .checkConnection(sessionToken: "sess+1/=", publicKeyHex: "abcd")
            .url(environment: environment, channelId: "ch_1")

        XCTAssertEqual(url.scheme, "https")
        XCTAssertEqual(url.host, "platform.moonpay.com")
        XCTAssertEqual(url.path, "/platform/v1/check-connection")
        XCTAssertEqual(queryItems(url), ["sessionToken": "sess+1/=", "publicKey": "abcd", "channelId": "ch_1"])
        XCTAssertTrue(url.absoluteString.contains("sessionToken=sess%2B1%2F%3D"), url.absoluteString)
    }

    func testCheckConnectionSkipKyc() throws {
        let url = try MoonPayFrame
            .checkConnection(sessionToken: "s", publicKeyHex: "p", skipKyc: true)
            .url(environment: environment, channelId: "c")
        XCTAssertEqual(queryItems(url)["skipKyc"], "true")
    }

    func testConnectURL() throws {
        let url = try MoonPayFrame
            .connect(clientToken: "client", publicKeyHex: "pub", theme: .dark)
            .url(environment: environment, channelId: "ch_2")
        XCTAssertEqual(url.path, "/platform/v1/connect")
        XCTAssertEqual(queryItems(url), ["clientToken": "client", "publicKey": "pub", "theme": "dark", "channelId": "ch_2"])
    }

    func testWidgetURLAddsBuyFlow() throws {
        let url = try MoonPayFrame
            .widget(clientToken: "client", quoteSignature: "sig", externalTransactionId: "ext-1", theme: .light)
            .url(environment: environment, channelId: "ch_3")
        XCTAssertEqual(url.path, "/platform/v1/widget")
        XCTAssertEqual(
            queryItems(url),
            ["flow": "buy", "clientToken": "client", "quoteSignature": "sig", "externalTransactionId": "ext-1", "theme": "light", "channelId": "ch_3"]
        )
    }

    func testBuyURLOmitsNilParameters() throws {
        let url = try MoonPayFrame
            .buy(clientToken: "client", signature: "sig")
            .url(environment: environment, channelId: "ch_4")
        XCTAssertEqual(url.path, "/platform/v1/buy")
        XCTAssertEqual(queryItems(url), ["clientToken": "client", "signature": "sig", "channelId": "ch_4"])
    }

    func testApplePayURL() throws {
        let url = try MoonPayFrame
            .applePay(clientToken: "client", signature: "sig", applePayButtonSettings: #"{"type":"buy"}"#)
            .url(environment: environment, channelId: "ch_5")
        XCTAssertEqual(url.path, "/platform/v1/apple-pay")
        XCTAssertEqual(
            queryItems(url),
            ["clientToken": "client", "signature": "sig", "applePayButtonSettings": #"{"type":"buy"}"#, "channelId": "ch_5"]
        )
    }

    func testAddCardURL() throws {
        let url = try MoonPayFrame
            .addCard(clientToken: "client")
            .url(environment: environment, channelId: "ch_6")
        XCTAssertEqual(url.path, "/platform/v1/add-card")
        XCTAssertEqual(queryItems(url), ["clientToken": "client", "channelId": "ch_6"])
    }

    func testChallengeURLKeepsIssuedPathAndQuery() throws {
        let issued = try XCTUnwrap(URL(string: "https://platform.moonpay.com/platform/v1/challenge?challengeToken=abc%2Bdef&flow=buy"))
        let url = try MoonPayFrame
            .challenge(url: issued, clientToken: "client", theme: .dark)
            .url(environment: environment, channelId: "ch_7")

        XCTAssertEqual(url.path, "/platform/v1/challenge")
        XCTAssertTrue(url.absoluteString.hasPrefix("https://platform.moonpay.com/platform/v1/challenge?challengeToken=abc%2Bdef&flow=buy&"))
        XCTAssertEqual(
            queryItems(url),
            ["challengeToken": "abc+def", "flow": "buy", "clientToken": "client", "theme": "dark", "channelId": "ch_7"]
        )
    }

    func testSandboxSharesFrameOrigin() throws {
        let url = try MoonPayFrame
            .addCard(clientToken: "client")
            .url(environment: .sandbox, channelId: "c")
        XCTAssertEqual(url.host, "platform.moonpay.com")
        XCTAssertEqual(MoonPayEnvironment.sandbox.apiBaseURL.host, "api.moonpay.dev")
        XCTAssertEqual(MoonPayEnvironment.production.apiBaseURL.host, "api.moonpay.com")
    }

    private func queryItems(_ url: URL) -> [String: String] {
        let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
        return Dictionary(uniqueKeysWithValues: items.map { ($0.name, $0.value ?? "") })
    }
}
