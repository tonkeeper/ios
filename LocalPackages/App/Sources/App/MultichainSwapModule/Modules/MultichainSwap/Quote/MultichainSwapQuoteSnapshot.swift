import BigInt
import Foundation
import KeeperCore
import TKLocalize

enum MultichainSwapQuoteText {
    case regular(String)
    case rate(_ inverted: Bool, value: (Bool) -> String)

    var stringValue: String {
        switch self {
        case let .regular(string):
            string
        case let .rate(inverted, value):
            value(inverted)
        }
    }
}

struct MultichainSwapQuoteSnapshot {
    let rateText: MultichainSwapQuoteText
    let lastReadyRateText: MultichainSwapQuoteText?
    let progressRestartToken: Int
    let quoteState: MultichainSwapQuoteState
    let selectedQuote: MultichainSwapQuote?
    let selectedRoute: MultichainSwapRoute?
    /// USD prices of the most recent ready route, carried across refresh
    /// transitions (loading/failed/expired drop the route) so fiat display does
    /// not blink out while a new quote loads. Reset with the pair (`initial`).
    let lastKnownSourceUsdPrice: Double?
    let lastKnownDestinationUsdPrice: Double?

    var sourceUsdPrice: Double? {
        selectedRoute?.sourceUsdPrice ?? lastKnownSourceUsdPrice
    }

    var destinationUsdPrice: Double? {
        selectedRoute?.destinationUsdPrice ?? lastKnownDestinationUsdPrice
    }

    static func initial(
        progressRestartToken: Int = 0
    ) -> MultichainSwapQuoteSnapshot {
        MultichainSwapQuoteSnapshot(
            rateText: .regular(
                TKLocales.NativeSwap.Quote.Rate.enterAmount
            ),
            lastReadyRateText: nil,
            progressRestartToken: progressRestartToken,
            quoteState: .idle,
            selectedQuote: nil,
            selectedRoute: nil,
            lastKnownSourceUsdPrice: nil,
            lastKnownDestinationUsdPrice: nil
        )
    }
}

final class MultichainSwapQuoteSnapshotMaker {
    private let amountFormatter: AmountFormatter
    private var progressRestartToken: Int = 0

    init(amountFormatter: AmountFormatter) {
        self.amountFormatter = amountFormatter
    }
}

extension MultichainSwapQuoteSnapshotMaker {
    func initial() -> MultichainSwapQuoteSnapshot {
        .initial(progressRestartToken: progressRestartToken)
    }

    func updating(
        lastReadyRateText: MultichainSwapQuoteText?,
        previous: MultichainSwapQuoteSnapshot
    ) -> MultichainSwapQuoteSnapshot {
        MultichainSwapQuoteSnapshot(
            rateText: .regular(
                TKLocales.NativeSwap.Quote.Rate.updating
            ),
            lastReadyRateText: lastReadyRateText,
            progressRestartToken: progressRestartToken,
            quoteState: .loading,
            selectedQuote: nil,
            selectedRoute: nil,
            lastKnownSourceUsdPrice: previous.sourceUsdPrice,
            lastKnownDestinationUsdPrice: previous.destinationUsdPrice
        )
    }

    func failed(previous: MultichainSwapQuoteSnapshot) -> MultichainSwapQuoteSnapshot {
        failed(
            previous: previous,
            rateText: TKLocales.NativeSwap.Quote.Rate.unavailable
        )
    }

    func pairUnavailable(previous: MultichainSwapQuoteSnapshot) -> MultichainSwapQuoteSnapshot {
        failed(
            previous: previous,
            rateText: TKLocales.NativeSwap.Quote.Rate.pairUnavailable
        )
    }

    private func failed(
        previous: MultichainSwapQuoteSnapshot,
        rateText: String
    ) -> MultichainSwapQuoteSnapshot {
        MultichainSwapQuoteSnapshot(
            rateText: .regular(rateText),
            lastReadyRateText: nil,
            progressRestartToken: progressRestartToken,
            quoteState: .failed,
            selectedQuote: nil,
            selectedRoute: nil,
            lastKnownSourceUsdPrice: previous.sourceUsdPrice,
            lastKnownDestinationUsdPrice: previous.destinationUsdPrice
        )
    }

