@testable import App
import AppUI
import BigInt
import Combine
import Foundation
@testable import KeeperCore
import OperationReviewModels
import TKCore
import TKLocalize
import TKTestSupport
import TonSwift
import XCTest

/// Announces each change a wait in this file reads: the view model's, a spy's or a callback's.
private let changed = TestSignal()

final class MultichainSwapConfirmationViewModelTests: XCTestCase {
    private var subscriptions = Set<AnyCancellable>()

    @MainActor
    func test_displayMakerFormatsConfirmationDetailsAndNetworkFeeStates() {
        let maker = MultichainSwapConfirmationDisplayMaker(
            amountFormatter: makeAmountFormatter()
        )
        let input = makeInput(
            route: makeRoute(
                totalSlippageBps: 100,
                valueDifferenceBps: -250,
                fees: [
                    MultichainSwapFee(
                        type: "protocol",
                        asset: "TON",
                        amount: "3",
                        amountUsd: "0.12"
                    ),
                    MultichainSwapFee(
                        type: "bridge",
                        asset: "ETH",
                        amount: "0.001"
                    ),
                ],
                warnings: ["High volatility"]
            )
        )

        let display = maker.make(
            input: input,
            networkFees: [networkFee()],
            selectedSlippageBps: 75
        )
        let loadingDisplay = maker.make(
            input: input,
            networkFees: nil,
            selectedSlippageBps: 75
        )

        XCTAssertTrue(display.rateLine.hasPrefix("1 ETH ≈ "))
        XCTAssertTrue(display.rateLine.hasSuffix(" TON"))
        XCTAssertTrue(display.rateLine.contains("2.5") || display.rateLine.contains("2,5"))
        XCTAssertEqual(display.slippageLine, maker.percentLine(bps: 75))
        XCTAssertEqual(display.minimumReceivedLine, "≈ 2.45 TON")
        XCTAssertNil(display.minimumReceivedFiatLine)
        XCTAssertEqual(display.networkFeeValue, "≈ 0.0021")
        XCTAssertEqual(display.networkFeeMethod, "ETH")
        XCTAssertEqual(display.networkFeeSubtitle, TKLocales.MultichainSwap.Screen.Confirm.NetworkFee.estimatedTime(5))
        XCTAssertFalse(display.isNetworkFeeShortage)
        XCTAssertEqual(
            loadingDisplay.networkFeeValue,
            TKLocales.MultichainSwap.Screen.Confirm.Value.calculating
        )
    }

    /// The minimum received has its fiat value; the fee is shown in what pays it, as the swap settings
    /// draw it.
    @MainActor
    func test_displayMakerShowsFiatForMinimumReceivedAndTheFeeInItsAsset() {
        let maker = MultichainSwapConfirmationDisplayMaker(
            amountFormatter: makeAmountFormatter()
        )
        let input = makeInput(
            sendAsset: asset(symbol: "ETH", decimals: 18, usdPrice: 2000),
            receiveAsset: asset(assetId: "ton/mainnet/coin", symbol: "TON", decimals: 9, usdPrice: 5)
        )

        let display = maker.make(
            input: input,
            networkFees: [networkFee()],
            feeOptions: [nativeOption()],
            selectedFeeOption: nativeOption(),
            selectedSlippageBps: 100
        )

        let minimumReceivedFiat = display.minimumReceivedFiatLine ?? ""
        XCTAssertTrue(minimumReceivedFiat.hasPrefix("≈ $"), minimumReceivedFiat)
        XCTAssertTrue(minimumReceivedFiat.contains("12.25"), minimumReceivedFiat)
        XCTAssertEqual(display.networkFeeValue, "≈ 0.0021")
        XCTAssertEqual(display.networkFeeMethod, "ETH")
    }

    /// Nothing can pay: a battery says how many charges it has, a coin that it is missing, both in red;
    /// a battery that pays shows what it locks on top of its fee.
    @MainActor
    func test_displayMakerNamesWhatTheFeeIsShortOfAndTheBatteryReserve() {
        let maker = MultichainSwapConfirmationDisplayMaker(amountFormatter: makeAmountFormatter())
        let input = makeInput()
        func display(_ option: MultichainSwapFeeOption) -> MultichainSwapConfirmationDisplay {
            maker.make(
                input: input,
                networkFees: [networkFee()],
                feeOptions: [option],
                selectedFeeOption: option,
                selectedSlippageBps: 100
            )
        }
        let chargesText = "21 \(TKLocales.Battery.Refill.chargesCount(count: 21))"

        // The battery holds 28 and gives 21 back: a fee of 7 and a reserve of 21, as the design draws it.
        let shortBattery = display(MultichainSwapFeeOption(
            cost: .batteryCharges(count: 28, excess: 21, isInsufficient: true),
            availableCharges: 3
        ))
        XCTAssertEqual(shortBattery.networkFeeValue, "7 \(TKLocales.Battery.Refill.chargesCount(count: 7))")
        XCTAssertEqual(shortBattery.networkFeeMethod, TKLocales.Settings.Items.battery)
        XCTAssertEqual(shortBattery.networkFeeSubtitle, TKLocales.MultichainSwap.Screen.Confirm.NetworkFee.notEnoughCharges("3"))
        XCTAssertTrue(shortBattery.isNetworkFeeShortage)

        let battery = display(MultichainSwapFeeOption(
            cost: .batteryCharges(count: 28, excess: 21, isInsufficient: false),
            availableCharges: 771
        ))
        XCTAssertEqual(battery.networkFeeSubtitle, TKLocales.TronUsdtFees.TransactionConfirmation.outOfAvailable("771"))
        XCTAssertFalse(battery.isNetworkFeeShortage)
        XCTAssertEqual(shortBattery.temporaryReserve?.value, "≈ \(chargesText)")

        let shortCoin = display(MultichainSwapFeeOption(cost: .native([networkFee()], isInsufficient: true)))
        XCTAssertEqual(shortCoin.networkFeeSubtitle, TKLocales.MultichainSwap.Screen.Confirm.NetworkFee.notEnough("ETH"))
        XCTAssertTrue(shortCoin.isNetworkFeeShortage)
        XCTAssertNil(shortCoin.temporaryReserve)

        let payingBattery = display(MultichainSwapFeeOption(
            cost: .batteryCharges(count: 28, excess: 21, isInsufficient: false),
            availableCharges: 771
        ))
        XCTAssertFalse(payingBattery.isNetworkFeeShortage)
        XCTAssertEqual(payingBattery.temporaryReserve?.value, "≈ \(chargesText)")
        XCTAssertEqual(
            payingBattery.temporaryReserve?.hint,
            TKLocales.MultichainSwap.Screen.Confirm.TemporaryReserve.chargesInfo(chargesText)
        )
    }

    @MainActor
    func test_swapStartedFromTheSwapScreenConfirmsTheFirstPlan() async {
        let executionService = ConfirmationExecutionServiceSpy(
            executionPlanResults: [.success(makeExecutionPlan(fees: [networkFee()], feeOptions: [nativeOption()]))]
        )
        var confirmCount = 0
        var unavailableCount = 0
        let viewModel = makeViewModel(
            executionService: executionService,
            onConfirm: { confirmCount += 1 },
            onConfirmUnavailable: { unavailableCount += 1 }
        )

        viewModel.confirmWhenReady()
        viewModel.prepareExecutionPlan()

        await waitUntil { confirmCount == 1 }
        XCTAssertEqual(confirmCount, 1)
        XCTAssertEqual(unavailableCount, 0)
    }

    @MainActor
    func test_swapStartedFromTheSwapScreenOpensTheDetailsWhenThePlanCannotPay() async {
        let executionService = ConfirmationExecutionServiceSpy(
            executionPlanResults: [
                .success(makeExecutionPlan(fees: [networkFee()], feeOptions: [batteryOption(isInsufficient: true)])),
            ]
        )
        var confirmCount = 0
        var unavailableCount = 0
        let viewModel = makeViewModel(
            executionService: executionService,
            onConfirm: { confirmCount += 1 },
            onConfirmUnavailable: { unavailableCount += 1 }
        )

        viewModel.confirmWhenReady()
        viewModel.prepareExecutionPlan()

        await waitUntil { unavailableCount == 1 }
        XCTAssertEqual(unavailableCount, 1)
        XCTAssertEqual(confirmCount, 0)
    }

    /// The price impact warning comes up before the plan is asked for: the swap holds the screen's quote
    /// from the tap, and backing out of the warning releases it with no plan prepared.
    @MainActor
    func test_backingOutOfThePriceImpactWarningPreparesNoPlan() {
        let executionService = ConfirmationExecutionServiceSpy(
            executionPlanResults: [.success(makeExecutionPlan(fees: [networkFee()], feeOptions: [nativeOption()]))]
        )
        var confirmCount = 0
        var unavailableCount = 0
        var inFlightChanges = [Bool]()
        let viewModel = makeViewModel(
            executionService: executionService,
            onConfirm: { confirmCount += 1 },
            onConfirmUnavailable: { unavailableCount += 1 },
            onSwapInFlightChange: { inFlightChanges.append($0) }
        )

        viewModel.confirmWhenReady()
        XCTAssertEqual(inFlightChanges, [true])
        viewModel.cancelConfirm()

        XCTAssertEqual(inFlightChanges, [true, false])
        XCTAssertEqual(executionService.executionPlanCallCount, 0)
        XCTAssertEqual(confirmCount, 0)
        XCTAssertEqual(unavailableCount, 0)
    }

    @MainActor
    func test_acceptedPriceImpactCoversOnlyTheRouteItWasGivenFor() {
        let viewModel = makeViewModel(input: makeInput(route: makeRoute(valueDifferenceBps: -1200)))

        XCTAssertFalse(viewModel.isPriceImpactAccepted)
        viewModel.acceptPriceImpact()
        XCTAssertTrue(viewModel.isPriceImpactAccepted)

        viewModel.updateQuote(freshQuote(route: makeRoute(routeId: "refreshed-route", valueDifferenceBps: -1200)))

        XCTAssertFalse(viewModel.isPriceImpactAccepted)
    }

    /// A swap tapped before its plan goes on with the route a recovery brings, so that route's price impact
    /// is asked about again before the passcode.
    @MainActor
    func test_routeRecoveredForAPendingSwapIsAskedAboutAgain() async {
        let executionService = ConfirmationExecutionServiceSpy(
            executionPlanResults: [
                .failure(.preparationFailed(kind: .internalError, reason: "internal server error")),
                .success(makeExecutionPlan(routeId: "recovered-route", fees: [networkFee()])),
            ]
        )
        let swapService = ConfirmationSwapServiceSpy(
            quoteResults: [
                .success(MultichainSwapQuote(
                    quoteId: "recovered-quote",
                    routes: [makeRoute(routeId: "recovered-route", valueDifferenceBps: -1500)]
                )),
            ]
        )
        var confirmCount = 0
        let viewModel = makeViewModel(
            input: makeInput(route: makeRoute(valueDifferenceBps: -1200)),
            executionService: executionService,
            swapService: swapService,
            onConfirm: { confirmCount += 1 }
        )

        viewModel.confirmWhenReady()
        viewModel.acceptPriceImpact()
        viewModel.prepareExecutionPlan()

        await waitUntil { confirmCount == 1 }
        XCTAssertEqual(viewModel.currentConfirmationInput.quoteState.route.routeId, "recovered-route")
        XCTAssertFalse(viewModel.isPriceImpactAccepted)
        XCTAssertEqual(viewModel.priceImpactSeverity, .danger)
    }

    /// The swap was tapped for what the screen's route gives: a route recovered meanwhile that gives less
    /// is pinned and asked about before the passcode.
    @MainActor
    func test_routeRecoveredWithLessToReceiveAsksBeforeTheSwap() async {
        let executionService = ConfirmationExecutionServiceSpy(
            executionPlanResults: [
                .failure(.routeExpired(routeId: "route")),
                .success(makeExecutionPlan(routeId: "recovered-route", fees: [networkFee()])),
            ]
        )
        let swapService = ConfirmationSwapServiceSpy(
            quoteResults: [
                .success(MultichainSwapQuote(
                    quoteId: "recovered-quote",
                    routes: [makeRoute(routeId: "recovered-route", estimatedDestinationAmount: "2400000000")]
                )),
            ]
        )
        var confirmCount = 0
        var priceChanges = [String]()
        var inFlightChanges = [Bool]()
        let viewModel = makeViewModel(
            executionService: executionService,
            swapService: swapService,
            onConfirm: { confirmCount += 1 },
            onPriceChanged: { priceChanges.append($0) },
            onSwapInFlightChange: { inFlightChanges.append($0) }
        )

        viewModel.confirmWhenReady()
        viewModel.prepareExecutionPlan()

        await waitUntil { !priceChanges.isEmpty }
        let receiveSymbol = viewModel.currentConfirmationInput.userInput.receiveAsset.swapDisplaySymbol
        let amounts = makeAmountFormatter().formatDistinctly(
            2_400_000_000,
            2_500_000_000,
            fractionDigits: 9,
            accessory: .tokenSymbol(receiveSymbol)
        )
        XCTAssertEqual(priceChanges, [TKLocales.MultichainSwap.Screen.Confirm.PriceChanged.receive(amounts.0, amounts.1)])
        XCTAssertEqual(confirmCount, 0)
        XCTAssertEqual(inFlightChanges, [true])

        viewModel.execute(signer: .mnemonic(passcodeProvider: { "passcode" }), consent: .refuse)

        await waitUntil { viewModel.executionState == .completed }
        XCTAssertEqual(executionService.executedRouteIds, ["recovered-route"])
    }

    /// A swap by the amount to receive is priced by what it sells, and backing out of the warning sends nothing.
    @MainActor
    func test_routeRecoveredSellingMoreForTheAmountToReceiveAsksBeforeTheSwap() async {
        let executionService = ConfirmationExecutionServiceSpy(
            executionPlanResults: [
                .failure(.routeExpired(routeId: "route")),
                .success(makeExecutionPlan(routeId: "recovered-route", fees: [networkFee()])),
            ]
        )
        let recoveredSourceAmount = oneEth + oneEth / 10
        let swapService = ConfirmationSwapServiceSpy(
            quoteResults: [
                .success(MultichainSwapQuote(
                    quoteId: "recovered-quote",
                    routes: [makeRoute(routeId: "recovered-route", sourceAmount: recoveredSourceAmount.description)]
                )),
            ]
        )
        var priceChanges = [String]()
        var inFlightChanges = [Bool]()
        let viewModel = makeViewModel(
            input: makeInput(quoteAmount: .destination(2_500_000_000)),
            executionService: executionService,
            swapService: swapService,
            onPriceChanged: { priceChanges.append($0) },
            onSwapInFlightChange: { inFlightChanges.append($0) }
        )

        viewModel.confirmWhenReady()
        viewModel.prepareExecutionPlan()

        await waitUntil { !priceChanges.isEmpty }
        let sendSymbol = viewModel.currentConfirmationInput.userInput.sendAsset.swapDisplaySymbol
        let amounts = makeAmountFormatter().formatDistinctly(
            recoveredSourceAmount,
            oneEth,
            fractionDigits: 18,
            accessory: .tokenSymbol(sendSymbol)
        )
        XCTAssertEqual(priceChanges, [TKLocales.MultichainSwap.Screen.Confirm.PriceChanged.send(amounts.0, amounts.1)])

        viewModel.cancelConfirm()
        viewModel.execute(signer: .mnemonic(passcodeProvider: { "passcode" }), consent: .refuse)

        XCTAssertEqual(inFlightChanges, [true, false])
        XCTAssertEqual(executionService.executeCallCount, 0)
    }

    @MainActor
    func test_picksFromTheSwapScreenAreKeptAndNewOnesReported() async {
        let executionService = ConfirmationExecutionServiceSpy(
            executionPlanResults: [
                .success(makeExecutionPlan(fees: [networkFee()], feeOptions: [nativeOption(), batteryOption()])),
            ]
        )
        var reportedSlippage = [Int]()
        let viewModel = makeViewModel(
            input: makeInput(slippageBps: 50, feeMethod: .battery),
            executionService: executionService,
            onSlippageChange: { reportedSlippage.append($0) }
        )

        viewModel.prepareExecutionPlan()
        await waitUntil { executionService.executionPlanCallCount == 1 && viewModel.isConfirmEnabled }

        XCTAssertEqual(viewModel.selectedSlippageBps, 50)
        XCTAssertEqual(viewModel.selectedFeeMethod, .battery)
        viewModel.selectSlippageBps(100)
        XCTAssertEqual(reportedSlippage, [100])
    }

    func test_priceImpactResolverUsesRouteBpsAndMapsSeverity() {
        let resolver = MultichainSwapConfirmationPriceImpactResolver()
        let input = makeInput(
            route: makeRoute(valueDifferenceBps: -400)
        )

        XCTAssertEqual(resolver.priceImpactBps(input: input), -400)
        XCTAssertEqual(resolver.severity(input: input), .warning)
        XCTAssertEqual(MultichainSwapPriceImpactSeverity(bps: -501), .danger)
        XCTAssertEqual(MultichainSwapPriceImpactSeverity(bps: -299), .none)
    }

    func test_priceImpactResolverIgnoresUsdFallbackWhenRouteOmitsValueDifference() {
        let resolver = MultichainSwapConfirmationPriceImpactResolver()
        let pricedInput = makeInput(
            sendAsset: asset(symbol: "ETH", decimals: 18, usdPrice: 2),
            receiveAsset: asset(
                assetId: "ton/mainnet/coin",
                symbol: "TON",
                decimals: 9,
                usdPrice: 0.5
            ),
            route: makeRoute(
                estimatedDestinationAmount: "3000000000",
                minimumDestinationAmount: "2900000000",
                valueDifferenceBps: nil
            )
        )

        XCTAssertNil(resolver.priceImpactBps(input: pricedInput))
        XCTAssertEqual(resolver.severity(input: pricedInput), .none)
    }

