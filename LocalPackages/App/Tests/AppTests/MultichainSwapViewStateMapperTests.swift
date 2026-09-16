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
            quote: quoteSnapshot(state: .failed)
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
        XCTAssertEqual(loaded.sendCard.insufficientBalanceText, TKLocales.InsufficientFunds.insufficientBalance)
        XCTAssertEqual(loaded.receiveCard.amount, "4.2")
        XCTAssertEqual(loaded.receiveCard.amountState, .disabled)
        XCTAssertEqual(loaded.receiveCard.maximumFractionDigits, 9)
        XCTAssertEqual(loaded.receiveCard.token.symbol, "TON")
        XCTAssertEqual(loaded.quote.mode, .failed)
        XCTAssertEqual(loaded.quote.rateText, "Quote unavailable")
        XCTAssertEqual(loaded.quote.progressRestartToken, 7)
        XCTAssertEqual(loaded.quote.refreshDuration, 30)
        XCTAssertFalse(loaded.canContinue)
    }

    func test_failedQuoteWithoutReceiveAmountShowsNoQuoteText() {
        let mappedState = makeMapper().map(
            state: .loaded(loadedState(receiveAmount: "", quoteState: .failed)),
            promoTitle: nil,
            focusRequestID: 0
        )

        guard case let .loaded(loaded) = mappedState.content else {
            return XCTFail("Expected loaded content")
        }
        XCTAssertEqual(loaded.receiveCard.quoteUnavailableText, TKLocales.NativeSwap.Quote.noQuote)
        XCTAssertFalse(loaded.receiveCard.showsQuoteShimmer)
    }

    func test_failedQuoteKeepsCarriedReceiveAmountVisible() {
        let mappedState = makeMapper().map(
            state: .loaded(loadedState(receiveAmount: "4.2", quoteState: .failed)),
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
            quote: snapshot
        )

        let mappedState = makeMapper().map(
            state: .loaded(loadedState),
            promoTitle: nil,
            focusRequestID: 0
        )

        guard case let .loaded(loaded) = mappedState.content else {
            return XCTFail("Expected loaded content")
        }
        XCTAssertEqual(loaded.quote.mode, .ready)
        XCTAssertFalse(loaded.canContinue)
    }
}

private extension MultichainSwapViewStateMapperTests {
    func makeMapper() -> MultichainSwapViewStateMapper {
        var configuration = AmountFormatter.Configuration()
        configuration.locale = Locale(identifier: "en_US_POSIX")
        configuration.space = " "
        return MultichainSwapViewStateMapper(
            amountFormatter: AmountFormatter(configuration: configuration),
            quoteRefreshDuration: 30
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
                diff7d: [:],
                diff30d: [:]
            ),
            balance: balance
        )
    }

    func loadedState(
        receiveAmount: String,
        quoteState: MultichainSwapQuoteState
    ) -> MultichainSwapLoadedState {
        MultichainSwapLoadedState(
            sendAmount: "1",
            sendAmountInputMode: .crypto,
            receiveAmount: receiveAmount,
            receiveAmountInputMode: .crypto,
            sendAmountFiatSymbol: nil,
            receiveAmountFiatSymbol: nil,
            sendAsset: asset(assetId: "eth/mainnet/coin", symbol: "ETH", decimals: 18),
            receiveAsset: asset(assetId: "ton/mainnet/coin", symbol: "TON", decimals: 9),
            slippage: nil,
            sendCardRateText: nil,
            receiveCardRateText: nil,
            validationState: .valid,
            quote: quoteSnapshot(state: quoteState)
        )
    }

    func quoteSnapshot(
        state: MultichainSwapQuoteState,
        selectedRoute: MultichainSwapRoute? = nil
    ) -> MultichainSwapQuoteSnapshot {
        MultichainSwapQuoteSnapshot(
            rateText: .regular("Quote unavailable"),
            lastReadyRateText: nil,
            progressRestartToken: 7,
            quoteState: state,
            selectedQuote: nil,
            selectedRoute: selectedRoute,
            lastKnownSourceUsdPrice: nil,
            lastKnownDestinationUsdPrice: nil
        )
    }
}
