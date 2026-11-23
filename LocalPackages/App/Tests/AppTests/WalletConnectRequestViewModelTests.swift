@testable import App
@testable import KeeperCore
import OperationReviewModels
import TKLocalize
import TKTestSupport
import TKUIKit
import UIKit
import XCTest

final class WalletConnectRequestViewModelTests: XCTestCase {
    @MainActor
    func testApproveResponseDeliveryFailureAllowsRetry() async {
        let changed = TestSignal()
        let viewModel = makeViewModel()
        var approveCount = 0
        var completeCount = 0

        viewModel.didApprove = { _, _ in
            approveCount += 1
            changed.send()
            throw WalletConnectResponseError.sdk(message: "network", retryable: true)
        }
        viewModel.didComplete = {
            completeCount += 1
        }

        viewModel.approve()

        await waitUntil(viewModel.objectWillChange.merge(with: changed)) {
            viewModel.actionBarState == .idle && approveCount == 1
        }
        XCTAssertEqual(completeCount, 0)
        XCTAssertFalse(viewModel.canReject)
        XCTAssertTrue(viewModel.canApprove)

        viewModel.approve()

        await waitUntil(viewModel.objectWillChange.merge(with: changed)) {
            viewModel.actionBarState == .idle && approveCount == 2
        }
        XCTAssertEqual(completeCount, 0)
    }

    @MainActor
    func testApproveSigningFailureCompletes() async {
        let changed = TestSignal()
        let viewModel = makeViewModel()
        var completeCount = 0

        viewModel.didApprove = { _, _ in
            throw WalletConnectSigningError.failedToSign(reason: "Signing failed")
        }
        viewModel.didComplete = {
            completeCount += 1
            changed.send()
        }

        viewModel.approve()

        await waitUntil(changed) {
            completeCount == 1
        }
        XCTAssertEqual(viewModel.actionBarState, .failure)
    }

    @MainActor
    func testApproveResponseDeliveryFailurePreventsReject() async {
        let viewModel = makeViewModel()
        var rejectCount = 0

        viewModel.didApprove = { _, _ in
            throw WalletConnectResponseError.sdk(message: "network", retryable: true)
        }
        viewModel.didReject = {
            rejectCount += 1
        }

        viewModel.approve()

        await waitUntil(viewModel) {
            viewModel.actionBarState == .idle && !viewModel.canReject
        }
        viewModel.reject()
        XCTAssertEqual(rejectCount, 0)
    }

    @MainActor
    func testRejectResponseDeliveryFailureAllowsRetry() async {
        let changed = TestSignal()
        let viewModel = makeViewModel()
        var rejectCount = 0
        var completeCount = 0

        viewModel.didReject = {
            rejectCount += 1
            changed.send()
            throw WalletConnectResponseError.sdk(message: "network", retryable: true)
        }
        viewModel.didComplete = {
            completeCount += 1
        }

        viewModel.reject()

        await waitUntil(viewModel.objectWillChange.merge(with: changed)) {
            viewModel.actionBarState == .idle && rejectCount == 1
        }
        XCTAssertEqual(completeCount, 0)

        viewModel.reject()

        await waitUntil(viewModel.objectWillChange.merge(with: changed)) {
            viewModel.actionBarState == .idle && rejectCount == 2
        }
        XCTAssertEqual(completeCount, 0)
    }

    @MainActor
    func testApproveSigningFailureWithRejectDeliveryFailureAllowsRejectRetry() async {
        let changed = TestSignal()
        let viewModel = makeViewModel()
        var approveCount = 0
        var rejectCount = 0
        var completeCount = 0

        viewModel.didApprove = { _, _ in
            approveCount += 1
            throw WalletConnectRequestDeliveryRetryError.reject(
                WalletConnectResponseError.sdk(message: "network", retryable: true)
            )
        }
        viewModel.didReject = {
            rejectCount += 1
            changed.send()
            throw WalletConnectResponseError.sdk(message: "network", retryable: true)
        }
        viewModel.didComplete = {
            completeCount += 1
        }

        viewModel.approve()

        await waitUntil(viewModel) {
            viewModel.actionBarState == .idle && viewModel.canReject
        }
        XCTAssertEqual(approveCount, 1)
        XCTAssertEqual(completeCount, 0)
        XCTAssertTrue(viewModel.canReject)
        XCTAssertFalse(viewModel.canApprove)

        viewModel.approve()
        XCTAssertEqual(approveCount, 1)

        viewModel.reject()

        await waitUntil(viewModel.objectWillChange.merge(with: changed)) {
            viewModel.actionBarState == .idle && rejectCount == 1
        }
        XCTAssertEqual(completeCount, 0)
    }

