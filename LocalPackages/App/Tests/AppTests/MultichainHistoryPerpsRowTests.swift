@testable import App
import AppUI
import Foundation
@testable import KeeperCore
import TKLocalize
import TKUIKit
import XCTest

@MainActor
final class MultichainHistoryPerpsRowTests: XCTestCase {
    func test_balanceMoves_describeTheCompletedOperationAndPerpsBalance() {
        let mapper = makeMapper()
        let deposit = mapper.makeItem(activity: perpsActivity(.perpsBalanceDeposit, inAmount: "10250000"))
        let withdrawal = mapper.makeItem(activity: perpsActivity(.perpsBalanceWithdrawal, outAmount: "10250000"))

        XCTAssertEqual(deposit.title, TKLocales.MultichainHistory.Perps.deposit)
        XCTAssertEqual(deposit.subtitle, TKLocales.MultichainHistory.Perps.toPerps)
        XCTAssertEqual(withdrawal.title, TKLocales.MultichainHistory.Perps.withdrawal)
        XCTAssertEqual(withdrawal.subtitle, TKLocales.MultichainHistory.Perps.fromPerps)
        XCTAssertEqual(
            mapper.makeItem(activity: perpsActivity(.perpsBalanceDeposit, status: .pending)).title,
            TKLocales.MultichainHistory.Perps.deposit
        )
        XCTAssertEqual(
            mapper.makeItem(activity: perpsActivity(.perpsBalanceWithdrawal, status: .pending)).title,
            TKLocales.MultichainHistory.Perps.withdrawal
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

    func test_withdrawal_showsWhatLeftThePerpsBalance_whichAlreadyHoldsTheFee() {
        let mapper = makeMapper()
        let builder = makeDetailsBuilder()

        for feeAssetId in ["arb/mainnet/erc20/usdc", "arb/mainnet/coin"] {
            let withFee = perpsActivity(.perpsBalanceWithdrawal, outAmount: "12400000", feeAmount: "3000000", feeAssetId: feeAssetId)
            XCTAssertEqual(mapper.makeItem(activity: withFee).primaryAmount?.text, "\u{2212} $\u{2009}12.4")
            XCTAssertEqual(builder.build(activity: withFee).amountLines.first?.amount, "\u{2212} 12.40 USDC")
        }

        let deposit = perpsActivity(.perpsBalanceDeposit, outAmount: "10250000", feeAmount: "3000000")
        XCTAssertEqual(mapper.makeItem(activity: deposit).primaryAmount?.text, "+ $\u{2009}10.25")
    }

    func test_withdrawalPaidOutInUsdc_showsWhatArrivedUnderWhatLeftThePerpsBalance() {
        let perpsUsdc = MultichainAssetDetails(assetId: "lighter/mainnet/3", name: "USDC", symbol: "USDC", decimals: 6, image: "https://usdc.png")
        let arbitrumUsdc = MultichainAssetDetails(
            assetId: "arb/mainnet/erc20/0xaf88d065e77c8cc2239327c5edb3a432268e5831",
            name: "USD Coin",
            symbol: "USDC",
            decimals: 6,
            image: "https://usdc.png"
        )
        let event = perpsActivity(
            .perpsBalanceWithdrawal,
            inAmount: "976253",
            outAmount: "1000000",
            incomingToken: arbitrumUsdc,
            outgoingToken: perpsUsdc,
            inAmountUsd: 0.976166606547525,
            feeAmount: "23741",
            feeAssetId: "lighter/mainnet/3"
        )
        XCTAssertEqual(makeMapper().makeItem(activity: event).primaryAmount?.text, "\u{2212} $\u{2009}1")
        for hidden in [false, true] {
            let model = makeDetailsBuilder(hidden: hidden).build(activity: event)
            XCTAssertEqual(
                model.amountLines.map(\.amount),
                hidden ? [.secureModeValueShort, .secureModeValueShort] : ["\u{2212} 1.00 USDC", "+ 0.976 USDC"]
            )
            XCTAssertEqual(model.amountLines.map(\.chain), [nil, MultichainChain.arb.addressConfiguration.title])
            XCTAssertEqual(model.fiat, hidden ? .secureModeValueShort : "+ $\u{2009}0.97")
            guard case .swap = model.image else { return XCTFail("a payout pairs the Perps USDC with the received USDC") }
        }

        let toThePerpsAsset = perpsActivity(
            .perpsBalanceWithdrawal,
            inAmount: "976253",
            outAmount: "1000000",
            incomingToken: perpsUsdc,
            outgoingToken: perpsUsdc
        )
        XCTAssertEqual(makeDetailsBuilder().build(activity: toThePerpsAsset).amountLines.map(\.amount), ["\u{2212} 1.00 USDC"])

        let depositFromUsdc = perpsActivity(
            .perpsBalanceDeposit,
            inAmount: "976253",
            outAmount: "1000000",
            incomingToken: perpsUsdc,
            outgoingToken: arbitrumUsdc
        )
        XCTAssertEqual(makeDetailsBuilder().build(activity: depositFromUsdc).amountLines.map(\.amount), ["+ 0.976 USDC"])
    }

    func test_hiddenBalances_maskTheAmountAndDropItsColour() {
        let mapper = MultichainHistoryActivityItemMapper(
            amountFormatter: makeAmountFormatter(),
            dateFormatter: makeDateFormatter(),
            hidesAmounts: { true }
        )

        for activity in [
            perpsActivity(.perpsBalanceDeposit, inAmount: "10250000"),
            perpsActivity(.perpsPositionClosed, inAmount: "10250000", symbol: "TON"),
        ] {
            let item = mapper.makeItem(activity: activity)
            XCTAssertEqual(item.primaryAmount?.text, .secureModeValueShort)
            XCTAssertEqual(item.primaryAmount?.style, .primary)
            XCTAssertEqual(item.title, makeMapper().makeItem(activity: activity).title)
        }
    }

    func test_aDepositTheProviderFailed_readsFailedInOrangeUnderAGreyAmount() {
        let item = makeMapper().makeItem(activity: perpsActivity(.perpsBalanceDeposit, inAmount: "10250000", status: .failed))

        XCTAssertEqual(item.subtitle, TKLocales.MultichainHistory.Perps.toPerps)
        XCTAssertEqual(item.detailsTitle, TransactionCellContent.DetailsTitle(text: TKLocales.State.failed, color: .accentOrange))
        XCTAssertEqual(item.transactionAmount?.style, .secondary)
    }

    func test_balanceMoveAmountColour_followsItsStatus() {
        let mapper = makeMapper()
        let cases: [(MultichainActivityType, MultichainActivityStatus, TransactionCellContent.AmountStyle)] = [
            (.perpsBalanceDeposit, .pending, .secondary),
            (.perpsBalanceDeposit, .confirmed, .positive),
            (.perpsBalanceDeposit, .dropped, .secondary),
            (.perpsBalanceWithdrawal, .pending, .primary),
            (.perpsBalanceWithdrawal, .confirmed, .primary),
            (.perpsBalanceWithdrawal, .failed, .secondary),
        ]
        for (type, status, style) in cases {
            let item = mapper.makeItem(activity: perpsActivity(type, inAmount: "10250000", outAmount: "10250000", status: status))
            XCTAssertEqual(item.transactionAmount?.style, style, "\(type) \(status)")
        }
        let failedClose = mapper.makeItem(activity: perpsActivity(.perpsPositionClosed, inAmount: "10250000", symbol: "TON", status: .failed))
        XCTAssertEqual(failedClose.transactionAmount?.style, .warning)
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

    func test_balanceMoveDetails_showTheUsdcLegWithItsDollarValue() {
        let deposit = makeDetailsBuilder().build(activity: perpsActivity(.perpsBalanceDeposit, outAmount: "10249995"))
        XCTAssertEqual(deposit.amountLines.map(\.amount), ["+ 10.24 USDC"])
        XCTAssertNil(deposit.amountLines.first?.chain)
        XCTAssertEqual(deposit.fiat, "+ $\u{2009}10.24")

        let withdrawal = makeDetailsBuilder().build(activity: perpsActivity(.perpsBalanceWithdrawal, inAmount: "12400000"))
        XCTAssertEqual(withdrawal.amountLines.map(\.amount), ["\u{2212} 12.40 USDC"])
        XCTAssertEqual(withdrawal.fiat, "\u{2212} $\u{2009}12.40")
    }

    func test_fundingDetails_showTheWalletDirectionProtocolAndHash() {
        for type in [MultichainActivityType.perpsBalanceDeposit, .perpsBalanceWithdrawal] {
            let model = makeDetailsBuilder(walletName: "Main")
                .build(activity: perpsActivity(type, outAmount: "10250000", protocolName: "lighter"))
            let rows = model.rows.compactMap { row -> String? in
                switch row {
                case let .property(title, value): "\(title): \(value)"
                case let .inlineHash(title, hash): "\(title): \(hash)"
                default: nil
                }
            }
            let direction = type == .perpsBalanceDeposit
                ? TKLocales.MultichainHistory.Perps.depositedTo
                : TKLocales.MultichainHistory.Perps.withdrawnFrom
            XCTAssertEqual(rows, [
                "\(TKLocales.ConfirmSend.wallet): Main",
                "\(direction): \(TKLocales.Perps.balance)",
                "\(TKLocales.EventDetails.protocol): Lighter",
                "\(TKLocales.MultichainHistory.Perps.transactionHash): \(type.rawValue)",
            ])
            XCTAssertTrue(model.tags.isEmpty)
            guard case let .single(asset) = model.image, case .image = asset.imageSource else {
                return XCTFail("funding without a token image needs an operation icon")
            }
        }
    }

    func test_fundingStatus_isShownWhenTheDetailsOpenedInProgressOrTheOperationFailed() {
        for type in [MultichainActivityType.perpsBalanceDeposit, .perpsBalanceWithdrawal] {
            for status in [MultichainActivityStatus.pending, .confirmed, .failed, .dropped] {
                let event = perpsActivity(type, outAmount: "10250000", status: status)
                let opened = makeDetailsBuilder().build(activity: event)
                switch status {
                case .pending, .confirmed: XCTAssertNil(statusRow(in: opened))
                case .failed: XCTAssertEqual(statusRow(in: opened)?.value, TKLocales.State.failed)
                case .dropped: XCTAssertEqual(statusRow(in: opened)?.value, TKLocales.LiveActivity.dropped)
                }
                XCTAssertEqual(opened.pendingTitle != nil, status == .pending)
                if status == .confirmed {
                    XCTAssertEqual(
                        opened.date,
                        type == .perpsBalanceDeposit
                            ? TKLocales.EventDetails.depositedOn("29 Apr, 05:20")
                            : TKLocales.EventDetails.withdrawnOn("29 Apr, 05:20")
                    )
                } else {
                    let title = type == .perpsBalanceDeposit ? TKLocales.MultichainHistory.Perps.deposit : TKLocales.MultichainHistory.Perps.withdrawal
                    XCTAssertTrue(opened.date.hasPrefix(title + " · "))
                }

                let tracked = makeDetailsBuilder().build(activity: event, showsFundingStatus: true)
                XCTAssertNil(tracked.pendingTitle)
                let row = statusRow(in: tracked)
                switch status {
                case .pending:
                    XCTAssertEqual(row?.value, TKLocales.MultichainSwap.Details.pending)
                    XCTAssertEqual(row?.isPending, true)
                case .confirmed: XCTAssertEqual(row?.value, TKLocales.Result.success)
                case .failed: XCTAssertEqual(row?.value, TKLocales.State.failed)
                case .dropped: XCTAssertEqual(row?.value, TKLocales.LiveActivity.dropped)
                }
            }
        }
    }

    func test_aLighterTransactionIdShowsItsHashWithoutThePrefix() {
        let model = makeDetailsBuilder().build(activity: perpsActivity(.perpsBalanceDeposit, outAmount: "10250000"))
        XCTAssertTrue(model.rows.contains {
            if case let .inlineHash(_, hash) = $0 { return hash == MultichainActivityType.perpsBalanceDeposit.rawValue }
            return false
        })
    }

    func test_withdrawalWithAPayout_showsBothLegsAndThePayoutDollarValue() {
        let gram = MultichainAssetDetails(assetId: "ton/mainnet/coin", name: "GRAM", symbol: "GRAM", decimals: 9, image: "https://gram.png")
        let event = perpsActivity(
            .perpsBalanceWithdrawal,
            inAmount: "2000000000",
            outAmount: "10250000",
            incomingToken: gram,
            inAmountUsd: 3.95702793,
            feeAmount: "100000"
        )
        for hidden in [false, true] {
            let model = makeDetailsBuilder(hidden: hidden).build(activity: event)
            XCTAssertEqual(
                model.amountLines.map(\.amount),
                hidden ? [.secureModeValueShort, .secureModeValueShort] : ["\u{2212} 10.25 USDC", "+ 2 GRAM"]
            )
            XCTAssertEqual(model.fiat, hidden ? .secureModeValueShort : "+ $\u{2009}3.95")
            guard case .swap = model.image else { return XCTFail("a payout pairs the USDC with the received token") }
            XCTAssertTrue(model.rows.contains {
                if case let .fee(_, amount, fiat) = $0 {
                    return amount == (hidden ? .secureModeValueShort : "$\u{2009}0.1") && fiat == nil
                }
                return false
            })
        }
    }

    func test_payoutInAnEighteenDecimalToken_isShortenedAsInTheHistoryRow() {
        let bnb = MultichainAssetDetails(assetId: "bsc/mainnet/coin", name: "BNB", symbol: "BNB", decimals: 18, image: "https://bnb.png")
        let model = makeDetailsBuilder().build(activity: perpsActivity(
            .perpsBalanceWithdrawal,
            inAmount: "11153124572880421",
            outAmount: "7880000",
            incomingToken: bnb,
            inAmountUsd: 7.84
        ))
        XCTAssertEqual(model.amountLines.map(\.amount), ["\u{2212} 7.88 USDC", "+ 0.0111 BNB"])
    }

    func test_depositSource_keepsEveryDigitTheUserSent() {
        let eth = MultichainAssetDetails(assetId: "eth/mainnet/coin", name: "Ether", symbol: "ETH", decimals: 18, image: "https://eth.png")
        let model = makeDetailsBuilder().build(activity: perpsActivity(
            .perpsBalanceDeposit,
            inAmount: "2960000",
            outAmount: "1234567890000000",
            outgoingToken: eth,
            inAmountUsd: 2.96
        ))
        XCTAssertEqual(model.amountLines.first?.amount, "\u{2212} 0.00123456789 ETH")
    }

    func test_depositWithASourceToken_showsItBeforeTheCreditedUsdc() {
        let gram = MultichainAssetDetails(assetId: "ton/mainnet/coin", name: "GRAM", symbol: "GRAM", decimals: 9, image: "https://gram.png")
        let model = makeDetailsBuilder().build(activity: perpsActivity(
            .perpsBalanceDeposit,
            inAmount: "10250000",
            outAmount: "350000000000",
            outgoingToken: gram,
            inAmountUsd: 10.2536
        ))
        XCTAssertEqual(model.amountLines.map(\.amount), ["\u{2212} 350 GRAM", "+ 10.25 USDC"])
        XCTAssertEqual(model.fiat, "+ $\u{2009}10.25")
        guard case .swap = model.image else { return XCTFail("a source token pairs with the credited USDC") }
    }

    func test_fundingWithOnlyTheWalletLeg_doesNotRepeatItAsASwap() {
        let token = MultichainAssetDetails(assetId: "ton/mainnet/coin", name: "GRAM", symbol: "GRAM", decimals: 9, image: "")
        let events = [
            perpsActivity(.perpsBalanceDeposit, outAmount: "2000000000", outgoingToken: token),
            perpsActivity(.perpsBalanceWithdrawal, inAmount: "2000000000", incomingToken: token),
        ]
        for event in events {
            let model = makeDetailsBuilder().build(activity: event)
            XCTAssertEqual(model.amountLines.count, 1)
            guard case .single = model.image else { return XCTFail("one known leg needs one asset") }
        }
    }

    func test_withdrawalPaidOutOnEthereum_showsAndOpensThePayoutHash() throws {
        let withdrawal = perpsActivity(
            .perpsBalanceWithdrawal,
            outAmount: "15000000",
            txIds: ["lighter:0xaaaa1111", "eth:0xbbbb2222"],
            explorerURL: URL(string: "https://eth.blockscout.com/tx/0xbbbb2222"),
            explorerTxId: "eth:0xbbbb2222"
        )
        let model = MultichainTransactionDetailsModelBuilder(
            amountFormatter: makeAmountFormatter(), dateFormatter: makeDateFormatter(),
            transactionButtonProvider: MultichainTransactionDetailsModelBuilder.transactionButton,
            hidesAmounts: { false }
        ).build(activity: withdrawal)

        XCTAssertTrue(model.rows.contains {
            if case .inlineHash(_, "0xbbbb2222") = $0 { return true }
            return false
        })
        let button = try XCTUnwrap(model.transactionButton)
        XCTAssertEqual(button.url.absoluteString, "https://eth.blockscout.com/tx/0xbbbb2222")
        XCTAssertEqual(button.title.spans.last?.text, "0xbbbb22")
    }
}

private extension MultichainHistoryPerpsRowTests {
    func statusRow(in model: MultichainTransactionDetailsModel) -> (value: String, isPending: Bool)? {
        model.rows.lazy.compactMap { row -> (value: String, isPending: Bool)? in
            if case let .status(_, value, _, isPending) = row { return (value, isPending) }
            return nil
        }.first
    }

    func makeDetailsBuilder(hidden: Bool = false, walletName: String? = nil) -> MultichainTransactionDetailsModelBuilder {
        MultichainTransactionDetailsModelBuilder(
            amountFormatter: makeAmountFormatter(), dateFormatter: makeDateFormatter(),
            transactionButtonProvider: { _ in nil }, hidesAmounts: { hidden }, walletName: walletName
        )
    }

    func makeMapper() -> MultichainHistoryActivityItemMapper {
        MultichainHistoryActivityItemMapper(
            amountFormatter: makeAmountFormatter(),
            dateFormatter: makeDateFormatter(),
            hidesAmounts: { false }
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
        incomingToken: MultichainAssetDetails? = nil,
        outgoingToken: MultichainAssetDetails? = nil,
        inAmountUsd: Double? = nil,
        feeAmount: String? = nil,
        feeAssetId: String = "arb/mainnet/erc20/usdc",
        protocolName: String? = nil,
        status: MultichainActivityStatus = .confirmed,
        txIds: [String]? = nil,
        explorerURL: URL? = nil,
        explorerTxId: String? = nil
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
            status: status,
            blockTime: Date(timeIntervalSince1970: 1_777_440_000),
            blockNumber: nil,
            fromChain: nil,
            toChain: nil,
            walletAddress: "0xwallet",
            direction: inAmount != nil ? .incoming : .outgoing,
            fromAddress: nil,
            toAddress: nil,
            outToken: outAmount.map { _ in outgoingToken ?? usdc },
            outAmount: outAmount,
            outAmountUsd: nil,
            inToken: inAmount.map { _ in incomingToken ?? usdc },
            inAmount: inAmount,
            inAmountUsd: inAmountUsd,
            feeToken: feeAmount.map { _ in
                MultichainAssetDetails(assetId: feeAssetId, name: "USD Coin", symbol: "USDC", decimals: 6, image: "")
            },
            feeAmount: feeAmount,
            feeAmountUsd: nil,
            protocolName: protocolName,
            txIds: txIds ?? ["lighter:\(activityType.rawValue)"],
            explorerURL: explorerURL,
            explorerTxId: explorerTxId,
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
