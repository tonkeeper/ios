@testable import App
import BigInt
import Foundation
@testable import KeeperCore
import OperationReviewModels
import TKCore
import TKLocalize
import TKTestSupport
import TKUIKit
import TonSwift
import XCTest

final class MultichainSwapViewModelTests: XCTestCase {
    @MainActor
    func test_initialStateIsShimmerWhileInitialAssetsAreLoading() {
        let defaultAssetsService = DefaultAssetsServiceSpy(
            result: .success(initialAssets())
        )
        let viewModel = makeViewModel(defaultAssetsService: defaultAssetsService)

        guard case .shimmer = viewModel.state else {
            return XCTFail("Expected shimmer state")
        }
    }

    @MainActor
    func test_successfulInitialAssetsLoadTransitionsToLoadedState() async {
        let initialAssets = initialAssets()
        let defaultAssetsService = DefaultAssetsServiceSpy(
            result: .success(initialAssets)
        )
        let swapService = SwapServiceSpy()
        let viewModel = makeViewModel(
            defaultAssetsService: defaultAssetsService,
            swapService: swapService
        )

        await waitUntil(viewModel) {
            guard case let .loaded(state) = viewModel.state else {
                return false
            }
            return state.sendAsset.asset.assetId == initialAssets.sendAsset.asset.assetId
                && state.receiveAsset.asset.assetId == initialAssets.receiveAsset.asset.assetId
        }

        guard case let .loaded(state) = viewModel.state else {
            return XCTFail("Expected loaded state")
        }
        XCTAssertEqual(state.quote.quoteState, .idle)
        let requests = await swapService.quoteRequests()
        XCTAssertEqual(requests.count, 0)
    }

    @MainActor
    func test_failedInitialAssetsLoadShowsRetryableErrorState() async {
        let defaultAssetsService = DefaultAssetsServiceSpy(
            result: .failure(StubError.unimplemented)
        )
        let viewModel = makeViewModel(defaultAssetsService: defaultAssetsService)

        await waitUntil(viewModel) {
            if case .error = viewModel.state {
                return true
            }
            return false
        }

        guard case .error = viewModel.state else {
            return XCTFail("Expected error state")
        }

        viewModel.retryLoading()

        guard case .shimmer = viewModel.state else {
            return XCTFail("Expected shimmer state on retry")
        }
    }

    @MainActor
    func test_unavailableInitialSelectionIsReportedOnceLoaded() async {
        let defaultAssetsService = DefaultAssetsServiceSpy(
            result: .success(initialAssets(hasUnavailableInitialSelection: true))
        )
        let reported = expectation(description: "unavailable initial selection reported")
        let viewModel = makeViewModel(
            defaultAssetsService: defaultAssetsService,
            onInitialSelectionUnavailable: {
                reported.fulfill()
            }
        )

        await fulfillment(of: [reported], timeout: 5)

        guard case .loaded = viewModel.state else {
            return XCTFail("Expected loaded state")
        }
    }

    @MainActor
    func test_closeCancelsInitialAssetsLoading() async {
        let defaultAssetsService = DefaultAssetsServiceSpy(
            result: .success(initialAssets(hasUnavailableInitialSelection: true)),
            hold: TestGate()
        )
        var didReportUnavailableSelection = false
        let viewModel = makeViewModel(
            defaultAssetsService: defaultAssetsService,
            onInitialSelectionUnavailable: {
                didReportUnavailableSelection = true
            }
        )

        viewModel.close()
        await waitUntil(defaultAssetsService.changes) {
            await defaultAssetsService.finishedLoads == 1
        }

        XCTAssertFalse(didReportUnavailableSelection)
    }

    @MainActor
    func test_initialAssetsLoadingDoesNotRetainViewModel() async {
        let defaultAssetsService = DefaultAssetsServiceSpy(
            result: .success(initialAssets()),
            hold: TestGate()
        )
        var viewModel: MultichainSwapViewModel? = makeViewModel(
            defaultAssetsService: defaultAssetsService
        )
        weak var weakViewModel: MultichainSwapViewModel?
        weakViewModel = viewModel

        await Task.yield()
        viewModel = nil

        XCTAssertNil(weakViewModel)
    }

    @MainActor
    func test_actionsDuringShimmerDoNotRequestQuoteOrPicker() async {
        let assetsLoad = TestGate()
        let defaultAssetsService = DefaultAssetsServiceSpy(
            result: .success(initialAssets()),
            hold: assetsLoad
        )
        let swapService = SwapServiceSpy()
        let viewModel = makeViewModel(
            defaultAssetsService: defaultAssetsService,
            swapService: swapService
        )
        var didRequestSendPicker = false
        var didRequestReceivePicker = false
        viewModel.onRequestPickSendToken = {
            didRequestSendPicker = true
        }
        viewModel.onRequestPickReceiveToken = {
            didRequestReceivePicker = true
        }

        viewModel.updateSendAmount("1")
        viewModel.updateReceiveAmount("2")
        viewModel.swapTokens()
        viewModel.applySendPercent(100)
        viewModel.quoteCountdownDidFinish()
        viewModel.requestPickSendToken()
        viewModel.requestPickReceiveToken()
        viewModel.continueSwap()

        XCTAssertFalse(didRequestSendPicker)
        XCTAssertFalse(didRequestReceivePicker)
        guard case .shimmer = viewModel.state else {
            return XCTFail("Expected shimmer state")
        }

        await assetsLoad.open()
        await waitUntil(viewModel) {
            if case .loaded = viewModel.state { return true }
            return false
        }
        let quoteRequestCount = await swapService.quoteRequests().count
        XCTAssertEqual(quoteRequestCount, 0)
    }

    @MainActor
    func test_maxPreset_reportsUnavailableTonBalanceBelowReserve() async {
        let tonBalance = BigUInt(900_000_000)
        let initialAssets = MultichainSwapInitialAssets(
            sendAsset: asset(
                assetId: "ton/mainnet/coin",
                symbol: "GRAM",
                decimals: 9,
                balance: tonBalance
            ),
            receiveAsset: asset(
                assetId: "eth/mainnet/coin",
                symbol: "ETH",
                decimals: 18
            ),
            slippage: .init(chains: [:]),
            usdFiatRate: nil,
            hasUnavailableInitialSelection: false
        )
        let defaultAssetsService = DefaultAssetsServiceSpy(result: .success(initialAssets))
        let swapService = SwapServiceSpy()
        var didReportTonMaxUnavailable = false
        let viewModel = makeViewModel(
            defaultAssetsService: defaultAssetsService,
            swapService: swapService,
            onTonMaxAmountUnavailable: {
                didReportTonMaxUnavailable = true
            }
        )

        await waitUntil(viewModel) {
            guard case .loaded = viewModel.state else {
                return false
            }
            return true
        }

        viewModel.applySendPercent(100)

        guard case let .loaded(state) = viewModel.state else {
            return XCTFail("Expected loaded state")
        }
        XCTAssertTrue(didReportTonMaxUnavailable)
        XCTAssertEqual(state.sendAmount, "")
    }

    @MainActor
    func test_sendCardRateTextTogglesBetweenFiatAndCryptoAmounts() async {
        let oneEth = BigUInt(10).power(18)
        let initialAssets = initialAssets(
            sendBalance: oneEth * 10,
            sendPrice: 2,
            receivePrice: 0.5
        )
        let quote = quote(
            sourceAmount: oneEth.description,
            estimatedDestinationAmount: "5000000000"
        )
        let defaultAssetsService = DefaultAssetsServiceSpy(
            result: .success(initialAssets)
        )
        let swapService = SwapServiceSpy(quoteResult: .success(quote))
        var confirmationInput: MultichainSwapConfirmationInput?
        let viewModel = makeViewModel(
            defaultAssetsService: defaultAssetsService,
            swapService: swapService,
            onContinue: { input in
                confirmationInput = input
            }
        )

        await waitUntil(viewModel) {
            guard case .loaded = viewModel.state else {
                return false
            }
            return true
        }

        viewModel.updateSendAmount("1")

        await waitUntil(viewModel) {
            guard case let .loaded(state) = viewModel.state else {
                return false
            }
            return state.validationState == .valid
        }

        guard case let .loaded(cryptoState) = viewModel.state else {
            return XCTFail("Expected loaded state")
        }
        XCTAssertEqual(cryptoState.sendAmountInputMode, .crypto)
        XCTAssertEqual(cryptoState.sendCardRateText, "$\u{2009}2.00")
        XCTAssertEqual(cryptoState.receiveCardRateText, "$\u{2009}2.50")

        viewModel.toggleSendAmountInputMode()

        await waitUntil(viewModel) {
            guard case let .loaded(state) = viewModel.state else {
                return false
            }
            return state.sendAmountInputMode == .fiat
                && state.validationState == .valid
        }

        guard case let .loaded(fiatState) = viewModel.state else {
            return XCTFail("Expected loaded state")
        }
        XCTAssertEqual(fiatState.sendAmount, "2")
        XCTAssertEqual(fiatState.sendCardRateText, "1 ETH")

        let requests = await swapService.quoteRequests()
        XCTAssertEqual(requests.last?.amount, .source(oneEth))

        viewModel.continueSwap()
        XCTAssertEqual(confirmationInput?.sourceAmount, oneEth)
    }

    @MainActor
    func test_repeatedSendAmountInputModeTogglesKeepTheAmountExact() async {
        let oneEth = BigUInt(10).power(18)
        let defaultAssetsService = DefaultAssetsServiceSpy(
            result: .success(
                initialAssets(
                    sendBalance: oneEth * 10,
                    sendPrice: 3.4567,
                    receivePrice: 0.5
                )
            )
        )
        let swapService = SwapServiceSpy(
            quoteResult: .success(
                quote(
                    sourceAmount: oneEth.description,
                    estimatedDestinationAmount: "5000000000"
                )
            )
        )
        let viewModel = makeViewModel(
            defaultAssetsService: defaultAssetsService,
            swapService: swapService
        )

        await waitUntil(viewModel) {
            guard case .loaded = viewModel.state else {
                return false
            }
            return true
        }

        viewModel.updateSendAmount("1")
        await waitUntil(viewModel) {
            guard case let .loaded(state) = viewModel.state else {
                return false
            }
            return state.validationState == .valid
        }

        for _ in 0 ..< 3 {
            viewModel.toggleSendAmountInputMode()
            guard case let .loaded(fiatState) = viewModel.state else {
                return XCTFail("Expected loaded state")
            }
            XCTAssertEqual(fiatState.sendAmountInputMode, .fiat)
            // The fiat field rounds to cents; the crypto amount behind it must not.
            XCTAssertEqual(fiatState.sendAmount, "3.45")
            XCTAssertEqual(fiatState.sendCardRateText, "1 ETH")

            viewModel.toggleSendAmountInputMode()
            guard case let .loaded(cryptoState) = viewModel.state else {
                return XCTFail("Expected loaded state")
            }
            XCTAssertEqual(cryptoState.sendAmountInputMode, .crypto)
            XCTAssertEqual(cryptoState.sendAmount, "1")
        }

        guard case let .loaded(settledState) = viewModel.state else {
            return XCTFail("Expected loaded state")
        }
        XCTAssertNotEqual(settledState.quote.quoteState, .loading, "no requote is pending")
        let requests = await swapService.quoteRequests()
        XCTAssertTrue(requests.allSatisfy { $0.amount == .source(oneEth) })
    }

    @MainActor
    func test_sendAmountEditedInFiatModeConvertsFromTheTypedFiatValue() async {
        let oneEth = BigUInt(10).power(18)
        let defaultAssetsService = DefaultAssetsServiceSpy(
            result: .success(
                initialAssets(
                    sendBalance: oneEth * 10,
                    sendPrice: 2,
                    receivePrice: 0.5
                )
            )
        )
        let viewModel = makeViewModel(defaultAssetsService: defaultAssetsService)

        await waitUntil(viewModel) {
            guard case .loaded = viewModel.state else {
                return false
            }
            return true
        }

        viewModel.updateSendAmount("1")
        viewModel.toggleSendAmountInputMode()
        viewModel.updateSendAmount("5")
        viewModel.toggleSendAmountInputMode()

        guard case let .loaded(state) = viewModel.state else {
            return XCTFail("Expected loaded state")
        }
        XCTAssertEqual(state.sendAmountInputMode, .crypto)
        XCTAssertEqual(state.sendAmount, "2.5")
    }

    @MainActor
    func test_maxSendSurvivesSendAmountInputModeRoundTrip() async {
        let oneEth = BigUInt(10).power(18)
        let balance = oneEth * 2
        let defaultAssetsService = DefaultAssetsServiceSpy(
            result: .success(
                initialAssets(
                    sendBalance: balance,
                    sendPrice: 3.4567,
                    receivePrice: 0.5
                )
            )
        )
        let swapService = SwapServiceSpy(
            quoteResult: .success(
                quote(
                    sourceAmount: balance.description,
                    estimatedDestinationAmount: "5000000000"
                )
            )
        )
        var confirmationInput: MultichainSwapConfirmationInput?
        let viewModel = makeViewModel(
            defaultAssetsService: defaultAssetsService,
            swapService: swapService,
            onContinue: { input in
                confirmationInput = input
            }
        )

        await waitUntil(viewModel) {
            guard case .loaded = viewModel.state else {
                return false
            }
            return true
        }

        viewModel.applySendPercent(100)
        await waitUntil(viewModel) {
            guard case let .loaded(state) = viewModel.state else {
                return false
            }
            return state.validationState == .valid
                && state.quote.quoteState == .ready
        }

        viewModel.toggleSendAmountInputMode()
        viewModel.toggleSendAmountInputMode()

        guard case let .loaded(state) = viewModel.state else {
            return XCTFail("Expected loaded state")
        }
        XCTAssertEqual(state.sendAmount, "2")

        viewModel.continueSwap()
        XCTAssertEqual(confirmationInput?.sourceAmount, balance)
        XCTAssertEqual(confirmationInput?.userInput.isMax, true)
        let maxRequests = await swapService.quoteRequests()
        XCTAssertEqual(maxRequests.last?.isMax, true)
        XCTAssertEqual(maxRequests.last?.amount, .source(balance))
    }

    @MainActor
    func test_maxPreset_quotesTheSpendableBalanceAndDropsTheFlagOnceEdited() async {
        let oneUsdt = BigUInt(1_000_000)
        let balance = oneUsdt * 3 + 1
        let defaultAssetsService = DefaultAssetsServiceSpy(
            result: .success(
                initialAssets(
                    sendAssetId: "ton/mainnet/jetton/0:usdt",
                    sendSymbol: "USDT",
                    sendDecimals: 6,
                    sendBalance: balance
                )
            )
        )
        let swapService = SwapServiceSpy(
            quoteResult: .success(
                quote(
                    sourceAmount: balance.description,
                    estimatedDestinationAmount: "1"
                )
            )
        )
        let viewModel = makeViewModel(
            defaultAssetsService: defaultAssetsService,
            swapService: swapService
        )

        await waitUntil(viewModel) {
            guard case .loaded = viewModel.state else {
                return false
            }
            return true
        }

        viewModel.applySendPercent(100)
        await waitUntil(viewModel) {
            guard case let .loaded(state) = viewModel.state else {
                return false
            }
            return state.validationState == .valid && state.quote.quoteState == .ready
        }

        let maxRequests = await swapService.quoteRequests()
        XCTAssertEqual(maxRequests.last?.isMax, true)
        XCTAssertEqual(maxRequests.last?.amount, .source(balance))

        viewModel.updateSendAmount("1")
        await waitUntil(swapService.changes) {
            let requests = await swapService.quoteRequests()
            return requests.count > maxRequests.count && requests.last?.isMax == nil
        }
        let editedRequests = await swapService.quoteRequests()
        XCTAssertEqual(editedRequests.last?.amount, .source(oneUsdt))
        XCTAssertNil(editedRequests.last?.isMax)
    }

    @MainActor
    func test_percentPresetQuotesAShareOfTheSpendableBalanceWithoutTheMaxFlag() async {
        let defaultAssetsService = DefaultAssetsServiceSpy(
            result: .success(
                initialAssets(
                    sendAssetId: "ton/mainnet/jetton/0:usdt",
                    sendSymbol: "USDT",
                    sendDecimals: 6,
                    sendBalance: 3_000_001
                )
            )
        )
        let swapService = SwapServiceSpy(
            quoteResult: .success(
                quote(
                    sourceAmount: "1500000",
                    estimatedDestinationAmount: "1"
                )
            )
        )
        let viewModel = makeViewModel(
            defaultAssetsService: defaultAssetsService,
            swapService: swapService
        )

        await waitUntil(viewModel) {
            guard case .loaded = viewModel.state else {
                return false
            }
            return true
        }

        viewModel.applySendPercent(50)
        await waitUntil(swapService.changes) {
            await !swapService.quoteRequests().isEmpty
        }

        let request = await swapService.quoteRequests().last
        XCTAssertEqual(request?.amount, .source(1_500_000))
        XCTAssertNil(request?.isMax)
    }

    @MainActor
    func test_usdOnlyPricesWithoutFxRateShowOnlyZeroFiatAndKeepFiatInputDisabled() async throws {
        let oneEth = BigUInt(10).power(18)
        let initialAssets = initialAssets(
            sendBalance: oneEth * 10,
            sendPrice: 2,
            receivePrice: 0.5
        )
        let quote = quote(
            sourceAmount: oneEth.description,
            estimatedDestinationAmount: "5000000000"
        )
        let defaultAssetsService = DefaultAssetsServiceSpy(
            result: .success(initialAssets)
        )
        let swapService = SwapServiceSpy(quoteResult: .success(quote))
        let viewModel = try makeViewModel(
            defaultAssetsService: defaultAssetsService,
            swapService: swapService,
            displayCurrency: XCTUnwrap(Currency(code: "EUR"))
        )

        await waitUntil(viewModel) {
            guard case .loaded = viewModel.state else {
                return false
            }
            return true
        }

        guard case let .loaded(initialState) = viewModel.state else {
            return XCTFail("Expected loaded state")
        }
        XCTAssertEqual(initialState.sendCardRateText, "€\u{2009}0.00")
        XCTAssertEqual(initialState.receiveCardRateText, "€\u{2009}0.00")

        viewModel.updateSendAmount("1")

        await waitUntil(viewModel) {
            guard case let .loaded(state) = viewModel.state else {
                return false
            }
            return state.quote.quoteState == .ready
                && state.validationState == .valid
        }

        guard case let .loaded(cryptoState) = viewModel.state else {
            return XCTFail("Expected loaded state")
        }
        XCTAssertEqual(cryptoState.sendAmountInputMode, .crypto)
        XCTAssertNil(cryptoState.sendCardRateText)
        XCTAssertNil(cryptoState.receiveCardRateText)

        let requestCountBeforeToggle = await swapService.quoteRequests().count
        viewModel.toggleSendAmountInputMode()

        guard case let .loaded(afterToggleState) = viewModel.state else {
            return XCTFail("Expected loaded state")
        }
        XCTAssertEqual(afterToggleState.sendAmountInputMode, .crypto)
        XCTAssertEqual(afterToggleState.sendAmount, "1")
        XCTAssertNil(afterToggleState.sendCardRateText)
        XCTAssertNotEqual(afterToggleState.quote.quoteState, .loading, "no requote is pending")

        let requestCountAfterToggle = await swapService.quoteRequests().count
        XCTAssertEqual(requestCountAfterToggle, requestCountBeforeToggle)
    }

