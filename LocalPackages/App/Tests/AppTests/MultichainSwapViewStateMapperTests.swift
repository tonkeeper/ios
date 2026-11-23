@testable import App
import AppUI
import BigInt
import Foundation
@testable import KeeperCore
import TKLocalize
import TKUIKit
import XCTest

final class MultichainSwapViewStateMapperTests: XCTestCase {
    func test_shimmerMapsFocusRequestWithoutContent() {
        let state = makeMapper().map(
            state: .shimmer,
            promoTitle: nil,
            focusRequestID: 3
        )

        XCTAssertEqual(state.content, .shimmer)
        XCTAssertNil(state.promoTitle)
        XCTAssertEqual(state.focusRequestID, 3)
        XCTAssertFalse(state.isLoaded)
    }

    func test_loadedStateMapsCardsFailedQuoteDisabledContinueAndPromo() {
        let sendAsset = asset(
            assetId: "eth/mainnet/coin",
            symbol: "ETH",
            decimals: 18,
            balance: 2_500_000_000_000_000_000
        )
        let receiveAsset = asset(
            assetId: "ton/mainnet/coin",
            symbol: "TON",
            decimals: 9,
            balance: 1_000_000_000
        )
        let loadedState = MultichainSwapLoadedState(
            sendAmount: "12.5",
            sendAmountInputMode: .fiat,
            receiveAmount: "4.2",
            receiveAmountInputMode: .crypto,
            sendAmountFiatSymbol: "$",
            receiveAmountFiatSymbol: nil,
            sendAsset: sendAsset,
            receiveAsset: receiveAsset,
            slippage: nil,
            sendCardRateText: "1 ETH",
            receiveCardRateText: "$ 0.42",
            validationState: .insufficientBalance,
            quote: quoteSnapshot(state: .failed(.unavailable)),
            feeSummary: nil,
            enteredField: .send,
            isReceiveAmountEditable: false,
            showsBatteryPromo: false
        )

        let mappedState = makeMapper().map(
            state: .loaded(loadedState),
            promoTitle: TKLocales.MysteryRaffle.swapPromo,
            focusRequestID: 8
        )

        guard case let .loaded(loaded) = mappedState.content else {
            return XCTFail("Expected loaded content")
        }

        XCTAssertEqual(mappedState.promoTitle, TKLocales.MysteryRaffle.swapPromo)
        XCTAssertEqual(mappedState.focusRequestID, 8)
        XCTAssertTrue(mappedState.isLoaded)
        XCTAssertEqual(loaded.sendCard.amount, "12.5")
        XCTAssertEqual(loaded.sendCard.amountPrefix, "$")
        XCTAssertEqual(loaded.sendCard.maximumFractionDigits, 2)
        XCTAssertEqual(loaded.sendCard.token.symbol, "ETH")
        XCTAssertTrue(loaded.sendCard.exceedsBalance)
        XCTAssertFalse(loaded.receiveCard.exceedsBalance)
        XCTAssertEqual(loaded.receiveCard.amount, "4.2")
        XCTAssertEqual(loaded.receiveCard.amountState, .disabled)
        XCTAssertEqual(loaded.receiveCard.maximumFractionDigits, 9)
        XCTAssertEqual(loaded.receiveCard.token.symbol, "TON")
        XCTAssertEqual(loaded.quote.mode, .failed(TKLocales.NativeSwap.Quote.Rate.unavailable))
        XCTAssertNil(loaded.receiveCard.priceImpact)
        XCTAssertEqual(loaded.continueButton, .blocked(TKLocales.InsufficientFunds.insufficientBalance))
    }