    @MainActor
    func test_viewModelInitialRenderPreservesConfirmationState() {
        let viewModel = makeViewModel()

        XCTAssertEqual(viewModel.display.networkFeeValue, TKLocales.MultichainSwap.Screen.Confirm.Value.calculating)
        XCTAssertEqual(viewModel.selectedSlippageBps, 100)
        XCTAssertEqual(viewModel.currentConfirmationInput.quoteState.route.routeId, "route")
        XCTAssertEqual(viewModel.executionState, .idle)

        let state = MultichainSwapConfirmationViewStateMapper().map(viewModel)
        XCTAssertEqual(state.action, .swap(isEnabled: true, isLoading: false))
        XCTAssertEqual(state.networkFee.value, TKLocales.MultichainSwap.Screen.Confirm.Value.calculating)
        guard case .countdown = state.quoteProgress else {
            return XCTFail("Expected the screen's countdown")
        }
    }

    @MainActor
    func test_slippageSelectionWaitsForTheScreenQuoteAndRerendersDisplay() async {
        let executionService = ConfirmationExecutionServiceSpy()
        var reportedSlippage = [Int]()
        let viewModel = makeViewModel(
            executionService: executionService,
            onSlippageChange: { reportedSlippage.append($0) }
        )

        viewModel.selectSlippageBps(50)

        XCTAssertEqual(reportedSlippage, [50])
        XCTAssertEqual(viewModel.quoteStatus, .loading)
        XCTAssertFalse(viewModel.isSwapEnabled)

        viewModel.updateQuote(freshQuote(route: makeRoute(
            routeId: "refreshed-route",
            estimatedDestinationAmount: "3000000000",
            minimumDestinationAmount: "2900000000",
            totalSlippageBps: 50
        )))

        XCTAssertEqual(viewModel.currentConfirmationInput.quoteState.route.routeId, "refreshed-route")
        XCTAssertEqual(viewModel.display.minimumReceivedLine, "≈ 2.9 TON")
        XCTAssertTrue(viewModel.isSwapEnabled)
        await waitUntil { executionService.executionPlanCallCount == 1 }
    }

    @MainActor
    func test_staleRouteRecoveryFromTonSourceAsksForFullPayloadInsteadOfDepositAddress() async {
        let executionService = ConfirmationExecutionServiceSpy(
            executionPlanResults: [
                .failure(.routeExpired(routeId: "route")),
                .success(makeExecutionPlan(fees: [networkFee()])),
            ]
        )
        let swapService = ConfirmationSwapServiceSpy(
            quoteResults: [
                .success(MultichainSwapQuote(quoteId: "recovered-quote", routes: [makeRoute()])),
            ]
        )
        let viewModel = makeViewModel(
            sendAsset: asset(assetId: "ton/mainnet/coin", symbol: "TON", decimals: 9),
            receiveAsset: asset(assetId: "eth/mainnet/coin", symbol: "ETH", decimals: 18),
            executionService: executionService,
            swapService: swapService
        )

        viewModel.prepareExecutionPlan()

        await waitUntil { swapService.quoteRequests.count == 1 }
        XCTAssertEqual(swapService.quoteRequests.first?.senderAddress, "tonwallet")
        XCTAssertEqual(swapService.quoteRequests.first?.returnDepositAddress, false)
    }

    /// The quote on screen is the one the failed refresh was meant to replace, so the swap must not
    /// send it, and nothing moves until the user asks again.
    @MainActor
    func test_failedScreenQuoteLocksTheSwapUntilARetryBringsANewOne() async {
        let executionService = ConfirmationExecutionServiceSpy(
            executionPlanResults: [
                .success(makeExecutionPlan(fees: [networkFee()])),
                .success(makeExecutionPlan(routeId: "refreshed-route", fees: [networkFee()])),
            ]
        )
        var refreshRequests = 0
        var preparationFailureMessages = [String]()
        let viewModel = makeViewModel(
            executionService: executionService,
            onRefreshQuote: { refreshRequests += 1 },
            onPreparationFailed: { preparationFailureMessages.append($0) }
        )

        viewModel.prepareExecutionPlan()
        await waitUntil { viewModel.isConfirmEnabled }

        viewModel.updateQuote(.failed(.quote(.unavailable)))

        XCTAssertEqual(viewModel.quoteFailureMessage, TKLocales.MultichainSwap.ProviderError.unknown)
        XCTAssertFalse(viewModel.isSwapEnabled)
        XCTAssertEqual(preparationFailureMessages, [])

        viewModel.confirm()
        viewModel.execute(signer: .mnemonic(passcodeProvider: { "passcode" }), consent: .refuse)
        XCTAssertEqual(executionService.executeCallCount, 0)
        XCTAssertEqual(refreshRequests, 0)

        viewModel.retryQuote()

        XCTAssertEqual(refreshRequests, 1)
        XCTAssertEqual(viewModel.quoteStatus, .loading)

        viewModel.updateQuote(freshQuote(route: makeRoute(routeId: "refreshed-route")))

        await waitUntil { viewModel.isConfirmEnabled }
        XCTAssertNil(viewModel.quoteFailureMessage)
        XCTAssertEqual(viewModel.currentConfirmationInput.quoteState.route.routeId, "refreshed-route")
        XCTAssertEqual(executionService.executionPlanCallCount, 2)
    }

    /// The sheet names the reason the swap screen has, rather than one message for every failure.
    @MainActor
    func test_failedScreenQuoteNamesItsReason() {
        let expectations: [(MultichainSwapConfirmationQuoteFailure, String)] = [
            (.quote(.unavailable), TKLocales.MultichainSwap.ProviderError.unknown),
            (.quote(.pairUnavailable), TKLocales.NativeSwap.Quote.Rate.pairUnavailable),
            (.quote(.walletScreened), TKLocales.MultichainSwap.ProviderError.walletScreened),
            (.quote(.offline), TKLocales.MultichainSwap.Screen.Confirm.Error.networkError),
            (.insufficientBalance, TKLocales.InsufficientFunds.insufficientBalance),
        ]
        for (failure, message) in expectations {
            let viewModel = makeViewModel()

            viewModel.updateQuote(.failed(failure))

            XCTAssertEqual(viewModel.quoteFailureMessage, message)
            XCTAssertEqual(MultichainSwapConfirmationViewStateMapper().map(viewModel).action, .quoteFailed(message))
        }
    }

    @MainActor
    func test_slippageCanBeChangedAgainAfterAFailedQuote() {
        var reportedSlippage = [Int]()
        let viewModel = makeViewModel(onSlippageChange: { reportedSlippage.append($0) })

        viewModel.selectSlippageBps(50)
        viewModel.updateQuote(.failed(.quote(.unavailable)))
        viewModel.selectSlippageBps(100)

        XCTAssertEqual(reportedSlippage, [50, 100])
        XCTAssertEqual(viewModel.quoteStatus, .loading)
        XCTAssertFalse(viewModel.isSwapEnabled)
    }

    /// The legacy TRON pair carries no slippage config, and a SwapKit route reports a negative
    /// `total_slippage_bps`; asking with it again fails the quote validation.
    @MainActor
    func test_staleRouteRecoveryWithoutSlippageConfigAsksWithTheDefaultSlippage() async {
        let executionService = ConfirmationExecutionServiceSpy(
            executionPlanResults: [
                .failure(.routeExpired(routeId: "route")),
                .success(makeExecutionPlan(fees: [networkFee()])),
            ]
        )
        let swapService = ConfirmationSwapServiceSpy(
            quoteResults: [
                .success(MultichainSwapQuote(quoteId: "recovered-quote", routes: [makeRoute()])),
            ]
        )
        let viewModel = makeViewModel(
            input: makeInput(route: makeRoute(totalSlippageBps: -4136), slippage: nil),
            executionService: executionService,
            swapService: swapService,
            slippageService: nil
        )

        XCTAssertEqual(viewModel.selectedSlippageBps, 100)

        viewModel.prepareExecutionPlan()

        await waitUntil { swapService.quoteRequests.count == 1 }
        XCTAssertEqual(swapService.quoteRequests.first?.slippageBps, 100)
    }

    @MainActor
    func test_screenQuotePreparationFailureSendsTheSwapBackForAFreshQuote() async {
        let executionService = ConfirmationExecutionServiceSpy(
            executionPlanResults: [
                .success(makeExecutionPlan(routeId: "route", fees: [networkFee()])),
                .failure(.emulationFailed(kind: .insufficientBalance, reason: "insufficient")),
            ]
        )
        var failedMessages = [String]()
        var preparationFailureMessages = [String]()
        let viewModel = makeViewModel(
            executionService: executionService,
            onExecutionFailed: { message, _ in failedMessages.append(message) },
            onPreparationFailed: { preparationFailureMessages.append($0) }
        )

        viewModel.prepareExecutionPlan()
        await waitUntil { viewModel.isConfirmEnabled }

        viewModel.updateQuote(freshQuote(route: makeRoute(routeId: "fresh-route")))
        await waitUntil { !preparationFailureMessages.isEmpty }
        await viewModel.refreshModel.refreshTask?.value

        XCTAssertEqual(
            preparationFailureMessages,
            [TKLocales.MultichainSwap.Screen.Confirm.Error.insufficientBalance]
        )
        XCTAssertEqual(failedMessages, [])
        XCTAssertFalse(viewModel.isSwapEnabled)
    }

    /// The fee row names the shortage of the chain's coin, and Swap looks blocked while only a tap on it opens the
    /// deposit: every tap does, and no refresh, a deposit's included, does it on its own.
    @MainActor
    func test_nativeFeeShortageOpensFromEverySwapTapAndFromNoRefresh() async {
        let shortage = MultichainNativeFeeShortage(
            asset: asset(symbol: "ETH", decimals: 18).asset,
            requiredAmount: BigUInt(2_100_000_000_000_000)
        )
        let executionService = ConfirmationExecutionServiceSpy(
            executionPlanResults: [
                .failure(.insufficientNativeFee(shortage: shortage)),
                .failure(.insufficientNativeFee(shortage: MultichainNativeFeeShortage(
                    asset: shortage.asset,
                    requiredAmount: BigUInt(4_200_000_000_000_000)
                ))),
            ]
        )
        var shortages = [MultichainNativeFeeShortage]()
        let viewModel = makeViewModel(
            executionService: executionService,
            onInsufficientNativeFee: { shortages.append($0) }
        )

        viewModel.prepareExecutionPlan()
        await waitUntil { viewModel.display.isNetworkFeeShortage }

        XCTAssertEqual(shortages, [])
        XCTAssertEqual(MultichainSwapConfirmationViewStateMapper().map(viewModel).action, .feeUnpaid)

        viewModel.confirm()
        viewModel.confirm()

        XCTAssertEqual(shortages, [shortage, shortage])

        viewModel.refreshFeeCalculationAfterDeposit()
        await waitUntil { executionService.executionPlanCallCount == 2 && viewModel.display.networkFeeValue == "≈ 0.0042" }

        XCTAssertEqual(shortages.count, 2)
        XCTAssertEqual(executionService.executeCallCount, 0)
    }

    @MainActor
    func test_slippageSelectionInvalidatesExecutionPlanUntilTheNewQuoteIsPrepared() async {
        let executionService = ConfirmationExecutionServiceSpy(
            executionPlanResults: [
                .success(makeExecutionPlan(routeId: "route", fees: [networkFee()])),
                .success(makeExecutionPlan(routeId: "refreshed-route", fees: [networkFee(symbol: "TON", decimals: 9)])),
            ]
        )
        let viewModel = makeViewModel(executionService: executionService)

        viewModel.prepareExecutionPlan()
        await waitUntil { viewModel.isConfirmEnabled }

        viewModel.selectSlippageBps(50)

        XCTAssertFalse(viewModel.isSwapEnabled)
        XCTAssertEqual(
            viewModel.display.networkFeeValue,
            TKLocales.MultichainSwap.Screen.Confirm.Value.calculating
        )

        viewModel.confirm()
        viewModel.execute(signer: .mnemonic(passcodeProvider: { "passcode" }), consent: .refuse)

        XCTAssertEqual(viewModel.executionState, .idle)
        XCTAssertEqual(executionService.executeCallCount, 0)
        XCTAssertEqual(executionService.executedRouteIds, [])

        viewModel.updateQuote(freshQuote(route: makeRoute(
            routeId: "refreshed-route",
            estimatedDestinationAmount: "3000000000",
            minimumDestinationAmount: "2900000000",
            totalSlippageBps: 50
        )))
        await waitUntil(timeout: 2) { viewModel.isConfirmEnabled }
        viewModel.confirm()
        viewModel.execute(signer: .mnemonic(passcodeProvider: { "passcode" }), consent: .refuse)

        await waitUntil { viewModel.executionState == .completed }
        XCTAssertEqual(executionService.executedRouteIds, ["refreshed-route"])
    }

    @MainActor
    func test_viewDidLoadPreparesExecutionPlanAndUpdatesDisplay() async {
        let executionService = ConfirmationExecutionServiceSpy(
            executionPlanResults: [.success(makeExecutionPlan(fees: [networkFee()]))]
        )
        let viewModel = makeViewModel(executionService: executionService)

        viewModel.prepareExecutionPlan()

        await waitUntil {
            executionService.executionPlanCallCount == 1
        }
        await waitUntil {
            viewModel.display.networkFeeMethod == "ETH"
                && viewModel.display.networkFeeValue != TKLocales.MultichainSwap.Screen.Confirm.Value.calculating
        }
    }

    @MainActor
    func test_staleRouteIsRecoveredWithAFreshQuoteBeforeConfirmation() async {
        let recoveredRoute = makeRoute(routeId: "recovered-route")
        let executionService = ConfirmationExecutionServiceSpy(
            executionPlanResults: [
                .failure(.preparationFailed(kind: .internalError, reason: "internal server error")),
                .success(makeExecutionPlan(routeId: "recovered-route", fees: [networkFee()])),
            ]
        )
        let swapService = ConfirmationSwapServiceSpy(
            quoteResults: [
                .success(MultichainSwapQuote(quoteId: "recovered-quote", routes: [recoveredRoute])),
            ]
        )
        var failedMessage: String?
        var recoveredRouteIds = [String]()
        let viewModel = makeViewModel(
            executionService: executionService,
            swapService: swapService,
            onQuoteRecovered: { recoveredRouteIds.append($0.route.routeId) },
            onPreparationFailed: { failedMessage = $0 }
        )

        viewModel.prepareExecutionPlan()

        await waitUntil { viewModel.isConfirmEnabled }
        XCTAssertNil(failedMessage)
        XCTAssertEqual(swapService.quoteRequests.count, 1)
        XCTAssertEqual(executionService.executionPlanCallCount, 2)
        XCTAssertEqual(viewModel.currentConfirmationInput.quoteState.route.routeId, "recovered-route")
        XCTAssertEqual(recoveredRouteIds, ["recovered-route"])

        viewModel.confirm()
        viewModel.execute(signer: .mnemonic(passcodeProvider: { "passcode" }), consent: .refuse)

        await waitUntil { viewModel.executionState == .completed }
        XCTAssertEqual(executionService.executedRouteIds, ["recovered-route"])
    }

    /// A swap quoted by the amount to receive asks for that amount again and sells whatever the
    /// recovered route sells for it.
    @MainActor
    func test_staleRouteRecoveryByTheAmountToReceiveSellsWhatTheFreshRouteQuotes() async {
        let recoveredRoute = makeRoute(routeId: "recovered-route", sourceAmount: (oneEth / 2).description)
        let executionService = ConfirmationExecutionServiceSpy(
            executionPlanResults: [
                .failure(.preparationFailed(kind: .internalError, reason: "internal server error")),
                .success(makeExecutionPlan(routeId: "recovered-route", fees: [networkFee()])),
            ]
        )
        let swapService = ConfirmationSwapServiceSpy(
            quoteResults: [
                .success(MultichainSwapQuote(quoteId: "recovered-quote", routes: [recoveredRoute])),
            ]
        )
        var completedInput: MultichainSwapConfirmationInput?
        let viewModel = makeViewModel(
            input: makeInput(quoteAmount: .destination(2_500_000_000)),
            executionService: executionService,
            swapService: swapService,
            onExecutionCompleted: { input, _, _ in completedInput = input }
        )

        viewModel.prepareExecutionPlan()

        await waitUntil { viewModel.isConfirmEnabled }
        XCTAssertEqual(swapService.quoteRequests.first?.amount, .destination(2_500_000_000))
        XCTAssertNil(swapService.quoteRequests.first?.isMax)

        viewModel.confirm()
        viewModel.execute(signer: .mnemonic(passcodeProvider: { "passcode" }), consent: .refuse)

        await waitUntil { viewModel.executionState == .completed }
        XCTAssertEqual(completedInput?.sourceAmount, oneEth / 2)
    }

    @MainActor
    func test_staleRouteRecoveryBacksOffAndGivesUpAfterTheLadder() async {
        let executionService = ConfirmationExecutionServiceSpy(
            executionPlanResults: [
                .failure(.routeExpired(routeId: "route")),
                .failure(.routeExpired(routeId: "recovered-route")),
            ]
        )
        let swapService = ConfirmationSwapServiceSpy(
            quoteResults: [
                .success(MultichainSwapQuote(
                    quoteId: "recovered-quote",
                    routes: [makeRoute(routeId: "recovered-route")]
                )),
            ]
        )
        let recorder = RouteRecoveryDelayRecorder()
        var failedMessage: String?
        let viewModel = makeViewModel(
            executionService: executionService,
            swapService: swapService,
            routeRecovery: .recording(into: recorder),
            onPreparationFailed: { failedMessage = $0 }
        )

        viewModel.prepareExecutionPlan()

        await waitUntil { failedMessage != nil }
        await viewModel.refreshModel.refreshTask?.value
        XCTAssertEqual(recorder.delays, [0.5, 1, 2])
        XCTAssertEqual(swapService.quoteRequests.count, 3)
        XCTAssertEqual(executionService.executionPlanCallCount, 4)
        XCTAssertEqual(
            failedMessage,
            TKLocales.MultichainSwap.Screen.Confirm.Error.routeUnavailable
        )
        XCTAssertFalse(viewModel.isConfirmEnabled)
    }