    @MainActor
    func testRejectRetryCompletesWhenRetrySucceeds() async {
        let changed = TestSignal()
        let viewModel = makeViewModel()
        var rejectCount = 0
        var completeCount = 0

        viewModel.didApprove = { _, _ in
            throw WalletConnectRequestDeliveryRetryError.reject(
                WalletConnectResponseError.sdk(message: "network", retryable: true)
            )
        }
        viewModel.didReject = {
            rejectCount += 1
        }
        viewModel.didComplete = {
            completeCount += 1
            changed.send()
        }

        viewModel.approve()

        await waitUntil(viewModel) {
            viewModel.actionBarState == .idle && viewModel.canReject
        }

        viewModel.reject()

        await waitUntil(changed) {
            completeCount == 1
        }
        XCTAssertEqual(rejectCount, 1)
    }

    @MainActor
    func testRequestExpiredCompletesImmediately() async {
        let changed = TestSignal()
        var messages: [String] = []
        let viewModel = makeViewModel(
            waitForResultPresentation: { XCTFail("An expired request must finish immediately") },
            showErrorToast: { messages.append($0) }
        )
        var completeCount = 0

        viewModel.didApprove = { _, _ in
            throw WalletConnectResponseErrorMapper.map(
                NSError(domain: "WalletConnectSign.SessionResponder.Errors", code: 0),
                requestId: "1",
                topic: "topic"
            )
        }
        viewModel.didComplete = {
            completeCount += 1
            changed.send()
        }

        viewModel.approve()

        await waitUntil(changed) { completeCount == 1 }
        XCTAssertEqual(messages, [TKLocales.WalletConnect.Error.requestExpired])
        XCTAssertEqual(viewModel.actionBarState, .failure)
        XCTAssertFalse(viewModel.canApprove)
    }

    @MainActor
    func testExpiryAfterBroadcastShowsSubmittedTransactionWithoutRetry() async {
        let changed = TestSignal()
        var messages: [String] = []
        var approveCount = 0
        var completeCount = 0
        var deliveredCount = 0
        let viewModel = makeViewModel(
            waitForResultPresentation: { XCTFail("An expired request must finish immediately") },
            showErrorToast: { messages.append($0) }
        )
        viewModel.didApprove = { _, _ in
            approveCount += 1
            throw WalletConnectResponseError.requestExpiredAfterBroadcast(id: "1")
        }
        viewModel.didComplete = {
            completeCount += 1
            changed.send()
        }
        viewModel.didDeliverResponse = { deliveredCount += 1 }

        viewModel.approve()
        await waitUntil(changed) { completeCount == 1 }
        viewModel.approve()

        XCTAssertEqual(messages, [TKLocales.WalletConnect.Error.requestExpiredAfterBroadcast])
        XCTAssertEqual(approveCount, 1)
        XCTAssertEqual(deliveredCount, 0)
        XCTAssertEqual(viewModel.actionBarState, .failure)
        XCTAssertFalse(viewModel.canApprove)
        XCTAssertFalse(viewModel.canReject)
    }

    @MainActor
    func testTransactionIsApprovedOnlyWithTheFeeTheWalletPriced() async {
        let changed = TestSignal()
        let fee = WalletConnectEVMFee(amount: 63000, limit: 21000, price: .gas(price: 3))
        let viewModel = makeViewModel(feeQuote: feeQuote { fee })
        var approvedFee: WalletConnectEVMFee?
        viewModel.didApprove = { fee, _ in
            approvedFee = fee
            changed.send()
        }

        XCTAssertFalse(viewModel.canApprove)
        XCTAssertEqual(viewModel.content.rows.map(\.value), [AttributedString("loading")])

        await viewModel.loadFee()

        XCTAssertTrue(viewModel.canApprove)
        XCTAssertEqual(viewModel.content.rows.map(\.value), [AttributedString("63000")])

        viewModel.approve()

        await waitUntil(changed) {
            approvedFee != nil
        }
        XCTAssertEqual(approvedFee, fee)
    }

