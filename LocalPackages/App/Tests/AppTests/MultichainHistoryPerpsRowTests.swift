@testable import App
import Foundation
@testable import KeeperCore
import TKLocalize
import XCTest

@MainActor
final class MultichainHistoryPerpsRowTests: XCTestCase {
    func test_balanceMoves_sayWhichWayTheMoneyWentToPerps() {
        let mapper = makeMapper()

        XCTAssertEqual(
            mapper.makeItem(activity: perpsActivity(.perpsBalanceDeposit, inAmount: "10250000")).subtitle,
            TKLocales.MultichainHistory.Perps.toPerps
        )
        XCTAssertEqual(
            mapper.makeItem(activity: perpsActivity(.perpsBalanceWithdrawal, outAmount: "10250000")).subtitle,
            TKLocales.MultichainHistory.Perps.fromPerps
        )
        XCTAssertEqual(
            mapper.makeItem(activity: perpsActivity(.perpsPositionClosed, inAmount: "10250000", symbol: "TON")).subtitle,
            TKLocales.MultichainHistory.Perps.subtitle("TON")
        )
    }

    func test_balanceMoves_areSignedFromThePerpsAccountWhicheverLegCarriesTheAmount() {
        let mapper = makeMapper()

        for deposit in [
            perpsActivity(.perpsBalanceDeposit, inAmount: "10250000"),
            perpsActivity(.perpsBalanceDeposit, outAmount: "10250000"),
        ] {
            let amount = mapper.makeItem(activity: deposit).primaryAmount
            XCTAssertEqual(amount?.text, "+ $\u{2009}10.25")
            XCTAssertEqual(amount?.style, .positive)
            XCTAssertNil(amount?.chainTitle)
        }

        for withdrawal in [
            perpsActivity(.perpsBalanceWithdrawal, outAmount: "12400000"),
            perpsActivity(.perpsBalanceWithdrawal, inAmount: "12400000"),
        ] {
            let amount = mapper.makeItem(activity: withdrawal).primaryAmount
            XCTAssertEqual(amount?.text, "\u{2212} $\u{2009}12.4")
            XCTAssertEqual(amount?.style, .negative)
        }
    }

    func test_withdrawal_showsWhatLeftThePerpsBalanceIncludingTheLighterFee() {
        let mapper = makeMapper()
        let builder = MultichainTransactionDetailsModelBuilder(
            amountFormatter: makeAmountFormatter(),
            dateFormatter: makeDateFormatter(),
            transactionButtonProvider: { _ in nil }
        )

        let withFee = perpsActivity(.perpsBalanceWithdrawal, outAmount: "12400000", feeAmount: "3000000")
        XCTAssertEqual(mapper.makeItem(activity: withFee).primaryAmount?.text, "\u{2212} $\u{2009}15.4")
        XCTAssertEqual(builder.build(activity: withFee).amountLines.first?.amount, "\u{2212} $\u{2009}15.4")

        let otherFeeAsset = perpsActivity(.perpsBalanceWithdrawal, outAmount: "12400000", feeAmount: "3000000", feeAssetId: "arb/mainnet/coin")
        XCTAssertEqual(mapper.makeItem(activity: otherFeeAsset).primaryAmount?.text, "\u{2212} $\u{2009}12.4")

        let deposit = perpsActivity(.perpsBalanceDeposit, outAmount: "10250000", feeAmount: "3000000")
        XCTAssertEqual(mapper.makeItem(activity: deposit).primaryAmount?.text, "+ $\u{2009}10.25")
    }

    func test_openedPositionMargin_isInDollars() {
        let opened = perpsActivity(.perpsPositionOpened, symbol: "TON", marginUsd: 10.25)

        XCTAssertEqual(makeMapper().makeItem(activity: opened).primaryAmount?.text, "$\u{2009}10.25")
    }

