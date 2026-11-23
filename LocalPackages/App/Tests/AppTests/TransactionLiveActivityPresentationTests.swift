@testable import App
import TKLocalize
import XCTest

@available(iOS 16.2, *)
final class TransactionLiveActivityPresentationTests: XCTestCase {
    typealias Presentation = TransactionLiveActivityPresentation
    typealias State = TransactionLiveActivityAttributes.ContentState

    func test_sendSignsSourceAmountAndOmitsNetworkOfNativeCurrency() {
        var send = state(
            kind: .send,
            source: .init(network: "TON", currency: "TON", amount: "1.25"),
            destination: .init(network: "TON", currency: "TON", amount: nil),
            counterparty: "UQDGQ7uTp6a4Bq8tCVlq8UlHBq5DBXL4OLllNaD-BdZ_H7CE"
        )
        send.fiat = "$4.10"
        let presentation = Presentation(state: send, isStale: false)

        XCTAssertEqual(presentation.glyph, .send)
        XCTAssertEqual(presentation.badge, .arrowUp)
        XCTAssertEqual(presentation.badgeTone, .pending)
        XCTAssertEqual(presentation.status, TKLocales.LiveActivity.confirming)
        XCTAssertEqual(presentation.amount, .init(text: "\u{2212}1.25 TON", style: .primary))
        XCTAssertEqual(presentation.secondaryAmount, .init(text: "$4.10", style: .secondary))
        XCTAssertEqual(presentation.subtitle, TKLocales.LiveActivity.to("UQDG...H7CE"))
        XCTAssertEqual(presentation.compactValues, ["\u{2212}1.25 TON", "\u{2212}1.25", "TON"])
    }

    func test_nativeCoinOmitsItsNetwork() {
        let gram = make(state(
            kind: .send,
            source: .init(network: "TON", currency: "GRAM", amount: "1.25"),
            counterparty: "UQDGQ7uTp6a4Bq8tCVlq8UlHBq5DBXL4OLllNaD-BdZ_H7CE"
        ))
        let usdt = make(state(
            kind: .send,
            source: .init(network: "TON", currency: "USDT", amount: "5"),
            counterparty: "UQDGQ7uTp6a4Bq8tCVlq8UlHBq5DBXL4OLllNaD-BdZ_H7CE"
        ))

        XCTAssertEqual(gram.subtitle, TKLocales.LiveActivity.to("UQDG...H7CE"))
        XCTAssertEqual(usdt.subtitle, TKLocales.LiveActivity.onNetwork(TKLocales.LiveActivity.to("UQDG...H7CE"), "TON"))
    }

    func test_receiveNamesTokenNetworkNextToSender() {
        let presentation = make(state(
            kind: .receive,
            source: .init(network: "TRON", currency: "USDT", amount: nil),
            destination: .init(network: "TRON", currency: "USDT", amount: "72"),
            counterparty: "TP1dnHvtnNypf6Paw5t6JGRdEBYWnm2T5t"
        ))

        XCTAssertEqual(presentation.badge, .arrowDown)
        XCTAssertEqual(presentation.amount, .init(text: "+72 USDT", style: .positive))
        XCTAssertNil(presentation.secondaryAmount)
        XCTAssertEqual(
            presentation.subtitle,
            TKLocales.LiveActivity.onNetwork(TKLocales.LiveActivity.from("TP1d...2T5t"), "TRON")
        )
    }

    func test_swapLeadsWithReceivedAmountAndNamesWhatChanges() {
        let tokens = make(state(
            kind: .swap,
            source: .init(network: "TON", currency: "USDT", amount: "12.5"),
            destination: .init(network: "TON", currency: "TON", amount: "4.5")
        ), detail: "USDT → TON")
        let networks = make(state(
            kind: .swap,
            source: .init(network: "TON", currency: "USDT", amount: "25"),
            destination: .init(network: "TRON", currency: "USDT", amount: "24.8")
        ))

        XCTAssertEqual(tokens.badge, .swap)
        XCTAssertEqual(tokens.amount, .init(text: "+4.5 TON", style: .positive))
        XCTAssertEqual(tokens.secondaryAmount, .init(text: "\u{2212}12.5 USDT", style: .secondary))
        XCTAssertEqual(tokens.subtitle, "USDT → TON")
        XCTAssertEqual(networks.subtitle, "TON → TRON")
        XCTAssertEqual(networks.compactValues, ["+24.8 USDT", "+24.8", "USDT"])
    }