    @MainActor
    func test_fxRateConvertsUsdPricesToDisplayCurrency() async throws {
        let oneEth = BigUInt(10).power(18)
        let initialAssets = initialAssets(
            sendBalance: oneEth * 10,
            sendPrice: 2,
            receivePrice: 0.5,
            usdFiatRate: Decimal(string: "0.9")
        )
        let quote = quote(
            sourceAmount: oneEth.description,
            estimatedDestinationAmount: "5000000000"
        )
        let defaultAssetsService = DefaultAssetsServiceSpy(
            result: .success(initialAssets)
        )
        let swapService = SwapServiceSpy(quoteResult: .success(quote))
        let viewModel = try makeViewModel(
            defaultAssetsService: defaultAssetsService,
            swapService: swapService,
            displayCurrency: XCTUnwrap(Currency(code: "EUR"))
        )

        await waitUntil(viewModel) {
            guard case .loaded = viewModel.state else {
                return false
            }
            return true
        }
        viewModel.updateSendAmount("1")
        await waitUntil(viewModel) {
            guard case let .loaded(state) = viewModel.state else {
                return false
            }
            return state.quote.quoteState == .ready
        }

        guard case let .loaded(readyState) = viewModel.state else {
            return XCTFail("Expected loaded state")
        }
        XCTAssertEqual(readyState.sendCardRateText, "€\u{2009}1.80")
        XCTAssertEqual(readyState.receiveCardRateText, "€\u{2009}2.25")

        viewModel.toggleReceiveAmountInputMode()

        guard case let .loaded(fiatState) = viewModel.state else {
            return XCTFail("Expected loaded state")
        }
        XCTAssertEqual(fiatState.receiveAmountInputMode, .fiat)
        XCTAssertEqual(fiatState.receiveAmountFiatSymbol, Currency(code: "EUR")?.symbol)
        XCTAssertEqual(fiatState.receiveAmount, "2.25")
        XCTAssertEqual(fiatState.receiveCardRateText, "5 TON")
    }

    @MainActor
    func test_quoteDerivedFxRateConvertsUsdPricesWhenWalletRateIsMissing() async throws {
        let oneEth = BigUInt(10).power(18)
        let initialAssets = initialAssets(
            sendBalance: oneEth * 10,
            sendPrices: ["RUB": 160.0],
            receivePrice: nil
        )
        let quote = quote(
            sourceAmount: oneEth.description,
            estimatedDestinationAmount: "5000000000",
            sourceUsdPrice: 2.0,
            destinationUsdPrice: 0.5
        )
        let defaultAssetsService = DefaultAssetsServiceSpy(
            result: .success(initialAssets)
        )
        let swapService = SwapServiceSpy(quoteResult: .success(quote))
        let viewModel = try makeViewModel(
            defaultAssetsService: defaultAssetsService,
            swapService: swapService,
            displayCurrency: XCTUnwrap(Currency(code: "RUB"))
        )

        await waitUntil(viewModel) {
            guard case .loaded = viewModel.state else {
                return false
            }
            return true
        }
        viewModel.updateSendAmount("1")
        await waitUntil(viewModel) {
            guard case let .loaded(state) = viewModel.state else {
                return false
            }
            return state.quote.quoteState == .ready
        }

        guard case let .loaded(readyState) = viewModel.state else {
            return XCTFail("Expected loaded state")
        }
        // FX recovered from the quote: 160 RUB / 2 USD = 80; 5 TON × $0.5 × 80 = 200 RUB.
        XCTAssertEqual(readyState.sendCardRateText, "160.00\u{2009}₽")
        XCTAssertEqual(readyState.receiveCardRateText, "200.00\u{2009}₽")
    }

    @MainActor
    func test_receiveCardShowsFiatFromRouteUsdPriceForTokenWithoutOwnPrice() async {
        let oneEth = BigUInt(10).power(18)
        let defaultAssetsService = DefaultAssetsServiceSpy(
            result: .success(
                initialAssets(
                    sendBalance: oneEth * 10,
                    sendPrice: 2000,
                    receivePrice: nil
                )
            )
        )
        let swapService = SwapServiceSpy(
            quoteResult: .success(
                quote(
                    sourceAmount: oneEth.description,
                    estimatedDestinationAmount: "5000000000",
                    destinationUsdPrice: 5.5
                )
            )
        )
        let viewModel = makeViewModel(
            defaultAssetsService: defaultAssetsService,
            swapService: swapService
        )

        await waitUntil(viewModel) {
            guard case .loaded = viewModel.state else {
                return false
            }
            return true
        }

        guard case let .loaded(initialState) = viewModel.state else {
            return XCTFail("Expected loaded state")
        }
        XCTAssertEqual(initialState.receiveCardRateText, "$\u{2009}0.00")

        viewModel.updateSendAmount("1")

        await waitUntil(viewModel) {
            guard case let .loaded(state) = viewModel.state else {
                return false
            }
            return state.quote.quoteState == .ready
        }

        guard case let .loaded(readyState) = viewModel.state else {
            return XCTFail("Expected loaded state")
        }
        XCTAssertEqual(readyState.receiveCardRateText, "$\u{2009}27.50")

        viewModel.toggleReceiveAmountInputMode()

        guard case let .loaded(fiatState) = viewModel.state else {
            return XCTFail("Expected loaded state")
        }
        XCTAssertEqual(fiatState.receiveAmountInputMode, .fiat)
        XCTAssertEqual(fiatState.receiveAmountFiatSymbol, Currency.USD.symbol)
        XCTAssertEqual(fiatState.receiveAmount, "27.5")
        XCTAssertEqual(fiatState.receiveCardRateText, "5 TON")

        viewModel.toggleReceiveAmountInputMode()

        viewModel.updateSendAmount("2")

        guard case let .loaded(refreshingState) = viewModel.state else {
            return XCTFail("Expected loaded state")
        }
        XCTAssertEqual(refreshingState.quote.quoteState, .loading)
        XCTAssertEqual(
            refreshingState.receiveCardRateText,
            "$\u{2009}27.50",
            "The fiat line must not blink out while a refreshed quote is loading"
        )
    }

    @MainActor
    func test_toggleReceiveAmountInputModeRendersReceiveAmountAsFiat() async {
        let oneEth = BigUInt(10).power(18)
        let defaultAssetsService = DefaultAssetsServiceSpy(
            result: .success(
                initialAssets(
                    sendBalance: oneEth * 10,
                    sendPrice: 2000,
                    receivePrice: 5.5
                )
            )
        )
        let swapService = SwapServiceSpy(
            quoteResult: .success(
                quote(
                    sourceAmount: oneEth.description,
                    estimatedDestinationAmount: "5000000000"
                )
            )
        )
        let viewModel = makeViewModel(
            defaultAssetsService: defaultAssetsService,
            swapService: swapService
        )

        await waitUntil(viewModel) {
            guard case .loaded = viewModel.state else {
                return false
            }
            return true
        }
        viewModel.updateSendAmount("1")
        await waitUntil(viewModel) {
            guard case let .loaded(state) = viewModel.state else {
                return false
            }
            return state.quote.quoteState == .ready
        }

        viewModel.toggleReceiveAmountInputMode()

        guard case let .loaded(fiatState) = viewModel.state else {
            return XCTFail("Expected loaded state")
        }
        XCTAssertEqual(fiatState.receiveAmountInputMode, .fiat)
        XCTAssertEqual(fiatState.receiveAmountFiatSymbol, Currency.USD.symbol)
        XCTAssertEqual(fiatState.receiveAmount, "27.5")
        XCTAssertEqual(fiatState.receiveCardRateText, "5 TON")

        viewModel.toggleReceiveAmountInputMode()

        guard case let .loaded(cryptoState) = viewModel.state else {
            return XCTFail("Expected loaded state")
        }
        XCTAssertEqual(cryptoState.receiveAmountInputMode, .crypto)
        XCTAssertNil(cryptoState.receiveAmountFiatSymbol)
        XCTAssertEqual(cryptoState.receiveAmount, "5")
        XCTAssertEqual(cryptoState.receiveCardRateText, "$\u{2009}27.50")
    }

    @MainActor
    func test_toggleReceiveAmountInputModeIsIgnoredWithoutDisplayCurrencyPrice() async throws {
        let oneEth = BigUInt(10).power(18)
        let defaultAssetsService = DefaultAssetsServiceSpy(
            result: .success(
                initialAssets(
                    sendBalance: oneEth * 10,
                    receivePrice: 5.5
                )
            )
        )
        let viewModel = try makeViewModel(
            defaultAssetsService: defaultAssetsService,
            displayCurrency: XCTUnwrap(Currency(code: "EUR"))
        )

        await waitUntil(viewModel) {
            guard case .loaded = viewModel.state else {
                return false
            }
            return true
        }

        viewModel.toggleReceiveAmountInputMode()

        guard case let .loaded(state) = viewModel.state else {
            return XCTFail("Expected loaded state")
        }
        XCTAssertEqual(state.receiveAmountInputMode, .crypto)
        XCTAssertNil(state.receiveAmountFiatSymbol)
    }

    @MainActor
    func test_toggleReceiveAmountInputModeIsIgnoredWithoutAssetOrRoutePrice() async throws {
        let oneEth = BigUInt(10).power(18)
        let defaultAssetsService = DefaultAssetsServiceSpy(
            result: .success(
                initialAssets(
                    sendBalance: oneEth * 10,
                    receivePrice: nil,
                    usdFiatRate: Decimal(string: "0.9")
                )
            )
        )
        let viewModel = try makeViewModel(
            defaultAssetsService: defaultAssetsService,
            displayCurrency: XCTUnwrap(Currency(code: "EUR"))
        )

        await waitUntil(viewModel) {
            guard case .loaded = viewModel.state else {
                return false
            }
            return true
        }

        viewModel.toggleReceiveAmountInputMode()

        guard case let .loaded(state) = viewModel.state else {
            return XCTFail("Expected loaded state")
        }
        XCTAssertEqual(state.receiveAmountInputMode, .crypto)
        XCTAssertNil(state.receiveAmountFiatSymbol)
    }

    @MainActor
    func test_sendAmountQuoteRefreshIsDebouncedAndShowsLoading() async {
        let oneEth = BigUInt(10).power(18)
        let defaultAssetsService = DefaultAssetsServiceSpy(
            result: .success(initialAssets(sendBalance: oneEth * 10))
        )
        let swapService = SwapServiceSpy(
            quoteResult: .success(
                quote(
                    sourceAmount: oneEth.description,
                    estimatedDestinationAmount: "5000000000"
                )
            )
        )
        let debounce = TestGate()
        var debounces: [UInt64] = []
        let debounceEntered = TestSignal()
        let viewModel = makeViewModel(
            defaultAssetsService: defaultAssetsService,
            swapService: swapService,
            quoteDebounce: {
                debounces.append($0)
                debounceEntered.send()
                try await debounce.wait()
            }
        )

        await waitUntil(viewModel) {
            guard case .loaded = viewModel.state else {
                return false
            }
            return true
        }

        viewModel.updateSendAmount("1")

        guard case let .loaded(loadingState) = viewModel.state else {
            return XCTFail("Expected loaded state")
        }
        XCTAssertEqual(loadingState.quote.quoteState, .loading)
        XCTAssertTrue(loadingState.showsQuoteShimmer(in: .receive))
        let requests = await swapService.quoteRequests()
        XCTAssertEqual(requests.count, 0)
        await waitUntil(debounceEntered) { !debounces.isEmpty }
        XCTAssertEqual(debounces, [500_000_000])

        await debounce.open()
        await waitUntil(viewModel) {
            await swapService.quoteRequests().count == 1
        }
    }

    @MainActor
    func test_sendAmountRefreshPreservesReceiveAmountWhileQuoteIsLoadingAndReplacesItWhenReady() async {
        let oneEth = BigUInt(10).power(18)
        let twoEth = oneEth * 2
        let defaultAssetsService = DefaultAssetsServiceSpy(
            result: .success(initialAssets(sendBalance: oneEth * 10))
        )
        let swapService = SwapServiceSpy(
            quoteResults: [
                .success(
                    quote(
                        sourceAmount: oneEth.description,
                        estimatedDestinationAmount: "5000000000"
                    )
                ),
                .success(
                    quote(
                        sourceAmount: twoEth.description,
                        estimatedDestinationAmount: "6000000000"
                    )
                ),
            ]
        )
        let viewModel = makeViewModel(
            defaultAssetsService: defaultAssetsService,
            swapService: swapService
        )

        await waitUntil(viewModel) {
            guard case .loaded = viewModel.state else {
                return false
            }
            return true
        }

        viewModel.updateSendAmount("1")
        await waitUntil(viewModel) {
            guard case let .loaded(state) = viewModel.state else {
                return false
            }
            return state.quote.quoteState == .ready
                && state.receiveAmount == "5"
        }

        viewModel.updateSendAmount("2")

        guard case let .loaded(loadingState) = viewModel.state else {
            return XCTFail("Expected loaded state")
        }
        XCTAssertEqual(loadingState.quote.quoteState, .loading)
        XCTAssertEqual(loadingState.receiveAmount, "5")
        XCTAssertNil(loadingState.quote.selectedRoute)
        XCTAssertFalse(loadingState.showsQuoteShimmer(in: .receive))
        XCTAssertEqual(loadingState.validationState, .routeUnavailable)

        await waitUntil(viewModel) {
            guard case let .loaded(state) = viewModel.state else {
                return false
            }
            return state.quote.quoteState == .ready
                && state.receiveAmount == "6"
                && state.quote.selectedRoute?.sourceAmount == twoEth.description
        }
    }

    @MainActor
    func test_loadingQuoteDoesNotContinueUntilReadyRouteReturns() async {
        let oneEth = BigUInt(10).power(18)
        let defaultAssetsService = DefaultAssetsServiceSpy(
            result: .success(initialAssets(sendBalance: oneEth * 10))
        )
        let swapService = SwapServiceSpy(
            quoteResult: .success(
                quote(
                    sourceAmount: oneEth.description,
                    estimatedDestinationAmount: "5000000000"
                )
            )
        )
        var confirmationInput: MultichainSwapConfirmationInput?
        let viewModel = makeViewModel(
            defaultAssetsService: defaultAssetsService,
            swapService: swapService,
            onContinue: { input in
                confirmationInput = input
            }
        )

        await waitUntil(viewModel) {
            guard case .loaded = viewModel.state else {
                return false
            }
            return true
        }

        viewModel.updateSendAmount("1")
        viewModel.continueSwap()
        XCTAssertNil(confirmationInput)

        await waitUntil(viewModel) {
            guard case let .loaded(state) = viewModel.state else {
                return false
            }
            return state.quote.quoteState == .ready
        }

        viewModel.continueSwap()
        XCTAssertNotNil(confirmationInput)
    }

    @MainActor
    func test_swapButtonReportsSwapClickAndThePricingDetailsDoNot() async {
        let oneEth = BigUInt(10).power(18)
        let analytics = AnalyticsServiceSpy()
        let viewModel = makeViewModel(
            defaultAssetsService: DefaultAssetsServiceSpy(result: .success(initialAssets(sendBalance: oneEth * 10))),
            swapService: SwapServiceSpy(
                quoteResult: .success(quote(sourceAmount: oneEth.description, estimatedDestinationAmount: "5000000000"))
            ),
            analytics: analytics
        )
        await waitUntil(viewModel) {
            guard case .loaded = viewModel.state else {
                return false
            }
            return true
        }
        viewModel.updateSendAmount("1")
        await waitUntil(viewModel) {
            guard case let .loaded(state) = viewModel.state else {
                return false
            }
            return state.quote.quoteState == .ready
        }

        viewModel.openPricingDetails()
        viewModel.confirmationDidClose()
        viewModel.continueSwap()

        XCTAssertEqual(analytics.events.map(\.name), ["swap_click"])
        let click = analytics.events.first?.args ?? [:]
        XCTAssertEqual(click["type"] as? String, "native")
        XCTAssertEqual(click["wallet_mode"] as? String, "multi")
        XCTAssertEqual(click["asset_from"] as? String, "eth/mainnet/coin")
        XCTAssertEqual(click["asset_to"] as? String, "ton/mainnet/coin")
        XCTAssertEqual(click["is_max"] as? Bool, false)
    }

    @MainActor
    func test_readyQuoteActivelyExpiresAndStopsContinue() async {
        let oneEth = BigUInt(10).power(18)
        let defaultAssetsService = DefaultAssetsServiceSpy(
            result: .success(initialAssets(sendBalance: oneEth * 10))
        )
        let swapService = SwapServiceSpy(
            quoteResult: .success(
                quote(
                    sourceAmount: oneEth.description,
                    estimatedDestinationAmount: "5000000000",
                    expiresIn: 1.2
                )
            )
        )
        var confirmationInputs = [MultichainSwapConfirmationInput]()
        let expiry = TestGate()
        let viewModel = makeViewModel(
            defaultAssetsService: defaultAssetsService,
            swapService: swapService,
            onContinue: { input in
                confirmationInputs.append(input)
            },
            routeExpiryWait: { _ in try await expiry.wait() }
        )

        await waitUntil(viewModel) {
            guard case .loaded = viewModel.state else {
                return false
            }
            return true
        }

        viewModel.updateSendAmount("1")
        await waitUntil(viewModel) {
            guard case let .loaded(state) = viewModel.state else {
                return false
            }
            return state.quote.quoteState == .ready
                && state.validationState == .valid
        }

        viewModel.continueSwap()
        XCTAssertEqual(confirmationInputs.count, 1)
        viewModel.confirmationDidClose()
        await expiry.open()

        await waitUntil(viewModel) {
            guard case let .loaded(state) = viewModel.state else {
                return false
            }
            return state.quote.quoteState == .failed(.unavailable)
                && state.quote.selectedRoute == nil
                && state.receiveAmount.isEmpty
                && state.validationState == .routeUnavailable
        }

        guard case let .loaded(failedState) = viewModel.state else {
            return XCTFail("Expected loaded state")
        }
        XCTAssertEqual(failedState.quote.quoteState, .failed(.unavailable))

        viewModel.continueSwap()
        XCTAssertEqual(confirmationInputs.count, 1)
    }

    /// The timer does not refresh a failed quote; the confirmation's "Try again" asks for a new one.
    @MainActor
    func test_freshQuoteRequestReplacesAnExpiredRoute() async {
        let oneEth = BigUInt(10).power(18)
        let defaultAssetsService = DefaultAssetsServiceSpy(
            result: .success(initialAssets(sendBalance: oneEth * 10))
        )
        let swapService = SwapServiceSpy(
            quoteResults: [
                .success(
                    quote(
                        sourceAmount: oneEth.description,
                        estimatedDestinationAmount: "5000000000",
                        expiresIn: 1.2
                    )
                ),
                .success(
                    quote(
                        sourceAmount: oneEth.description,
                        estimatedDestinationAmount: "5000000000"
                    )
                ),
            ]
        )
        let neverExpires = TestGate()
        let viewModel = makeViewModel(
            defaultAssetsService: defaultAssetsService,
            swapService: swapService,
            routeExpiryWait: { nanoseconds in
                if nanoseconds > 10_000_000_000 {
                    try await neverExpires.wait()
                }
            }
        )

        await waitUntil(viewModel) {
            guard case .loaded = viewModel.state else {
                return false
            }
            return true
        }
        viewModel.updateSendAmount("1")
        await waitUntil(viewModel) {
            guard case let .loaded(state) = viewModel.state else {
                return false
            }
            return state.quote.quoteState == .failed(.unavailable)
        }

        viewModel.requestFreshQuote()

        await waitUntil(viewModel) {
            guard case let .loaded(state) = viewModel.state else {
                return false
            }
            return state.quote.quoteState == .ready
                && state.validationState == .valid
        }
        let requests = await swapService.quoteRequests()
        XCTAssertEqual(requests.count, 2)
    }

