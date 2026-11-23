import AppUI
@testable import Perps
import PerpsModels
import TKLocalize
import XCTest

@MainActor
final class PerpsHistoryLoyaltyRewardTests: XCTestCase {
    func test_aCreditedReward_showsTheRowThatOpensLoyalty() throws {
        var opened = 0
        let model = PerpsHistoryDetailsMapping.model(
            event: event(loyaltyReward: "1000"),
            market: nil,
            format: .test,
            onShare: nil,
            onOpenLoyalty: { opened += 1 }
        )

        let row = try XCTUnwrap(model.rewardRow)
        XCTAssertEqual(row.title, TKLocales.Loyalty.resistanceReward)
        guard case let .amount(text, _) = row.value else { return XCTFail("\(row.value)") }
        XCTAssertEqual(text, TKLocales.Loyalty.rewardValue("1000"))
        guard case let .tap(open, _) = row.interaction else { return XCTFail("\(row.interaction)") }
        open()
        XCTAssertEqual(opened, 1)
    }

    func test_anEventWithoutAReward_hasNoRow() {
        let model = PerpsHistoryDetailsMapping.model(
            event: event(loyaltyReward: nil), market: nil, format: .test, onShare: nil, onOpenLoyalty: {}
        )

        XCTAssertNil(model.rewardRow)
    }

    func test_hiddenBalances_maskTheReward() throws {
        let hidden = PerpsFormatting(amounts: PerpsTestAmountFormatting()) { "* * *" }
        let model = PerpsHistoryDetailsMapping.model(
            event: event(loyaltyReward: "1000"), market: nil, format: hidden, onShare: nil, onOpenLoyalty: {}
        )

        let row = try XCTUnwrap(model.rewardRow)
        guard case let .text(text, _, _) = row.value else { return XCTFail("\(row.value)") }
        XCTAssertEqual(text, "* * *")
    }

    private func event(loyaltyReward: String?) -> PerpsHistoryEvent {
        PerpsHistoryEvent(
            id: "opened",
            kind: .opened,
            marketId: 1,
            symbol: "BTC",
            side: .long,
            date: Date(timeIntervalSince1970: 0),
            leverage: 40,
            entryPrice: 66541.7,
            margin: 20.5,
            loyaltyReward: loyaltyReward
        )
    }
}
