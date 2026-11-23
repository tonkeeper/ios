import AppUI
import SwiftUI
import TKUIKit
import UIKit

final class WalletConnectRequestHostingViewController: TKHostingController<WalletConnectRequestScreen> {
    typealias Dismiss = @MainActor (UIViewController, Bool, (() -> Void)?) -> Void

    private let requestId: String
    private let topic: String
    private let viewModel: WalletConnectRequestViewModel
    private lazy var consentPresenter = OperationConsentPresenter(host: { [weak self] in self })
    private let waitForTransitions: ModalTransitionWaiter.Wait
    private let dismissRequest: Dismiss
    private var expirationTask: Task<Void, Never>?

    init(
        requestId: String,
        topic: String,
        viewModel: WalletConnectRequestViewModel,
        waitForTransitions: @escaping ModalTransitionWaiter.Wait = ModalTransitionWaiter.wait,
        dismissRequest: @escaping Dismiss = { host, animated, completion in
            guard let presenter = host.presentingViewController else {
                completion?()
                return
            }
            presenter.dismiss(animated: animated, completion: completion)
        }
    ) {
        self.requestId = requestId
        self.topic = topic
        self.viewModel = viewModel
        self.waitForTransitions = waitForTransitions
        self.dismissRequest = dismissRequest
        super.init(content: WalletConnectRequestScreen(viewModel: viewModel))
        configurePresentation()
        viewModel.consent = { [consentPresenter] in
            consentPresenter.consent()
        }
    }

    @available(*, unavailable)
    @MainActor
    dynamic required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .Background.page
        tkPresentationController?.delegate = self
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)

        if isBeingDismissed || navigationController?.isBeingDismissed == true {
            viewModel.disappeared()
            consentPresenter.hostDidLeave()
        }
    }

    func matchesRequest(id: String, topic: String) -> Bool {
        requestId == id && self.topic == topic
    }

    var hasFailedApprovalDelivery: Bool {
        viewModel.hasFailedApprovalDelivery
    }

    @discardableResult
    func dismissAfterRequestExpired(
        animated: Bool,
        submittedRequestId: String? = nil,
        submissionNotificationHandled: Bool = false,
        completion: (() -> Void)? = nil
    ) -> Bool {
        // The request expired or its session ended: a review still asked about it is refused, not answered.
        // The presenting controller dismisses the host and its modals in one transition.
        guard expirationTask == nil,
              viewModel.completeWithoutReject(submittedRequestId: submittedRequestId, submissionNotificationHandled: submissionNotificationHandled)
        else { return false }
        consentPresenter.hostDidLeave(dismissSheet: false)
        expirationTask = Task { @MainActor [weak self] in
            guard let self else {
                completion?()
                return
            }
            await ModalTransitionWaiter.perform(from: presentingViewController ?? self, wait: waitForTransitions) {
                self.dismissRequest(self, animated, completion)
            }
        }
        return true
    }
}

private extension WalletConnectRequestHostingViewController {
    func configurePresentation() {
        modalPresentationStyle = .pageSheet

        guard let sheetPresentationController else {
            return
        }

        sheetPresentationController.detents = [.large()]
        sheetPresentationController.prefersGrabberVisible = false
        sheetPresentationController.prefersScrollingExpandsWhenScrolledToEdge = false
    }
}

extension WalletConnectRequestHostingViewController: UIAdaptivePresentationControllerDelegate {
    func presentationControllerShouldDismiss(_ presentationController: UIPresentationController) -> Bool {
        false
    }

    func presentationControllerDidAttemptToDismiss(_ presentationController: UIPresentationController) {
        guard viewModel.canDismiss else { return }
        viewModel.reject()
    }

    func presentationControllerDidDismiss(_ presentationController: UIPresentationController) {
        viewModel.disappeared()
    }
}