    func inverted(_ source: MultichainSwapQuoteSnapshot) -> MultichainSwapQuoteSnapshot {
        switch source.rateText {
        case .regular:
            source
        case let .rate(inverted, value):
            MultichainSwapQuoteSnapshot(
                rateText: .rate(!inverted, value: value),
                lastReadyRateText: source.lastReadyRateText,
                progressRestartToken: source.progressRestartToken,
                quoteState: source.quoteState,
                selectedQuote: source.selectedQuote,
                selectedRoute: source.selectedRoute,
                lastKnownSourceUsdPrice: source.lastKnownSourceUsdPrice,
                lastKnownDestinationUsdPrice: source.lastKnownDestinationUsdPrice
            )
        }
    }

    func ready(
        sourceAmount: BigUInt,
        quote: MultichainSwapQuote,
        route: MultichainSwapRoute,
        sourceSymbol: String,
        destinationSymbol: String,
        sourceDecimals: Int,
        destinationDecimals: Int,
        inverted: Bool
    ) -> MultichainSwapQuoteSnapshot {
        progressRestartToken += 1
        return MultichainSwapQuoteSnapshot(
            rateText: rateText(
                sourceAmount: sourceAmount,
                route: route,
                sourceSymbol: sourceSymbol,
                destinationSymbol: destinationSymbol,
                sourceDecimals: sourceDecimals,
                destinationDecimals: destinationDecimals,
                inverted: inverted
            ),
            lastReadyRateText: nil,
            progressRestartToken: progressRestartToken,
            quoteState: .ready,
            selectedQuote: quote,
            selectedRoute: route,
            lastKnownSourceUsdPrice: route.sourceUsdPrice,
            lastKnownDestinationUsdPrice: route.destinationUsdPrice
        )
    }
}

private extension MultichainSwapQuoteSnapshotMaker {
    func rateText(
        sourceAmount: BigUInt,
        route: MultichainSwapRoute,
        sourceSymbol: String,
        destinationSymbol: String,
        sourceDecimals: Int,
        destinationDecimals: Int,
        inverted: Bool
    ) -> MultichainSwapQuoteText {
        let sourceUnits = route.sourceAmount.flatMap {
            BigUInt($0)
        } ?? sourceAmount
        let destinationUnits = BigUInt(
            route.estimatedDestinationAmount
        ) ?? 0
        guard
            let sourceDecimal = decimalAmount(
                sourceUnits,
                decimals: sourceDecimals
            ),
            let destinationDecimal = decimalAmount(
                destinationUnits,
                decimals: destinationDecimals
            ),
            sourceDecimal > 0,
            destinationDecimal > 0
        else {
            return .rate(inverted) { inverted in
                if inverted {
                    "\(destinationSymbol) / \(sourceSymbol)"
                } else {
                    "\(sourceSymbol) / \(destinationSymbol)"
                }
            }
        }
        return .rate(inverted) { [self] inverted in
            if inverted {
                "1 \(destinationSymbol) ≈ \(formatDecimal(sourceDecimal / destinationDecimal)) \(sourceSymbol)"
            } else {
                "1 \(sourceSymbol) ≈ \(formatDecimal(destinationDecimal / sourceDecimal)) \(destinationSymbol)"
            }
        }
    }

    func decimalAmount(_ amount: BigUInt, decimals: Int) -> Decimal? {
        guard
            let integer = Decimal(string: amount.description)
        else {
            return nil
        }
        let divisor = Decimal(
            sign: .plus,
            exponent: decimals,
            significand: 1
        )
        return integer / divisor
    }

    func formatDecimal(_ decimal: Decimal) -> String {
        amountFormatter.format(decimal: decimal, style: .regular)
    }
}
