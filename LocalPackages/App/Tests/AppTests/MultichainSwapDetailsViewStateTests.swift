@testable import App
import AppUI
import KeeperCore
import TKLocalize
import XCTest

@MainActor
final class MultichainSwapDetailsViewStateTests: XCTestCase {
    func test_aPendingSwapAcrossChainsLinksItsSentTransactionAndAwaitsTheOneToReceive() throws {
        let state = try makeState(
            from: .ton,
            to: .btc,
            activity: activity(status: .pending, from: .ton, to: .btc, links: [link("ton:4d1e1608aa", .ton)])
        )

        XCTAssertEqual(state.transactions.map(describe), [
            "\(TKLocales.ActionTypes.sent) 4d1e1608 → https://explorer.test/ton:4d1e1608aa, copies 4d1e1608aa",
            "receiving",
        ])
    }

    func test_aDoneSwapAcrossChainsLinksBothItsTransactions() throws {
        let state = try makeState(
            from: .ton,
            to: .btc,
            activity: activity(
                status: .confirmed,
                from: .ton,
                to: .btc,
                links: [link("ton:4d1e1608aa", .ton), link("btc:9b7c3e52bb", .btc)]
            )
        )

        XCTAssertEqual(state.transactions.map(describe), [
            "\(TKLocales.ActionTypes.sent) 4d1e1608 → https://explorer.test/ton:4d1e1608aa, copies 4d1e1608aa",
            "\(TKLocales.ActionTypes.received) 9b7c3e52 → https://explorer.test/btc:9b7c3e52bb, copies 9b7c3e52bb",
        ])
    }

    func test_aFailedSwapLinksOnlyItsSentTransaction() throws {
        let state = try makeState(
            from: .ton,
            to: .btc,
            activity: activity(status: .failed, from: .ton, to: .btc, links: [link("ton:4d1e1608aa", .ton)])
        )

        XCTAssertEqual(state.transactions.map(describe), [
            "\(TKLocales.ActionTypes.sent) 4d1e1608 → https://explorer.test/ton:4d1e1608aa, copies 4d1e1608aa",
        ])
    }

    func test_aPendingSwapOnOneChainAwaitsNoOtherTransaction() throws {
        let state = try makeState(
            from: .ton,
            to: .ton,
            activity: activity(status: .pending, from: .ton, to: .ton, links: [link("ton:4d1e1608aa", .ton)])
        )

        XCTAssertEqual(state.transactions.map(describe), [
            "\(TKLocales.ActionTypes.sent) 4d1e1608 → https://explorer.test/ton:4d1e1608aa, copies 4d1e1608aa",
        ])
    }

    func test_theNetworkFeeIsWhatTheHistoryEntryPaid() {
        let state = makeState(
            from: .ton,
            to: .btc,
            activity: activity(status: .pending, from: .ton, to: .btc, links: [], batteryCharges: 7)
        )

        XCTAssertEqual(state.networkFee, "7 \(TKLocales.Battery.Refill.chargesCount(count: 7))")
    }

    func test_aSwapNotInHistoryYetShowsNoFeeAndNoTransactions() {
        let state = makeState(from: .ton, to: .btc, activity: nil)

        XCTAssertNil(state.networkFee)
        XCTAssertTrue(state.transactions.isEmpty)
    }
}

private extension MultichainSwapDetailsViewStateTests {
    func makeState(
        from sendChain: MultichainChain,
        to receiveChain: MultichainChain,
        activity: MultichainActivity?
    ) -> MultichainSwapDetailsViewState {
        let amountFormatter = AmountFormatter()
        let dateFormatter = DateFormatter()
        let swap = MultichainSwapSentSwap(
            multichainState: MultichainWalletState(walletId: "wallet", addresses: []),
            txHash: nil,
            sendAsset: asset("SEND", chain: sendChain),
            receiveAsset: asset("RECEIVE", chain: receiveChain),
            sendAmount: 100,
            estimatedReceiveAmount: 28,
            date: Date()
        )
        return MultichainSwapDetailsViewState(
            trackedSwap: MultichainSwapTrackedSwap(swap: swap, activity: activity),
            amountFormatter: amountFormatter,
            dateFormatter: dateFormatter,
            historyDetails: MultichainTransactionDetailsModelBuilder(
                amountFormatter: amountFormatter,
                dateFormatter: dateFormatter,
                transactionButtonProvider: { _ in nil },
                hidesAmounts: { false }
            )
        )
    }

    func asset(_ symbol: String, chain: MultichainChain) -> MultichainAsset {
        MultichainAsset(
            asset: MultichainAssetDetails(
                assetId: "\(chain.rawValue)/mainnet/\(symbol)",
                chain: chain,
                name: symbol,
                symbol: symbol,
                decimals: 9,
                image: ""
            ),
            price: MultichainAssetPrice(prices: [:], diff24h: [:], diff7d: [:]),
            balance: .zero
        )
    }

    func link(_ transactionId: String, _ chain: MultichainChain) throws -> MultichainActivityExplorerLink {
        try MultichainActivityExplorerLink(
            transactionId: transactionId,
            chain: chain,
            url: XCTUnwrap(URL(string: "https://explorer.test/\(transactionId)"))
        )
    }

    func activity(
        status: MultichainActivityStatus,
        from fromChain: MultichainChain,
        to toChain: MultichainChain,
        links: [MultichainActivityExplorerLink],
        batteryCharges: Int? = nil
    ) -> MultichainActivity {
        MultichainActivity(
            activityType: .swap,
            status: status,
            blockTime: Date(),
            blockNumber: nil,
            fromChain: fromChain,
            toChain: toChain,
            walletAddress: nil,
            direction: .outgoing,
            fromAddress: nil,
            toAddress: nil,
            outToken: nil,
            outAmount: nil,
            outAmountUsd: nil,
            inToken: nil,
            inAmount: nil,
            inAmountUsd: nil,
            feeToken: nil,
            feeAmount: nil,
            feeAmountUsd: nil,
            protocolName: nil,
            txIds: links.map(\.transactionId),
            explorerLinks: links,
            isRead: nil,
            feeType: batteryCharges.map { _ in .battery },
            batteryCharges: batteryCharges
        )
    }

    func describe(_ transaction: MultichainSwapDetailsViewState.Transaction) -> String {
        switch transaction {
        case let .link(button, hash):
            "\(button.title.spans.map(\.text).joined()) → \(button.url.absoluteString), copies \(hash)"
        case .receiving:
            "receiving"
        }
    }
}