    /// Past the warning threshold the route's value difference follows the receive card's rate, orange and
    /// then red; below it, and while no route is on screen, nothing does. Offline the last route stays with
    /// its amount, and so does its price impact.
    func test_valueDifferencePastTheThresholdShowsOnTheReceiveCard() {
        func cards(bps: Int?, quoteState: MultichainSwapQuoteState = .ready) -> MultichainSwapViewState.Loaded? {
            let state = loadedState(
                receiveAmount: "1",
                quoteState: quoteState,
                selectedRoute: route(valueDifferenceBps: bps)
            )
            let mappedState = makeMapper().map(state: .loaded(state), promoTitle: nil, focusRequestID: 0)
            guard case let .loaded(loaded) = mappedState.content else {
                XCTFail("Expected loaded content")
                return nil
            }
            return loaded
        }
        func priceImpact(bps: Int?, quoteState: MultichainSwapQuoteState = .ready) -> MultichainSwapViewState.PriceImpact? {
            cards(bps: bps, quoteState: quoteState)?.receiveCard.priceImpact
        }

        XCTAssertNil(priceImpact(bps: nil))
        XCTAssertNil(priceImpact(bps: -250))
        XCTAssertNil(priceImpact(bps: 600))
        XCTAssertEqual(priceImpact(bps: -400), MultichainSwapViewState.PriceImpact(severity: .warning, text: "(−4%)"))
        XCTAssertEqual(priceImpact(bps: -500)?.severity, .warning)
        XCTAssertEqual(priceImpact(bps: -1200), MultichainSwapViewState.PriceImpact(severity: .danger, text: "(−12%)"))
        XCTAssertEqual(priceImpact(bps: -425)?.text, "(−4.25%)")
        XCTAssertNil(cards(bps: -1200)?.sendCard.priceImpact)
        XCTAssertNil(priceImpact(bps: -1200, quoteState: .loading))
        XCTAssertNil(priceImpact(bps: -1200, quoteState: .failed(.unavailable)))
        XCTAssertEqual(priceImpact(bps: -1200, quoteState: .failed(.offline))?.severity, .danger)
    }

    /// Swap is offered once a quote is in. Until then the button asks for an amount or names the balance or
    /// the minimum in the way; anything else leaves a disabled Swap, and the row under the cards says why. A fee
    /// nothing pays leaves Swap looking blocked, though a tap on it, like one on the row, still goes through.
    func test_continueButtonNamesWhatBlocksTheSwap() {
        func continueButton(
            validationState: MultichainSwapValidationState = .routeUnavailable,
            quoteState: MultichainSwapQuoteState,
            receiveAmount: String = "",
            selectedRoute: MultichainSwapRoute? = nil,
            feeSummary: MultichainSwapFeeSummary? = nil
        ) -> MultichainSwapViewState.ContinueButton? {
            let state = loadedState(
                receiveAmount: receiveAmount,
                quoteState: quoteState,
                selectedRoute: selectedRoute,
                validationState: validationState,
                feeSummary: feeSummary
            )
            let mappedState = makeMapper().map(state: .loaded(state), promoTitle: nil, focusRequestID: 0)
            guard case let .loaded(loaded) = mappedState.content else {
                XCTFail("Expected loaded content")
                return nil
            }
            return loaded.continueButton
        }
        let enterAmount = MultichainSwapViewState.ContinueButton.blocked(TKLocales.NativeSwap.Quote.Rate.enterAmount)
        let unavailableSwap = MultichainSwapViewState.ContinueButton.blocked(TKLocales.WalletButtons.swap)

        XCTAssertEqual(continueButton(validationState: .emptyAmount, quoteState: .idle), enterAmount)
        XCTAssertEqual(continueButton(validationState: .invalidAmount, quoteState: .idle), enterAmount)
        XCTAssertEqual(
            continueButton(
                validationState: .insufficientBalance,
                quoteState: .ready,
                receiveAmount: "4.2",
                selectedRoute: route()
            ),
            .blocked(TKLocales.InsufficientFunds.insufficientBalance)
        )
        XCTAssertEqual(continueButton(validationState: .missingAddress, quoteState: .idle), unavailableSwap)
        XCTAssertEqual(continueButton(quoteState: .loading), unavailableSwap)
        XCTAssertEqual(continueButton(quoteState: .loading, receiveAmount: "4.2"), .swap(isEnabled: false))
        XCTAssertEqual(continueButton(quoteState: .failed(.unavailable)), unavailableSwap)
        XCTAssertEqual(continueButton(quoteState: .failed(.pairUnavailable)), unavailableSwap)
        XCTAssertEqual(continueButton(quoteState: .failed(.walletScreened)), unavailableSwap)
        XCTAssertEqual(continueButton(quoteState: .failed(.offline), receiveAmount: "4.2"), unavailableSwap)
        // The fee is still estimated: the swap waits for it.
        XCTAssertEqual(
            continueButton(validationState: .valid, quoteState: .ready, receiveAmount: "4.2", selectedRoute: route()),
            .swap(isEnabled: false)
        )
        XCTAssertEqual(
            continueButton(
                validationState: .valid,
                quoteState: .ready,
                receiveAmount: "4.2",
                selectedRoute: route(),
                feeSummary: .charges(7)
            ),
            .swap(isEnabled: true)
        )
        XCTAssertEqual(
            continueButton(
                validationState: .valid,
                quoteState: .ready,
                receiveAmount: "4.2",
                selectedRoute: route(),
                feeSummary: .unknown
            ),
            .swap(isEnabled: true)
        )
        for batteryShortage in [MultichainSwapFeeSummary.batteryEmpty, .lowBattery] {
            XCTAssertEqual(
                continueButton(
                    validationState: .valid,
                    quoteState: .ready,
                    receiveAmount: "4.2",
                    selectedRoute: route(),
                    feeSummary: batteryShortage
                ),
                .topUpBattery
            )
        }
        XCTAssertEqual(
            continueButton(
                validationState: .valid,
                quoteState: .ready,
                receiveAmount: "4.2",
                selectedRoute: route(),
                feeSummary: .noFunds(symbol: "GRAM")
            ),
            .feeUnpaid
        )
        XCTAssertTrue(MultichainSwapViewState.ContinueButton.feeUnpaid.isEnabled)
        XCTAssertTrue(MultichainSwapViewState.ContinueButton.topUpBattery.isEnabled)
    }

