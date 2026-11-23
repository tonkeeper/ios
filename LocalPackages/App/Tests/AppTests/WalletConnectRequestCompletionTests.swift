@testable import App
import KeeperCore
import XCTest

@MainActor
final class WalletConnectRequestCompletionTests: XCTestCase {
    func testMissingPendingRequestReportsSubmissionOnlyWithACachedSendResult() {
        let error = WalletConnectResponseError.missingRequest(id: "request")
        let approval = WalletConnectRequestApprovalState()
        XCTAssertEqual(approval.deliveryError(error, method: .ethSendTransaction, requestId: "request"), error)

        approval.cacheResponse(.string("submitted-hash"))
        for method in [WalletConnectMethod.ethSendTransaction, .solanaSignAndSendTransaction] {
            for terminalError in [error, .requestExpired(id: "request"), .missingSession(topic: "session"), .sdk(message: "SDK failure", retryable: false)] {
                XCTAssertEqual(approval.deliveryError(terminalError, method: method, requestId: "request"), .requestExpiredAfterBroadcast(id: "request"))
            }
        }
        for method in [WalletConnectMethod.ethSignTransaction, .solanaSignTransaction, .personalSign] {
            XCTAssertEqual(approval.deliveryError(error, method: method, requestId: "request"), error)
        }
        let networkError = WalletConnectResponseError.sdk(message: "network", retryable: true)
        XCTAssertEqual(approval.deliveryError(networkError, method: .ethSendTransaction, requestId: "request"), networkError)
        XCTAssertEqual(approval.cachedResponse(), .string("submitted-hash"))
    }

    func testADeliveredResponseRedirectsOnceAfterTheScreenCloses() {
        var events: [String] = []
        let completion = WalletConnectRequestCompletion(
            onDelivered: { events.append("redirect") },
            onFinished: { events.append("finish") }
        )

        completion.delivered()
        XCTAssertTrue(events.isEmpty)
        completion.finish()
        completion.delivered()
        completion.finish()

        XCTAssertEqual(events, ["redirect", "finish"])
    }

    func testDeliveryAfterExpiryCanRedirectAfterTheCoordinatorHasBeenReleased() {
        var owner: Owner? = Owner()
        let ownerWasReleased = { [weak owner] in owner == nil }
        var events: [String] = []
        let completion = WalletConnectRequestCompletion(
            onDelivered: { events.append("redirect") },
            onFinished: {
                events.append("finish")
                owner = nil
            }
        )

        completion.finish()
        XCTAssertTrue(ownerWasReleased())
        XCTAssertEqual(events, ["finish"])
        completion.delivered()
        completion.finish()
        completion.delivered()

        XCTAssertEqual(events, ["finish", "redirect"])
    }

    func testAnExpiredRequestWithNoResponseFinishesWithoutRedirecting() {
        var events: [String] = []
        let completion = WalletConnectRequestCompletion(
            onDelivered: { events.append("redirect") },
            onFinished: { events.append("finish") }
        )

        completion.finish()
        completion.finish()

        XCTAssertEqual(events, ["finish"])
    }
}

private final class Owner {}
