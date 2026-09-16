import SwiftUI
import TKUIKit
import UIKit

final class TokenManagementHostingViewController: TKHostingController<TokenManagementScreen> {
    var didDismissInteractively: (() -> Void)?

    private let viewModel: TokenManagementViewModelImplementation
    private var isProgrammaticDismissal = false

    init(viewModel: TokenManagementViewModelImplementation) {
        self.viewModel = viewModel
        super.init(content: TokenManagementScreen(viewModel: viewModel))
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
        viewModel.viewDidLoad()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        view.endEditing(true)
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)

        if isBeingDismissed || navigationController?.isBeingDismissed == true {
            viewModel.disappeared()
        }
    }

    func dismissFromCoordinator(
        animated: Bool,
        completion: (() -> Void)? = nil
    ) {
        isProgrammaticDismissal = true
        dismiss(animated: animated, completion: completion)
    }
}

private extension TokenManagementHostingViewController {
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

extension TokenManagementHostingViewController: UIAdaptivePresentationControllerDelegate {
    func presentationControllerDidDismiss(_ presentationController: UIPresentationController) {
        viewModel.disappeared()

        guard !isProgrammaticDismissal else {
            return
        }

        didDismissInteractively?()
    }
}