    @MainActor
    func testTransactionTheWalletCouldNotPriceCanOnlyBeRejected() async {
        let viewModel = makeViewModel(feeQuote: feeQuote {
            throw WalletConnectSigningError.failedToCalculateFee(reason: "execution reverted")
        })
        var approveCount = 0
        viewModel.didApprove = { _, _ in
            approveCount += 1
        }

        await viewModel.loadFee()
        viewModel.approve()

        XCTAssertFalse(viewModel.canApprove)
        XCTAssertTrue(viewModel.canReject)
        XCTAssertEqual(viewModel.content.rows.map(\.value), [AttributedString("unavailable")])
        XCTAssertEqual(approveCount, 0)
    }

    @MainActor
    func testTheReviewIsLoadedAlongsideTheFee() async {
        let fee = WalletConnectEVMFee(amount: 63000, limit: 21000, price: .gas(price: 3))
        let heldFee = Held<WalletConnectEVMFee>()
        let review = flaggedReview
        let viewModel = makeViewModel(feeQuote: feeQuote { await heldFee.load() }, review: { review })

        let loading = Task { await viewModel.load() }

        await waitUntil(viewModel) {
            viewModel.review == review
        }
        XCTAssertFalse(viewModel.canApprove)
        heldFee.release(fee)
        await loading.value
        XCTAssertTrue(viewModel.canApprove)
        XCTAssertEqual(viewModel.content.rows.map(\.value), [AttributedString("63000")])
    }

    /// The review only tints the slider: a slow one never holds back the fee the swipe waits for.
    @MainActor
    func testTheFeeIsLoadedAlongsideTheReview() async {
        let fee = WalletConnectEVMFee(amount: 63000, limit: 21000, price: .gas(price: 3))
        let heldReview = Held<OperationReview>()
        let review = flaggedReview
        let viewModel = makeViewModel(feeQuote: feeQuote { fee }, review: { await heldReview.load() })

        let loading = Task { await viewModel.load() }

        await waitUntil(viewModel) {
            viewModel.canApprove
        }
        XCTAssertEqual(viewModel.content.rows.map(\.value), [AttributedString("63000")])
        XCTAssertNil(viewModel.review)
        heldReview.release(review)
        await loading.value
        XCTAssertEqual(viewModel.review, review)
    }

    @MainActor
    func testTheFeeIsApprovableBeforeItsFiatPriceLoads() async {
        let fee = WalletConnectEVMFee(amount: 63000, limit: 21000, price: .gas(price: 3))
        let heldFiatPrice = Held<String>()
        var fiatPrice: String?
        let viewModel = makeViewModel(feeQuote: feeQuote(
            load: { fee },
            fiatPrice: { fiatPrice },
            loadFiatPrice: { fiatPrice = await heldFiatPrice.load() }
        ))

        let loading = Task { await viewModel.loadFee() }

        await waitUntil(viewModel) {
            viewModel.canApprove
        }
        XCTAssertEqual(viewModel.content.rows.map(\.value), [AttributedString("63000")])
        XCTAssertEqual(viewModel.content.rows.map(\.subtitle), [nil])
        heldFiatPrice.release("$0.19")
        await loading.value
        XCTAssertEqual(viewModel.content.rows.map(\.subtitle), ["$0.19"])
    }

