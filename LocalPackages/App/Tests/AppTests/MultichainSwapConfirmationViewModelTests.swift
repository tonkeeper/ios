@testable import App
import BigInt
import Foundation
@testable import KeeperCore
import TKLocalize
import TonSwift
import XCTest

final class MultichainSwapConfirmationViewModelTests: XCTestCase {
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

        XCTAssertEqual(display.sendLine, "1 ETH")
        XCTAssertEqual(display.receiveLine, "2.5 TON")
        XCTAssertTrue(display.rateLine.hasPrefix("1 ETH ≈ "))
        XCTAssertTrue(display.rateLine.hasSuffix(" TON"))
        XCTAssertTrue(display.rateLine.contains("2.5") || display.rateLine.contains("2,5"))
        XCTAssertEqual(display.slippageLine, maker.percentLine(bps: 75))
        XCTAssertEqual(display.minimumReceivedLine, "2.45 TON")
        XCTAssertEqual(display.priceImpactValue?.contains("2.5"), true)
        XCTAssertTrue(display.networkFeeValue.contains("ETH"))
        XCTAssertNotEqual(display.networkFeeValue, TKLocales.MultichainSwap.Screen.Confirm.Value.calculating)
        XCTAssertFalse(display.networkFeeSubtitle.isEmpty)
        XCTAssertEqual(
            loadingDisplay.networkFeeValue,
            TKLocales.MultichainSwap.Screen.Confirm.Value.calculating
        )

        let displayWithoutValueDifference = maker.make(
            input: makeInput(route: makeRoute(valueDifferenceBps: nil)),
            networkFees: [networkFee()],
            selectedSlippageBps: 75
        )
        XCTAssertNil(displayWithoutValueDifference.priceImpactValue)
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

