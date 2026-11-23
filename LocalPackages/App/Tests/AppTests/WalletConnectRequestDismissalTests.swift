@testable import App
import TKUIKit
import UIKit
import XCTest

@MainActor
final class WalletConnectRequestDismissalTests: XCTestCase {
    func testExpiryWaitsForPresentationAndDismissesOnlyOnce() async {
        let waiting = expectation(description: "waiting for passcode presentation")
        let finished = expectation(description: "expired request dismissed")
        let pause = Pause()
        var events: [String] = []
        let host = WalletConnectRequestHostingViewController(
            requestId: "request",
            topic: "session",
            viewModel: viewModel(),
            waitForTransitions: { _ in
                events.append("wait")
                waiting.fulfill()
                await pause.wait()
            },
            dismissRequest: { _, _, completion in
                events.append("dismiss")
                completion?()
            }
        )

        host.dismissAfterRequestExpired(animated: true) {
            events.append("finish")
            finished.fulfill()
        }
        await fulfillment(of: [waiting], timeout: 1)
        host.dismissAfterRequestExpired(animated: true) { XCTFail("duplicate expiry") }
        XCTAssertEqual(events, ["wait"])

        pause.release()
        await fulfillment(of: [finished], timeout: 1)

        XCTAssertEqual(events, ["wait", "dismiss", "finish"])
    }

    private func viewModel() -> WalletConnectRequestViewModel {
        WalletConnectRequestViewModel(
            content: WalletConnectRequestContent(
                dappName: "dApp", dappHost: "example.com", dappURL: nil, dappIconURL: nil,
                description: "Request", headline: AttributedString("Confirm"), chainIcon: UIImage(), rows: [], advancedDetails: []
            ),
            review: { nil },
            showErrorToast: { _ in }
        )
    }

    @MainActor
    private final class Pause {
        private var continuation: CheckedContinuation<Void, Never>?
        private var released = false
        func wait() async {
            guard !released else { return }
            await withCheckedContinuation { continuation = $0 }
        }

        func release() {
            released = true
            continuation?.resume()
            continuation = nil
        }
    }
}