    @MainActor
    func test_staleRouteRecoveryStopsOnTheRungThatSucceeds() async {
        let executionService = ConfirmationExecutionServiceSpy(
            executionPlanResults: [
                .failure(.routeExpired(routeId: "route")),
                .failure(.routeExpired(routeId: "recovered-route")),
                .success(makeExecutionPlan(routeId: "recovered-route", fees: [networkFee()])),
            ]
        )
        let swapService = ConfirmationSwapServiceSpy(
            quoteResults: [
                .success(MultichainSwapQuote(
                    quoteId: "recovered-quote",
                    routes: [makeRoute(routeId: "recovered-route")]
                )),
            ]
        )
        let recorder = RouteRecoveryDelayRecorder()
        var failedMessage: String?
        let viewModel = makeViewModel(
            executionService: executionService,
            swapService: swapService,
            routeRecovery: .recording(into: recorder),
            onPreparationFailed: { failedMessage = $0 }
        )

        viewModel.prepareExecutionPlan()

        await waitUntil { viewModel.isConfirmEnabled }
        XCTAssertEqual(recorder.delays, [0.5, 1])
        XCTAssertEqual(swapService.quoteRequests.count, 2)
        XCTAssertEqual(executionService.executionPlanCallCount, 3)
        XCTAssertNil(failedMessage)
    }

    @MainActor
    func test_staleRouteFailureIsReportedWhenTheFreshQuoteIsUnavailable() async {
        let executionService = ConfirmationExecutionServiceSpy(
            executionPlanResults: [
                .failure(.preparationFailed(kind: .badResponse, reason: "not found")),
            ]
        )
        let swapService = ConfirmationSwapServiceSpy()
        var failedMessage: String?
        let viewModel = makeViewModel(
            executionService: executionService,
            swapService: swapService,
            onPreparationFailed: { failedMessage = $0 }
        )

        viewModel.prepareExecutionPlan()

        await waitUntil { failedMessage != nil }
        XCTAssertEqual(
            failedMessage,
            TKLocales.MultichainSwap.Screen.Confirm.Error.badResponse
        )
        XCTAssertEqual(swapService.quoteRequests.count, 3)
        XCTAssertEqual(executionService.executionPlanCallCount, 1)
    }

    @MainActor
    func test_walletScreenedPreparationIsFinal() async {
        let executionService = ConfirmationExecutionServiceSpy(
            executionPlanResults: [
                .failure(.preparationFailed(kind: .walletScreened, reason: "wallet_screened")),
            ]
        )
        let swapService = ConfirmationSwapServiceSpy()
        let recorder = RouteRecoveryDelayRecorder()
        var failedMessages = [String]()
        let viewModel = makeViewModel(
            executionService: executionService,
            swapService: swapService,
            routeRecovery: .recording(into: recorder),
            onPreparationFailed: { failedMessages.append($0) }
        )

        viewModel.prepareExecutionPlan()

        await waitUntil { !failedMessages.isEmpty }
        await viewModel.refreshModel.refreshTask?.value
        XCTAssertEqual(failedMessages, [TKLocales.MultichainSwap.ProviderError.walletScreened])
        XCTAssertEqual(recorder.delays, [])
        XCTAssertTrue(swapService.quoteRequests.isEmpty)
        XCTAssertEqual(executionService.executionPlanCallCount, 1)
        XCTAssertFalse(viewModel.isConfirmEnabled)
    }

    @MainActor
    func test_screenedRouteOnRequoteEndsTheRouteRecovery() async {
        let executionService = ConfirmationExecutionServiceSpy(
            executionPlanResults: [
                .failure(.routeExpired(routeId: "route")),
            ]
        )
        let swapService = ConfirmationSwapServiceSpy(
            quoteResults: [
                .success(MultichainSwapQuote(
                    quoteId: "screened-quote",
                    routes: [makeRoute(routeId: "screened-route")],
                    providerErrors: [
                        MultichainSwapProviderError(
                            aggregator: "Aggregator",
                            code: "wallet_screened",
                            message: "wallet blocked by the provider's compliance screening"
                        ),
                    ]
                )),
            ]
        )
        let recorder = RouteRecoveryDelayRecorder()
        var failedMessages = [String]()
        var recoveredRouteIds = [String]()
        let viewModel = makeViewModel(
            executionService: executionService,
            swapService: swapService,
            routeRecovery: .recording(into: recorder),
            onQuoteRecovered: { recoveredRouteIds.append($0.route.routeId) },
            onPreparationFailed: { failedMessages.append($0) }
        )

        viewModel.prepareExecutionPlan()

        await waitUntil { !failedMessages.isEmpty }
        await viewModel.refreshModel.refreshTask?.value
        XCTAssertEqual(failedMessages, [TKLocales.MultichainSwap.ProviderError.walletScreened])
        XCTAssertEqual(recorder.delays, [0.5])
        XCTAssertEqual(swapService.quoteRequests.count, 1)
        XCTAssertEqual(executionService.executionPlanCallCount, 1)
        XCTAssertTrue(recoveredRouteIds.isEmpty)
        XCTAssertFalse(viewModel.isConfirmEnabled)
    }

    @MainActor
    func test_freshScreenQuoteDoesNotRequestAnotherQuoteForAStaleRoute() async {
        let executionService = ConfirmationExecutionServiceSpy(
            executionPlanResults: [
                .success(makeExecutionPlan(fees: [networkFee()])),
                .failure(.routeExpired(routeId: "refreshed-route")),
            ]
        )
        let swapService = ConfirmationSwapServiceSpy()
        var failedMessage: String?
        let viewModel = makeViewModel(
            executionService: executionService,
            swapService: swapService,
            onPreparationFailed: { failedMessage = $0 }
        )

        viewModel.prepareExecutionPlan()
        await waitUntil { viewModel.isConfirmEnabled }

        viewModel.updateQuote(freshQuote(route: makeRoute(routeId: "refreshed-route")))

        await waitUntil { failedMessage != nil }
        XCTAssertTrue(swapService.quoteRequests.isEmpty)
        XCTAssertEqual(executionService.executionPlanCallCount, 2)
    }

    /// A route quoted on `/v3` that has to be quoted again is quoted there again, whatever the flag says now.
    @MainActor
    func test_aStaleRouteQuotedOnV3IsQuotedAgainOnV3() async {
        var route = makeRoute()
        route.apiVersion = .v3
        let recoveredRoute = makeRoute(routeId: "recovered-route")
        let executionService = ConfirmationExecutionServiceSpy(
            executionPlanResults: [
                .failure(.payloadNotValidated(payloadId: "route", status: "pending")),
                .success(makeExecutionPlan(routeId: "recovered-route", fees: [networkFee()])),
            ]
        )
        let swapService = ConfirmationSwapServiceSpy(
            quoteResults: [.success(MultichainSwapQuote(quoteId: "recovered-quote", routes: [recoveredRoute]))]
        )
        let viewModel = makeViewModel(input: makeInput(route: route), executionService: executionService, swapService: swapService)

        viewModel.prepareExecutionPlan()

        await waitUntil { viewModel.isConfirmEnabled }
        XCTAssertEqual(swapService.quoteAPIVersions, [.v3])
        XCTAssertEqual(viewModel.currentConfirmationInput.quoteState.route.routeId, "recovered-route")
        XCTAssertEqual(viewModel.currentConfirmationInput.quoteState.route.apiVersion, .v3)
    }

    /// The backend may price a route again when it builds its operation: the details show, and the swap
    /// reports, what that operation receives.
    @MainActor
    func test_theDetailsShowWhatThePreparedOperationReceives() async throws {
        let prepared = makeRoute(estimatedDestinationAmount: "2400000000", minimumDestinationAmount: "2350000000")
        let executionService = try ConfirmationExecutionServiceSpy(executionPlanResults: [.success(makeOperationPlan(preparing: prepared))])
        let viewModel = makeViewModel(executionService: executionService)
        let shownBefore = viewModel.display.minimumReceivedLine

        viewModel.prepareExecutionPlan()

        await waitUntil { viewModel.isConfirmEnabled }
        let route = viewModel.currentConfirmationInput.quoteState.route
        XCTAssertEqual(route.estimatedDestinationAmount, "2400000000")
        XCTAssertEqual(route.minimumDestinationAmount, "2350000000")
        XCTAssertNotEqual(viewModel.display.minimumReceivedLine, shownBefore)
        XCTAssertEqual(viewModel.display.minimumReceivedLine, makeViewModel(input: makeInput(route: prepared)).display.minimumReceivedLine)
    }

    /// A plan that arrives for another route than the one shown leaves the one shown as it is.
    @MainActor
    func test_aPreparedOperationOfAnotherRouteDoesNotChangeTheRouteShown() async throws {
        let executionService = try ConfirmationExecutionServiceSpy(
            executionPlanResults: [.success(makeOperationPlan(preparing: makeRoute(routeId: "other", estimatedDestinationAmount: "1")))]
        )
        let viewModel = makeViewModel(executionService: executionService)

        viewModel.prepareExecutionPlan()

        await waitUntil { viewModel.isConfirmEnabled }
        XCTAssertEqual(viewModel.currentConfirmationInput.quoteState.route.estimatedDestinationAmount, "2500000000")
    }

    /// A swap tapped on the swap screen at its quote is asked about again before the passcode when the
    /// operation the backend built for it receives less.
    @MainActor
    func test_aSwapFromTheSwapScreenAsksWhenItsOperationReceivesLessThanItsQuote() async throws {
        let executionService = try ConfirmationExecutionServiceSpy(
            executionPlanResults: [.success(makeOperationPlan(preparing: makeRoute(estimatedDestinationAmount: "2400000000")))]
        )
        var confirmCount = 0
        var priceChanges = [String]()
        let viewModel = makeViewModel(
            executionService: executionService,
            onConfirm: { confirmCount += 1 },
            onPriceChanged: { priceChanges.append($0) }
        )

        viewModel.confirmWhenReady()
        viewModel.prepareExecutionPlan()

        await waitUntil { !priceChanges.isEmpty }
        XCTAssertEqual(confirmCount, 0)
    }

    /// A swap by the amount to receive sells as quoted, but the operation the backend built for it receives
    /// less than the amount typed: it is asked about before the passcode too.
    @MainActor
    func test_aSwapByTheAmountToReceiveAsksWhenItsOperationReceivesLessThanItsQuote() async throws {
        let executionService = try ConfirmationExecutionServiceSpy(
            executionPlanResults: [.success(makeOperationPlan(preparing: makeRoute(estimatedDestinationAmount: "2400000000")))]
        )
        var confirmCount = 0
        var priceChanges = [String]()
        let viewModel = makeViewModel(
            input: makeInput(quoteAmount: .destination(2_500_000_000)),
            executionService: executionService,
            onConfirm: { confirmCount += 1 },
            onPriceChanged: { priceChanges.append($0) }
        )

        viewModel.confirmWhenReady()
        viewModel.prepareExecutionPlan()

        await waitUntil { !priceChanges.isEmpty }
        let receiveSymbol = viewModel.currentConfirmationInput.userInput.receiveAsset.swapDisplaySymbol
        let amounts = makeAmountFormatter().formatDistinctly(
            2_400_000_000,
            2_500_000_000,
            fractionDigits: 9,
            accessory: .tokenSymbol(receiveSymbol)
        )
        XCTAssertEqual(priceChanges, [TKLocales.MultichainSwap.Screen.Confirm.PriceChanged.receive(amounts.0, amounts.1)])
        XCTAssertEqual(confirmCount, 0)
    }

    /// A quote for an amount to receive may promise more than that amount: an operation that receives less than
    /// the quote, but not less than the amount typed, goes to the passcode without asking.
    @MainActor
    func test_aSwapByTheAmountToReceiveGoesOnWhileItsOperationReceivesTheAmountTyped() async throws {
        let executionService = try ConfirmationExecutionServiceSpy(
            executionPlanResults: [.success(makeOperationPlan(preparing: makeRoute(estimatedDestinationAmount: "2505000000")))]
        )
        var confirmCount = 0
        var priceChanges = [String]()
        let viewModel = makeViewModel(
            input: makeInput(route: makeRoute(estimatedDestinationAmount: "2510000000"), quoteAmount: .destination(2_500_000_000)),
            executionService: executionService,
            onConfirm: { confirmCount += 1 },
            onPriceChanged: { priceChanges.append($0) }
        )

        viewModel.confirmWhenReady()
        viewModel.prepareExecutionPlan()

        await waitUntil { confirmCount == 1 }
        XCTAssertEqual(priceChanges, [])
    }

    /// The price impact the user accepted for the route tapped does not cover that route once the operation
    /// built for it prices it worse: its warning is asked again after the price change.
    @MainActor
    func test_anAcceptedPriceImpactIsAskedAgainWhenTheOperationPricesTheRouteWorse() async throws {
        let prepared = makeRoute(estimatedDestinationAmount: "2400000000", valueDifferenceBps: -600)
        let executionService = try ConfirmationExecutionServiceSpy(executionPlanResults: [.success(makeOperationPlan(preparing: prepared))])
        var priceChanges = [String]()
        let viewModel = makeViewModel(
            input: makeInput(route: makeRoute(valueDifferenceBps: -350)),
            executionService: executionService,
            onPriceChanged: { priceChanges.append($0) }
        )

        viewModel.confirmWhenReady()
        viewModel.acceptPriceImpact()
        XCTAssertTrue(viewModel.isPriceImpactAccepted)
        viewModel.prepareExecutionPlan()

        await waitUntil { !priceChanges.isEmpty }
        XCTAssertFalse(viewModel.isPriceImpactAccepted)
        XCTAssertEqual(viewModel.priceImpactSeverity, .danger)
    }

    @MainActor
    func test_executeWithoutPreparedExecutionPlanDoesNotStartExecution() {
        let executionService = ConfirmationExecutionServiceSpy()
        let viewModel = makeViewModel(executionService: executionService)

        viewModel.confirm()
        viewModel.execute(signer: .mnemonic(passcodeProvider: { "passcode" }), consent: .refuse)

        XCTAssertEqual(viewModel.executionState, .idle)
        XCTAssertEqual(executionService.executeCallCount, 0)
    }

    @MainActor
    func test_swapFromThePricingDetailsReportsSwapClickConfirmThenSuccess() async {
        let executionService = ConfirmationExecutionServiceSpy()
        let analytics = AnalyticsServiceSpy()
        let viewModel = makeViewModel(executionService: executionService, analytics: analytics)

        viewModel.prepareExecutionPlan()
        await waitUntil {
            executionService.executionPlanCallCount == 1 && viewModel.isConfirmEnabled
        }
        viewModel.confirm()
        viewModel.execute(signer: .mnemonic(passcodeProvider: { "passcode" }), consent: .refuse)
        await waitUntil {
            viewModel.executionState == .completed
        }

        XCTAssertEqual(analytics.events.map(\.name), ["swap_click", "swap_confirm", "swap_success"])
        let click = analytics.events.first?.args ?? [:]
        XCTAssertEqual(click["asset_from"] as? String, "eth/mainnet/coin")
        XCTAssertEqual(click["asset_to"] as? String, "ton/mainnet/coin")
        for event in analytics.events.dropFirst() {
            XCTAssertEqual(event.args["type"] as? String, "native", event.name)
            XCTAssertEqual(event.args["wallet_mode"] as? String, "multi", event.name)
            XCTAssertEqual(event.args["asset_from"] as? String, "eth/mainnet/coin", event.name)
            XCTAssertEqual(event.args["asset_to"] as? String, "ton/mainnet/coin", event.name)
            XCTAssertEqual(event.args["fee_asset"] as? String, "coin", event.name)
            XCTAssertEqual(event.args["provider_name"] as? String, "Aggregator", event.name)
            XCTAssertEqual(event.args["is_max"] as? Bool, false, event.name)
        }
    }

    @MainActor
    func test_failedSwapReportsSwapFailedWithTheFailure() async {
        let failure = MultichainSwapExecutionFailure.broadcastFailed(
            payloadId: "payload",
            kind: .networkError,
            reason: "timed out"
        )
        let executionService = ConfirmationExecutionServiceSpy(executeResult: .failure(failure))
        let analytics = AnalyticsServiceSpy()
        let viewModel = makeViewModel(executionService: executionService, analytics: analytics)

        viewModel.prepareExecutionPlan()
        await waitUntil {
            executionService.executionPlanCallCount == 1 && viewModel.isConfirmEnabled
        }
        viewModel.confirm()
        viewModel.execute(signer: .mnemonic(passcodeProvider: { "passcode" }), consent: .refuse)
        await waitUntil {
            if case .executionFailed = viewModel.executionState {
                return true
            }
            return false
        }

        XCTAssertEqual(analytics.events.map(\.name), ["swap_click", "swap_confirm", "swap_failed"])
        let failed = analytics.events.last?.args ?? [:]
        XCTAssertEqual(
            failed["error_message"] as? String,
            "type=MultichainSwapExecutionFailure, case=broadcastFailed, kind=\(MultichainSwapExecutionErrorKind.networkError.description)"
        )
        XCTAssertEqual(failed["provider_name"] as? String, "Aggregator")
        XCTAssertEqual(failed["fee_asset"] as? String, "coin")
        XCTAssertEqual(failed["asset_from"] as? String, "eth/mainnet/coin")
    }