        XCTAssertEqual(viewModel.display.sendLine, "1 ETH")
        XCTAssertEqual(viewModel.display.receiveLine, "2.5 TON")
        XCTAssertEqual(viewModel.display.networkFeeValue, TKLocales.MultichainSwap.Screen.Confirm.Value.calculating)
        XCTAssertEqual(viewModel.selectedSlippageBps, 100)
        XCTAssertEqual(viewModel.currentConfirmationInput.quoteState.route.routeId, "route")
        XCTAssertEqual(viewModel.executionState, .idle)
    }

    @MainActor
    func test_slippageSelectionRefreshesQuoteAndRerendersDisplay() async {
        let refreshedRoute = makeRoute(
            routeId: "refreshed-route",
            estimatedDestinationAmount: "3000000000",
            minimumDestinationAmount: "2900000000",
            totalSlippageBps: 50
        )
        let swapService = ConfirmationSwapServiceSpy(
            quoteResults: [
                .success(MultichainSwapQuote(quoteId: "refreshed-quote", routes: [refreshedRoute])),
            ]
        )
        let executionService = ConfirmationExecutionServiceSpy()
        let viewModel = makeViewModel(
            executionService: executionService,
            swapService: swapService,
            slippageService: TestSlippageService(
                optionsBps: [50, 100],
                defaultBps: 100
            )
        )

        viewModel.selectSlippageBps(50)

        await waitUntil {
            viewModel.currentConfirmationInput.quoteState.route.routeId == "refreshed-route"
        }
        let requests = swapService.quoteRequests
        XCTAssertEqual(requests.count, 1)
        XCTAssertEqual(requests.first?.slippageBps, 50)
        XCTAssertEqual(requests.first?.senderAddress, "0xwallet")
        XCTAssertEqual(requests.first?.recipientAddress, "tonwallet")
        XCTAssertEqual(requests.first?.returnDepositAddress, true)
        XCTAssertEqual(viewModel.display.receiveLine, "3 TON")
        XCTAssertEqual(viewModel.display.minimumReceivedLine, "2.9 TON")
        XCTAssertEqual(viewModel.circularProgressRestartToken, 1)
    }

    @MainActor
    func test_slippageRefreshFromTonSourceAsksForFullPayloadInsteadOfDepositAddress() async {
        let swapService = ConfirmationSwapServiceSpy(
            quoteResults: [
                .success(MultichainSwapQuote(quoteId: "refreshed-quote", routes: [makeRoute()])),
            ]
        )
        let viewModel = makeViewModel(
            sendAsset: asset(assetId: "ton/mainnet/coin", symbol: "TON", decimals: 9),
            receiveAsset: asset(assetId: "eth/mainnet/coin", symbol: "ETH", decimals: 18),
            swapService: swapService
        )

        viewModel.selectSlippageBps(50)

        await waitUntil { swapService.quoteRequests.count == 1 }
        XCTAssertEqual(swapService.quoteRequests.first?.senderAddress, "tonwallet")
        XCTAssertEqual(swapService.quoteRequests.first?.returnDepositAddress, false)
    }

    @MainActor
    func test_slippageRefreshWithoutRouteReportsProviderErrorMessage() async {
        let providerMessage = "insufficient balance for source asset: The specified amount is too low."
        let swapService = ConfirmationSwapServiceSpy(
            quoteResults: [
                .success(
                    MultichainSwapQuote(
                        quoteId: "empty-quote",
                        routes: [],
                        providerErrors: [
                            MultichainSwapProviderError(
                                aggregator: "swapsxyz",
                                code: "provider_error",
                                message: providerMessage
                            ),
                        ]
                    )
                ),
            ]
        )
        var receivedMessage: String?
        let viewModel = makeViewModel(
            swapService: swapService,
            onQuoteProviderError: { receivedMessage = $0 }
        )

        viewModel.selectSlippageBps(50)

        await waitUntil { receivedMessage != nil }
        XCTAssertEqual(receivedMessage, TKLocales.MultichainSwap.ProviderError.unknown)
        XCTAssertNotEqual(receivedMessage, providerMessage)
        XCTAssertEqual(swapService.quoteRequests.count, 1)
        XCTAssertEqual(viewModel.selectedSlippageBps, 100)
    }

    @MainActor
    func test_timerRefreshWithoutRouteDoesNotToastProviderError() async {
        let providerMessage = "insufficient balance for source asset: The specified amount is too low."
        let executionService = ConfirmationExecutionServiceSpy()
        let swapService = ConfirmationSwapServiceSpy(
            quoteResults: [
                .success(
                    MultichainSwapQuote(
                        quoteId: "empty-quote",
                        routes: [],
                        providerErrors: [
                            MultichainSwapProviderError(
                                aggregator: "swapsxyz",
                                code: "provider_error",
                                message: providerMessage
                            ),
                        ]
                    )
                ),
            ]
        )
        var receivedMessage: String?
        let viewModel = makeViewModel(
            executionService: executionService,
            swapService: swapService,
            onQuoteProviderError: { receivedMessage = $0 }
        )

        viewModel.viewDidLoad()
        await waitUntil { executionService.executionPlanCallCount == 1 }

        viewModel.notifyCircularProgressCompleted()
        await waitUntil { swapService.quoteRequests.count == 1 }
        try? await Task.sleep(nanoseconds: 50_000_000)

        XCTAssertNil(receivedMessage)
        XCTAssertGreaterThanOrEqual(viewModel.circularProgressRestartToken, 1)
    }

    @MainActor
    func test_timerRefreshPreparationFailureDoesNotToast() async {
        let executionService = ConfirmationExecutionServiceSpy(
            executionPlanResults: [
                .success(makeExecutionPlan(routeId: "route", fees: [networkFee()])),
                .failure(.emulationFailed(kind: .insufficientBalance, reason: "insufficient")),
            ]
        )
        let swapService = ConfirmationSwapServiceSpy(
            quoteResults: [
                .success(MultichainSwapQuote(quoteId: "refreshed-quote", routes: [makeRoute()])),
            ]
        )
        var failedMessage: String?
        let viewModel = makeViewModel(
            executionService: executionService,
            swapService: swapService,
            onExecutionFailed: { failedMessage = $0 }
        )

        viewModel.viewDidLoad()
        await waitUntil { viewModel.isConfirmEnabled }

        viewModel.notifyCircularProgressCompleted()
        await waitUntil { executionService.executionPlanCallCount == 2 }
        try? await Task.sleep(nanoseconds: 50_000_000)

        XCTAssertNil(failedMessage)
        guard case .preparationFailed = viewModel.executionState else {
            return XCTFail("Expected failed preparation state")
        }
    }

    @MainActor
    func test_nativeFeeShortageCanPresentOnceForEachUserInitiatedCalculation() async {
        let shortage = MultichainNativeFeeShortage(
            asset: asset(symbol: "ETH", decimals: 18).asset,
            requiredAmount: BigUInt(2_100_000_000_000_000)
        )
        let executionService = ConfirmationExecutionServiceSpy(
            executionPlanResults: [
                .failure(.insufficientNativeFee(shortage: shortage)),
                .failure(.insufficientNativeFee(shortage: shortage)),
                .failure(.insufficientNativeFee(shortage: shortage)),
            ]
        )
        let swapService = ConfirmationSwapServiceSpy(
            quoteResults: [
                .success(MultichainSwapQuote(quoteId: "slippage-quote", routes: [makeRoute()])),
                .success(MultichainSwapQuote(quoteId: "timer-quote", routes: [makeRoute()])),
            ]
        )
        let presentationGuard = MultichainNativeFeeShortagePopupPresentationGuard()
        var calculationReasons = [MultichainSwapConfirmationRefreshReason]()
        var permittedPopupCount = 0
        let viewModel = makeViewModel(
            executionService: executionService,
            swapService: swapService,
            onInsufficientNativeFee: { _ in
                if presentationGuard.reservePresentation() {
                    permittedPopupCount += 1
                }
            },
            onFeeCalculationStarted: { reason in
                calculationReasons.append(reason)
                if reason != .timer {
                    presentationGuard.startNewFeeCalculation()
                }
            }
        )

        viewModel.viewDidLoad()

        await waitUntil { permittedPopupCount == 1 }
        viewModel.selectSlippageBps(50)
        await waitUntil { permittedPopupCount == 2 }

        viewModel.notifyCircularProgressCompleted()
        await waitUntil { executionService.executionPlanCallCount == 3 }
        try? await Task.sleep(nanoseconds: 50_000_000)

        XCTAssertEqual(
            calculationReasons,
            [.initial, .slippageChanged, .timer]
        )
        XCTAssertEqual(permittedPopupCount, 2)
    }

    @MainActor
    func test_feeDepositRefreshCanPresentNativeFeeShortageAgain() async {
        let shortage = MultichainNativeFeeShortage(
            asset: asset(symbol: "ETH", decimals: 18).asset,
            requiredAmount: BigUInt(2_100_000_000_000_000)
        )
        let executionService = ConfirmationExecutionServiceSpy(
            executionPlanResults: [
                .failure(.insufficientNativeFee(shortage: shortage)),
                .failure(.insufficientNativeFee(shortage: shortage)),
            ]
        )
        let presentationGuard = MultichainNativeFeeShortagePopupPresentationGuard()
        var calculationReasons = [MultichainSwapConfirmationRefreshReason]()
        var permittedPopupCount = 0
        let viewModel = makeViewModel(
            executionService: executionService,
            onInsufficientNativeFee: { _ in
                if presentationGuard.reservePresentation() {
                    permittedPopupCount += 1
                }
            },
            onFeeCalculationStarted: { reason in
                calculationReasons.append(reason)
                if reason != .timer {
                    presentationGuard.startNewFeeCalculation()
                }
            }
        )

        viewModel.viewDidLoad()
        await waitUntil { permittedPopupCount == 1 }

        viewModel.refreshFeeCalculationAfterDeposit()
        await waitUntil { permittedPopupCount == 2 }

        XCTAssertEqual(calculationReasons, [.initial, .feeDeposit])
        XCTAssertEqual(executionService.executionPlanCallCount, 2)
    }

    @MainActor
    func test_slippageSelectionInvalidatesExecutionPlanUntilRefreshCompletes() async {
        let refreshedRoute = makeRoute(
            routeId: "refreshed-route",
            estimatedDestinationAmount: "3000000000",
            minimumDestinationAmount: "2900000000",
            totalSlippageBps: 50
        )
        let executionService = ConfirmationExecutionServiceSpy(
            executionPlanResults: [
                .success(makeExecutionPlan(routeId: "route", fees: [networkFee()])),
                .success(makeExecutionPlan(routeId: "refreshed-route", fees: [networkFee(symbol: "TON", decimals: 9)])),
            ]
        )
        let swapService = ConfirmationSwapServiceSpy(
            quoteResults: [
                .success(MultichainSwapQuote(quoteId: "refreshed-quote", routes: [refreshedRoute])),
            ],
            quoteDelays: [0.3]
        )
        let viewModel = makeViewModel(
            executionService: executionService,
            swapService: swapService
        )

        viewModel.viewDidLoad()
        await waitUntil {
            viewModel.isConfirmEnabled
        }

        viewModel.selectSlippageBps(50)

        XCTAssertFalse(viewModel.isConfirmEnabled)
        XCTAssertEqual(
            viewModel.display.networkFeeValue,
            TKLocales.MultichainSwap.Screen.Confirm.Value.calculating
        )

        viewModel.confirmSwipe()
        viewModel.execute(passcodeProvider: { "passcode" })

        XCTAssertEqual(viewModel.executionState, .idle)
        XCTAssertEqual(executionService.executeCallCount, 0)
        XCTAssertEqual(executionService.executedRouteIds, [])

        await waitUntil(timeout: 2) {
            viewModel.isConfirmEnabled
        }
        viewModel.confirmSwipe()
        viewModel.execute(passcodeProvider: { "passcode" })

        await waitUntil {
            viewModel.executionState == .completed
        }
        XCTAssertEqual(executionService.executedRouteIds, ["refreshed-route"])
    }

    @MainActor
    func test_viewDidLoadPreparesExecutionPlanAndUpdatesDisplay() async {
        let executionService = ConfirmationExecutionServiceSpy(
            executionPlanResults: [.success(makeExecutionPlan(fees: [networkFee()]))]
        )
        let viewModel = makeViewModel(executionService: executionService)

        viewModel.viewDidLoad()

        await waitUntil {
            executionService.executionPlanCallCount == 1
        }
        await waitUntil {
            viewModel.display.networkFeeValue.contains("ETH")
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
        let viewModel = makeViewModel(
            executionService: executionService,
            swapService: swapService,
            onExecutionFailed: { failedMessage = $0 }
        )

        viewModel.viewDidLoad()

        await waitUntil { viewModel.isConfirmEnabled }
        XCTAssertNil(failedMessage)
        XCTAssertEqual(swapService.quoteRequests.count, 1)
        XCTAssertEqual(executionService.executionPlanCallCount, 2)
        XCTAssertEqual(viewModel.currentConfirmationInput.quoteState.route.routeId, "recovered-route")

        viewModel.confirmSwipe()
        viewModel.execute(passcodeProvider: { "passcode" })

        await waitUntil { viewModel.executionState == .completed }
        XCTAssertEqual(executionService.executedRouteIds, ["recovered-route"])
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
            onExecutionFailed: { failedMessage = $0 }
        )

        viewModel.viewDidLoad()

        await waitUntil { failedMessage != nil }
        try? await Task.sleep(nanoseconds: 50_000_000)
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
            onExecutionFailed: { failedMessage = $0 }
        )

        viewModel.viewDidLoad()

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
            onExecutionFailed: { failedMessage = $0 }
        )

        viewModel.viewDidLoad()

        await waitUntil { failedMessage != nil }
        XCTAssertEqual(
            failedMessage,
            TKLocales.MultichainSwap.Screen.Confirm.Error.badResponse
        )
        XCTAssertEqual(swapService.quoteRequests.count, 3)
        XCTAssertEqual(executionService.executionPlanCallCount, 1)
    }

    @MainActor
    func test_timerRefreshDoesNotRequestAnotherQuoteForAStaleRoute() async {
        let executionService = ConfirmationExecutionServiceSpy(
            executionPlanResults: [
                .success(makeExecutionPlan(fees: [networkFee()])),
                .failure(.routeExpired(routeId: "refreshed-route")),
            ]
        )
        let swapService = ConfirmationSwapServiceSpy(
            quoteResults: [
                .success(MultichainSwapQuote(
                    quoteId: "refreshed-quote",
                    routes: [makeRoute(routeId: "refreshed-route")]
                )),
            ]
        )
        let viewModel = makeViewModel(
            executionService: executionService,
            swapService: swapService
        )

        viewModel.viewDidLoad()
        await waitUntil { viewModel.isConfirmEnabled }

        viewModel.notifyCircularProgressCompleted()

        await waitUntil { executionService.executionPlanCallCount == 2 }
        try? await Task.sleep(nanoseconds: 50_000_000)
        XCTAssertEqual(swapService.quoteRequests.count, 1)
        XCTAssertEqual(executionService.executionPlanCallCount, 2)
    }

    @MainActor
    func test_executeWithoutPreparedExecutionPlanDoesNotStartExecution() async {
        let executionService = ConfirmationExecutionServiceSpy()
        let viewModel = makeViewModel(executionService: executionService)

        viewModel.confirmSwipe()
        viewModel.execute(passcodeProvider: { "passcode" })

        // Both the swipe and the send release the slider when there is no plan behind them, so what
        // matters is that it was released and nothing was sent, not how many times.
        await waitUntil {
            viewModel.sliderResetToken > 0
        }
        XCTAssertEqual(viewModel.executionState, .idle)
        XCTAssertEqual(executionService.executeCallCount, 0)
    }

    @MainActor
    func test_unlimitedApprovalAffectsExecutionAndSuccessState() async {
        let executionService = ConfirmationExecutionServiceSpy(
            executionPlanResults: [
                .success(makeExecutionPlan(fees: [], requiresApproval: true)),
            ],
            executeResult: .success(
                MultichainSwapExecutionResult(
                    routeId: "route",
                    txHash: "tx-hash",
                    broadcastedPayloads: []
                )
            )
        )
        var completedCount = 0
        let viewModel = makeViewModel(
            sendAsset: asset(
                assetId: "unknown/erc20/usdt",
                symbol: "USDT",
                decimals: 6
            ),
            executionService: executionService,
            onExecutionCompleted: { _, _ in
                completedCount += 1
            }
        )

        XCTAssertFalse(viewModel.showsUnlimitedApprovalToggle)
        viewModel.viewDidLoad()
        await waitUntil {
            executionService.executionPlanCallCount == 1
        }
        XCTAssertTrue(viewModel.showsUnlimitedApprovalToggle)
        viewModel.setUnlimitedApprovalEnabled(true)
        viewModel.confirmSwipe()
        viewModel.execute(passcodeProvider: { "passcode" })

        await waitUntil {
            viewModel.executionState == .completed
        }
        XCTAssertEqual(executionService.approvalModes, [.unlimited])
        XCTAssertEqual(completedCount, 1)
    }

    @MainActor
    func test_tokenRouteWithoutApprovalDoesNotShowOrChangeUnlimitedMode() async {
        let executionService = ConfirmationExecutionServiceSpy(
            executionPlanResults: [.success(makeExecutionPlan(fees: [], requiresApproval: false))]
        )
        let viewModel = makeViewModel(
            sendAsset: asset(
                assetId: "unknown/erc20/usdt",
                symbol: "USDT",
                decimals: 6
            ),
            executionService: executionService
        )

        viewModel.viewDidLoad()
        await waitUntil {
            executionService.executionPlanCallCount == 1
        }
        viewModel.setUnlimitedApprovalEnabled(true)

        XCTAssertFalse(viewModel.showsUnlimitedApprovalToggle)
        XCTAssertFalse(viewModel.isUnlimitedApprovalEnabled)
    }

    @MainActor
    func test_executionFailureUpdatesStateAndCallback() async {
        let executionService = ConfirmationExecutionServiceSpy(
            executeResult: .failure(.internal(reason: "test failure"))
        )
        var failedMessage: String?
        let viewModel = makeViewModel(
            executionService: executionService,
            onExecutionFailed: { message in
                failedMessage = message
            }
        )

        viewModel.viewDidLoad()
        await waitUntil {
            executionService.executionPlanCallCount == 1
        }
        viewModel.confirmSwipe()
        viewModel.execute(passcodeProvider: { "passcode" })

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
    func test_failedExecutionUnlocksSliderAndRetriesOnARefreshedRoute() async {
        let executionService = ConfirmationExecutionServiceSpy(
            executionPlanResults: [
                .success(makeExecutionPlan(routeId: "route", fees: [networkFee()])),
                .success(makeExecutionPlan(routeId: "refreshed-route", fees: [networkFee()])),
            ],
            executeResult: .failure(
                .broadcastFailed(payloadId: "main", kind: .unknown, reason: "node rejected")
            )
        )
        let swapService = ConfirmationSwapServiceSpy(
            quoteResults: [
                .success(MultichainSwapQuote(
                    quoteId: "refreshed-quote",
                    routes: [makeRoute(routeId: "refreshed-route")]
                )),
            ]
        )
        let viewModel = makeViewModel(
            executionService: executionService,
            swapService: swapService
        )

        viewModel.viewDidLoad()
        await waitUntil { viewModel.isConfirmEnabled }
        let resetTokenBeforeExecution = viewModel.sliderResetToken

        viewModel.confirmSwipe()
        viewModel.execute(passcodeProvider: { "passcode" })

        await waitUntil {
            viewModel.executionState == .executionFailed(
                TKLocales.MultichainSwap.Screen.Confirm.Error.unknown
            )
        }
        XCTAssertGreaterThan(viewModel.sliderResetToken, resetTokenBeforeExecution)
        XCTAssertEqual(viewModel.executionState.confirmTitle, TKLocales.Actions.retry)

        await waitUntil {
            viewModel.currentConfirmationInput.quoteState.route.routeId == "refreshed-route"
        }
        await waitUntil { viewModel.isConfirmEnabled }
        XCTAssertEqual(viewModel.executionState.confirmTitle, TKLocales.Actions.retry)
        XCTAssertEqual(swapService.quoteRequests.count, 1)

        viewModel.confirmSwipe()
        viewModel.execute(passcodeProvider: { "passcode" })

        await waitUntil { executionService.executeCallCount == 2 }
        XCTAssertEqual(executionService.executedRouteIds, ["route", "refreshed-route"])
    }

    @MainActor
    func test_failedExecutionKeepsRetryAvailableWhenTheRecoveryRefreshFails() async {
        let executionService = ConfirmationExecutionServiceSpy(
            executeResult: .failure(
                .broadcastFailed(payloadId: "main", kind: .unknown, reason: "node rejected")
            )
        )
        let swapService = ConfirmationSwapServiceSpy(
            quoteResults: [
                .success(MultichainSwapQuote(
                    quoteId: "empty-quote",
                    routes: [],
                    providerErrors: [
                        MultichainSwapProviderError(
                            aggregator: "swapsxyz",
                            code: "provider_error",
                            message: "no route"
                        ),
                    ]
                )),
            ]
        )
        var failedMessages = [String]()
        var providerErrorMessages = [String]()
        let viewModel = makeViewModel(
            executionService: executionService,
            swapService: swapService,
            onExecutionFailed: { failedMessages.append($0) },
            onQuoteProviderError: { providerErrorMessages.append($0) }
        )

        viewModel.viewDidLoad()
        await waitUntil { viewModel.isConfirmEnabled }

        viewModel.confirmSwipe()
        viewModel.execute(passcodeProvider: { "passcode" })

        await waitUntil { swapService.quoteRequests.count == 1 }
        try? await Task.sleep(nanoseconds: 50_000_000)
        XCTAssertEqual(failedMessages, [TKLocales.MultichainSwap.Screen.Confirm.Error.unknown])
        XCTAssertEqual(providerErrorMessages, [])
        XCTAssertTrue(viewModel.isConfirmEnabled)
        XCTAssertEqual(viewModel.executionState.confirmTitle, TKLocales.Actions.retry)
    }

    @MainActor
    func test_preparationFailureBlocksConfirmationAndUsesTypedMessage() async {
        let executionService = ConfirmationExecutionServiceSpy(
            executionPlanResults: [
                .failure(.preparationFailed(kind: .insufficientBalance, reason: "fee exceeds balance")),
            ]
        )
        var failedMessage: String?
        let viewModel = makeViewModel(
            executionService: executionService,
            onExecutionFailed: { failedMessage = $0 }
        )

        viewModel.viewDidLoad()

        await waitUntil {
            if case .preparationFailed = viewModel.executionState {
                return true
            }
            return false
        }
        XCTAssertFalse(viewModel.isConfirmEnabled)
        XCTAssertEqual(
            failedMessage,
            TKLocales.MultichainSwap.Screen.Confirm.Error.insufficientBalance
        )
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
        let viewModel = makeViewModel(
            executionService: executionService,
            onInsufficientNativeFee: { presentedShortage = $0 }
        )

        viewModel.viewDidLoad()

        await waitUntil {
            presentedShortage == shortage
        }
        XCTAssertNotEqual(
            viewModel.display.networkFeeValue,
            TKLocales.MultichainSwap.Screen.Confirm.Value.calculating
        )
        XCTAssertTrue(viewModel.display.networkFeeValue.contains("ETH"))
        XCTAssertEqual(
            viewModel.display.networkFeeSubtitle,
            TKLocales.MultichainSwap.Screen.Confirm.NetworkFee.insufficientNativeToken("ETH")
        )
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

        viewModel.viewDidLoad()
        await waitUntil {
            if case .preparationFailed = viewModel.executionState {
                return true
            }
            return false
        }

        viewModel.viewDidLoad()

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
            onExecutionFailed: { message in
                failedMessages.append(message)
            }
        )

        viewModel.viewDidLoad()
        await waitUntil {
            executionService.executionPlanCallCount == 1
        }
        viewModel.confirmSwipe()
        viewModel.execute(passcodeProvider: { nil })

        await waitUntil {
            viewModel.sliderResetToken == 1
        }
        XCTAssertEqual(viewModel.executionState, .idle)
        XCTAssertEqual(failedMessages, [])
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
        let refreshedRoute = makeRoute(routeId: "refreshed-route")
        let executionService = ConfirmationExecutionServiceSpy(
            executionPlanResults: [
                .success(makeExecutionPlan(fees: [networkFee()])),
                .success(makeExecutionPlan(fees: [networkFee(symbol: "TON", decimals: 9)])),
            ],
            executionPlanDelays: [0.3, 0]
        )
        let swapService = ConfirmationSwapServiceSpy(
            quoteResults: [
                .success(MultichainSwapQuote(quoteId: "refreshed-quote", routes: [refreshedRoute])),
            ]
        )
        let viewModel = makeViewModel(
            executionService: executionService,
            swapService: swapService
        )

        viewModel.viewDidLoad()
        await waitUntil {
            executionService.executionPlanCallCount == 1
        }
        viewModel.selectSlippageBps(50)

        await waitUntil(timeout: 2) {
            viewModel.display.networkFeeValue.contains("TON")
        }
        try? await Task.sleep(nanoseconds: 400_000_000)
        XCTAssertTrue(viewModel.display.networkFeeValue.contains("TON"))
        XCTAssertFalse(viewModel.display.networkFeeValue.contains("ETH"))
    }

    @MainActor
    func test_circularProgressCompletionDoesNotRefreshQuoteAfterExecutionCompleted() async {
        let swapService = ConfirmationSwapServiceSpy(
            quoteResults: [
                .success(MultichainSwapQuote(quoteId: "refreshed-quote", routes: [makeRoute()])),
            ]
        )
        let executionService = ConfirmationExecutionServiceSpy()
        let viewModel = makeViewModel(
            executionService: executionService,
            swapService: swapService
        )

        viewModel.viewDidLoad()
        await waitUntil {
            executionService.executionPlanCallCount == 1
        }
        viewModel.confirmSwipe()
        viewModel.execute(passcodeProvider: { "passcode" })
        await waitUntil {
            viewModel.executionState == .completed
        }

        viewModel.notifyCircularProgressCompleted()
        try? await Task.sleep(nanoseconds: 50_000_000)
        XCTAssertTrue(swapService.quoteRequests.isEmpty)
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

        viewModel.viewDidLoad()
        await waitUntil { executionService.executionPlanCallCount == 1 }

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

        viewModel.viewDidLoad()
        await waitUntil { executionService.executionPlanCallCount == 1 }

        viewModel.selectFeeOption(nativeOption())
        XCTAssertEqual(viewModel.selectedFeeOption?.method, .native)

        viewModel.confirmSwipe()
        viewModel.execute(passcodeProvider: { "1111" })
        await waitUntil { executionService.executeCallCount == 1 }

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

        viewModel.viewDidLoad()
        await waitUntil { executionService.executionPlanCallCount == 1 }

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

        viewModel.viewDidLoad()
        await waitUntil { executionService.executionPlanCallCount == 1 }

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

        viewModel.viewDidLoad()
        await waitUntil { executionService.executionPlanCallCount == 1 }

        XCTAssertEqual(viewModel.selectedFeeOption?.method, .gram)
        XCTAssertEqual(
            viewModel.display.networkFeeMethod,
            TransactionConfirmationModel.ExtraType.default.feeRowMethodTitle
        )
        XCTAssertTrue(
            viewModel.display.networkFeeValue.hasSuffix(MultichainAssetDetails.gram.symbol),
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

        viewModel.viewDidLoad()
        await waitUntil { executionService.executionPlanCallCount == 1 }

        viewModel.selectFeeOption(gramOption(isInsufficient: true))

        XCTAssertEqual(depositedAssetIds, [MultichainAssetDetails.gram.assetId])
        XCTAssertEqual(refillRequests, 0)
        XCTAssertEqual(viewModel.selectedFeeOption?.method, .native)
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

        viewModel.viewDidLoad()
        await waitUntil { executionService.executionPlanCallCount == 1 }
        XCTAssertEqual(viewModel.selectedFeeOption?.method, .battery)

        viewModel.refreshFeeCalculationAfterDeposit()
        await waitUntil { executionService.executionPlanCallCount == 2 }

        XCTAssertEqual(shortages, 0)
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

        viewModel.viewDidLoad()
        await waitUntil { executionService.executionPlanCallCount == 1 }

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

        viewModel.viewDidLoad()
        await waitUntil { executionService.executionPlanCallCount == 1 }

        XCTAssertFalse(viewModel.isConfirmEnabled)
        XCTAssertEqual(
            viewModel.display.networkFeeSubtitle,
            TKLocales.MultichainSwap.Screen.Confirm.NetworkFee.insufficientNativeToken("ETH")
        )
    }

    @MainActor
    func test_nativeShortageIsReportedOnceTheRelayedMethodIsGone() async {
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

        viewModel.viewDidLoad()
        await waitUntil { executionService.executionPlanCallCount == 1 }
        XCTAssertEqual(viewModel.selectedFeeOption?.method, .battery)
        XCTAssertTrue(shortages.isEmpty)

        // A plan that no longer offers the relayed method really does leave nothing paying.
        viewModel.refreshFeeCalculationAfterDeposit()
        await waitUntil { executionService.executionPlanCallCount == 2 }
        XCTAssertEqual(viewModel.selectedFeeOption?.method, .native)

        viewModel.refreshFeeCalculationAfterDeposit()
        await waitUntil { executionService.executionPlanCallCount == 3 }
        await waitUntil {
            if case .preparationFailed = viewModel.executionState {
                return true
            }
            return false
        }

        XCTAssertEqual(shortages.count, 1)
        XCTAssertFalse(viewModel.isConfirmEnabled)
    }

    @MainActor
    func test_abandonedSwipeStartsTheQuoteMovingAgain() async {
        let executionService = ConfirmationExecutionServiceSpy(
            executionPlanResults: [.success(makeExecutionPlan(fees: [networkFee()]))]
        )
        let swapService = ConfirmationSwapServiceSpy(
            quoteResults: [.success(MultichainSwapQuote(quoteId: "resumed", routes: [makeRoute()]))]
        )
        let viewModel = makeViewModel(
            executionService: executionService,
            swapService: swapService
        )

        viewModel.viewDidLoad()
        await waitUntil { executionService.executionPlanCallCount == 1 }
        XCTAssertTrue(swapService.quoteRequests.isEmpty)

        viewModel.confirmSwipe()
        viewModel.resetConfirmSlider()

        await waitUntil { swapService.quoteRequests.count == 1 }
    }

    @MainActor
    func test_batteryShortageIsAnnouncedWhenOnlyARefillCanPay() async {
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
        let viewModel = makeViewModel(
            executionService: executionService,
            onBatteryFeeShortage: { shortages.append($0) }
        )

        viewModel.viewDidLoad()
        await waitUntil { executionService.executionPlanCallCount == 1 }

        XCTAssertEqual(shortages.map(\.asset.symbol), ["ETH"])
        XCTAssertEqual(shortages.first?.requiredAmount, networkFee().fee)
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

        viewModel.viewDidLoad()
        await waitUntil { executionService.executionPlanCallCount == 1 }

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
        let viewModel = makeViewModel(executionService: executionService)

        viewModel.viewDidLoad()
        await waitUntil { executionService.executionPlanCallCount == 1 }
        XCTAssertEqual(viewModel.selectedFeeOption?.method, .battery)

        viewModel.confirmSwipe()
        viewModel.execute(passcodeProvider: { "1111" })
        await waitUntil { executionService.executeCallCount == 1 }
        await waitUntil { !viewModel.isConfirmEnabled }

        XCTAssertFalse(viewModel.isConfirmEnabled)
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
        let viewModel = makeViewModel(executionService: executionService)

        viewModel.viewDidLoad()
        await waitUntil { executionService.executionPlanCallCount == 1 }

        viewModel.confirmSwipe()
        viewModel.execute(passcodeProvider: { "1111" })
        await waitUntil { executionService.executeCallCount == 1 }
        await waitUntil { viewModel.executionState.statusLine == TKLocales.State.failed }

        XCTAssertTrue(viewModel.isConfirmEnabled)
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

        viewModel.viewDidLoad()
        await waitUntil { executionService.executionPlanCallCount == 1 }
        XCTAssertEqual(viewModel.selectedFeeOption?.method, .battery)
        viewModel.selectFeeOption(batteryOption(charges: 3))

        viewModel.refreshFeeCalculationAfterDeposit()
        await waitUntil { executionService.executionPlanCallCount == 2 }

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

        viewModel.viewDidLoad()
        await waitUntil { executionService.executionPlanCallCount == 1 }
        XCTAssertEqual(viewModel.selectedFeeMethod, .battery)

        viewModel.openFeeMethodPicker()
        let items = (presentation?.dataSource as? any NetworkFeePickerItemsDataSource)?.items ?? []
        XCTAssertEqual(items.map(\.id), ["battery", "native"])

        guard let nativeItem = items.first(where: { $0.id == "native" }) else {
            return XCTFail("expected a row for the chain's own coin")
        }
        presentation?.didSelectItem(nativeItem, nil)

        XCTAssertEqual(viewModel.selectedFeeMethod, .native)
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

        viewModel.viewDidLoad()
        await waitUntil { executionService.executionPlanCallCount == 1 }
        viewModel.selectFeeOption(nativeOption())
        XCTAssertEqual(viewModel.selectedFeeMethod, .native)

        viewModel.refreshFeeCalculationAfterDeposit()
        await waitUntil { executionService.executionPlanCallCount == 2 }

        viewModel.refreshFeeCalculationAfterDeposit()
        await waitUntil { executionService.executionPlanCallCount == 3 }

        XCTAssertEqual(viewModel.selectedFeeMethod, .native)
        XCTAssertEqual(viewModel.selectedFeeOption?.method, .native)
    }

    @MainActor
    func test_routePayloadShapeRefreshesKeepAnExplicitBatteryPick() async {
        let options = [batteryOption(charges: 3), nativeOption()]
        let executionService = ConfirmationExecutionServiceSpy(
            executionPlanResults: [
                .success(makeExecutionPlan(routeId: "ton-boc", fees: [networkFee()], feeOptions: options)),
                .success(makeExecutionPlan(routeId: "alt-vm-deposit", fees: [networkFee()], feeOptions: options)),
                .success(makeExecutionPlan(routeId: "ton-boc-again", fees: [networkFee()], feeOptions: options)),
            ]
        )
        let viewModel = makeViewModel(executionService: executionService)

        viewModel.viewDidLoad()
        await waitUntil { executionService.executionPlanCallCount == 1 }
        viewModel.selectFeeOption(nativeOption())
        viewModel.selectFeeOption(batteryOption(charges: 3))

        viewModel.refreshFeeCalculationAfterDeposit()
        await waitUntil { executionService.executionPlanCallCount == 2 }
        XCTAssertEqual(viewModel.selectedFeeMethod, .battery)
        XCTAssertTrue(viewModel.display.canPickFeeMethod)

        viewModel.refreshFeeCalculationAfterDeposit()
        await waitUntil { executionService.executionPlanCallCount == 3 }
        XCTAssertEqual(viewModel.selectedFeeMethod, .battery)
        XCTAssertTrue(viewModel.display.canPickFeeMethod)
    }

    @MainActor
    func test_routePayloadShapeRefreshesKeepAnExplicitNativePick() async {
        let options = [batteryOption(charges: 3), nativeOption()]
        let executionService = ConfirmationExecutionServiceSpy(
            executionPlanResults: [
                .success(makeExecutionPlan(routeId: "ton-boc", fees: [networkFee()], feeOptions: options)),
                .success(makeExecutionPlan(routeId: "alt-vm-deposit", fees: [networkFee()], feeOptions: options)),
                .success(makeExecutionPlan(routeId: "ton-boc-again", fees: [networkFee()], feeOptions: options)),
            ]
        )
        let viewModel = makeViewModel(executionService: executionService)

        viewModel.viewDidLoad()
        await waitUntil { executionService.executionPlanCallCount == 1 }
        viewModel.selectFeeOption(nativeOption())

        viewModel.refreshFeeCalculationAfterDeposit()
        await waitUntil { executionService.executionPlanCallCount == 2 }
        XCTAssertEqual(viewModel.selectedFeeMethod, .native)
        XCTAssertTrue(viewModel.display.canPickFeeMethod)

        viewModel.refreshFeeCalculationAfterDeposit()
        await waitUntil { executionService.executionPlanCallCount == 3 }
        XCTAssertEqual(viewModel.selectedFeeMethod, .native)
        XCTAssertTrue(viewModel.display.canPickFeeMethod)
    }
}

