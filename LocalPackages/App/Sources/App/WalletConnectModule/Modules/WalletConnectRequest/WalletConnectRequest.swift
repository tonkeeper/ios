import KeeperCore
import OperationReviewModels
import TKCoordinator
import TKCore
import TKUIKit
import UIKit

@MainActor
final class WalletConnectRequest: RouterCoordinator<ViewControllerRouter> {
    var didApprove: ((WalletConnectRequestApprovalState, WalletConnectEVMFee?, OperationConsent) async throws -> Void)?
    var didReject: (() async throws -> Void)?
    private let didDeliverResponse: () -> Void

    private let request: WalletConnectSessionRequest
    private let wallet: Wallet
    private let keeperCoreMainAssembly: KeeperCore.MainAssembly
    private let coreAssembly: TKCore.CoreAssembly
    private let approvalState = WalletConnectRequestApprovalState()
    private lazy var completion = WalletConnectRequestCompletion(
        onDelivered: didDeliverResponse,
        onFinished: { [weak self] in
            guard let self else { return }
            didFinish?(self)
        }
    )
    private weak var requestViewController: WalletConnectRequestHostingViewController?

    init(
        request: WalletConnectSessionRequest,
        wallet: Wallet,
        keeperCoreMainAssembly: KeeperCore.MainAssembly,
        coreAssembly: TKCore.CoreAssembly,
        didDeliverResponse: @escaping () -> Void,
        router: ViewControllerRouter
    ) {
        self.request = request
        self.wallet = wallet
        self.keeperCoreMainAssembly = keeperCoreMainAssembly
        self.coreAssembly = coreAssembly
        self.didDeliverResponse = didDeliverResponse
        super.init(router: router)
    }

    override func start() {
        openRequest()
    }

    func matchesRequest(id: String, topic: String) -> Bool {
        request.id == id
            && request.topic == topic
            && (requestViewController?.matchesRequest(id: id, topic: topic) ?? true)
    }

    /// Returns whether a submitted-transaction notice replaced the generic expiry notice.
    @discardableResult
    func dismissAfterRequestExpired() -> Bool {
        guard let requestViewController else {
            finish()
            return false
        }
        let submitted = approvalState.hasSubmittedTransaction(for: request.method)
        let notifySubmission = submitted && requestViewController.hasFailedApprovalDelivery
        let dismissed = requestViewController.dismissAfterRequestExpired(
            animated: true,
            submittedRequestId: submitted ? request.id : nil,
            submissionNotificationHandled: notifySubmission
        ) { [completion] in
            completion.finish()
        }
        guard dismissed, notifySubmission else { return false }
        let error = WalletConnectResponseError.requestExpiredAfterBroadcast(id: request.id)
        ToastPresenter.showToast(configuration: .init(title: error.localizedDescription))
        return true
    }
}

private extension WalletConnectRequest {
    func openRequest() {
        let module = WalletConnectRequestAssembly.module(
            request: request,
            wallet: wallet,
            keeperCoreMainAssembly: keeperCoreMainAssembly
        )
        let viewController = module.view
        requestViewController = viewController

        module.output.didReject = { [weak self] in
            guard let self else { return }
            try await self.didReject?()
        }

        module.output.didApprove = { [weak self] evmFee, consent in
            guard let self else { return }
            try await self.didApprove?(self.approvalState, evmFee, consent)
        }

        module.output.didOpenDAppHost = { [weak self] url in
            self?.coreAssembly.urlOpener().open(url: url)
        }

        let completion = completion
        module.output.didDeliverResponse = { completion.delivered() }
        module.output.didComplete = { [weak viewController] in
            guard let viewController,
                  viewController.presentingViewController != nil
            else {
                completion.finish()
                return
            }
            viewController.dismiss(animated: true) { completion.finish() }
        }

        router.rootViewController.topPresentedViewController().present(viewController.tkLiquidGlassModal(), animated: true)
    }

    func finish() {
        completion.finish()
    }
}

/// Delivery can return after expiry closed the screen and released its coordinator.
@MainActor
final class WalletConnectRequestCompletion {
    private var onDelivered: (() -> Void)?
    private var onFinished: (() -> Void)?
    private var isClosed = false
    private var hasResponse = false

    init(onDelivered: @escaping () -> Void, onFinished: @escaping () -> Void) {
        self.onDelivered = onDelivered
        self.onFinished = onFinished
    }

    func delivered() {
        hasResponse = true
        notifyIfClosed()
    }

    func finish() {
        isClosed = true
        notifyIfClosed()
        let onFinished = onFinished
        self.onFinished = nil
        onFinished?()
    }

    private func notifyIfClosed() {
        guard isClosed, hasResponse else { return }
        let onDelivered = onDelivered
        self.onDelivered = nil
        onDelivered?()
    }
}

@MainActor
final class WalletConnectRequestApprovalState {
    private var response: WalletConnectResponseValue?

    func cachedResponse() -> WalletConnectResponseValue? {
        response
    }

    func cacheResponse(_ response: WalletConnectResponseValue) {
        self.response = response
    }

    func hasSubmittedTransaction(for method: WalletConnectMethod) -> Bool {
        response != nil && method.broadcastsBeforeResponding
    }

    func deliveryError(_ error: WalletConnectResponseError, method: WalletConnectMethod, requestId: String) -> WalletConnectResponseError {
        guard hasSubmittedTransaction(for: method), !error.isRetryableDeliveryFailure else { return error }
        return .requestExpiredAfterBroadcast(id: requestId)
    }
}