    @MainActor
    func test_pairChangeRefreshesQuoteWithoutDebounce() async {
        let oneEth = BigUInt(10).power(18)
        let defaultAssetsService = DefaultAssetsServiceSpy(
            result: .success(initialAssets(sendBalance: oneEth * 10))
        )
        let swapService = SwapServiceSpy(
            quoteResults: [
                .success(
                    quote(
                        sourceAmount: oneEth.description,
                        estimatedDestinationAmount: "5000000000"
                    )
                ),
            ],
            quoteHolds: [TestGate(), nil]
        )
        let viewModel = makeViewModel(
            defaultAssetsService: defaultAssetsService,
            swapService: swapService
        )

        await waitUntil(viewModel) {
            guard case .loaded = viewModel.state else {
                return false
            }
            return true
        }

        viewModel.updateSendAmount("1")
        await waitUntil(swapService.changes) {
            await swapService.quoteRequests().count == 1
        }

        viewModel.applyReceiveAsset(
            asset(
                assetId: "ton/mainnet/usdt",
                symbol: "USDT",
                decimals: 6
            )
        )

        guard case let .loaded(loadingState) = viewModel.state else {
            return XCTFail("Expected loaded state")
        }
        XCTAssertEqual(loadingState.quote.quoteState, .loading)
        await waitUntil(swapService.changes) {
            await swapService.quoteRequests().count == 2
        }
    }

    @MainActor
    func test_confirmationUsesSelectedRouteAmountsInsteadOfDisplayedText() async {
        let oneEth = BigUInt(10).power(18)
        let routeSourceAmount = oneEth + (oneEth / 4)
        let defaultAssetsService = DefaultAssetsServiceSpy(
            result: .success(initialAssets(sendBalance: oneEth * 10))
        )
        let swapService = SwapServiceSpy(
            quoteResult: .success(
                quote(
                    sourceAmount: routeSourceAmount.description,
                    estimatedDestinationAmount: "4560000000"
                )
            )
        )
        var confirmationInput: MultichainSwapConfirmationInput?
        let viewModel = makeViewModel(
            defaultAssetsService: defaultAssetsService,
            swapService: swapService,
            onContinue: { input in
                confirmationInput = input
            }
        )

        await waitUntil(viewModel) {
            guard case .loaded = viewModel.state else {
                return false
            }
            return true
        }

        viewModel.updateSendAmount("1")
        await waitUntil(viewModel) {
            guard case let .loaded(state) = viewModel.state else {
                return false
            }
            return state.quote.quoteState == .ready
        }

        viewModel.continueSwap()

        XCTAssertEqual(
            confirmationInput?.quoteState.route.estimatedDestinationAmount,
            "4560000000"
        )
        XCTAssertEqual(confirmationInput?.sourceAmount, routeSourceAmount)
    }

    @MainActor
    func test_routeSourceAmountAboveBalanceShowsInsufficientBalanceAndDoesNotContinue() async {
        let oneEth = BigUInt(10).power(18)
        let routeSourceAmount = oneEth + (oneEth / 4)
        let defaultAssetsService = DefaultAssetsServiceSpy(
            result: .success(initialAssets(sendBalance: oneEth))
        )
        let swapService = SwapServiceSpy(
            quoteResult: .success(
                quote(
                    sourceAmount: routeSourceAmount.description,
                    estimatedDestinationAmount: "4560000000"
                )
            )
        )
        var confirmationInput: MultichainSwapConfirmationInput?
        let viewModel = makeViewModel(
            defaultAssetsService: defaultAssetsService,
            swapService: swapService,
            onContinue: { input in
                confirmationInput = input
            }
        )

        await waitUntil(viewModel) {
            guard case .loaded = viewModel.state else {
                return false
            }
            return true
        }

        viewModel.updateSendAmount("1")
        await waitUntil(viewModel) {
            guard case let .loaded(state) = viewModel.state else {
                return false
            }
            return state.quote.quoteState == .ready
                && state.validationState == .insufficientBalance
        }

        guard case let .loaded(state) = viewModel.state else {
            return XCTFail("Expected loaded state")
        }
        XCTAssertEqual(state.validationState, .insufficientBalance)
        viewModel.continueSwap()
        XCTAssertNil(confirmationInput)
    }

    /// A max quote whose echoed `source_amount` is a few base units above the balance
    /// is the balance that was sent, not a larger trade.
    @MainActor
    func test_maxQuoteEchoRoundedAboveBalance_confirmsTheSentBalance() async throws {
        let balance = try XCTUnwrap(BigUInt("4181445029473734404"))
        let defaultAssetsService = DefaultAssetsServiceSpy(
            result: .success(initialAssets(sendBalance: balance))
        )
        let swapService = SwapServiceSpy(
            quoteResult: .success(
                quote(
                    sourceAmount: (balance + 596).description,
                    estimatedDestinationAmount: "3976271"
                )
            )
        )
        var confirmationInput: MultichainSwapConfirmationInput?
        let viewModel = makeViewModel(
            defaultAssetsService: defaultAssetsService,
            swapService: swapService,
            onContinue: { input in
                confirmationInput = input
            }
        )

        await waitUntil(viewModel) {
            guard case .loaded = viewModel.state else {
                return false
            }
            return true
        }

        viewModel.applySendPercent(100)
        await waitUntil(viewModel) {
            guard case let .loaded(state) = viewModel.state else {
                return false
            }
            return state.quote.quoteState == .ready
                && state.validationState == .valid
        }

        viewModel.continueSwap()
        XCTAssertEqual(confirmationInput?.sourceAmount, balance)
        XCTAssertEqual(confirmationInput?.userInput.isMax, true)
    }

    @MainActor
    func test_pairChangeClearsStaleReceiveAmountAndSelectedRoute() async {
        let oneEth = BigUInt(10).power(18)
        let defaultAssetsService = DefaultAssetsServiceSpy(
            result: .success(initialAssets(sendBalance: oneEth * 10))
        )
        let swapService = SwapServiceSpy(
            quoteResults: [
                .success(
                    quote(
                        sourceAmount: oneEth.description,
                        estimatedDestinationAmount: "5000000000"
                    )
                ),
                .success(
                    quote(
                        sourceAmount: oneEth.description,
                        estimatedDestinationAmount: "7000000"
                    )
                ),
            ]
        )
        let viewModel = makeViewModel(
            defaultAssetsService: defaultAssetsService,
            swapService: swapService
        )

        await waitUntil(viewModel) {
            guard case .loaded = viewModel.state else {
                return false
            }
            return true
        }

        viewModel.updateSendAmount("1")
        await waitUntil(viewModel) {
            guard case let .loaded(state) = viewModel.state else {
                return false
            }
            return state.quote.quoteState == .ready
                && state.receiveAmount == "5"
                && state.quote.selectedRoute != nil
        }

        viewModel.applyReceiveAsset(
            asset(
                assetId: "ton/mainnet/usdt",
                symbol: "USDT",
                decimals: 6
            )
        )

        guard case let .loaded(pairChangeState) = viewModel.state else {
            return XCTFail("Expected loaded state")
        }
        XCTAssertEqual(pairChangeState.quote.quoteState, .loading)
        XCTAssertEqual(pairChangeState.receiveAmount, "")
        XCTAssertNil(pairChangeState.quote.selectedRoute)
        XCTAssertTrue(pairChangeState.showsQuoteShimmer(in: .receive))
        XCTAssertEqual(pairChangeState.validationState, .routeUnavailable)
    }

    @MainActor
    func test_swapTokensMovesSendAmountToReceiveFieldAndClearsRoute() async {
        let oneEth = BigUInt(10).power(18)
        let oneTon = BigUInt(10).power(9)
        let defaultAssetsService = DefaultAssetsServiceSpy(
            result: .success(
                initialAssets(
                    sendBalance: oneEth * 10,
                    receiveBalance: oneTon * 10
                )
            )
        )
        let swapService = SwapServiceSpy(
            quoteResults: [
                .success(
                    quote(
                        sourceAmount: oneEth.description,
                        estimatedDestinationAmount: (oneTon * 5).description
                    )
                ),
                .success(
                    quote(
                        sourceAmount: (oneTon * 5).description,
                        estimatedDestinationAmount: oneEth.description
                    )
                ),
            ]
        )
        let viewModel = makeViewModel(
            defaultAssetsService: defaultAssetsService,
            swapService: swapService
        )

        await waitUntil(viewModel) {
            guard case .loaded = viewModel.state else {
                return false
            }
            return true
        }

        viewModel.updateSendAmount("1")
        await waitUntil(viewModel) {
            guard case let .loaded(state) = viewModel.state else {
                return false
            }
            return state.quote.quoteState == .ready
                && state.sendAmount == "1"
                && state.receiveAmount == "5"
        }

        viewModel.swapTokens()

        guard case let .loaded(swappedState) = viewModel.state else {
            return XCTFail("Expected loaded state")
        }
        XCTAssertEqual(swappedState.sendAsset.asset.symbol, "TON")
        XCTAssertEqual(swappedState.receiveAsset.asset.symbol, "ETH")
        XCTAssertEqual(swappedState.sendAmount, "5")
        XCTAssertEqual(swappedState.receiveAmount, "1")
        XCTAssertEqual(swappedState.quote.quoteState, .loading)
        XCTAssertFalse(swappedState.showsQuoteShimmer(in: .receive))
        XCTAssertNil(swappedState.quote.selectedRoute)
        XCTAssertEqual(swappedState.validationState, .routeUnavailable)
    }

    @MainActor
    func test_swapTokensCarriesFiatSendAmountAsCryptoReceiveAmount() async {
        let oneEth = BigUInt(10).power(18)
        let oneTon = BigUInt(10).power(9)
        let defaultAssetsService = DefaultAssetsServiceSpy(
            result: .success(
                initialAssets(
                    sendBalance: oneEth * 10,
                    receiveBalance: oneTon * 10,
                    sendPrice: 2
                )
            )
        )
        let swapService = SwapServiceSpy(
            quoteResults: [
                .success(
                    quote(
                        sourceAmount: oneEth.description,
                        estimatedDestinationAmount: (oneTon * 5).description
                    )
                ),
                .success(
                    quote(
                        sourceAmount: (oneTon * 5).description,
                        estimatedDestinationAmount: oneEth.description
                    )
                ),
            ]
        )
        let viewModel = makeViewModel(
            defaultAssetsService: defaultAssetsService,
            swapService: swapService
        )

        await waitUntil(viewModel) {
            guard case .loaded = viewModel.state else {
                return false
            }
            return true
        }

        viewModel.updateSendAmount("1")
        await waitUntil(viewModel) {
            guard case let .loaded(state) = viewModel.state else {
                return false
            }
            return state.quote.quoteState == .ready
                && state.receiveAmount == "5"
        }
        viewModel.toggleSendAmountInputMode()

        guard case let .loaded(fiatState) = viewModel.state else {
            return XCTFail("Expected loaded state")
        }
        XCTAssertEqual(fiatState.sendAmountInputMode, .fiat)
        XCTAssertEqual(fiatState.sendAmount, "2")

        viewModel.swapTokens()

        guard case let .loaded(swappedState) = viewModel.state else {
            return XCTFail("Expected loaded state")
        }
        XCTAssertEqual(swappedState.sendAmountInputMode, .crypto)
        XCTAssertEqual(swappedState.sendAsset.asset.symbol, "TON")
        XCTAssertEqual(swappedState.receiveAsset.asset.symbol, "ETH")
        XCTAssertEqual(swappedState.sendAmount, "5")
        XCTAssertEqual(swappedState.receiveAmount, "1")
    }

    @MainActor
    func test_swapTokensWithZeroReceiveAmountKeepsSendAmountAndRequestsNewQuote() async {
        let oneEth = BigUInt(10).power(18)
        let oneTon = BigUInt(10).power(9)
        let defaultAssetsService = DefaultAssetsServiceSpy(
            result: .success(
                initialAssets(
                    sendBalance: oneEth * 10,
                    receiveBalance: oneTon * 10
                )
            )
        )
        let swapService = SwapServiceSpy(quoteResult: .failure(.unimplemented))
        let viewModel = makeViewModel(
            defaultAssetsService: defaultAssetsService,
            swapService: swapService
        )

        await waitUntil(viewModel) {
            guard case .loaded = viewModel.state else {
                return false
            }
            return true
        }

        viewModel.updateSendAmount("1")
        await waitUntil(viewModel) {
            guard case let .loaded(state) = viewModel.state else {
                return false
            }
            if case .failed = state.quote.quoteState {
                return true
            }
            return false
        }

        let requestCountBeforeSwap = await swapService.quoteRequests().count

        viewModel.swapTokens()

        guard case let .loaded(swappedState) = viewModel.state else {
            return XCTFail("Expected loaded state")
        }
        XCTAssertEqual(swappedState.sendAsset.asset.symbol, "TON")
        XCTAssertEqual(swappedState.receiveAsset.asset.symbol, "ETH")
        XCTAssertEqual(swappedState.sendAmount, "1")
        XCTAssertEqual(swappedState.receiveAmount, "")

        await waitUntil(swapService.changes) {
            await swapService.quoteRequests().count > requestCountBeforeSwap
        }
    }

    @MainActor
    func test_oldInFlightPairQuoteCannotOverwriteSnapshotAfterPairSwitch() async throws {
        let oneEth = BigUInt(10).power(18)
        let defaultAssetsService = DefaultAssetsServiceSpy(
            result: .success(initialAssets(sendBalance: oneEth * 10))
        )
        let staleQuote = TestGate()
        let swapService = SwapServiceSpy(
            quoteResults: [
                .success(
                    quote(
                        sourceAmount: oneEth.description,
                        estimatedDestinationAmount: "5000000000"
                    )
                ),
                .success(
                    quote(
                        sourceAmount: oneEth.description,
                        estimatedDestinationAmount: "7000000"
                    )
                ),
            ],
            quoteHolds: [staleQuote, nil],
            ignoreQuoteHoldCancellation: true
        )
        let viewModel = makeViewModel(
            defaultAssetsService: defaultAssetsService,
            swapService: swapService
        )

        await waitUntil(viewModel) {
            guard case .loaded = viewModel.state else {
                return false
            }
            return true
        }

        viewModel.updateSendAmount("1")
        await waitUntil(swapService.changes) {
            await swapService.quoteRequests().count == 1
        }
        let staleQuoteTask = try XCTUnwrap(viewModel.quoteViewModel.activePairViewModel?.quoteTask)

        viewModel.applyReceiveAsset(
            asset(
                assetId: "ton/mainnet/usdt",
                symbol: "USDT",
                decimals: 6
            )
        )

        await waitUntil(viewModel) {
            guard case let .loaded(state) = viewModel.state else {
                return false
            }
            return state.quote.quoteState == .ready
                && state.receiveAsset.asset.symbol == "USDT"
                && state.receiveAmount == "7"
        }

        await staleQuote.open()
        await staleQuoteTask.value

        guard case let .loaded(finalState) = viewModel.state else {
            return XCTFail("Expected loaded state")
        }
        XCTAssertEqual(finalState.receiveAsset.asset.symbol, "USDT")
        XCTAssertEqual(finalState.receiveAmount, "7")
        XCTAssertEqual(finalState.quote.selectedRoute?.estimatedDestinationAmount, "7000000")

        let requests = await swapService.quoteRequests()
        XCTAssertEqual(requests.count, 2)
        XCTAssertEqual(requests.first?.destinationAsset, "ton/mainnet/coin")
        XCTAssertEqual(requests.last?.destinationAsset, "ton/mainnet/usdt")
    }

    @MainActor
    func test_countdownRefreshRestartsTheCycleOnlyAfterSuccessfulQuote() async {
        let oneEth = BigUInt(10).power(18)
        let defaultAssetsService = DefaultAssetsServiceSpy(
            result: .success(initialAssets(sendBalance: oneEth * 10))
        )
        let refresh = TestGate()
        let swapService = SwapServiceSpy(
            quoteResults: [
                .success(
                    quote(
                        sourceAmount: oneEth.description,
                        estimatedDestinationAmount: "5000000000"
                    )
                ),
                .success(
                    quote(
                        sourceAmount: oneEth.description,
                        estimatedDestinationAmount: "6000000000"
                    )
                ),
            ],
            quoteHolds: [nil, refresh]
        )
        let viewModel = makeViewModel(
            defaultAssetsService: defaultAssetsService,
            swapService: swapService
        )

        await waitUntil(viewModel) {
            guard case .loaded = viewModel.state else {
                return false
            }
            return true
        }
        viewModel.updateSendAmount("1")
        await waitUntil(viewModel) {
            guard case let .loaded(state) = viewModel.state else {
                return false
            }
            return state.quote.quoteState == .ready
        }

        guard let firstCycle = viewModel.quoteRefreshCycle else {
            return XCTFail("Expected the ready quote's countdown")
        }

        viewModel.quoteCountdownDidFinish()

        guard case let .loaded(loadingState) = viewModel.state else {
            return XCTFail("Expected loaded state")
        }
        XCTAssertEqual(loadingState.quote.quoteState, .loading)
        XCTAssertNil(viewModel.quoteRefreshCycle)
        await waitUntil(swapService.changes) {
            await swapService.quoteRequests().count == 2
        }

        XCTAssertNil(viewModel.quoteRefreshCycle)

        await refresh.open()

        await waitUntil(viewModel) {
            guard case let .loaded(state) = viewModel.state else {
                return false
            }
            return state.quote.quoteState == .ready
                && state.receiveAmount == "6"
        }
        let secondCycle = viewModel.quoteRefreshCycle
        XCTAssertNotNil(secondCycle)
        XCTAssertGreaterThan(secondCycle?.startDate ?? .distantPast, firstCycle.startDate)
    }

    /// The screen shows no countdown, so a ready quote refreshes itself when its countdown runs out.
    @MainActor
    func test_readyQuoteRefreshesWhenItsCountdownRunsOut() async {
        let oneEth = BigUInt(10).power(18)
        let defaultAssetsService = DefaultAssetsServiceSpy(
            result: .success(initialAssets(sendBalance: oneEth * 10))
        )
        let swapService = SwapServiceSpy(
            quoteResults: [
                .success(quote(sourceAmount: oneEth.description, estimatedDestinationAmount: "5000000000")),
                .success(quote(sourceAmount: oneEth.description, estimatedDestinationAmount: "6000000000")),
            ]
        )
        let viewModel = makeViewModel(
            defaultAssetsService: defaultAssetsService,
            swapService: swapService,
            quoteRefreshDuration: 0.3
        )

        await waitUntil(viewModel) {
            guard case .loaded = viewModel.state else {
                return false
            }
            return true
        }
        viewModel.updateSendAmount("1")
        await waitUntil(viewModel) {
            guard case let .loaded(state) = viewModel.state else {
                return false
            }
            return state.quote.quoteState == .ready && state.receiveAmount == "6"
        }

        guard case let .loaded(state) = viewModel.state else {
            return XCTFail("Expected loaded state")
        }
        XCTAssertEqual(state.receiveAmount, "6")
    }