private extension MultichainSwapConfirmationViewModelTests {
    @MainActor
    func makeViewModel(
        sendAsset: MultichainAsset? = nil,
        receiveAsset: MultichainAsset? = nil,
        input: MultichainSwapConfirmationInput? = nil,
        executionService: ConfirmationExecutionServiceSpy = ConfirmationExecutionServiceSpy(),
        swapService: ConfirmationSwapServiceSpy = ConfirmationSwapServiceSpy(),
        slippageService: (any MultichainSwapSlippageService)? = TestSlippageService(
            optionsBps: [50, 100],
            defaultBps: 100
        ),
        routeRecovery: MultichainSwapRouteRecovery = .instantLadder,
        onExecutionCompleted: @escaping (MultichainSwapConfirmationInput, MultichainSwapFeeMethod) -> Void = { _, _ in },
        onExecutionFailed: @escaping (String) -> Void = { _ in },
        onQuoteProviderError: @escaping (String) -> Void = { _ in },
        onInsufficientNativeFee: @escaping (MultichainNativeFeeShortage) -> Void = { _ in },
        onFeeCalculationStarted: @escaping (MultichainSwapConfirmationRefreshReason) -> Void = { _ in },
        onOpenFeePicker: @escaping (NetworkFeePickerPresentation) -> Void = { _ in },
        onRefillBattery: @escaping (@escaping () -> Void) -> Void = { _ in },
        onBatteryFeeShortage: @escaping (MultichainNativeFeeShortage) -> Void = { _ in },
        onDepositNativeFee: @escaping (MultichainAssetDetails) -> Void = { _ in }
    ) -> MultichainSwapConfirmationViewModel {
        let resolvedSendAsset = sendAsset ?? asset(symbol: "ETH", decimals: 18)
        let resolvedReceiveAsset = receiveAsset ?? asset(
            assetId: "ton/mainnet/coin",
            symbol: "TON",
            decimals: 9
        )
        return MultichainSwapConfirmationViewModel(
            wallet: makeWallet(),
            confirmationInput: input ?? makeInput(
                sendAsset: resolvedSendAsset,
                receiveAsset: resolvedReceiveAsset
            ),
            amountFormatter: makeAmountFormatter(),
            executionService: executionService,
            multichainSwapService: swapService,
            slippageService: slippageService,
            routeRecovery: routeRecovery,
            onExecutionCompleted: onExecutionCompleted,
            onExecutionFailed: onExecutionFailed,
            onQuoteProviderError: onQuoteProviderError,
            onInsufficientNativeFee: onInsufficientNativeFee,
            onFeeCalculationStarted: onFeeCalculationStarted,
            onOpenFeePicker: onOpenFeePicker,
            onRefillBattery: onRefillBattery,
            onBatteryFeeShortage: onBatteryFeeShortage,
            onDepositNativeFee: onDepositNativeFee
        )
    }

