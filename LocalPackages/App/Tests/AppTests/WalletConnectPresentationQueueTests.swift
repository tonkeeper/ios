@testable import App
import KeeperCore
import XCTest

final class WalletConnectPresentationQueueTests: XCTestCase {
    func testQueuePresentsOneItemAtATime() {
        let queue = WalletConnectPresentationQueue()
        let first = request(id: "1", topic: "topic-1")
        let second = proposal(id: "2", pairingTopic: "pairing-2")

        XCTAssertEqual(queue.enqueue(first), first)
        XCTAssertEqual(queue.activeKey, first.key)
        XCTAssertNil(queue.enqueue(second))
        XCTAssertEqual(queue.activeKey, first.key)

        XCTAssertEqual(queue.finish(first.key), second)
        XCTAssertEqual(queue.activeKey, second.key)

        XCTAssertNil(queue.finish(first.key))
        XCTAssertNil(queue.finish(second.key))
        XCTAssertNil(queue.activeKey)
    }

    func testProposalKeyIncludesPairingTopic() {
        let queue = WalletConnectPresentationQueue()
        let first = proposal(id: "proposal", pairingTopic: "pairing-1")
        let second = proposal(id: "proposal", pairingTopic: "pairing-2")

        XCTAssertNotEqual(first.key, second.key)
        XCTAssertEqual(queue.enqueue(first), first)
        XCTAssertNil(queue.enqueue(second))

        XCTAssertEqual(queue.finish(first.key), second)
        XCTAssertEqual(queue.activeKey, second.key)
    }

    func testRemoveQueuedRequestsByTopicKeepsActiveRequestAndOtherTopics() {
        let queue = WalletConnectPresentationQueue()
        let active = request(id: "active", topic: "topic-1")
        let sameTopicQueued = request(id: "queued-1", topic: "topic-1")
        let otherTopicQueued = request(id: "queued-2", topic: "topic-2")

        XCTAssertEqual(queue.enqueue(active), active)
        XCTAssertNil(queue.enqueue(sameTopicQueued))
        XCTAssertNil(queue.enqueue(otherTopicQueued))

        XCTAssertTrue(queue.removeQueuedRequests(topic: "topic-1"))
        XCTAssertEqual(queue.activeKey, active.key)
        XCTAssertEqual(queue.finish(active.key), otherTopicQueued)
        XCTAssertEqual(queue.activeKey, otherTopicQueued.key)
    }
}

private extension WalletConnectPresentationQueueTests {
    func proposal(
        id: String,
        pairingTopic: String
    ) -> WalletConnectPresentationItem {
        .proposal(
            WalletConnectSessionProposal(
                id: id,
                pairingTopic: pairingTopic,
                dapp: dapp(),
                namespaces: [],
                validation: .valid,
                source: .deeplink
            )
        )
    }

    func request(
        id: String,
        topic: String
    ) -> WalletConnectPresentationItem {
        .request(
            WalletConnectSessionRequest(
                id: id,
                topic: topic,
                chain: .eth,
                method: .personalSign,
                dapp: dapp(),
                payload: .signMessage(
                    WalletConnectSignMessage(
                        address: "0xabc",
                        message: "0x68656c6c6f",
                        kind: .personal
                    )
                ),
                source: .deeplink,
                walletId: "wallet"
            )
        )
    }

    func dapp() -> WalletConnectDapp {
        WalletConnectDapp(
            name: "dApp",
            url: "https://example.com",
            description: "",
            iconURL: nil
        )
    }
}
