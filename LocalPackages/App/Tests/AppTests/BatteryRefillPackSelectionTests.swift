@testable import App
import XCTest

final class BatteryRefillPackSelectionTests: XCTestCase {
    private func packId(previous: String?, enabledIds: [String], allowsCustom: Bool = false) -> String? {
        BatteryRefillViewModelImplementation.packId(previous: previous, enabledIds: enabledIds, allowsCustom: allowsCustom)
    }

    func test_keepsThePreviousPackWhileItCanBeBought() {
        XCTAssertEqual(packId(previous: "large", enabledIds: ["large", "medium", "small"]), "large")
    }

    func test_opensOnTheMiddlePack() {
        XCTAssertEqual(packId(previous: nil, enabledIds: ["large", "medium", "small"]), "medium")
        XCTAssertEqual(packId(previous: nil, enabledIds: ["medium", "small"]), "small")
        XCTAssertEqual(packId(previous: nil, enabledIds: ["small"]), "small")
    }

    func test_replacesAPreviousPackThatCannotBeBought() {
        XCTAssertEqual(packId(previous: "large", enabledIds: ["medium", "small", "tiny"]), "small")
    }

    func test_keepsOtherWhileTheMethodOffersIt() {
        XCTAssertEqual(packId(previous: "custom", enabledIds: ["large", "medium", "small"], allowsCustom: true), "custom")
        XCTAssertEqual(packId(previous: "custom", enabledIds: [], allowsCustom: true), "custom")
    }

    func test_replacesOtherWhereTheMethodDoesNotOfferIt() {
        XCTAssertEqual(packId(previous: "custom", enabledIds: ["large", "medium", "small"]), "medium")
    }

    func test_keepsThePreviousPackWhileNoneCanBeBought() {
        XCTAssertEqual(packId(previous: "large", enabledIds: []), "large")
        XCTAssertNil(packId(previous: nil, enabledIds: []))
    }
}