    func makeInput(
        sendAsset: MultichainAsset? = nil,
        receiveAsset: MultichainAsset? = nil,
        route: MultichainSwapRoute? = nil
    ) -> MultichainSwapConfirmationInput {
        let resolvedSendAsset = sendAsset ?? asset(symbol: "ETH", decimals: 18)
        let resolvedReceiveAsset = receiveAsset ?? asset(
            assetId: "ton/mainnet/coin",
            symbol: "TON",
            decimals: 9
        )
        let resolvedRoute = route ?? makeRoute()
        return MultichainSwapConfirmationInput(
            userInput: MultichainSwapConfirmationUserInput(
                sendAmount: "1",
                rateText: "1 ETH ≈ 2.5 TON",
                sourceAmount: oneEth,
                sendAsset: resolvedSendAsset,
                receiveAsset: resolvedReceiveAsset,
                slippage: MultichainSwapSlippage(
                    chains: [
                        "eth": MultichainSwapSlippageOptions(
                            optionsBps: [50, 100],
                            defaultBps: 100
                        ),
                    ]
                ),
                isMax: false
            ),
            quoteState: MultichainSwapConfirmationQuoteState(
                quote: MultichainSwapQuote(quoteId: "quote", routes: [resolvedRoute]),
                route: resolvedRoute
            )
        )
    }