    @MainActor
    func test_canceledSwapReportsNoFailure() async {
        let executionService = ConfirmationExecutionServiceSpy(executeResult: .failure(.canceled))
        let analytics = AnalyticsServiceSpy()
        let viewModel = makeViewModel(executionService: executionService, analytics: analytics)

        viewModel.prepareExecutionPlan()
        await waitUntil {
            executionService.executionPlanCallCount == 1 && viewModel.isConfirmEnabled
        }
        viewModel.confirm()
        viewModel.execute(signer: .mnemonic(passcodeProvider: { nil }), consent: .refuse)
        await waitUntil {
            executionService.executeCallCount == 1 && viewModel.executionState == .idle
        }

        XCTAssertEqual(analytics.events.map(\.name), ["swap_click", "swap_confirm"])
    }

    @MainActor
    func test_swapFromTheSwapScreenLeavesSwapClickToIt() async {
        let executionService = ConfirmationExecutionServiceSpy()
        let analytics = AnalyticsServiceSpy()
        var confirmCount = 0
        let viewModel = makeViewModel(
            executionService: executionService,
            onConfirm: { confirmCount += 1 },
            analytics: analytics
        )

        viewModel.confirmWhenReady()
        viewModel.prepareExecutionPlan()
        await waitUntil { confirmCount == 1 }
        viewModel.execute(signer: .mnemonic(passcodeProvider: { "passcode" }), consent: .refuse)
        await waitUntil {
            viewModel.executionState == .completed
        }

        XCTAssertEqual(analytics.events.map(\.name), ["swap_confirm", "swap_success"])
    }

    /// The swap screen counted the tap. Its swap could not pay with the battery and went on in the pricing
    /// details, whose Swap button continues it once the fee is paid rather than starting another.
    @MainActor
    func test_swapTheSwapScreenHandsToThePricingDetailsKeepsItsOneClick() async {
        let executionService = ConfirmationExecutionServiceSpy(
            executionPlanResults: [
                .success(makeExecutionPlan(fees: [networkFee()], feeOptions: [batteryOption(isInsufficient: true)])),
                .success(makeExecutionPlan(fees: [networkFee()], feeOptions: [nativeOption()])),
            ]
        )
        let analytics = AnalyticsServiceSpy()
        var confirmCount = 0
        var unavailableCount = 0
        let viewModel = makeViewModel(
            executionService: executionService,
            onConfirm: { confirmCount += 1 },
            onConfirmUnavailable: { unavailableCount += 1 },
            analytics: analytics
        )

        viewModel.confirmWhenReady()
        viewModel.prepareExecutionPlan()
        await waitUntil { unavailableCount == 1 }
        viewModel.refreshFeeCalculationAfterDeposit()
        await waitUntil { executionService.executionPlanCallCount == 2 && viewModel.isConfirmEnabled }
        viewModel.confirm()
        await waitUntil { confirmCount == 1 }
        viewModel.execute(signer: .mnemonic(passcodeProvider: { "passcode" }), consent: .refuse)
        await waitUntil {
            viewModel.executionState == .completed
        }

        XCTAssertEqual(analytics.events.map(\.name), ["swap_confirm", "swap_success"])
    }

    @MainActor
    func test_executionFailureUpdatesStateAndCallback() async {
        let executionService = ConfirmationExecutionServiceSpy(
            executeResult: .failure(.internal(reason: "test failure"))
        )
        var failedMessage: String?
        let viewModel = makeViewModel(
            executionService: executionService,
            onExecutionFailed: { message, _ in
                failedMessage = message
            }
        )

        viewModel.prepareExecutionPlan()
        await waitUntil {
            executionService.executionPlanCallCount == 1 && viewModel.isConfirmEnabled
        }
        viewModel.confirm()
        viewModel.execute(signer: .mnemonic(passcodeProvider: { "passcode" }), consent: .refuse)

        await waitUntil {
            if case .executionFailed = viewModel.executionState {
                return true
            }
            return false
        }
        let expected = TKLocales.MultichainSwap.Screen.Confirm.Error.internalError
        XCTAssertEqual(failedMessage, expected)
        if case let .executionFailed(message) = viewModel.executionState {
            XCTAssertEqual(message, expected)
        } else {
            XCTFail("Expected failed execution state")
        }
    }

    @MainActor
    func test_failedExecutionAsksForAFreshQuoteAndRetriesOnIt() async {
        let executionService = ConfirmationExecutionServiceSpy(
            executionPlanResults: [
                .success(makeExecutionPlan(routeId: "route", fees: [networkFee()])),
                .success(makeExecutionPlan(routeId: "refreshed-route", fees: [networkFee()])),
            ],
            executeResult: .failure(
                .broadcastFailed(payloadId: "main", kind: .unknown, reason: "node rejected")
            )
        )
        var events = [String]()
        let viewModel = makeViewModel(
            executionService: executionService,
            onRefreshQuote: { events.append("fresh quote") },
            onExecutionFailed: { _, _ in events.append("failure") }
        )

        viewModel.prepareExecutionPlan()
        await waitUntil { viewModel.isConfirmEnabled }

        viewModel.confirm()
        viewModel.execute(signer: .mnemonic(passcodeProvider: { "passcode" }), consent: .refuse)

        await waitUntil {
            viewModel.executionState == .executionFailed(
                TKLocales.MultichainSwap.Screen.Confirm.Error.unknown
            )
        }
        // Without the sheet the failure report ends the confirmation, so the fresh quote is asked for first.
        XCTAssertEqual(events, ["fresh quote", "failure"])

        viewModel.updateQuote(freshQuote(route: makeRoute(routeId: "refreshed-route")))
        await waitUntil { viewModel.isConfirmEnabled }

        viewModel.confirm()
        viewModel.execute(signer: .mnemonic(passcodeProvider: { "passcode" }), consent: .refuse)

        await waitUntil { executionService.executeCallCount == 2 && events.count == 4 }
        XCTAssertEqual(executionService.executedRouteIds, ["route", "refreshed-route"])
    }

    @MainActor
    func test_failedExecutionLocksTheRetryWhenTheFreshQuoteFails() async {
        let executionService = ConfirmationExecutionServiceSpy(
            executeResult: .failure(
                .broadcastFailed(payloadId: "main", kind: .unknown, reason: "node rejected")
            )
        )
        var refreshRequests = 0
        var failedMessages = [String]()
        var preparationFailureMessages = [String]()
        let viewModel = makeViewModel(
            executionService: executionService,
            onRefreshQuote: { refreshRequests += 1 },
            onExecutionFailed: { message, _ in failedMessages.append(message) },
            onPreparationFailed: { preparationFailureMessages.append($0) }
        )

        viewModel.prepareExecutionPlan()
        await waitUntil { viewModel.isConfirmEnabled }

        viewModel.confirm()
        viewModel.execute(signer: .mnemonic(passcodeProvider: { "passcode" }), consent: .refuse)

        await waitUntil { refreshRequests == 1 }
        viewModel.updateQuote(.failed(.quote(.unavailable)))

        XCTAssertEqual(failedMessages, [TKLocales.MultichainSwap.Screen.Confirm.Error.unknown])
        XCTAssertEqual(viewModel.quoteFailureMessage, TKLocales.MultichainSwap.ProviderError.unknown)
        XCTAssertEqual(preparationFailureMessages, [])
        XCTAssertFalse(viewModel.isSwapEnabled)
        XCTAssertEqual(executionService.executeCallCount, 1)
    }

    @MainActor
    func test_preparationFailureSendsTheSwapBackWithTypedMessage() async {
        let executionService = ConfirmationExecutionServiceSpy(
            executionPlanResults: [
                .failure(.preparationFailed(kind: .insufficientBalance, reason: "fee exceeds balance")),
            ]
        )
        var failedMessages = [String]()
        var preparationFailureMessages = [String]()
        let viewModel = makeViewModel(
            executionService: executionService,
            onExecutionFailed: { message, _ in failedMessages.append(message) },
            onPreparationFailed: { preparationFailureMessages.append($0) }
        )

        viewModel.prepareExecutionPlan()

        await waitUntil { !preparationFailureMessages.isEmpty }
        XCTAssertFalse(viewModel.isConfirmEnabled)
        XCTAssertEqual(
            preparationFailureMessages,
            [TKLocales.MultichainSwap.Screen.Confirm.Error.insufficientBalance]
        )
        XCTAssertEqual(failedMessages, [])
    }

    @MainActor
    func test_insufficientNativeFeePreparationKeepsFeeInDisplay() async {
        let nativeFeeAsset = asset(symbol: "ETH", decimals: 18).asset
        let shortage = MultichainNativeFeeShortage(
            asset: nativeFeeAsset,
            requiredAmount: BigUInt(2_100_000_000_000_000)
        )
        let executionService = ConfirmationExecutionServiceSpy(
            executionPlanResults: [.failure(.insufficientNativeFee(shortage: shortage))]
        )
        var presentedShortage: MultichainNativeFeeShortage?
        var preparationFailureMessages = [String]()
        let viewModel = makeViewModel(
            executionService: executionService,
            onPreparationFailed: { preparationFailureMessages.append($0) },
            onInsufficientNativeFee: { presentedShortage = $0 }
        )

        viewModel.prepareExecutionPlan()

        await waitUntil { viewModel.display.isNetworkFeeShortage }
        XCTAssertNil(presentedShortage)
        XCTAssertEqual(preparationFailureMessages, [])
        XCTAssertNotEqual(
            viewModel.display.networkFeeValue,
            TKLocales.MultichainSwap.Screen.Confirm.Value.calculating
        )
        XCTAssertEqual(viewModel.display.networkFeeMethod, "ETH")
        XCTAssertEqual(
            viewModel.display.networkFeeSubtitle,
            TKLocales.MultichainSwap.Screen.Confirm.NetworkFee.notEnough("ETH")
        )
        XCTAssertTrue(viewModel.display.isNetworkFeeShortage)
    }

    @MainActor
    func test_successfulPreparationRetryClearsPreparationFailure() async {
        let executionService = ConfirmationExecutionServiceSpy(
            executionPlanResults: [
                .failure(.preparationFailed(kind: .networkError, reason: "offline")),
                .success(makeExecutionPlan(fees: [networkFee()])),
            ]
        )
        let viewModel = makeViewModel(executionService: executionService)

        viewModel.prepareExecutionPlan()
        await waitUntil {
            if case .preparationFailed = viewModel.executionState {
                return true
            }
            return false
        }

        viewModel.prepareExecutionPlan()

        await waitUntil { viewModel.isConfirmEnabled }
        XCTAssertEqual(viewModel.executionState, .idle)
        XCTAssertEqual(executionService.executionPlanCallCount, 2)
    }

    @MainActor
    func test_executionCancellationReturnsToIdleWithoutErrorCallback() async {
        let executionService = ConfirmationExecutionServiceSpy(
            executeResult: .failure(MultichainSwapExecutionFailure.canceled)
        )
        var failedMessages = [String]()
        let viewModel = makeViewModel(
            executionService: executionService,
            onExecutionFailed: { message, _ in
                failedMessages.append(message)
            }
        )

        viewModel.prepareExecutionPlan()
        await waitUntil {
            executionService.executionPlanCallCount == 1 && viewModel.isConfirmEnabled
        }
        viewModel.confirm()
        viewModel.execute(signer: .mnemonic(passcodeProvider: { nil }), consent: .refuse)

        await waitUntil {
            executionService.executeCallCount == 1 && viewModel.executionState == .idle
        }
        XCTAssertEqual(failedMessages, [])
    }

    /// The swap is held to what its quote showed the user selling: the amount entered, not the
    /// route's echo of it, or for an amount to receive the cap the route puts on it.
    @MainActor
    func test_theSwapIsSentWithTheSpendLimitOfItsQuote() async {
        let cases: [(input: MultichainSwapConfirmationInput, spendLimit: BigUInt)] = [
            (makeInput(route: makeRoute(sourceAmount: (oneEth + 7).description), quoteAmount: .source(oneEth)), oneEth),
            (
                makeInput(
                    route: makeRoute(sourceAmount: (oneEth * 2).description, maximumSourceAmount: (oneEth * 3).description),
                    quoteAmount: .destination(2_500_000_000)
                ),
                oneEth * 3
            ),
        ]
        for (input, spendLimit) in cases {
            let executionService = ConfirmationExecutionServiceSpy()
            let viewModel = makeViewModel(input: input, executionService: executionService)

            viewModel.prepareExecutionPlan()
            await waitUntil { viewModel.isConfirmEnabled }
            viewModel.confirm()
            viewModel.execute(signer: .mnemonic(passcodeProvider: { "passcode" }), consent: .refuse)
            await waitUntil { viewModel.executionState == .completed }

            XCTAssertEqual(executionService.spendLimits, [spendLimit])
        }
    }

    /// The swipe's consent answers the review of what a relayed swap signs. A refusal cancels the
    /// swap: the screen goes back to idle with nothing failed and nothing locked, and the next swipe
    /// asks again.
    @MainActor
    func test_aRefusedReviewLeavesTheSwapIdleAndRetryable() async {
        let executionService = ConfirmationExecutionServiceSpy(
            executionPlanResults: [
                .success(makeExecutionPlan(fees: [networkFee()], feeOptions: [batteryOption(charges: 3), nativeOption()])),
            ],
            review: flaggedReview
        )
        var failedMessages = [String]()
        let viewModel = makeViewModel(
            executionService: executionService,
            onExecutionFailed: { message, _ in
                failedMessages.append(message)
            }
        )

        viewModel.prepareExecutionPlan()
        await waitUntil { viewModel.isConfirmEnabled }
        XCTAssertEqual(viewModel.selectedFeeOption?.method, .battery)
        viewModel.confirm()
        viewModel.execute(signer: .mnemonic(passcodeProvider: { "passcode" }), consent: SwipingUser(answering: false).consent())
        await waitUntil { executionService.executeCallCount == 1 && viewModel.executionState == .idle }

        XCTAssertEqual(failedMessages, [])
        XCTAssertFalse(viewModel.isRetryUnsafe)
        XCTAssertTrue(viewModel.isConfirmEnabled)

        let user = SwipingUser(answering: true)
        viewModel.confirm()
        viewModel.execute(signer: .mnemonic(passcodeProvider: { "passcode" }), consent: user.consent())
        await waitUntil { viewModel.executionState == .completed }

        let asked = await user.asked
        XCTAssertEqual(asked, [flaggedReview])
        XCTAssertEqual(executionService.feeMethods, [.battery, .battery])
    }

    func test_confirmationUserMessageMapsSwapFailureReasons() {
        XCTAssertNil(MultichainSwapExecutionFailure.canceled.confirmationUserMessage)
        XCTAssertEqual(
            MultichainSwapExecutionFailure.routeExpired(routeId: "route").confirmationUserMessage,
            TKLocales.MultichainSwap.Screen.Confirm.Error.routeUnavailable
        )
        XCTAssertEqual(
            MultichainSwapExecutionFailure
                .signingFailed(payloadId: "main", kind: .insufficientBalance, reason: "r")
                .confirmationUserMessage,
            TKLocales.MultichainSwap.Screen.Confirm.Error.insufficientBalance
        )
        XCTAssertEqual(
            MultichainSwapExecutionFailure
                .broadcastFailed(payloadId: "main", kind: .networkError, reason: "r")
                .confirmationUserMessage,
            TKLocales.MultichainSwap.Screen.Confirm.Error.networkError
        )
        XCTAssertEqual(
            MultichainSwapExecutionFailure
                .nonceFailed(payloadId: "main", kind: .noAvailableNodes, reason: "r")
                .confirmationUserMessage,
            TKLocales.MultichainSwap.Screen.Confirm.Error.noAvailableNodes
        )
        XCTAssertEqual(
            MultichainSwapExecutionFailure
                .emulationFailed(kind: .unknown, reason: "r")
                .confirmationUserMessage,
            TKLocales.MultichainSwap.Screen.Confirm.Error.unknown
        )
        XCTAssertEqual(
            MultichainSwapExecutionFailure
                .emulationFailed(kind: .unsupportedAsset, reason: "r")
                .confirmationUserMessage,
            TKLocales.MultichainSwap.Screen.Confirm.Error.unsupportedAsset
        )
        XCTAssertEqual(
            MultichainSwapExecutionFailure
                .preparationFailed(kind: .badResponse, reason: "r")
                .confirmationUserMessage,
            TKLocales.MultichainSwap.Screen.Confirm.Error.badResponse
        )
        XCTAssertEqual(
            MultichainSwapExecutionFailure
                .invalidPayload(payloadId: "main", reason: "r")
                .confirmationUserMessage,
            TKLocales.MultichainSwap.Screen.Confirm.Error.prepareFailed
        )
        XCTAssertEqual(
            MultichainSwapExecutionFailure
                .unsupportedAggregator("unsupported")
                .confirmationUserMessage,
            TKLocales.MultichainSwap.Screen.Confirm.Error.unsupportedProvider
        )
    }

    func test_transactionConfirmationUserMessageMapsMultichainFailureReasons() {
        XCTAssertEqual(
            MultichainTransactionFailure
                .emulationFailure(.chainError(kind: .insufficientBalance, reason: "technical reason"))
                .transactionConfirmationUserMessage,
            TKLocales.MultichainSwap.Screen.Confirm.Error.insufficientBalance
        )
        XCTAssertEqual(
            MultichainTransactionFailure
                .emulationFailure(.internal(reason: "technical reason"))
                .transactionConfirmationUserMessage,
            TKLocales.Multichain.Transaction.Error.failedToCalculateFee
        )
        XCTAssertEqual(
            MultichainTransactionFailure
                .failedToSign(kind: .unknown, reason: "technical reason")
                .transactionConfirmationUserMessage,
            TKLocales.MultichainSwap.Screen.Confirm.Error.signInternalError
        )
        XCTAssertEqual(
            MultichainTransactionFailure
                .failedToEstimateNonce(kind: .unknown, reason: "technical reason")
                .transactionConfirmationUserMessage,
            TKLocales.Multichain.Transaction.Error.failedToPrepare
        )
        XCTAssertEqual(
            MultichainTransactionFailure
                .failedToSendSigned(kind: .unknown, reason: "technical reason")
                .transactionConfirmationUserMessage,
            TKLocales.Multichain.Transaction.Error.failedToSend
        )
        XCTAssertEqual(
            MultichainTransactionFailure.unsupportedAsset(id: "eth/mainnet/asset/0x1")
                .transactionConfirmationUserMessage,
            TKLocales.Multichain.Transaction.Error.unsupportedAsset
        )
    }

