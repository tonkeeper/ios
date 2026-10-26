@testable import KeeperCore
import XCTest

final class TokenManagementStateTests: XCTestCase {
    private let usdt = "0:usdt"

    func testNativeCoinIsPrependedToPinnedWhenAbsentFromBothLists() {
        let state = TokenManagementState(
            pinnedItems: [usdt],
            unpinnedItems: ["0:other"],
            hiddenState: ["0:other": true]
        )

        let normalized = state.pinningNativeCoinByDefault()

        XCTAssertEqual(normalized.pinnedItems, [TonInfo.symbol, usdt])
        XCTAssertEqual(normalized.unpinnedItems, ["0:other"])
        XCTAssertEqual(normalized.hiddenState, ["0:other": true])
    }

    func testPinnedNativeCoinKeepsItsPosition() {
        let state = TokenManagementState(
            pinnedItems: [usdt, TonInfo.symbol],
            unpinnedItems: [],
            hiddenState: [:]
        )

        let normalized = state.pinningNativeCoinByDefault()

        XCTAssertEqual(normalized.pinnedItems, [usdt, TonInfo.symbol])
    }

    func testExplicitlyUnpinnedNativeCoinStaysUnpinned() {
        let state = TokenManagementState(
            pinnedItems: [usdt],
            unpinnedItems: [TonInfo.symbol],
            hiddenState: [:]
        )

        let normalized = state.pinningNativeCoinByDefault()

        XCTAssertEqual(normalized.pinnedItems, [usdt])
        XCTAssertEqual(normalized.unpinnedItems, [TonInfo.symbol])
    }
}