    /// The design's "Minimum 1 TON": a GRAM swap under its floor names the floor, quote or not.
    func test_gramBelowTheMinimumNamesTheMinimum() {
        let state = loadedState(
            receiveAmount: "0.92",
            quoteState: .ready,
            selectedRoute: route(),
            validationState: .belowMinimum(1_000_000_000),
            sendAsset: asset(assetId: "ton/mainnet/coin", symbol: "GRAM", decimals: 9)
        )

        let mappedState = makeMapper().map(state: .loaded(state), promoTitle: nil, focusRequestID: 0)

        guard case let .loaded(loaded) = mappedState.content else {
            return XCTFail("Expected loaded content")
        }
        XCTAssertEqual(
            loaded.continueButton,
            .blocked(TKLocales.MultichainSwap.Screen.Swap.minimumAmount("1 GRAM"))
        )
        XCTAssertFalse(loaded.sendCard.exceedsBalance)
    }

    /// The row under the cards says why there is no quote to act on; while one loads, and then while its
    /// fee is estimated, it says so instead, and before anything is entered it stays empty. Offline is left
    /// to the no internet toast, and the row keeps the fee it had. An amount above the balance hides the row:
    /// the button says what is wrong. An amount under the minimum is still priced.
    func test_quoteRowNamesWhyThereIsNoQuote() {
        func mode(
            _ quoteState: MultichainSwapQuoteState,
            feeSummary: MultichainSwapFeeSummary? = nil,
            validationState: MultichainSwapValidationState = .valid
        ) -> MultichainSwapViewState.Quote.Mode? {
            let mappedState = makeMapper().map(
                state: .loaded(
                    loadedState(
                        receiveAmount: "",
                        quoteState: quoteState,
                        validationState: validationState,
                        feeSummary: feeSummary
                    )
                ),
                promoTitle: nil,
                focusRequestID: 0
            )
            guard case let .loaded(loaded) = mappedState.content else {
                return nil
            }
            return loaded.quote.mode
        }

        XCTAssertEqual(mode(.failed(.unavailable)), .failed(TKLocales.NativeSwap.Quote.Rate.unavailable))
        XCTAssertEqual(mode(.failed(.pairUnavailable)), .failed(TKLocales.NativeSwap.Quote.Rate.pairUnavailable))
        XCTAssertEqual(mode(.failed(.walletScreened)), .failed(TKLocales.MultichainSwap.ProviderError.walletScreened))
        XCTAssertEqual(mode(.failed(.offline)), .hidden)
        XCTAssertEqual(mode(.failed(.offline), feeSummary: .unknown), .hidden)
        XCTAssertEqual(mode(.failed(.offline), feeSummary: .charges(7)), .fee(.init(text: chargesText(7), icon: .battery)))
        XCTAssertEqual(mode(.loading), .loading)
        XCTAssertEqual(mode(.ready), .estimatingFee)
        XCTAssertEqual(mode(.idle), .hidden)
        XCTAssertEqual(mode(.ready, validationState: .insufficientBalance), .hidden)
        XCTAssertEqual(
            mode(.ready, feeSummary: .charges(7), validationState: .insufficientBalance),
            .hidden
        )
        XCTAssertEqual(mode(.ready, feeSummary: .unknown, validationState: .insufficientBalance), .hidden)
        XCTAssertEqual(mode(.ready, validationState: .belowMinimum(1_000_000_000)), .estimatingFee)
        XCTAssertEqual(
            mode(.ready, feeSummary: .charges(7), validationState: .belowMinimum(1_000_000_000)),
            .fee(.init(text: chargesText(7), icon: .battery))
        )
        XCTAssertEqual(mode(.ready, feeSummary: .charges(7), validationState: .missingAddress), .hidden)
    }

