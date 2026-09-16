import SwiftUI
import TKUIKit
import UIKit

final class TokenPickerV2HostingViewController: TKHostingController<TokenPickerV2Screen> {
    private let viewModel: TokenPickerV2ViewModelImplementation
    private let presentation: TokenPickerV2Presentation

    init(
        viewModel: TokenPickerV2ViewModelImplementation,
        ignoresSafeArea: Bool = true,
        presentation: TokenPickerV2Presentation = .modal
    ) {
        self.viewModel = viewModel
        self.presentation = presentation
        super.init(content: TokenPickerV2Screen(
            viewModel: viewModel,
            ignoresSafeArea: ignoresSafeArea
        ))
        if presentation.configuresSheet {
            configurePresentation()
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
        viewModel.viewDidLoad()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        if !presentation.configuresSheet {
            navigationController?.setNavigationBarHidden(true, animated: animated)
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        view.endEditing(true)
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)

        if isBeingDismissed
            || navigationController?.isBeingDismissed == true
            || isMovingFromParent
        {
            viewModel.disappeared()
        }
    }
}

private extension TokenPickerV2HostingViewController {
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

extension TokenPickerV2HostingViewController: UIAdaptivePresentationControllerDelegate {
    func presentationControllerDidDismiss(_ presentationController: UIPresentationController) {
        viewModel.disappeared()
    }
}
