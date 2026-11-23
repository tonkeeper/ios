@testable import App
import TKCore
import XCTest

@available(iOS 16.2, *)
final class TransactionLiveActivityAnalyticsTests: XCTestCase {
    typealias State = TransactionLiveActivityAttributes.ContentState

    func test_perpsIdsWinOverTheTransactionKind() {
        XCTAssertEqual(LiveActivityOperation(state(id: "perps-funding:op", kind: .send)), .perpsFunding)
        XCTAssertEqual(LiveActivityOperation(state(id: "perps-trading:op", kind: .other)), .perpsTrade)
    }

    func test_walletTransactionsFollowTheirKind() {
        XCTAssertEqual(LiveActivityOperation(state(id: "ton:abc", kind: .send)), .send)
        XCTAssertEqual(LiveActivityOperation(state(id: "ton:abc", kind: .receive)), .receive)
        XCTAssertEqual(LiveActivityOperation(state(id: "swap:ton:abc", kind: .swap)), .swap)
        XCTAssertEqual(LiveActivityOperation(state(id: "tron:abc", kind: .other)), .other)
        XCTAssertEqual(LiveActivityOperation(state(id: "tron:abc", kind: nil)), .other)
    }

    @MainActor
    func test_tapWithoutItsActivityKeepsWhatTheLinkTells() {
        let click = LiveActivityClick(
            link: TransactionLiveActivityLink(walletId: "w", transactionId: "perps-funding:op"),
            isColdStart: true
        )

        XCTAssertEqual(click.operation, .perpsFunding)
        XCTAssertEqual(click.status, .unknown)
        XCTAssertTrue(click.isColdStart)
    }

    private func state(id: String, kind: State.Kind?) -> State {
        State(
            transactionId: id,
            chain: "TON",
            detail: nil,
            status: .pending,
            title: "Title",
            updatedAt: Date(timeIntervalSince1970: 0),
            source: nil,
            destination: nil,
            kind: kind,
            wallet: nil,
            counterpartyAddress: nil,
            stage: nil,
            perpsMarketId: nil
        )
    }
}
