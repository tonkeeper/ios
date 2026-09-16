@testable import App
@testable import KeeperCore
import UIKit
import XCTest

final class WalletConnectRequestViewModelTests: XCTestCase {
    @MainActor
    func testApproveResponseDeliveryFailureAllowsRetry() async {
        let viewModel = makeViewModel()
        var approveCount = 0
        var completeCount = 0

        viewModel.didApprove = {
            approveCount += 1
            throw WalletConnectResponseError.sdk(message: "network", retryable: true)
        }
        viewModel.didComplete = {
            completeCount += 1
        }

        viewModel.approve()

        await waitUntil {
            viewModel.actionBarState == .idle && approveCount == 1
        }
        XCTAssertEqual(completeCount, 0)
        XCTAssertFalse(viewModel.canReject)
        XCTAssertTrue(viewModel.canApprove)

        viewModel.approve()

        await waitUntil {
            viewModel.actionBarState == .idle && approveCount == 2
        }
        XCTAssertEqual(completeCount, 0)
    }

    @MainActor
    func testApproveSigningFailureCompletes() async {
        let viewModel = makeViewModel()
        var completeCount = 0

        viewModel.didApprove = {
            throw WalletConnectSigningError.failedToSign(reason: "Signing failed")
        }
        viewModel.didComplete = {
            completeCount += 1
        }

        viewModel.approve()

        await waitUntil {
            completeCount == 1
        }
        XCTAssertEqual(viewModel.actionBarState, .failure)
    }

    @MainActor
    func testApproveResponseDeliveryFailurePreventsReject() async {
        let viewModel = makeViewModel()
        var rejectCount = 0

        viewModel.didApprove = {
            throw WalletConnectResponseError.sdk(message: "network", retryable: true)
        }
        viewModel.didReject = {
            rejectCount += 1
        }

        viewModel.approve()

        await waitUntil {
            viewModel.actionBarState == .idle && !viewModel.canReject
        }
        viewModel.reject()
        XCTAssertEqual(rejectCount, 0)
    }

    @MainActor
    func testRejectResponseDeliveryFailureAllowsRetry() async {
        let viewModel = makeViewModel()
        var rejectCount = 0
        var completeCount = 0

        viewModel.didReject = {
            rejectCount += 1
            throw WalletConnectResponseError.sdk(message: "network", retryable: true)
        }
        viewModel.didComplete = {
            completeCount += 1
        }

        viewModel.reject()

        await waitUntil {
            viewModel.actionBarState == .idle && rejectCount == 1
        }
        XCTAssertEqual(completeCount, 0)

        viewModel.reject()

        await waitUntil {
            viewModel.actionBarState == .idle && rejectCount == 2
        }
        XCTAssertEqual(completeCount, 0)
    }

    @MainActor
    func testApproveSigningFailureWithRejectDeliveryFailureAllowsRejectRetry() async {
        let viewModel = makeViewModel()
        var approveCount = 0
        var rejectCount = 0
        var completeCount = 0

        viewModel.didApprove = {
            approveCount += 1
            throw WalletConnectRequestDeliveryRetryError.reject(
                WalletConnectResponseError.sdk(message: "network", retryable: true)
            )
        }
        viewModel.didReject = {
            rejectCount += 1
            throw WalletConnectResponseError.sdk(message: "network", retryable: true)
        }
        viewModel.didComplete = {
            completeCount += 1
        }

        viewModel.approve()

        await waitUntil {
            viewModel.actionBarState == .idle && viewModel.canReject
        }
        XCTAssertEqual(approveCount, 1)
        XCTAssertEqual(completeCount, 0)
        XCTAssertTrue(viewModel.canReject)
        XCTAssertFalse(viewModel.canApprove)

        viewModel.approve()
        XCTAssertEqual(approveCount, 1)

        viewModel.reject()

        await waitUntil {
            viewModel.actionBarState == .idle && rejectCount == 1
        }
        XCTAssertEqual(completeCount, 0)
    }

    @MainActor
    func testRejectRetryCompletesWhenRetrySucceeds() async {
        let viewModel = makeViewModel()
        var rejectCount = 0
        var completeCount = 0

        viewModel.didApprove = {
            throw WalletConnectRequestDeliveryRetryError.reject(
                WalletConnectResponseError.sdk(message: "network", retryable: true)
            )
        }
        viewModel.didReject = {
            rejectCount += 1
        }
        viewModel.didComplete = {
            completeCount += 1
        }

        viewModel.approve()

        await waitUntil {
            viewModel.actionBarState == .idle && viewModel.canReject
        }

        viewModel.reject()

        await waitUntil {
            completeCount == 1
        }
        XCTAssertEqual(rejectCount, 1)
    }

    @MainActor
    func testRequestExpiredCompletesImmediately() async {
        let viewModel = makeViewModel(resultPresentationDuration: 1_000_000_000)
        var completeCount = 0

        viewModel.didApprove = {
            throw WalletConnectResponseError.requestExpired(id: "1")
        }
        viewModel.didComplete = {
            completeCount += 1
        }

        viewModel.approve()

        await waitUntil(timeout: 0.1) {
            completeCount == 1
        }
    }

    @MainActor
    func testDisappearedRejectsAndCompletes() async {
        let viewModel = makeViewModel()
        var rejectCount = 0
        var completeCount = 0

        viewModel.didReject = {
            rejectCount += 1
            throw WalletConnectResponseError.sdk(message: "network", retryable: true)
        }
        viewModel.didComplete = {
            completeCount += 1
        }

        viewModel.disappeared()

        await waitUntil {
            rejectCount == 1 && completeCount == 1
        }
        XCTAssertFalse(viewModel.canApprove)
        XCTAssertFalse(viewModel.canReject)
    }
}

private extension WalletConnectRequestViewModelTests {
    @MainActor
    func makeViewModel(resultPresentationDuration: UInt64 = 1_000_000) -> WalletConnectRequestViewModel {
        WalletConnectRequestViewModel(
            content: WalletConnectRequestContent(
                dappName: "dApp",
                dappHost: "example.com",
                dappURL: nil,
                dappIconURL: nil,
                description: "Request",
                headline: AttributedString("Confirm"),
                chainIcon: UIImage(),
                rows: [],
                advancedDetails: []
            ),
            resultPresentationDuration: resultPresentationDuration,
            showErrorToast: { _ in }
        )
    }

    @MainActor
    func waitUntil(
        timeout: TimeInterval = 1,
        condition: @escaping () -> Bool
    ) async {
        let deadline = Date().addingTimeInterval(timeout)
        while !condition(), Date() < deadline {
            try? await Task.sleep(nanoseconds: 10_000_000)
        }
        if !condition() {
            XCTFail("Timed out waiting for condition")
        }
    }
}
