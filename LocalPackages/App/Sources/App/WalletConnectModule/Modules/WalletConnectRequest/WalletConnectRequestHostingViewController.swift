import SwiftUI
import TKUIKit
import UIKit

final class WalletConnectRequestHostingViewController: TKHostingController<WalletConnectRequestScreen> {
    private let requestId: String
    private let topic: String
    private let viewModel: WalletConnectRequestViewModel
    private var pendingExpirationDismissal: (animated: Bool, completion: (() -> Void)?)?

    init(
        requestId: String,
        topic: String,
        viewModel: WalletConnectRequestViewModel
    ) {
        self.requestId = requestId
        self.topic = topic
        self.viewModel = viewModel
        super.init(content: WalletConnectRequestScreen(viewModel: viewModel))
        configurePresentation()
    }

    @available(*, unavailable)
    @MainActor
    dynamic required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .Background.page
        presentationController?.delegate = self
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)

        if isBeingDismissed || navigationController?.isBeingDismissed == true {
            viewModel.disappeared()
        }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        performPendingExpirationDismissalIfNeeded()
    }

    func matchesRequest(id: String, topic: String) -> Bool {
        requestId == id && self.topic == topic
    }

    func dismissAfterRequestExpired(
        animated: Bool,
        completion: (() -> Void)? = nil
    ) {
        viewModel.completeWithoutReject()
        guard presentedViewController == nil else {
            pendingExpirationDismissal = (animated: animated, completion: completion)
            return
        }
        dismiss(animated: animated, completion: completion)
    }
}

private extension WalletConnectRequestHostingViewController {
    func performPendingExpirationDismissalIfNeeded() {
        guard presentedViewController == nil,
              let dismissal = pendingExpirationDismissal
        else {
            return
        }
        pendingExpirationDismissal = nil
        dismiss(animated: dismissal.animated, completion: dismissal.completion)
    }

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
