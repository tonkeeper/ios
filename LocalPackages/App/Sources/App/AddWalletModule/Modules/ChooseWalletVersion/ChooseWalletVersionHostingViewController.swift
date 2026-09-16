import SwiftUI
import TKUIKit
import UIKit

final class ChooseWalletVersionHostingViewController: UIViewController {
    private let viewModel: ChooseWalletVersionViewModel
    private let hostingController: TKHostingController<ChooseWalletVersionScreen>

    init(viewModel: ChooseWalletVersionViewModel) {
        self.viewModel = viewModel
        self.hostingController = TKHostingController(
            content: ChooseWalletVersionScreen(viewModel: viewModel)
        )
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .Background.page

        addChild(hostingController)
        view.addSubview(hostingController.view)
        hostingController.didMove(toParent: self)

        hostingController.view.backgroundColor = .clear
        hostingController.view.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            hostingController.view.topAnchor.constraint(equalTo: view.topAnchor),
            hostingController.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            hostingController.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            hostingController.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        guard !isMovingToParent else { return }
        viewModel.resetContinueImport()
    }
}