    @MainActor
    func test_cancelledInitialFeeLoadDoesNotOverwriteRefreshedFees() async {
        let initialPlan = TestGate()
        let executionService = ConfirmationExecutionServiceSpy(
            executionPlanResults: [
                .success(makeExecutionPlan(fees: [networkFee()])),
                .success(makeExecutionPlan(fees: [networkFee(symbol: "TON", decimals: 9)])),
            ],
            executionPlanHolds: [initialPlan]
        )
        let viewModel = makeViewModel(executionService: executionService)

        viewModel.prepareExecutionPlan()
        await waitUntil {
            executionService.executionPlanCallCount == 1
        }
        let initialLoad = viewModel.refreshModel.refreshTask
        viewModel.selectSlippageBps(50)
        viewModel.updateQuote(freshQuote(route: makeRoute(routeId: "refreshed-route")))

        await waitUntil(timeout: 2) {
            viewModel.display.networkFeeMethod == "TON"
        }
        await initialPlan.open()
        await initialLoad?.value
        XCTAssertEqual(viewModel.display.networkFeeMethod, "TON")
    }

    @MainActor
    func test_screenQuoteChangesAfterACompletedSwapAreIgnored() async {
        let executionService = ConfirmationExecutionServiceSpy()
        let viewModel = makeViewModel(executionService: executionService)

        viewModel.prepareExecutionPlan()
        await waitUntil {
            executionService.executionPlanCallCount == 1 && viewModel.isConfirmEnabled
        }
        viewModel.confirm()
        viewModel.execute(signer: .mnemonic(passcodeProvider: { "passcode" }), consent: .refuse)
        await waitUntil {
            viewModel.executionState == .completed
        }

        viewModel.updateQuote(freshQuote(route: makeRoute(routeId: "refreshed-route")))
        await viewModel.refreshModel.refreshTask?.value

        XCTAssertEqual(viewModel.currentConfirmationInput.quoteState.route.routeId, "route")
        XCTAssertEqual(executionService.executionPlanCallCount, 1)
    }

    @MainActor
    func test_feeRowOffersTheRelayedMethodItPreselected() async {
        let executionService = ConfirmationExecutionServiceSpy(
            executionPlanResults: [
                .success(
                    makeExecutionPlan(
                        fees: [networkFee()],
                        feeOptions: [batteryOption(charges: 3), nativeOption()]
                    )
                ),
            ]
        )
        let viewModel = makeViewModel(executionService: executionService)

        viewModel.prepareExecutionPlan()
        await waitUntil { executionService.executionPlanCallCount == 1 && viewModel.isConfirmEnabled }

        XCTAssertEqual(viewModel.selectedFeeOption?.method, .battery)
        XCTAssertTrue(viewModel.display.canPickFeeMethod)
        XCTAssertEqual(
            viewModel.display.networkFeeMethod,
            TransactionConfirmationModel.ExtraType.battery.feeRowMethodTitle
        )
        XCTAssertTrue(viewModel.display.networkFeeValue.hasPrefix("3 "))
    }

    @MainActor
    func test_pickedFeeMethodIsTheOneExecuted() async {
        let executionService = ConfirmationExecutionServiceSpy(
            executionPlanResults: [
                .success(
                    makeExecutionPlan(
                        fees: [networkFee()],
                        feeOptions: [batteryOption(charges: 3), nativeOption()]
                    )
                ),
            ]
        )
        let viewModel = makeViewModel(executionService: executionService)

        viewModel.prepareExecutionPlan()
        await waitUntil { executionService.executionPlanCallCount == 1 && viewModel.isConfirmEnabled }

        viewModel.selectFeeOption(nativeOption())
        XCTAssertEqual(viewModel.selectedFeeOption?.method, .native)

        viewModel.confirm()
        viewModel.execute(signer: .mnemonic(passcodeProvider: { "1111" }), consent: .refuse)
        await waitUntil { executionService.executeCallCount == 1 && viewModel.executionState == .completed }

        XCTAssertEqual(executionService.feeMethods, [.native])
    }

    @MainActor
    func test_insufficientMethodOpensRefillInsteadOfBeingSelected() async {
        let executionService = ConfirmationExecutionServiceSpy(
            executionPlanResults: [
                .success(
                    makeExecutionPlan(
                        fees: [networkFee()],
                        feeOptions: [
                            batteryOption(charges: 3, isInsufficient: true),
                            nativeOption(),
                        ]
                    )
                ),
            ]
        )
        var refillRequests = 0
        let viewModel = makeViewModel(
            executionService: executionService,
            onRefillBattery: { _ in refillRequests += 1 }
        )

        viewModel.prepareExecutionPlan()
        await waitUntil { executionService.executionPlanCallCount == 1 && viewModel.isConfirmEnabled }

        XCTAssertEqual(viewModel.selectedFeeOption?.method, .native)

        viewModel.selectFeeOption(batteryOption(charges: 3, isInsufficient: true))

        XCTAssertEqual(refillRequests, 1)
        XCTAssertEqual(viewModel.selectedFeeOption?.method, .native)
    }

    @MainActor
    func test_insufficientNativeMethodOpensTheDeposit() async {
        let executionService = ConfirmationExecutionServiceSpy(
            executionPlanResults: [
                .success(
                    makeExecutionPlan(
                        fees: [networkFee()],
                        feeOptions: [
                            batteryOption(charges: 3, isInsufficient: true),
                            MultichainSwapFeeOption(cost: .native([networkFee()], isInsufficient: true)),
                        ]
                    )
                ),
            ]
        )
        var depositedAssetIds = [String]()
        let viewModel = makeViewModel(
            executionService: executionService,
            onDepositNativeFee: { depositedAssetIds.append($0.assetId) }
        )

        viewModel.prepareExecutionPlan()
        await waitUntil { executionService.executionPlanCallCount == 1 && viewModel.requiresBatteryTopUp }

        viewModel.selectFeeOption(
            MultichainSwapFeeOption(cost: .native([networkFee()], isInsufficient: true))
        )

        XCTAssertEqual(depositedAssetIds, [networkFee().asset.assetId])
    }

    /// The TRON send screen shows the relayer's instant fee as a GRAM amount, and the swap row has to
    /// read the same way for the same asset.
    @MainActor
    func test_gramFeeRowReadsLikeTheSendScreen() async {
        let executionService = ConfirmationExecutionServiceSpy(
            executionPlanResults: [
                .success(
                    makeExecutionPlan(
                        fees: [networkFee()],
                        feeOptions: [gramOption(), nativeOption()]
                    )
                ),
            ]
        )
        let viewModel = makeViewModel(executionService: executionService)

        viewModel.prepareExecutionPlan()
        await waitUntil { executionService.executionPlanCallCount == 1 && viewModel.isConfirmEnabled }

        XCTAssertEqual(viewModel.selectedFeeOption?.method, .gram)
        XCTAssertEqual(
            viewModel.display.networkFeeMethod,
            TransactionConfirmationModel.ExtraType.default.feeRowMethodTitle
        )
        XCTAssertTrue(viewModel.display.networkFeeValue.hasPrefix("≈ "), viewModel.display.networkFeeValue)
        XCTAssertFalse(
            viewModel.display.networkFeeValue.contains(MultichainAssetDetails.gram.symbol),
            viewModel.display.networkFeeValue
        )
    }

    /// GRAM is not charges, so an unaffordable row leads to a TON deposit rather than to the battery
    /// refill the charges row opens.
    @MainActor
    func test_insufficientGramOpensTheTonDeposit() async {
        let executionService = ConfirmationExecutionServiceSpy(
            executionPlanResults: [
                .success(
                    makeExecutionPlan(
                        fees: [networkFee()],
                        feeOptions: [gramOption(isInsufficient: true), nativeOption()]
                    )
                ),
            ]
        )
        var depositedAssetIds = [String]()
        var refillRequests = 0
        let viewModel = makeViewModel(
            executionService: executionService,
            onRefillBattery: { _ in refillRequests += 1 },
            onDepositNativeFee: { depositedAssetIds.append($0.assetId) }
        )

        viewModel.prepareExecutionPlan()
        await waitUntil { executionService.executionPlanCallCount == 1 && viewModel.isConfirmEnabled }

        viewModel.selectFeeOption(gramOption(isInsufficient: true))

        XCTAssertEqual(depositedAssetIds, [MultichainAssetDetails.gram.assetId])
        XCTAssertEqual(refillRequests, 0)
        XCTAssertEqual(viewModel.selectedFeeOption?.method, .native)
    }

    /// The chain's coin, short of the fee with no other method to pay it, keeps the row it had, and a tap on it
    /// opens the coin's deposit: a picker of the one method would only lead there.
    @MainActor
    func test_loneShortFeeMethodOpensItsDeposit() async {
        let shortage = MultichainNativeFeeShortage(asset: networkFee().asset, requiredAmount: networkFee().fee)
        let executionService = ConfirmationExecutionServiceSpy(
            executionPlanResults: [.failure(.insufficientNativeFee(shortage: shortage))]
        )
        var depositedAssetIds = [String]()
        var pickerCount = 0
        let viewModel = makeViewModel(
            executionService: executionService,
            onOpenFeePicker: { _ in pickerCount += 1 },
            onDepositNativeFee: { depositedAssetIds.append($0.assetId) }
        )

        viewModel.prepareExecutionPlan()
        await waitUntil { viewModel.display.isNetworkFeeShortage }
        let feeRow = MultichainSwapConfirmationViewStateMapper().map(viewModel).networkFee
        XCTAssertTrue(feeRow.isShortage)
        XCTAssertFalse(feeRow.canPickMethod)

        viewModel.tapFeeMethod()

        XCTAssertEqual(depositedAssetIds, [shortage.asset.assetId])
        XCTAssertEqual(pickerCount, 0)
    }

    @MainActor
    func test_nativeFeeShortageIsSilentWhileARelayedMethodPays() async {
        let executionService = ConfirmationExecutionServiceSpy(
            executionPlanResults: [
                .success(
                    makeExecutionPlan(
                        fees: [networkFee()],
                        feeOptions: [batteryOption(charges: 3), nativeOption()]
                    )
                ),
                .failure(
                    .insufficientNativeFee(
                        shortage: MultichainNativeFeeShortage(
                            asset: networkFee().asset,
                            requiredAmount: 1
                        )
                    )
                ),
            ]
        )
        var shortages = 0
        let viewModel = makeViewModel(
            executionService: executionService,
            onInsufficientNativeFee: { _ in shortages += 1 }
        )

        viewModel.prepareExecutionPlan()
        await waitUntil { executionService.executionPlanCallCount == 1 && viewModel.isConfirmEnabled }
        XCTAssertEqual(viewModel.selectedFeeOption?.method, .battery)

        viewModel.refreshFeeCalculationAfterDeposit()
        await waitUntil { executionService.executionPlanCallCount == 2 && !viewModel.isConfirmEnabled }

        XCTAssertEqual(shortages, 0)
        XCTAssertFalse(viewModel.display.isNetworkFeeShortage)
    }

    /// Battery holds 4 charges and gives 3 back: the swap costs 1, and the 3 are its temporary reserve.
    @MainActor
    func test_batteryRowSplitsTheHeldChargesIntoTheFeeAndTheReserve() async {
        let executionService = ConfirmationExecutionServiceSpy(
            executionPlanResults: [
                .success(
                    makeExecutionPlan(
                        fees: [networkFee()],
                        feeOptions: [batteryOption(charges: 4, excess: 3), nativeOption()]
                    )
                ),
            ]
        )
        let viewModel = makeViewModel(executionService: executionService)

        viewModel.prepareExecutionPlan()
        await waitUntil { executionService.executionPlanCallCount == 1 && viewModel.isConfirmEnabled }

        XCTAssertEqual(viewModel.selectedFeeOption?.method, .battery)
        XCTAssertEqual(viewModel.display.networkFeeValue, "1 \(TKLocales.Battery.Refill.chargesCount(count: 1))")
        XCTAssertEqual(
            viewModel.display.temporaryReserve?.value,
            "≈ 3 \(TKLocales.Battery.Refill.chargesCount(count: 3))"
        )
    }

    @MainActor
    func test_batteryRowKeepsQuietAboutARefundItCannotDistinguishFromTheCount() async {
        let executionService = ConfirmationExecutionServiceSpy(
            executionPlanResults: [
                .success(
                    makeExecutionPlan(
                        fees: [networkFee()],
                        feeOptions: [batteryOption(charges: 4, excess: 4), nativeOption()]
                    )
                ),
            ]
        )
        let viewModel = makeViewModel(executionService: executionService)

        viewModel.prepareExecutionPlan()
        await waitUntil { executionService.executionPlanCallCount == 1 && viewModel.isConfirmEnabled }

        XCTAssertNil(viewModel.display.temporaryReserve)
        XCTAssertEqual(viewModel.display.networkFeeValue, "4 \(TKLocales.Battery.Refill.chargesCount(count: 4))")
    }

    @MainActor
    func test_batteryConfirmsASwapTheChainCoinCannotPayFor() async {
        let executionService = ConfirmationExecutionServiceSpy(
            executionPlanResults: [
                .success(
                    makeExecutionPlan(
                        fees: [networkFee()],
                        feeOptions: [
                            batteryOption(charges: 3),
                            MultichainSwapFeeOption(cost: .native([networkFee()], isInsufficient: true)),
                        ]
                    )
                ),
            ]
        )
        var shortages = 0
        let viewModel = makeViewModel(
            executionService: executionService,
            onInsufficientNativeFee: { _ in shortages += 1 }
        )

        viewModel.prepareExecutionPlan()
        await waitUntil { executionService.executionPlanCallCount == 1 && viewModel.isConfirmEnabled }

        XCTAssertEqual(viewModel.selectedFeeOption?.method, .battery)
        XCTAssertTrue(viewModel.isConfirmEnabled)
        XCTAssertEqual(shortages, 0)
        XCTAssertFalse(
            viewModel.display.networkFeeSubtitle.contains(
                TKLocales.MultichainSwap.Screen.Confirm.NetworkFee.insufficientNativeToken("ETH")
            )
        )
    }

    @MainActor
    func test_confirmIsBlockedAndExplainedWhenNoMethodCanPay() async {
        let executionService = ConfirmationExecutionServiceSpy(
            executionPlanResults: [
                .success(
                    makeExecutionPlan(
                        fees: [networkFee()],
                        feeOptions: [
                            batteryOption(charges: 3, isInsufficient: true),
                            MultichainSwapFeeOption(cost: .native([networkFee()], isInsufficient: true)),
                        ]
                    )
                ),
            ]
        )
        let viewModel = makeViewModel(executionService: executionService)

        viewModel.prepareExecutionPlan()
        await waitUntil { executionService.executionPlanCallCount == 1 && viewModel.requiresBatteryTopUp }

        XCTAssertFalse(viewModel.isConfirmEnabled)
        XCTAssertEqual(
            viewModel.display.networkFeeSubtitle,
            TKLocales.MultichainSwap.Screen.Confirm.NetworkFee.notEnoughCharges("0")
        )
        XCTAssertTrue(viewModel.requiresBatteryTopUp)
        XCTAssertEqual(MultichainSwapConfirmationViewStateMapper().map(viewModel).action, .topUpBattery)
    }

    @MainActor
    func test_swapTapReportsTheNativeShortageOnceTheRelayedMethodIsGone() async {
        let shortage = MultichainNativeFeeShortage(
            asset: networkFee().asset,
            requiredAmount: networkFee().fee
        )
        let executionService = ConfirmationExecutionServiceSpy(
            executionPlanResults: [
                .success(
                    makeExecutionPlan(
                        fees: [networkFee()],
                        feeOptions: [
                            batteryOption(charges: 3),
                            MultichainSwapFeeOption(cost: .native([networkFee()], isInsufficient: true)),
                        ]
                    )
                ),
                .success(
                    makeExecutionPlan(
                        fees: [networkFee()],
                        feeOptions: [
                            MultichainSwapFeeOption(cost: .native([networkFee()], isInsufficient: true)),
                        ]
                    )
                ),
                .failure(.insufficientNativeFee(shortage: shortage)),
            ]
        )
        var shortages = [MultichainNativeFeeShortage]()
        let viewModel = makeViewModel(
            executionService: executionService,
            onInsufficientNativeFee: { shortages.append($0) }
        )

        viewModel.prepareExecutionPlan()
        await waitUntil { executionService.executionPlanCallCount == 1 && viewModel.isConfirmEnabled }
        XCTAssertEqual(viewModel.selectedFeeOption?.method, .battery)
        XCTAssertTrue(shortages.isEmpty)

        // A plan that no longer offers the relayed method really does leave nothing paying.
        viewModel.refreshFeeCalculationAfterDeposit()
        await waitUntil { viewModel.selectedFeeOption?.method == .native }
        XCTAssertTrue(shortages.isEmpty)

        viewModel.confirm()

        XCTAssertEqual(shortages, [shortage])

        viewModel.refreshFeeCalculationAfterDeposit()
        await waitUntil { executionService.executionPlanCallCount == 3 && viewModel.selectedFeeOption == nil }
        viewModel.confirm()

        XCTAssertEqual(shortages, [shortage, shortage])
        XCTAssertFalse(viewModel.isConfirmEnabled)
        XCTAssertTrue(viewModel.isSwapEnabled)
    }