    func test_perpsOperationsReadAsDepositWithdrawalOrTrade() {
        let deposit = make(state(
            kind: .deposit,
            source: .init(network: "TON", currency: "GRAM", amount: "25"),
            destination: .init(network: "ETH", currency: "USDC", amount: "72.5")
        ), chain: "PERPS")
        var withdrawalState = state(
            kind: .withdrawal,
            source: .init(network: "PERPS", currency: "USDC", amount: "50"),
            destination: .init(network: "ETH", currency: "USDC", amount: nil)
        )
        withdrawalState.fiat = "$50.00"
        let withdrawal = make(withdrawalState, chain: "PERPS")
        let open = make(state(kind: .open, destination: .init(network: "PERPS", currency: "BTC", amount: "0.015")), chain: "PERPS")
        let close = make(state(kind: .close, destination: .init(network: "PERPS", currency: "ETH", amount: "0.42")), chain: "PERPS")

        XCTAssertEqual(deposit.glyph, .perps)
        XCTAssertEqual(deposit.badge, .trayArrowDown)
        XCTAssertEqual(deposit.amount, .init(text: "+72.5 USDC", style: .positive))
        XCTAssertEqual(deposit.secondaryAmount, .init(text: "\u{2212}25 GRAM", style: .secondary))
        XCTAssertEqual(deposit.subtitle, "GRAM → USDC")
        XCTAssertEqual(withdrawal.badge, .trayArrowUp)
        XCTAssertEqual(withdrawal.amount, .init(text: "+50 USDC", style: .positive))
        XCTAssertEqual(withdrawal.secondaryAmount, .init(text: "$50.00", style: .secondary))
        XCTAssertEqual(withdrawal.subtitle, "\(TKLocales.LiveActivity.perps) → \(TKLocales.Receive.Multichain.Networks.Ethereum.title)")
        XCTAssertEqual(open.badge, .arrowUp)
        XCTAssertEqual(open.amount, .init(text: "0.015 BTC", style: .primary))
        XCTAssertEqual(open.subtitle, TKLocales.LiveActivity.perps)
        XCTAssertEqual(close.badge, .arrowDown)
    }

    func test_unmovedFundsLoseTheirDirectionalColor() {
        for status in [State.Status.failed, .dropped] {
            let send = make(state(status: status, kind: .send, source: .init(network: "TON", currency: "TON", amount: "1")))
            let receive = make(state(status: status, kind: .receive, destination: .init(network: "TON", currency: "TON", amount: "1")))
            let swap = make(state(
                status: status,
                kind: .swap,
                source: .init(network: "TON", currency: "USDT", amount: "12.5"),
                destination: .init(network: "TON", currency: "TON", amount: "4.5")
            ))

            XCTAssertEqual(send.amount, .init(text: "\u{2212}1 TON", style: .secondary), "\(status)")
            XCTAssertEqual(receive.amount, .init(text: "1 TON", style: .primary), "\(status)")
            XCTAssertEqual(swap.amount, .init(text: "+4.5 TON", style: .secondary), "\(status)")
        }
        let unknown = make(state(status: .unknown, kind: .send, source: .init(network: "TON", currency: "TON", amount: "1")))
        XCTAssertEqual(unknown.amount, .init(text: "1 TON", style: .primary))
    }