    /// A swap that failed to send stands in for the presets and the Swap button for a while, and gives
    /// way at once when the swap changes.
    @MainActor
    func test_sendFailureShowsForAWhileOrUntilTheSwapChanges() async {
        let viewModel = makeViewModel(
            defaultAssetsService: DefaultAssetsServiceSpy(result: .success(initialAssets())),
            sendFailureWait: { _ in }
        )
        await waitUntil(viewModel) {
            guard case .loaded = viewModel.state else {
                return false
            }
            return true
        }

        viewModel.swapDidFailToSend(.retryable("Insufficient balance"))

        XCTAssertEqual(viewModel.sendFailure, .retryable("Insufficient balance"))
        await waitUntil(viewModel) { viewModel.sendFailure == nil }

        viewModel.swapDidFailToSend(.retryable("Insufficient balance"))
        viewModel.updateSendAmount("5")

        XCTAssertNil(viewModel.sendFailure)
    }

    /// The relayer may still hold the message of a send whose outcome is unknown, and a second one could
    /// swap twice: the same pair and amount are not offered again, whatever else changes or however long
    /// it takes, until the swap itself changes.
    @MainActor
    func test_sendWithAnUnknownOutcomeKeepsTheSameSwapBackUntilTheSwapChanges() async {
        let oneEth = BigUInt(10).power(18)
        let swapService = SwapServiceSpy(
            quoteResult: .success(
                quote(
                    sourceAmount: oneEth.description,
                    estimatedDestinationAmount: "5000000000"
                )
            )
        )
        var continued = 0
        var detailsOpened = 0
        let viewModel = makeViewModel(
            defaultAssetsService: DefaultAssetsServiceSpy(result: .success(initialAssets(sendBalance: oneEth * 10))),
            swapService: swapService,
            onContinue: { _ in continued += 1 },
            onOpenPricingDetails: { _ in detailsOpened += 1 },
            sendFailureWait: { _ in }
        )
        let isReady = {
            guard case let .loaded(state) = viewModel.state else {
                return false
            }
            return state.validationState == .valid && state.quote.quoteState == .ready
        }
        await waitUntil(viewModel) {
            guard case .loaded = viewModel.state else {
                return false
            }
            return true
        }
        viewModel.updateSendAmount("1")
        await waitUntil(viewModel, isReady)

        viewModel.swapDidFailToSend(.outcomeUnknown)
        viewModel.setSlippageBps(300)
        await waitUntil(viewModel, isReady)
        viewModel.continueSwap()
        viewModel.openPricingDetails()

        XCTAssertEqual(viewModel.sendFailure, .outcomeUnknown)
        XCTAssertNil(viewModel.confirmationPhase)
        XCTAssertEqual(continued, 0)
        XCTAssertEqual(detailsOpened, 0)

        viewModel.updateSendAmount("2")
        XCTAssertNil(viewModel.sendFailure)
        await waitUntil(viewModel, isReady)
        viewModel.continueSwap()

        XCTAssertEqual(continued, 1)
    }

    /// One quote and one countdown: the pricing details show the screen's, so opening them neither asks
    /// for a quote nor restarts the countdown, and the screen's refresh is what reaches them.
    @MainActor
    func test_pricingDetailsFollowTheScreenQuoteAndItsCountdown() async throws {
        let oneEth = BigUInt(10).power(18)
        let defaultAssetsService = DefaultAssetsServiceSpy(
            result: .success(initialAssets(sendBalance: oneEth * 10))
        )
        let swapService = SwapServiceSpy(
            quoteResults: [
                .success(quote(sourceAmount: oneEth.description, estimatedDestinationAmount: "5000000000")),
                .success(quote(sourceAmount: oneEth.description, estimatedDestinationAmount: "6000000000")),
            ]
        )
        var updates = [MultichainSwapConfirmationQuoteUpdate]()
        let viewModel = makeViewModel(
            defaultAssetsService: defaultAssetsService,
            swapService: swapService
        )
        viewModel.onConfirmationQuoteChange = { updates.append($0) }

        await waitUntil(viewModel) {
            guard case .loaded = viewModel.state else {
                return false
            }
            return true
        }
        viewModel.updateSendAmount("1")
        await waitUntil(viewModel) {
            guard case let .loaded(state) = viewModel.state else {
                return false
            }
            return state.validationState == .valid && state.quote.quoteState == .ready
        }
        let openedCycle = try XCTUnwrap(viewModel.quoteRefreshCycle)

        viewModel.openPricingDetails()

        let requestsAtOpen = await swapService.quoteRequests().count
        XCTAssertTrue(updates.isEmpty)
        XCTAssertEqual(viewModel.quoteRefreshCycle, openedCycle)

        viewModel.quoteCountdownDidFinish()
        await waitUntil(viewModel) {
            guard case .ready = updates.last else {
                return false
            }
            return true
        }

        guard case .loading = updates.first, case let .ready(input, cycle) = updates.last else {
            return XCTFail("Expected the refresh to reach the pricing details as loading, then ready")
        }
        XCTAssertEqual(input.quoteState.route.estimatedDestinationAmount, "6000000000")
        XCTAssertGreaterThan(cycle.startDate, openedCycle.startDate)
        let requestsAfterRefresh = await swapService.quoteRequests().count
        XCTAssertEqual(requestsAfterRefresh, requestsAtOpen + 1)

        let focusRequestID = viewModel.focusRequestID
        viewModel.confirmationDidClose()

        let requestsAfterClose = await swapService.quoteRequests().count
        XCTAssertEqual(requestsAfterClose, requestsAfterRefresh)
        XCTAssertEqual(viewModel.focusRequestID, focusRequestID + 1)
    }

    /// The pricing details hear why the screen has no quote, here a refresh that never reached the server.
    @MainActor
    func test_pricingDetailsLearnWhyTheScreenQuoteFailed() async {
        let oneEth = BigUInt(10).power(18)
        let defaultAssetsService = DefaultAssetsServiceSpy(
            result: .success(initialAssets(sendBalance: oneEth * 10))
        )
        let swapService = SwapServiceSpy(
            quoteResults: [
                .success(quote(sourceAmount: oneEth.description, estimatedDestinationAmount: "5000000000")),
                .failure(
                    .transportError(diagnostic: MultichainAPIDiagnostic(error: URLError(.notConnectedToInternet)))
                ),
            ]
        )
        var updates = [MultichainSwapConfirmationQuoteUpdate]()
        let viewModel = makeViewModel(
            defaultAssetsService: defaultAssetsService,
            swapService: swapService
        )
        let quoteChanges = TestSignal()
        viewModel.onConfirmationQuoteChange = {
            updates.append($0)
            quoteChanges.send()
        }

        await waitUntil(viewModel) {
            if case .loaded = viewModel.state { return true }
            return false
        }
        viewModel.updateSendAmount("1")
        await waitUntil(viewModel) {
            guard case let .loaded(state) = viewModel.state else {
                return false
            }
            return state.validationState == .valid && state.quote.quoteState == .ready
        }
        viewModel.openPricingDetails()
        viewModel.quoteCountdownDidFinish()
        await waitUntil(quoteChanges) {
            guard case .failed = updates.last else {
                return false
            }
            return true
        }

        guard case let .failed(failure) = updates.last else {
            return XCTFail("Expected the failed refresh to reach the pricing details")
        }
        XCTAssertEqual(failure, .quote(.offline))
    }

    /// A swap on its way pins the quote it was confirmed with. Releasing it catches up only on what the
    /// hold kept back: a countdown that ran out, a route that expired.
    @MainActor
    func test_heldQuoteNeitherRefreshesNorExpiresAndCatchesUpOnRelease() async throws {
        let oneEth = BigUInt(10).power(18)
        let defaultAssetsService = DefaultAssetsServiceSpy(
            result: .success(initialAssets(sendBalance: oneEth * 10))
        )
        let swapService = SwapServiceSpy(
            quoteResult: .success(
                quote(
                    sourceAmount: oneEth.description,
                    estimatedDestinationAmount: "5000000000",
                    expiresIn: 1.2
                )
            )
        )
        var confirmationInput: MultichainSwapConfirmationInput?
        var clock = Date()
        let expiry = TestGate()
        let expired = expectation(description: "the route's lifetime is over")
        let viewModel = makeViewModel(
            defaultAssetsService: defaultAssetsService,
            swapService: swapService,
            onContinue: { confirmationInput = $0 },
            routeExpiryWait: { _ in
                try await expiry.wait()
                expired.fulfill()
            },
            now: { clock }
        )

        await waitUntil(viewModel) {
            guard case .loaded = viewModel.state else {
                return false
            }
            return true
        }
        viewModel.updateSendAmount("1")
        await waitUntil(viewModel) {
            guard case let .loaded(state) = viewModel.state else {
                return false
            }
            return state.validationState == .valid && state.quote.quoteState == .ready
        }
        viewModel.continueSwap()
        let routeExpiry = try XCTUnwrap(confirmationInput?.quoteState.route.dateExpire)

        viewModel.setQuoteHeld(true)
        viewModel.setQuoteHeld(false)
        guard case let .loaded(releasedEarlyState) = viewModel.state else {
            return XCTFail("Expected loaded state")
        }
        XCTAssertEqual(releasedEarlyState.quote.quoteState, .ready)

        viewModel.setQuoteHeld(true)
        viewModel.quoteCountdownDidFinish()
        clock = routeExpiry
        await expiry.open()
        await fulfillment(of: [expired], timeout: 5)

        guard case let .loaded(heldState) = viewModel.state else {
            return XCTFail("Expected loaded state")
        }
        XCTAssertEqual(heldState.quote.quoteState, .ready)
        XCTAssertEqual(heldState.receiveAmount, "5")
        let requestsWhileHeld = await swapService.quoteRequests().count
        XCTAssertEqual(requestsWhileHeld, 1)

        viewModel.setQuoteHeld(false)

        guard case let .loaded(releasedState) = viewModel.state else {
            return XCTFail("Expected loaded state")
        }
        XCTAssertEqual(releasedState.quote.quoteState, .loading)
    }

    /// A countdown that runs out while a swap holds the quote asks for a fresh one once the hold ends.
    @MainActor
    func test_heldQuoteWhoseCountdownRanOutRefreshesOnRelease() async throws {
        let oneEth = BigUInt(10).power(18)
        let swapService = SwapServiceSpy(
            quoteResult: .success(
                quote(
                    sourceAmount: oneEth.description,
                    estimatedDestinationAmount: "5000000000"
                )
            )
        )
        var clock = Date()
        let viewModel = makeViewModel(
            defaultAssetsService: DefaultAssetsServiceSpy(result: .success(initialAssets(sendBalance: oneEth * 10))),
            swapService: swapService,
            quoteRefreshDuration: 0.3,
            now: { clock }
        )
        await waitUntil(viewModel) {
            guard case .loaded = viewModel.state else {
                return false
            }
            return true
        }
        viewModel.updateSendAmount("1")
        await waitUntil(viewModel) {
            guard case let .loaded(state) = viewModel.state else {
                return false
            }
            return state.quote.quoteState == .ready
        }

        viewModel.setQuoteHeld(true)
        let cycle = try XCTUnwrap(viewModel.quoteRefreshCycle)
        clock = cycle.startDate.addingTimeInterval(cycle.duration)
        guard case let .loaded(heldState) = viewModel.state else {
            return XCTFail("Expected loaded state")
        }
        XCTAssertNotEqual(heldState.quote.quoteState, .loading, "no requote is pending")
        viewModel.quoteCountdownDidFinish()
        let requestsWhileHeld = await swapService.quoteRequests().count
        XCTAssertEqual(requestsWhileHeld, 1)

        viewModel.setQuoteHeld(false)

        guard case let .loaded(releasedState) = viewModel.state else {
            return XCTFail("Expected loaded state")
        }
        XCTAssertEqual(releasedState.quote.quoteState, .loading)
    }

    @MainActor
    func test_pricingDetailsPicksCarryIntoTheNextQuoteAndTheSwap() async {
        let oneEth = BigUInt(10).power(18)
        let defaultAssetsService = DefaultAssetsServiceSpy(
            result: .success(initialAssets(sendBalance: oneEth * 10))
        )
        let swapService = SwapServiceSpy(
            quoteResult: .success(
                quote(
                    sourceAmount: oneEth.description,
                    estimatedDestinationAmount: "5000000000"
                )
            )
        )
        var detailsInput: MultichainSwapConfirmationInput?
        var swapInput: MultichainSwapConfirmationInput?
        let viewModel = makeViewModel(
            defaultAssetsService: defaultAssetsService,
            swapService: swapService,
            onContinue: { swapInput = $0 },
            onOpenPricingDetails: { detailsInput = $0 }
        )
        let isReady = {
            guard case let .loaded(state) = viewModel.state else {
                return false
            }
            return state.validationState == .valid && state.quote.quoteState == .ready
        }

        await waitUntil(viewModel) {
            guard case .loaded = viewModel.state else {
                return false
            }
            return true
        }
        viewModel.updateSendAmount("1")
        await waitUntil(viewModel, isReady)

        viewModel.openPricingDetails()
        XCTAssertEqual(viewModel.confirmationPhase, .pricingDetails)
        let quotedSlippageBps = await swapService.quoteRequests().last?.slippageBps
        XCTAssertEqual(detailsInput?.userInput.slippageBps, quotedSlippageBps)

        viewModel.setSlippageBps(300)
        viewModel.setFeeMethod(.battery)
        await waitUntil(swapService.changes) {
            await swapService.quoteRequests().last?.slippageBps == 300
        }
        viewModel.confirmationDidClose()
        await waitUntil(viewModel, isReady)

        viewModel.continueSwap()
        XCTAssertEqual(viewModel.confirmationPhase, .swapping)
        XCTAssertEqual(swapInput?.userInput.slippageBps, 300)
        XCTAssertEqual(swapInput?.userInput.feeMethod, .battery)
    }

    /// A registered wallet that signs with its own mnemonic is quoted on `/v3` while the flag is on, and
    /// the route it is shown remembers it.
    @MainActor
    func test_aRegisteredWalletOfItsOwnMnemonicIsQuotedOnV3WhileTheFlagIsOn() async {
        let swapService = SwapServiceSpy(quoteResult: .success(quote(sourceAmount: oneEth.description, estimatedDestinationAmount: "5000000000")))
        let viewModel = makeViewModel(
            defaultAssetsService: DefaultAssetsServiceSpy(result: .success(initialAssets(sendBalance: oneEth * 10))),
            swapService: swapService,
            isSwapV3Enabled: true
        )

        await quoteOneEth(viewModel)

        let apiVersions = await swapService.quoteAPIVersions()
        XCTAssertEqual(apiVersions, [.v3])
        XCTAssertEqual(viewModel.makeConfirmationInput()?.quoteState.route.apiVersion, .v3)
    }

    /// With the flag off, a hardware wallet, a legacy wallet the backend does not know, and a bitcoin
    /// sale, whose memo chain-kit drops, are all quoted on `/v2`.
    @MainActor
    func test_aSwapIsQuotedOnV2WithTheFlagOffForALedgerALegacyWalletOrABitcoinSale() async {
        let state = MultichainWalletState(walletId: "wallet", addresses: [.init(chain: .eth, address: "0xwallet"), .init(chain: .ton, address: "tonwallet"), .init(chain: .btc, address: "bc1wallet")])
        let wallet = makeWallet(multichainState: state)
        let swaps: [(name: String, isOn: Bool, swapWallet: MultichainSwapWallet?, assets: MultichainSwapInitialAssets)] = [
            ("flag off", false, nil, initialAssets(sendBalance: oneEth * 10)),
            ("ledger", true, MultichainSwapWallet(wallet: wallet, addresses: state.addresses, registration: .registered(walletId: "wallet"), keys: .device), initialAssets(sendBalance: oneEth * 10)),
            ("legacy", true, MultichainSwapWallet(wallet: wallet, addresses: state.addresses, registration: .unregistered, keys: .legacy), initialAssets(sendBalance: oneEth * 10)),
            ("bitcoin", true, MultichainSwapWallet(wallet: wallet, registeredState: state), initialAssets(sendAssetId: "btc/mainnet/coin", sendSymbol: "BTC", sendDecimals: 8, sendBalance: 10_000_000_000)),
        ]

        for swap in swaps {
            let swapService = SwapServiceSpy(quoteResult: .success(quote(sourceAmount: "100000000", estimatedDestinationAmount: "5000000000")))
            let viewModel = makeViewModel(
                defaultAssetsService: DefaultAssetsServiceSpy(result: .success(swap.assets)),
                swapService: swapService,
                isSwapV3Enabled: swap.isOn,
                swapWallet: swap.swapWallet
            )

            await waitUntil(viewModel) {
                guard case .loaded = viewModel.state else { return false }
                return true
            }
            viewModel.updateSendAmount("1")
            await waitUntil(swapService.changes) { await !swapService.quoteAPIVersions().isEmpty }

            let apiVersions = await swapService.quoteAPIVersions()
            XCTAssertEqual(apiVersions, [.v2], swap.name)
        }
    }

    @MainActor
    func test_quoteFailureShowsQuoteUnavailableMessageAndStopsTimerCycle() async {
        let oneEth = BigUInt(10).power(18)
        let defaultAssetsService = DefaultAssetsServiceSpy(
            result: .success(initialAssets(sendBalance: oneEth * 10))
        )
        let swapService = SwapServiceSpy(
            quoteResult: .failure(.unimplemented)
        )
        let viewModel = makeViewModel(
            defaultAssetsService: defaultAssetsService,
            swapService: swapService
        )

        await waitUntil(viewModel) {
            guard case .loaded = viewModel.state else {
                return false
            }
            return true
        }
        viewModel.updateSendAmount("1")

        await waitUntil(viewModel) {
            guard case let .loaded(state) = viewModel.state else {
                return false
            }
            if case .failed = state.quote.quoteState {
                return true
            }
            return false
        }

        guard case let .loaded(failedState) = viewModel.state else {
            return XCTFail("Expected loaded state")
        }
        XCTAssertEqual(failedState.quote.quoteState, .failed(.unavailable))
        XCTAssertEqual(failedState.validationState, .routeUnavailable)
        XCTAssertNil(viewModel.quoteRefreshCycle)

        viewModel.quoteCountdownDidFinish()
        guard case let .loaded(afterCountdownState) = viewModel.state else {
            return XCTFail("Expected loaded state")
        }
        XCTAssertNotEqual(afterCountdownState.quote.quoteState, .loading, "no requote is pending")
        let requests = await swapService.quoteRequests()
        XCTAssertEqual(requests.count, 1)
    }

    @MainActor
    func test_resettingAmountStopsTheCountdown() async {
        let oneEth = BigUInt(10).power(18)
        let defaultAssetsService = DefaultAssetsServiceSpy(
            result: .success(initialAssets(sendBalance: oneEth * 10))
        )
        let swapService = SwapServiceSpy(
            quoteResult: .success(
                quote(
                    sourceAmount: oneEth.description,
                    estimatedDestinationAmount: "5000000000"
                )
            )
        )
        let viewModel = makeViewModel(
            defaultAssetsService: defaultAssetsService,
            swapService: swapService
        )

        await waitUntil(viewModel) {
            guard case .loaded = viewModel.state else {
                return false
            }
            return true
        }

        viewModel.updateSendAmount("1")
        await waitUntil(viewModel) {
            guard case let .loaded(state) = viewModel.state else {
                return false
            }
            return state.quote.quoteState == .ready
        }

        viewModel.updateSendAmount("")

        guard case let .loaded(state) = viewModel.state else {
            return XCTFail("Expected loaded state")
        }
        XCTAssertEqual(state.quote.quoteState, .idle)
        XCTAssertNil(viewModel.quoteRefreshCycle)
    }

