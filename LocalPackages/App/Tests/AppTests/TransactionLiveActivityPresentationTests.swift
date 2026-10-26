@testable import App
import XCTest

@available(iOS 16.2, *)
final class TransactionLiveActivityPresentationTests: XCTestCase {
    typealias Presentation = TransactionLiveActivityPresentation
    typealias State = TransactionLiveActivityAttributes.ContentState

    func test_sendSignsSourceAmountAndOmitsNetworkOfNativeCurrency() {
        let presentation = make(state(
            kind: .send,
            source: .init(network: "TON", currency: "TON", amount: "1.25"),
            destination: .init(network: "TON", currency: "TON", amount: nil),
            counterparty: "UQDGQ7uTp6a4Bq8tCVlq8UlHBq5DBXL4OLllNaD-BdZ_H7CE"
        ))

        XCTAssertEqual(presentation.glyph, .send)
        XCTAssertEqual(presentation.tone, .pending)
        XCTAssertEqual(presentation.amount, .init(text: "\u{2212}1.25 TON", style: .primary))
        XCTAssertNil(presentation.secondaryAmount)
        XCTAssertEqual(presentation.subtitle, "UQDG...H7CE")
        XCTAssertEqual(presentation.compactValues, ["1.25 TON", "1.25", "TON"])
    }

    func test_receiveNamesTokenNetworkNextToSender() {
        let presentation = make(state(
            kind: .receive,
            source: .init(network: "TRON", currency: "USDT", amount: nil),
            destination: .init(network: "TRON", currency: "USDT", amount: "72"),
            counterparty: "TP1dnHvtnNypf6Paw5t6JGRdEBYWnm2T5t"
        ))

        XCTAssertEqual(presentation.glyph, .receive)
        XCTAssertEqual(presentation.amount, .init(text: "+72 USDT", style: .positive))
        XCTAssertEqual(presentation.subtitle, "TRON · TP1d...2T5t")
    }

    func test_swapLeadsWithReceivedAmountAndShowsRouteOnlyAcrossChains() {
        let sameChain = make(state(
            kind: .swap,
            source: .init(network: "TON", currency: "USDT", amount: "12.5"),
            destination: .init(network: "TON", currency: "TON", amount: "4.5")
        ), detail: "USDT → TON")
        let crossChain = make(state(
            kind: .swap,
            source: .init(network: "TON", currency: "USDT", amount: "12.5"),
            destination: .init(network: "BTC", currency: "BTC", amount: "0.0001")
        ))

        XCTAssertEqual(sameChain.amount, .init(text: "+4.5 TON", style: .positive))
        XCTAssertEqual(sameChain.secondaryAmount, .init(text: "\u{2212}12.5 USDT", style: .secondary))
        XCTAssertNil(sameChain.subtitle)
        XCTAssertEqual(crossChain.subtitle, "TON → BTC")
        XCTAssertEqual(crossChain.compactValues, ["0.0001 BTC", "0.0001", "BTC"])
    }

    func test_unmovedFundsLoseTheirDirectionalColor() {
        for status in [State.Status.failed, .dropped, .unknown] {
            let presentation = make(state(
                status: status,
                kind: .receive,
                destination: .init(network: "TON", currency: "TON", amount: "3")
            ))

            XCTAssertEqual(presentation.glyph, status == .unknown ? .unknown : .failed)
            XCTAssertEqual(presentation.tone, status == .unknown ? .neutral : .failure)
            XCTAssertEqual(presentation.amount?.style, .secondary)
            XCTAssertEqual(presentation.amount?.text, status == .unknown ? "3 TON" : "+3 TON")
        }
    }

    func test_staleNoticeOnlyWhilePending() {
        XCTAssertTrue(make(state(kind: .send), isStale: true).showsStaleNotice)
        XCTAssertFalse(make(state(status: .confirmed, kind: .send), isStale: true).showsStaleNotice)
        XCTAssertFalse(make(state(status: .unknown, kind: .send), isStale: true).showsStaleNotice)
        XCTAssertFalse(make(state(kind: .send), isStale: false).showsStaleNotice)
    }