    /// The row names what pays the fee: charges with the battery, a coin or a token by its amount, what is
    /// missing in red when nothing can pay. An unknown fee has no row.
    func test_feeRowNamesWhatPaysTheFee() {
        func fee(_ summary: MultichainSwapFeeSummary) -> MultichainSwapViewState.Quote.Mode? {
            let mappedState = makeMapper().map(
                state: .loaded(loadedState(receiveAmount: "1", quoteState: .ready, feeSummary: summary)),
                promoTitle: nil,
                focusRequestID: 0
            )
            guard case let .loaded(loaded) = mappedState.content else {
                return nil
            }
            return loaded.quote.mode
        }
        typealias Strings = TKLocales.MultichainSwap.Screen.Swap.NetworkFee
        let gram = MultichainAssetDetails.gram
        let bnb = MultichainAssetDetails(assetId: "bsc/mainnet/coin", name: "BNB", symbol: "BNB", decimals: 18, image: "")

        XCTAssertEqual(fee(.charges(7)), .fee(.init(text: chargesText(7), icon: .battery)))
        XCTAssertEqual(fee(.amounts([.init(amount: 300_000_000, asset: gram)])), .fee(.init(text: Strings.amount("0.3 GRAM"))))
        XCTAssertEqual(
            fee(.amounts([.init(amount: 300_000_000, asset: gram), .init(amount: 1_000_000_000_000_000, asset: bnb)])),
            .fee(.init(text: Strings.amount("0.3 GRAM + 0.001 BNB")))
        )
        XCTAssertEqual(fee(.batteryEmpty), .fee(.init(text: Strings.notEnoughCharges, icon: .battery, isShortage: true)))
        XCTAssertEqual(fee(.lowBattery), .fee(.init(text: Strings.notEnoughCharges, icon: .battery, isShortage: true)))
        XCTAssertEqual(fee(.noFunds(symbol: "BNB")), .fee(.init(text: Strings.noFunds("BNB"), icon: .exclamationMark, isShortage: true)))
        XCTAssertEqual(fee(.unknown), .hidden)
    }

    /// The battery promo takes the empty row only; once something is entered the row is the quote's.
    func test_batteryPromoTakesTheEmptyRow() {
        func mode(_ quoteState: MultichainSwapQuoteState) -> MultichainSwapViewState.Quote.Mode? {
            let mappedState = makeMapper().map(
                state: .loaded(
                    loadedState(receiveAmount: "", quoteState: quoteState, feeSummary: .charges(7), showsBatteryPromo: true)
                ),
                promoTitle: nil,
                focusRequestID: 0
            )
            guard case let .loaded(loaded) = mappedState.content else {
                return nil
            }
            return loaded.quote.mode
        }

        XCTAssertEqual(mode(.idle), .batteryPromo(TKLocales.MultichainSwap.Screen.Swap.NetworkFee.batteryPromo))
        XCTAssertEqual(mode(.loading), .loading)
        XCTAssertEqual(mode(.ready), .fee(.init(text: chargesText(7), icon: .battery)))
    }