    @MainActor
    func testAFiatPriceTheScreenLeftIsLoadedAgainWhenItReturns() async {
        let fee = WalletConnectEVMFee(amount: 63000, limit: 21000, price: .gas(price: 3))
        let neverLoadingFiatPrice = TestGate()
        var fiatPrice: String?
        var fiatPriceLoads = 0
        let viewModel = makeViewModel(feeQuote: feeQuote(
            load: { fee },
            fiatPrice: { fiatPrice },
            loadFiatPrice: {
                fiatPriceLoads += 1
                if fiatPriceLoads == 1 {
                    try? await neverLoadingFiatPrice.wait()
                } else {
                    fiatPrice = "$0.19"
                }
            }
        ))

        let leftScreen = Task { await viewModel.loadFee() }
        await waitUntil(viewModel) {
            viewModel.canApprove
        }
        leftScreen.cancel()
        await leftScreen.value
        XCTAssertEqual(viewModel.content.rows.map(\.subtitle), [nil])

        await viewModel.loadFee()

        XCTAssertEqual(fiatPriceLoads, 2)
        XCTAssertEqual(viewModel.content.rows.map(\.value), [AttributedString("63000")])
        XCTAssertEqual(viewModel.content.rows.map(\.subtitle), ["$0.19"])
    }

    @MainActor
    func testTheFeeIsUnavailableWithoutWaitingForItsFiatPrice() async {
        let heldFiatPrice = Held<String>()
        let viewModel = makeViewModel(feeQuote: feeQuote(
            load: { throw WalletConnectSigningError.failedToCalculateFee(reason: "execution reverted") },
            loadFiatPrice: { _ = await heldFiatPrice.load() }
        ))

        let loading = Task { await viewModel.loadFee() }

        await waitUntil(viewModel) {
            viewModel.content.rows.map(\.value) == [AttributedString("unavailable")]
        }
        XCTAssertFalse(viewModel.canApprove)
        heldFiatPrice.release("$0.19")
        await loading.value
        XCTAssertEqual(viewModel.content.rows.map(\.value), [AttributedString("unavailable")])
    }

    /// SwiftUI restarts the screen's task when it appears again, as after the passcode.
    @MainActor
    func testTheReviewIsLoadedOnceTheScreenStaysForIt() async {
        let changed = TestSignal()
        let review = flaggedReview
        let heldReview = Held<OperationReview>()
        var reviews = 0
        let viewModel = makeViewModel(review: {
            reviews += 1
            changed.send()
            if reviews == 1 {
                return await heldReview.load()
            }
            return review
        })

        let left = Task { await viewModel.load() }
        await waitUntil(changed) {
            reviews == 1
        }
        left.cancel()
        heldReview.release(review)
        await left.value
        XCTAssertNil(viewModel.review)
        await viewModel.load()
        await viewModel.load()

        XCTAssertEqual(reviews, 2)
        XCTAssertEqual(viewModel.review, review)
    }

    @MainActor
    func testEachApprovalAsksWithAFreshConsentOfTheScreen() async {
        let changed = TestSignal()
        let viewModel = makeViewModel()
        let answers = ConsentAttempts()
        var attempts = 0
        viewModel.consent = {
            attempts += 1
            return answers.consent(attempt: attempts)
        }
        let review = flaggedReview
        var approveCount = 0
        viewModel.didApprove = { _, consent in
            approveCount += 1
            changed.send()
            _ = await consent(review)
            throw WalletConnectResponseError.sdk(message: "network", retryable: true)
        }

        viewModel.approve()
        await waitUntil(viewModel.objectWillChange.merge(with: changed)) {
            viewModel.actionBarState == .idle && approveCount == 1
        }
        viewModel.approve()
        await waitUntil(viewModel.objectWillChange.merge(with: changed)) {
            viewModel.actionBarState == .idle && approveCount == 2
        }

        let asked = await answers.asked
        XCTAssertEqual(asked, [1, 2])
    }

    @MainActor
    func testAnApprovalFinishingAfterExpiryDoesNotUpdateOrCompleteTheClosedScreen() async {
        let changed = TestSignal()
        for fails in [false, true] {
            let held = Held<Bool>()
            let viewModel = makeViewModel()
            var started = false
            var returned = false
            var completions = 0
            var deliveries = 0
            viewModel.didApprove = { _, _ in
                started = true
                changed.send()
                _ = await held.load()
                returned = true
                changed.send()
                if fails { throw WalletConnectSigningError.canceled }
            }
            viewModel.didComplete = { completions += 1 }
            viewModel.didDeliverResponse = { deliveries += 1 }
            viewModel.approve()
            await waitUntil(changed) { started }

            viewModel.completeWithoutReject()
            held.release(true)
            await waitUntil(changed) { returned }

            XCTAssertEqual(viewModel.actionBarState, .loading)
            XCTAssertEqual(completions, 0)
            XCTAssertEqual(deliveries, fails ? 0 : 1)
            XCTAssertFalse(viewModel.canApprove)
        }
    }

