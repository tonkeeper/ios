import SwiftUI
import TKUIKit
import UIKit

final class AddWalletOptionPickerViewController: TKHostingController<AddWalletOptionPickerScreen> {
    var didDismissInteractively: (() -> Void)?

    private let viewModel: AddWalletOptionPickerViewModelImplementation
    private var isProgrammaticDismissal = false

    init(viewModel: AddWalletOptionPickerViewModelImplementation) {
        self.viewModel = viewModel
        super.init(content: AddWalletOptionPickerScreen(viewModel: viewModel))
        configurePresentation()
    }

    @available(*, unavailable)
    @MainActor
    required init?(coder: NSCoder) {
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

    func dismissFromCoordinator(
        animated: Bool,
        completion: (() -> Void)? = nil
    ) {
        isProgrammaticDismissal = true
        dismiss(animated: animated, completion: completion)
    }
}

private extension AddWalletOptionPickerViewController {
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

extension AddWalletOptionPickerViewController: UIAdaptivePresentationControllerDelegate {
    func presentationControllerDidDismiss(_ presentationController: UIPresentationController) {
        guard !isProgrammaticDismissal else {
            return
        }

        didDismissInteractively?()
    }
}