    @MainActor
    func test_emptyRoutesReportsProviderErrorMessage() async {
        let oneEth = BigUInt(10).power(18)
        let providerMessage = "insufficient balance for source asset: The specified amount is too low."
        let defaultAssetsService = DefaultAssetsServiceSpy(
            result: .success(initialAssets(sendBalance: oneEth * 10))
        )
        let swapService = SwapServiceSpy(
            quoteResult: .success(
                MultichainSwapQuote(
                    quoteId: "quote",
                    routes: [],
                    providerErrors: [
                        MultichainSwapProviderError(
                            aggregator: "swapsxyz",
                            code: "provider_error",
                            message: providerMessage
                        ),
                    ]
                )
            )
        )
        var receivedMessage: String?
        let received = expectation(description: "provider error message")
        let viewModel = makeViewModel(
            defaultAssetsService: defaultAssetsService,
            swapService: swapService,
            onQuoteProviderError: {
                receivedMessage = $0
                received.fulfill()
            }
        )

        await waitUntil(viewModel) {
            if case .loaded = viewModel.state {
                return true
            }
            return false
        }
        viewModel.updateSendAmount("1")

        await fulfillment(of: [received], timeout: 5)
        XCTAssertEqual(receivedMessage, TKLocales.MultichainSwap.ProviderError.unknown)
        XCTAssertNotEqual(receivedMessage, providerMessage)
        guard case let .loaded(state) = viewModel.state else {
            return XCTFail("Expected loaded state")
        }
        // No routes ⇒ unavailable, not "route expired" — otherwise the rate row
        // would contradict the provider error toast.
        XCTAssertEqual(state.quote.quoteState, .failed(.unavailable))
    }

    @MainActor
    func test_noRouteProviderErrorShowsPairUnavailableState() async {
        let oneEth = BigUInt(10).power(18)
        let defaultAssetsService = DefaultAssetsServiceSpy(
            result: .success(initialAssets(sendBalance: oneEth * 10))
        )
        let swapService = SwapServiceSpy(
            quoteResult: .success(
                MultichainSwapQuote(
                    quoteId: "quote",
                    routes: [],
                    providerErrors: [
                        MultichainSwapProviderError(
                            aggregator: "swapsxyz",
                            code: "no_route",
                            message: "no route found"
                        ),
                    ]
                )
            )
        )
        var receivedMessage: String?
        let viewModel = makeViewModel(
            defaultAssetsService: defaultAssetsService,
            swapService: swapService,
            onQuoteProviderError: { receivedMessage = $0 }
        )

        await waitUntil(viewModel) {
            if case .loaded = viewModel.state {
                return true
            }
            return false
        }
        viewModel.updateSendAmount("1")

        await waitUntil(viewModel) {
            guard case let .loaded(state) = viewModel.state else {
                return false
            }
            return state.quote.quoteState == .failed(.pairUnavailable)
        }
        guard case let .loaded(state) = viewModel.state else {
            return XCTFail("Expected loaded state")
        }
        XCTAssertEqual(state.quote.quoteState, .failed(.pairUnavailable))
        XCTAssertNil(receivedMessage)
    }

    @MainActor
    func test_pairNotAllowedQuoteErrorShowsPairUnavailableState() async {
        let oneEth = BigUInt(10).power(18)
        let defaultAssetsService = DefaultAssetsServiceSpy(
            result: .success(initialAssets(sendBalance: oneEth * 10))
        )
        let swapService = SwapServiceSpy(
            quoteResult: .failure(
                MultichainSwapAPIError.badRequest(
                    message: "pair is not allowed",
                    code: "pair_not_allowed",
                    requestId: nil
                )
            )
        )
        var receivedMessage: String?
        let viewModel = makeViewModel(
            defaultAssetsService: defaultAssetsService,
            swapService: swapService,
            onQuoteProviderError: { receivedMessage = $0 }
        )

        await waitUntil(viewModel) {
            if case .loaded = viewModel.state { return true }
            return false
        }
        viewModel.updateSendAmount("1")

        await waitUntil(viewModel) {
            guard case let .loaded(state) = viewModel.state else {
                return false
            }
            return state.quote.quoteState == .failed(.pairUnavailable)
        }
        guard case let .loaded(state) = viewModel.state else {
            return XCTFail("Expected loaded state")
        }
        XCTAssertEqual(state.quote.quoteState, .failed(.pairUnavailable))
        XCTAssertNil(receivedMessage)
    }

    @MainActor
    func test_quoteErrorWithoutPairNotAllowedShowsGenericFailure() async {
        let oneEth = BigUInt(10).power(18)
        let defaultAssetsService = DefaultAssetsServiceSpy(
            result: .success(initialAssets(sendBalance: oneEth * 10))
        )
        let swapService = SwapServiceSpy(
            quoteResult: .failure(
                MultichainSwapAPIError.badRequest(
                    message: "bad request",
                    code: "some_other_code",
                    requestId: nil
                )
            )
        )
        let viewModel = makeViewModel(
            defaultAssetsService: defaultAssetsService,
            swapService: swapService
        )

        await waitUntil(viewModel) {
            if case .loaded = viewModel.state { return true }
            return false
        }
        viewModel.updateSendAmount("1")

        await waitUntil(viewModel) {
            guard case let .loaded(state) = viewModel.state else {
                return false
            }
            return state.quote.quoteState == .failed(.unavailable)
        }
        guard case let .loaded(state) = viewModel.state else {
            return XCTFail("Expected loaded state")
        }
        XCTAssertNotEqual(state.quote.quoteState, .failed(.pairUnavailable))
    }

    @MainActor
    func test_quoteRequestThatNeverReachedTheServerShowsOfflineState() async {
        let oneEth = BigUInt(10).power(18)
        let defaultAssetsService = DefaultAssetsServiceSpy(
            result: .success(initialAssets(sendBalance: oneEth * 10))
        )
        let swapService = SwapServiceSpy(quoteResult: .failure(.offline))
        var offlineCount = 0
        let viewModel = makeViewModel(
            defaultAssetsService: defaultAssetsService,
            swapService: swapService,
            onQuoteOffline: { offlineCount += 1 }
        )

        await waitUntil(viewModel) {
            if case .loaded = viewModel.state { return true }
            return false
        }
        viewModel.updateSendAmount("1")

        await waitUntil(viewModel) {
            guard case let .loaded(state) = viewModel.state else {
                return false
            }
            return state.quote.quoteState == .failed(.offline)
        }
        guard case let .loaded(state) = viewModel.state else {
            return XCTFail("Expected loaded state")
        }
        XCTAssertEqual(state.quote.quoteState, .failed(.offline))
        XCTAssertEqual(offlineCount, 1)
    }

    /// The fee row reads the plan prepared for the route on screen and follows the method picked for it;
    /// offline it keeps that plan with the quote kept on screen.
    @MainActor
    func test_feeRowReadsThePlanOfTheRouteOnScreen() async {
        let oneEth = BigUInt(10).power(18)
        let swapService = SwapServiceSpy(
            quoteResults: [
                .success(quote(sourceAmount: oneEth.description, estimatedDestinationAmount: "2500000000")),
                .failure(.offline),
            ]
        )
        let nativeFee = MultichainTransactionEmulationResult(fee: 2_000_000_000_000_000, asset: ethDetails)
        let executionService = FeePlanServiceStub(feeOptions: [
            MultichainSwapFeeOption(
                cost: .batteryCharges(count: 7, excess: nil, isInsufficient: false),
                availableCharges: 771
            ),
            MultichainSwapFeeOption(cost: .native([nativeFee], isInsufficient: false)),
        ])
        let multichainState = MultichainWalletState(walletId: "wallet", addresses: [.init(chain: .eth, address: "0xwallet")])
        let viewModel = makeViewModel(
            defaultAssetsService: DefaultAssetsServiceSpy(
                result: .success(initialAssets(sendBalance: oneEth * 10))
            ),
            swapService: swapService,
            planProvider: MultichainSwapPlanProvider(
                swapWallet: MultichainSwapWallet(wallet: makeWallet(multichainState: multichainState), registeredState: multichainState),
                executionService: executionService
            )
        )
        func feeSummary() -> MultichainSwapFeeSummary? {
            guard case let .loaded(state) = viewModel.state else {
                return nil
            }
            return state.feeSummary
        }
        await waitUntil(viewModel) {
            if case .loaded = viewModel.state { return true }
            return false
        }

        viewModel.updateSendAmount("1")
        await waitUntil(viewModel) { feeSummary() == .charges(7) }
        viewModel.setFeeMethod(.native)
        XCTAssertEqual(feeSummary(), .amounts([.init(amount: nativeFee.fee, asset: ethDetails)]))

        viewModel.requestFreshQuote()
        await waitUntil(viewModel) {
            guard case let .loaded(state) = viewModel.state else {
                return false
            }
            return state.quote.quoteState == .failed(.offline)
        }
        XCTAssertEqual(feeSummary(), .amounts([.init(amount: nativeFee.fee, asset: ethDetails)]))
        XCTAssertEqual(executionService.callCount, 1)
    }

    /// The Swap button goes straight to the passcode only with a fee the row names. A fee the row could not
    /// estimate is estimated again in the pricing details, where the user sees it before the swap goes.
    @MainActor
    func test_swapWithAnUnknownFeeOpensThePricingDetails() async {
        let plans: [(feeOptions: [MultichainSwapFeeOption], failures: [MultichainSwapExecutionFailure])] = [
            ([], [.internal(reason: "emulation failed")]),
            ([MultichainSwapFeeOption(cost: .native([], isInsufficient: false))], []),
        ]
        for (feeOptions, failures) in plans {
            let oneEth = BigUInt(10).power(18)
            let swapService = SwapServiceSpy(
                quoteResults: [.success(quote(sourceAmount: (oneEth / 2).description, estimatedDestinationAmount: "125000000"))]
            )
            let executionService = FeePlanServiceStub(feeOptions: feeOptions, failures: failures)
            var continued = 0
            var openedPricingDetails = 0
            let analytics = AnalyticsServiceSpy()
            let multichainState = MultichainWalletState(walletId: "wallet", addresses: [.init(chain: .eth, address: "0xwallet")])
            let viewModel = makeViewModel(
                defaultAssetsService: DefaultAssetsServiceSpy(result: .success(initialAssets(sendBalance: oneEth))),
                swapService: swapService,
                onContinue: { _ in continued += 1 },
                onOpenPricingDetails: { _ in openedPricingDetails += 1 },
                planProvider: MultichainSwapPlanProvider(
                    swapWallet: MultichainSwapWallet(wallet: makeWallet(multichainState: multichainState), registeredState: multichainState),
                    executionService: executionService
                ),
                analytics: analytics
            )
            func loadedState() -> MultichainSwapLoadedState? {
                guard case let .loaded(state) = viewModel.state else {
                    return nil
                }
                return state
            }
            await waitUntil(viewModel) { loadedState() != nil }

            viewModel.updateSendAmount("0.5")
            await waitUntil(viewModel) { loadedState()?.feeSummary == .unknown }
            viewModel.continueSwap()

            XCTAssertEqual(openedPricingDetails, 1)
            XCTAssertEqual(continued, 0)
            XCTAssertEqual(analytics.events.map(\.name), [], "the pricing details send swap_click from their Swap button")
        }
    }

    /// A swap that ends under the fee popup it left over the swap screen keeps the keyboard down: the amount takes it
    /// back only when the confirmation closed with nothing over the screen.
    @MainActor
    func test_confirmationClosedUnderAPopupLeavesTheAmountUnfocused() {
        let viewModel = makeViewModel(
            defaultAssetsService: DefaultAssetsServiceSpy(result: .success(initialAssets(sendBalance: BigUInt(10).power(18))))
        )
        let focusRequestID = viewModel.focusRequestID

        viewModel.confirmationDidClose(refocusesAmount: false)
        XCTAssertEqual(viewModel.focusRequestID, focusRequestID)

        viewModel.confirmationDidClose()
        XCTAssertEqual(viewModel.focusRequestID, focusRequestID + 1)
    }

    @MainActor
    func test_insufficientBalanceDoesNotPrepareUntilTheAmountFits() async {
        let oneEth = BigUInt(10).power(18)
        let balance = oneEth / 10
        let swapService = SwapServiceSpy(
            quoteResults: [
                .success(quote(sourceAmount: oneEth.description, estimatedDestinationAmount: "2500000000", routeId: "above")),
                .success(quote(
                    sourceAmount: (balance / 2).description,
                    estimatedDestinationAmount: "125000000",
                    routeId: "covered"
                )),
            ]
        )
        let executionService = FeePlanServiceStub(
            feeOptions: [
                MultichainSwapFeeOption(
                    cost: .batteryCharges(count: 7, excess: nil, isInsufficient: false),
                    availableCharges: 771
                ),
            ]
        )
        let multichainState = MultichainWalletState(walletId: "wallet", addresses: [.init(chain: .eth, address: "0xwallet")])
        let viewModel = makeViewModel(
            defaultAssetsService: DefaultAssetsServiceSpy(
                result: .success(initialAssets(sendBalance: balance))
            ),
            swapService: swapService,
            planProvider: MultichainSwapPlanProvider(
                swapWallet: MultichainSwapWallet(wallet: makeWallet(multichainState: multichainState), registeredState: multichainState),
                executionService: executionService
            )
        )
        func loadedState() -> MultichainSwapLoadedState? {
            guard case let .loaded(state) = viewModel.state else {
                return nil
            }
            return state
        }
        await waitUntil(viewModel) { loadedState() != nil }

        viewModel.updateSendAmount("1")
        await waitUntilQuoteReady(viewModel)
        XCTAssertEqual(loadedState()?.validationState, .insufficientBalance)
        viewModel.continueSwap()
        viewModel.openPricingDetails()
        XCTAssertNil(viewModel.confirmationPhase)
        XCTAssertEqual(executionService.callCount, 0)

        viewModel.updateSendAmount("0.05")
        await waitUntil(viewModel) { loadedState()?.feeSummary == .charges(7) }
        XCTAssertEqual(loadedState()?.validationState, .valid)
        XCTAssertEqual(executionService.callCount, 1)
    }

    @MainActor
    func test_emptyUsdtWalletDoesNotPrepareTheQuote() async {
        let swapService = SwapServiceSpy(
            quoteResult: .success(quote(sourceAmount: "1000000", estimatedDestinationAmount: "950000000"))
        )
        let executionService = FeePlanServiceStub(feeOptions: [])
        let multichainState = MultichainWalletState(walletId: "wallet", addresses: [.init(chain: .ton, address: "tonwallet")])
        let swapWallet = MultichainSwapWallet(wallet: makeWallet(multichainState: multichainState), registeredState: multichainState)
        let viewModel = makeViewModel(
            defaultAssetsService: DefaultAssetsServiceSpy(result: .success(initialAssets(
                sendAssetId: "ton/mainnet/jetton/0:usdt",
                sendSymbol: "USDT",
                sendDecimals: 6,
                sendBalance: 0
            ))),
            swapService: swapService,
            swapWallet: swapWallet,
            planProvider: MultichainSwapPlanProvider(swapWallet: swapWallet, executionService: executionService)
        )
        await waitUntil(viewModel) {
            if case .loaded = viewModel.state { return true }
            return false
        }
        viewModel.updateSendAmount("1")
        await waitUntilQuoteReady(viewModel)
        guard case let .loaded(state) = viewModel.state else {
            return XCTFail("Expected loaded state")
        }
        XCTAssertEqual(state.validationState, .insufficientBalance)
        viewModel.continueSwap()
        viewModel.openPricingDetails()
        viewModel.confirmationDidClose(refocusesAmount: false)
        XCTAssertNil(viewModel.confirmationPhase)
        XCTAssertEqual(executionService.callCount, 0)
    }

    @MainActor
    func test_belowMinimumOnlyEstimatesFeeWhenTheBalanceCoversTheAmount() async {
        for balance: BigUInt in [0, 300_000_000, 2_000_000_000] {
            let fee = MultichainTransactionEmulationResult(fee: 280_000_000, asset: .gram)
            let executionService = FeePlanServiceStub(feeOptions: [MultichainSwapFeeOption(cost: .native([fee], isInsufficient: false))])
            let multichainState = MultichainWalletState(walletId: "wallet", addresses: [.init(chain: .ton, address: "tonwallet")])
            let swapWallet = MultichainSwapWallet(wallet: makeWallet(multichainState: multichainState), registeredState: multichainState)
            let viewModel = makeViewModel(
                defaultAssetsService: DefaultAssetsServiceSpy(result: .success(initialAssets(
                    sendAssetId: "ton/mainnet/coin",
                    sendSymbol: "GRAM",
                    sendDecimals: 9,
                    sendBalance: balance
                ))),
                swapService: SwapServiceSpy(quoteResult: .success(quote(sourceAmount: "500000000", estimatedDestinationAmount: "500000"))),
                swapWallet: swapWallet,
                planProvider: MultichainSwapPlanProvider(swapWallet: swapWallet, executionService: executionService)
            )
            await waitUntil(viewModel) {
                if case .loaded = viewModel.state { return true }
                return false
            }
            viewModel.updateSendAmount("0.5")
            await waitUntilQuoteReady(viewModel)

            if balance >= 500_000_000 {
                await waitUntil(viewModel) {
                    guard case let .loaded(state) = viewModel.state else { return false }
                    return state.feeSummary == .amounts([.init(amount: fee.fee, asset: fee.asset)])
                }
                guard case let .loaded(state) = viewModel.state else { return XCTFail("Expected loaded state") }
                XCTAssertEqual(state.validationState, .belowMinimum(1_000_000_000))
                XCTAssertEqual(executionService.callCount, 1)
            } else {
                guard case let .loaded(state) = viewModel.state else { return XCTFail("Expected loaded state") }
                XCTAssertEqual(state.validationState, .insufficientBalance)
                viewModel.confirmationDidClose(refocusesAmount: false)
                XCTAssertEqual(executionService.callCount, 0)
            }
            viewModel.continueSwap()
            viewModel.openPricingDetails()
            XCTAssertNil(viewModel.confirmationPhase)
        }
    }

