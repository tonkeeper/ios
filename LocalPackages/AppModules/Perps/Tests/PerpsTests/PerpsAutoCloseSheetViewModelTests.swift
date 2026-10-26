@testable import Perps
import PerpsModels
import TKLocalize
import XCTest

@MainActor
final class PerpsAutoCloseSheetViewModelTests: XCTestCase {
    private func makeViewModel(
        side: PerpsModels.PerpsTradeSide,
        entry: Double = 100,
        reference: Double? = nil,
        leverage: Double = 10,
        baseSize: Double = 0,
        liquidation: Double? = nil,
        priceDecimals: Int = 2,
        draft: PerpsAutoClose? = nil,
        roiInput: PerpsAutoCloseROIInput = .none,
        inputMemory: PerpsAutoCloseInputMemory.Slot? = nil
    ) -> PerpsAutoCloseSheetViewModel {
        PerpsAutoCloseSheetViewModel(
            context: PerpsAutoCloseSheetContext(
                marketId: 1,
                side: side,
                entryPrice: entry,
                referencePrice: reference ?? entry,
                leverage: leverage,
                baseSize: baseSize,
                liquidationPrice: liquidation,
                priceDecimals: priceDecimals,
                draft: draft,
                roiInput: roiInput
            ),
            format: PerpsFormatting.test,
            inputMemory: inputMemory
        )
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

    func test_typedPriceAgainstTheLeg_flipsThePercentSign() {
        let long = makeViewModel(side: .long, entry: 100, leverage: 10)
        long.setTakeProfitPrice("99")
        XCTAssertEqual(long.takeProfitPercentSign, .minus)
        XCTAssertEqual(long.takeProfitPercentText, "10")
        long.setStopLossPrice("101")
        XCTAssertEqual(long.stopLossPercentSign, .plus)
        XCTAssertEqual(long.stopLossPercentText, "10")

        long.setTakeProfitPrice("101")
        XCTAssertEqual(long.takeProfitPercentSign, .plus)
        long.setStopLossPrice("100")
        XCTAssertEqual(long.stopLossPercentSign, .minus)

        let short = makeViewModel(side: .short, entry: 100, leverage: 10)
        short.setTakeProfitPrice("101")
        XCTAssertEqual(short.takeProfitPercentSign, .minus)
        short.setStopLossPrice("99")
        XCTAssertEqual(short.stopLossPercentSign, .plus)
    }

    func test_editingAFlippedPercent_keepsItsSide() {
        let viewModel = makeViewModel(side: .long, entry: 100, leverage: 10)
        viewModel.setTakeProfitPrice("99")
        viewModel.setTakeProfitPercent("0.")
        XCTAssertEqual(viewModel.takeProfitPercentSign, .minus)
        viewModel.setTakeProfitPercent("20")
        XCTAssertEqual(viewModel.takeProfitPercentSign, .minus)
        XCTAssertEqual(viewModel.takeProfitPrice ?? 0, 98, accuracy: 1e-6)

        viewModel.setStopLossPrice("101")
        viewModel.setStopLossPercent("20")
        XCTAssertEqual(viewModel.stopLossPercentSign, .plus)
        XCTAssertEqual(viewModel.stopLossPrice ?? 0, 102, accuracy: 1e-6)
    }

    func test_presetOrClearedPercent_restoresTheDefaultSign() {
        let viewModel = makeViewModel(side: .long, entry: 100, leverage: 10)
        viewModel.setStopLossPrice("101")
        viewModel.applyStopLossPreset(10)
        XCTAssertEqual(viewModel.stopLossPercentSign, .minus)
        XCTAssertEqual(viewModel.stopLossPrice ?? 0, 99, accuracy: 1e-6)

        viewModel.setTakeProfitPrice("99")
        viewModel.setTakeProfitPercent("")
        XCTAssertEqual(viewModel.takeProfitPercentSign, .plus)
        viewModel.setTakeProfitPercent("10")
        XCTAssertEqual(viewModel.takeProfitPrice ?? 0, 101, accuracy: 1e-6)
    }

    func test_prefilledDraft_showsTheActualSign() {
        let viewModel = makeViewModel(side: .long, entry: 100, leverage: 10, draft: PerpsAutoClose(
            takeProfit: PerpsAutoCloseTrigger(triggerPrice: 99),
            stopLoss: PerpsAutoCloseTrigger(triggerPrice: 101)
        ))
        XCTAssertEqual(viewModel.takeProfitPercentSign, .minus)
        XCTAssertEqual(viewModel.stopLossPercentSign, .plus)
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

    func test_long_stopLossBeyondLiquidationWarnsWithoutBlockingSet() {
        // A manually entered SL at/below liquidation can never trigger, but the venue
        // takes it: the sheet says so and leaves Set alive.
        let viewModel = makeViewModel(side: .long, entry: 100, leverage: 10, liquidation: 90)
        viewModel.setStopLossPrice("85")
        XCTAssertTrue(viewModel.isApplyEnabled)
        XCTAssertFalse(viewModel.isValid)
        XCTAssertEqual(
            viewModel.stopLossWarningText,
            "The Stop Loss value must be above the liquidation price (\(PerpsFormatting.test.usd(90)))."
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
        viewModel.onApply = .draft { autoClose, _ in emitted = autoClose }
        viewModel.apply()
        XCTAssertEqual(emitted?.takeProfit?.triggerPrice, 110)
        XCTAssertEqual(emitted?.stopLoss?.triggerPrice, 90)
    }

    func test_apply_blockedWhenInvalid() {
        let viewModel = makeViewModel(side: .long)
        viewModel.setTakeProfitPrice("90") // invalid for long
        var applied = false
        viewModel.onApply = .draft { _, _ in applied = true }
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

    // MARK: - Expected profit and loss

    func test_expectedTexts_fallBackToHintsUntilBothSizeAndPercentAreKnown() {
        let withoutSize = makeViewModel(side: .long, entry: 100, leverage: 10)
        withoutSize.setTakeProfitPercent("50")
        XCTAssertEqual(withoutSize.takeProfitExpectedText, TKLocales.Perps.OpenPosition.takeProfitHint)

        let withoutPercent = makeViewModel(side: .long, entry: 100, leverage: 10, baseSize: 20)
        XCTAssertEqual(withoutPercent.stopLossExpectedText, TKLocales.Perps.OpenPosition.stopLossHint)
    }

    func test_expectedTexts_areROIOnMargin() {
        let viewModel = makeViewModel(side: .long, entry: 100, leverage: 10, baseSize: 20)

        viewModel.setTakeProfitPercent("50")
        XCTAssertEqual(
            viewModel.takeProfitExpectedText,
            TKLocales.Perps.OpenPosition.expectedProfit(PerpsFormatting.test.signedUsd(100))
        )

        viewModel.setStopLossPercent("25")
        XCTAssertEqual(
            viewModel.stopLossExpectedText,
            TKLocales.Perps.OpenPosition.expectedLoss(PerpsFormatting.test.signedUsd(-50))
        )
    }

    func test_expectedTexts_followActualPnlWhenMarketMovedPastEntry() {
        let long = makeViewModel(side: .long, entry: 100, reference: 120, leverage: 10, baseSize: 20)
        long.setStopLossPrice("110")
        XCTAssertTrue(long.isValid)
        XCTAssertEqual(
            long.stopLossExpectedText,
            TKLocales.Perps.OpenPosition.expectedProfit(PerpsFormatting.test.signedUsd(200))
        )

        let longLoss = makeViewModel(side: .long, entry: 100, reference: 95, leverage: 10, baseSize: 20)
        longLoss.setTakeProfitPrice("98")
        XCTAssertTrue(longLoss.isValid)
        XCTAssertEqual(
            longLoss.takeProfitExpectedText,
            TKLocales.Perps.OpenPosition.expectedLoss(PerpsFormatting.test.signedUsd(-40))
        )

        let short = makeViewModel(side: .short, entry: 100, reference: 90, leverage: 10, baseSize: 20)
        short.setStopLossPrice("95")
        XCTAssertTrue(short.isValid)
        XCTAssertEqual(
            short.stopLossExpectedText,
            TKLocales.Perps.OpenPosition.expectedProfit(PerpsFormatting.test.signedUsd(100))
        )

        let shortLoss = makeViewModel(side: .short, entry: 100, reference: 105, leverage: 10, baseSize: 20)
        shortLoss.setTakeProfitPrice("102")
        XCTAssertTrue(shortLoss.isValid)
        XCTAssertEqual(
            shortLoss.takeProfitExpectedText,
            TKLocales.Perps.OpenPosition.expectedLoss(PerpsFormatting.test.signedUsd(-40))
        )
    }

    // MARK: - Typed ROI (TK-4777)

    func test_typedROI_isShownAsTyped_whileItStillNamesTheLegsPrice() throws {
        // 1.23% at 10x on 100 is 100.123, which a 0.1 tick holds as 100.1 — a price
        // that reads back as 1%. The sheet must give back what was typed.
        let typing = makeViewModel(side: .long, entry: 100, priceDecimals: 1)
        typing.setTakeProfitPercent("1.23")
        var emitted: (PerpsAutoClose?, PerpsAutoCloseROIInput)?
        typing.onApply = .draft { emitted = ($0, $1) }
        typing.apply()
        let (draft, roiInput) = try XCTUnwrap(emitted)
        XCTAssertEqual(try XCTUnwrap(draft?.takeProfit?.triggerPrice), 100.1, accuracy: 1e-9)

        let reopened = makeViewModel(side: .long, entry: 100, priceDecimals: 1, draft: draft, roiInput: roiInput)
        XCTAssertEqual(reopened.takeProfitPercentText, "1.23")
        XCTAssertEqual(reopened.takeProfitPriceText, "100.1")

        let withoutInput = makeViewModel(side: .long, entry: 100, priceDecimals: 1, draft: draft)
        XCTAssertEqual(withoutInput.takeProfitPercentText, "1")
    }

    func test_typedROI_givesWayToThePrice_onceTheEntryMoved() {
        let draft = PerpsAutoClose(takeProfit: PerpsAutoCloseTrigger(triggerPrice: 100.1), stopLoss: nil)
        let roiInput = PerpsAutoCloseROIInput(takeProfit: PerpsAutoCloseROI(sign: .plus, text: "1.23"))
        // On 100.05 the typed 1.23% would name 100.2, not the leg's 100.1.
        let moved = makeViewModel(side: .long, entry: 100.05, priceDecimals: 1, draft: draft, roiInput: roiInput)
        XCTAssertEqual(moved.takeProfitPercentText, "0.5")

        var emitted: PerpsAutoCloseROIInput?
        moved.onApply = .draft { _, roiInput in emitted = roiInput }
        moved.apply()
        XCTAssertEqual(emitted, PerpsAutoCloseROIInput.none, "an ROI the sheet derived is not one the user typed")
    }

    func test_apply_carriesTheROIOnlyForLegsTypedAsAPercent() {
        let viewModel = makeViewModel(side: .long, entry: 100)
        viewModel.applyTakeProfitPreset(20)
        viewModel.setStopLossPrice("95")
        var emitted: PerpsAutoCloseROIInput?
        viewModel.onApply = .draft { _, roiInput in emitted = roiInput }
        viewModel.apply()
        XCTAssertEqual(emitted, PerpsAutoCloseROIInput(takeProfit: PerpsAutoCloseROI(sign: .plus, text: "20")))
    }

    func test_inputMemory_restoresTheTypedROI_andForgetsALegRetypedAsAPrice() {
        let slot = PerpsAutoCloseInputMemory().slot(accountIndex: 7, marketId: 1)
        let first = makeViewModel(side: .long, entry: 100, priceDecimals: 1, inputMemory: slot)
        first.setTakeProfitPercent("1.23")
        first.setStopLossPrice("99")
        first.onApply = .submit { _ in .finished }
        first.apply()
        XCTAssertEqual(slot.input, PerpsAutoCloseROIInput(takeProfit: PerpsAutoCloseROI(sign: .plus, text: "1.23")))

        let resting = PerpsAutoClose(
            takeProfit: PerpsAutoCloseTrigger(triggerPrice: 100.1),
            stopLoss: PerpsAutoCloseTrigger(triggerPrice: 99)
        )
        let reopened = makeViewModel(side: .long, entry: 100, priceDecimals: 1, draft: resting, inputMemory: slot)
        XCTAssertEqual(reopened.takeProfitPercentText, "1.23")
        XCTAssertEqual(reopened.stopLossPercentText, "10")

        reopened.setTakeProfitPrice("100.2")
        reopened.onApply = .submit { _ in .finished }
        reopened.apply()
        XCTAssertEqual(slot.input, .none)
    }

    func test_resolving_rederivesOnlyTheLegsTypedAsROI() {
        let base = PerpsAutoCloseBase(side: .long, entryPrice: 200, leverage: 10, priceDecimals: 2)
        let draft = PerpsAutoClose(
            takeProfit: PerpsAutoCloseTrigger(triggerPrice: 110),
            stopLoss: PerpsAutoCloseTrigger(triggerPrice: 95)
        )
        let input = PerpsAutoCloseROIInput(takeProfit: PerpsAutoCloseROI(sign: .plus, text: "10"))
        let resolved = input.resolving(draft, on: base)
        XCTAssertEqual(resolved?.takeProfit?.triggerPrice, 202)
        XCTAssertEqual(resolved?.stopLoss?.triggerPrice, 95)
    }

    func test_inputMemory_keepsUntouchedLegsWhenAnotherSheetUsesADifferentBase() {
        let slot = PerpsAutoCloseInputMemory().slot(accountIndex: 7, marketId: 1)
        let input = PerpsAutoCloseROIInput(
            takeProfit: PerpsAutoCloseROI(sign: .plus, text: "10"),
            stopLoss: PerpsAutoCloseROI(sign: .minus, text: "20")
        )
        slot.remember(input)
        let draft = PerpsAutoClose(
            takeProfit: PerpsAutoCloseTrigger(triggerPrice: 101),
            stopLoss: PerpsAutoCloseTrigger(triggerPrice: 98)
        )
        let sheet = makeViewModel(side: .long, entry: 100.5, leverage: 5, draft: draft, inputMemory: slot)
        XCTAssertEqual(sheet.roiInput, .none)
        sheet.onApply = .draft { _, _ in }
        sheet.apply()
        XCTAssertEqual(slot.input, input)

        sheet.setTakeProfitPrice("102")
        sheet.apply()
        XCTAssertEqual(slot.input, PerpsAutoCloseROIInput(stopLoss: input.stopLoss))

        sheet.setStopLossPercent("")
        sheet.apply()
        XCTAssertEqual(slot.input, .none)
    }

    func test_inputMemory_settingANewLegPreservesAnUntouchedMissingLeg() {
        let slot = PerpsAutoCloseInputMemory().slot(accountIndex: 7, marketId: 1)
        let tp = PerpsAutoCloseROI(sign: .plus, text: "1.23")
        slot.remember(PerpsAutoCloseROIInput(takeProfit: tp))
        let sheet = makeViewModel(side: .long, entry: 200, inputMemory: slot)
        sheet.setStopLossPercent("10")
        sheet.onApply = .draft { _, _ in }
        sheet.apply()
        XCTAssertEqual(slot.input, PerpsAutoCloseROIInput(
            takeProfit: tp,
            stopLoss: PerpsAutoCloseROI(sign: .minus, text: "10")
        ))
    }

    func test_unplaceableROI_keepsItsInputAndBlocksSetUntilCorrected() {
        let draft = PerpsAutoClose(takeProfit: PerpsAutoCloseTrigger(triggerPrice: 90), stopLoss: nil)
        let input = PerpsAutoCloseROIInput(takeProfit: PerpsAutoCloseROI(sign: .plus, text: "100"))
        let base = PerpsAutoCloseBase(side: .short, entryPrice: 100, leverage: 1, priceDecimals: 2)
        XCTAssertEqual(input.resolving(draft, on: base), draft)
        XCTAssertTrue(input.hasInvalidPrice(on: base))

        let sheet = makeViewModel(side: .short, leverage: 1, draft: draft, roiInput: input)
        XCTAssertEqual(sheet.takeProfitPercentText, "100")
        XCTAssertNil(sheet.takeProfitPrice)
        XCTAssertEqual(sheet.takeProfitWarningText, TKLocales.Perps.Error.autoCloseInvalid)
        XCTAssertFalse(sheet.isApplyEnabled)
        var applied = false
        sheet.onApply = .draft { _, _ in applied = true }
        sheet.apply()
        XCTAssertFalse(applied)

        sheet.setTakeProfitPercent("20")
        XCTAssertEqual(sheet.takeProfitPrice, 80)
        XCTAssertNil(sheet.takeProfitWarningText)
        XCTAssertTrue(sheet.isApplyEnabled)
        sheet.apply()
        XCTAssertTrue(applied)
    }

    func test_nonPositiveDerivedPrice_isNotAppliedAsClearingTheLeg() {
        for side in [PerpsTradeSide.long, .short] {
            let sheet = makeViewModel(side: side, leverage: 1)
            if side == .long {
                sheet.setStopLossPercent("150")
            } else {
                sheet.setTakeProfitPercent("150")
            }
            XCTAssertFalse(sheet.isApplyEnabled)
            XCTAssertFalse(sheet.isValid)
        }
    }

    func test_confirmSheet_keepsEntryAndBaseSizeOnTheReviewedBasis() {
        let input = PerpsAutoCloseROIInput(takeProfit: PerpsAutoCloseROI(sign: .plus, text: "10"))
        let intent = PerpsOpenMarketIntent(
            marketId: 1, side: .long, marginUsd: "100", leverage: 10, maxSlippage: 0.01,
            autoClose: PerpsAutoClose(takeProfit: PerpsAutoCloseTrigger(triggerPrice: 101), stopLoss: nil)
        )
        var context = PerpsConfirmContext(
            intent: intent, sizeDecimals: 6, priceDecimals: 2,
            review: PerpsOpenOrderReview(
                symbol: "BTC", marginUsd: 100, entryPrice: 100, liquidationPrice: nil,
                notionalUsd: 1000, baseSize: 10, estimatedFeeUsd: nil, liquidationUnavailableReason: nil
            )
        )
        let oldSheet = context.autoCloseSheetContext(referencePrice: 120, roiInput: input)
        XCTAssertEqual(oldSheet.entryPrice, 100)
        XCTAssertEqual(oldSheet.baseSize, 10)

        context.review = PerpsOpenOrderReview(
            symbol: "BTC", marginUsd: 100, entryPrice: 125, liquidationPrice: nil,
            notionalUsd: 1000, baseSize: 8, estimatedFeeUsd: nil, liquidationUnavailableReason: nil
        )
        let refreshed = context.autoCloseSheetContext(referencePrice: 125.5, roiInput: input)
        let sheet = PerpsAutoCloseSheetViewModel(context: refreshed, format: PerpsFormatting.test)
        XCTAssertEqual(sheet.entryPrice, 125)
        XCTAssertEqual(sheet.referencePrice, 125.5)
        XCTAssertEqual(sheet.takeProfitPrice, 126.25)
        XCTAssertEqual(sheet.takeProfitExpectedText, TKLocales.Perps.OpenPosition.expectedProfit(PerpsFormatting.test.signedUsd(10)))
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
