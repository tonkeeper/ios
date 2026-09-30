@testable import App
import XCTest

final class DappNativeBridgeTests: XCTestCase {
    func test_configJsonCarriesShellFields() {
        let config = DappNativeBridge.Config(theme: "dark", locale: "en-US", featuredVaults: [])

        XCTAssertEqual(config.json, #"{"featuredVaults":[],"locale":"en-US","theme":"dark"}"#)
    }

    func test_injectionExposesShellContract() {
        let injection = DappNativeBridge.injection(
            config: DappNativeBridge.Config(theme: "light", locale: "ru", featuredVaults: [])
        )

        XCTAssertTrue(injection.contains("window.native = {"))
        XCTAssertTrue(injection.contains(#"config: {"featuredVaults":[],"locale":"ru","theme":"light"}"#))
        XCTAssertTrue(injection.contains("invoke: (method, params) =>"))
        XCTAssertTrue(injection.contains("on: () => () => {}"))
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
