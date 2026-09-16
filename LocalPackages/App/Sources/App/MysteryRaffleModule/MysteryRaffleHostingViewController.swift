import SwiftUI
import TKUIKit
import UIKit

final class MysteryRaffleHostingViewController: TKHostingController<MysteryRaffleView> {
    private let viewModel: MysteryRaffleViewModel

    init(viewModel: MysteryRaffleViewModel) {
        self.viewModel = viewModel
        super.init(content: MysteryRaffleView(viewModel: viewModel))
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
}

private extension MysteryRaffleHostingViewController {
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

extension MysteryRaffleHostingViewController: UIAdaptivePresentationControllerDelegate {
    func presentationControllerDidDismiss(_ presentationController: UIPresentationController) {
        viewModel.didTapClose()
    }
}