    func makeRoute(
        routeId: String = "route",
        sourceAmount: String? = nil,
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
                diff7d: [:],
                diff30d: [:]
            ),
            balance: .zero
        )
    }

    func makeExecutionPlan(
        routeId: String = "route",
        fees: [MultichainTransactionEmulationResult],
        requiresApproval: Bool = false,
        feeOptions: [MultichainSwapFeeOption] = []
    ) -> MultichainSwapExecutionPlan {
        MultichainSwapExecutionPlan(
            routeId: routeId,
            aggregator: .swapsXyz,
            payloads: .stub,
            networkFees: fees,
            requiresApproval: requiresApproval,
            feeOptions: feeOptions,
            payloadFees: [:]
        )
    }

    func batteryOption(
        charges: Int = 3,
        isInsufficient: Bool = false
    ) -> MultichainSwapFeeOption {
        MultichainSwapFeeOption(cost: .batteryCharges(count: charges, excess: nil, isInsufficient: isInsufficient))
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
        timeout: TimeInterval = 1,
        condition: @escaping () -> Bool
    ) async {
        let deadline = Date().addingTimeInterval(timeout)
        while !condition(), Date() < deadline {
            try? await Task.sleep(nanoseconds: 10_000_000)
        }
        if !condition() {
            XCTFail("Timed out waiting for condition")
        }
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
    let defaultBps: Int

    func initialSelectedBps(route: MultichainSwapRoute) -> Int {
        if let totalSlippageBps = route.totalSlippageBps,
           optionsBps.contains(totalSlippageBps)
        {
            return totalSlippageBps
        }
        return defaultBps
    }
}

