import AppUI
@testable import Perps
import PerpsModels
import TKLocalize
import XCTest

@MainActor
final class PerpsHistoryMaskingTests: XCTestCase {
    private let hidden = PerpsFormatting(amounts: PerpsTestAmountFormatting()) { "* * *" }

    func test_hiddenBalances_maskTheActivityRowAndDropItsColour() {
        let row = PerpsAssetPageViewModel.makeActivityRow(closedEvent(), format: hidden)

        XCTAssertEqual(row.amountText, "* * *")
        XCTAssertEqual(row.amountStyle, .primary)
        XCTAssertEqual(PerpsAssetPageViewModel.makeActivityRow(closedEvent(), format: .test).amountStyle, .positive)
    }

    func test_hiddenBalances_maskTheEventDetailsAmounts_andKeepThePrices() {
        let model = PerpsHistoryDetailsMapping.model(event: closedEvent(), market: nil, format: hidden, onShare: nil, onOpenLoyalty: {})

        XCTAssertEqual(model.amountLines.map(\.amount), ["* * *"])
        let values = model.rows.compactMap { row -> (String, String, String?)? in
            switch row {
            case let .property(title, value): (title, value, nil)
            case let .value(title, value, subvalue): (title, value, subvalue)
            default: nil
            }
        }
        XCTAssertEqual(values.first { $0.0 == TKLocales.Perps.Asset.entryPrice }?.1, PerpsFormatting.test.price(100))
        XCTAssertEqual(values.first { $0.0 == TKLocales.Perps.HistoryDetails.closePrice }?.1, PerpsFormatting.test.price(110))
        XCTAssertEqual(values.first { $0.0 == TKLocales.Perps.Asset.size }?.1, "* * *")
        XCTAssertNil(values.first { $0.0 == TKLocales.Perps.Asset.size }?.2)
        XCTAssertEqual(values.first { $0.0 == TKLocales.Perps.Confirm.fee }?.1, "* * *")
        XCTAssertEqual(values.first { $0.0 == TKLocales.Perps.Asset.funding }?.1, "* * *")
        XCTAssertEqual(values.first { $0.0 == TKLocales.Perps.HistoryDetails.profit }?.1, PerpsFormatting.test.signedPercent(100))
    }

    func test_hiddenBalances_keepTheLossPercent() {
        let model = PerpsHistoryDetailsMapping.model(
            event: closedEvent(pnl: -0.07, pnlPercent: -2.89), market: nil, format: hidden, onShare: nil, onOpenLoyalty: {}
        )

        let loss = model.rows.compactMap { row -> String? in
            if case let .property(title, value) = row, title == TKLocales.Perps.HistoryDetails.loss { value } else { nil }
        }
        XCTAssertEqual(loss, [PerpsFormatting.test.signedPercent(-2.89)])
    }

    private func closedEvent(pnl: Double = 10, pnlPercent: Double = 100) -> PerpsHistoryEvent {
        PerpsHistoryEvent(
            id: "closed",
            kind: .closed,
            marketId: 1,
            symbol: "BTC",
            side: .long,
            date: Date(timeIntervalSince1970: 0),
            leverage: 10,
            entryPrice: 100,
            closePrice: 110,
            baseSize: 1,
            usdSize: 110,
            pnl: pnl,
            pnlPercent: pnlPercent,
            fundingUsd: -0.1,
            feeUsd: 0.05,
            fee: .init(value: 0.05, symbol: "USDC")
        )
    }
}
