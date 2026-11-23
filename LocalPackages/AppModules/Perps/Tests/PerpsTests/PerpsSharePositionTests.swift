import Combine
@testable import Perps
import PerpsModels
import TKLocalize
import XCTest

final class PerpsSharePositionTests: XCTestCase {
    // MARK: Presenter mapping

    func test_model_profitLong_formatsCardFields() {
        let model = PerpsSharePositionPresenter.model(from: snapshot(
            isLong: true, leverage: 27, entryPrice: 66541.7, currentPrice: 120_541, pnlPercent: 128.97, isProfit: true
        ), format: PerpsFormatting.test)
        XCTAssertEqual(model.coinName, "Bitcoin")
        XCTAssertEqual(model.iconLetter, "B")
        XCTAssertTrue(model.isProfit)
        XCTAssertEqual(model.sideText, TKLocales.Perps.Asset.long.uppercased())
        XCTAssertEqual(model.leverageText, PerpsFormatting.test.leverage(27).uppercased())
        XCTAssertEqual(model.pnlPercentText, PerpsFormatting.test.signedPercent(128.97))
        XCTAssertEqual(model.entryText, PerpsFormatting.test.price(66541.7))
        XCTAssertEqual(model.currentText, PerpsFormatting.test.price(120_541))
        XCTAssertEqual(model.dateText, PerpsFormatting.test.candleDateTime(Date(timeIntervalSince1970: 0)))
    }

    func test_model_namesTheThirdPriceCurrent_andCloseForAClosedPosition() {
        let live = PerpsSharePositionPresenter.model(from: snapshot(isLong: true, pnlPercent: 1, isProfit: true), format: .test)
        XCTAssertEqual(live.currentLabel, TKLocales.Perps.Asset.current)

        let closed = SharePositionSnapshot(
            coinName: "Bitcoin",
            iconLetter: "B",
            iconURL: nil,
            isLong: true,
            leverage: nil,
            entryPrice: 1,
            currentPrice: 2,
            isClosed: true,
            pnlPercent: 1,
            isProfit: true,
            date: Date(timeIntervalSince1970: 0)
        )
        XCTAssertEqual(PerpsSharePositionPresenter.model(from: closed, format: .test).currentLabel, TKLocales.Perps.Asset.close)
    }

    func test_model_lossShort_isProfitFalse_andSideShort() {
        let model = PerpsSharePositionPresenter.model(from: snapshot(
            isLong: false, leverage: nil, pnlPercent: -128.97, isProfit: false
        ), format: PerpsFormatting.test)
        XCTAssertFalse(model.isProfit)
        XCTAssertEqual(model.sideText, TKLocales.Perps.Asset.short.uppercased())
        XCTAssertNil(model.leverageText)
        XCTAssertEqual(model.pnlPercentText, PerpsFormatting.test.signedPercent(-128.97))
    }

    /// Non-positive margin (no ROE basis) hides the headline rather than showing 0%.
    func test_model_nilPercent_hidesHeadline() {
        let model = PerpsSharePositionPresenter.model(from: snapshot(
            isLong: true, pnlPercent: nil, isProfit: true
        ), format: PerpsFormatting.test)
        XCTAssertNil(model.pnlPercentText)
    }

    // MARK: Live card

    @MainActor
    func test_share_followsThePosition_withTheLivePrice_andKeepsTheOpeningDate() {
        let account = StubRootAccountStore()
        let markets = StubRootMarketsStore()
        markets.markets = livePrice(3.6135)
        account.marketLifecycle = .open(position(roiPercent: 2.27, markPrice: 3.62))
        let viewModel = PerpsAssetPageViewModel(
            marketId: 1,
            store: markets,
            marketDetailsStore: LifecycleMarketDetailsStore(),
            accountStore: account,
            openPositionFlow: PerpsOpenPositionFlow(),
            tradeOutcomes: { AsyncStream { $0.finish() } },
            format: .test,
            loyalty: nil
        )
        viewModel.onWillAppear()

        var opened: SharePositionSnapshot?
        var updates: [SharePositionSnapshot] = []
        var cancellable: AnyCancellable?
        viewModel.onShare = { snapshot, live in
            opened = snapshot
            cancellable = live.sink { updates.append($0) }
        }
        viewModel.share()

        XCTAssertEqual(opened?.pnlPercent, 2.27)
        XCTAssertEqual(opened?.currentPrice, 3.6135)

        markets.markets = livePrice(3.6102)
        account.marketLifecycle = .open(position(roiPercent: 2.73, markPrice: 3.62))
        viewModel.onWillAppear()
        viewModel.onWillAppear()

        XCTAssertEqual(updates.map(\.pnlPercent), [2.73])
        XCTAssertEqual(updates.first?.currentPrice, 3.6102)
        XCTAssertEqual(updates.first?.date, opened?.date)
        withExtendedLifetime(cancellable) {}
    }