private final class ConfirmationSwapServiceSpy: MultichainSwapService {
    private(set) var quoteRequests = [MultichainSwapQuoteRequest]()
    private let quoteResults: [Result<MultichainSwapQuote, MultichainSwapAPIError>]
    private let quoteDelays: [TimeInterval]

    init(
        quoteResults: [Result<MultichainSwapQuote, MultichainSwapAPIError>] = [.failure(.unimplemented)],
        quoteDelays: [TimeInterval] = []
    ) {
        self.quoteResults = quoteResults
        self.quoteDelays = quoteDelays
    }

    func createCrossSwapQuote(
        request: MultichainSwapQuoteRequest,
        walletId _: String?
    ) async throws(MultichainSwapAPIError) -> MultichainSwapQuote {
        let callIndex = quoteRequests.count
        quoteRequests.append(request)
        if callIndex < quoteDelays.count {
            try? await Task.sleep(nanoseconds: UInt64(quoteDelays[callIndex] * 1_000_000_000))
        }
        let result = callIndex < quoteResults.count
            ? quoteResults[callIndex]
            : (quoteResults.last ?? .failure(.unimplemented))
        return try result.get()
    }

    func listCrossSwapAssets(query _: MultichainSwapAssetsQuery) async throws -> [MultichainSwapAsset] {
        throw StubError.unimplemented
    }

