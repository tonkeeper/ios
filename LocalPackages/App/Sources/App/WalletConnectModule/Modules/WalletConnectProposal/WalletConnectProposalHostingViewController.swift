import SwiftUI
import TKUIKit
import UIKit

final class WalletConnectProposalHostingViewController: TKHostingController<WalletConnectProposalScreen> {
    private let proposalId: String
    private let pairingTopic: String
    private let viewModel: WalletConnectProposalViewModel
    private var pendingExpirationDismissal: (animated: Bool, completion: (() -> Void)?)?

    init(
        proposalId: String,
        pairingTopic: String,
        viewModel: WalletConnectProposalViewModel
    ) {
        self.proposalId = proposalId
        self.pairingTopic = pairingTopic
        self.viewModel = viewModel
        super.init(content: WalletConnectProposalScreen(viewModel: viewModel))
        configurePresentation()
        viewModel.didTapNetworksList = { [weak self] in
            self?.presentNetworksList()
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

    func matchesProposal(id: String, pairingTopic: String) -> Bool {
        proposalId == id && self.pairingTopic == pairingTopic
    }

    func dismissAfterProposalExpired(
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

private extension WalletConnectProposalHostingViewController {
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

    func presentNetworksList() {
        guard presentedViewController == nil,
              viewModel.content.chains.count > 1
        else {
            return
        }

        let viewController = WalletConnectNetworksListHostingViewController(
            chains: viewModel.content.chains
        )
        present(viewController, animated: true)
    }
}

extension WalletConnectProposalHostingViewController: UIAdaptivePresentationControllerDelegate {
    func presentationControllerShouldDismiss(_ presentationController: UIPresentationController) -> Bool {
        false
    }

    func presentationControllerDidAttemptToDismiss(_ presentationController: UIPresentationController) {
        guard viewModel.canReject else { return }
        viewModel.reject()
    }

    func presentationControllerDidDismiss(_ presentationController: UIPresentationController) {
        viewModel.disappeared()
    }
}