    /// A send that failed says why in place of the presets and the button, rather than inviting a retry
    /// that fails the same way.
    func test_sendFailureNamesItsReason() {
        func title(_ sendFailure: MultichainSwapSendFailure) -> String? {
            makeMapper().map(
                state: .loaded(loadedState(receiveAmount: "", quoteState: .ready)),
                promoTitle: nil,
                focusRequestID: 0,
                sendFailure: sendFailure
            ).sendFailure
        }

        XCTAssertEqual(title(.retryable("Insufficient balance")), "Insufficient balance")
        XCTAssertEqual(title(.retryable("")), TKLocales.MultichainSwap.Screen.Swap.sendFailed)
        XCTAssertEqual(title(.outcomeUnknown), TKLocales.MultichainSwap.Screen.Confirm.Error.statusUnknown)
    }

    func test_failedQuoteWithoutReceiveAmountShowsNoQuoteText() {
        let mappedState = makeMapper().map(
            state: .loaded(loadedState(receiveAmount: "", quoteState: .failed(.unavailable))),
            promoTitle: nil,
            focusRequestID: 0
        )

        guard case let .loaded(loaded) = mappedState.content else {
            return XCTFail("Expected loaded content")
        }
        XCTAssertEqual(loaded.receiveCard.quoteUnavailableText, TKLocales.NativeSwap.Quote.noQuote)
        XCTAssertFalse(loaded.receiveCard.showsQuoteShimmer)
    }

    func test_offlineQuoteNeverReadsAsNoQuote() {
        func receiveCard(receiveAmount: String) -> MultichainSwapViewState.AmountCard? {
            let mappedState = makeMapper().map(
                state: .loaded(loadedState(receiveAmount: receiveAmount, quoteState: .failed(.offline))),
                promoTitle: nil,
                focusRequestID: 0
            )
            guard case let .loaded(loaded) = mappedState.content else {
                XCTFail("Expected loaded content")
                return nil
            }
            return loaded.receiveCard
        }

        XCTAssertNil(receiveCard(receiveAmount: "")?.quoteUnavailableText)
        XCTAssertNil(receiveCard(receiveAmount: "4.2")?.quoteUnavailableText)
        XCTAssertEqual(receiveCard(receiveAmount: "4.2")?.amount, "4.2")
    }

    func test_failedQuoteKeepsCarriedReceiveAmountVisible() {
        let mappedState = makeMapper().map(
            state: .loaded(loadedState(receiveAmount: "4.2", quoteState: .failed(.unavailable))),
            promoTitle: nil,
            focusRequestID: 0
        )

        guard case let .loaded(loaded) = mappedState.content else {
            return XCTFail("Expected loaded content")
        }
        XCTAssertNil(loaded.receiveCard.quoteUnavailableText)
    }

    func test_loadingQuoteWithoutReceiveAmountShowsShimmerInsteadOfNoQuoteText() {
        let mappedState = makeMapper().map(
            state: .loaded(loadedState(receiveAmount: "", quoteState: .loading)),
            promoTitle: nil,
            focusRequestID: 0
        )

        guard case let .loaded(loaded) = mappedState.content else {
            return XCTFail("Expected loaded content")
        }
        XCTAssertTrue(loaded.receiveCard.showsQuoteShimmer)
        XCTAssertNil(loaded.receiveCard.quoteUnavailableText)
    }

    /// The amount to receive, once typed, is what the receive card keeps and the focus returns to,
    /// while the send card waits for the quote.
    func test_enteredReceiveAmountQuotesIntoTheSendCard() {
        let mappedState = makeMapper().map(
            state: .loaded(
                loadedState(
                    receiveAmount: "2",
                    quoteState: .loading,
                    enteredField: .receive,
                    isReceiveAmountEditable: true
                )
            ),
            promoTitle: nil,
            focusRequestID: 0
        )

        guard case let .loaded(loaded) = mappedState.content else {
            return XCTFail("Expected loaded content")
        }
        XCTAssertEqual(loaded.sendCard.amountState, .loading)
        XCTAssertEqual(loaded.receiveCard.amountState, .editable)
        XCTAssertFalse(loaded.receiveCard.showsQuoteShimmer)
        XCTAssertEqual(mappedState.focusField, .receive)
    }