    /// A tap before the fee is priced is taken rather than refused, the way the swap screen's button
    /// takes it, and the swap goes on as soon as the plan arrives.
    @MainActor
    func test_swapTappedBeforeTheFeeIsPricedWaitsForThePlan() async {
        let plan = TestGate()
        let executionService = ConfirmationExecutionServiceSpy(
            executionPlanResults: [.success(makeExecutionPlan(fees: [networkFee()]))],
            executionPlanHolds: [plan]
        )
        var confirmCount = 0
        let viewModel = makeViewModel(
            executionService: executionService,
            onConfirm: { confirmCount += 1 }
        )

        viewModel.prepareExecutionPlan()

        XCTAssertTrue(viewModel.isSwapEnabled)
        XCTAssertFalse(viewModel.isConfirmEnabled)

        viewModel.confirm()
        viewModel.confirm()

        XCTAssertTrue(viewModel.isConfirmPending)
        XCTAssertEqual(
            MultichainSwapConfirmationViewStateMapper().map(viewModel).action,
            .swap(isEnabled: true, isLoading: true)
        )
        XCTAssertEqual(confirmCount, 0)
        await plan.open()
        await waitUntil { confirmCount == 1 }
        XCTAssertFalse(viewModel.isConfirmPending)
        XCTAssertEqual(executionService.executionPlanCallCount, 1)
    }

    /// Waiting holds the swap screen's quote, so a tap with no plan on its way would wait for good: it asks
    /// for the plan itself, such as after a refresh that ended without one while a relayed method paid.
    @MainActor
    func test_swapTappedWithNoPlanOnItsWayAsksForOne() async {
        let executionService = ConfirmationExecutionServiceSpy(
            executionPlanResults: [
                .success(makeExecutionPlan(fees: [networkFee()], feeOptions: [batteryOption(charges: 3), nativeOption()])),
                .failure(
                    .insufficientNativeFee(
                        shortage: MultichainNativeFeeShortage(asset: networkFee().asset, requiredAmount: 1)
                    )
                ),
                .success(makeExecutionPlan(fees: [networkFee()], feeOptions: [batteryOption(charges: 3), nativeOption()])),
            ]
        )
        var confirmCount = 0
        let viewModel = makeViewModel(
            executionService: executionService,
            onConfirm: { confirmCount += 1 }
        )
        viewModel.prepareExecutionPlan()
        await waitUntil { viewModel.isConfirmEnabled }
        viewModel.refreshFeeCalculationAfterDeposit()
        await waitUntil { executionService.executionPlanCallCount == 2 && !viewModel.isConfirmEnabled }
        XCTAssertTrue(viewModel.isSwapEnabled)

        viewModel.confirm()

        XCTAssertTrue(viewModel.isConfirmPending)
        await waitUntil { confirmCount == 1 }
        XCTAssertEqual(executionService.executionPlanCallCount, 3)
    }

    /// A Swap tap waiting for its plan goes on to the passcode once the plan arrives, so the slippage, which
    /// would bring another quote, holds still meanwhile.
    @MainActor
    func test_slippageHoldsStillWhileASwapTapWaitsForItsPlan() {
        var reportedSlippage = [Int]()
        let viewModel = makeViewModel(onSlippageChange: { reportedSlippage.append($0) })

        viewModel.confirmWhenReady()
        viewModel.selectSlippageBps(50)

        XCTAssertFalse(viewModel.canSelectSlippage)
        XCTAssertEqual(viewModel.selectedSlippageBps, 100)
        XCTAssertEqual(reportedSlippage, [])
    }

    /// The quote already on screen only restarts the countdown; a refresh holds the swap until the next
    /// quote arrives, and that one is priced again.
    @MainActor
    func test_swapWaitsWhileTheScreenQuoteRefreshes() async {
        let executionService = ConfirmationExecutionServiceSpy(
            executionPlanResults: [
                .success(makeExecutionPlan(fees: [networkFee()])),
                .success(makeExecutionPlan(routeId: "refreshed-route", fees: [networkFee()])),
            ]
        )
        let viewModel = makeViewModel(executionService: executionService)

        viewModel.prepareExecutionPlan()
        await waitUntil { viewModel.isConfirmEnabled }

        let restartedCycle = MultichainSwapQuoteRefreshCycle(startDate: Date(), duration: 30)
        viewModel.updateQuote(.ready(viewModel.currentConfirmationInput, restartedCycle))

        XCTAssertEqual(viewModel.quoteStatus, .ready(restartedCycle))
        XCTAssertTrue(viewModel.isConfirmEnabled)
        XCTAssertEqual(executionService.executionPlanCallCount, 1)

        viewModel.updateQuote(.loading)

        XCTAssertEqual(viewModel.quoteStatus, .loading)
        XCTAssertFalse(viewModel.isSwapEnabled)

        viewModel.updateQuote(freshQuote(route: makeRoute(routeId: "refreshed-route")))

        XCTAssertTrue(viewModel.isSwapEnabled)
        await waitUntil { viewModel.isConfirmEnabled }
        XCTAssertEqual(executionService.executionPlanCallCount, 2)
    }

    /// A swap on its way holds the swap screen's quote, with no gap from the tap to the send, until it
    /// ends: backed out of, or canceled at the passcode.
    @MainActor
    func test_aSwapOnItsWayHoldsTheScreenQuoteUntilItEnds() async {
        let plan = TestGate()
        let executionService = ConfirmationExecutionServiceSpy(
            executionPlanResults: [.success(makeExecutionPlan(fees: [networkFee()]))],
            executionPlanHolds: [plan],
            executeResult: .failure(.canceled)
        )
        var inFlightChanges = [Bool]()
        var confirmCount = 0
        let viewModel = makeViewModel(
            executionService: executionService,
            onConfirm: { confirmCount += 1 },
            onSwapInFlightChange: { inFlightChanges.append($0) }
        )

        viewModel.prepareExecutionPlan()
        viewModel.confirm()
        await plan.open()
        await waitUntil { confirmCount == 1 }

        XCTAssertEqual(inFlightChanges, [true])

        viewModel.cancelConfirm()

        XCTAssertEqual(inFlightChanges, [true, false])

        viewModel.confirm()
        viewModel.execute(signer: .mnemonic(passcodeProvider: { nil }), consent: .refuse)
        await waitUntil { inFlightChanges.count == 4 }

        XCTAssertEqual(inFlightChanges, [true, false, true, false])
        XCTAssertEqual(viewModel.executionState, .idle)
    }

    /// The sheet's button tops the battery up itself, so the battery popup comes only from a swap tapped on
    /// the swap screen, naming the battery beside the chain's coin.
    @MainActor
    func test_batteryShortageOpensFromASwapTappedOnTheSwapScreen() async {
        let executionService = ConfirmationExecutionServiceSpy(
            executionPlanResults: [
                .success(
                    makeExecutionPlan(
                        fees: [networkFee()],
                        feeOptions: [
                            batteryOption(charges: 3, isInsufficient: true),
                            MultichainSwapFeeOption(cost: .native([networkFee()], isInsufficient: true)),
                        ]
                    )
                ),
            ]
        )
        var shortages = [MultichainNativeFeeShortage]()
        var unavailableCount = 0
        let viewModel = makeViewModel(
            executionService: executionService,
            onConfirmUnavailable: { unavailableCount += 1 },
            onBatteryFeeShortage: { shortages.append($0) }
        )

        viewModel.prepareExecutionPlan()
        await waitUntil { viewModel.requiresBatteryTopUp }

        XCTAssertTrue(shortages.isEmpty)

        viewModel.confirmWhenReady()

        XCTAssertEqual(shortages.map(\.asset.symbol), ["ETH"])
        XCTAssertEqual(shortages.first?.requiredAmount, networkFee().fee)
        XCTAssertEqual(unavailableCount, 0)
        XCTAssertFalse(viewModel.isConfirmPending)
    }

    /// A plan that names the coin it falls short of, as `/v3` does beside a relayed method, has the battery
    /// popup ask for all of it: the fee and the coin the swap sends besides, which the native option leaves out.
    @MainActor
    func test_batteryShortageAsksForTheCoinThePlanFallsShortOf() async {
        var plan = makeExecutionPlan(
            fees: [networkFee()],
            feeOptions: [
                batteryOption(charges: 3, isInsufficient: true),
                MultichainSwapFeeOption(cost: .native([networkFee()], isInsufficient: true)),
            ]
        )
        plan.nativeFeeShortage = MultichainNativeFeeShortage(asset: networkFee().asset, requiredAmount: networkFee().fee + 80_000_001)
        var shortages = [MultichainNativeFeeShortage]()
        let viewModel = makeViewModel(
            executionService: ConfirmationExecutionServiceSpy(executionPlanResults: [.success(plan)]),
            onBatteryFeeShortage: { shortages.append($0) }
        )

        viewModel.prepareExecutionPlan()
        await waitUntil { viewModel.requiresBatteryTopUp }
        viewModel.confirmWhenReady()

        XCTAssertEqual(shortages.map(\.requiredAmount), [networkFee().fee + 80_000_001])
    }

    @MainActor
    func test_batteryShortageStaysSilentWhileAMethodCanPay() async {
        let executionService = ConfirmationExecutionServiceSpy(
            executionPlanResults: [
                .success(
                    makeExecutionPlan(
                        fees: [networkFee()],
                        feeOptions: [
                            batteryOption(charges: 3),
                            MultichainSwapFeeOption(cost: .native([networkFee()], isInsufficient: true)),
                        ]
                    )
                ),
            ]
        )
        var shortages = [MultichainNativeFeeShortage]()
        let viewModel = makeViewModel(
            executionService: executionService,
            onBatteryFeeShortage: { shortages.append($0) }
        )

        viewModel.prepareExecutionPlan()
        await waitUntil { executionService.executionPlanCallCount == 1 && viewModel.isConfirmEnabled }

        XCTAssertTrue(shortages.isEmpty)
        XCTAssertTrue(viewModel.isConfirmEnabled)
    }

    @MainActor
    func test_unknownRelayOutcomeBlocksARetry() async {
        let executionService = ConfirmationExecutionServiceSpy(
            executionPlanResults: [
                .success(
                    makeExecutionPlan(
                        fees: [networkFee()],
                        feeOptions: [batteryOption(charges: 3), nativeOption()]
                    )
                ),
            ],
            executeResult: .failure(
                .broadcastFailed(payloadId: "main", kind: .unknown, reason: "relay did not answer")
            )
        )
        var retryableFailures = [Bool]()
        let viewModel = makeViewModel(
            executionService: executionService,
            onExecutionFailed: { _, canRetry in retryableFailures.append(canRetry) }
        )

        viewModel.prepareExecutionPlan()
        await waitUntil { executionService.executionPlanCallCount == 1 && viewModel.isConfirmEnabled }
        XCTAssertEqual(viewModel.selectedFeeOption?.method, .battery)

        viewModel.confirm()
        viewModel.execute(signer: .mnemonic(passcodeProvider: { "1111" }), consent: .refuse)
        await waitUntil { executionService.executeCallCount == 1 && !retryableFailures.isEmpty }

        XCTAssertFalse(viewModel.isConfirmEnabled)
        XCTAssertEqual(retryableFailures, [false])
        XCTAssertEqual(
            MultichainSwapConfirmationViewStateMapper().map(viewModel).action,
            .sendFailed(TKLocales.MultichainSwap.Screen.Confirm.Error.statusUnknown)
        )
    }

    /// A relayer that refused for lack of funds took nothing, so the swap says so and can go again.
    @MainActor
    func test_relayRefusedForLackOfFundsStaysRetryable() async {
        let executionService = ConfirmationExecutionServiceSpy(
            executionPlanResults: [
                .success(
                    makeExecutionPlan(
                        fees: [networkFee()],
                        feeOptions: [batteryOption(charges: 3), nativeOption()]
                    )
                ),
            ],
            executeResult: .failure(
                .broadcastRefused(payloadId: "main", kind: .insufficientBalance, reason: "battery relay rejected the swap")
            )
        )
        var failureMessages = [String]()
        var retryableFailures = [Bool]()
        let viewModel = makeViewModel(
            executionService: executionService,
            onExecutionFailed: { message, canRetry in
                failureMessages.append(message)
                retryableFailures.append(canRetry)
            }
        )

        viewModel.prepareExecutionPlan()
        await waitUntil { executionService.executionPlanCallCount == 1 && viewModel.isConfirmEnabled }
        XCTAssertEqual(viewModel.selectedFeeOption?.method, .battery)

        viewModel.confirm()
        viewModel.execute(signer: .mnemonic(passcodeProvider: { "1111" }), consent: .refuse)
        await waitUntil { !retryableFailures.isEmpty }

        XCTAssertEqual(retryableFailures, [true])
        XCTAssertEqual(failureMessages, [TKLocales.MultichainSwap.Screen.Confirm.Error.insufficientBalance])
        XCTAssertFalse(viewModel.isRetryUnsafe)
    }

    @MainActor
    func test_failedNativeSwapStaysRetryable() async {
        let executionService = ConfirmationExecutionServiceSpy(
            executionPlanResults: [
                .success(makeExecutionPlan(fees: [networkFee()], feeOptions: [nativeOption()])),
            ],
            executeResult: .failure(
                .broadcastFailed(payloadId: "main", kind: .unknown, reason: "node rejected")
            )
        )
        var refreshRequests = 0
        var retryableFailures = [Bool]()
        let viewModel = makeViewModel(
            executionService: executionService,
            onRefreshQuote: { refreshRequests += 1 },
            onExecutionFailed: { _, canRetry in retryableFailures.append(canRetry) }
        )

        viewModel.prepareExecutionPlan()
        await waitUntil { executionService.executionPlanCallCount == 1 && viewModel.isConfirmEnabled }

        viewModel.confirm()
        viewModel.execute(signer: .mnemonic(passcodeProvider: { "1111" }), consent: .refuse)
        await waitUntil { executionService.executeCallCount == 1 }
        await waitUntil { refreshRequests == 1 }
        XCTAssertEqual(retryableFailures, [true])

        viewModel.updateQuote(freshQuote(route: makeRoute(), quoteId: "refreshed-quote"))
        await waitUntil { viewModel.isConfirmEnabled }
    }

    /// A shortage of the chain's coin found only at sending outranks the plan that priced the coin as paying:
    /// the fee row names it in red while the coin stays selected, as every Swap tap now opens its deposit.
    @MainActor
    func test_coinShortageFoundAtSendingShowsOnTheFeeRow() async {
        let shortage = MultichainNativeFeeShortage(asset: networkFee().asset, requiredAmount: networkFee().fee)
        let executionService = ConfirmationExecutionServiceSpy(
            executionPlanResults: [
                .success(makeExecutionPlan(fees: [networkFee()], feeOptions: [nativeOption()])),
            ],
            executeResult: .failure(.insufficientNativeFee(shortage: shortage))
        )
        var shortages = [MultichainNativeFeeShortage]()
        let viewModel = makeViewModel(
            executionService: executionService,
            onInsufficientNativeFee: { shortages.append($0) }
        )

        viewModel.prepareExecutionPlan()
        await waitUntil { viewModel.isConfirmEnabled }
        XCTAssertFalse(viewModel.display.isNetworkFeeShortage)

        viewModel.confirm()
        viewModel.execute(signer: .mnemonic(passcodeProvider: { "1111" }), consent: .refuse)
        await waitUntil { shortages == [shortage] }

        XCTAssertEqual(viewModel.selectedFeeOption?.method, .native)
        XCTAssertTrue(viewModel.display.isNetworkFeeShortage)
        XCTAssertEqual(
            viewModel.display.networkFeeSubtitle,
            TKLocales.MultichainSwap.Screen.Confirm.NetworkFee.notEnough("ETH")
        )
    }

    @MainActor
    func test_refreshedPlanDropsAFeeMethodItNoLongerOffers() async {
        let executionService = ConfirmationExecutionServiceSpy(
            executionPlanResults: [
                .success(
                    makeExecutionPlan(
                        fees: [networkFee()],
                        feeOptions: [batteryOption(charges: 3), nativeOption()]
                    )
                ),
                .success(
                    makeExecutionPlan(fees: [networkFee()], feeOptions: [nativeOption()])
                ),
            ]
        )
        let viewModel = makeViewModel(executionService: executionService)

        viewModel.prepareExecutionPlan()
        await waitUntil { executionService.executionPlanCallCount == 1 && viewModel.isConfirmEnabled }
        XCTAssertEqual(viewModel.selectedFeeOption?.method, .battery)
        viewModel.selectFeeOption(batteryOption(charges: 3))

        viewModel.refreshFeeCalculationAfterDeposit()
        await waitUntil { executionService.executionPlanCallCount == 2 && viewModel.selectedFeeOption?.method == .native }

        XCTAssertEqual(viewModel.selectedFeeOption?.method, .native)
        XCTAssertEqual(viewModel.selectedFeeMethod, .native)
        XCTAssertFalse(viewModel.display.canPickFeeMethod)
    }

    /// The picker hands back the row that was tapped, and the swap has to resolve it to the same
    /// method — not to whatever sat at that position in the list the picker was built from.
    @MainActor
    func test_feePickerRowsAreIdentifiedByTheirFeeMethod() async {
        let executionService = ConfirmationExecutionServiceSpy(
            executionPlanResults: [
                .success(
                    makeExecutionPlan(
                        fees: [networkFee()],
                        feeOptions: [batteryOption(charges: 3), nativeOption()]
                    )
                ),
            ]
        )
        var presentation: NetworkFeePickerPresentation?
        let viewModel = makeViewModel(
            executionService: executionService,
            onOpenFeePicker: { presentation = $0 }
        )

        viewModel.prepareExecutionPlan()
        await waitUntil { executionService.executionPlanCallCount == 1 && viewModel.isConfirmEnabled }
        XCTAssertEqual(viewModel.selectedFeeMethod, .battery)

        viewModel.tapFeeMethod()
        let items = (presentation?.dataSource as? any NetworkFeePickerItemsDataSource)?.items ?? []
        XCTAssertEqual(items.map(\.id), ["battery", "native"])

        guard let nativeItem = items.first(where: { $0.id == "native" }) else {
            return XCTFail("expected a row for the chain's own coin")
        }
        presentation?.didSelectItem(nativeItem, nil)

        XCTAssertEqual(viewModel.selectedFeeMethod, .native)
    }