    /// A resize used to arrive as `position_closed` and read as a close with a zero result.
    func test_resizes_areTitledAsResizesAndAnIncreaseShowsItsMargin() {
        let mapper = makeMapper()
        let increased = mapper.makeItem(activity: perpsActivity(.perpsPositionIncreased, symbol: "TON", marginUsd: 10.25))
        let reduced = mapper.makeItem(activity: perpsActivity(.perpsPositionReduced, inAmount: "10250000", symbol: "TON"))

        XCTAssertEqual(increased.title, TKLocales.MultichainHistory.Perps.increased)
        XCTAssertEqual(increased.subtitle, TKLocales.MultichainHistory.Perps.subtitle("TON"))
        XCTAssertEqual(increased.primaryAmount?.text, "$\u{2009}10.25")
        XCTAssertEqual(reduced.title, TKLocales.MultichainHistory.Perps.reduced)
        XCTAssertEqual(reduced.subtitle, TKLocales.MultichainHistory.Perps.subtitle("TON"))
    }

    func test_balanceMoveDetails_showTheSignedDollarAmountWithoutARepeatedFiatLine() {
        let builder = MultichainTransactionDetailsModelBuilder(
            amountFormatter: makeAmountFormatter(),
            dateFormatter: makeDateFormatter(),
            transactionButtonProvider: { _ in nil }
        )

        let deposit = builder.build(activity: perpsActivity(.perpsBalanceDeposit, outAmount: "10250000"))
        XCTAssertEqual(deposit.amountLines.first?.amount, "+ $\u{2009}10.25")
        XCTAssertNil(deposit.amountLines.first?.chain)
        XCTAssertNil(deposit.fiat)

        let withdrawal = builder.build(activity: perpsActivity(.perpsBalanceWithdrawal, inAmount: "12400000"))
        XCTAssertEqual(withdrawal.amountLines.first?.amount, "\u{2212} $\u{2009}12.4")
    }
}

private extension MultichainHistoryPerpsRowTests {
    func makeMapper() -> MultichainHistoryActivityItemMapper {
        MultichainHistoryActivityItemMapper(
            amountFormatter: makeAmountFormatter(),
            dateFormatter: makeDateFormatter()
        )
    }

    func makeAmountFormatter() -> AmountFormatter {
        var configuration = AmountFormatter.Configuration()
        configuration.locale = Locale(identifier: "en_US_POSIX")
        configuration.space = " "
        return AmountFormatter(configuration: configuration)
    }

    func makeDateFormatter() -> DateFormatter {
        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        dateFormatter.timeZone = TimeZone(secondsFromGMT: 0)
        return dateFormatter
    }

    func perpsActivity(
        _ activityType: MultichainActivityType,
        inAmount: String? = nil,
        outAmount: String? = nil,
        symbol: String? = nil,
        marginUsd: Double? = nil,
        feeAmount: String? = nil,
        feeAssetId: String = "arb/mainnet/erc20/usdc"
    ) -> MultichainActivity {
        let usdc = MultichainAssetDetails(
            assetId: "arb/mainnet/erc20/usdc",
            name: "USD Coin",
            symbol: "USDC",
            decimals: 6,
            image: ""
        )
        return MultichainActivity(
            activityType: activityType,
            status: .confirmed,
            blockTime: Date(timeIntervalSince1970: 1_777_440_000),
            blockNumber: nil,
            fromChain: nil,
            toChain: nil,
            walletAddress: "0xwallet",
            direction: inAmount != nil ? .incoming : .outgoing,
            fromAddress: nil,
            toAddress: nil,
            outToken: outAmount.map { _ in usdc },
            outAmount: outAmount,
            outAmountUsd: nil,
            inToken: inAmount.map { _ in usdc },
            inAmount: inAmount,
            inAmountUsd: nil,
            feeToken: feeAmount.map { _ in
                MultichainAssetDetails(assetId: feeAssetId, name: "USD Coin", symbol: "USDC", decimals: 6, image: "")
            },
            feeAmount: feeAmount,
            feeAmountUsd: nil,
            protocolName: nil,
            txIds: ["lighter:\(activityType.rawValue)"],
            isRead: nil,
            perps: MultichainActivityPerpsMeta(
                symbol: symbol,
                assetId: nil,
                side: nil,
                closeReason: nil,
                accountIndex: nil,
                settledAt: nil,
                marginUsd: marginUsd
            )
        )
    }
}