    /// Once the amount to receive is the entered one, the send card is where the quote shows: a
    /// shimmer while it loads, and "No quote" as the placeholder of a field that still takes typing.
    func test_enteredReceiveAmountQuoteStatesShowInTheSendCard() {
        func sendCard(quoteState: MultichainSwapQuoteState) -> MultichainSwapViewState.AmountCard? {
            let state = loadedState(
                sendAmount: "",
                receiveAmount: "2",
                quoteState: quoteState,
                enteredField: .receive,
                isReceiveAmountEditable: true
            )
            let mappedState = makeMapper().map(state: .loaded(state), promoTitle: nil, focusRequestID: 0)
            guard case let .loaded(loaded) = mappedState.content else {
                XCTFail("Expected loaded content")
                return nil
            }
            return loaded.sendCard
        }

        XCTAssertEqual(sendCard(quoteState: .loading)?.showsQuoteShimmer, true)
        XCTAssertNil(sendCard(quoteState: .loading)?.quoteUnavailableText)
        XCTAssertEqual(sendCard(quoteState: .failed(.unavailable))?.quoteUnavailableText, TKLocales.NativeSwap.Quote.noQuote)
        XCTAssertEqual(sendCard(quoteState: .failed(.unavailable))?.amountState, .editable)
    }

    /// A receive card that takes no typing, as in fiat, leaves the focus on the send card even when its
    /// amount is the entered one.
    func test_enteredReceiveAmountInAReadOnlyCardFocusesTheSendCard() {
        let mappedState = makeMapper().map(
            state: .loaded(
                loadedState(
                    receiveAmount: "2",
                    quoteState: .ready,
                    enteredField: .receive,
                    isReceiveAmountEditable: false
                )
            ),
            promoTitle: nil,
            focusRequestID: 0
        )

        guard case let .loaded(loaded) = mappedState.content else {
            return XCTFail("Expected loaded content")
        }
        XCTAssertEqual(loaded.receiveCard.amountState, .disabled)
        XCTAssertEqual(mappedState.focusField, .send)
    }

    func test_editableReceiveCardKeepsTakingInputWhenItsQuoteFails() {
        let mappedState = makeMapper().map(
            state: .loaded(
                loadedState(
                    receiveAmount: "",
                    quoteState: .failed(.unavailable),
                    isReceiveAmountEditable: true
                )
            ),
            promoTitle: nil,
            focusRequestID: 0
        )

        guard case let .loaded(loaded) = mappedState.content else {
            return XCTFail("Expected loaded content")
        }
        XCTAssertEqual(loaded.receiveCard.amountState, .editable)
        XCTAssertEqual(loaded.receiveCard.quoteUnavailableText, TKLocales.NativeSwap.Quote.noQuote)
        XCTAssertEqual(mappedState.focusField, .send)
    }

    func test_expiredReadyRouteDisablesContinue() {
        let expiredRoute = MultichainSwapRoute(
            routeId: "route",
            aggregator: "test",
            protocolSlug: "test",
            routeType: "swap",
            sourceAmount: "1000000000000000000",
            estimatedDestinationAmount: "1000000000",
            minimumDestinationAmount: "1000000000",
            sourceUsdPrice: nil,
            destinationUsdPrice: nil,
            legs: [],
            dateExpire: Date().addingTimeInterval(-1),
            riskLevel: "low"
        )
        let snapshot = quoteSnapshot(state: .ready, selectedRoute: expiredRoute)
        let loadedState = MultichainSwapLoadedState(
            sendAmount: "1",
            sendAmountInputMode: .crypto,
            receiveAmount: "1",
            receiveAmountInputMode: .crypto,
            sendAmountFiatSymbol: nil,
            receiveAmountFiatSymbol: nil,
            sendAsset: asset(assetId: "eth/mainnet/coin", symbol: "ETH", decimals: 18),
            receiveAsset: asset(assetId: "ton/mainnet/coin", symbol: "TON", decimals: 9),
            slippage: nil,
            sendCardRateText: nil,
            receiveCardRateText: nil,
            validationState: .valid,
            quote: snapshot,
            feeSummary: .charges(7),
            enteredField: .send,
            isReceiveAmountEditable: false,
            showsBatteryPromo: false
        )

        let mappedState = makeMapper().map(
            state: .loaded(loadedState),
            promoTitle: nil,
            focusRequestID: 0
        )

        guard case let .loaded(loaded) = mappedState.content else {
            return XCTFail("Expected loaded content")
        }
        XCTAssertEqual(loaded.quote.mode, .fee(.init(text: chargesText(7), icon: .battery)))
        XCTAssertEqual(loaded.continueButton, .swap(isEnabled: false))
    }
}