    func getCrossSwapAsset(assetId _: String) async throws -> MultichainSwapAsset {
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
    private(set) var approvalModes = [MultichainSwapApprovalMode]()
    private(set) var feeMethods = [MultichainSwapFeeMethod]()
    private(set) var executedRouteIds = [String]()
    private let executionPlanResults: [Result<MultichainSwapExecutionPlan, MultichainSwapExecutionFailure>]
    private let executionPlanDelays: [TimeInterval]
    private let executeResult: Result<MultichainSwapExecutionResult, MultichainSwapExecutionFailure>

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
        executionPlanDelays: [TimeInterval] = [],
        executeResult: Result<MultichainSwapExecutionResult, MultichainSwapExecutionFailure> = .success(
            MultichainSwapExecutionResult(
                routeId: "route",
                txHash: "tx-hash",
                broadcastedPayloads: []
            )
        )
    ) {
        self.executionPlanResults = executionPlanResults
        self.executionPlanDelays = executionPlanDelays
        self.executeResult = executeResult
    }

    func prepareExecutionPlan(
        wallet _: Wallet,
        sourceAsset _: MultichainAsset,
        destinationAsset _: MultichainAsset,
        route _: MultichainSwapRoute
    ) async throws(MultichainSwapExecutionFailure) -> MultichainSwapExecutionPlan {
        let callIndex = executionPlanCallCount
        executionPlanCallCount += 1
        if callIndex < executionPlanDelays.count {
            try? await Task.sleep(nanoseconds: UInt64(executionPlanDelays[callIndex] * 1_000_000_000))
        }
        let result = callIndex < executionPlanResults.count
            ? executionPlanResults[callIndex]
            : (executionPlanResults.last ?? .failure(.internal(reason: "unimplemented")))
        return try result.get()
    }

    func execute(
        passcodeProvider _: @escaping () async -> String?,
        wallet _: Wallet,
        sourceAsset _: MultichainAsset,
        destinationAsset _: MultichainAsset,
        executionPlan: MultichainSwapExecutionPlan,
        approvalMode: MultichainSwapApprovalMode,
        feeMethod: MultichainSwapFeeMethod
    ) async throws(MultichainSwapExecutionFailure) -> MultichainSwapExecutionResult {
        executeCallCount += 1
        executedRouteIds.append(executionPlan.routeId)
        approvalModes.append(approvalMode)
        feeMethods.append(feeMethod)
        return try executeResult.get()
    }
}

private enum StubError: Error {
    case unimplemented
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