    @MainActor
    func testALateBroadcastFailureNotifiesWithoutUpdatingTheExpiredScreen() async {
        let changed = TestSignal()
        let held = Held<Bool>()
        var started = false
        var messages: [String] = []
        var completions = 0
        var deliveries = 0
        let viewModel = makeViewModel(showErrorToast: {
            messages.append($0)
            changed.send()
        })
        viewModel.didApprove = { _, _ in
            started = true
            changed.send()
            _ = await held.load()
            throw WalletConnectResponseError.requestExpiredAfterBroadcast(id: "1")
        }
        viewModel.didComplete = { completions += 1 }
        viewModel.didDeliverResponse = { deliveries += 1 }
        viewModel.approve()
        await waitUntil(changed) { started }

        viewModel.completeWithoutReject()
        held.release(true)
        await waitUntil(changed) { !messages.isEmpty }

        XCTAssertEqual(messages, [TKLocales.WalletConnect.Error.requestExpiredAfterBroadcast])
        XCTAssertEqual(viewModel.actionBarState, .loading)
        XCTAssertEqual(completions, 0)
        XCTAssertEqual(deliveries, 0)
        XCTAssertFalse(viewModel.canApprove)
    }

    @MainActor
    func testFailedDeliveryIsKnownDuringFailurePresentationAndWaitingForRetry() async {
        let held = Held<Bool>()
        let viewModel = makeViewModel(waitForResultPresentation: { _ = await held.load() })
        viewModel.didApprove = { _, _ in
            throw WalletConnectResponseError.sdk(message: "network", retryable: true)
        }
        viewModel.approve()
        await waitUntil(viewModel) { viewModel.hasFailedApprovalDelivery }
        XCTAssertFalse(viewModel.canApprove)
        held.release(true)
        await waitUntil(viewModel) { viewModel.canApprove }
        XCTAssertTrue(viewModel.hasFailedApprovalDelivery)

        viewModel.completeWithoutReject(submittedRequestId: "1", submissionNotificationHandled: true)
        XCTAssertFalse(viewModel.canApprove)
    }

    @MainActor
    func testAlreadyShownSubmissionNoticeIsNotRepeatedByLateFailure() async {
        let changed = TestSignal()
        let held = Held<Bool>()
        var started = false
        var returned = false
        var messages: [String] = []
        let viewModel = makeViewModel(showErrorToast: { messages.append($0) })
        viewModel.didApprove = { _, _ in
            started = true
            changed.send()
            _ = await held.load()
            returned = true
            changed.send()
            throw WalletConnectResponseError.requestExpiredAfterBroadcast(id: "1")
        }
        viewModel.approve()
        await waitUntil(changed) { started }
        XCTAssertFalse(viewModel.hasFailedApprovalDelivery)

        viewModel.completeWithoutReject(submittedRequestId: "1", submissionNotificationHandled: true)
        held.release(true)
        await waitUntil(changed) { returned }
        XCTAssertTrue(messages.isEmpty)
    }

    @MainActor
    func testLateDeliveryFailureUsesTheKnownSubmissionAfterScreenClosure() async {
        let changed = TestSignal()
        for error in [WalletConnectResponseError.sdk(message: "network", retryable: true), .missingSession(topic: "session")] {
            let held = Held<Bool>()
            var started = false
            var messages: [String] = []
            let viewModel = makeViewModel(showErrorToast: {
                messages.append($0)
                changed.send()
            })
            viewModel.didApprove = { _, _ in
                started = true
                changed.send()
                _ = await held.load()
                throw error
            }
            viewModel.approve()
            await waitUntil(changed) { started }

            viewModel.completeWithoutReject(submittedRequestId: "1")
            held.release(true)
            await waitUntil(changed) { !messages.isEmpty }
            XCTAssertEqual(messages, [TKLocales.WalletConnect.Error.requestExpiredAfterBroadcast])
            XCTAssertFalse(viewModel.canApprove)
        }
    }