    /// A picker row names its method as the fee row does and prices what it pays: the battery's charges
    /// with what it has, the coin by its amount after the fiat value.
    @MainActor
    func test_feePickerRowsNameTheMethodAndWhatItPays() async {
        let executionService = ConfirmationExecutionServiceSpy(
            executionPlanResults: [
                .success(
                    makeExecutionPlan(
                        fees: [networkFee()],
                        feeOptions: [
                            MultichainSwapFeeOption(
                                cost: .batteryCharges(count: 28, excess: 21, isInsufficient: false),
                                availableCharges: 771
                            ),
                            nativeOption(),
                        ]
                    )
                ),
            ]
        )
        var presentation: NetworkFeePickerPresentation?
        let viewModel = makeViewModel(
            sendAsset: asset(symbol: "ETH", decimals: 18, usdPrice: 2000),
            executionService: executionService,
            onOpenFeePicker: { presentation = $0 }
        )

        viewModel.prepareExecutionPlan()
        await waitUntil { executionService.executionPlanCallCount == 1 && viewModel.isConfirmEnabled }
        viewModel.tapFeeMethod()
        let items = (presentation?.dataSource as? any NetworkFeePickerItemsDataSource)?.items ?? []

        guard items.count == 2,
              case let .titled(batteryTitle, batterySubtitle) = items[0].text,
              case let .titled(coinTitle, coinSubtitle) = items[1].text
        else {
            return XCTFail("expected a titled row for each method")
        }
        XCTAssertEqual(batteryTitle, TKLocales.Settings.Items.battery)
        XCTAssertEqual(
            batterySubtitle,
            "7 \(TKLocales.Battery.Refill.chargesCount(count: 7)) · "
                + TKLocales.MultichainSwap.Screen.Confirm.FeePicker.available("771")
        )
        XCTAssertEqual(coinTitle, "ETH")
        XCTAssertTrue(coinSubtitle.hasPrefix("≈ $"), coinSubtitle)
        XCTAssertTrue(coinSubtitle.hasSuffix(" · 0.0021 ETH"), coinSubtitle)
    }

    /// A refresh that produced no plan knows nothing about what can pay, so it must not drop an
    /// explicit pick: the next plan offers battery first and would otherwise silently take the swap
    /// back off the chain's own coin.
    @MainActor
    func test_planlessRefreshKeepsAnExplicitFeeMethodPick() async {
        let executionService = ConfirmationExecutionServiceSpy(
            executionPlanResults: [
                .success(
                    makeExecutionPlan(
                        fees: [networkFee()],
                        feeOptions: [batteryOption(charges: 3), nativeOption()]
                    )
                ),
                .failure(.preparationFailed(kind: .networkError, reason: "no route")),
                .success(
                    makeExecutionPlan(
                        fees: [networkFee()],
                        feeOptions: [batteryOption(charges: 3), nativeOption()]
                    )
                ),
            ]
        )
        let viewModel = makeViewModel(executionService: executionService)

        viewModel.prepareExecutionPlan()
        await waitUntil { executionService.executionPlanCallCount == 1 && viewModel.isConfirmEnabled }
        viewModel.selectFeeOption(nativeOption())
        XCTAssertEqual(viewModel.selectedFeeMethod, .native)

        viewModel.refreshFeeCalculationAfterDeposit()
        await waitUntil { executionService.executionPlanCallCount == 2 && !viewModel.isConfirmEnabled }

        viewModel.refreshFeeCalculationAfterDeposit()
        await waitUntil { executionService.executionPlanCallCount == 3 && viewModel.isConfirmEnabled }

        XCTAssertEqual(viewModel.selectedFeeMethod, .native)
        XCTAssertEqual(viewModel.selectedFeeOption?.method, .native)
    }

    @MainActor
    func test_routePayloadShapeRefreshesKeepAnExplicitBatteryPick() async {
        let options = [nativeOption(), batteryOption(charges: 3)]
        let executionService = ConfirmationExecutionServiceSpy(
            executionPlanResults: [
                .success(makeExecutionPlan(routeId: "ton-boc", fees: [networkFee()], feeOptions: options)),
                .success(makeExecutionPlan(
                    routeId: "alt-vm-deposit",
                    fees: [networkFee()],
                    feeOptions: [nativeOption(), batteryOption(charges: 5)]
                )),
                .success(makeExecutionPlan(routeId: "ton-boc-again", fees: [networkFee()], feeOptions: options)),
            ]
        )
        let viewModel = makeViewModel(executionService: executionService)

        viewModel.prepareExecutionPlan()
        await waitUntil { executionService.executionPlanCallCount == 1 && viewModel.isConfirmEnabled }
        viewModel.selectFeeOption(nativeOption())
        viewModel.selectFeeOption(batteryOption(charges: 3))

        viewModel.refreshFeeCalculationAfterDeposit()
        await waitUntil {
            executionService.executionPlanCallCount == 2
                && viewModel.display.networkFeeValue == "5 \(TKLocales.Battery.Refill.chargesCount(count: 5))"
        }
        XCTAssertEqual(viewModel.selectedFeeMethod, .battery)
        XCTAssertTrue(viewModel.display.canPickFeeMethod)

        viewModel.refreshFeeCalculationAfterDeposit()
        await waitUntil {
            executionService.executionPlanCallCount == 3
                && viewModel.display.networkFeeValue == "3 \(TKLocales.Battery.Refill.chargesCount(count: 3))"
        }
        XCTAssertEqual(viewModel.selectedFeeMethod, .battery)
        XCTAssertTrue(viewModel.display.canPickFeeMethod)
    }

    @MainActor
    func test_routePayloadShapeRefreshesKeepAnExplicitNativePick() async {
        let options = [batteryOption(charges: 3), nativeOption()]
        let executionService = ConfirmationExecutionServiceSpy(
            executionPlanResults: [
                .success(makeExecutionPlan(routeId: "ton-boc", fees: [networkFee()], feeOptions: options)),
                .success(makeExecutionPlan(
                    routeId: "alt-vm-deposit",
                    fees: [networkFee(symbol: "BNB")],
                    feeOptions: [batteryOption(charges: 3), nativeOption(fees: [networkFee(symbol: "BNB")])]
                )),
                .success(makeExecutionPlan(routeId: "ton-boc-again", fees: [networkFee()], feeOptions: options)),
            ]
        )
        let viewModel = makeViewModel(executionService: executionService)

        viewModel.prepareExecutionPlan()
        await waitUntil { executionService.executionPlanCallCount == 1 && viewModel.isConfirmEnabled }
        viewModel.selectFeeOption(nativeOption())

        viewModel.refreshFeeCalculationAfterDeposit()
        await waitUntil { executionService.executionPlanCallCount == 2 && viewModel.display.networkFeeMethod == "BNB" }
        XCTAssertEqual(viewModel.selectedFeeMethod, .native)
        XCTAssertTrue(viewModel.display.canPickFeeMethod)

        viewModel.refreshFeeCalculationAfterDeposit()
        await waitUntil { executionService.executionPlanCallCount == 3 && viewModel.display.networkFeeMethod == "ETH" }
        XCTAssertEqual(viewModel.selectedFeeMethod, .native)
        XCTAssertTrue(viewModel.display.canPickFeeMethod)
    }

    /// The fee row and the confirmation ask for the same route at once: it is prepared once, and an ask
    /// after that reads the plan already prepared.
    @MainActor
    func test_planProviderPreparesARouteOnceForEveryoneWhoAsks() async throws {
        let plan = TestGate()
        let executionService = ConfirmationExecutionServiceSpy(
            executionPlanResults: [.success(makeExecutionPlan(fees: [networkFee()]))],
            executionPlanHolds: [plan]
        )
        let provider = MultichainSwapPlanProvider(swapWallet: makeSwapWallet(), executionService: executionService)
        let input = makeInput()

        async let rowPlan = provider.plan(
            sourceAsset: input.userInput.sendAsset,
            destinationAsset: input.userInput.receiveAsset,
            route: input.quoteState.route
        )
        async let sheetPlan = provider.plan(
            sourceAsset: input.userInput.sendAsset,
            destinationAsset: input.userInput.receiveAsset,
            route: input.quoteState.route
        )
        await waitUntil { executionService.executionPlanCallCount == 1 }
        await plan.open()
        _ = try await(rowPlan, sheetPlan)
        _ = try await provider.plan(
            sourceAsset: input.userInput.sendAsset,
            destinationAsset: input.userInput.receiveAsset,
            route: input.quoteState.route
        )

        XCTAssertEqual(executionService.executionPlanCallCount, 1)
    }

    /// A failure other than the coin falling short of the fee is not kept: the next ask prepares the route
    /// again. A deposit prepares it again anyway, and the asks after it read the new plan.
    @MainActor
    func test_planProviderPreparesAgainAfterAFailureAndOnRequest() async throws {
        let executionService = ConfirmationExecutionServiceSpy(
            executionPlanResults: [
                .failure(.internal(reason: "unavailable")),
                .success(makeExecutionPlan(fees: [networkFee()], feeOptions: [batteryOption(isInsufficient: true)])),
                .success(makeExecutionPlan(fees: [networkFee()], feeOptions: [batteryOption()])),
            ]
        )
        let provider = MultichainSwapPlanProvider(swapWallet: makeSwapWallet(), executionService: executionService)
        let input = makeInput()
        func plan(reusingPrepared: Bool = true) async throws(MultichainSwapExecutionFailure) -> MultichainSwapExecutionPlan {
            try await provider.plan(
                sourceAsset: input.userInput.sendAsset,
                destinationAsset: input.userInput.receiveAsset,
                route: input.quoteState.route,
                reusingPrepared: reusingPrepared
            )
        }

        do {
            _ = try await plan()
            XCTFail("Expected the first preparation to fail")
        } catch {}
        let shortPlan = try await plan()
        let depositPlan = try await plan(reusingPrepared: false)
        let readPlan = try await plan()

        XCTAssertEqual(shortPlan.feeOptions.first?.isInsufficient, true)
        XCTAssertEqual(depositPlan.feeOptions.first?.isInsufficient, false)
        XCTAssertEqual(readPlan.feeOptions.first?.isInsufficient, false)
        XCTAssertEqual(executionService.executionPlanCallCount, 3)
    }

    /// A route asked for after it expired is prepared again rather than read back, so the preparation can report
    /// it expired, as for a swap held on the price impact warning past its route's expiry.
    @MainActor
    func test_planProviderPreparesAnExpiredRouteAgain() async throws {
        let executionService = ConfirmationExecutionServiceSpy(
            executionPlanResults: [.success(makeExecutionPlan(fees: [networkFee()]))]
        )
        let provider = MultichainSwapPlanProvider(swapWallet: makeSwapWallet(), executionService: executionService)
        let input = makeInput(route: makeRoute(dateExpire: Date().addingTimeInterval(-1)))

        for _ in 0 ..< 2 {
            _ = try await provider.plan(
                sourceAsset: input.userInput.sendAsset,
                destinationAsset: input.userInput.receiveAsset,
                route: input.quoteState.route
            )
        }

        XCTAssertEqual(executionService.executionPlanCallCount, 2)
    }

    /// The pricing details hold a plan whose operation stopped being signed while its route lives on: Swap does
    /// not send it, but prepares the route again and confirms the plan that brings.
    @MainActor
    func test_aSwapTappedPastItsOperationsDeadlinePreparesTheRouteAgain() async throws {
        let input = makeInput()
        let executionService = try ConfirmationExecutionServiceSpy(
            executionPlanResults: [
                .success(makeOperationPlan(preparing: input.quoteState.route, expiresAt: Date().addingTimeInterval(-1))),
                .success(makeOperationPlan(preparing: input.quoteState.route)),
            ]
        )
        var confirmCount = 0
        let viewModel = makeViewModel(input: input, executionService: executionService, onConfirm: { confirmCount += 1 })

        viewModel.prepareExecutionPlan()
        await waitUntil { viewModel.isConfirmEnabled }
        viewModel.confirm()

        await waitUntil { confirmCount == 1 }
        XCTAssertEqual(executionService.executionPlanCallCount, 2)
    }

    /// The operation `/v3` built for a route can stop being signed before the route expires: a route asked for
    /// past that is prepared again rather than read back with an operation that would fail as expired.
    @MainActor
    func test_planProviderPreparesARouteAgainOnceItsOperationExpired() async throws {
        let input = makeInput()
        let executionService = try ConfirmationExecutionServiceSpy(
            executionPlanResults: [
                .success(makeOperationPlan(preparing: input.quoteState.route, expiresAt: Date().addingTimeInterval(-1))),
                .success(makeOperationPlan(preparing: input.quoteState.route)),
            ]
        )
        let provider = MultichainSwapPlanProvider(swapWallet: makeSwapWallet(), executionService: executionService)
        func plan() async throws(MultichainSwapExecutionFailure) -> MultichainSwapExecutionPlan {
            try await provider.plan(
                sourceAsset: input.userInput.sendAsset,
                destinationAsset: input.userInput.receiveAsset,
                route: input.quoteState.route
            )
        }

        _ = try await plan()
        let fresh = try await plan()
        _ = try await plan()

        XCTAssertGreaterThan(try XCTUnwrap(fresh.expiresAt), Date())
        XCTAssertEqual(executionService.executionPlanCallCount, 2)
    }

    /// The fee row found the chain's coin short of the fee: the pricing details open with that fee instead of
    /// estimating it again, and a deposit still prepares the route again.
    @MainActor
    func test_pricingDetailsOpenWithTheCoinShortageTheFeeRowFound() async {
        let shortage = MultichainNativeFeeShortage(
            asset: asset(symbol: "ETH", decimals: 18).asset,
            requiredAmount: BigUInt(2_100_000_000_000_000)
        )
        let executionService = ConfirmationExecutionServiceSpy(
            executionPlanResults: [
                .failure(.insufficientNativeFee(shortage: shortage)),
                .success(makeExecutionPlan(fees: [networkFee()], feeOptions: [nativeOption()])),
            ]
        )
        let planProvider = MultichainSwapPlanProvider(swapWallet: makeSwapWallet(), executionService: executionService)
        let input = makeInput()
        do {
            _ = try await planProvider.plan(
                sourceAsset: input.userInput.sendAsset,
                destinationAsset: input.userInput.receiveAsset,
                route: input.quoteState.route
            )
            XCTFail("Expected the coin to fall short of the fee")
        } catch {}
        let viewModel = makeViewModel(input: input, executionService: executionService, planProvider: planProvider)

        viewModel.prepareExecutionPlan()
        await waitUntil { viewModel.display.isNetworkFeeShortage }
        XCTAssertEqual(executionService.executionPlanCallCount, 1)

        viewModel.refreshFeeCalculationAfterDeposit()
        await waitUntil { viewModel.isConfirmEnabled }
        XCTAssertFalse(viewModel.display.isNetworkFeeShortage)
        XCTAssertEqual(executionService.executionPlanCallCount, 2)
    }
}

private extension MultichainSwapConfirmationViewModelTests {
    @MainActor
    func makeViewModel(
        sendAsset: MultichainAsset? = nil,
        receiveAsset: MultichainAsset? = nil,
        input: MultichainSwapConfirmationInput? = nil,
        executionService: ConfirmationExecutionServiceSpy = ConfirmationExecutionServiceSpy(),
        planProvider: MultichainSwapPlanProvider? = nil,
        swapService: ConfirmationSwapServiceSpy = ConfirmationSwapServiceSpy(),
        slippageService: (any MultichainSwapSlippageService)? = TestSlippageService(optionsBps: [50, 100]),
        routeRecovery: MultichainSwapRouteRecovery = .instantLadder,
        onConfirm: @escaping () -> Void = {},
        onPriceChanged: @escaping (String) -> Void = { _ in },
        onConfirmUnavailable: @escaping () -> Void = {},
        onSwapInFlightChange: @escaping (Bool) -> Void = { _ in },
        onRefreshQuote: @escaping () -> Void = {},
        onQuoteRecovered: @escaping (MultichainSwapConfirmationQuoteState) -> Void = { _ in },
        onSlippageChange: @escaping (Int) -> Void = { _ in },
        onExecutionCompleted: @escaping (
            MultichainSwapConfirmationInput,
            MultichainSwapFeeMethod,
            MultichainSwapExecutionResult
        ) -> Void = { _, _, _ in },
        onExecutionFailed: @escaping (_ message: String, _ canRetry: Bool) -> Void = { _, _ in },
        onPreparationFailed: @escaping (String) -> Void = { _ in },
        onInsufficientNativeFee: @escaping (MultichainNativeFeeShortage) -> Void = { _ in },
        onOpenFeePicker: @escaping (NetworkFeePickerPresentation) -> Void = { _ in },
        onRefillBattery: @escaping (@escaping () -> Void) -> Void = { _ in },
        onBatteryFeeShortage: @escaping (MultichainNativeFeeShortage) -> Void = { _ in },
        onDepositNativeFee: @escaping (MultichainAssetDetails) -> Void = { _ in },
        analytics: AnalyticsService? = nil
    ) -> MultichainSwapConfirmationViewModel {
        let resolvedSendAsset = sendAsset ?? asset(symbol: "ETH", decimals: 18)
        let resolvedReceiveAsset = receiveAsset ?? asset(
            assetId: "ton/mainnet/coin",
            symbol: "TON",
            decimals: 9
        )
        let viewModel = MultichainSwapConfirmationViewModel(
            swapWallet: makeSwapWallet(),
            confirmationInput: input ?? makeInput(
                sendAsset: resolvedSendAsset,
                receiveAsset: resolvedReceiveAsset
            ),
            quoteRefreshCycle: MultichainSwapQuoteRefreshCycle(startDate: Date(), duration: 30),
            amountFormatter: makeAmountFormatter(),
            executionService: executionService,
            planProvider: planProvider,
            multichainSwapService: swapService,
            slippageService: slippageService,
            routeRecovery: routeRecovery,
            swapAnalytics: analytics.map { MultichainSwapAnalytics.logging(to: $0, wallet: makeWallet()) },
            onConfirm: { onConfirm(); changed.send() },
            onPriceChanged: { onPriceChanged($0); changed.send() },
            onConfirmUnavailable: { onConfirmUnavailable(); changed.send() },
            onSwapInFlightChange: { onSwapInFlightChange($0); changed.send() },
            onRefreshQuote: { onRefreshQuote(); changed.send() },
            onQuoteRecovered: { onQuoteRecovered($0); changed.send() },
            onSlippageChange: { onSlippageChange($0); changed.send() },
            onExecutionCompleted: { onExecutionCompleted($0, $1, $2); changed.send() },
            onExecutionFailed: { onExecutionFailed($0, $1); changed.send() },
            onPreparationFailed: { onPreparationFailed($0); changed.send() },
            onInsufficientNativeFee: { onInsufficientNativeFee($0); changed.send() },
            onOpenFeePicker: { onOpenFeePicker($0); changed.send() },
            onRefillBattery: { onRefillBattery($0); changed.send() },
            onBatteryFeeShortage: { onBatteryFeeShortage($0); changed.send() },
            onDepositNativeFee: { onDepositNativeFee($0); changed.send() }
        )
        viewModel.objectWillChange.sink { changed.send() }.store(in: &subscriptions)
        return viewModel
    }

