import TKUIKit
import UIKit

final class PickMultichainAddressViewController: TKHostingController<PickMultichainAddressScreen> {
    var didDismissInteractively: (() -> Void)?

    private let viewModel: PickMultichainAddressViewModelImplementation
    private var isProgrammaticDismissal = false

    init(viewModel: PickMultichainAddressViewModelImplementation) {
        self.viewModel = viewModel
        super.init(content: PickMultichainAddressScreen(viewModel: viewModel))
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

private extension PickMultichainAddressViewController {
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

extension PickMultichainAddressViewController: UIAdaptivePresentationControllerDelegate {
    func presentationControllerDidDismiss(_ presentationController: UIPresentationController) {
        guard !isProgrammaticDismissal else {
            return
        }

        didDismissInteractively?()
    }
}