    @MainActor
    func testExpiryAfterApprovalDeliveryKeepsTheCompletionThatRedirectsTheDApp() async {
        let changed = TestSignal()
        let held = Held<Bool>()
        let viewModel = makeViewModel(waitForResultPresentation: { _ = await held.load() })
        var completions = 0
        viewModel.didApprove = { _, _ in }
        viewModel.didComplete = {
            completions += 1
            changed.send()
        }
        viewModel.approve()
        await waitUntil(viewModel) { viewModel.actionBarState == .success }

        XCTAssertFalse(viewModel.completeWithoutReject())
        XCTAssertEqual(completions, 0)
        held.release(true)
        await waitUntil(changed) { completions == 1 }

        XCTAssertEqual(viewModel.actionBarState, .success)
        XCTAssertFalse(viewModel.completeWithoutReject())
        XCTAssertEqual(completions, 1)
    }

    @MainActor
    func testARejectionFinishingAfterExpiryDoesNotCompleteOrShowAnError() async {
        let changed = TestSignal()
        for fails in [false, true] {
            let held = Held<Bool>()
            let viewModel = makeViewModel()
            var started = false
            var returned = false
            var completions = 0
            var deliveries = 0
            viewModel.didReject = {
                started = true
                changed.send()
                _ = await held.load()
                returned = true
                changed.send()
                if fails { throw WalletConnectResponseError.sdk(message: "late failure", retryable: true) }
            }
            viewModel.didComplete = { completions += 1 }
            viewModel.didDeliverResponse = { deliveries += 1 }
            viewModel.reject()
            await waitUntil(changed) { started }

            XCTAssertTrue(viewModel.completeWithoutReject())
            held.release(true)
            await waitUntil(changed) { returned }

            XCTAssertEqual(viewModel.actionBarState, .loading)
            XCTAssertEqual(completions, 0)
            XCTAssertEqual(deliveries, fails ? 0 : 1)
            XCTAssertFalse(viewModel.canReject)
        }
    }

    @MainActor
    func testExpiryAfterRejectionDeliveryKeepsTheNormalCompletion() async {
        let changed = TestSignal()
        let viewModel = makeViewModel()
        var completions = 0
        viewModel.didReject = {}
        viewModel.didComplete = {
            completions += 1
            changed.send()
        }
        viewModel.reject()
        await waitUntil(changed) { completions == 1 }

        XCTAssertFalse(viewModel.completeWithoutReject())
        XCTAssertEqual(completions, 1)
    }

    @MainActor
    func testExpiryAlsoCancelsTheRejectionStartedByDisappearing() async {
        let changed = TestSignal()
        let held = Held<Bool>()
        let viewModel = makeViewModel()
        var started = false
        var returned = false
        var completions = 0
        var deliveries = 0
        viewModel.didReject = {
            started = true
            changed.send()
            _ = await held.load()
            returned = true
            changed.send()
        }
        viewModel.didComplete = { completions += 1 }
        viewModel.didDeliverResponse = { deliveries += 1 }
        viewModel.disappeared()
        await waitUntil(changed) { started }

        XCTAssertTrue(viewModel.completeWithoutReject())
        held.release(true)
        await waitUntil(changed) { returned }

        XCTAssertEqual(completions, 0)
        XCTAssertEqual(deliveries, 1)
    }

    @MainActor
    func testExpiryInTheDeliveryCallbackStillRedirectsOnceAfterDismissal() async {
        let changed = TestSignal()
        for approves in [true, false] {
            let viewModel = makeViewModel()
            var events: [String] = []
            var returned = false
            let completion = WalletConnectRequestCompletion(
                onDelivered: { events.append("redirect") },
                onFinished: { events.append("finish") }
            )
            let delivered = {
                XCTAssertTrue(viewModel.completeWithoutReject())
                completion.finish()
                returned = true
                changed.send()
            }
            viewModel.didApprove = { _, _ in delivered() }
            viewModel.didReject = { delivered() }
            viewModel.didDeliverResponse = { completion.delivered() }
            viewModel.didComplete = { XCTFail("The expiry path already owns dismissal") }

            if approves { viewModel.approve() } else { viewModel.reject() }
            await waitUntil(changed) { returned }

            XCTAssertEqual(events, ["finish", "redirect"])
            XCTAssertEqual(viewModel.actionBarState, .loading)
        }
    }

