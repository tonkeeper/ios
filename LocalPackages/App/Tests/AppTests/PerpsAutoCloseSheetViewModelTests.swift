@testable import App
@testable import KeeperCore
import XCTest

@MainActor
final class PerpsAutoCloseSheetViewModelTests: XCTestCase {
    private func makeViewModel(
        side: KeeperCore.PerpsTradeSide,
        entry: Double = 100,
        leverage: Double = 10,
        liquidation: Double? = nil,
        priceDecimals: Int = 2,
        draft: PerpsAutoClose? = nil
    ) -> PerpsAutoCloseSheetViewModel {
        PerpsAutoCloseSheetViewModel(context: PerpsAutoCloseSheetContext(
            side: side,
            entryPrice: entry,
            referencePrice: entry,
            leverage: leverage,
            liquidationPrice: liquidation,
            priceDecimals: priceDecimals,
            draft: draft
        ))
    }

    // MARK: - Price-relation validity

    func test_long_validWhenTpAboveAndSlBelowEntry() {
        let viewModel = makeViewModel(side: .long)
        viewModel.setTakeProfitPrice("110")
        viewModel.setStopLossPrice("90")
        XCTAssertTrue(viewModel.isValid)
    }

    func test_long_invalidWhenTpBelowEntry() {
        let viewModel = makeViewModel(side: .long)
        viewModel.setTakeProfitPrice("90")
        XCTAssertFalse(viewModel.isValid)
        XCTAssertEqual(viewModel.takeProfitWarningText, "The Take Profit value must be above the current price.")
    }

    func test_long_invalidWhenSlAboveEntry() {
        let viewModel = makeViewModel(side: .long)
        viewModel.setStopLossPrice("110")
        XCTAssertFalse(viewModel.isValid)
        XCTAssertEqual(viewModel.stopLossWarningText, "The Stop Loss value must be below the current price.")
    }

    func test_short_relationsAreMirrored() {
        let viewModel = makeViewModel(side: .short)
        viewModel.setTakeProfitPrice("90") // TP below entry for short = valid
        viewModel.setStopLossPrice("110") // SL above entry for short = valid
        XCTAssertTrue(viewModel.isValid)

        viewModel.setTakeProfitPrice("110") // now invalid for short
        XCTAssertFalse(viewModel.isValid)
        XCTAssertEqual(viewModel.takeProfitWarningText, "The Take Profit value must be below the current price.")
    }

    // MARK: - ROI ↔ price (the percent is profit/loss on margin, divided by leverage)

    func test_long_takeProfitPreset_isROIThroughLeverage() {
        // +50% profit at 10x = +5% price → 100 × 1.05 = 105.
        let viewModel = makeViewModel(side: .long, entry: 100, leverage: 10)
        viewModel.applyTakeProfitPreset(50)
        XCTAssertEqual(viewModel.takeProfitPercentText, "50")
        XCTAssertEqual(viewModel.takeProfitPrice ?? 0, 105, accuracy: 1e-6)
        XCTAssertTrue(viewModel.isValid)
    }

    func test_long_stopLossPreset_isROIThroughLeverage() {
        // −50% loss at 10x = −5% price → 100 × 0.95 = 95.
        let viewModel = makeViewModel(side: .long, entry: 100, leverage: 10)
        viewModel.applyStopLossPreset(50)
        XCTAssertEqual(viewModel.stopLossPrice ?? 0, 95, accuracy: 1e-6)
    }

    func test_short_takeProfitPreset_movesPriceDown() {
        // Short profits when price falls: +50% ROI at 10x → 100 × 0.95 = 95.
        let viewModel = makeViewModel(side: .short, entry: 100, leverage: 10)
        viewModel.applyTakeProfitPreset(50)
        XCTAssertEqual(viewModel.takeProfitPrice ?? 0, 95, accuracy: 1e-6)
        XCTAssertTrue(viewModel.isValid)
    }