    /// The empty screen offers the battery to a wallet without charges, for a send asset the battery pays the
    /// swap of. It counts as shown once on screen, gives the row back to an entered amount, comes back with
    /// the empty screen, and ends with a recharge.
    @MainActor
    func test_batteryPromoOffersTheBatteryOnTheEmptyScreen() async {
        let oneEth = BigUInt(10).power(18)
        var shownCount = 0
        var refills = [() -> Void]()
        let viewModel = makeViewModel(
            defaultAssetsService: DefaultAssetsServiceSpy(
                result: .success(initialAssets(sendBalance: oneEth * 10))
            ),
            swapService: SwapServiceSpy(
                quoteResults: [.success(quote(sourceAmount: oneEth.description, estimatedDestinationAmount: "2500000000"))]
            ),
            batteryPromo: MultichainSwapBatteryPromo(
                load: { { $0.asset.assetId == "eth/mainnet/coin" } },
                markShown: { shownCount += 1 }
            ),
            onRefillBattery: { refills.append($0) }
        )
        func loadedState() -> MultichainSwapLoadedState? {
            guard case let .loaded(state) = viewModel.state else {
                return nil
            }
            return state
        }

        await waitUntil(viewModel) { loadedState()?.showsBatteryPromo == true }
        XCTAssertEqual(shownCount, 1)

        viewModel.updateSendAmount("1")
        await waitUntil(viewModel) { loadedState()?.quote.quoteState == .ready }
        XCTAssertEqual(loadedState()?.showsBatteryPromo, false)

        viewModel.updateSendAmount("")
        await waitUntil(viewModel) { loadedState()?.showsBatteryPromo == true }
        XCTAssertEqual(shownCount, 1)

        viewModel.openBatteryPromo()
        XCTAssertEqual(refills.count, 1)
        refills.first?()

        XCTAssertEqual(loadedState()?.showsBatteryPromo, false)
    }

    /// Nothing to offer, or a send asset the battery does not pay the swap of, leaves the empty row empty and
    /// the promo unspent.
    @MainActor
    func test_batteryPromoStaysOffWithoutAnythingToOfferForTheSendAsset() async {
        let promos: [(String, MultichainSwapBatteryPromo.Load)] = [
            ("nothing to offer", { nil }),
            ("send asset not covered", { { _ in false } }),
        ]
        for (reason, load) in promos {
            var shownCount = 0
            let viewModel = makeViewModel(
                defaultAssetsService: DefaultAssetsServiceSpy(result: .success(initialAssets())),
                batteryPromo: MultichainSwapBatteryPromo(load: load, markShown: { shownCount += 1 })
            )
            await waitUntil(viewModel) {
                if case .loaded = viewModel.state { return true }
                return false
            }

            guard case let .loaded(state) = viewModel.state else {
                return XCTFail(reason)
            }
            XCTAssertFalse(state.showsBatteryPromo, reason)
            XCTAssertEqual(shownCount, 0, reason)
        }
    }

    /// The backend expires a route a minute after it quoted it, so the refresh comes a little before that
    /// rather than after the full refresh time.
    @MainActor
    func test_quoteRefreshesBeforeItsRouteExpires() async {
        func refreshDuration(routeExpiresIn: TimeInterval) async -> TimeInterval? {
            let oneEth = BigUInt(10).power(18)
            let viewModel = makeViewModel(
                defaultAssetsService: DefaultAssetsServiceSpy(
                    result: .success(initialAssets(sendBalance: oneEth * 10))
                ),
                swapService: SwapServiceSpy(
                    quoteResults: [
                        .success(quote(
                            sourceAmount: oneEth.description,
                            estimatedDestinationAmount: "2500000000",
                            expiresIn: routeExpiresIn
                        )),
                    ]
                ),
                quoteRefreshDuration: 60
            )
            await waitUntil(viewModel) {
                if case .loaded = viewModel.state { return true }
                return false
            }
            viewModel.updateSendAmount("1")
            await waitUntilQuoteReady(viewModel)
            return viewModel.quoteRefreshCycle?.duration
        }

        let minuteRoute = await refreshDuration(routeExpiresIn: 60)
        let longRoute = await refreshDuration(routeExpiresIn: 600)
        XCTAssertEqual(minuteRoute ?? 0, 55, accuracy: 1)
        XCTAssertEqual(longRoute, 60)
    }

    /// Offline, a refresh keeps the last quote for the amount on screen with no swap offered for it; a new
    /// amount has no quote to keep.
    @MainActor
    func test_offlineRefreshKeepsTheLastQuoteOnlyForItsAmount() async {
        let oneEth = BigUInt(10).power(18)
        let swapService = SwapServiceSpy(
            quoteResults: [
                .success(quote(sourceAmount: oneEth.description, estimatedDestinationAmount: "2500000000")),
                .failure(.offline),
            ]
        )
        var confirmationInput: MultichainSwapConfirmationInput?
        let viewModel = makeViewModel(
            defaultAssetsService: DefaultAssetsServiceSpy(
                result: .success(initialAssets(sendBalance: oneEth * 10))
            ),
            swapService: swapService,
            onContinue: { confirmationInput = $0 }
        )
        await waitUntil(viewModel) {
            if case .loaded = viewModel.state { return true }
            return false
        }
        viewModel.updateSendAmount("1")
        await waitUntilQuoteReady(viewModel)

        viewModel.requestFreshQuote()
        await waitUntil(viewModel) {
            guard case let .loaded(state) = viewModel.state else {
                return false
            }
            return state.quote.quoteState == .failed(.offline)
        }
        guard case let .loaded(offlineState) = viewModel.state else {
            return XCTFail("Expected loaded state")
        }
        XCTAssertEqual(offlineState.receiveAmount, "2.5")
        XCTAssertFalse(offlineState.isQuoteUnavailable(in: .receive))
        viewModel.continueSwap()
        XCTAssertNil(confirmationInput)

        viewModel.updateSendAmount("2")
        await waitUntil(viewModel) {
            guard case let .loaded(state) = viewModel.state else {
                return false
            }
            return state.quote.quoteState == .failed(.offline) && state.receiveAmount.isEmpty
        }
    }

    @MainActor
    func test_mixedProviderErrorsWithNoRouteShowPairUnavailableState() async {
        let oneEth = BigUInt(10).power(18)
        let defaultAssetsService = DefaultAssetsServiceSpy(
            result: .success(initialAssets(sendBalance: oneEth * 10))
        )
        let swapService = SwapServiceSpy(
            quoteResult: .success(
                MultichainSwapQuote(
                    quoteId: "quote",
                    routes: [],
                    providerErrors: [
                        MultichainSwapProviderError(
                            aggregator: "swapsxyz",
                            code: "min_amount_not_met",
                            message: "Minimum amount is 10 USDT"
                        ),
                        MultichainSwapProviderError(
                            aggregator: "rango",
                            code: "no_route",
                            message: "no route found"
                        ),
                    ]
                )
            )
        )
        var receivedMessage: String?
        let viewModel = makeViewModel(
            defaultAssetsService: defaultAssetsService,
            swapService: swapService,
            onQuoteProviderError: { receivedMessage = $0 }
        )

        await waitUntil(viewModel) {
            if case .loaded = viewModel.state {
                return true
            }
            return false
        }
        viewModel.updateSendAmount("1")

        await waitUntil(viewModel) {
            guard case let .loaded(state) = viewModel.state else {
                return false
            }
            return state.quote.quoteState == .failed(.pairUnavailable)
        }
        guard case let .loaded(state) = viewModel.state else {
            return XCTFail("Expected loaded state")
        }
        XCTAssertEqual(state.quote.quoteState, .failed(.pairUnavailable))
        XCTAssertNil(receivedMessage)
    }

    @MainActor
    func test_screenedRouteShowsTheWalletScreenedStateWithoutAToast() async {
        let viewModel = await loadedViewModel(
            quote: screenedQuote(routes: [payloadlessRoute(routeId: "swapsxyz-route", aggregator: "swapsxyz")])
        )

        viewModel.viewModel.updateSendAmount("1")

        await waitUntil(viewModel.viewModel) {
            guard case let .loaded(state) = viewModel.viewModel.state else {
                return false
            }
            return state.quote.quoteState == .failed(.walletScreened)
        }
        guard case let .loaded(state) = viewModel.viewModel.state else {
            return XCTFail("Expected loaded state")
        }
        XCTAssertNil(state.quote.selectedRoute)
        XCTAssertNil(viewModel.providerMessage())
    }

    @MainActor
    func test_walletScreeningOutranksANoRouteError() async {
        let quote = MultichainSwapQuote(
            quoteId: "quote",
            routes: [],
            providerErrors: [
                MultichainSwapProviderError(aggregator: "swapkit", code: "no_route", message: "no route found"),
                MultichainSwapProviderError(
                    aggregator: "swapsxyz",
                    code: "wallet_screened",
                    message: "wallet blocked by the provider's compliance screening"
                ),
            ]
        )
        let viewModel = await loadedViewModel(quote: quote)

        viewModel.viewModel.updateSendAmount("1")

        await waitUntil(viewModel.viewModel) {
            guard case let .loaded(state) = viewModel.viewModel.state else {
                return false
            }
            return state.quote.quoteState == .failed(.walletScreened)
        }
        XCTAssertNil(viewModel.providerMessage())
    }

    @MainActor
    func test_routeOfAnotherAggregatorIsQuotedPastAScreenedOne() async {
        let viewModel = await loadedViewModel(
            quote: screenedQuote(routes: [
                payloadlessRoute(routeId: "swapsxyz-route", aggregator: "swapsxyz"),
                payloadlessRoute(routeId: "swapkit-route", aggregator: "swapkit"),
            ])
        )

        viewModel.viewModel.updateSendAmount("1")

        await waitUntil(viewModel.viewModel) {
            guard case let .loaded(state) = viewModel.viewModel.state else {
                return false
            }
            return state.quote.quoteState == .ready
        }
        guard case let .loaded(state) = viewModel.viewModel.state else {
            return XCTFail("Expected loaded state")
        }
        XCTAssertEqual(state.quote.selectedRoute?.routeId, "swapkit-route")
    }

    @MainActor
    func test_failedRefreshStopsTheCountdownAndClearsTheReceiveAmount() async {
        let oneEth = BigUInt(10).power(18)
        let defaultAssetsService = DefaultAssetsServiceSpy(
            result: .success(initialAssets(sendBalance: oneEth * 10))
        )
        let swapService = SwapServiceSpy(
            quoteResults: [
                .success(
                    quote(
                        sourceAmount: oneEth.description,
                        estimatedDestinationAmount: "5000000000"
                    )
                ),
                .failure(.unimplemented),
            ]
        )
        let viewModel = makeViewModel(
            defaultAssetsService: defaultAssetsService,
            swapService: swapService
        )

        await waitUntil(viewModel) {
            guard case .loaded = viewModel.state else {
                return false
            }
            return true
        }

        viewModel.updateSendAmount("1")
        await waitUntil(viewModel) {
            guard case let .loaded(state) = viewModel.state else {
                return false
            }
            return state.quote.quoteState == .ready
        }

        viewModel.updateSendAmount("2")
        await waitUntil(viewModel) {
            guard case let .loaded(state) = viewModel.state else {
                return false
            }
            return state.quote.quoteState == .failed(.unavailable)
        }

        guard case let .loaded(state) = viewModel.state else {
            return XCTFail("Expected loaded state")
        }
        XCTAssertNil(viewModel.quoteRefreshCycle)
        XCTAssertEqual(state.receiveAmount, "")
    }

    @MainActor
    func test_quoteRefreshAfterFailureShimmersReceiveCardInsteadOfShowingEmptyAmount() async {
        let oneEth = BigUInt(10).power(18)
        let defaultAssetsService = DefaultAssetsServiceSpy(
            result: .success(initialAssets(sendBalance: oneEth * 10))
        )
        let swapService = SwapServiceSpy(
            quoteResults: [
                .success(
                    quote(
                        sourceAmount: oneEth.description,
                        estimatedDestinationAmount: "5000000000"
                    )
                ),
                .failure(.unimplemented),
            ]
        )
        let viewModel = makeViewModel(
            defaultAssetsService: defaultAssetsService,
            swapService: swapService
        )

        await waitUntil(viewModel) {
            guard case .loaded = viewModel.state else {
                return false
            }
            return true
        }

        viewModel.updateSendAmount("1")
        await waitUntil(viewModel) {
            guard case let .loaded(state) = viewModel.state else {
                return false
            }
            return state.quote.quoteState == .ready
        }

        viewModel.updateSendAmount("2")
        await waitUntil(viewModel) {
            guard case let .loaded(state) = viewModel.state else {
                return false
            }
            return state.quote.quoteState == .failed(.unavailable)
        }

        guard case let .loaded(failedState) = viewModel.state else {
            return XCTFail("Expected loaded state")
        }
        XCTAssertEqual(failedState.receiveAmount, "")
        XCTAssertTrue(failedState.isQuoteUnavailable(in: .receive))
        XCTAssertFalse(failedState.showsQuoteShimmer(in: .receive))

        viewModel.updateSendAmount("3")

        guard case let .loaded(refreshState) = viewModel.state else {
            return XCTFail("Expected loaded state")
        }
        XCTAssertEqual(refreshState.quote.quoteState, .loading)
        XCTAssertEqual(refreshState.receiveAmount, "")
        XCTAssertTrue(refreshState.showsQuoteShimmer(in: .receive))
        XCTAssertFalse(refreshState.isQuoteUnavailable(in: .receive))
    }

    @MainActor
    func test_exactOutput_receiveAmountQuotesByDestinationAndFillsSendAmount() async {
        let oneEth = BigUInt(10).power(18)
        let swapService = SwapServiceSpy(
            quoteResult: .success(quote(sourceAmount: (oneEth / 2).description, estimatedDestinationAmount: "2001000000"))
        )
        var confirmationInput: MultichainSwapConfirmationInput?
        let viewModel = await loadedExactOutputViewModel(
            swapService: swapService,
            sendBalance: oneEth * 10,
            onContinue: { confirmationInput = $0 }
        )

        viewModel.updateReceiveAmount("2")
        await waitUntilQuoteReady(viewModel)

        guard case let .loaded(state) = viewModel.state else {
            return XCTFail("Expected loaded state")
        }
        XCTAssertEqual(state.enteredField, .receive)
        XCTAssertEqual(state.sendAmount, "0.5")
        XCTAssertEqual(state.receiveAmount, "2")
        XCTAssertEqual(state.validationState, .valid)
        let requests = await swapService.quoteRequests()
        XCTAssertEqual(requests.last?.amount, .destination(2_000_000_000))
        XCTAssertEqual(requests.last?.aggregators, ["swapsxyz"])

        viewModel.continueSwap()
        XCTAssertEqual(confirmationInput?.sourceAmount, oneEth / 2)
        XCTAssertEqual(confirmationInput?.userInput.quoteAmount, .destination(2_000_000_000))
    }

    @MainActor
    func test_exactOutput_pairWithoutSwapsXyzKeepsReceiveAmountReadOnly() async {
        let swapService = SwapServiceSpy(
            quoteResult: .success(quote(sourceAmount: "1", estimatedDestinationAmount: "1"))
        )
        let viewModel = await loadedExactOutputViewModel(
            swapService: swapService,
            swapAggregators: [.swapKit]
        )

        viewModel.updateReceiveAmount("2")

        guard case let .loaded(state) = viewModel.state else {
            return XCTFail("Expected loaded state")
        }

        XCTAssertNotEqual(state.quote.quoteState, .loading, "no requote is pending")
        XCTAssertFalse(state.isReceiveAmountEditable)
        XCTAssertEqual(state.enteredField, .send)
        XCTAssertEqual(state.receiveAmount, "")
        let requestCount = await swapService.quoteRequests().count
        XCTAssertEqual(requestCount, 0)
    }

    @MainActor
    func test_exactOutput_typingSendAmountQuotesBySourceAgain() async {
        let oneEth = BigUInt(10).power(18)
        let swapService = SwapServiceSpy(
            quoteResult: .success(quote(sourceAmount: (oneEth / 2).description, estimatedDestinationAmount: "2000000000"))
        )
        let viewModel = await loadedExactOutputViewModel(swapService: swapService, sendBalance: oneEth * 10)
        viewModel.updateReceiveAmount("2")
        await waitUntilQuoteReady(viewModel)

        viewModel.updateSendAmount("1")
        await waitUntil(swapService.changes) {
            await swapService.quoteRequests().count == 2
        }

        guard case let .loaded(state) = viewModel.state else {
            return XCTFail("Expected loaded state")
        }
        XCTAssertEqual(state.enteredField, .send)
        let requests = await swapService.quoteRequests()
        XCTAssertEqual(requests.last?.amount, .source(oneEth))
    }

    @MainActor
    func test_exactOutput_quotedSendAmountAboveBalanceIsInsufficient() async {
        let oneEth = BigUInt(10).power(18)
        var didContinue = false
        let viewModel = await loadedExactOutputViewModel(
            swapService: SwapServiceSpy(
                quoteResult: .success(quote(sourceAmount: (oneEth / 2).description, estimatedDestinationAmount: "2000000000"))
            ),
            sendBalance: oneEth / 4,
            onContinue: { _ in didContinue = true }
        )

        viewModel.updateReceiveAmount("2")
        await waitUntilQuoteReady(viewModel)
        viewModel.continueSwap()

        guard case let .loaded(state) = viewModel.state else {
            return XCTFail("Expected loaded state")
        }
        XCTAssertEqual(state.validationState, .insufficientBalance)
        XCTAssertFalse(didContinue)
    }

    @MainActor
    func test_exactOutput_swapTokensMovesReceiveAmountToSend() async {
        let oneEth = BigUInt(10).power(18)
        let swapService = SwapServiceSpy(
            quoteResult: .success(quote(sourceAmount: (oneEth / 2).description, estimatedDestinationAmount: "2000000000"))
        )
        let viewModel = await loadedExactOutputViewModel(swapService: swapService, sendBalance: oneEth * 10)
        viewModel.updateReceiveAmount("2")
        await waitUntilQuoteReady(viewModel)

        viewModel.swapTokens()
        await waitUntil(swapService.changes) {
            await swapService.quoteRequests().count == 2
        }

        guard case let .loaded(state) = viewModel.state else {
            return XCTFail("Expected loaded state")
        }
        XCTAssertEqual(state.enteredField, .send)
        XCTAssertEqual(state.sendAsset.asset.assetId, "ton/mainnet/coin")
        XCTAssertEqual(state.sendAmount, "2")
        let requests = await swapService.quoteRequests()
        XCTAssertEqual(requests.last?.amount, .source(2_000_000_000))
    }

    /// What was quoted for an amount the new pair cannot be quoted by means nothing for it, so both
    /// amounts go rather than one becoming the other's.
    @MainActor
    func test_exactOutput_receiveAssetWithoutSupportClearsBothAmounts() async {
        let oneEth = BigUInt(10).power(18)
        let swapService = SwapServiceSpy(
            quoteResult: .success(quote(sourceAmount: (oneEth / 2).description, estimatedDestinationAmount: "2000000000"))
        )
        let viewModel = await loadedExactOutputViewModel(swapService: swapService, sendBalance: oneEth * 10)
        viewModel.updateReceiveAmount("2")
        await waitUntilQuoteReady(viewModel)

        viewModel.applyReceiveAsset(
            asset(
                assetId: "ton/mainnet/jetton/0:0000000000000000000000000000000000000000000000000000000000000001",
                symbol: "JET",
                decimals: 9,
                swapAggregators: [.swapKit]
            )
        )

        guard case let .loaded(state) = viewModel.state else {
            return XCTFail("Expected loaded state")
        }

        XCTAssertNotEqual(state.quote.quoteState, .loading, "no requote is pending")
        XCTAssertEqual(state.enteredField, .send)
        XCTAssertEqual(state.sendAmount, "")
        XCTAssertEqual(state.receiveAmount, "")
        let requestCount = await swapService.quoteRequests().count
        XCTAssertEqual(requestCount, 1)
    }