    @MainActor
    func testExpiryAfterDisappearingDeliveredItsRejectionKeepsTheNormalCompletion() async {
        let changed = TestSignal()
        let viewModel = makeViewModel()
        var completions = 0
        viewModel.didReject = {}
        viewModel.didComplete = {
            completions += 1
            changed.send()
        }

        viewModel.disappeared()
        await waitUntil(changed) { completions == 1 }

        XCTAssertFalse(viewModel.completeWithoutReject())
        XCTAssertEqual(completions, 1)
    }

    @MainActor
    func testDisappearedRejectsAndCompletes() async {
        let changed = TestSignal()
        let viewModel = makeViewModel()
        var rejectCount = 0
        var completeCount = 0

        viewModel.didReject = {
            rejectCount += 1
            changed.send()
            throw WalletConnectResponseError.sdk(message: "network", retryable: true)
        }
        viewModel.didComplete = {
            completeCount += 1
            changed.send()
        }

        viewModel.disappeared()

        await waitUntil(changed) {
            rejectCount == 1 && completeCount == 1
        }
        XCTAssertFalse(viewModel.canApprove)
        XCTAssertFalse(viewModel.canReject)
    }
}

private extension WalletConnectRequestViewModelTests {
    var flaggedReview: OperationReview {
        OperationReview(id: "review", findings: [OperationFinding(id: "finding", kind: "Stub", severity: .warning, title: "Finding")])
    }

    @MainActor
    func makeViewModel(
        feeQuote: WalletConnectRequestFeeQuote? = nil,
        review: @escaping () async -> OperationReview? = { nil },
        resultPresentationDuration: UInt64 = 1_000_000,
        waitForResultPresentation: (() async -> Void)? = nil,
        showErrorToast: @escaping (String) -> Void = { _ in }
    ) -> WalletConnectRequestViewModel {
        WalletConnectRequestViewModel(
            content: WalletConnectRequestContent(
                dappName: "dApp",
                dappHost: "example.com",
                dappURL: nil,
                dappIconURL: nil,
                description: "Request",
                headline: AttributedString("Confirm"),
                chainIcon: UIImage(),
                rows: feeQuote.map { [$0.row(.loading)] } ?? [],
                advancedDetails: []
            ),
            feeQuote: feeQuote,
            review: review,
            resultPresentationDuration: resultPresentationDuration,
            waitForResultPresentation: waitForResultPresentation,
            showErrorToast: showErrorToast
        )
    }

    func feeQuote(
        load: @escaping () async throws -> WalletConnectEVMFee,
        fiatPrice: @escaping () -> String? = { nil },
        loadFiatPrice: @escaping () async -> Void = {}
    ) -> WalletConnectRequestFeeQuote {
        WalletConnectRequestFeeQuote(
            load: load,
            row: { display in
                let value = switch display {
                case .loading:
                    "loading"
                case let .loaded(fee):
                    fee.amount.description
                case .unavailable:
                    "unavailable"
                }
                return WalletConnectRequestInfoRow(
                    id: .fee,
                    title: "Network fee",
                    value: AttributedString(value),
                    subtitle: fiatPrice(),
                    valueIcon: nil,
                    trailingIcon: nil,
                    trailingIconColor: .accentBlue
                )
            },
            loadFiatPrice: loadFiatPrice
        )
    }
}

/// A fee or a review the screen is still loading until the test lets it through.
@MainActor
private final class Held<Value: Sendable> {
    private var continuation: CheckedContinuation<Value, Never>?
    private var released: Value?

    func load() async -> Value {
        if let released {
            return released
        }
        return await withCheckedContinuation { continuation = $0 }
    }

    func release(_ value: Value) {
        released = value
        continuation?.resume(returning: value)
        continuation = nil
    }
}

/// Which approval attempt each consent asked for, refusing every review.
private actor ConsentAttempts {
    private(set) var asked = [Int]()

    nonisolated func consent(attempt: Int) -> OperationConsent {
        OperationConsent { _ in
            await self.record(attempt)
            return false
        }
    }

    private func record(_ attempt: Int) {
        asked.append(attempt)
    }
}
