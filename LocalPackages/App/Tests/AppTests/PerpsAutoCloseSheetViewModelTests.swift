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
        draft: PerpsAutoClose? = nil
    ) -> PerpsAutoCloseSheetViewModel {
        PerpsAutoCloseSheetViewModel(context: PerpsAutoCloseSheetContext(
            side: side,
            entryPrice: entry,
            leverage: leverage,
            liquidationPrice: liquidation,
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
        viewModel.onApply = { emitted = $0 }
        viewModel.apply()
        XCTAssertEqual(emitted?.takeProfit?.triggerPrice, 110)
        XCTAssertEqual(emitted?.stopLoss?.triggerPrice, 90)
    }

    func test_apply_blockedWhenInvalid() {
        let viewModel = makeViewModel(side: .long)
        viewModel.setTakeProfitPrice("90") // invalid for long
        var applied = false
        viewModel.onApply = { _ in applied = true }
        viewModel.apply()
        XCTAssertFalse(applied)
    }

    // MARK: - Live-position submit (TK-1580)

    func test_apply_withSubmitHandler_showsLoadingThenInlineError_andNeverFiresOnApply() async {
        let viewModel = makeViewModel(side: .long)
        viewModel.setTakeProfitPrice("110")
        var applied = false
        viewModel.onApply = { _ in applied = true }
        var submitted: PerpsAutoClose??
        var submitCallCount = 0
        viewModel.onSubmit = { target in
            submitCallCount += 1
            submitted = target
            return "boom"
        }

        viewModel.apply()
        XCTAssertTrue(viewModel.isSubmitting)
        // Re-entry while in flight is a no-op.
        viewModel.apply()

        await waitUntil { !viewModel.isSubmitting }
        XCTAssertEqual(submitCallCount, 1, "re-entry while in flight must be a no-op")
        XCTAssertEqual(viewModel.submitErrorText, "boom")
        XCTAssertEqual(submitted??.takeProfit?.triggerPrice, 110)
        XCTAssertFalse(applied, "live mode must not fall through to the instant apply path")
    }

    func test_apply_withSubmitHandler_emptyResult_staysOpenWithoutInlineError() async {
        let viewModel = makeViewModel(side: .long)
        viewModel.setTakeProfitPrice("110")
        // The coordinator returns "" for passcode cancel / position gone — no inline error.
        viewModel.onSubmit = { _ in "" }
        viewModel.apply()
        await waitUntil { !viewModel.isSubmitting }
        XCTAssertNil(viewModel.submitErrorText, "empty submit result must not render an inline warning")
    }

    func test_apply_withSubmitHandler_clearingRestingLegs_submitsNilTarget() async {
        let viewModel = makeViewModel(side: .long, draft: PerpsAutoClose(
            takeProfit: PerpsAutoCloseTrigger(triggerPrice: 110),
            stopLoss: nil
        ))
        viewModel.setTakeProfitPrice("")
        var submitted: PerpsAutoClose?? = PerpsAutoClose(takeProfit: nil, stopLoss: nil)
        viewModel.onSubmit = { target in
            submitted = target
            return nil
        }
        XCTAssertTrue(viewModel.isApplyEnabled, "clearing resting legs is a legitimate Set")
        viewModel.apply()
        await waitUntil { !viewModel.isSubmitting }
        XCTAssertEqual(submitted, PerpsAutoClose?.none, "emptied fields over resting legs mean clearing — the handler must see a nil target")
    }

    func test_apply_liveMode_disabledWhenNothingToSetAndNothingToClear() {
        let viewModel = makeViewModel(side: .long)
        viewModel.onSubmit = { _ in nil }
        XCTAssertFalse(viewModel.isApplyEnabled, "empty sheet over no resting legs is a no-op — Set must stay disabled")

        // The open flow keeps empty-Set enabled: it means "no draft".
        let openFlow = makeViewModel(side: .long)
        XCTAssertTrue(openFlow.isApplyEnabled)
    }

    func test_prefill_keepsFineTickPrecision() throws {
        let viewModel = makeViewModel(side: .long, entry: 0.05, draft: PerpsAutoClose(
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