    func test_perpsTradeDropsDetailAlreadyShownAsCurrency() {
        let presentation = make(
            state(kind: .other, destination: .init(network: "PERPS", currency: "BTC", amount: "0.5")),
            chain: "PERPS",
            detail: "BTC"
        )

        XCTAssertEqual(presentation.glyph, .perps)
        XCTAssertEqual(presentation.amount, .init(text: "0.5 BTC", style: .primary))
        XCTAssertNil(presentation.subtitle)
    }

    func test_pushStartedStateWithoutKindReadsAsExchange() {
        let presentation = make(state(
            kind: nil,
            source: .init(network: "TON", currency: "USDT", amount: "12.5"),
            destination: .init(network: "BTC", currency: "BTC", amount: "0.0001")
        ), chain: "BTC", detail: "USDT → BTC")

        XCTAssertEqual(presentation.glyph, .pending)
        XCTAssertEqual(presentation.amount, .init(text: "+0.0001 BTC", style: .positive))
        XCTAssertEqual(presentation.secondaryAmount, .init(text: "\u{2212}12.5 USDT", style: .secondary))
        XCTAssertEqual(presentation.subtitle, "TON → BTC")
    }

    func test_compactValuesFallBackToCurrencyThenChainWithoutAmounts() {
        let withCurrency = make(state(
            kind: .other,
            source: .init(network: "PERPS", currency: "USDC", amount: nil),
            destination: .init(network: "ETH", currency: "USDC", amount: "")
        ), chain: "PERPS", detail: "Withdraw")
        let bare = make(state(kind: .other), chain: "TRON")

        XCTAssertNil(withCurrency.amount)
        XCTAssertEqual(withCurrency.compactValues, ["USDC"])
        XCTAssertEqual(withCurrency.subtitle, "PERPS → ETH")
        XCTAssertEqual(bare.compactValues, ["TRON"])
        XCTAssertNil(bare.subtitle)
    }

    func test_compactValuesNeverRepeatAnAmountWithoutCurrency() {
        let presentation = make(state(kind: .receive, destination: .init(network: "TON", currency: nil, amount: "5")))

        XCTAssertEqual(presentation.compactValues, ["5", "TON"])
    }

    func test_compactValuesUseUpdatedDestinationNetworkWhenIndexed() {
        let presentation = make(state(
            kind: .swap,
            source: .init(network: "TON", currency: nil, amount: nil),
            destination: .init(network: "BTC", currency: nil, amount: nil)
        ), chain: "TON")

        XCTAssertEqual(presentation.compactValues, ["BTC"])
    }

    func test_ringFillsWithTheStagesReachedOnlyWhilePending() {
        let staged = state(kind: .other, stage: .init(index: 2, count: 4))

        XCTAssertEqual(make(staged).progress, 0.5)
        XCTAssertEqual(make(state(kind: .other, stage: .init(index: 5, count: 4))).progress, 1)
        XCTAssertEqual(make(state(kind: .other, stage: .init(index: 1, count: 0))).progress, 1)
        XCTAssertNil(make(state(kind: .other)).progress)
        XCTAssertNil(make(state(status: .confirmed, kind: .other, stage: .init(index: 3, count: 4))).progress)
    }

    private func make(
        _ state: State,
        chain: String = "TON",
        detail: String? = nil,
        isStale: Bool = false
    ) -> Presentation {
        Presentation(
            state: State(
                transactionId: state.transactionId,
                chain: chain,
                detail: detail,
                status: state.status,
                title: state.title,
                updatedAt: state.updatedAt,
                source: state.source,
                destination: state.destination,
                kind: state.kind,
                wallet: state.wallet,
                counterpartyAddress: state.counterpartyAddress,
                stage: state.stage,
                perpsMarketId: state.perpsMarketId
            ),
            isStale: isStale
        )
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