    // MARK: Rendering

    @MainActor
    func test_renderer_producesNonBlankCard() {
        let model = PerpsSharePositionPresenter.model(from: snapshot(
            isLong: true, leverage: 27, entryPrice: 66541.7, currentPrice: 120_541, pnlPercent: 128.97, isProfit: true
        ), format: PerpsFormatting.test)
        guard let image = PerpsSharePositionRenderer.image(model: model, containerWidth: 390) else {
            return XCTFail("renderer returned no image")
        }
        XCTAssertGreaterThan(image.size.width, 0)
        XCTAssertGreaterThan(image.size.height, 0)

        // Regression: an off-screen render must not come out blank/white. The profit
        // glow is opaque and green-dominant near the bottom-centre.
        guard let pixel = image.pixel(atUnitX: 0.5, unitY: 0.9) else {
            return XCTFail("could not sample rendered image")
        }
        XCTAssertGreaterThan(pixel.a, 128, "card should be opaque at bottom-centre, not blank")
        XCTAssertGreaterThan(pixel.g, max(pixel.r, pixel.b), "profit glow should be green-dominant")
    }
}

private extension UIImage {
    /// Samples one pixel by unit coordinates (origin top-left). Returns premultiplied RGBA.
    func pixel(atUnitX ux: CGFloat, unitY uy: CGFloat) -> (r: UInt8, g: UInt8, b: UInt8, a: UInt8)? {
        guard let cg = cgImage else { return nil }
        let x = Int(ux * CGFloat(cg.width))
        let y = Int(uy * CGFloat(cg.height))
        var data = [UInt8](repeating: 0, count: 4)
        guard let context = CGContext(
            data: &data, width: 1, height: 1, bitsPerComponent: 8, bytesPerRow: 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }
        context.draw(cg, in: CGRect(x: -x, y: -(cg.height - 1 - y), width: cg.width, height: cg.height))
        return (data[0], data[1], data[2], data[3])
    }
}

private extension PerpsSharePositionTests {
    func livePrice(_ price: Double) -> PerpsMarkets {
        PerpsMarkets(sort: .volume, items: [], livePrices: [1: price], hasNextPage: false, isLoadingNextPage: false)
    }

    func position(roiPercent: Double, markPrice: Double) -> PerpsPositionSummary {
        PerpsPositionSummary(
            positionId: "lighter:1", marketId: 1, symbol: "LIT", side: .short, baseSize: 1,
            notionalUsd: 3.6, marginUsd: 0.72, equityUsd: 0.74, leverage: 5, roiPercent: roiPercent,
            entryPrice: 3.63, liquidationPrice: 4.3, unrealizedPnlUsd: 0.02, realizedPnlUsd: 0,
            fundingPaidUsd: nil, markPrice: markPrice
        )
    }

    func snapshot(
        isLong: Bool,
        leverage: Double? = 27,
        entryPrice: Double = 66541.7,
        currentPrice: Double = 120_541,
        pnlPercent: Double?,
        isProfit: Bool
    ) -> SharePositionSnapshot {
        SharePositionSnapshot(
            coinName: "Bitcoin",
            iconLetter: "B",
            iconURL: nil,
            isLong: isLong,
            leverage: leverage,
            entryPrice: entryPrice,
            currentPrice: currentPrice,
            pnlPercent: pnlPercent,
            isProfit: isProfit,
            date: Date(timeIntervalSince1970: 0)
        )
    }
}