    /// The amount to receive stays through a send asset the pair still quotes by it, and the send card
    /// left in fiat for an asset it cannot price goes back to crypto without taking the entered side.
    @MainActor
    func test_exactOutput_sendAssetChangeKeepsTheAmountToReceive() async {
        let oneEth = BigUInt(10).power(18)
        let swapService = SwapServiceSpy(
            quoteResult: .success(quote(sourceAmount: (oneEth / 2).description, estimatedDestinationAmount: "2000000000"))
        )
        let viewModel = await loadedExactOutputViewModel(swapService: swapService, sendBalance: oneEth * 10, sendPrice: 2000)
        viewModel.updateReceiveAmount("2")
        await waitUntilQuoteReady(viewModel)
        viewModel.toggleSendAmountInputMode()

        viewModel.applySendAsset(
            asset(
                assetId: "eth/mainnet/erc20/0x0000000000000000000000000000000000000001",
                symbol: "TKN",
                decimals: 18,
                swapAggregators: [.swapsXyz]
            )
        )
        await waitUntil(swapService.changes) {
            await swapService.quoteRequests().count == 2
        }

        guard case let .loaded(state) = viewModel.state else {
            return XCTFail("Expected loaded state")
        }
        XCTAssertEqual(state.enteredField, .receive)
        XCTAssertEqual(state.receiveAmount, "2")
        XCTAssertEqual(state.sendAmountInputMode, .crypto)
        let requests = await swapService.quoteRequests()
        XCTAssertEqual(requests.last?.amount, .destination(2_000_000_000))
    }

    @MainActor
    func test_exactOutput_receiveAssetChangeAsksForTheTypedNumberOfTheNewAsset() async {
        let swapService = SwapServiceSpy(
            quoteResult: .success(quote(sourceAmount: "500000000000000000", estimatedDestinationAmount: "2000000000"))
        )
        let viewModel = await loadedExactOutputViewModel(swapService: swapService)
        viewModel.updateReceiveAmount("2")
        await waitUntilQuoteReady(viewModel)

        viewModel.applyReceiveAsset(
            asset(
                assetId: "ton/mainnet/jetton/0:b113a994b5024a16719f69139328eb759596c38a25f59028b146fecdc3621dfe",
                symbol: "USDT",
                decimals: 6,
                swapAggregators: [.omniston, .swapsXyz]
            )
        )
        await waitUntil(swapService.changes) {
            await swapService.quoteRequests().count == 2
        }

        guard case let .loaded(state) = viewModel.state else {
            return XCTFail("Expected loaded state")
        }
        XCTAssertEqual(state.enteredField, .receive)
        XCTAssertEqual(state.receiveAmount, "2")
        let requests = await swapService.quoteRequests()
        XCTAssertEqual(requests.last?.amount, .destination(2_000_000))
    }

    @MainActor
    func test_exactOutput_clearingTheAmountToReceiveClearsTheSendAmount() async {
        let oneEth = BigUInt(10).power(18)
        let swapService = SwapServiceSpy(
            quoteResult: .success(quote(sourceAmount: (oneEth / 2).description, estimatedDestinationAmount: "2000000000"))
        )
        let viewModel = await loadedExactOutputViewModel(swapService: swapService, sendBalance: oneEth * 10)
        viewModel.updateReceiveAmount("2")
        await waitUntilQuoteReady(viewModel)

        viewModel.updateReceiveAmount("")

        guard case let .loaded(state) = viewModel.state else {
            return XCTFail("Expected loaded state")
        }

        XCTAssertNotEqual(state.quote.quoteState, .loading, "no requote is pending")
        XCTAssertEqual(state.enteredField, .receive)
        XCTAssertEqual(state.sendAmount, "")
        XCTAssertEqual(state.validationState, .emptyAmount)
        let requestCount = await swapService.quoteRequests().count
        XCTAssertEqual(requestCount, 1)
    }

    @MainActor
    func test_exactOutput_typingTheAmountToReceiveDropsMax() async {
        let oneEth = BigUInt(10).power(18)
        let swapService = SwapServiceSpy(
            quoteResult: .success(quote(sourceAmount: (oneEth / 2).description, estimatedDestinationAmount: "2000000000"))
        )
        var confirmationInput: MultichainSwapConfirmationInput?
        let viewModel = await loadedExactOutputViewModel(
            swapService: swapService,
            sendBalance: oneEth * 10,
            onContinue: { confirmationInput = $0 }
        )
        viewModel.applySendPercent(100)
        await waitUntilQuoteReady(viewModel)

        viewModel.updateReceiveAmount("3")
        await waitUntil(swapService.changes) {
            await swapService.quoteRequests().count == 2
        }
        await waitUntilQuoteReady(viewModel)

        let request = await swapService.quoteRequests().last
        XCTAssertEqual(request?.amount, .destination(3_000_000_000))
        XCTAssertNil(request?.isMax)
        viewModel.continueSwap()
        XCTAssertEqual(confirmationInput?.userInput.isMax, false)
    }

    @MainActor
    func test_exactOutput_maxGoesBackToTheAmountToSend() async {
        let oneEth = BigUInt(10).power(18)
        let swapService = SwapServiceSpy(
            quoteResult: .success(quote(sourceAmount: (oneEth / 2).description, estimatedDestinationAmount: "2000000000"))
        )
        let viewModel = await loadedExactOutputViewModel(swapService: swapService, sendBalance: oneEth * 10)
        viewModel.updateReceiveAmount("2")
        await waitUntilQuoteReady(viewModel)

        viewModel.applySendPercent(100)
        await waitUntil(swapService.changes) {
            await swapService.quoteRequests().count == 2
        }

        guard case let .loaded(state) = viewModel.state else {
            return XCTFail("Expected loaded state")
        }
        XCTAssertEqual(state.enteredField, .send)
        let request = await swapService.quoteRequests().last
        XCTAssertEqual(request?.amount, .source(oneEth * 10))
        XCTAssertEqual(request?.isMax, true)
    }

    /// A send amount the quote derived changes only its currency, so its text follows the toggle and
    /// nothing is asked again.
    @MainActor
    func test_exactOutput_sendCurrencyToggleConvertsTheQuotedAmountWithoutRequoting() async {
        let oneEth = BigUInt(10).power(18)
        let swapService = SwapServiceSpy(
            quoteResult: .success(quote(sourceAmount: (oneEth / 2).description, estimatedDestinationAmount: "2000000000"))
        )
        let viewModel = await loadedExactOutputViewModel(swapService: swapService, sendBalance: oneEth * 10, sendPrice: 2000)
        viewModel.updateReceiveAmount("2")
        await waitUntilQuoteReady(viewModel)

        viewModel.toggleSendAmountInputMode()

        guard case let .loaded(state) = viewModel.state else {
            return XCTFail("Expected loaded state")
        }

        XCTAssertNotEqual(state.quote.quoteState, .loading, "no requote is pending")
        XCTAssertEqual(state.sendAmountInputMode, .fiat)
        XCTAssertEqual(state.sendAmount, "1000")
        XCTAssertEqual(state.enteredField, .receive)
        let requestCount = await swapService.quoteRequests().count
        XCTAssertEqual(requestCount, 1)
    }

    @MainActor
    func test_exactOutput_flagOffKeepsReceiveAmountReadOnlyOnASupportedPair() async {
        let swapService = SwapServiceSpy(
            quoteResult: .success(quote(sourceAmount: "1", estimatedDestinationAmount: "1"))
        )
        let viewModel = await loadedExactOutputViewModel(swapService: swapService, isExactOutputEnabled: false)

        viewModel.updateReceiveAmount("2")

        guard case let .loaded(state) = viewModel.state else {
            return XCTFail("Expected loaded state")
        }

        XCTAssertNotEqual(state.quote.quoteState, .loading, "no requote is pending")
        XCTAssertFalse(state.isReceiveAmountEditable)
        XCTAssertEqual(state.enteredField, .send)
        XCTAssertEqual(state.receiveAmount, "")
        let requestCount = await swapService.quoteRequests().count
        XCTAssertEqual(requestCount, 0)
    }

    /// In fiat the receive card renders the amount it is given and takes no typing.
    @MainActor
    func test_exactOutput_receiveAmountInFiatIsReadOnly() async {
        let swapService = SwapServiceSpy(
            quoteResult: .success(quote(sourceAmount: "1", estimatedDestinationAmount: "1"))
        )
        let viewModel = await loadedExactOutputViewModel(swapService: swapService, receivePrice: 2)

        viewModel.toggleReceiveAmountInputMode()
        viewModel.updateReceiveAmount("2")

        guard case let .loaded(state) = viewModel.state else {
            return XCTFail("Expected loaded state")
        }

        XCTAssertNotEqual(state.quote.quoteState, .loading, "no requote is pending")
        XCTAssertEqual(state.receiveAmountInputMode, .fiat)
        XCTAssertFalse(state.isReceiveAmountEditable)
        XCTAssertEqual(state.enteredField, .send)
        let requestCount = await swapService.quoteRequests().count
        XCTAssertEqual(requestCount, 0)
    }

    /// Picking the asset being received as the one to send flips the pair; the typed amount stays the
    /// amount to receive, now of the asset that was being sent.
    @MainActor
    func test_exactOutput_flipViaSendPickerKeepsTheAmountToReceive() async {
        let oneEth = BigUInt(10).power(18)
        let swapService = SwapServiceSpy(
            quoteResult: .success(quote(sourceAmount: (oneEth / 2).description, estimatedDestinationAmount: "2000000000"))
        )
        let viewModel = await loadedExactOutputViewModel(swapService: swapService, sendBalance: oneEth * 10)
        viewModel.updateReceiveAmount("2")
        await waitUntilQuoteReady(viewModel)
        guard case let .loaded(before) = viewModel.state else {
            return XCTFail("Expected loaded state")
        }

        viewModel.applySendAsset(before.receiveAsset)
        await waitUntil(swapService.changes) {
            await swapService.quoteRequests().count == 2
        }

        guard case let .loaded(state) = viewModel.state else {
            return XCTFail("Expected loaded state")
        }
        XCTAssertEqual(state.receiveAsset.asset.assetId, "eth/mainnet/coin")
        XCTAssertEqual(state.enteredField, .receive)
        XCTAssertEqual(state.receiveAmount, "2")
        let request = await swapService.quoteRequests().last
        XCTAssertEqual(request?.sourceAsset, "ton/mainnet/coin")
        XCTAssertEqual(request?.amount, .destination(oneEth * 2))
    }

    /// The amount to send is whatever the route sells for the amount to receive, so a refresh that
    /// moves it reaches the pricing details, and one past the balance takes the swap away from them.
    @MainActor
    func test_exactOutput_pricingDetailsFollowTheRefreshedAmountToSend() async {
        let oneEth = BigUInt(10).power(18)
        let swapService = SwapServiceSpy(
            quoteResults: [
                .success(quote(sourceAmount: (oneEth / 2).description, estimatedDestinationAmount: "2000000000")),
                .success(quote(sourceAmount: (oneEth * 3 / 4).description, estimatedDestinationAmount: "2000000000")),
                .success(quote(sourceAmount: (oneEth * 2).description, estimatedDestinationAmount: "2000000000")),
            ]
        )
        var updates = [MultichainSwapConfirmationQuoteUpdate]()
        let viewModel = await loadedExactOutputViewModel(swapService: swapService, sendBalance: oneEth)
        viewModel.onConfirmationQuoteChange = { updates.append($0) }
        viewModel.updateReceiveAmount("2")
        await waitUntilQuoteReady(viewModel)
        viewModel.openPricingDetails()

        viewModel.quoteCountdownDidFinish()
        await waitUntil(viewModel) {
            guard case .ready = updates.last else {
                return false
            }
            return true
        }
        guard case let .ready(input, _) = updates.last else {
            return XCTFail("Expected the refreshed quote to reach the pricing details")
        }
        XCTAssertEqual(input.sourceAmount, oneEth * 3 / 4)
        XCTAssertEqual(input.userInput.quoteAmount, .destination(2_000_000_000))

        viewModel.quoteCountdownDidFinish()
        await waitUntil(viewModel) {
            guard case .failed(.insufficientBalance) = updates.last else {
                return false
            }
            return true
        }
    }

    /// An empty send card stays empty through currency switches, also while the first quote for an
    /// amount to receive loads, rather than turning into a "0" that reads as typed.
    @MainActor
    func test_exactOutput_sendCurrencyTogglesKeepAnEmptySendAmountEmpty() async {
        let oneEth = BigUInt(10).power(18)
        let swapService = SwapServiceSpy(
            quoteResult: .success(quote(sourceAmount: (oneEth / 2).description, estimatedDestinationAmount: "2000000000"))
        )
        let viewModel = await loadedExactOutputViewModel(swapService: swapService, sendBalance: oneEth * 10, sendPrice: 2000)
        func assertTogglesKeepTheSendAmountEmpty(enteredField: MultichainSwapAmountField) {
            for mode in [MultichainSwapAmountInputMode.fiat, .crypto] {
                viewModel.toggleSendAmountInputMode()
                guard case let .loaded(state) = viewModel.state else {
                    return XCTFail("Expected loaded state")
                }
                XCTAssertEqual(state.enteredField, enteredField)
                XCTAssertEqual(state.sendAmountInputMode, mode)
                XCTAssertEqual(state.sendAmount, "")
            }
        }

        assertTogglesKeepTheSendAmountEmpty(enteredField: .send)
        viewModel.updateReceiveAmount("2")
        assertTogglesKeepTheSendAmountEmpty(enteredField: .receive)
    }

    /// A quote for the amount to send still in flight when the amount to receive is typed is dropped.
    @MainActor
    func test_exactOutput_quoteInFlightForTheAmountToSendIsDroppedOnceTheAmountToReceiveIsTyped() async throws {
        let oneEth = BigUInt(10).power(18)
        let staleQuote = TestGate()
        let swapService = SwapServiceSpy(
            quoteResults: [
                .success(quote(sourceAmount: oneEth.description, estimatedDestinationAmount: "5000000000")),
                .success(quote(sourceAmount: (oneEth / 2).description, estimatedDestinationAmount: "2000000000")),
            ],
            quoteHolds: [staleQuote, nil],
            ignoreQuoteHoldCancellation: true
        )
        let viewModel = await loadedExactOutputViewModel(swapService: swapService, sendBalance: oneEth * 10)
        viewModel.updateSendAmount("1")
        await waitUntil(swapService.changes) {
            await swapService.quoteRequests().count == 1
        }
        let staleQuoteTask = try XCTUnwrap(viewModel.quoteViewModel.activePairViewModel?.quoteTask)

        viewModel.updateReceiveAmount("2")

        guard case let .loaded(pendingState) = viewModel.state else {
            return XCTFail("Expected loaded state")
        }
        XCTAssertEqual(pendingState.quote.quoteState, .loading)
        XCTAssertNil(pendingState.quote.selectedRoute)

        await waitUntilQuoteReady(viewModel)
        guard case let .loaded(state) = viewModel.state else {
            return XCTFail("Expected loaded state")
        }
        XCTAssertEqual(state.enteredField, .receive)
        XCTAssertEqual(state.sendAmount, "0.5")
        XCTAssertEqual(state.quote.selectedRoute?.estimatedDestinationAmount, "2000000000")

        await staleQuote.open()
        await staleQuoteTask.value
        guard case let .loaded(afterStale) = viewModel.state else {
            return XCTFail("Expected loaded state")
        }
        XCTAssertEqual(afterStale.sendAmount, "0.5")
        XCTAssertEqual(afterStale.quote.selectedRoute?.estimatedDestinationAmount, "2000000000")
    }

    /// A zero the route derives leaves the quoted card empty: the editable card would complete a "0" to
    /// "0." and take it as typed.
    @MainActor
    func test_exactOutput_zeroQuotedAmountLeavesTheQuotedCardEmpty() async {
        let oneEth = BigUInt(10).power(18)
        let swapService = SwapServiceSpy(
            quoteResults: [
                .success(quote(sourceAmount: oneEth.description, estimatedDestinationAmount: "0")),
                .success(quote(sourceAmount: "0", estimatedDestinationAmount: "2000000000")),
            ]
        )
        let viewModel = await loadedExactOutputViewModel(swapService: swapService, sendBalance: oneEth * 10)

        viewModel.updateSendAmount("1")
        await waitUntilQuoteReady(viewModel)
        guard case let .loaded(sendEnteredState) = viewModel.state else {
            return XCTFail("Expected loaded state")
        }
        XCTAssertEqual(sendEnteredState.receiveAmount, "")

        viewModel.updateReceiveAmount("2")
        await waitUntil(swapService.changes) {
            await swapService.quoteRequests().count == 2
        }
        await waitUntilQuoteReady(viewModel)
        guard case let .loaded(receiveEnteredState) = viewModel.state else {
            return XCTFail("Expected loaded state")
        }
        XCTAssertEqual(receiveEnteredState.enteredField, .receive)
        XCTAssertEqual(receiveEnteredState.sendAmount, "")
        XCTAssertEqual(receiveEnteredState.validationState, .routeUnavailable)
    }

    /// While a refresh loads, the send amount still shown keeps the balance check, so "Insufficient
    /// balance" does not drop out until the new route answers.
    @MainActor
    func test_exactOutput_insufficientBalanceHoldsWhileTheQuoteRefreshes() async {
        let oneEth = BigUInt(10).power(18)
        let swapService = SwapServiceSpy(
            quoteResult: .success(quote(sourceAmount: (oneEth / 2).description, estimatedDestinationAmount: "2000000000"))
        )
        let viewModel = await loadedExactOutputViewModel(swapService: swapService, sendBalance: oneEth / 4)
        viewModel.updateReceiveAmount("2")
        await waitUntilQuoteReady(viewModel)

        viewModel.updateReceiveAmount("2.5")

        guard case let .loaded(state) = viewModel.state else {
            return XCTFail("Expected loaded state")
        }
        XCTAssertEqual(state.quote.quoteState, .loading)
        XCTAssertEqual(state.sendAmount, "0.5")
        XCTAssertEqual(state.validationState, .insufficientBalance)
    }

    /// A send amount the route derived is drawn from the route again on a currency switch, so switching
    /// back after a refresh shows the route's amount, not the rounded fiat text converted back.
    @MainActor
    func test_exactOutput_sendCurrencyToggleRedrawsTheRouteAmount() async {
        let routeSourceAmount = BigUInt(123_456_789_012_345_678)
        let swapService = SwapServiceSpy(
            quoteResult: .success(quote(sourceAmount: routeSourceAmount.description, estimatedDestinationAmount: "2000000000"))
        )
        let viewModel = await loadedExactOutputViewModel(
            swapService: swapService,
            sendBalance: BigUInt(10).power(18),
            sendPrice: 2000
        )
        viewModel.updateReceiveAmount("2")
        await waitUntilQuoteReady(viewModel)
        viewModel.toggleSendAmountInputMode()
        viewModel.quoteCountdownDidFinish()
        await waitUntil(swapService.changes) {
            await swapService.quoteRequests().count == 2
        }
        await waitUntilQuoteReady(viewModel)
        guard case let .loaded(fiatState) = viewModel.state else {
            return XCTFail("Expected loaded state")
        }
        XCTAssertEqual(fiatState.sendAmount, "246.91")

        viewModel.toggleSendAmountInputMode()

        guard case let .loaded(state) = viewModel.state else {
            return XCTFail("Expected loaded state")
        }
        XCTAssertEqual(state.sendAmountInputMode, .crypto)
        XCTAssertEqual(state.sendAmount, "0.123456789012345678")
    }

