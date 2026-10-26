@testable import App
import KeeperCore
import XCTest

final class DappNativeBridgeTests: XCTestCase {
    func test_configJsonCarriesShellFields() {
        let config = DappNativeBridge.Config(theme: "dark", locale: "en-US", featuredVaults: [])

        XCTAssertEqual(config.json, #"{"featuredVaults":[],"locale":"en-US","theme":"dark"}"#)
    }

    func test_configJsonCarriesTheVaultIdentifierThePageReads() throws {
        let vault = try XCTUnwrap(
            EarnFeaturedVault(network: "base", vaultId: "0x1234567890abcdef1234567890ABCDEF12345678-usdc")
        )
        let config = DappNativeBridge.Config(theme: "dark", locale: "en", featuredVaults: [vault])

        XCTAssertEqual(
            config.json,
            #"{"featuredVaults":[{"network":"base","vaultId":"0x1234567890abcdef1234567890ABCDEF12345678-usdc"}],"locale":"en","theme":"dark"}"#
        )
    }

    func test_injectionExposesShellContract() {
        let injection = DappNativeBridge.injection(
            config: DappNativeBridge.Config(theme: "light", locale: "ru", featuredVaults: [])
        )

        XCTAssertTrue(injection.contains("window.native = {"))
        XCTAssertTrue(injection.contains(#"config: {"featuredVaults":[],"locale":"ru","theme":"light"}"#))
        XCTAssertTrue(injection.contains("invoke: (method, params) =>"))
        XCTAssertTrue(injection.contains("on: (event, handler) =>"))
    }

    func test_injectionSubscribesToNativeEventsOnly() {
        let injection = DappNativeBridge.injection(
            config: DappNativeBridge.Config(theme: "dark", locale: "en", featuredVaults: [])
        )

        XCTAssertTrue(injection.contains("data.type !== 'nativeEvent'"))
        XCTAssertTrue(injection.contains("window.nativeEventListeners[data.event]"))
        XCTAssertTrue(injection.contains("data.event === 'config.themeChanged'"))
    }

    func test_eventJsonMatchesTheShellEnvelope() throws {
        let json = try XCTUnwrap(DappNativeBridge.eventJson(name: DappNativeBridge.Event.themeChanged.rawValue, payload: ["theme": "light"]))
        let decoded = try XCTUnwrap(
            JSONSerialization.jsonObject(with: XCTUnwrap(json.data(using: .utf8))) as? [String: Any]
        )

        XCTAssertEqual(decoded["type"] as? String, "nativeEvent")
        XCTAssertEqual(decoded["event"] as? String, "config.themeChanged")
        XCTAssertEqual((decoded["payload"] as? [String: Any])?["theme"] as? String, "light")
    }

    func test_trackParamsKeepsScalarsOnly() {
        let params = DappNativeBridge.trackParams([
            "text": "vault",
            "count": 3,
            "rate": 1.5,
            "enabled": true,
            "nested": ["a": 1],
            "list": [1, 2],
            "missing": NSNull(),
        ])

        XCTAssertEqual(Set(params.keys), ["text", "count", "rate", "enabled"])
    }

    func test_trackParamsWithoutValuesIsEmpty() {
        XCTAssertTrue(DappNativeBridge.trackParams(nil).isEmpty)
    }

    func test_trackParamsDropsKeysTheIngestionApiRejects() {
        let params = DappNativeBridge.trackParams([
            String(repeating: "a", count: 41): "too long",
            "  ": "blank",
            "vault": "usdt",
        ])

        XCTAssertEqual(Set(params.keys), ["vault"])
    }
}