    /// The swap screen's next quote as it reaches the confirmation.
    func freshQuote(
        route: MultichainSwapRoute,
        quoteId: String = "fresh-quote"
    ) -> MultichainSwapConfirmationQuoteUpdate {
        .ready(
            makeInput(route: route, quoteId: quoteId),
            MultichainSwapQuoteRefreshCycle(startDate: Date(), duration: 30)
        )
    }

    func makeInput(
        sendAsset: MultichainAsset? = nil,
        receiveAsset: MultichainAsset? = nil,
        route: MultichainSwapRoute? = nil,
        quoteId: String = "quote",
        slippage: MultichainSwapSlippage? = MultichainSwapSlippage(
            chains: [
                "eth": MultichainSwapSlippageOptions(
                    optionsBps: [50, 100],
                    defaultBps: 100
                ),
            ]
        ),
        slippageBps: Int = 100,
        feeMethod: MultichainSwapFeeMethod? = nil,
        quoteAmount: MultichainSwapQuoteAmount? = nil
    ) -> MultichainSwapConfirmationInput {
        let quoteAmount = quoteAmount ?? .source(oneEth)
        let resolvedSendAsset = sendAsset ?? asset(symbol: "ETH", decimals: 18)
        let resolvedReceiveAsset = receiveAsset ?? asset(
            assetId: "ton/mainnet/coin",
            symbol: "TON",
            decimals: 9
        )
        let resolvedRoute = route ?? makeRoute()
        return MultichainSwapConfirmationInput(
            userInput: MultichainSwapConfirmationUserInput(
                quoteAmount: quoteAmount,
                sendAsset: resolvedSendAsset,
                receiveAsset: resolvedReceiveAsset,
                slippage: slippage,
                isMax: false,
                slippageBps: slippageBps,
                feeMethod: feeMethod,
                usdFiatRate: nil
            ),
            quoteState: MultichainSwapConfirmationQuoteState(
                quote: MultichainSwapQuote(quoteId: quoteId, routes: [resolvedRoute]),
                route: resolvedRoute
            )
        )
    }

    func makeRoute(
        routeId: String = "route",
        sourceAmount: String? = nil,
        maximumSourceAmount: String? = nil,
        estimatedDestinationAmount: String = "2500000000",
        minimumDestinationAmount: String = "2450000000",
        totalSlippageBps: Int? = 100,
        valueDifferenceBps: Int? = nil,
        fees: [MultichainSwapFee]? = nil,
        warnings: [String]? = nil,
        riskLevel: String = "low",
        dateExpire: Date = Date().addingTimeInterval(60)
    ) -> MultichainSwapRoute {
        MultichainSwapRoute(
            routeId: routeId,
            aggregator: "Aggregator",
            protocolSlug: "Protocol",
            routeType: "swap",
            sourceAmount: sourceAmount ?? oneEth.description,
            maximumSourceAmount: maximumSourceAmount,
            estimatedDestinationAmount: estimatedDestinationAmount,
            minimumDestinationAmount: minimumDestinationAmount,
            estimatedTime: MultichainSwapTimeEstimate(totalSeconds: 300),
            totalSlippageBps: totalSlippageBps,
            valueDifferenceBps: valueDifferenceBps,
            warnings: warnings,
            fees: fees,
            legs: [],
            dateExpire: dateExpire,
            riskLevel: riskLevel
        )
    }

    func asset(
        assetId: String = "eth/mainnet/coin",
        symbol: String,
        decimals: Int,
        usdPrice: Double? = nil
    ) -> MultichainAsset {
        MultichainAsset(
            asset: MultichainAssetDetails(
                assetId: assetId,
                name: symbol,
                symbol: symbol,
                decimals: decimals,
                image: ""
            ),
            price: MultichainAssetPrice(
                prices: usdPrice.map { [Currency.USD.code.lowercased(): $0] } ?? [:],
                diff24h: [:],
                diff7d: [:]
            ),
            balance: .zero
        )
    }

    func makeExecutionPlan(
        routeId: String = "route",
        fees: [MultichainTransactionEmulationResult],
        feeOptions: [MultichainSwapFeeOption] = []
    ) -> MultichainSwapExecutionPlan {
        MultichainSwapExecutionPlan(
            routeId: routeId,
            aggregator: .swapsXyz,
            payloads: .stub,
            networkFees: fees,
            feeOptions: feeOptions,
            payloadFees: [:]
        )
    }

    /// A plan of the operation `/v3` built for `route`, which it shows as that operation receives.
    func makeOperationPlan(
        preparing route: MultichainSwapRoute,
        expiresAt: Date = Date().addingTimeInterval(60)
    ) throws -> MultichainSwapExecutionPlan {
        let operation = try ChainKitOperationSender.parse(
            id: route.routeId,
            payloads: #"[{"chain_id":"eth/mainnet","id":"swap","type":"main","version":1,"meta":{"to":"0x1b6257cae4192e62b629efca21771be3d759183d","value":"0"}}]"#
        )
        let account = try ChainKitOperationSender.account(
            of: MultichainWalletAddress(chain: .eth, address: "0x9858EfFD232B4033E47d90003D41EC34EcaEda94"),
            asset: nil
        )
        let fees = [networkFee()]
        return MultichainSwapExecutionPlan(
            routeId: route.routeId,
            aggregator: .swapsXyz,
            providerRouteId: nil,
            signs: .operation(MultichainSwapOperation(
                operation: operation,
                account: account,
                signingAccount: account,
                fees: [],
                recipient: nil,
                expiresAt: expiresAt,
                route: route
            )),
            networkFees: fees,
            feeOptions: [nativeOption(fees: fees)],
            sourceAmount: route.sourceAmount
        )
    }

    func batteryOption(
        charges: Int = 3,
        excess: Int? = nil,
        isInsufficient: Bool = false
    ) -> MultichainSwapFeeOption {
        MultichainSwapFeeOption(cost: .batteryCharges(count: charges, excess: excess, isInsufficient: isInsufficient))
    }

    func gramOption(
        amountNano: BigUInt = 12_000_000,
        isInsufficient: Bool = false
    ) -> MultichainSwapFeeOption {
        MultichainSwapFeeOption(cost: .gram(amountNano: amountNano, isInsufficient: isInsufficient))
    }

    func nativeOption(
        fees: [MultichainTransactionEmulationResult]? = nil
    ) -> MultichainSwapFeeOption {
        MultichainSwapFeeOption(cost: .native(fees ?? [networkFee()], isInsufficient: false))
    }

    func networkFee(
        symbol: String = "ETH",
        decimals: Int = 18
    ) -> MultichainTransactionEmulationResult {
        MultichainTransactionEmulationResult(
            fee: BigUInt(2_100_000_000_000_000),
            asset: MultichainAssetDetails(
                assetId: "\(symbol.lowercased())/mainnet/coin",
                name: symbol,
                symbol: symbol,
                decimals: decimals,
                image: ""
            )
        )
    }

    func makeWallet() -> Wallet {
        let publicKey = PublicKey(data: Data(repeating: 0x01, count: 32))
        return Wallet(
            id: "wallet",
            identity: WalletIdentity(network: .mainnet, kind: .Regular(publicKey, .v4R2)),
            metaData: WalletMetaData(
                label: "Test wallet",
                tintColor: .defaultColor,
                icon: .icon(.wallet)
            ),
            setupSettings: WalletSetupSettings(isSetupFinished: true),
            batterySettings: BatterySettings(),
            multichain: .multichain(
                MultichainWalletState(
                    walletId: "wallet",
                    addresses: [
                        MultichainWalletAddress(chain: .eth, address: "0xwallet"),
                        MultichainWalletAddress(chain: .ton, address: "tonwallet"),
                    ]
                )
            )
        )
    }

    func makeSwapWallet() -> MultichainSwapWallet {
        let wallet = makeWallet()
        guard case let .multichain(state)? = wallet.multichain else {
            fatalError("Expected a multichain test wallet")
        }
        return MultichainSwapWallet(wallet: wallet, registeredState: state)
    }

    func makeAmountFormatter() -> AmountFormatter {
        var configuration = AmountFormatter.Configuration()
        configuration.locale = Locale(identifier: "en_US_POSIX")
        configuration.space = " "
        return AmountFormatter(configuration: configuration)
    }

    var oneEth: BigUInt {
        BigUInt(10).power(18)
    }

    @MainActor
    func waitUntil(
        timeout: TimeInterval = 5,
        file: StaticString = #filePath,
        line: UInt = #line,
        condition: () -> Bool
    ) async {
        await TKTestSupport.waitUntil(changed, timeout: timeout, file: file, line: line) { condition() }
    }
}

private extension MultichainSwapRouteRecovery {
    /// Keeps the shipping ladder length so attempt counts are exercised, without the wall clock.
    static let instantLadder = MultichainSwapRouteRecovery(
        delays: MultichainSwapRouteRecovery.default.delays,
        sleep: { _ in }
    )

    static func recording(into recorder: RouteRecoveryDelayRecorder) -> MultichainSwapRouteRecovery {
        MultichainSwapRouteRecovery(
            delays: MultichainSwapRouteRecovery.default.delays,
            sleep: { delay in await recorder.record(delay) }
        )
    }
}

@MainActor
private final class RouteRecoveryDelayRecorder {
    private(set) var delays = [TimeInterval]()

    func record(_ delay: TimeInterval) {
        delays.append(delay)
    }
}

private struct TestSlippageService: MultichainSwapSlippageService {
    let optionsBps: [Int]
}

private final class ConfirmationSwapServiceSpy: MultichainSwapService {
    private(set) var quoteRequests = [MultichainSwapQuoteRequest]()
    /// The API each quote was asked on, in order.
    private(set) var quoteAPIVersions = [MultichainSwapAPIVersion]()
    private let quoteResults: [Result<MultichainSwapQuote, MultichainSwapAPIError>]

    init(quoteResults: [Result<MultichainSwapQuote, MultichainSwapAPIError>] = [.failure(.unimplemented)]) {
        self.quoteResults = quoteResults
    }

    func createCrossSwapQuote(
        request: MultichainSwapQuoteRequest,
        walletId _: String?
    ) async throws(MultichainSwapAPIError) -> MultichainSwapQuote {
        try answer(request, on: .v2)
    }

    /// Answers as `/v3` does: the same routes, quoted there.
    func createCrossSwapQuoteV3(
        request: MultichainSwapQuoteRequest,
        walletId _: String
    ) async throws(MultichainSwapAPIError) -> MultichainSwapQuote {
        var quote = try answer(request, on: .v3)
        quote.routes = quote.routes.map { route in
            var route = route
            route.apiVersion = .v3
            return route
        }
        return quote
    }

    private func answer(
        _ request: MultichainSwapQuoteRequest,
        on apiVersion: MultichainSwapAPIVersion
    ) throws(MultichainSwapAPIError) -> MultichainSwapQuote {
        let callIndex = quoteRequests.count
        quoteRequests.append(request)
        quoteAPIVersions.append(apiVersion)
        changed.send()
        let result = callIndex < quoteResults.count
            ? quoteResults[callIndex]
            : (quoteResults.last ?? .failure(.unimplemented))
        return try result.get()
    }

    func listCrossSwapAssets(query _: MultichainSwapAssetsQuery) async throws -> [MultichainSwapAsset] {
        throw StubError.unimplemented
    }

    func getCrossSwapConfig(
        walletId _: String,
        fromAssetId _: String?,
        toAssetId _: String?
    ) async throws -> MultichainSwapConfig {
        throw StubError.unimplemented
    }

    func prepareCrossSwapRoute(
        routeId _: String,
        request _: MultichainSwapPrepareRouteRequest?,
        walletId: String?
    ) async throws -> MultichainSwapPrepare {
        throw StubError.unimplemented
    }
}

private final class ConfirmationExecutionServiceSpy: MultichainSwapExecutionService {
    private(set) var executionPlanCallCount = 0
    private(set) var executeCallCount = 0
    private(set) var feeMethods = [MultichainSwapFeeMethod]()
    private(set) var executedRouteIds = [String]()
    private(set) var spendLimits = [BigUInt]()
    private let executionPlanResults: [Result<MultichainSwapExecutionPlan, MultichainSwapExecutionFailure>]
    private let executionPlanHolds: [TestGate]
    private let executeResult: Result<MultichainSwapExecutionResult, MultichainSwapExecutionFailure>
    /// What the gate before the relayer finds, put to the consent a relayed swap is sent with: a
    /// refusal cancels the swap, as the gate's does. The chain's own coin is not reviewed.
    private let review: OperationReview?

    init(
        executionPlanResults: [Result<MultichainSwapExecutionPlan, MultichainSwapExecutionFailure>] = [
            .success(MultichainSwapExecutionPlan(
                routeId: "route",
                aggregator: .swapsXyz,
                payloads: .stub,
                networkFees: [],
                payloadFees: [:]
            )),
        ],
        executionPlanHolds: [TestGate] = [],
        executeResult: Result<MultichainSwapExecutionResult, MultichainSwapExecutionFailure> = .success(
            MultichainSwapExecutionResult(
                routeId: "route",
                txHash: "tx-hash",
                broadcastedPayloads: []
            )
        ),
        review: OperationReview? = nil
    ) {
        self.executionPlanResults = executionPlanResults
        self.executionPlanHolds = executionPlanHolds
        self.executeResult = executeResult
        self.review = review
    }

    func prepareExecutionPlan(
        swapWallet _: MultichainSwapWallet,
        sourceAsset _: MultichainAsset,
        destinationAsset _: MultichainAsset,
        route _: MultichainSwapRoute
    ) async throws(MultichainSwapExecutionFailure) -> MultichainSwapExecutionPlan {
        let callIndex = executionPlanCallCount
        executionPlanCallCount += 1
        changed.send()
        if callIndex < executionPlanHolds.count {
            try? await executionPlanHolds[callIndex].wait()
        }
        let result = callIndex < executionPlanResults.count
            ? executionPlanResults[callIndex]
            : (executionPlanResults.last ?? .failure(.internal(reason: "unimplemented")))
        return try result.get()
    }

    func execute(
        signer _: MultichainTransferSigner,
        swapWallet _: MultichainSwapWallet,
        sourceAsset _: MultichainAsset,
        destinationAsset _: MultichainAsset,
        executionPlan: MultichainSwapExecutionPlan,
        feeMethod: MultichainSwapFeeMethod,
        spendLimit: BigUInt,
        consent: OperationConsent
    ) async throws(MultichainSwapExecutionFailure) -> MultichainSwapExecutionResult {
        executeCallCount += 1
        executedRouteIds.append(executionPlan.routeId)
        feeMethods.append(feeMethod)
        spendLimits.append(spendLimit)
        changed.send()
        if let review, feeMethod.isRelayed, await !consent(review) {
            throw .canceled
        }
        return try executeResult.get()
    }
}

private let flaggedReview = OperationReview(
    id: "relayed-swap",
    findings: [OperationFinding(id: "finding", kind: "StubWarning", severity: .warning, title: "Finding")]
)

/// The user a swipe asks: answers every review alike, and keeps what it was asked.
private actor SwipingUser {
    private(set) var asked = [OperationReview]()
    private let answer: Bool

    init(answering answer: Bool) {
        self.answer = answer
    }

    nonisolated func consent() -> OperationConsent {
        OperationConsent { await self.ask($0) }
    }

    private func ask(_ review: OperationReview) -> Bool {
        asked.append(review)
        return answer
    }
}

private enum StubError: Error {
    case unimplemented
}

private final class AnalyticsServiceSpy: AnalyticsService {
    private(set) var events = [(name: String, args: [String: Any])]()

    func logEvent(name: String, args: [String: Any]) {
        events.append((name: name, args: args))
        changed.send()
    }
}

private extension MultichainSwapAPIError {
    static let unimplemented = MultichainSwapAPIError.unknown(statusCode: -1)
}

private extension MultichainSwapRoutePayloads {
    static var stub: MultichainSwapRoutePayloads {
        .main(MultichainSwapPreparedPayload(
            payloadId: "main",
            kind: "main",
            chainId: "eth/mainnet",
            chainFamily: "EVM",
            payloadType: "evm_tx",
            payload: "{}",
            humanSummary: MultichainSwapHumanSummary(
                action: "swap",
                spendAsset: "eth/mainnet/coin",
                spendAmount: "1",
                receiveAsset: "ton/mainnet/coin"
            ),
            validationStatus: "validated",
            dateExpire: Date(timeIntervalSince1970: 100_000_000_000)
        ))
    }
}