    func test_statusLineBadgeAndToneFollowTheStatus() {
        let pending = make(state(kind: .send))
        let stale = make(state(kind: .send), isStale: true)
        let confirmed = make(state(status: .confirmed, kind: .send))
        let failed = make(state(status: .failed, kind: .send))
        let dropped = make(state(status: .dropped, kind: .receive))
        let unknown = make(state(status: .unknown, kind: .send))
        let staleOutcome = make(state(status: .confirmed, kind: .send), isStale: true)

        XCTAssertEqual(pending.statusTone, .neutral)
        XCTAssertEqual(stale.status, TKLocales.LiveActivity.noUpdatesFor(5))
        XCTAssertEqual([stale.statusTone, stale.badgeTone, stale.progress.tone], [.warning, .warning, .warning])
        XCTAssertEqual(stale.badge, .clock)
        XCTAssertEqual(confirmed.status, TKLocales.LiveActivity.confirmed)
        XCTAssertEqual([confirmed.badge, failed.badge, unknown.badge], [.done, .cross, .question])
        XCTAssertEqual([confirmed.statusTone, failed.statusTone, unknown.statusTone], [.success, .failure, .neutral])
        XCTAssertEqual(failed.status, TKLocales.State.failed)
        XCTAssertEqual(dropped.subtitle, TKLocales.LiveActivity.droppedByNetwork)
        XCTAssertEqual(unknown.subtitle, TKLocales.LiveActivity.checkStatusInHistory)
        XCTAssertEqual(staleOutcome.badge, .done)
    }

    func test_stageNamesTheStatusAndFillsItsSegmentByHalf() {
        let stage = State.Stage(index: 2, count: 3, title: "Converting to USDC")
        let staged = make(state(kind: .deposit, stage: stage))
        let overflow = make(state(kind: .deposit, stage: .init(index: 5, count: 3, title: nil)))
        let legacy = make(state(kind: .swap, stage: .init(index: 2, count: 4)))
        var settledState = state(status: .confirmed, kind: .deposit)
        settledState.steps = 3
        let settled = make(settledState)
        var unknownState = state(status: .unknown, kind: .deposit)
        unknownState.steps = 3
        let single = make(state(kind: .send))

        XCTAssertEqual(staged.status, "Converting to USDC")
        XCTAssertEqual(staged.progress, .init(steps: 3, filled: 1.5, tone: .pending))
        XCTAssertEqual(overflow.progress.filled, 2.5)
        XCTAssertEqual(legacy.status, TKLocales.LiveActivity.confirming)
        XCTAssertEqual(legacy.progress.steps, 4)
        XCTAssertEqual(settled.progress, .init(steps: 3, filled: 3, tone: .success))
        XCTAssertEqual(make(unknownState).progress, .init(steps: 3, filled: 0, tone: .neutral))
        XCTAssertEqual(single.progress, .init(steps: 1, filled: 0.5, tone: .pending))
    }

    func test_hiddenBalanceShowsOnlyAPlaceholder() {
        var hidden = state(
            kind: .send,
            source: .init(network: "TRON", currency: "USDT", amount: nil),
            counterparty: nil
        )
        hidden.isRedacted = true

        let presentation = make(hidden)

        XCTAssertEqual(presentation.amount, .init(text: Presentation.hiddenAmount, style: .primary))
        XCTAssertNil(presentation.secondaryAmount)
        XCTAssertEqual(presentation.compactValues, [Presentation.hiddenAmount])
        XCTAssertEqual(
            presentation.subtitle,
            TKLocales.LiveActivity.onNetwork(TKLocales.LiveActivity.to(Presentation.hiddenAmount), "TRON")
        )
    }

    func test_queueShowsOnlyWhilePending() {
        var pending = state(kind: .send)
        pending.queuedCount = 2
        var confirmed = pending
        confirmed.status = .confirmed

        XCTAssertEqual(make(pending).queuedCount, 2)
        XCTAssertEqual(make(confirmed).queuedCount, 0)
    }

    private func make(
        _ state: State,
        chain: String = "TON",
        detail: String? = nil,
        isStale: Bool = false
    ) -> Presentation {
        var state = state
        state.chain = chain
        state.detail = detail
        return Presentation(state: state, isStale: isStale)
    }

    private func state(
        status: State.Status = .pending,
        kind: State.Kind?,
        source: State.Leg? = nil,
        destination: State.Leg? = nil,
        counterparty: String? = nil,
        stage: State.Stage? = nil
    ) -> State {
        State(
            transactionId: "tx",
            chain: "TON",
            detail: nil,
            status: status,
            title: "Title",
            updatedAt: Date(timeIntervalSince1970: 0),
            source: source,
            destination: destination,
            kind: kind,
            wallet: nil,
            counterpartyAddress: counterparty,
            stage: stage,
            perpsMarketId: nil
        )
    }
}
