@testable import App
import BigInt
import Foundation
@testable import KeeperCore
import TKLocalize
import TonSwift
import XCTest

final class MultichainSwapViewModelTests: XCTestCase {
    @MainActor
    func test_initialStateIsShimmerWhileInitialAssetsAreLoading() {
        let defaultAssetsService = DefaultAssetsServiceSpy(
            result: .success(initialAssets()),
            delayNanoseconds: 1_000_000_000
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

        await waitUntil {
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
        XCTAssertEqual(state.quote.rateText.stringValue, "Enter amount")
        let requests = await swapService.quoteRequests()
        XCTAssertEqual(requests.count, 0)
    }

    @MainActor
    func test_failedInitialAssetsLoadShowsRetryableErrorState() async {
        let defaultAssetsService = DefaultAssetsServiceSpy(
            result: .failure(StubError.unimplemented)
        )
        let viewModel = makeViewModel(defaultAssetsService: defaultAssetsService)

        await waitUntil {
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
        var didReportUnavailableSelection = false
        let viewModel = makeViewModel(
            defaultAssetsService: defaultAssetsService,
            onInitialSelectionUnavailable: {
                didReportUnavailableSelection = true
            }
        )

        await waitUntil {
            didReportUnavailableSelection
        }

        guard case .loaded = viewModel.state else {
            return XCTFail("Expected loaded state")
        }
    }

    @MainActor
    func test_closeCancelsInitialAssetsLoading() async {
        let defaultAssetsService = DefaultAssetsServiceSpy(
            result: .success(initialAssets(hasUnavailableInitialSelection: true)),
            delayNanoseconds: 1_000_000_000
        )
        var didReportUnavailableSelection = false
        let viewModel = makeViewModel(
            defaultAssetsService: defaultAssetsService,
            onInitialSelectionUnavailable: {
                didReportUnavailableSelection = true
            }
        )

        viewModel.close()
        try? await Task.sleep(nanoseconds: 50_000_000)

        XCTAssertFalse(didReportUnavailableSelection)
    }

    @MainActor
    func test_initialAssetsLoadingDoesNotRetainViewModel() async {
        let defaultAssetsService = DefaultAssetsServiceSpy(
            result: .success(initialAssets()),
            delayNanoseconds: 5_000_000_000
        )
        var viewModel: MultichainSwapViewModel? = makeViewModel(
            defaultAssetsService: defaultAssetsService
        )
        weak var weakViewModel: MultichainSwapViewModel?
        weakViewModel = viewModel

        await Task.yield()
        viewModel = nil

        await waitUntil {
            weakViewModel == nil
        }
    }

    @MainActor
    func test_actionsDuringShimmerDoNotRequestQuoteOrPicker() async {
        let defaultAssetsService = DefaultAssetsServiceSpy(
            result: .success(initialAssets()),
            delayNanoseconds: 1_000_000_000
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
        viewModel.applyMaxSend()
        viewModel.toggleRateDisplayDirection()
        viewModel.notifyCircularProgressCompleted()
        viewModel.requestPickSendToken()
        viewModel.requestPickReceiveToken()
        viewModel.continueSwap()

        try? await Task.sleep(nanoseconds: 50_000_000)

        XCTAssertFalse(didRequestSendPicker)
        XCTAssertFalse(didRequestReceivePicker)
        guard case .shimmer = viewModel.state else {
            return XCTFail("Expected shimmer state")
        }
        let quoteRequestCount = await swapService.quoteRequests().count
        XCTAssertEqual(quoteRequestCount, 0)
    }

    @MainActor
    func test_applyMaxSend_reportsUnavailableTonBalanceBelowReserve() async {
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
            catalog: [
                "ton/mainnet/coin": swapAsset(assetId: "ton/mainnet/coin", symbol: "GRAM", decimals: 9, chainId: "ton/mainnet"),
                "eth/mainnet/coin": swapAsset(assetId: "eth/mainnet/coin", symbol: "ETH", decimals: 18, chainId: "eth/mainnet"),
            ],
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

        await waitUntil {
            guard case .loaded = viewModel.state else {
                return false
            }
            return true
        }

        viewModel.applyMaxSend()

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

        await waitUntil {
            guard case .loaded = viewModel.state else {
                return false
            }
            return true
        }

        viewModel.updateSendAmount("1")

        await waitUntil(timeout: 2) {
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
        XCTAssertTrue(cryptoState.quote.rateText.stringValue.hasPrefix("1 ETH"))

        let requestCountBeforeRateToggle = await swapService.quoteRequests().count
        viewModel.toggleRateDisplayDirection()
        guard case let .loaded(invertedRateState) = viewModel.state else {
            return XCTFail("Expected loaded state")
        }
        XCTAssertTrue(invertedRateState.quote.rateText.stringValue.hasPrefix("1 TON"))
        try? await Task.sleep(nanoseconds: 100_000_000)
        let requestCountAfterRateToggle = await swapService.quoteRequests().count
        XCTAssertEqual(requestCountAfterRateToggle, requestCountBeforeRateToggle)

        viewModel.toggleSendAmountInputMode()

        await waitUntil(timeout: 2) {
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
        XCTAssertEqual(requests.last?.sourceAmount, oneEth.description)

        viewModel.continueSwap()
        XCTAssertEqual(confirmationInput?.userInput.sendAmount, "1")
        XCTAssertEqual(confirmationInput?.userInput.sourceAmount, oneEth)
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

        await waitUntil {
            guard case .loaded = viewModel.state else {
                return false
            }
            return true
        }

        viewModel.updateSendAmount("1")
        await waitUntil(timeout: 2) {
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

        try? await Task.sleep(nanoseconds: 300_000_000)
        let requests = await swapService.quoteRequests()
        XCTAssertTrue(requests.allSatisfy { $0.sourceAmount == oneEth.description })
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

        await waitUntil {
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

        await waitUntil {
            guard case .loaded = viewModel.state else {
                return false
            }
            return true
        }

        viewModel.applyMaxSend()
        await waitUntil(timeout: 2) {
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
        XCTAssertEqual(confirmationInput?.userInput.sourceAmount, balance)
        XCTAssertEqual(confirmationInput?.userInput.isMax, true)
    }

    @MainActor
    func test_usdOnlyPricesWithoutFxRateShowOnlyZeroFiatAndKeepFiatInputDisabled() async {
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
        let viewModel = makeViewModel(
            defaultAssetsService: defaultAssetsService,
            swapService: swapService,
            displayCurrency: .EUR
        )

        await waitUntil {
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

        await waitUntil(timeout: 2) {
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

        try? await Task.sleep(nanoseconds: 100_000_000)
        let requestCountAfterToggle = await swapService.quoteRequests().count
        XCTAssertEqual(requestCountAfterToggle, requestCountBeforeToggle)
    }

    @MainActor
    func test_fxRateConvertsUsdPricesToDisplayCurrency() async {
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
        let viewModel = makeViewModel(
            defaultAssetsService: defaultAssetsService,
            swapService: swapService,
            displayCurrency: .EUR
        )

        await waitUntil {
            guard case .loaded = viewModel.state else {
                return false
            }
            return true
        }
        viewModel.updateSendAmount("1")
        await waitUntil(timeout: 2) {
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
        XCTAssertEqual(fiatState.receiveAmountFiatSymbol, Currency.EUR.symbol)
        XCTAssertEqual(fiatState.receiveAmount, "2.25")
        XCTAssertEqual(fiatState.receiveCardRateText, "5 TON")
    }

    @MainActor
    func test_quoteDerivedFxRateConvertsUsdPricesWhenWalletRateIsMissing() async {
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
        let viewModel = makeViewModel(
            defaultAssetsService: defaultAssetsService,
            swapService: swapService,
            displayCurrency: .RUB
        )

        await waitUntil {
            guard case .loaded = viewModel.state else {
                return false
            }
            return true
        }
        viewModel.updateSendAmount("1")
        await waitUntil(timeout: 2) {
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

        await waitUntil {
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

        await waitUntil(timeout: 2) {
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

        await waitUntil {
            guard case .loaded = viewModel.state else {
                return false
            }
            return true
        }
        viewModel.updateSendAmount("1")
        await waitUntil(timeout: 2) {
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
    func test_toggleReceiveAmountInputModeIsIgnoredWithoutDisplayCurrencyPrice() async {
        let oneEth = BigUInt(10).power(18)
        let defaultAssetsService = DefaultAssetsServiceSpy(
            result: .success(
                initialAssets(
                    sendBalance: oneEth * 10,
                    receivePrice: 5.5
                )
            )
        )
        let viewModel = makeViewModel(
            defaultAssetsService: defaultAssetsService,
            displayCurrency: .EUR
        )

        await waitUntil {
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
    func test_toggleReceiveAmountInputModeIsIgnoredWithoutAssetOrRoutePrice() async {
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
        let viewModel = makeViewModel(
            defaultAssetsService: defaultAssetsService,
            displayCurrency: .EUR
        )

        await waitUntil {
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
        let viewModel = makeViewModel(
            defaultAssetsService: defaultAssetsService,
            swapService: swapService
        )

        await waitUntil {
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
        XCTAssertEqual(loadingState.quote.rateText.stringValue, "Fetching quote")
        XCTAssertTrue(loadingState.shouldShowReceiveQuoteShimmer)
        XCTAssertNil(loadingState.quote.lastReadyRateText)
        var requests = await swapService.quoteRequests()
        XCTAssertEqual(requests.count, 0)

        try? await Task.sleep(nanoseconds: 100_000_000)
        requests = await swapService.quoteRequests()
        XCTAssertEqual(requests.count, 0)

        await waitUntilAsync(timeout: 2) {
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
            ],
            quoteDelayNanoseconds: [
                0,
                0,
            ]
        )
        let viewModel = makeViewModel(
            defaultAssetsService: defaultAssetsService,
            swapService: swapService
        )

        await waitUntil {
            guard case .loaded = viewModel.state else {
                return false
            }
            return true
        }

        viewModel.updateSendAmount("1")
        await waitUntil(timeout: 2) {
            guard case let .loaded(state) = viewModel.state else {
                return false
            }
            return state.quote.quoteState == .ready
                && state.receiveAmount == "5"
        }

        guard case let .loaded(readyState) = viewModel.state else {
            return XCTFail("Expected loaded state")
        }
        let lastReadyRateText = readyState.quote.rateText.stringValue

        viewModel.updateSendAmount("2")

        guard case let .loaded(loadingState) = viewModel.state else {
            return XCTFail("Expected loaded state")
        }
        XCTAssertEqual(loadingState.quote.quoteState, .loading)
        XCTAssertEqual(loadingState.receiveAmount, "5")
        XCTAssertNil(loadingState.quote.selectedRoute)
        XCTAssertFalse(loadingState.shouldShowReceiveQuoteShimmer)
        XCTAssertEqual(loadingState.quote.lastReadyRateText?.stringValue, lastReadyRateText)
        XCTAssertEqual(loadingState.validationState, .routeUnavailable)

        await waitUntil(timeout: 2) {
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

        await waitUntil {
            guard case .loaded = viewModel.state else {
                return false
            }
            return true
        }

        viewModel.updateSendAmount("1")
        viewModel.continueSwap()
        XCTAssertNil(confirmationInput)

        await waitUntil(timeout: 2) {
            guard case let .loaded(state) = viewModel.state else {
                return false
            }
            return state.quote.quoteState == .ready
        }

        viewModel.continueSwap()
        XCTAssertNotNil(confirmationInput)
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
        let viewModel = makeViewModel(
            defaultAssetsService: defaultAssetsService,
            swapService: swapService,
            onContinue: { input in
                confirmationInputs.append(input)
            }
        )

        await waitUntil {
            guard case .loaded = viewModel.state else {
                return false
            }
            return true
        }

        viewModel.updateSendAmount("1")
        await waitUntil(timeout: 2) {
            guard case let .loaded(state) = viewModel.state else {
                return false
            }
            return state.quote.quoteState == .ready
                && state.validationState == .valid
        }

        viewModel.continueSwap()
        XCTAssertEqual(confirmationInputs.count, 1)

        await waitUntil(timeout: 2) {
            guard case let .loaded(state) = viewModel.state else {
                return false
            }
            return state.quote.quoteState == .failed
                && state.quote.selectedRoute == nil
                && state.receiveAmount.isEmpty
                && state.validationState == .routeUnavailable
        }

        guard case let .loaded(failedState) = viewModel.state else {
            return XCTFail("Expected loaded state")
        }
        XCTAssertEqual(
            failedState.quote.rateText.stringValue,
            TKLocales.NativeSwap.Quote.Rate.unavailable
        )
        XCTAssertNil(failedState.quote.lastReadyRateText)

        viewModel.continueSwap()
        XCTAssertEqual(confirmationInputs.count, 1)
    }

    @MainActor
    func test_pairChangeRefreshesQuoteWithoutDebounce() async {
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
            ),
            quoteDelayNanoseconds: 1_000_000_000
        )
        let viewModel = makeViewModel(
            defaultAssetsService: defaultAssetsService,
            swapService: swapService
        )

        await waitUntil {
            guard case .loaded = viewModel.state else {
                return false
            }
            return true
        }

        viewModel.updateSendAmount("1")
        await waitUntilAsync(timeout: 2) {
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
        XCTAssertEqual(loadingState.quote.rateText.stringValue, "Fetching quote")
        await waitUntilAsync(timeout: 0.2) {
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

        await waitUntil {
            guard case .loaded = viewModel.state else {
                return false
            }
            return true
        }

        viewModel.updateSendAmount("1")
        await waitUntil(timeout: 2) {
            guard case let .loaded(state) = viewModel.state else {
                return false
            }
            return state.quote.quoteState == .ready
        }

        viewModel.updateReceiveAmount("999")
        viewModel.continueSwap()

        XCTAssertEqual(confirmationInput?.userInput.sendAmount, "1.25")
        XCTAssertEqual(
            confirmationInput?.quoteState.route.estimatedDestinationAmount,
            "4560000000"
        )
        XCTAssertEqual(confirmationInput?.userInput.sourceAmount, routeSourceAmount)
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

        await waitUntil {
            guard case .loaded = viewModel.state else {
                return false
            }
            return true
        }

        viewModel.updateSendAmount("1")
        await waitUntil(timeout: 2) {
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
            ],
            quoteDelayNanoseconds: [
                0,
                1_000_000_000,
            ]
        )
        let viewModel = makeViewModel(
            defaultAssetsService: defaultAssetsService,
            swapService: swapService
        )

        await waitUntil {
            guard case .loaded = viewModel.state else {
                return false
            }
            return true
        }

        viewModel.updateSendAmount("1")
        await waitUntil(timeout: 2) {
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
        XCTAssertTrue(pairChangeState.shouldShowReceiveQuoteShimmer)
        XCTAssertNil(pairChangeState.quote.lastReadyRateText)
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
            ],
            quoteDelayNanoseconds: [
                0,
                1_000_000_000,
            ]
        )
        let viewModel = makeViewModel(
            defaultAssetsService: defaultAssetsService,
            swapService: swapService
        )

        await waitUntil {
            guard case .loaded = viewModel.state else {
                return false
            }
            return true
        }

        viewModel.updateSendAmount("1")
        await waitUntil(timeout: 2) {
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
        XCTAssertFalse(swappedState.shouldShowReceiveQuoteShimmer)
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
            ],
            quoteDelayNanoseconds: [
                0,
                1_000_000_000,
            ]
        )
        let viewModel = makeViewModel(
            defaultAssetsService: defaultAssetsService,
            swapService: swapService
        )

        await waitUntil {
            guard case .loaded = viewModel.state else {
                return false
            }
            return true
        }

        viewModel.updateSendAmount("1")
        await waitUntil(timeout: 2) {
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

        await waitUntil {
            guard case .loaded = viewModel.state else {
                return false
            }
            return true
        }

        viewModel.updateSendAmount("1")
        await waitUntil(timeout: 2) {
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

        await waitUntilAsync(timeout: 2) {
            await swapService.quoteRequests().count > requestCountBeforeSwap
        }
    }

    @MainActor
    func test_oldInFlightPairQuoteCannotOverwriteSnapshotAfterPairSwitch() async {
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
            ],
            quoteDelayNanoseconds: [
                300_000_000,
                0,
            ],
            ignoreQuoteDelayCancellation: true
        )
        let viewModel = makeViewModel(
            defaultAssetsService: defaultAssetsService,
            swapService: swapService
        )

        await waitUntil {
            guard case .loaded = viewModel.state else {
                return false
            }
            return true
        }

        viewModel.updateSendAmount("1")
        await waitUntilAsync(timeout: 2) {
            await swapService.quoteRequests().count == 1
        }

        viewModel.applyReceiveAsset(
            asset(
                assetId: "ton/mainnet/usdt",
                symbol: "USDT",
                decimals: 6
            )
        )

        await waitUntil(timeout: 2) {
            guard case let .loaded(state) = viewModel.state else {
                return false
            }
            return state.quote.quoteState == .ready
                && state.receiveAsset.asset.symbol == "USDT"
                && state.receiveAmount == "7"
        }

        try? await Task.sleep(nanoseconds: 500_000_000)

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
    func test_timerRefreshRestartsCircularProgressOnlyAfterSuccessfulQuote() async {
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
                        estimatedDestinationAmount: "6000000000"
                    )
                ),
            ],
            quoteDelayNanoseconds: [
                0,
                1_000_000_000,
            ]
        )
        let viewModel = makeViewModel(
            defaultAssetsService: defaultAssetsService,
            swapService: swapService
        )

        await waitUntil {
            guard case .loaded = viewModel.state else {
                return false
            }
            return true
        }
        viewModel.updateSendAmount("1")
        await waitUntil(timeout: 2) {
            guard case let .loaded(state) = viewModel.state else {
                return false
            }
            return state.quote.quoteState == .ready
        }

        guard case let .loaded(readyState) = viewModel.state else {
            return XCTFail("Expected loaded state")
        }
        XCTAssertEqual(readyState.quote.progressRestartToken, 1)

        viewModel.notifyCircularProgressCompleted()

        guard case let .loaded(loadingState) = viewModel.state else {
            return XCTFail("Expected loaded state")
        }
        XCTAssertEqual(loadingState.quote.quoteState, .loading)
        XCTAssertEqual(loadingState.quote.progressRestartToken, 1)
        XCTAssertEqual(loadingState.quote.rateText.stringValue, "Fetching quote")
        await waitUntilAsync(timeout: 0.2) {
            await swapService.quoteRequests().count == 2
        }

        try? await Task.sleep(nanoseconds: 100_000_000)
        guard case let .loaded(stillLoadingState) = viewModel.state else {
            return XCTFail("Expected loaded state")
        }
        XCTAssertEqual(stillLoadingState.quote.progressRestartToken, 1)

        await waitUntil(timeout: 2) {
            guard case let .loaded(state) = viewModel.state else {
                return false
            }
            return state.quote.quoteState == .ready
                && state.quote.progressRestartToken == 2
                && state.receiveAmount == "6"
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

        await waitUntil {
            guard case .loaded = viewModel.state else {
                return false
            }
            return true
        }
        viewModel.updateSendAmount("1")

        await waitUntil(timeout: 2) {
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
        XCTAssertEqual(failedState.quote.rateText.stringValue, "Couldn't get a quote. Change amount")
        XCTAssertEqual(failedState.validationState, .routeUnavailable)
        XCTAssertEqual(failedState.quote.progressRestartToken, 0)

        viewModel.notifyCircularProgressCompleted()
        try? await Task.sleep(nanoseconds: 100_000_000)
        let requests = await swapService.quoteRequests()
        XCTAssertEqual(requests.count, 1)
    }

    @MainActor
    func test_resettingAmountClearsLastReadyRateText() async {
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

        await waitUntil {
            guard case .loaded = viewModel.state else {
                return false
            }
            return true
        }

        viewModel.updateSendAmount("1")
        await waitUntil(timeout: 2) {
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
        XCTAssertNil(state.quote.lastReadyRateText)
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
        let viewModel = makeViewModel(
            defaultAssetsService: defaultAssetsService,
            swapService: swapService,
            onQuoteProviderError: { receivedMessage = $0 }
        )

        await waitUntil {
            if case .loaded = viewModel.state {
                return true
            }
            return false
        }
        viewModel.updateSendAmount("1")

        await waitUntil { receivedMessage != nil }
        XCTAssertEqual(receivedMessage, TKLocales.MultichainSwap.ProviderError.unknown)
        XCTAssertNotEqual(receivedMessage, providerMessage)
        guard case let .loaded(state) = viewModel.state else {
            return XCTFail("Expected loaded state")
        }
        // No routes ⇒ unavailable, not "route expired" — otherwise the rate row
        // would contradict the provider error toast.
        XCTAssertEqual(state.quote.quoteState, .failed)
        XCTAssertEqual(state.quote.rateText.stringValue, "Couldn't get a quote. Change amount")
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

        await waitUntil {
            if case .loaded = viewModel.state {
                return true
            }
            return false
        }
        viewModel.updateSendAmount("1")

        await waitUntil {
            guard case let .loaded(state) = viewModel.state else {
                return false
            }
            return state.quote.quoteState == .failed
        }
        guard case let .loaded(state) = viewModel.state else {
            return XCTFail("Expected loaded state")
        }
        XCTAssertEqual(
            state.quote.rateText.stringValue,
            TKLocales.NativeSwap.Quote.Rate.pairUnavailable
        )
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

        await waitUntil {
            if case .loaded = viewModel.state { return true }
            return false
        }
        viewModel.updateSendAmount("1")

        await waitUntil {
            guard case let .loaded(state) = viewModel.state else {
                return false
            }
            return state.quote.quoteState == .failed
        }
        guard case let .loaded(state) = viewModel.state else {
            return XCTFail("Expected loaded state")
        }
        XCTAssertEqual(
            state.quote.rateText.stringValue,
            TKLocales.NativeSwap.Quote.Rate.pairUnavailable
        )
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

        await waitUntil {
            if case .loaded = viewModel.state { return true }
            return false
        }
        viewModel.updateSendAmount("1")

        await waitUntil {
            guard case let .loaded(state) = viewModel.state else {
                return false
            }
            return state.quote.quoteState == .failed
        }
        guard case let .loaded(state) = viewModel.state else {
            return XCTFail("Expected loaded state")
        }
        XCTAssertNotEqual(
            state.quote.rateText.stringValue,
            TKLocales.NativeSwap.Quote.Rate.pairUnavailable
        )
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

        await waitUntil {
            if case .loaded = viewModel.state {
                return true
            }
            return false
        }
        viewModel.updateSendAmount("1")

        await waitUntil {
            guard case let .loaded(state) = viewModel.state else {
                return false
            }
            return state.quote.quoteState == .failed
        }
        guard case let .loaded(state) = viewModel.state else {
            return XCTFail("Expected loaded state")
        }
        XCTAssertEqual(
            state.quote.rateText.stringValue,
            TKLocales.NativeSwap.Quote.Rate.pairUnavailable
        )
        XCTAssertNil(receivedMessage)
    }

    @MainActor
    func test_failedRefreshClearsLastReadyRateText() async {
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
            ],
            quoteDelayNanoseconds: [0, 0]
        )
        let viewModel = makeViewModel(
            defaultAssetsService: defaultAssetsService,
            swapService: swapService
        )

        await waitUntil {
            guard case .loaded = viewModel.state else {
                return false
            }
            return true
        }

        viewModel.updateSendAmount("1")
        await waitUntil(timeout: 2) {
            guard case let .loaded(state) = viewModel.state else {
                return false
            }
            return state.quote.quoteState == .ready
        }

        viewModel.updateSendAmount("2")
        await waitUntil(timeout: 2) {
            guard case let .loaded(state) = viewModel.state else {
                return false
            }
            return state.quote.quoteState == .failed
        }

        guard case let .loaded(state) = viewModel.state else {
            return XCTFail("Expected loaded state")
        }
        XCTAssertNil(state.quote.lastReadyRateText)
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
            ],
            quoteDelayNanoseconds: [0, 0]
        )
        let viewModel = makeViewModel(
            defaultAssetsService: defaultAssetsService,
            swapService: swapService
        )

        await waitUntil {
            guard case .loaded = viewModel.state else {
                return false
            }
            return true
        }

        viewModel.updateSendAmount("1")
        await waitUntil(timeout: 2) {
            guard case let .loaded(state) = viewModel.state else {
                return false
            }
            return state.quote.quoteState == .ready
        }

        viewModel.updateSendAmount("2")
        await waitUntil(timeout: 2) {
            guard case let .loaded(state) = viewModel.state else {
                return false
            }
            return state.quote.quoteState == .failed
        }

        guard case let .loaded(failedState) = viewModel.state else {
            return XCTFail("Expected loaded state")
        }
        XCTAssertEqual(failedState.receiveAmount, "")
        XCTAssertTrue(failedState.isReceiveQuoteUnavailable)
        XCTAssertFalse(failedState.shouldShowReceiveQuoteShimmer)

        viewModel.updateSendAmount("3")

        guard case let .loaded(refreshState) = viewModel.state else {
            return XCTFail("Expected loaded state")
        }
        XCTAssertEqual(refreshState.quote.quoteState, .loading)
        XCTAssertEqual(refreshState.receiveAmount, "")
        XCTAssertTrue(refreshState.shouldShowReceiveQuoteShimmer)
        XCTAssertFalse(refreshState.isReceiveQuoteUnavailable)
    }
}

private extension MultichainSwapViewModelTests {
    @MainActor
    func test_flipViaSendPickerResetsReceiveFiatModeWhenNewReceiveCannotPriceFiat() async {
        // send asset unpriced, receive asset priced.
        let defaultAssetsService = DefaultAssetsServiceSpy(
            result: .success(initialAssets(sendPrice: nil, receivePrice: 2))
        )
        let viewModel = makeViewModel(defaultAssetsService: defaultAssetsService)
        await waitUntil {
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
        await waitUntil {
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

    @MainActor
    func makeViewModel(
        defaultAssetsService: MultichainSwapDefaultAssetsService,
        swapService: MultichainSwapService = SwapServiceSpy(),
        displayCurrency: Currency = .USD,
        onContinue: @escaping (MultichainSwapConfirmationInput) -> Void = { _ in },
        onInitialSelectionUnavailable: @escaping () -> Void = {},
        onQuoteProviderError: @escaping (String) -> Void = { _ in },
        onTonMaxAmountUnavailable: @escaping () -> Void = {}
    ) -> MultichainSwapViewModel {
        let multichainState = MultichainWalletState(
            walletId: "wallet",
            addresses: [
                .init(chain: .eth, address: "0xwallet"),
                .init(chain: .ton, address: "tonwallet"),
            ]
        )
        return MultichainSwapViewModel(
            amountFormatter: makeAmountFormatter(),
            multichainSwapService: swapService,
            multichainState: multichainState,
            wallet: makeWallet(multichainState: multichainState),
            defaultAssetsService: defaultAssetsService,
            displayCurrency: displayCurrency,
            onContinue: onContinue,
            onInitialSelectionUnavailable: onInitialSelectionUnavailable,
            onQuoteProviderError: onQuoteProviderError,
            onTonMaxAmountUnavailable: onTonMaxAmountUnavailable
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
        sendBalance: BigUInt = 100,
        receiveBalance: BigUInt = .zero,
        sendPrice: Double? = nil,
        sendPrices: [String: Double]? = nil,
        receivePrice: Double? = nil,
        usdFiatRate: Decimal? = nil,
        hasUnavailableInitialSelection: Bool = false
    ) -> MultichainSwapInitialAssets {
        let sendAsset = asset(
            assetId: "eth/mainnet/coin",
            symbol: "ETH",
            decimals: 18,
            balance: sendBalance,
            usdPrice: sendPrice,
            prices: sendPrices
        )
        let receiveAsset = asset(
            assetId: "ton/mainnet/coin",
            symbol: "TON",
            decimals: 9,
            balance: receiveBalance,
            usdPrice: receivePrice
        )
        return MultichainSwapInitialAssets(
            sendAsset: sendAsset,
            receiveAsset: receiveAsset,
            catalog: [
                sendAsset.asset.assetId: swapAsset(assetId: sendAsset.asset.assetId, symbol: "ETH", decimals: 18, chainId: "eth/mainnet"),
                receiveAsset.asset.assetId: swapAsset(assetId: receiveAsset.asset.assetId, symbol: "TON", decimals: 9, chainId: "ton/mainnet"),
            ],
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
        prices: [String: Double]? = nil
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
                prices: prices ?? usdPrice.map { [Currency.USD.code.lowercased(): $0] } ?? [:],
                diff24h: [:],
                diff7d: [:],
                diff30d: [:]
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

    func quote(
        sourceAmount: String,
        estimatedDestinationAmount: String,
        expiresIn: TimeInterval = 60,
        sourceUsdPrice: Double? = nil,
        destinationUsdPrice: Double? = nil
    ) -> MultichainSwapQuote {
        MultichainSwapQuote(
            quoteId: "quote",
            routes: [
                MultichainSwapRoute(
                    routeId: "route",
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

    @MainActor
    func waitUntilAsync(
        timeout: TimeInterval = 1,
        condition: @escaping () async -> Bool
    ) async {
        let deadline = Date().addingTimeInterval(timeout)
        while !(await condition()), Date() < deadline {
            try? await Task.sleep(nanoseconds: 10_000_000)
        }
        if !(await condition()) {
            XCTFail("Timed out waiting for condition")
        }
    }
}

private actor DefaultAssetsServiceSpy: MultichainSwapDefaultAssetsService {
    private let result: Result<MultichainSwapInitialAssets, Error>
    private let delayNanoseconds: UInt64

    init(
        result: Result<MultichainSwapInitialAssets, Error>,
        delayNanoseconds: UInt64 = 0
    ) {
        self.result = result
        self.delayNanoseconds = delayNanoseconds
    }

    func load() async throws -> MultichainSwapInitialAssets {
        if delayNanoseconds > 0 {
            try await Task.sleep(nanoseconds: delayNanoseconds)
        }
        return try result.get()
    }
}

private actor SwapServiceSpy: MultichainSwapService {
    private var recordedQuoteRequests = [MultichainSwapQuoteRequest]()
    private var quoteResults: [Result<MultichainSwapQuote, MultichainSwapAPIError>]
    private var quoteDelayNanoseconds: [UInt64]
    private let ignoreQuoteDelayCancellation: Bool

    init(
        quoteResult: Result<MultichainSwapQuote, MultichainSwapAPIError> = .failure(.unimplemented),
        quoteDelayNanoseconds: UInt64 = 0,
        ignoreQuoteDelayCancellation: Bool = false
    ) {
        self.quoteResults = [quoteResult]
        self.quoteDelayNanoseconds = [quoteDelayNanoseconds]
        self.ignoreQuoteDelayCancellation = ignoreQuoteDelayCancellation
    }

    init(
        quoteResults: [Result<MultichainSwapQuote, MultichainSwapAPIError>],
        quoteDelayNanoseconds: [UInt64],
        ignoreQuoteDelayCancellation: Bool = false
    ) {
        self.quoteResults = quoteResults
        self.quoteDelayNanoseconds = quoteDelayNanoseconds
        self.ignoreQuoteDelayCancellation = ignoreQuoteDelayCancellation
    }

    func quoteRequests() -> [MultichainSwapQuoteRequest] {
        recordedQuoteRequests
    }

    func createCrossSwapQuote(
        request: MultichainSwapQuoteRequest,
        walletId _: String?
    ) async throws(MultichainSwapAPIError) -> MultichainSwapQuote {
        recordedQuoteRequests.append(request)
        let result = nextQuoteResult()
        let delayNanoseconds = nextQuoteDelayNanoseconds()
        if delayNanoseconds > 0 {
            try? await Task.sleep(nanoseconds: delayNanoseconds)
            if !ignoreQuoteDelayCancellation, Task.isCancelled {
                throw .canceledDelay
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

    private func nextQuoteDelayNanoseconds() -> UInt64 {
        guard quoteDelayNanoseconds.count > 1 else {
            return quoteDelayNanoseconds.first ?? 0
        }
        return quoteDelayNanoseconds.removeFirst()
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

private enum StubError: Error {
    case unimplemented
}

private extension MultichainSwapAPIError {
    static let unimplemented = MultichainSwapAPIError.unknown(statusCode: -1)
    static let canceledDelay = MultichainSwapAPIError.unknown(statusCode: -2)
}