    @MainActor
    func test_flipViaSendPickerResetsReceiveFiatModeWhenNewReceiveCannotPriceFiat() async {
        // send asset unpriced, receive asset priced.
        let defaultAssetsService = DefaultAssetsServiceSpy(
            result: .success(initialAssets(sendPrice: nil, receivePrice: 2))
        )
        let viewModel = makeViewModel(defaultAssetsService: defaultAssetsService)
        await waitUntil(viewModel) {
            if case .loaded = viewModel.state {
                return true
            }
            return false
        }

        viewModel.toggleReceiveAmountInputMode()
        guard case let .loaded(before) = viewModel.state else {
            return XCTFail("Expected loaded state")
        }
        XCTAssertEqual(before.receiveAmountInputMode, .fiat)

        // Pick the current receive asset as the send asset → flip. The new receive
        // asset is the old (unpriced) send asset, which cannot render fiat.
        viewModel.applySendAsset(before.receiveAsset)

        guard case let .loaded(after) = viewModel.state else {
            return XCTFail("Expected loaded state")
        }
        XCTAssertEqual(after.sendAsset.asset.assetId, before.receiveAsset.asset.assetId)
        XCTAssertEqual(after.receiveAsset.asset.assetId, before.sendAsset.asset.assetId)
        XCTAssertEqual(after.receiveAmountInputMode, .crypto)
    }

    @MainActor
    func test_flipViaReceivePickerResetsSendFiatModeWhenNewSendCannotPriceFiat() async {
        // send asset priced, receive asset unpriced.
        let defaultAssetsService = DefaultAssetsServiceSpy(
            result: .success(
                initialAssets(
                    sendBalance: BigUInt(10).power(18) * 10,
                    sendPrice: 2,
                    receivePrice: nil
                )
            )
        )
        let viewModel = makeViewModel(defaultAssetsService: defaultAssetsService)
        await waitUntil(viewModel) {
            if case .loaded = viewModel.state {
                return true
            }
            return false
        }

        viewModel.updateSendAmount("1")
        viewModel.toggleSendAmountInputMode()
        guard case let .loaded(before) = viewModel.state else {
            return XCTFail("Expected loaded state")
        }
        XCTAssertEqual(before.sendAmountInputMode, .fiat)
        XCTAssertFalse(before.sendAmount.isEmpty)

        // Pick the current send asset as the receive asset → flip. The new send
        // asset is the old (unpriced) receive asset, which cannot render fiat.
        viewModel.applyReceiveAsset(before.sendAsset)

        guard case let .loaded(after) = viewModel.state else {
            return XCTFail("Expected loaded state")
        }
        XCTAssertEqual(after.sendAsset.asset.assetId, before.receiveAsset.asset.assetId)
        XCTAssertEqual(after.receiveAsset.asset.assetId, before.sendAsset.asset.assetId)
        XCTAssertEqual(after.sendAmountInputMode, .crypto)
        XCTAssertEqual(after.sendAmount, "")
    }
}

private extension MultichainSwapViewModelTests {
    @MainActor
    func loadedExactOutputViewModel(
        swapService: MultichainSwapService,
        sendBalance: BigUInt = 100,
        sendPrice: Double? = nil,
        receivePrice: Double? = nil,
        swapAggregators: Set<MultichainSwapAggregator> = [.swapsXyz],
        isExactOutputEnabled: Bool = true,
        onContinue: @escaping (MultichainSwapConfirmationInput) -> Void = { _ in }
    ) async -> MultichainSwapViewModel {
        let viewModel = makeViewModel(
            defaultAssetsService: DefaultAssetsServiceSpy(
                result: .success(
                    initialAssets(
                        sendBalance: sendBalance,
                        sendPrice: sendPrice,
                        receivePrice: receivePrice,
                        swapAggregators: swapAggregators
                    )
                )
            ),
            swapService: swapService,
            onContinue: onContinue,
            isExactOutputEnabled: isExactOutputEnabled
        )
        await waitUntil(viewModel) {
            if case .loaded = viewModel.state {
                return true
            }
            return false
        }
        return viewModel
    }

    var oneEth: BigUInt {
        BigUInt(10).power(18)
    }

    /// Loads the screen and quotes one ETH, the swap ready to be confirmed.
    @MainActor
    func quoteOneEth(_ viewModel: MultichainSwapViewModel) async {
        await waitUntil(viewModel) {
            guard case .loaded = viewModel.state else { return false }
            return true
        }
        viewModel.updateSendAmount("1")
        await waitUntil(viewModel) {
            guard case let .loaded(state) = viewModel.state else { return false }
            return state.validationState == .valid && state.quote.quoteState == .ready
        }
    }

    @MainActor
    func waitUntilQuoteReady(_ viewModel: MultichainSwapViewModel) async {
        await waitUntil(viewModel) {
            guard case let .loaded(state) = viewModel.state else {
                return false
            }
            return state.quote.quoteState == .ready
        }
    }

    @MainActor
    func makeViewModel(
        defaultAssetsService: MultichainSwapDefaultAssetsService,
        swapService: MultichainSwapService = SwapServiceSpy(),
        displayCurrency: Currency = .USD,
        onContinue: @escaping (MultichainSwapConfirmationInput) -> Void = { _ in },
        onOpenPricingDetails: @escaping (MultichainSwapConfirmationInput) -> Void = { _ in },
        onInitialSelectionUnavailable: @escaping () -> Void = {},
        onQuoteProviderError: @escaping (String) -> Void = { _ in },
        onQuoteOffline: @escaping () -> Void = {},
        onTonMaxAmountUnavailable: @escaping () -> Void = {},
        isExactOutputEnabled: Bool = false,
        isSwapV3Enabled: Bool = false,
        swapWallet: MultichainSwapWallet? = nil,
        planProvider: MultichainSwapPlanProvider? = nil,
        batteryPromo: MultichainSwapBatteryPromo? = nil,
        onRefillBattery: @escaping (_ onRecharged: @escaping () -> Void) -> Void = { _ in },
        quoteRefreshDuration: TimeInterval = 30,
        sendFailureWait: MultichainSwapQuotePairViewModel.Wait? = nil,
        quoteDebounce: @escaping MultichainSwapQuotePairViewModel.Wait = { _ in },
        routeExpiryWait: MultichainSwapQuotePairViewModel.Wait? = nil,
        now: @escaping () -> Date = Date.init,
        analytics: AnalyticsService? = nil
    ) -> MultichainSwapViewModel {
        let multichainState = MultichainWalletState(
            walletId: "wallet",
            addresses: [
                .init(chain: .eth, address: "0xwallet"),
                .init(chain: .ton, address: "tonwallet"),
            ]
        )
        let wallet = makeWallet(multichainState: multichainState)
        return MultichainSwapViewModel(
            amountFormatter: makeAmountFormatter(),
            multichainSwapService: swapService,
            swapWallet: swapWallet ?? MultichainSwapWallet(wallet: wallet, registeredState: multichainState),
            defaultAssetsService: defaultAssetsService,
            displayCurrency: displayCurrency,
            isExactOutputEnabled: isExactOutputEnabled,
            isSwapV3Enabled: isSwapV3Enabled,
            swapAnalytics: analytics.map { MultichainSwapAnalytics.logging(to: $0, wallet: wallet) },
            planProvider: planProvider,
            batteryPromo: batteryPromo,
            onOpenConfirmation: { input, _, phase in
                switch phase {
                case .swapping:
                    onContinue(input)
                case .pricingDetails:
                    onOpenPricingDetails(input)
                }
            },
            onInitialSelectionUnavailable: onInitialSelectionUnavailable,
            onQuoteProviderError: onQuoteProviderError,
            onQuoteOffline: onQuoteOffline,
            onTonMaxAmountUnavailable: onTonMaxAmountUnavailable,
            onRefillBattery: onRefillBattery,
            quoteRefreshDuration: quoteRefreshDuration,
            sendFailureWait: sendFailureWait,
            quoteDebounce: quoteDebounce,
            routeExpiryWait: routeExpiryWait,
            now: now
        )
    }

    func makeWallet(multichainState: MultichainWalletState) -> Wallet {
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
            multichain: .multichain(multichainState)
        )
    }

    func initialAssets(
        sendAssetId: String = "eth/mainnet/coin",
        sendSymbol: String = "ETH",
        sendDecimals: Int = 18,
        sendBalance: BigUInt = 100,
        receiveBalance: BigUInt = .zero,
        sendPrice: Double? = nil,
        sendPrices: [String: Double]? = nil,
        receivePrice: Double? = nil,
        usdFiatRate: Decimal? = nil,
        hasUnavailableInitialSelection: Bool = false,
        swapAggregators: Set<MultichainSwapAggregator>? = nil
    ) -> MultichainSwapInitialAssets {
        let sendAsset = asset(
            assetId: sendAssetId,
            symbol: sendSymbol,
            decimals: sendDecimals,
            balance: sendBalance,
            usdPrice: sendPrice,
            prices: sendPrices,
            swapAggregators: swapAggregators
        )
        let receiveAsset = asset(
            assetId: "ton/mainnet/coin",
            symbol: "TON",
            decimals: 9,
            balance: receiveBalance,
            usdPrice: receivePrice,
            swapAggregators: swapAggregators
        )
        return MultichainSwapInitialAssets(
            sendAsset: sendAsset,
            receiveAsset: receiveAsset,
            slippage: .init(chains: [:]),
            usdFiatRate: usdFiatRate,
            hasUnavailableInitialSelection: hasUnavailableInitialSelection
        )
    }

    func asset(
        assetId: String,
        symbol: String,
        decimals: Int,
        balance: BigUInt = .zero,
        usdPrice: Double? = nil,
        prices: [String: Double]? = nil,
        swapAggregators: Set<MultichainSwapAggregator>? = nil
    ) -> MultichainAsset {
        MultichainAsset(
            asset: MultichainAssetDetails(
                assetId: assetId,
                name: symbol,
                symbol: symbol,
                decimals: decimals,
                image: "",
                swapAggregators: swapAggregators
            ),
            price: MultichainAssetPrice(
                prices: prices ?? usdPrice.map { [Currency.USD.code.lowercased(): $0] } ?? [:],
                diff24h: [:],
                diff7d: [:]
            ),
            balance: balance
        )
    }

    func swapAsset(
        assetId: String,
        symbol: String,
        decimals: Int,
        chainId: String
    ) -> MultichainSwapAsset {
        MultichainSwapAsset(
            assetId: assetId,
            symbol: symbol,
            name: symbol,
            decimals: decimals,
            image: nil,
            chainFamily: chainId.split(separator: "/").first.map(String.init) ?? "",
            supportedAggregators: ["test"]
        )
    }

    @MainActor
    func loadedViewModel(quote: MultichainSwapQuote) async -> (
        viewModel: MultichainSwapViewModel,
        providerMessage: () -> String?
    ) {
        let oneEth = BigUInt(10).power(18)
        var receivedMessage: String?
        let viewModel = makeViewModel(
            defaultAssetsService: DefaultAssetsServiceSpy(
                result: .success(initialAssets(sendBalance: oneEth * 10))
            ),
            swapService: SwapServiceSpy(quoteResult: .success(quote)),
            onQuoteProviderError: { receivedMessage = $0 }
        )
        await waitUntil(viewModel) {
            if case .loaded = viewModel.state {
                return true
            }
            return false
        }
        return (viewModel, { receivedMessage })
    }

    func screenedQuote(routes: [MultichainSwapRoute]) -> MultichainSwapQuote {
        MultichainSwapQuote(
            quoteId: "quote",
            routes: routes,
            providerErrors: [
                MultichainSwapProviderError(
                    aggregator: "swapsxyz",
                    code: "wallet_screened",
                    message: "wallet blocked by the provider's compliance screening"
                ),
            ]
        )
    }

    func payloadlessRoute(routeId: String, aggregator: String) -> MultichainSwapRoute {
        MultichainSwapRoute(
            routeId: routeId,
            aggregator: aggregator,
            routeType: "cross_chain_swap",
            sourceAmount: BigUInt(10).power(18).description,
            estimatedDestinationAmount: "2500000000",
            minimumDestinationAmount: "2450000000",
            legs: [],
            dateExpire: Date().addingTimeInterval(60),
            riskLevel: "low"
        )
    }

    func quote(
        sourceAmount: String,
        estimatedDestinationAmount: String,
        expiresIn: TimeInterval = 60,
        sourceUsdPrice: Double? = nil,
        destinationUsdPrice: Double? = nil,
        routeId: String = "route"
    ) -> MultichainSwapQuote {
        MultichainSwapQuote(
            quoteId: "quote",
            routes: [
                MultichainSwapRoute(
                    routeId: routeId,
                    aggregator: "test",
                    protocolSlug: "test",
                    routeType: "swap",
                    sourceAmount: sourceAmount,
                    estimatedDestinationAmount: estimatedDestinationAmount,
                    minimumDestinationAmount: estimatedDestinationAmount,
                    sourceUsdPrice: sourceUsdPrice,
                    destinationUsdPrice: destinationUsdPrice,
                    legs: [],
                    dateExpire: Date().addingTimeInterval(expiresIn),
                    riskLevel: "low"
                ),
            ]
        )
    }

    func makeAmountFormatter() -> AmountFormatter {
        var configuration = AmountFormatter.Configuration()
        configuration.locale = Locale(identifier: "en_US_POSIX")
        configuration.space = " "
        return AmountFormatter(configuration: configuration)
    }
}

private actor DefaultAssetsServiceSpy: MultichainSwapDefaultAssetsService {
    private let result: Result<MultichainSwapInitialAssets, Error>
    private let hold: TestGate?
    private(set) var finishedLoads = 0
    nonisolated let changes = TestSignal()

    init(
        result: Result<MultichainSwapInitialAssets, Error>,
        hold: TestGate? = nil
    ) {
        self.result = result
        self.hold = hold
    }

    func load() async throws -> MultichainSwapInitialAssets {
        defer {
            finishedLoads += 1
            changes.send()
        }
        try await hold?.wait()
        return try result.get()
    }
}

private actor SwapServiceSpy: MultichainSwapService {
    private var recordedQuoteRequests = [MultichainSwapQuoteRequest]()
    private var recordedQuoteAPIVersions = [MultichainSwapAPIVersion]()
    private var quoteResults: [Result<MultichainSwapQuote, MultichainSwapAPIError>]
    private var quoteHolds: [TestGate?]
    private let ignoreQuoteHoldCancellation: Bool

    init(
        quoteResult: Result<MultichainSwapQuote, MultichainSwapAPIError> = .failure(.unimplemented)
    ) {
        self.quoteResults = [quoteResult]
        self.quoteHolds = []
        self.ignoreQuoteHoldCancellation = false
    }

    /// A request waits for its hold until the hold opens or the request is cancelled; the last hold
    /// applies to every later request.
    init(
        quoteResults: [Result<MultichainSwapQuote, MultichainSwapAPIError>],
        quoteHolds: [TestGate?] = [],
        ignoreQuoteHoldCancellation: Bool = false
    ) {
        self.quoteResults = quoteResults
        self.quoteHolds = quoteHolds
        self.ignoreQuoteHoldCancellation = ignoreQuoteHoldCancellation
    }

    nonisolated let changes = TestSignal()

    func quoteRequests() -> [MultichainSwapQuoteRequest] {
        recordedQuoteRequests
    }

    /// The API each quote was asked on, in order.
    func quoteAPIVersions() -> [MultichainSwapAPIVersion] {
        recordedQuoteAPIVersions
    }

    func createCrossSwapQuote(
        request: MultichainSwapQuoteRequest,
        walletId _: String?
    ) async throws(MultichainSwapAPIError) -> MultichainSwapQuote {
        try await answer(request, on: .v2)
    }

    /// Answers as `/v3` does: the same routes, quoted there.
    func createCrossSwapQuoteV3(
        request: MultichainSwapQuoteRequest,
        walletId _: String
    ) async throws(MultichainSwapAPIError) -> MultichainSwapQuote {
        var quote = try await answer(request, on: .v3)
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
    ) async throws(MultichainSwapAPIError) -> MultichainSwapQuote {
        recordedQuoteRequests.append(request)
        recordedQuoteAPIVersions.append(apiVersion)
        changes.send()
        let result = nextQuoteResult()
        if let hold = nextQuoteHold() {
            if ignoreQuoteHoldCancellation {
                await Task { try? await hold.wait() }.value
            } else {
                try? await hold.wait()
                if Task.isCancelled {
                    throw .canceledHold
                }
            }
        }
        return try result.get()
    }

    private func nextQuoteResult() -> Result<MultichainSwapQuote, MultichainSwapAPIError> {
        guard quoteResults.count > 1 else {
            return quoteResults.first ?? .failure(.unimplemented)
        }
        return quoteResults.removeFirst()
    }

    private func nextQuoteHold() -> TestGate? {
        guard quoteHolds.count > 1 else {
            return quoteHolds.first ?? nil
        }
        return quoteHolds.removeFirst()
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

private enum StubError: Error {
    case unimplemented
}

private extension MultichainSwapAPIError {
    static let unimplemented = MultichainSwapAPIError.unknown(statusCode: -1)
    static let canceledHold = MultichainSwapAPIError.unknown(statusCode: -2)
    static let offline = MultichainSwapAPIError.transportError(
        diagnostic: MultichainAPIDiagnostic(error: URLError(.notConnectedToInternet))
    )
}

private extension MultichainSwapViewModelTests {
    var ethDetails: MultichainAssetDetails {
        MultichainAssetDetails(assetId: "eth/mainnet/coin", name: "ETH", symbol: "ETH", decimals: 18, image: "")
    }
}

/// Prepares every route with the same fee options, unless a failure is queued for that call, and counts how
/// often it was asked.
private final class FeePlanServiceStub: MultichainSwapExecutionService {
    private(set) var callCount = 0
    private let feeOptions: [MultichainSwapFeeOption]
    private let failures: [MultichainSwapExecutionFailure]

    init(feeOptions: [MultichainSwapFeeOption], failures: [MultichainSwapExecutionFailure] = []) {
        self.feeOptions = feeOptions
        self.failures = failures
    }

    func prepareExecutionPlan(
        swapWallet _: MultichainSwapWallet,
        sourceAsset _: MultichainAsset,
        destinationAsset _: MultichainAsset,
        route: MultichainSwapRoute
    ) async throws(MultichainSwapExecutionFailure) -> MultichainSwapExecutionPlan {
        callCount += 1
        if failures.indices.contains(callCount - 1) {
            throw failures[callCount - 1]
        }
        return MultichainSwapExecutionPlan(
            routeId: route.routeId,
            aggregator: .swapsXyz,
            payloads: .main(MultichainSwapPreparedPayload(
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
            )),
            networkFees: [],
            feeOptions: feeOptions,
            payloadFees: [:]
        )
    }

    func execute(
        signer _: MultichainTransferSigner,
        swapWallet _: MultichainSwapWallet,
        sourceAsset _: MultichainAsset,
        destinationAsset _: MultichainAsset,
        executionPlan _: MultichainSwapExecutionPlan,
        feeMethod _: MultichainSwapFeeMethod,
        spendLimit _: BigUInt,
        consent _: OperationConsent
    ) async throws(MultichainSwapExecutionFailure) -> MultichainSwapExecutionResult {
        throw .internal(reason: "not used")
    }
}

private final class AnalyticsServiceSpy: AnalyticsService {
    private(set) var events = [(name: String, args: [String: Any])]()

    func logEvent(name: String, args: [String: Any]) {
        events.append((name: name, args: args))
    }
}