    func test_priceInput_backfillsPercent() {
        // Typing a price fills the ROI %: (105/100 − 1) × 10 × 100 = 50.
        let viewModel = makeViewModel(side: .long, entry: 100, leverage: 10)
        viewModel.setTakeProfitPrice("105")
        XCTAssertEqual(viewModel.takeProfitPercentText, "50")
    }

    // MARK: - Presets are leverage-safe (regression: −% used to be read as price move)

    func test_stopLossPreset_staysAboveLiquidation_atTenX() {
        // At 10x, liquidation ≈ −10% price (~90). The −50% loss preset is only a −5% price
        // move (95), so it stays inside the liquidation bound and Set is valid.
        let viewModel = makeViewModel(side: .long, entry: 100, leverage: 10, liquidation: 90.5)
        viewModel.applyStopLossPreset(50)
        XCTAssertGreaterThan(viewModel.stopLossPrice ?? 0, 90.5)
        XCTAssertTrue(viewModel.isValid)
    }

    func test_long_stopLossBeyondLiquidationIsInvalid() {
        // A manually entered SL at/below liquidation can never trigger.
        let viewModel = makeViewModel(side: .long, entry: 100, leverage: 10, liquidation: 90)
        viewModel.setStopLossPrice("85")
        XCTAssertFalse(viewModel.isValid)
        XCTAssertEqual(
            viewModel.stopLossWarningText,
            "The Stop Loss value must be above the liquidation price (\(PerpsFormatting.usd(90)))."
        )
        // A SL between liquidation and entry is fine.
        viewModel.setStopLossPrice("95")
        XCTAssertTrue(viewModel.isValid)
        XCTAssertNil(viewModel.stopLossWarningText)
    }

    // MARK: - Apply

    func test_apply_emitsAutoCloseWithBothLegsAsPrices() {
        let viewModel = makeViewModel(side: .long)
        viewModel.setTakeProfitPrice("110")
        viewModel.setStopLossPrice("90")
        var emitted: PerpsAutoClose?
        viewModel.onApply = .draft { emitted = $0 }
        viewModel.apply()
        XCTAssertEqual(emitted?.takeProfit?.triggerPrice, 110)
        XCTAssertEqual(emitted?.stopLoss?.triggerPrice, 90)
    }

    func test_apply_blockedWhenInvalid() {
        let viewModel = makeViewModel(side: .long)
        viewModel.setTakeProfitPrice("90") // invalid for long
        var applied = false
        viewModel.onApply = .draft { _ in applied = true }
        viewModel.apply()
        XCTAssertFalse(applied)
    }

    // MARK: - Live-position submit (TK-1580)

    func test_apply_withSubmitHandler_showsLoadingThenInlineError() async {
        let viewModel = makeViewModel(side: .long)
        viewModel.setTakeProfitPrice("110")
        var submitted: PerpsAutoClose??
        var submitCallCount = 0
        viewModel.onApply = .submit { target in
            submitCallCount += 1
            submitted = target
            return .failed("boom")
        }

        viewModel.apply()
        XCTAssertTrue(viewModel.isSubmitting)
        // Re-entry while in flight is a no-op.
        viewModel.apply()

        await waitUntil { !viewModel.isSubmitting }
        XCTAssertEqual(submitCallCount, 1, "re-entry while in flight must be a no-op")
        XCTAssertEqual(viewModel.submitErrorText, "boom")
        XCTAssertEqual(submitted??.takeProfit?.triggerPrice, 110)
    }

    func test_apply_withSubmitHandler_finished_staysOpenWithoutInlineError() async {
        let viewModel = makeViewModel(side: .long)
        viewModel.setTakeProfitPrice("110")
        // The owner closed the sheet, or the user backed out of the passcode.
        viewModel.onApply = .submit { _ in .finished }
        viewModel.apply()
        await waitUntil { !viewModel.isSubmitting }
        XCTAssertNil(viewModel.submitErrorText, "a finished submit must not render an inline warning")
    }