private extension MultichainSwapViewStateMapperTests {
    func chargesText(_ count: Int) -> String {
        TKLocales.MultichainSwap.Screen.Swap.NetworkFee.charges("\(count) \(TKLocales.Battery.Refill.chargesCount(count: count))")
    }

    func makeMapper() -> MultichainSwapViewStateMapper {
        var configuration = AmountFormatter.Configuration()
        configuration.locale = Locale(identifier: "en_US_POSIX")
        configuration.space = " "
        return MultichainSwapViewStateMapper(
            amountFormatter: AmountFormatter(configuration: configuration)
        )
    }

    func asset(
        assetId: String,
        symbol: String,
        decimals: Int,
        balance: BigUInt = .zero
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
                prices: [:],
                diff24h: [:],
                diff7d: [:]
            ),
            balance: balance
        )
    }

    func loadedState(
        sendAmount: String = "1",
        receiveAmount: String,
        quoteState: MultichainSwapQuoteState,
        selectedRoute: MultichainSwapRoute? = nil,
        validationState: MultichainSwapValidationState = .valid,
        sendAsset: MultichainAsset? = nil,
        enteredField: MultichainSwapAmountField = .send,
        isReceiveAmountEditable: Bool = false,
        feeSummary: MultichainSwapFeeSummary? = nil,
        showsBatteryPromo: Bool = false
    ) -> MultichainSwapLoadedState {
        MultichainSwapLoadedState(
            sendAmount: sendAmount,
            sendAmountInputMode: .crypto,
            receiveAmount: receiveAmount,
            receiveAmountInputMode: .crypto,
            sendAmountFiatSymbol: nil,
            receiveAmountFiatSymbol: nil,
            sendAsset: sendAsset ?? asset(assetId: "eth/mainnet/coin", symbol: "ETH", decimals: 18),
            receiveAsset: asset(assetId: "ton/mainnet/coin", symbol: "TON", decimals: 9),
            slippage: nil,
            sendCardRateText: nil,
            receiveCardRateText: nil,
            validationState: validationState,
            quote: quoteSnapshot(state: quoteState, selectedRoute: selectedRoute),
            feeSummary: feeSummary,
            enteredField: enteredField,
            isReceiveAmountEditable: isReceiveAmountEditable,
            showsBatteryPromo: showsBatteryPromo
        )
    }

    func route(valueDifferenceBps: Int? = nil) -> MultichainSwapRoute {
        MultichainSwapRoute(
            routeId: "route",
            aggregator: "test",
            protocolSlug: "test",
            routeType: "swap",
            sourceAmount: "1000000000000000000",
            estimatedDestinationAmount: "1000000000",
            minimumDestinationAmount: "1000000000",
            valueDifferenceBps: valueDifferenceBps,
            legs: [],
            dateExpire: Date().addingTimeInterval(60),
            riskLevel: "low"
        )
    }

    func quoteSnapshot(
        state: MultichainSwapQuoteState,
        selectedRoute: MultichainSwapRoute? = nil
    ) -> MultichainSwapQuoteSnapshot {
        MultichainSwapQuoteSnapshot(
            progressStartDate: nil,
            quoteState: state,
            selectedQuote: nil,
            selectedRoute: selectedRoute,
            lastKnownSourceUsdPrice: nil,
            lastKnownDestinationUsdPrice: nil
        )
    }
}