    func test_apply_withSubmitHandler_clearingRestingLegs_submitsNilTarget() async {
        let viewModel = makeViewModel(side: .long, draft: PerpsAutoClose(
            takeProfit: PerpsAutoCloseTrigger(triggerPrice: 110),
            stopLoss: nil
        ))
        viewModel.setTakeProfitPrice("")
        var submitted: PerpsAutoClose?? = PerpsAutoClose(takeProfit: nil, stopLoss: nil)
        viewModel.onApply = .submit { target in
            submitted = target
            return .finished
        }
        XCTAssertTrue(viewModel.isApplyEnabled, "clearing resting legs is a legitimate Set")
        viewModel.apply()
        await waitUntil { !viewModel.isSubmitting }
        XCTAssertEqual(submitted, PerpsAutoClose?.none, "emptied fields over resting legs mean clearing — the handler must see a nil target")
    }

    func test_apply_liveMode_disabledWhenNothingToSetAndNothingToClear() {
        let viewModel = makeViewModel(side: .long)
        viewModel.onApply = .submit { _ in .finished }
        XCTAssertFalse(viewModel.isApplyEnabled, "empty sheet over no resting legs is a no-op — Set must stay disabled")

        // The open flow keeps empty-Set enabled: it means "no draft".
        let openFlow = makeViewModel(side: .long)
        XCTAssertTrue(openFlow.isApplyEnabled)
    }

    func test_prefill_keepsFineTickPrecision() throws {
        let viewModel = makeViewModel(side: .long, entry: 0.05, priceDecimals: 6, draft: PerpsAutoClose(
            takeProfit: PerpsAutoCloseTrigger(triggerPrice: 0.061234),
            stopLoss: nil
        ))
        // parse() reads through Decimal (1 ulp tolerance) — what matters is that
        // the prefill text keeps every tick digit instead of truncating to 2.
        XCTAssertEqual(viewModel.takeProfitPriceText, "0.061234")
        XCTAssertEqual(
            try XCTUnwrap(viewModel.takeProfitPrice),
            0.061234,
            accuracy: 1e-12,
            "an untouched Set must not move the resting leg on fine-tick markets"
        )
    }

    func test_preset_onFineTickMarket_keepsTheDerivedTriggerPrice() throws {
        // 10% ROI at 10x is a 1% price move: 0.001 → 0.00101. Rendering the
        // derived price at two decimals used to collapse it to "0", and the
        // sheet then reported no take profit at all.
        let viewModel = makeViewModel(side: .long, entry: 0.001, leverage: 10, priceDecimals: 6)
        viewModel.applyTakeProfitPreset(10)
        XCTAssertEqual(viewModel.takeProfitPriceText, "0.00101")
        XCTAssertEqual(try XCTUnwrap(viewModel.takeProfitPrice), 0.00101, accuracy: 1e-12)
        XCTAssertTrue(viewModel.isValid)
    }

    func test_typedPrice_onFineTickMarket_isNotTruncatedToTwoDecimals() throws {
        let viewModel = makeViewModel(side: .long, entry: 0.001, leverage: 10, priceDecimals: 6)
        viewModel.setTakeProfitPrice("0.00101")
        XCTAssertEqual(viewModel.takeProfitPriceText, "0.00101")
        XCTAssertEqual(try XCTUnwrap(viewModel.takeProfitPrice), 0.00101, accuracy: 1e-12)
    }

    func test_coarseMarket_roundsTheDerivedTriggerToTheMarketTick() {
        // priceDecimals is the venue's tick: the sheet must not offer a price
        // the market cannot hold.
        let viewModel = makeViewModel(side: .long, entry: 100, leverage: 10, priceDecimals: 1)
        viewModel.setTakeProfitPrice("105.678")
        XCTAssertEqual(viewModel.takeProfitPriceText, "105.6")
    }

    private func waitUntil(
        timeout: TimeInterval = 2,
        intervalNanoseconds: UInt64 = 5_000_000,
        condition: @escaping () -> Bool
    ) async {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if condition() { return }
            try? await Task.sleep(nanoseconds: intervalNanoseconds)
        }
    }
}
